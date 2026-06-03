import re
import codecs

DUMPED_LOG = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main\dumper-and-env-loggers-main\Revea.lol\revea.lol_dumped.lua"

with open(DUMPED_LOG, "r", encoding="utf-8") as f:
    lines = f.readlines()

for idx in [24, 27, 30, 33, 36, 39]:
    line = lines[idx]
    line_strip = line.strip()
    chunk_idx = line_strip.find("CHUNK:")
    if chunk_idx != -1:
        quote_char = line_strip[chunk_idx - 1]
        end_quote_idx = line_strip.rfind(quote_char)
        raw_chunk = line_strip[chunk_idx + 6:end_quote_idx]
        print(f"Line {idx+1}:")
        print(f"  line_strip: {line_strip}")
        print(f"  quote_char: {quote_char}")
        print(f"  end_quote_idx: {end_quote_idx}")
        print(f"  raw_chunk: {raw_chunk}")
