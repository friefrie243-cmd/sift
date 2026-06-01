import os
import re
import asyncio
from sift.core.detector import ObfuscatorDetector
from sift.core.ironbrew import IronBrewDeobfuscator
from sift.core.lune_runner import LuneRunner
from sift.core.decompiler import Decompiler
from sift.config import Config

def score_output(code: str) -> int:
    """
    Score the output code based on the number of meaningful Lua code lines.
    Excludes comments, blank lines, and debug/spy prefix lines.
    """
    if not code:
        return 0
    score = 0
    debug_prefixes = (
        "[ Spy ",
        "[mimic-debug]",
        "[VOID]",
        "[*] ",
        "[-] ",
        "[+] ",
        "[!] "
    )
    in_multiline_comment = False
    
    for line in code.splitlines():
        line_strip = line.strip()
        if not line_strip:
            continue
            
        # Check multiline comment start/end
        if in_multiline_comment:
            if "]]" in line_strip:
                in_multiline_comment = False
            continue
        else:
            if line_strip.startswith("--[["):
                in_multiline_comment = True
                continue
            if line_strip.startswith("--"):
                continue
                
        # Exclude debug/spy/verbose logging lines
        is_debug = False
        for prefix in debug_prefixes:
            if line_strip.startswith(prefix):
                is_debug = True
                break
        if is_debug:
            continue
            
        score += 1
    return score

def clean_output(code: str) -> str:
    """
    Clean the output code by removing debug/spy prefix lines and trailing error lines.
    """
    if not code:
        return ""
    cleaned_lines = []
    debug_prefixes = (
        "[ Spy ",
        "[mimic-debug]",
        "[VOID]"
    )
    error_patterns = [
        r'^error\s*\(',
        r'^local\s+_callerror\d+\s*=\s*error\(',
        r'^local\s+er\s*=\s*error\(',
    ]
    for line in code.splitlines():
        line_strip = line.strip()
        is_debug = False
        for prefix in debug_prefixes:
            if line_strip.startswith(prefix):
                is_debug = True
                break
        if is_debug:
            continue
        # Skip error() calls that are tamper detection artifacts
        is_error = False
        for pattern in error_patterns:
            if re.match(pattern, line_strip):
                is_error = True
                break
        if is_error:
            continue
        cleaned_lines.append(line)
    
    # Strip trailing empty lines and error comments from the end
    while cleaned_lines and (
        not cleaned_lines[-1].strip() or 
        cleaned_lines[-1].strip().startswith("-- Execution halted") or
        cleaned_lines[-1].strip().startswith("-- error:") or
        "Too many operations" in cleaned_lines[-1] or
        "Tamper Detected" in cleaned_lines[-1] or
        "infinitelooperror" in cleaned_lines[-1].lower()
    ):
        cleaned_lines.pop()
    
    return "\n".join(cleaned_lines)

def is_valid_lua_output(code: str) -> bool:
    """
    Validates that the output is usable Lua code.
    Now accepts partial outputs with meaningful code lines.
    """
    if not code or not code.strip():
        return False
    
    # Reject ONLY the static fallback header — everything else gets a chance
    if code.startswith("-- Sift Ultimate Fallback"):
        return False
    
    # Count meaningful lines
    meaningful = score_output(code)
    
    # Accept if there are at least 2 meaningful code lines
    # This allows partial deobfuscations to be used
    if meaningful >= 2:
        return True
    
    return False


