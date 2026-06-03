import codecs

src_path = r"c:\Users\giyuu\Downloads\dumper-and-env-loggers-main\dumper-and-env-loggers-main\Revea.lol\extracted\_env_dumper_launcher.lua"
with open(src_path, "r", encoding="utf-8") as f:
    content = f.read()

print("Original length:", len(content))
print("First 200 chars:", repr(content[:200]))

# Let's decode it using codecs.escape_decode
try:
    raw_bytes = content.encode("utf-8")
    decoded_bytes, _ = codecs.escape_decode(raw_bytes)
    decoded = decoded_bytes.decode("utf-8", errors="ignore")
    print("Decoded length:", len(decoded))
    print("First 200 chars decoded:", repr(decoded[:200]))
except Exception as e:
    print("Error:", e)
