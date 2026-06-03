import os
import shutil

PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
NESTED_DIR = os.path.join(PROJECT_ROOT, "dumper-and-env-loggers-main")
RESOURCES_DIR = os.path.join(PROJECT_ROOT, "sift", "resources")

os.makedirs(RESOURCES_DIR, exist_ok=True)

def clean_escapes(content):
    # Perform clean, standard unescaping of backslashes and quotes
    # 1. Replace \\" with "
    content = content.replace('\\\\"', '"')
    # 2. Replace \\' with '
    content = content.replace('\\\\\'', '\'')
    # 3. Replace \\\\ with \\
    content = content.replace('\\\\', '\\')
    return content

def clean_escapes_single(content):
    # For Flame which uses \" instead of \\"
    content = content.replace('\\"', '"')
    content = content.replace('\\\'', '\'')
    content = content.replace('\\\\', '\\')
    return content

def unescape_zala():
    src = os.path.join(NESTED_DIR, "zala-src-main", "dumper.lua")
    dst = os.path.join(RESOURCES_DIR, "zala_dumper.lua")
    print(f"[*] Unescaping Zala: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def unescape_pengu():
    src = os.path.join(NESTED_DIR, "Pengue-env", "auSqHhv.lua (2).txt")
    dst = os.path.join(RESOURCES_DIR, "pengu_dumper.lua")
    print(f"[*] Unescaping Pengu: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def unescape_kolenv():
    src = os.path.join(NESTED_DIR, "Kolenv", "olderleak.lua")
    dst = os.path.join(RESOURCES_DIR, "kolenv_dumper.lua")
    print(f"[*] Unescaping Kolenv: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def unescape_kolenv_new():
    src = os.path.join(NESTED_DIR, "Kolenv", "possiblynewsrc")
    dst = os.path.join(RESOURCES_DIR, "kolenv_dumper_new.lua")
    print(f"[*] Unescaping Kolenv New: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        lines = f.readlines()
    # Skip log printing lines (index 1 to 5)
    clean_lines = [lines[0]] + lines[6:]
    content = "".join(clean_lines)
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def unescape_polyester():
    src = os.path.join(NESTED_DIR, "Polyester", "EMJKaQ.lua.txt")
    dst = os.path.join(RESOURCES_DIR, "polyester_dumper.lua")
    print(f"[*] Unescaping Polyester: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        lines = f.readlines()
    # Polyester payload is between line 57 (index 56) and 6001 (index 6000)
    payload_lines = lines[56:6001]
    payload_lines[0] = payload_lines[0].replace('print("@', '', 1)
    payload_lines[-1] = payload_lines[-1].replace('")', '', 1)
    content = "".join(payload_lines)
    fixed = clean_escapes(content)
    # Strip any trailing 'return q' to avoid duplicate return and append standard runner wrapper
    fixed = fixed.strip()
    if fixed.endswith("return q"):
        fixed = fixed[:-8]
    fixed += "\n\nif arg and arg[1] then\n    q.dump_file(arg[1], arg[2])\nend\nreturn q\n"
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def unescape_flame():
    src = os.path.join(NESTED_DIR, "FlameCoderV3", "FlameDumperV3.txt")
    dst = os.path.join(RESOURCES_DIR, "flame_dumper.lua")
    print(f"[*] Unescaping Flame: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    # Flame starts on line 8 (index 7) and ends on line 28413 (index 28412)
    payload_lines = lines[7:28413]
    
    # Strip print(" from first line
    payload_lines[0] = payload_lines[0].replace('print("', '', 1)
    # Strip ") from last line
    payload_lines[-1] = payload_lines[-1].replace('")', '', 1)
    
    clean_lines = []
    for line in payload_lines:
        line_clean = line.rstrip("\r\n")
        # Strip trailing backslash which escapes the newline in print string literal
        if line_clean.endswith("\\"):
            line_clean = line_clean[:-1]
        clean_lines.append(line_clean)
        
    content = "\n".join(clean_lines)
    fixed = clean_escapes_single(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def copy_static_resources():
    # Copy Larry Regular
    shutil.copy(
        os.path.join(NESTED_DIR, "Larry", "files.zvyz.live.lua.txt"),
        os.path.join(RESOURCES_DIR, "larry_regular.lua")
    )
    # Copy extracted Revea and Larry Premium from Revea.lol/extracted
    shutil.copy(
        os.path.join(NESTED_DIR, "Revea.lol", "extracted", "_env_dumper_launcher.lua"),
        os.path.join(RESOURCES_DIR, "larry_dumper.lua")
    )
    
    # Copy and patch revea_dumper.lua to be robust under standalone Lune
    revea_src_path = os.path.join(NESTED_DIR, "Revea.lol", "extracted", "message_1504352283192983645.lua")
    with open(revea_src_path, "r", encoding="utf-8") as f:
        revea_content = f.read()
    
    # Replace the fragile getfenv(3) block with a robust fallback loader
    fragile_block = 'local env = getfenv(3)\nlocal mt = getmetatable(env)\nlocal idx = rawget(mt, "__index")\nlocal req = rawget(idx, "require")\nlocal fs = req("@lune/fs")'
    robust_block = """local fs
local ok, req_fs = pcall(require, "@lune/fs")
if ok then
    fs = req_fs
else
    local env = getfenv and getfenv(3)
    if env then
        local mt = getmetatable(env)
        local idx = mt and rawget(mt, "__index")
        local req = idx and rawget(idx, "require")
        fs = req and req("@lune/fs")
    end
end
if not fs then
    error("Could not load @lune/fs")
end"""
    revea_content = revea_content.replace(fragile_block, robust_block)
    
    with open(os.path.join(RESOURCES_DIR, "revea_dumper.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write(revea_content)
    # Copy 25ms logs
    shutil.copy(
        os.path.join(NESTED_DIR, "25ms", "httplog.lua"),
        os.path.join(RESOURCES_DIR, "httplog_25ms.lua")
    )
    shutil.copy(
        os.path.join(NESTED_DIR, "25ms", "loadstringlog.lua"),
        os.path.join(RESOURCES_DIR, "loadstringlog_25ms.lua")
    )
    # Copy 45ms dumper
    shutil.copy(
        os.path.join(NESTED_DIR, "Old-45ms", "45ms.lua.txt"),
        os.path.join(RESOURCES_DIR, "45ms_dumper.lua")
    )

def main():
    unescape_zala()
    unescape_pengu()
    unescape_kolenv()
    unescape_kolenv_new()
    unescape_polyester()
    unescape_flame()
    copy_static_resources()
    print("[+] All resources processed and copied cleanly!")

if __name__ == "__main__":
    main()
