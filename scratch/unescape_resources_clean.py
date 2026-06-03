import os
import shutil

PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
NESTED_DIR = os.path.join(PROJECT_ROOT, "dumper-and-env-loggers-main")
RESOURCES_DIR = os.path.join(PROJECT_ROOT, "sift", "resources")

os.makedirs(RESOURCES_DIR, exist_ok=True)

def clean_escapes(content):
    # Replace escaped quotes and backslashes
    # We replace \\" with " and then \\ with \
    fixed = content.replace('\\\\"', '"')
    fixed = fixed.replace('\\\\\'', '\'')
    fixed = fixed.replace('\\\\', '\\')
    return fixed

def clean_escapes_single(content):
    # For Flame which uses \" instead of \\"
    fixed = content.replace('\\"', '"')
    fixed = fixed.replace('\\\'', '\'')
    fixed = fixed.replace('\\\\', '\\')
    return fixed

def copy_zala():
    src = os.path.join(NESTED_DIR, "zala-src-main", "dumper.lua")
    dst = os.path.join(RESOURCES_DIR, "zala_dumper.lua")
    print(f"[*] Copying Zala: {src} -> {dst}")
    shutil.copy(src, dst)

def copy_larry_regular():
    src = os.path.join(NESTED_DIR, "Larry", "files.zvyz.live.lua.txt")
    dst = os.path.join(RESOURCES_DIR, "larry_regular.lua")
    print(f"[*] Copying Larry Regular: {src} -> {dst}")
    shutil.copy(src, dst)

def process_pengu():
    src = os.path.join(NESTED_DIR, "Pengue-env", "auSqHhv.lua (2).txt")
    dst = os.path.join(RESOURCES_DIR, "pengu_dumper.lua")
    print(f"[*] Processing Pengu: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def process_kolenv():
    src = os.path.join(NESTED_DIR, "Kolenv", "olderleak.lua")
    dst = os.path.join(RESOURCES_DIR, "kolenv_dumper.lua")
    print(f"[*] Processing Kolenv: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        content = f.read()
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def process_kolenv_new():
    src = os.path.join(NESTED_DIR, "Kolenv", "possiblynewsrc")
    dst = os.path.join(RESOURCES_DIR, "kolenv_dumper_new.lua")
    print(f"[*] Processing Kolenv New: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    # Skip log printing lines (lines 1 to 6, 0-indexed: 0 to 5)
    # Line 1 is a comment we want to keep
    # Lines 2-6 are print statements
    # Line 7 is "local warn = warn or function() end"
    clean_lines = [lines[0]] + lines[6:]
    content = "".join(clean_lines)
    fixed = clean_escapes(content)
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def process_flame():
    src = os.path.join(NESTED_DIR, "FlameCoderV3", "FlameDumperV3.txt")
    dst = os.path.join(RESOURCES_DIR, "flame_dumper.lua")
    print(f"[*] Processing Flame: {src} -> {dst}")
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

def process_polyester():
    src = os.path.join(NESTED_DIR, "Polyester", "EMJKaQ.lua.txt")
    dst = os.path.join(RESOURCES_DIR, "polyester_dumper.lua")
    print(f"[*] Processing Polyester: {src} -> {dst}")
    with open(src, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    # Polyester starts on line 57 (index 56) and ends on line 6000 (index 5999)
    payload_lines = lines[56:6000]
    
    # Strip print("@ from first line
    payload_lines[0] = payload_lines[0].replace('print("@', '', 1)
    
    content = "".join(payload_lines)
    fixed = clean_escapes(content)
    
    # Polyester needs its return wrapper
    if not (fixed.strip().endswith("return q") or fixed.strip().endswith("return q\n")):
        fixed += "\n\nif arg and arg[1] then\n    q.dump_file(arg[1], arg[2])\nend\nreturn q\n"
        
    with open(dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(fixed)

def main():
    copy_zala()
    copy_larry_regular()
    process_pengu()
    process_kolenv()
    process_kolenv_new()
    process_flame()
    process_polyester()
    print("[+] All dumpers copied and unescaped successfully!")

if __name__ == "__main__":
    main()
