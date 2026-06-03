import re
import codecs

DUMPED_LOG = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main\dumper-and-env-loggers-main\Revea.lol\revea.lol_dumped.lua"

with open(DUMPED_LOG, "r", encoding="utf-8") as f:
    lines = f.readlines()

for idx in range(45, 65):
    line = lines[idx]
    line_strip = line.strip()
    chunk_idx = line_strip.find("CHUNK:")
    if chunk_idx != -1:
        quote_char = line_strip[chunk_idx - 1]
        if line_strip.endswith(")"):
            end_quote_idx = line_strip.rfind(quote_char, 0, len(line_strip) - 1)
        else:
            end_quote_idx = line_strip.rfind(quote_char)
        raw_chunk = line_strip[chunk_idx + 6:end_quote_idx]
        try:
            unescaped = raw_chunk.encode("utf-8")
            decoded, _ = codecs.escape_decode(unescaped)
            decoded_str = decoded.decode("utf-8", errors="ignore")
        except Exception as e:
            decoded_str = f"Error: {e}"
        print(f"Line {idx+1}:")
        print(f"  Raw: {line_strip}")
        print(f"  Quote Char: {quote_char}")
        print(f"  End Quote Idx: {end_quote_idx}")
        print(f"  Extracted: {repr(decoded_str)}")
