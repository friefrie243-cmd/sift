import os
import subprocess
import asyncio
import base64
import struct
import aiohttp
from sift.config import Config

class Decompiler:
    # Known Luau bytecode version ranges
    LUAU_VERSIONS = list(range(2, 7))  # v2-v6 commonly supported
    
    @staticmethod
    def detect_bytecode_version(file_path: str) -> tuple[str, int]:
        """
        Reads the bytecode header to detect the type and version.
        Returns (type, version) where type is 'lua51', 'lua52', 'lua53', 'lua54', 'luajit', 'luau', or 'unknown'.
        """
        try:
            with open(file_path, "rb") as f:
                header = f.read(8)
            
            if len(header) < 4:
                return "unknown", 0
            
            # Standard Lua: \x1bLua followed by version byte
            if header[:4] == b"\x1bLua":
                version_byte = header[4] if len(header) > 4 else 0
                if version_byte == 0x51:
                    return "lua51", 0x51
                elif version_byte == 0x52:
                    return "lua52", 0x52
                elif version_byte == 0x53:
                    return "lua53", 0x53
                elif version_byte == 0x54:
                    return "lua54", 0x54
                else:
                    return "lua_unknown", version_byte
            
            # LuaJIT: starts with \x1b\x4c\x4a
            if header[:3] == b"\x1bLJ":
                version = header[3] if len(header) > 3 else 0
                return "luajit", version
            
            # Luau bytecode: version byte is typically the first byte
            # Luau bytecode versions range from 2 to 6+ and start with the version number
            first_byte = header[0]
            if 2 <= first_byte <= 100:  # Reasonable Luau version range
                return "luau", first_byte
            
            return "unknown", 0
        except Exception:
            return "unknown", 0

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
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
            if process.returncode == 0 and os.path.exists(out_path):
                return True
        except Exception as e:
            print(f"Error in decompile_lua: {e}")
        return False

    @staticmethod
    async def decompile_luau(file_path: str, out_path: str) -> bool:
        """
        Decompiles Roblox Luau bytecode using luau-lifter.exe, with multi-API fallbacks.
        Supports all bytecode versions including newer ones (v45+).
        """
        lifter_path = Config.LUAU_LIFTER_PATH
        if not os.path.exists(lifter_path):
            lifter_path = "./medal51/luau-lifter.exe"
            if not os.path.exists(lifter_path):
                lifter_path = "../medal51/luau-lifter.exe"

        success = False
        
        # Try 1: Local luau-lifter binary
        if os.path.exists(lifter_path):
            try:
                process = await asyncio.create_subprocess_exec(
                    lifter_path, file_path, "-e",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
                if not stderr or process.returncode == 0:
                    output = stdout.decode('utf-8', errors='ignore')
                    if output.strip() and "unhandled" not in output.lower():
                        with open(out_path, 'w', encoding='utf-8') as f:
                            f.write(output)
                        success = True
            except Exception as e:
                print(f"Error running luau-lifter: {e}")

        # Try 2: api.lua.expert API
        if not success:
            try:
                with open(file_path, "rb") as f:
                    content = f.read()
                
                async with aiohttp.ClientSession() as session:
                    headers = {"Content-Type": "application/json"}
                    payload = {"script": base64.b64encode(content).decode()}
                    async with session.post(
                        "https://api.lua.expert/decompile", 
                        json=payload, 
                        headers=headers,
                        timeout=aiohttp.ClientTimeout(total=30)
                    ) as response:
                        if response.status == 200:
                            result_text = await response.text()
                            if result_text.strip() and "unhandled" not in result_text.lower() and "error" not in result_text[:50].lower():
                                with open(out_path, "w", encoding="utf-8") as f:
                                    f.write(result_text)
                                success = True
                            else:
                                print(f"lua.expert returned unusable result: {result_text[:200]}")
            except Exception as e:
                print(f"Decompilation API (lua.expert) fallback error: {e}")

        # Try 3: unluau.xyz API (supports newer bytecode versions)
        if not success:
            try:
                with open(file_path, "rb") as f:
                    content = f.read()
                
                async with aiohttp.ClientSession() as session:
                    headers = {"Content-Type": "application/octet-stream"}
                    async with session.post(
                        "https://unluau.xyz/api/decompile",
                        data=content,
                        headers=headers,
                        timeout=aiohttp.ClientTimeout(total=30)
                    ) as response:
                        if response.status == 200:
                            result = await response.json()
                            decompiled = result.get("output", result.get("result", ""))
                            if decompiled and len(decompiled.strip()) > 10:
                                with open(out_path, "w", encoding="utf-8") as f:
                                    f.write(decompiled)
                                success = True
            except Exception as e:
                print(f"Decompilation API (unluau.xyz) fallback error: {e}")

        # Try 4: Direct Luau built-in decompiler via lune (if available)
        if not success:
            try:
                lune_path = Config.LUNE_PATH
                # Create a small lune script that reads and decompiles bytecode
                decompile_script = f"""
local fs = require("@lune/fs")
local process = require("@lune/process")
local content = fs.readFile("{file_path.replace(os.sep, '/')}")
-- Try to use luau.compile in reverse if possible
process.exit(1)
"""
                # This is a placeholder — Lune doesn't have native decompile
                # But we try the lifter one more time with different args
                if os.path.exists(lifter_path):
                    process = await asyncio.create_subprocess_exec(
                        lifter_path, file_path,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE
                    )
                    stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
                    output = stdout.decode('utf-8', errors='ignore')
                    if output.strip() and len(output.strip()) > 20:
                        with open(out_path, 'w', encoding='utf-8') as f:
                            f.write(output)
                        success = True
            except Exception as e:
                print(f"Alternative decompilation fallback error: {e}")

        return success

    @classmethod
    async def decompile(cls, file_path: str, out_path: str, is_luau: bool = True) -> tuple[bool, str]:
        """
        Selects appropriate decompiler based on detected bytecode type and version.
        Returns (success, details).
        """
        if not os.path.exists(file_path):
            return False, "Input file does not exist."

        # Detect bytecode type and version
        bc_type, bc_version = cls.detect_bytecode_version(file_path)
        
        if bc_type.startswith("lua5") or bc_type == "lua_unknown":
            # Standard Lua bytecode
            ok = await cls.decompile_lua(file_path, out_path)
            if ok:
                return True, f"Standard Lua bytecode (v{bc_version}) decompiled via unluac."
            # Fallback to Luau decompiler APIs
            ok = await cls.decompile_luau(file_path, out_path)
            if ok:
                return True, f"Standard Lua bytecode decompiled via API fallback."
            return False, f"Failed to decompile standard Lua bytecode (version {bc_version})."
        
        elif bc_type == "luajit":
            # LuaJIT bytecode — try unluac first, then APIs
            ok = await cls.decompile_lua(file_path, out_path)
            if ok:
                return True, "LuaJIT bytecode decompiled via unluac."
            ok = await cls.decompile_luau(file_path, out_path)
            if ok:
                return True, "LuaJIT bytecode decompiled via API fallback."
            return False, f"Failed to decompile LuaJIT bytecode (version {bc_version})."
        
        elif bc_type == "luau":
            # Luau bytecode — use multi-fallback decompiler
            ok = await cls.decompile_luau(file_path, out_path)
            if ok:
                return True, f"Luau bytecode (version {bc_version}) decompiled successfully."
            return False, f"Failed to decompile Luau bytecode (version {bc_version}). All decompilers and APIs tried."
        
        else:
            # Unknown — try both paths
            # First try standard Lua header check
            with open(file_path, "rb") as f:
                header = f.read(4)
            
            is_lua_standard = (header == b"\x1bLua")
            
            if is_lua_standard:
                ok = await cls.decompile_lua(file_path, out_path)
                if ok:
                    return True, "Standard Lua bytecode decompiled via unluac."
            
            # Try Luau decompiler with all fallbacks
            ok = await cls.decompile_luau(file_path, out_path)
            if ok:
                return True, "Bytecode decompiled successfully via API."
            
            return False, f"Failed to decompile bytecode (unknown type, version byte: {bc_version}). All decompilers tried."
