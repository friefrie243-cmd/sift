import os
import shutil

PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
RESOURCES_DIR = os.path.join(PROJECT_ROOT, "sift", "resources")
os.makedirs(RESOURCES_DIR, exist_ok=True)

# Sources
dumper_src_dir = os.path.join(PROJECT_ROOT, "dumper-and-env-loggers-main")

def copy_and_prepare():
    print("[*] Copying resources to sift/resources...")
    
    # 1. Zala Dumper
    zala_src = os.path.join(dumper_src_dir, "zala-src-main", "dumper.lua")
    zala_dst = os.path.join(RESOURCES_DIR, "zala_dumper.lua")
    print(f"   Copying Zala Dumper: {zala_src} -> {zala_dst}")
    shutil.copy(zala_src, zala_dst)
    
    # 2. Larry Premium
    larry_premium_src = os.path.join(dumper_src_dir, "Revea.lol", "extracted", "_env_dumper_launcher.lua")
    larry_premium_dst = os.path.join(RESOURCES_DIR, "larry_dumper.lua")
    print(f"   Unescaping & Copying Larry Premium: {larry_premium_src} -> {larry_premium_dst}")
    with open(larry_premium_src, "r", encoding="utf-8") as f:
        content = f.read()
    # Replace literal '\\n' with actual newlines
    # Wait, let's do a safe replacement of '\\n' to '\n'
    content = content.replace("\\n", "\n")
    with open(larry_premium_dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)
        
    # 3. Flame Dumper
    flame_src = os.path.join(dumper_src_dir, "FlameCoderV3", "FlameDumperV3.txt")
    flame_dst = os.path.join(RESOURCES_DIR, "flame_dumper.lua")
    print(f"   Copying Flame Dumper: {flame_src} -> {flame_dst}")
    shutil.copy(flame_src, flame_dst)
    
    # 4. Polyester
    polyester_src = os.path.join(dumper_src_dir, "Polyester", "EMJKaQ.lua.txt")
    polyester_dst = os.path.join(RESOURCES_DIR, "polyester_dumper.lua")
    print(f"   Copying and modifying Polyester: {polyester_src} -> {polyester_dst}")
    with open(polyester_src, "r", encoding="utf-8") as f:
        p_content = f.read()
    # Replace last return q or append wrapper
    if p_content.endswith("return q\n") or p_content.endswith("return q"):
        p_content += "\n\nif arg and arg[1] then\n    q.dump_file(arg[1], arg[2])\nend\n"
    else:
        # Just append it
        p_content += "\n\nif arg and arg[1] then\n    q.dump_file(arg[1], arg[2])\nend\nreturn q\n"
    with open(polyester_dst, "w", encoding="utf-8", newline="\n") as f:
        f.write(p_content)
        
    # 5. Pengu Dumper
    pengu_src = os.path.join(dumper_src_dir, "Pengue-env", "auSqHhv.lua (2).txt")
    pengu_dst = os.path.join(RESOURCES_DIR, "pengu_dumper.lua")
    print(f"   Copying Pengu Dumper: {pengu_src} -> {pengu_dst}")
    shutil.copy(pengu_src, pengu_dst)
    
    # 6. 25ms logs
    httplog_25ms_src = os.path.join(dumper_src_dir, "25ms", "httplog.lua")
    httplog_25ms_dst = os.path.join(RESOURCES_DIR, "httplog_25ms.lua")
    print(f"   Copying 25ms HttpLog: {httplog_25ms_src} -> {httplog_25ms_dst}")
    shutil.copy(httplog_25ms_src, httplog_25ms_dst)
    
    loadstringlog_25ms_src = os.path.join(dumper_src_dir, "25ms", "loadstringlog.lua")
    loadstringlog_25ms_dst = os.path.join(RESOURCES_DIR, "loadstringlog_25ms.lua")
    print(f"   Copying 25ms LoadstringLog: {loadstringlog_25ms_src} -> {loadstringlog_25ms_dst}")
    shutil.copy(loadstringlog_25ms_src, loadstringlog_25ms_dst)
    
    # 7. Larry Regular
    larry_reg_src = os.path.join(dumper_src_dir, "Larry", "files.zvyz.live.lua.txt")
    larry_reg_dst = os.path.join(RESOURCES_DIR, "larry_regular.lua")
    print(f"   Copying Larry Regular: {larry_reg_src} -> {larry_reg_dst}")
    shutil.copy(larry_reg_src, larry_reg_dst)
    
    # 8. Kolenv Dumper
    kolenv_src = os.path.join(dumper_src_dir, "Kolenv", "olderleak.lua")
    kolenv_dst = os.path.join(RESOURCES_DIR, "kolenv_dumper.lua")
    print(f"   Copying Kolenv Dumper: {kolenv_src} -> {kolenv_dst}")
    shutil.copy(kolenv_src, kolenv_dst)
    
    kolenv_new_src = os.path.join(dumper_src_dir, "Kolenv", "possiblynewsrc")
    kolenv_new_dst = os.path.join(RESOURCES_DIR, "kolenv_dumper_new.lua")
    print(f"   Copying Kolenv Dumper (New): {kolenv_new_src} -> {kolenv_new_dst}")
    shutil.copy(kolenv_new_src, kolenv_new_dst)
    
    print("[+] Resources copied successfully!")

if __name__ == "__main__":
    copy_and_prepare()
