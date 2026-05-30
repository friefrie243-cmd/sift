import os
import asyncio
from sift.core.detector import ObfuscatorDetector
from sift.core.ironbrew import IronBrewDeobfuscator
from sift.core.lune_runner import LuneRunner
from sift.core.decompiler import Decompiler
from sift.config import Config

class DeobfuscatorEngine:
    @classmethod
    async def deobfuscate(cls, code: str, mode: str = "auto") -> tuple[bool, str, str, str]:
        """
        Main entry point for deobfuscation.
        Returns (success, output_code, console_log, detected_type)
        """
        if mode == "auto" or not mode:
            detected_type = ObfuscatorDetector.detect(code)
        else:
            detected_type = mode

        console_log = f"[*] Detected Obfuscator: {detected_type}\n"
        output_code = ""
        success = False

        if detected_type == "IronBrew":
            # Attempt static IronBrew v2 deobfuscation first
            success, output_code, ib_log = IronBrewDeobfuscator.deobfuscate(code)
            console_log += ib_log
            
            if not success:
                # Fallback to dynamic logging
                console_log += "[*] Static deobfuscation failed. Falling back to dynamic Lune environment logger...\n"
                success, output_code, runner_log = await LuneRunner.run_lune_script("httplog2.lua", code)
                console_log += runner_log
                
        elif detected_type == "Luraph":
            console_log += "[*] Launching specialized Luraph dumper...\n"
            success, output_code, runner_log = await LuneRunner.run_lune_script("luraphdump.lua", code)
            console_log += runner_log
            
        elif detected_type in ["Moonsec", "Prometheus", "Moonveil", "Soteria", "WynnSfuscate"]:
            console_log += f"[*] Running dynamic Lune environment logging for {detected_type}...\n"
            success, output_code, runner_log = await LuneRunner.run_lune_script("httplog2.lua", code)
            console_log += runner_log
            
            if not success:
                console_log += "[*] Lune logger failed. Running Lua 5.3 fallback dumper...\n"
                success, output_code, dumper_log = await LuneRunner.run_lua_dumper(code)
                console_log += dumper_log
                
        elif detected_type == "Bytecode":
            # Bytecode decompile
            console_log += "[*] Bytecode detected. Launching decompiler...\n"
            import uuid
            job_id = str(uuid.uuid4())
            temp_in = os.path.join(Config.TEMP_DIR, f"bytecode_{job_id}.luac")
            temp_out = os.path.join(Config.TEMP_DIR, f"decompiled_{job_id}.lua")
            
            try:
                # Write binary
                with open(temp_in, "wb") as f:
                    # If user provided hex string, decode it, otherwise write string bytes
                    try:
                        f.write(bytes.fromhex(code.strip()))
                    except:
                        f.write(code.encode("utf-8", errors="ignore"))
                        
                ok, details = await Decompiler.decompile(temp_in, temp_out)
                console_log += f"{details}\n"
                if ok and os.path.exists(temp_out):
                    success = True
                    with open(temp_out, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
            except Exception as e:
                console_log += f"Decompilation Error: {str(e)}\n"
            finally:
                if os.path.exists(temp_in): os.remove(temp_in)
                if os.path.exists(temp_out): os.remove(temp_out)
                
        else:
            # Unknown, attempt general dynamic logger
            console_log += "[*] Obfuscator unknown. Attempting generic Lune environment logging...\n"
            success, output_code, runner_log = await LuneRunner.run_lune_script("httplog2.lua", code)
            console_log += runner_log
            
            if not success:
                console_log += "[*] Lune logger failed. Attempting fallback dumper...\n"
                success, output_code, dumper_log = await LuneRunner.run_lua_dumper(code)
                console_log += dumper_log

        # Ultimate fallback: If everything failed, extract all string literals statically
        if not success or not output_code.strip():
            console_log += "[!] All deobfuscators failed. Extracting strings/upvalues statically...\n"
            output_code = cls.extract_strings_statically(code)
            success = True # Return true since we extracted strings successfully

        return success, output_code, console_log, detected_type

    @staticmethod
    def extract_strings_statically(code: str) -> str:
        """
        Static string extraction fallback.
        """
        # Find all strings inside quotes
        strings = re.findall(r'"([A-Za-z0-9+/=\s\\._\-\[\]\(\)\{\}\:\;\,\!\?\@\#\$\%\^\&\*\+\-\/]*)"', code)
        strings += re.findall(r"'([A-Za-z0-9+/=\s\\._\-\[\]\(\)\{\}\:\;\,\!\?\@\#\$\%\^\&\*\+\-\/]*)'", code)
        
        unique_strings = sorted(list(set(strings)), key=len, reverse=True)
        
        output = "-- Sift Ultimate Fallback (Static String Dump)\n\n"
        output += "local strings = {\n"
        for i, s in enumerate(unique_strings[:1000]):  # Cap at 1000 strings
            if len(s.strip()) > 3:
                clean_s = s.replace('"', '\\"').replace('\n', '\\n')
                output += f"    [{i}] = \"{clean_s}\",\n"
        output += "}\n"
        return output
