import os
import re
import asyncio
from sift.core.detector import ObfuscatorDetector
from sift.core.ironbrew import IronBrewDeobfuscator
from sift.core.lune_runner import LuneRunner
from sift.core.decompiler import Decompiler
from sift.config import Config

class DeobfuscatorEngine:
    @classmethod
    async def run_all_dynamic_loggers(cls, code: str, console_log: str) -> tuple[bool, str, str]:
        """
        Runs all available Lune and Lua environment loggers/dumpers in sequence,
        logs their progress, and selects the most complete/longest deobfuscated output.
        """
        methods = [
            ("Lune httplog2", lambda c: LuneRunner.run_lune_script("httplog2.lua", c)),
            ("UnveilR", lambda c: LuneRunner.run_unveilr(c)),
            ("Mimic", lambda c: LuneRunner.run_mimic(c)),
            ("Mimic2", lambda c: LuneRunner.run_mimic2(c)),
            ("Lua 5.3 Fallback", lambda c: LuneRunner.run_lua_dumper(c))
        ]

        success_outputs = []
        for name, run_func in methods:
            console_log += f"[*] Running {name}...\n"
            try:
                ok, out, log = await run_func(code)
                # Keep console log logs concise in the output panel
                lines = log.splitlines() if log else []
                if len(lines) > 20:
                    concise_log = "\n".join(lines[:10]) + f"\n... [Truncated {len(lines)-20} lines of console output] ...\n" + "\n".join(lines[-10:])
                else:
                    concise_log = log or ""
                console_log += concise_log + "\n"
                
                # Check if it succeeded and returned actual decompiled/deobfuscated Lua code,
                # not just the static string extraction header or nothing.
                if ok and out.strip() and not out.startswith("-- Sift Ultimate Fallback"):
                    success_outputs.append((name, out))
                    console_log += f"[+] {name} succeeded ({len(out.splitlines())} lines).\n"
                else:
                    console_log += f"[-] {name} failed or returned empty/fallback.\n"
            except Exception as e:
                console_log += f"[!] {name} failed with error: {str(e)}\n"

        if success_outputs:
            # Sort by output length descending to pick the most complete dump
            success_outputs.sort(key=lambda x: len(x[1]), reverse=True)
            best_name, best_out = success_outputs[0]
            console_log += f"[+] Selected best output from {best_name}.\n"
            return True, best_out, console_log
        else:
            console_log += "[!] All dynamic environment loggers/dumpers failed.\n"
            return False, "", console_log

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
            console_log += f"[*] Launching dynamic deobfuscation chain for {detected_type}...\n"
            success, output_code, console_log = await cls.run_all_dynamic_loggers(code, console_log)
            
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
            # Unknown, attempt general dynamic logger chain
            console_log += "[*] Obfuscator unknown. Launching dynamic deobfuscation chain...\n"
            success, output_code, console_log = await cls.run_all_dynamic_loggers(code, console_log)

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
