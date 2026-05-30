import os
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sift.config import Config
from sift.core.deobfuscator import DeobfuscatorEngine
from sift.core.renamer import AIRenamer
from sift.core.decompiler import Decompiler
from sift.core.fetcher import AdvancedFetcher
import uuid

app = FastAPI(title="Sift API", description="Unified Lua reverse engineering backend")

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

@app.post("/api/deobf")
async def api_deobf(req: DeobfRequest):
    if not req.code.strip():
        raise HTTPException(status_code=400, detail="Code parameter cannot be empty.")
    success, output_code, console_log, detected_type = await DeobfuscatorEngine.deobfuscate(req.code, req.mode)
    return {
        "success": success,
        "output_code": output_code,
        "console_log": console_log,
        "detected_type": detected_type
    }

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
