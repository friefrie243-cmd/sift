import re

class ObfuscatorDetector:
    @staticmethod
    def detect(code: str) -> str:
        """
        Analyzes Lua code to determine if it is obfuscated and by which obfuscator.
        Improved with more robust detection patterns.
        """
        if not code or not isinstance(code, str):
            return "Unknown"

        # Check for binary bytecode first (before string analysis)
        if len(code) > 4:
            first_bytes = code[:4].encode("latin-1", errors="ignore")
            if first_bytes[:4] == b"\x1bLua":
                return "Bytecode"
            if first_bytes[:3] == b"\x1bLJ":
                return "Bytecode"
            # Luau bytecode starts with version byte (2-100)
            if len(first_bytes) > 0 and 2 <= first_bytes[0] <= 100 and not code[0].isascii():
                return "Bytecode"

        # Luraph Detection
        if "Luraph" in code or re.search(r"Luraph\s*(?:Run|script|v\d+)", code, re.IGNORECASE):
            return "Luraph"
        if "does your environment support load/loadstring?" in code and "LPS" in code:
            return "Luraph"

        # Prometheus Detection
        if "newproxy,setmetatable,getmetatable,select,{...})end)(...)end)(...)" in code:
            return "Prometheus"
        if "newproxy, setmetatable, getmetatable" in code:
            return "Prometheus"
        # More robust Prometheus detection: characteristic VM structure
        if re.search(r"local\s+\w+\s*=\s*newproxy\s*\(\s*true\s*\).*setmetatable.*getmetatable.*select", code, re.DOTALL):
            return "Prometheus"

        # Moonsec Detection
        if "This file was protected with MoonSec" in code or "Moonsec" in code:
            return "Moonsec"
        if re.search(r"ENV;\s*[\w_]+\s*=\s*'", code):
            return "Moonsec"

        # Moonveil Detection
        if re.search(r"\{\d+,\d+,\w+\},\{\d+,\d+,\w+\},\{\d+,\d+,\w+\}", code):
            return "Moonveil"

        # IronBrew Detection
        if "IronBrew" in code or "IronBrew v" in code:
            return "IronBrew"
        # Heuristic for IronBrew VM structure: check for large opcode lists and bitwise decryption loops
        if re.search(r"local\s+[\w_]+,\s*[\w_]+,\s*[\w_]+\s*=\s*select\s*\(\s*3,\s*\.\.\.\s*\)", code):
            if re.search(r"[\w_]+\s*=\s*[\w_]+\s*\+\s*[\w_]+", code) and "load" in code:
                return "IronBrew"

        # Soteria Detection
        if "Soteria" in code or re.search(r"--\s*Soteria\s*Obfuscator", code, re.IGNORECASE):
            return "Soteria"

        # WynnSfuscate Detection
        if "WynnSfuscate" in code or "Wynfuscate" in code:
            return "WynnSfuscate"

        # WeAreDevs Obfuscator Detection
        if re.search(r"v\d+\.\d+\s+https?://wearedevs\.net/obfuscator", code):
            return "WeAreDevs"
        
        # PSU (Psu.dev) Detection
        if "PSU" in code and re.search(r"local\s+\w+\s*=\s*string\.byte", code):
            return "PSU"

        # Fallback heuristic: check if it's heavily obfuscated by variable naming patterns
        # Large number of single-letter or underscore-heavy variables
        obf_var_count = len(re.findall(r"local\s+[_lI1]{3,}\s*=", code))
        if obf_var_count > 20:
            return "Unknown/Obfuscated"

        # Fallback heuristic: check if it's Luau/Lua bytecode by hex content
        if code.startswith("\x1bLua") or code.startswith("\x1bLuau") or code.startswith("LJ\x01") or code.startswith("LJ\x02"):
            return "Bytecode"

        return "Unknown/None"
