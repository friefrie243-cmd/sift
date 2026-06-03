import os
import re

PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
RESOURCES_DIR = os.path.join(PROJECT_ROOT, "sift", "resources")

def unescape_quote_counting(lines, quote_pattern=r'\\\\"'):
    # Merges lines where a string literal is opened but not closed (odd number of quote_pattern)
    merged_lines = []
    current_line = ""
    in_string = False
    
    for idx, line in enumerate(lines):
        # Strip newline characters for processing
        line_clean = line.rstrip("\r\n")
        
        # Count the number of quote patterns (e.g. \\")
        # We need to be careful: if the quote pattern is \\", we count matches
        quote_count = len(re.findall(quote_pattern, line_clean))
        
        if quote_count % 2 == 1:
            in_string = not in_string
            
        if in_string:
            # We are inside a string, so the literal newline at the end of the line
            # should be escaped as \n in the Lua file
            current_line += line_clean + "\\n"
        else:
            current_line += line_clean
            merged_lines.append(current_line)
            current_line = ""
            
    if current_line:
        merged_lines.append(current_line)
        
    # Now unescape quotes and backslashes in the merged lines
    unescaped_content = []
    for line in merged_lines:
        # \\" -> "
        # \\' -> '
        # \\\\ -> \\
        # We replace \\" first, then \\', then \\
        line_fixed = line
        if quote_pattern == r'\\\\"':
            line_fixed = line_fixed.replace('\\\\"', '"')
            line_fixed = line_fixed.replace("\\\\'", "'")
            line_fixed = line_fixed.replace("\\\\", "\\")
        elif quote_pattern == r'\\"':
            line_fixed = line_fixed.replace('\\"', '"')
            line_fixed = line_fixed.replace("\\'", "'")
            line_fixed = line_fixed.replace("\\\\", "\\")
        unescaped_content.append(line_fixed)
        
    return "\n".join(unescaped_content)

def clean_zala():
    src_path = os.path.join(RESOURCES_DIR, "zala_dumper.lua")
    print(f"[*] Cleaning Zala: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    
    content = unescape_quote_counting(lines, r'\\\\"')
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def clean_pengu():
    src_path = os.path.join(RESOURCES_DIR, "pengu_dumper.lua")
    print(f"[*] Cleaning Pengu: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    content = unescape_quote_counting(lines, r'\\\\"')
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def clean_kolenv():
    src_path = os.path.join(RESOURCES_DIR, "kolenv_dumper.lua")
    print(f"[*] Cleaning Kolenv: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    content = unescape_quote_counting(lines, r'\\\\"')
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def clean_kolenv_new():
    src_path = os.path.join(RESOURCES_DIR, "kolenv_dumper_new.lua")
    print(f"[*] Cleaning Kolenv New: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    # Strip the first 6 lines of console prints
    # Line 1: -- https://discord.gg/WCZghenRpw | kolenvlogger v1.25
    # Line 2-6: prints of re-acquiring, etc.
    # Line 7: local warn = warn or function() end
    cleaned_lines = []
    cleaned_lines.append(lines[0]) # keep comment line
    for line in lines[6:]:
        cleaned_lines.append(line)
        
    content = unescape_quote_counting(cleaned_lines, r'\\\\"')
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def clean_flame():
    src_path = os.path.join(RESOURCES_DIR, "flame_dumper.lua")
    print(f"[*] Cleaning Flame Dumper: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    cleaned_lines = []
    started = False
    for idx, line in enumerate(lines):
        line_strip = line.strip()
        if not started:
            if line_strip.startswith('print("do\\'):
                # print("do\ is the line. We want just do
                line_fixed = line_strip[7:] # strip print("
                if line_fixed.endswith("\\"):
                    line_fixed = line_fixed[:-1]
                cleaned_lines.append(line_fixed)
                started = True
            continue
        else:
            # We are in the body. Every line has a trailing \
            if line_strip.endswith("\\"):
                # Strip trailing \
                line_fixed = line_strip[:-1]
                cleaned_lines.append(line_fixed)
            elif line_strip == '")':
                # End of print
                break
            else:
                cleaned_lines.append(line_strip)
                
    # Now unescape the body (uses \" and not \\")
    content = "\n".join(cleaned_lines)
    content = content.replace('\\"', '"')
    content = content.replace("\\'", "'")
    content = content.replace("\\\\", "\\")
    
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def clean_polyester():
    src_path = os.path.join(RESOURCES_DIR, "polyester_dumper.lua")
    print(f"[*] Cleaning Polyester: {src_path}")
    with open(src_path, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    cleaned_lines = []
    started = False
    for idx, line in enumerate(lines):
        line_strip = line.strip()
        if not started:
            if line_strip.startswith('print("@local a = debug') or line_strip.startswith('print("@local a ='):
                line_fixed = line_strip[8:] # strip print("@
                cleaned_lines.append(line_fixed)
                started = True
            continue
        else:
            if line_strip == '")':
                continue
            cleaned_lines.append(line)
            
    # Now merge lines with quote counting
    content = unescape_quote_counting(cleaned_lines, r'\\\\"')

    
    # Let's fix the appended polyester wrapper if it got messed up
    # The wrapper was:
    # if arg and arg[1] then
    #     q.dump_file(arg[1], arg[2])
    # end
    # return q
    # If the unescape replaced quotes or backslashes in the wrapper, it's fine since it didn't contain escapes.
    with open(src_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(content)

def main():
    clean_zala()
    clean_pengu()
    clean_kolenv()
    clean_kolenv_new()
    clean_flame()
    clean_polyester()
    print("[+] All resource files cleaned successfully!")

if __name__ == "__main__":
    main()