class DeobfuscatorEngine:
    @classmethod
    async def run_all_dynamic_loggers(cls, code: str, console_log: str, include_loggers: bool = False) -> tuple[bool, str, str]:
        """
        Runs available Lune and Lua environment loggers/dumpers SEQUENTIALLY,
        with early-exit once a high-quality output is found.
        Logs progress and selects the best output.
        """
        all_methods = [
            ("Mimic", lambda c: LuneRunner.run_mimic(c)),
            ("Mimic2", lambda c: LuneRunner.run_mimic2(c)),
            ("UnveilR", lambda c: LuneRunner.run_unveilr(c)),
            ("Revea.lol", lambda c: LuneRunner.run_revea(c)),
            ("Old-45ms", lambda c: LuneRunner.run_45ms(c)),
            ("FlameCoderV3", lambda c: LuneRunner.run_flame(c)),
            ("Polyester", lambda c: LuneRunner.run_polyester(c)),
            ("PenguEnv", lambda c: LuneRunner.run_pengu(c)),
            ("Zala Dumper", lambda c: LuneRunner.run_zala(c)),
            ("Larry Premium", lambda c: LuneRunner.run_larry_premium(c)),
            ("Larry Regular", lambda c: LuneRunner.run_larry_regular(c)),
            ("Kolenv Dumper", lambda c: LuneRunner.run_kolenv(c)),
            ("Kolenv Dumper (New)", lambda c: LuneRunner.run_kolenv_new(c)),
            ("Lune httplog2", lambda c: LuneRunner.run_lune_script("httplog2.lua", c)),
            ("25ms HttpLog", lambda c: LuneRunner.run_httplog_25ms(c)),
            ("25ms LoadstringLog", lambda c: LuneRunner.run_loadstringlog_25ms(c)),
            ("Lua 5.3 Fallback", lambda c: LuneRunner.run_lua_dumper(c))
        ]

        trace_logger_names = {"Lune httplog2", "25ms HttpLog", "25ms LoadstringLog"}
        methods = [m for m in all_methods if include_loggers or m[0] not in trace_logger_names]

        success_outputs = []
        for name, run_func in methods:
            console_log += f"[*] Running {name}...\n"
            try:
                ok, out, log = await run_func(code)
                # Keep console logs concise in the output panel
                lines = log.splitlines() if log else []
                if len(lines) > 20:
                    concise_log = "\n".join(lines[:10]) + f"\n... [Truncated {len(lines)-20} lines of console output] ...\n" + "\n".join(lines[-10:])
                else:
                    concise_log = log or ""
                console_log += concise_log + "\n"
                
                if ok and is_valid_lua_output(out):
                    output_score = score_output(out)
                    success_outputs.append((name, out, output_score))
                    console_log += f"[+] {name} succeeded ({len(out.splitlines())} lines, score: {output_score}).\n"
                    
                    # Early exit if we got a high-quality output (>50 meaningful lines)
                    if output_score > 50:
                        console_log += f"[+] High-quality output from {name} — skipping remaining engines.\n"
                        break
                else:
                    console_log += f"[-] {name} failed or returned empty/invalid output.\n"
            except Exception as e:
                console_log += f"[!] {name} failed with error: {str(e)}\n"

        if success_outputs:
            # Prioritize dumpers over trace loggers, then sort by score
            dumpers = [x for x in success_outputs if x[0] not in trace_logger_names]
            loggers = [x for x in success_outputs if x[0] in trace_logger_names]
            if dumpers:
                dumpers.sort(key=lambda x: x[2], reverse=True)
                best_name, best_out, _ = dumpers[0]
            else:
                loggers.sort(key=lambda x: x[2], reverse=True)
                best_name, best_out, _ = loggers[0]
            
            best_out_clean = clean_output(best_out)
            console_log += f"[+] Selected best output from {best_name}.\n"
            return True, best_out_clean, console_log
        else:
            console_log += "[!] All dynamic environment loggers/dumpers failed.\n"
            return False, "", console_log

    @classmethod
    async def run_all_deobfuscators_concurrently(cls, code: str, include_loggers: bool = False) -> tuple[bool, str, str, list]:
        """
        Runs all available deobfuscators concurrently via asyncio.gather and returns
        (success, best_output, console_log, all_outputs_list).
        """
        all_methods = [
            ("IronBrew (Static)", lambda c: asyncio.to_thread(IronBrewDeobfuscator.deobfuscate, c)),
            ("Luraph Dumper", lambda c: LuneRunner.run_lune_script("luraphdump.lua", c)),
            ("Mimic", lambda c: LuneRunner.run_mimic(c)),
            ("Mimic2", lambda c: LuneRunner.run_mimic2(c)),
            ("UnveilR", lambda c: LuneRunner.run_unveilr(c)),
            ("Revea.lol", lambda c: LuneRunner.run_revea(c)),
            ("Old-45ms", lambda c: LuneRunner.run_45ms(c)),
            ("FlameCoderV3", lambda c: LuneRunner.run_flame(c)),
            ("Polyester", lambda c: LuneRunner.run_polyester(c)),
            ("PenguEnv", lambda c: LuneRunner.run_pengu(c)),
            ("Zala Dumper", lambda c: LuneRunner.run_zala(c)),
            ("Larry Premium", lambda c: LuneRunner.run_larry_premium(c)),
            ("Larry Regular", lambda c: LuneRunner.run_larry_regular(c)),
            ("Kolenv Dumper", lambda c: LuneRunner.run_kolenv(c)),
            ("Kolenv Dumper (New)", lambda c: LuneRunner.run_kolenv_new(c)),
            ("Lune httplog2", lambda c: LuneRunner.run_lune_script("httplog2.lua", c)),
            ("25ms HttpLog", lambda c: LuneRunner.run_httplog_25ms(c)),
            ("25ms LoadstringLog", lambda c: LuneRunner.run_loadstringlog_25ms(c)),
            ("Lua 5.3 Fallback", lambda c: LuneRunner.run_lua_dumper(c))
        ]

        trace_logger_names = {"Lune httplog2", "25ms HttpLog", "25ms LoadstringLog"}
        methods = [m for m in all_methods if include_loggers or m[0] not in trace_logger_names]

        async def run_method(name, func):
            try:
                res = await func(code)
                ok = res[0]
                out = res[1]
                log = res[2] if len(res) > 2 else ""
                
                is_valid = bool(ok and is_valid_lua_output(out))
                return {
                    "name": name,
                    "success": is_valid,
                    "output_code": out if is_valid else "",
                    "console_log": log
                }
            except Exception as e:
                return {
                    "name": name,
                    "success": False,
                    "output_code": "",
                    "console_log": f"Error: {str(e)}"
                }

        results = await asyncio.gather(*[run_method(name, func) for name, func in methods])
        
        # Compile successful outputs
        successful = [r for r in results if r["success"]]
        
        # Sort successful outputs: prioritize dumpers over trace loggers, then sort by score descending
        def sort_key(item):
            is_dumper = item["name"] not in trace_logger_names
            return (1 if is_dumper else 0, score_output(item["output_code"]))
        
        successful.sort(key=sort_key, reverse=True)
        
        all_outputs_list = [
            {
                "name": r["name"],
                "output_code": clean_output(r["output_code"]),
                "console_log": r["console_log"]
            }
            for r in successful
        ]
        
        console_log = "[*] Running all deobfuscators concurrently...\n"
        for r in results:
            lines = r["console_log"].splitlines() if r["console_log"] else []
            if len(lines) > 20:
                concise_log = "\n".join(lines[:10]) + f"\n... [Truncated {len(lines)-20} lines of console output] ...\n" + "\n".join(lines[-10:])
            else:
                concise_log = r["console_log"] or ""
            console_log += f"--- {r['name']} Log ---\n{concise_log}\n"
            if r["success"]:
                console_log += f"[+] {r['name']} succeeded ({len(r['output_code'].splitlines())} lines).\n\n"
            else:
                console_log += f"[-] {r['name']} failed or returned empty/invalid output.\n\n"

        if successful:
            best = successful[0]
            best_clean = clean_output(best["output_code"])
            console_log += f"[+] Selected best output from {best['name']}.\n"
            return True, best_clean, console_log, all_outputs_list
        else:
            console_log += "[!] All deobfuscators failed. Extracting strings/upvalues statically...\n"
            output_code = cls.extract_strings_statically(code)
            all_outputs_list = [{
                "name": "Static String Extraction (Fallback)",
                "output_code": output_code,
                "console_log": "All engines failed. Performed static analysis."
            }]
            return True, output_code, console_log, all_outputs_list

    @classmethod
    async def deobfuscate(cls, code: str, mode: str = "auto", all_outputs: bool = False, include_loggers: bool = False) -> tuple[bool, str, str, str, list]:
        """
        Main entry point for deobfuscation.
        Returns (success, output_code, console_log, detected_type, all_outputs_list)
        """
        if mode == "auto" or not mode:
            detected_type = ObfuscatorDetector.detect(code)
        else:
            detected_type = mode

        # If user explicitly requested multi-engine deobfuscation
        if all_outputs:
            success, output_code, console_log, all_outputs_list = await cls.run_all_deobfuscators_concurrently(code, include_loggers)
            return success, output_code, console_log, detected_type, all_outputs_list

        console_log = f"[*] Detected Obfuscator: {detected_type}\n"
        output_code = ""
        success = False
        all_outputs_list = []

        if detected_type == "IronBrew":
            success, output_code, ib_log = IronBrewDeobfuscator.deobfuscate(code)
            console_log += ib_log
            if not success:
                if include_loggers:
                    console_log += "[*] Static deobfuscation failed. Falling back to dynamic Lune environment logger...\n"
                    success, output_code, runner_log = await LuneRunner.run_lune_script("httplog2.lua", code)
                    console_log += runner_log
                else:
                    console_log += "[*] Static deobfuscation failed and trace loggers disabled. Falling back to dynamic dumpers...\n"
                    success, output_code, console_log = await cls.run_all_dynamic_loggers(code, console_log, include_loggers)
                
        elif detected_type == "Luraph":
            console_log += "[*] Launching specialized Luraph dumper...\n"
            success, output_code, runner_log = await LuneRunner.run_lune_script("luraphdump.lua", code)
            console_log += runner_log
            
        elif detected_type in ["Moonsec", "Prometheus", "Moonveil", "Soteria", "WynnSfuscate"]:
            console_log += f"[*] Launching dynamic deobfuscation chain for {detected_type}...\n"
            success, output_code, console_log = await cls.run_all_dynamic_loggers(code, console_log, include_loggers)
            
        elif detected_type == "Bytecode":
            console_log += "[*] Bytecode detected. Launching decompiler...\n"
            import uuid
            job_id = str(uuid.uuid4())
            temp_in = os.path.join(Config.TEMP_DIR, f"bytecode_{job_id}.luac")
            temp_out = os.path.join(Config.TEMP_DIR, f"decompiled_{job_id}.lua")
            
            try:
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
            console_log += "[*] Obfuscator unknown. Launching dynamic deobfuscation chain...\n"
            success, output_code, console_log = await cls.run_all_dynamic_loggers(code, console_log, include_loggers)

        if not success or not output_code.strip():
            console_log += "[!] All deobfuscators failed. Extracting strings/upvalues statically...\n"
            output_code = cls.extract_strings_statically(code)
            success = True

        # For single output mode, all_outputs_list just contains the selected best output
        if success and output_code.strip():
            all_outputs_list = [{
                "name": detected_type if detected_type != "Unknown/None" else "Sift Output",
                "output_code": output_code,
                "console_log": console_log
            }]

        return success, output_code, console_log, detected_type, all_outputs_list

    @staticmethod
    def extract_strings_statically(code: str) -> str:
        """
        Improved static string extraction fallback.
        Decodes octal/decimal escape sequences and extracts readable strings.
        """
        # Extract quoted strings
        strings = re.findall(r'"([^"]*)"', code)
        strings += re.findall(r"'([^']*)'", code)
        
        decoded_strings = []
        for s in strings:
            if len(s.strip()) < 3:
                continue
            
            # Decode octal/decimal escape sequences like \051\101\049
            if re.search(r'\\(\d{1,3})', s):
                try:
                    decoded = re.sub(
                        r'\\(\d{1,3})',
                        lambda m: chr(int(m.group(1))) if int(m.group(1)) < 256 else m.group(0),
                        s
                    )
                    # Only use decoded version if it has printable content
                    if decoded and any(32 <= ord(c) < 127 for c in decoded):
                        decoded_strings.append(decoded)
                        continue
                except:
                    pass
            
            # Filter for strings with meaningful content
            if any(c.isalpha() for c in s) or len(s) > 10:
                decoded_strings.append(s)
        
        # Deduplicate and sort by length (longest first — usually most meaningful)
        unique_strings = sorted(list(set(decoded_strings)), key=len, reverse=True)
        
        output = "-- Sift Ultimate Fallback (Static String Dump)\n"
        output += "-- Strings extracted and decoded from the obfuscated script\n\n"
        output += "local strings = {\n"
        for i, s in enumerate(unique_strings[:1000]):
            clean_s = s.replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r')
            output += f'    [{i}] = "{clean_s}",\n'
        output += "}\n"
        return output
