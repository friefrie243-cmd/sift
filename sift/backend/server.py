import os
import uuid
import time
import asyncio
from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional
from sift.config import Config
from sift.core.deobfuscator import DeobfuscatorEngine
from sift.core.renamer import AIRenamer
from sift.core.decompiler import Decompiler
from sift.core.fetcher import AdvancedFetcher
import aiohttp

app = FastAPI(title="Sift API", description="Unified Lua reverse engineering backend")

# In-memory store for recent dump results (job_id -> {output_code, timestamp, filename})
_dump_store = {}
_DUMP_TTL = 3600  # Keep dumps for 1 hour

def _cleanup_old_dumps():
    """Remove expired dumps."""
    now = time.time()
    expired = [k for k, v in _dump_store.items() if now - v["timestamp"] > _DUMP_TTL]
    for k in expired:
        # Also remove file if it exists
        dump = _dump_store.get(k, {})
        fpath = dump.get("filepath")
        if fpath and os.path.exists(fpath):
            try: os.remove(fpath)
            except: pass
        del _dump_store[k]

def _store_dump(output_code: str, filename: str = "sift_output.lua") -> str:
    """Store a dump result and return a job_id for download."""
    _cleanup_old_dumps()
    job_id = str(uuid.uuid4())
    # Save to dumps directory for persistence
    dump_path = os.path.join(Config.DUMPED_DIR, f"sift_{job_id}.lua")
    with open(dump_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(output_code)
    _dump_store[job_id] = {
        "output_code": output_code,
        "timestamp": time.time(),
        "filename": filename,
        "filepath": dump_path
    }
    return job_id

# Request schemas
class DeobfRequest(BaseModel):
    code: str
    mode: str = "auto"  # auto, IronBrew, Luraph, Moonsec, Prometheus, Bytecode, etc.
    all_outputs: bool = False
    include_loggers: bool = False

class RenameRequest(BaseModel):
    code: str
    provider: str = "openai"  # openai or ollama
    api_key: str = None

class FetchRequest(BaseModel):
    url: str
    retries: int = 3
    proxy: str = None

class DecompileRequest(BaseModel):
    bytecode_hex: str
    is_luau: bool = True

class DeobfUrlRequest(BaseModel):
    url: str
    mode: str = "auto"
    all_outputs: bool = False
    include_loggers: bool = False

@app.post("/api/deobf")
async def api_deobf(req: DeobfRequest):
    if not req.code.strip():
        raise HTTPException(status_code=400, detail="Code parameter cannot be empty.")
    success, output_code, console_log, detected_type, all_outputs = await DeobfuscatorEngine.deobfuscate(
        req.code, req.mode, req.all_outputs, req.include_loggers
    )
    job_id = _store_dump(output_code, f"sift_deobf.lua") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
        "all_outputs": all_outputs,
        "job_id": job_id
    }

def _extract_url_from_loadstring(text: str) -> str:
    """
    Extracts the actual URL from loadstring / HttpGet wrappers in Lua, if present.
    Example: loadstring(game:HttpGet("https://raw.githubusercontent.com/..."))()
    returns https://raw.githubusercontent.com/...
    """
    import re
    if not text:
        return ""
    text_strip = text.strip()
    patterns = [
        r'game\s*[:\.]\s*HttpGet\s*\(\s*["\'](https?://[^"\']+)["\']\s*\)',
        r'loadstring\s*\(\s*game\s*[:\.]\s*HttpGet\s*\(\s*["\'](https?://[^"\']+)["\']\s*\)\s*\)',
        r'loadstring\s*\(\s*["\'](https?://[^"\']+)["\']\s*\)',
    ]
    for pattern in patterns:
        match = re.search(pattern, text_strip, re.IGNORECASE)
        if match:
            return match.group(1)
            
    if text_strip.startswith("http://") or text_strip.startswith("https://"):
        return text_strip
        
    return text_strip

