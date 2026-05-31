import os
import uuid
import time
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

@app.post("/api/deobf")
async def api_deobf(req: DeobfRequest):
    if not req.code.strip():
        raise HTTPException(status_code=400, detail="Code parameter cannot be empty.")
    success, output_code, console_log, detected_type = await DeobfuscatorEngine.deobfuscate(req.code, req.mode)
    job_id = _store_dump(output_code, f"sift_deobf.lua") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
        "job_id": job_id
    }

@app.post("/api/deobf-url")
async def api_deobf_url(req: DeobfUrlRequest):
    """Fetch code from a URL (loadstring link, raw GitHub, pastebin, etc.) and deobfuscate it."""
    if not req.url.strip():
        raise HTTPException(status_code=400, detail="URL cannot be empty.")

    url = req.url.strip()
    # Auto-convert common link formats to raw
    if "pastebin.com/" in url and "/raw/" not in url:
        url = url.replace("pastebin.com/", "pastebin.com/raw/")
    elif "github.com/" in url and "/raw/" not in url and "raw.githubusercontent.com" not in url:
        url = url.replace("github.com/", "raw.githubusercontent.com/").replace("/blob/", "/")

    success_fetch, content = await AdvancedFetcher.fetch(url)
    if not success_fetch:
        return {"success": False, "output_code": "", "console_log": f"[!] Failed to fetch URL: {content}", "detected_type": "N/A", "job_id": None}

    success, output_code, console_log, detected_type = await DeobfuscatorEngine.deobfuscate(content, req.mode)
    console_log = f"[*] Fetched {len(content)} bytes from {url}\n" + console_log
    job_id = _store_dump(output_code, f"sift_deobf.lua") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
        "job_id": job_id
    }

@app.post("/api/deobf-upload")
async def api_deobf_upload(
    file: UploadFile = File(...),
    mode: str = Form("auto")
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

    success, output_code, console_log, detected_type = await DeobfuscatorEngine.deobfuscate(code, mode)
    console_log = f"[*] Uploaded file: {file.filename} ({len(content)} bytes)\n" + console_log
    job_id = _store_dump(output_code, f"sift_deobf_{file.filename}") if output_code else None
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type,
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
