import os
import re
import codecs

PROJECT_ROOT = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main"
DUMPED_LOG = os.path.join(PROJECT_ROOT, "dumper-and-env-loggers-main", "Revea.lol", "revea.lol_dumped.lua")

def unescape_chunk(chunk_str):
    try:
        # codecs.escape_decode unescapes standard backslash sequences like \n, \", \\
        # It takes bytes, so we encode to utf-8 first
        raw_bytes = chunk_str.encode("utf-8")
        decoded_bytes, _ = codecs.escape_decode(raw_bytes)
        decoded = decoded_bytes.decode("utf-8", errors="ignore")
        return decoded
    except Exception as e:
        print(f"Error decoding chunk: {e}")
        return chunk_str

def extract():
    print(f"[*] Reading {DUMPED_LOG}...")
    with open(DUMPED_LOG, "r", encoding="utf-8") as f:
        lines = f.readlines()
        
    current_file = None
    file_chunks = []
    
    for idx, line in enumerate(lines):
        line_strip = line.strip()
        
        # We only match START_FILE / END_FILE if the line is literally print("START_FILE:...")
        # or print('START_FILE:...') and NOT inside a CHUNK
        if line_strip.startswith('print("START_FILE:') or line_strip.startswith("print('START_FILE:"):
            # Extract filename
            m = re.search(r'START_FILE:(.+?)["\']', line_strip)
            if m:
                current_file = m.group(1)
                file_chunks = []
                print(f"[+] Found file start: {current_file}")
            continue
            
        if line_strip.startswith('print("END_FILE:') or line_strip.startswith("print('END_FILE:"):
            m = re.search(r'END_FILE:(.+?)["\']', line_strip)
            if m:
                fname = m.group(1)
                if current_file:
                    full_content = "".join(file_chunks)
                    out_basename = os.path.basename(current_file)
                    
                    if out_basename == "_env_dumper_launcher.lua":
                        out_basename = "larry_dumper.lua"
                    elif out_basename == "message_1504352283192983645.lua":
                        out_basename = "revea_dumper.lua"
                        
                    out_path = os.path.join(PROJECT_ROOT, "sift", "resources", out_basename)
                    print(f"[+] Reconstructing {out_path} ({len(full_content)} bytes)...")
                    with open(out_path, "w", encoding="utf-8", newline="\n") as out_f:
                        out_f.write(full_content)
                    current_file = None
            continue
            
        # Extract chunk if we are inside a file
        if current_file:
            # We want to match lines that contain the chunk string
            # e.g., 'CHUNK:...' or "CHUNK:..."
            # Since the print is formatted, the line is: 'CHUNK:content' or "CHUNK:content"
            # Let's find the first index of CHUNK:
            chunk_idx = line_strip.find("CHUNK:")
            if chunk_idx != -1:
                quote_char = line_strip[chunk_idx - 1]
                if quote_char in ["'", '"']:
                    # Find closing quote
                    if line_strip.endswith(")"):
                        end_quote_idx = line_strip.rfind(quote_char, 0, len(line_strip) - 1)
                    else:
                        end_quote_idx = line_strip.rfind(quote_char)
                        
                    if end_quote_idx != -1 and end_quote_idx > chunk_idx + 6:
                        raw_chunk = line_strip[chunk_idx + 6:end_quote_idx]
                        unescaped = unescape_chunk(raw_chunk)
                        file_chunks.append(unescaped)
                    else:
                        print(f"[!] Warning: Could not find closing quote on line {idx + 1}: {line_strip}")

if __name__ == "__main__":
    extract()