@app.post("/api/deobf-url")
async def api_deobf_url(req: DeobfUrlRequest):
    """Fetch code from a URL (loadstring link, raw GitHub, pastebin, etc.) and deobfuscate it."""
    if not req.url.strip():
        raise HTTPException(status_code=400, detail="URL cannot be empty.")

    url = _extract_url_from_loadstring(req.url)
    # Auto-convert common link formats to raw
    if "pastebin.com/" in url and "/raw/" not in url:
        url = url.replace("pastebin.com/", "pastebin.com/raw/")
    elif "github.com/" in url and "/raw/" not in url and "raw.githubusercontent.com" not in url:
        url = url.replace("github.com/", "raw.githubusercontent.com/").replace("/blob/", "/")

    success_fetch, content = await AdvancedFetcher.fetch(url)
    if not success_fetch:
        return {"success": False, "output_code": "", "console_log": f"[!] Failed to fetch URL: {content}", "detected_type": "N/A", "all_outputs": [], "job_id": None}

    success, output_code, console_log, detected_type, all_outputs = await DeobfuscatorEngine.deobfuscate(
        content, req.mode, req.all_outputs, req.include_loggers
    )
    console_log = f"[*] Fetched {len(content)} bytes from {url}\n" + console_log
    job_id = _store_dump(output_code, f"sift_deobf.lua") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
        "all_outputs": all_outputs,
        "job_id": job_id
    }

@app.post("/api/deobf-upload")
async def api_deobf_upload(
    file: UploadFile = File(...),
    mode: str = Form("auto"),
    all_outputs: bool = Form(False),
    include_loggers: bool = Form(False)
):
    """Accept a .lua or .txt file upload and deobfuscate it."""
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided.")

    # Validate extension
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in [".lua", ".txt", ".luau", ""]:
        raise HTTPException(status_code=400, detail=f"Unsupported file type: {ext}. Please upload .lua, .luau, or .txt files.")

    content = await file.read()
    code = content.decode("utf-8", errors="ignore")

    if not code.strip():
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    success, output_code, console_log, detected_type, all_outputs = await DeobfuscatorEngine.deobfuscate(
        code, mode, all_outputs, include_loggers
    )
    console_log = f"[*] Uploaded file: {file.filename} ({len(content)} bytes)\n" + console_log
    job_id = _store_dump(output_code, f"sift_deobf_{file.filename}") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
        "all_outputs": all_outputs,
        "job_id": job_id
    }

@app.get("/api/download/{job_id}")
async def api_download(job_id: str):
    """Download a dump result by job_id."""
    if job_id not in _dump_store:
        raise HTTPException(status_code=404, detail="Dump not found or expired. Dumps are kept for 1 hour.")
    dump = _dump_store[job_id]
    filepath = dump.get("filepath")
    if filepath and os.path.exists(filepath):
        return FileResponse(
            filepath,
            media_type="text/plain",
            filename=dump.get("filename", "sift_output.lua")
        )
    # Fallback: return from memory
    from fastapi.responses import Response
    return Response(
        content=dump["output_code"],
        media_type="text/plain",
        headers={"Content-Disposition": f'attachment; filename="{dump.get("filename", "sift_output.lua")}"'}
    )

@app.post("/api/rename")
async def api_rename(req: RenameRequest):
    if not req.code.strip():
        raise HTTPException(status_code=400, detail="Code parameter cannot be empty.")
    renamed_code = await AIRenamer.rename(req.code, req.provider, req.api_key)
    return {
        "success": not renamed_code.startswith("-- [AI Renamer Error]"),
        "renamed_code": renamed_code
    }

@app.post("/api/fetch")
async def api_fetch(req: FetchRequest):
    if not req.url.strip():
        raise HTTPException(status_code=400, detail="URL cannot be empty.")
    success, text = await AdvancedFetcher.fetch(req.url, req.retries, req.proxy)
    return {
        "success": success,
        "content": text
    }

