import os

source_file = r"C:\Users\giyuu\.gemini\antigravity-ide\brain\c23b5897-07e6-405f-bb2b-19aae2234ceb\.system_generated\steps\375\content.md"
dest_file = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main\sift\resources\sift_ui_library.lua"

print(f"[*] Extracting Sift UI from {source_file} to {dest_file}...")

if not os.path.exists(source_file):
    print("[!] Error: Source file not found!")
    exit(1)

with open(source_file, "r", encoding="utf-8") as f:
    content = f.read()

parts = content.split("---\n\n")
if len(parts) < 2:
    parts = content.split("---")
    
if len(parts) >= 2:
    lua_code = "".join(parts[1:])
    # Strip leading/trailing newlines
    lua_code = lua_code.strip()
    
    os.makedirs(os.path.dirname(dest_file), exist_ok=True)
    with open(dest_file, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua_code)
    print(f"[+] Successfully extracted Sift UI library ({len(lua_code)} bytes)")
else:
    print("[!] Error: Could not find separation marker (---) in cached file.")
