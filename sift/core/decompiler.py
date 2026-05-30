import os
import subprocess
import asyncio
import base64
import aiohttp
from sift.config import Config

class Decompiler:
    @staticmethod
    async def decompile_lua(file_path: str, out_path: str) -> bool:
        """
        Decompiles standard Lua 5.1 bytecode using unluac.jar.
        """
        if not os.path.exists(Config.UNLUAC_JAR_PATH):
            # Fallback path check
            jar_path = "./deobfuscate/unluac.jar"
            if not os.path.exists(jar_path):
                jar_path = "../deobfuscate/unluac.jar"
        else:
            jar_path = Config.UNLUAC_JAR_PATH
            
        if not os.path.exists(jar_path):
            return False

        cmd = [Config.JAVA_PATH, "-jar", jar_path, file_path, "-o", out_path]
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await process.communicate()
            if process.returncode == 0 and os.path.exists(out_path):
                return True
        except Exception as e:
            print(f"Error in decompile_lua: {e}")
        return False

    @staticmethod
    async def decompile_luau(file_path: str, out_path: str) -> bool:
        """
        Decompiles Roblox Luau bytecode using luau-lifter.exe or fallbacks to api.lua.expert.
        """
        lifter_path = Config.LUAU_LIFTER_PATH
        if not os.path.exists(lifter_path):
            lifter_path = "./medal51/luau-lifter.exe"
            if not os.path.exists(lifter_path):
                lifter_path = "../medal51/luau-lifter.exe"

        success = False
        if os.path.exists(lifter_path):
            try:
                process = await asyncio.create_subprocess_exec(
                    lifter_path, file_path, "-e",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await process.communicate()
                if not stderr:
                    with open(out_path, 'w', encoding='utf-8') as f:
                        f.write(stdout.decode('utf-8', errors='ignore'))
                    success = True
            except Exception as e:
                print(f"Error running luau-lifter: {e}")

        # Fallback to api.lua.expert API if lifter failed
        if not success:
            try:
                with open(file_path, "rb") as f:
                    content = f.read()
                
                async with aiohttp.ClientSession() as session:
                    headers = {"Content-Type": "application/json"}
                    payload = {"script": base64.b64encode(content).decode()}
                    async with session.post("https://api.lua.expert/decompile", json=payload, headers=headers) as response:
                        if response.status == 200:
                            result_text = await response.text()
                            with open(out_path, "w", encoding="utf-8") as f:
                                f.write(result_text)
                            success = True
            except Exception as e:
                print(f"Decompilation API fallback error: {e}")
                
        return success

    @classmethod
    async def decompile(cls, file_path: str, out_path: str, is_luau: bool = True) -> tuple[bool, str]:
        """
        Selects appropriate decompiler based on type. Returns (success, details).
        """
        if not os.path.exists(file_path):
            return False, "Input file does not exist."

        # Detect by extension or binary header if possible
        with open(file_path, "rb") as f:
            header = f.read(4)
        
        # Standard Lua bytecode starts with \x1bLua
        is_lua_standard = (header == b"\x1bLua")
        
        if is_lua_standard:
            ok = await cls.decompile_lua(file_path, out_path)
            if ok:
                return True, "Standard Lua bytecode decompiled via unluac."
            return False, "Failed to decompile standard Lua bytecode."
        else:
            ok = await cls.decompile_luau(file_path, out_path)
            if ok:
                return True, "Luau bytecode decompiled successfully."
            return False, "Failed to decompile Luau bytecode (both lifter and API failed)."