@app.post("/api/decompile")
async def api_decompile(req: DecompileRequest):
    job_id = str(uuid.uuid4())
    temp_in = os.path.join(Config.TEMP_DIR, f"dec_{job_id}.luac")
    temp_out = os.path.join(Config.TEMP_DIR, f"dec_{job_id}.lua")

    try:
        bytecode = bytes.fromhex(req.bytecode_hex.strip())
        with open(temp_in, "wb") as f:
            f.write(bytecode)

        success, details = await Decompiler.decompile(temp_in, temp_out, req.is_luau)
        output_code = ""
        if success and os.path.exists(temp_out):
            with open(temp_out, "r", encoding="utf-8", errors="ignore") as f:
                output_code = f.read()
        return {
            "success": success,
            "output_code": output_code,
            "details": details
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Decompilation failed: {str(e)}")
    finally:
        if os.path.exists(temp_in): os.remove(temp_in)
        if os.path.exists(temp_out): os.remove(temp_out)



def update_env_file(token: str, prefix: str):
    env_path = ".env"
    lines = []
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
    
    updated_token = False
    updated_prefix = False
    new_lines = []
    
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("DISCORD_TOKEN=") or stripped.startswith("BOT_TOKEN="):
            new_lines.append(f"DISCORD_TOKEN={token}\n")
            updated_token = True
        elif stripped.startswith("BOT_PREFIX="):
            new_lines.append(f"BOT_PREFIX={prefix}\n")
            updated_prefix = True
        else:
            new_lines.append(line)
            
    if not updated_token:
        new_lines.append(f"DISCORD_TOKEN={token}\n")
    if not updated_prefix:
        new_lines.append(f"BOT_PREFIX={prefix}\n")
        
    # Write to local .env
    with open(env_path, "w", encoding="utf-8") as f:
        f.writelines(new_lines)
        
    Config.reload()

    # Async trigger to update Render Environment Variables
    async def update_render():
        import aiohttp
        render_url = f"https://api.render.com/v1/services/srv-d8d6s0km0tmc73dk7lkg/env-vars"
        headers = {
            "Authorization": "Bearer rnd_LMRVLdOeuFVsfDmOZTjYq4noML7A",
            "Content-Type": "application/json"
        }
        # Render accepts a list of env vars to put/patch. We update BOT_TOKEN.
        payload = [
            {"key": "BOT_TOKEN", "value": token}
        ]
        try:
            async with aiohttp.ClientSession() as session:
                async with session.put(render_url, json=payload, headers=headers) as resp:
                    if resp.status in [200, 201]:
                        print("[*] Successfully synchronized bot token with Render env vars.")
                    else:
                        body = await resp.text()
                        print(f"[!] Render env sync failed with status {resp.status}: {body}")
        except Exception as e:
            print(f"[!] Render env sync exception: {e}")
            
    asyncio.create_task(update_render())

from sift.bot.state import BotManager

def check_auth(key: str):
    if key != Config.API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized Sift API Key")

@app.get("/api/bot/status")
async def api_bot_status(key: str = Query(...)):
    check_auth(key)
    return BotManager.get_status()

@app.get("/api/bot/logs")
async def api_bot_logs(key: str = Query(...), lines: int = 150):
    check_auth(key)
    log_path = "dumps/sift_system.log"
    if not os.path.exists(log_path):
        return {"logs": "System log file does not exist yet. Please start operations."}
    try:
        with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
            all_lines = f.readlines()
        tail = "".join(all_lines[-lines:])
        return {"logs": tail}
    except Exception as e:
        return {"logs": f"Error reading logs: {str(e)}"}

class BotConfigRequest(BaseModel):
    token: str
    prefix: str
    key: str

@app.post("/api/bot/config")
async def api_bot_config(req: BotConfigRequest):
    check_auth(req.key)
    update_env_file(req.token, req.prefix)
    await BotManager.restart()
    return {"success": True, "status": BotManager.get_status()}

class BotControlRequest(BaseModel):
    action: str
    key: str

@app.post("/api/bot/control")
async def api_bot_control(req: BotControlRequest):
    check_auth(req.key)
    if req.action == "start":
        await BotManager.start()
    elif req.action == "stop":
        await BotManager.stop()
    elif req.action == "restart":
        await BotManager.restart()
    else:
        raise HTTPException(status_code=400, detail="Invalid action")
    return {"success": True, "status": BotManager.get_status()}

@app.get("/bot", response_class=HTMLResponse)
async def serve_bot_dashboard():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Sift Engine - Bot Control Panel</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
        <style>
            :root {
                --bg-color: #08060f;
                --panel-bg: rgba(22, 17, 38, 0.7);
                --border-color: rgba(187, 134, 252, 0.15);
                --primary: #9d4edd;
                --primary-glow: rgba(157, 78, 221, 0.4);
                --secondary: #c77dff;
                --text-color: #f1ecf9;
                --text-muted: #a594bd;
                --success: #38b000;
                --error: #d90429;
            }

            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                background-color: var(--bg-color);
                background-image: radial-gradient(circle at 10% 20%, rgba(90, 24, 154, 0.12) 0%, transparent 40%),
                                  radial-gradient(circle at 90% 80%, rgba(60, 9, 108, 0.12) 0%, transparent 40%);
                color: var(--text-color);
                font-family: 'Outfit', sans-serif;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                overflow-x: hidden;
            }

            /* Glass panel card */
            .panel {
                background: var(--panel-bg);
                border: 1px solid var(--border-color);
                border-radius: 16px;
                padding: 32px;
                width: 90%;
                max-width: 1000px;
                box-shadow: 0 12px 40px 0 rgba(0, 0, 0, 0.5);
                backdrop-filter: blur(12px);
                display: flex;
                flex-direction: column;
                gap: 24px;
            }

            .panel-header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                border-bottom: 1px solid var(--border-color);
                padding-bottom: 16px;
            }

            .logo {
                font-size: 24px;
                font-weight: 800;
                color: var(--text-color);
                letter-spacing: 1px;
            }
            .logo span {
                background: linear-gradient(135deg, var(--secondary), var(--primary));
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
            }

            .title {
                font-size: 20px;
                font-weight: 600;
                color: var(--secondary);
                display: flex;
                align-items: center;
                gap: 10px;
            }

            /* Auth Overlay */
            #auth-overlay {
                position: fixed;
                inset: 0;
                background: rgba(8, 6, 15, 0.95);
                z-index: 1000;
                display: flex;
                justify-content: center;
                align-items: center;
                backdrop-filter: blur(10px);
            }
            .auth-card {
                background: var(--panel-bg);
                border: 1px solid var(--border-color);
                border-radius: 16px;
                padding: 40px;
                width: 90%;
                max-width: 450px;
                text-align: center;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.5);
                display: flex;
                flex-direction: column;
                gap: 20px;
            }

            /* Form Elements */
            input, select, button {
                background: rgba(36, 28, 59, 0.6);
                border: 1px solid var(--border-color);
                color: var(--text-color);
                padding: 12px 18px;
                border-radius: 8px;
                font-family: inherit;
                font-size: 14px;
                outline: none;
                transition: all 0.3s;
                width: 100%;
            }
            input:focus {
                border-color: var(--primary);
                box-shadow: 0 0 8px var(--primary-glow);
            }
            button {
                cursor: pointer;
                font-weight: 600;
                background: linear-gradient(135deg, var(--primary), var(--secondary));
                border: none;
                user-select: none;
            }
            button:hover {
                transform: translateY(-1px);
                box-shadow: 0 4px 15px var(--primary-glow);
            }
            button.stop-btn {
                background: linear-gradient(135deg, #d90429, #ef233c);
            }
            button.stop-btn:hover {
                box-shadow: 0 4px 15px rgba(217, 4, 41, 0.4);
            }
            button.sec-btn {
                background: rgba(36, 28, 59, 0.8);
                border: 1px solid var(--border-color);
                border-radius: 8px;
            }
            button.sec-btn:hover {
                border-color: var(--primary);
                background: rgba(50, 38, 80, 0.8);
                box-shadow: none;
            }

            .grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 24px;
            }
            @media (max-width: 768px) {
                .grid { grid-template-columns: 1fr; }
            }

            .card {
                background: rgba(30, 23, 51, 0.4);
                border: 1px solid var(--border-color);
                border-radius: 12px;
                padding: 20px;
                display: flex;
                flex-direction: column;
                gap: 16px;
            }

            .card-title {
                font-size: 16px;
                font-weight: 600;
                color: var(--secondary);
                border-bottom: 1px solid rgba(187, 134, 252, 0.1);
                padding-bottom: 8px;
            }

            .status-row {
                display: flex;
                align-items: center;
                gap: 12px;
                font-size: 18px;
                font-weight: 600;
            }

            /* Pulsing Dot */
            .status-dot {
                width: 12px;
                height: 12px;
                border-radius: 50%;
                display: inline-block;
                animation: pulse 2s infinite;
            }
            .status-dot.online { background: var(--success); }
            .status-dot.starting { background: #f77f00; }
            .status-dot.offline { background: #5a5468; }
            .status-dot.error { background: var(--error); }

            @keyframes pulse {
                0%, 100% { opacity: 1; }
                50% { opacity: 0.4; }
            }

            .info-item {
                display: flex;
                justify-content: space-between;
                font-size: 14px;
                color: var(--text-muted);
            }
            .info-item span:last-child {
                color: var(--text-color);
                font-weight: 600;
            }

            /* Log terminal style */
            .logs-container {
                display: flex;
                flex-direction: column;
                gap: 8px;
                flex-grow: 1;
            }
            .logs-terminal {
                background: #040308;
                border: 1px solid var(--border-color);
                border-radius: 8px;
                padding: 16px;
                font-family: 'JetBrains Mono', monospace;
                font-size: 12px;
                color: #e2e0eb;
                height: 250px;
                overflow-y: auto;
                white-space: pre-wrap;
                line-height: 1.5;
                box-shadow: inset 0 2px 10px rgba(0,0,0,0.8);
            }

            .toast {
                position: fixed;
                bottom: 30px;
                right: 30px;
                background: rgba(22, 17, 38, 0.95);
                border: 1px solid var(--border-color);
                border-radius: 12px;
                padding: 14px 20px;
                color: var(--text-color);
                font-size: 14px;
                transform: translateY(100px);
                opacity: 0;
                transition: all 0.4s ease;
                z-index: 1001;
            }
            .toast.show { transform: translateY(0); opacity: 1; }
        </style>
    </head>
    <body>
        <!-- Password Authorization Overlay -->
        <div id="auth-overlay">
            <div class="auth-card">
                <div class="logo">SIFT <span>ENGINE</span></div>
                <p style="color: var(--text-muted); font-size: 14px;">Please enter the Sift system API Key to access the Discord Bot Dashboard.</p>
                <input type="password" id="auth-key-input" placeholder="System API Key">
                <button onclick="authorize()">Unlock Dashboard</button>
            </div>
        </div>

        <!-- Main Dashboard Panel -->
        <div class="panel" id="dashboard" style="display: none;">
            <div class="panel-header">
                <div class="logo">SIFT <span>BOT CONTROL</span></div>
                <div>
                    <button class="sec-btn" onclick="logout()" style="padding: 8px 16px; font-size: 12px; width: auto;">Lock Dashboard</button>
                </div>
            </div>

            <div class="grid">
                <!-- Status Card -->
                <div class="card">
                    <div class="card-title">Bot Status & Metadata</div>
                    <div class="status-row">
                        <span class="status-dot offline" id="bot-dot"></span>
                        <span id="bot-status-text">OFFLINE</span>
                    </div>
                    <div class="info-item">
                        <span>Username:</span>
                        <span id="bot-username">N/A</span>
                    </div>
                    <div class="info-item">
                        <span>Bot ID:</span>
                        <span id="bot-id">N/A</span>
                    </div>
                    <div class="info-item">
                        <span>Latency:</span>
                        <span id="bot-latency">N/A</span>
                    </div>
                    <div class="info-item">
                        <span>Active Prefix:</span>
                        <span id="bot-active-prefix">!</span>
                    </div>
                    <div class="info-item" id="bot-error-row" style="display: none; color: var(--error); flex-direction: column; gap: 4px; align-items: flex-start;">
                        <span>Error Details:</span>
                        <span id="bot-error-text" style="color: var(--error); font-family: monospace; font-size: 12px; text-align: left; max-height: 60px; overflow-y: auto; width: 100%;">None</span>
                    </div>
                </div>

                <!-- Bot Settings Form -->
                <div class="card">
                    <div class="card-title">Configuration (.env)</div>
                    <div style="display: flex; flex-direction: column; gap: 12px;">
                        <div>
                            <label style="font-size: 12px; color: var(--text-muted); display: block; margin-bottom: 6px;">Discord Token</label>
                            <input type="password" id="config-token" placeholder="MTIzNDU2Nzg5MDEyMzQ1Njc4...">
                        </div>
                        <div>
                            <label style="font-size: 12px; color: var(--text-muted); display: block; margin-bottom: 6px;">Command Prefix</label>
                            <input type="text" id="config-prefix" placeholder="!" maxlength="5">
                        </div>
                        <button onclick="saveConfig()" style="margin-top: 6px;">Save & Restart Bot</button>
                    </div>
                </div>
            </div>

            <!-- Bot Lifecycle Controls -->
            <div class="card">
                <div class="card-title">Service Controls</div>
                <div style="display: flex; gap: 16px; flex-wrap: wrap;">
                    <button onclick="triggerControl('start')" style="flex: 1; min-width: 150px; background: linear-gradient(135deg, #137333, #38b000);">Start Service</button>
                    <button class="stop-btn" onclick="triggerControl('stop')" style="flex: 1; min-width: 150px;">Stop Service</button>
                    <button class="sec-btn" onclick="triggerControl('restart')" style="flex: 1; min-width: 150px;">Restart Service</button>
                </div>
            </div>

            <!-- Terminal Logs -->
            <div class="card" style="flex-grow: 1;">
                <div class="panel-header" style="border: none; padding: 0;">
                    <div class="card-title" style="border: none; padding: 0;">System console logs (sift_system.log)</div>
                    <button class="sec-btn" onclick="fetchLogs()" style="padding: 6px 12px; font-size: 12px; width: auto;">Refresh Logs</button>
                </div>
                <div class="logs-container">
                    <div class="logs-terminal" id="terminal">Loading logs...</div>
                </div>
            </div>
        </div>

        <div class="toast" id="toast"></div>

        <script>
            let apiKey = localStorage.getItem("sift_api_key") || "";
            let logInterval = null;
            let statusInterval = null;

            function showToast(message) {
                const toast = document.getElementById("toast");
                toast.textContent = message;
                toast.classList.add("show");
                setTimeout(() => toast.classList.remove("show"), 3000);
            }

            window.onload = function() {
                if (apiKey) {
                    document.getElementById("auth-overlay").style.display = "none";
                    document.getElementById("dashboard").style.display = "flex";
                    startPolling();
                }
            };

            function authorize() {
                const val = document.getElementById("auth-key-input").value.trim();
                if (!val) {
                    showToast("Please enter an API Key.");
                    return;
                }
                apiKey = val;
                // Test the key by requesting status
                fetch(`/api/bot/status?key=${encodeURIComponent(apiKey)}`)
                    .then(res => {
                        if (res.status === 401) {
                            showToast("Invalid API Key.");
                            apiKey = "";
                        } else {
                            localStorage.setItem("sift_api_key", apiKey);
                            document.getElementById("auth-overlay").style.display = "none";
                            document.getElementById("dashboard").style.display = "flex";
                            startPolling();
                            showToast("Dashboard unlocked!");
                        }
                    })
                    .catch(err => {
                        showToast("Network error: " + err.message);
                        apiKey = "";
                    });
            }

            function logout() {
                localStorage.removeItem("sift_api_key");
                apiKey = "";
                clearInterval(logInterval);
                clearInterval(statusInterval);
                document.getElementById("auth-overlay").style.display = "flex";
                document.getElementById("dashboard").style.display = "none";
                document.getElementById("auth-key-input").value = "";
            }

            function startPolling() {
                updateStatus();
                fetchLogs();
                // Poll status every 5 seconds
                statusInterval = setInterval(updateStatus, 5000);
                // Poll logs every 3 seconds
                logInterval = setInterval(fetchLogs, 3000);
            }

            function updateStatus() {
                if (!apiKey) return;
                fetch(`/api/bot/status?key=${encodeURIComponent(apiKey)}`)
                    .then(res => {
                        if (res.status === 401) {
                            logout();
                            showToast("API Key expired or unauthorized.");
                            return null;
                        }
                        return res.json();
                    })
                    .then(data => {
                        if (!data) return;
                        // Update UI status dot
                        const dot = document.getElementById("bot-dot");
                        dot.className = "status-dot " + data.status;
                        
                        const statusTxt = document.getElementById("bot-status-text");
                        statusTxt.textContent = data.status.toUpperCase();
                        if (data.status === "online") statusTxt.style.color = "var(--success)";
                        else if (data.status === "starting") statusTxt.style.color = "#f77f00";
                        else if (data.status === "error") statusTxt.style.color = "var(--error)";
                        else statusTxt.style.color = "var(--text-muted)";

                        document.getElementById("bot-username").textContent = data.username || "N/A";
                        document.getElementById("bot-id").textContent = data.bot_id || "N/A";
                        document.getElementById("bot-latency").textContent = data.latency ? (data.latency + "ms") : "N/A";
                        document.getElementById("bot-active-prefix").textContent = data.prefix || "!";

                        const errRow = document.getElementById("bot-error-row");
                        if (data.error) {
                            errRow.style.display = "flex";
                            document.getElementById("bot-error-text").textContent = data.error;
                        } else {
                            errRow.style.display = "none";
                        }
                    })
                    .catch(err => {
                        console.error("Status check failed", err);
                    });
            }

            function fetchLogs() {
                if (!apiKey) return;
                fetch(`/api/bot/logs?key=${encodeURIComponent(apiKey)}&lines=150`)
                    .then(res => res.json())
                    .then(data => {
                        const term = document.getElementById("terminal");
                        const isAtBottom = term.scrollHeight - term.clientHeight <= term.scrollTop + 50;
                        term.textContent = data.logs || "No logs available.";
                        if (isAtBottom) {
                            term.scrollTop = term.scrollHeight;
                        }
                    })
                    .catch(err => {
                        console.error("Logs fetch failed", err);
                    });
            }

            function saveConfig() {
                const token = document.getElementById("config-token").value.trim();
                const prefix = document.getElementById("config-prefix").value.trim();

                if (!token || !prefix) {
                    showToast("Token and Prefix cannot be empty.");
                    return;
                }

                showToast("Saving config and restarting bot...");
                fetch("/api/bot/config", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ token, prefix, key: apiKey })
                })
                .then(res => res.json())
                .then(data => {
                    if (data.success) {
                        showToast("Config saved! Bot is restarting...");
                        updateStatus();
                        document.getElementById("config-token").value = "";
                    } else {
                        showToast("Failed to save configuration.");
                    }
                })
                .catch(err => {
                    showToast("Error saving configuration: " + err.message);
                });
            }

            function triggerControl(action) {
                showToast(`Sending service action: ${action}...`);
                fetch("/api/bot/control", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ action, key: apiKey })
                })
                .then(res => res.json())
                .then(data => {
                    if (data.success) {
                        showToast(`Bot successfully triggered to ${action}!`);
                        updateStatus();
                    } else {
                        showToast(`Failed to trigger ${action}.`);
                    }
                })
                .catch(err => {
                    showToast("Control trigger failed: " + err.message);
                });
            }
        </script>
    </body>
    </html>
    """

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "sift"}

# Serve simple web static files
os.makedirs("sift/backend/static", exist_ok=True)

@app.get("/", response_class=HTMLResponse)
async def serve_ui():
    static_ui_path = "sift/backend/static/index.html"
    if os.path.exists(static_ui_path):
        with open(static_ui_path, "r", encoding="utf-8") as f:
            return f.read()

    # Simple default premium Sift UI placeholder if the main index.html isn't written yet
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Sift Engine</title>
        <style>
            body { background: #0b0914; color: #e2e0eb; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
            h1 { color: #bb86fc; }
        </style>
    </head>
    <body>
        <div><h1>Sift Web UI Loading...</h1></div>
    </body>
    </html>
    """

try:
    app.mount("/static", StaticFiles(directory="sift/backend/static"), name="static")
except:
    pass

# Self-ping loop to keep the Render free tier container active 24/7
async def _self_ping_loop():
    # Wait 30 seconds after container boot before beginning self-pings
    await asyncio.sleep(30)
    url = os.getenv("RENDER_EXTERNAL_URL", "https://sift-vs4y.onrender.com").rstrip("/") + "/health"
    print(f"[*] Self-ping auto-wake loop started. Target: {url}")
    while True:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=15) as resp:
                    print(f"[*] Self-ping success: HTTP {resp.status}")
        except Exception as e:
            print(f"[!] Self-ping failed: {e}")
        # Sleep for 10 minutes (600 seconds) to prevent idling
        await asyncio.sleep(600)

@app.on_event("startup")
async def startup_event():
    asyncio.create_task(_self_ping_loop())
