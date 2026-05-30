import re

class ObfuscatorDetector:
    @staticmethod
    def detect(code: str) -> str:
        """
        Analyzes Lua code to determine if it is obfuscated and by which obfuscator.
        """
        if not code or not isinstance(code, str):
            return "Unknown"

        # Luraph Detection
        if "Luraph" in code or re.search(r"Luraph\s*(?:Run|script|v\d+)", code, re.IGNORECASE):
            return "Luraph"
        if "does your environment support load/loadstring?" in code and "LPS" in code:
            return "Luraph"

        # Prometheus Detection
        if "newproxy,setmetatable,getmetatable,select,{...})end)(...)" in code or "newproxy, setmetatable, getmetatable" in code:
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

        # Fallback heuristic: check if it's Luau/Lua bytecode
        if code.startswith("\x1bLua") or code.startswith("\x1bLuau") or code.startswith("LJ\x01") or code.startswith("LJ\x02"):
            return "Bytecode"

        return "Unknown/None"
