import os
import subprocess
import asyncio
import shutil
import uuid
from sift.config import Config
from sift.core.decompiler import Decompiler

class LuneRunner:
    @staticmethod
    async def run_lune_script(script_name: str, input_code: str, output_suffix: str = ".lua") -> tuple[bool, str, str]:
        """
        Writes input_code to a temp file, runs the specified Lune script (e.g. httplog2.lua or luraphdump.lua),
        and returns (success, output_code, console_output).
        """
        job_id = str(uuid.uuid4())

        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"in_{job_id}{output_suffix}"

        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        output_path = os.path.join(Config.DUMPED_DIR, temp_output_name)

        # Write input file
        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        # Resolve script path — check multiple locations
        script_path = os.path.join("sift", "resources", script_name)
        if not os.path.exists(script_path):
            script_path = os.path.join("25ms", script_name)

        # Build command: lune run <script_path> <filename>
        cmd = [Config.LUNE_PATH, "run", script_path, temp_input_name]

        success = False
        console_log = ""
        output_code = ""

        try:
            # We set a hard timeout of 120 seconds to allow complex scripts more time
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=120.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if process.returncode == 0 or os.path.exists(output_path):
                    success = True
            except asyncio.TimeoutError:
                try:
                    process.kill()
                except:
                    pass
                console_log = "Execution timed out (120s limit exceeded). Infinite loop or anti-tamper detected."

            # If output file exists (even after timeout/error), try to read it
            if os.path.exists(output_path):
                with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                    output_code = f.read()
                # Accept partial output if it has meaningful content
                if len(output_code.strip()) > 0:
                    success = True

        except Exception as e:
            console_log += f"\nRunner Error: {str(e)}"
        finally:
            # Cleanup input file only — keep output for download
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass

        return success, output_code, console_log

    @staticmethod
    async def run_lua_dumper(input_code: str, key: str = "NoKey", place_id: str = "123456789") -> tuple[bool, str, str]:
        """
        Runs the Lua 5.3 dumper.lua fallback.
        """
        job_id = str(uuid.uuid4())

        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        # We write to temp dir
        os.makedirs(Config.TEMP_DIR, exist_ok=True)
        input_path = os.path.join(Config.TEMP_DIR, temp_input_name)
        output_path = os.path.join(Config.TEMP_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        dumper_path = os.path.join("sift", "resources", "dumper.lua")

        # Cross-platform check for lua interpreter
        lua_bin = shutil.which("lua5.3") or shutil.which("lua") or shutil.which("lua53") or "lua5.3"
        cmd = [lua_bin, dumper_path, input_path, output_path, key, place_id]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = "Dumper timed out."

        except Exception as e:
            console_log += f"\nDumper Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass
            # Keep output for potential download

        return success, output_code, console_log

    @staticmethod
    async def run_unveilr(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the UnveilR dumper (the-big-unveilr-v1-main/hi.luau) via Lune.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        output_path = os.path.join(Config.DUMPED_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        # Resolve script path (check workspace root, then nested subdirectory)
        script_dir = os.path.abspath("the-big-unveilr-v1-main")
        if not os.path.exists(script_dir):
            script_dir = os.path.abspath(os.path.join("dumper-and-env-loggers-main", "the-big-unveilr-v1-main"))
        script_path = os.path.join(script_dir, "hi.luau")

        cmd = [
            Config.LUNE_PATH,
            "run",
            script_path,
            "--",
            os.path.abspath(input_path),
            "--raw",
            f"--outfile={os.path.abspath(output_path)}"
        ]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=script_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = "UnveilR timed out."
        except Exception as e:
            console_log += f"\nUnveilR Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass
            # Keep output for download

        return success, output_code, console_log

    @staticmethod
    async def run_mimic(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the Mimic dumper (Mimic/main.luau) via Lune.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        output_path = os.path.join(Config.DUMPED_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        # Resolve script path (check workspace root, then nested subdirectory)
        script_dir = os.path.abspath("Mimic")
        if not os.path.exists(script_dir):
            script_dir = os.path.abspath(os.path.join("dumper-and-env-loggers-main", "Mimic"))
        script_path = os.path.join(script_dir, "main.luau")

        cmd = [
            Config.LUNE_PATH,
            "run",
            script_path,
            os.path.abspath(input_path),
            os.path.abspath(output_path)
        ]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=script_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = "Mimic timed out."
        except Exception as e:
            console_log += f"\nMimic Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass

        return success, output_code, console_log

    @staticmethod
    async def run_mimic2(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the Mimic2 dumper (Mimic2/main.luau) via Lune.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        output_path = os.path.join(Config.DUMPED_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        # Resolve script path (check workspace root, then nested subdirectory)
        script_dir = os.path.abspath("Mimic2")
        if not os.path.exists(script_dir):
            script_dir = os.path.abspath(os.path.join("dumper-and-env-loggers-main", "Mimic2"))
        script_path = os.path.join(script_dir, "main.luau")

        cmd = [
            Config.LUNE_PATH,
            "run",
            script_path,
            os.path.abspath(input_path),
            os.path.abspath(output_path)
        ]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=script_dir,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = "Mimic2 timed out."
        except Exception as e:
            console_log += f"\nMimic2 Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass

        return success, output_code, console_log

    @staticmethod
    async def run_lua_dumper_generic(script_name: str, input_code: str, key: str = "NoKey", place_id: str = "123456789") -> tuple[bool, str, str]:
        """
        Runs a Lua 5.3 dumper script with standard arguments.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        os.makedirs(Config.TEMP_DIR, exist_ok=True)
        input_path = os.path.join(Config.TEMP_DIR, temp_input_name)
        output_path = os.path.join(Config.TEMP_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        dumper_path = os.path.join("sift", "resources", script_name)
        lua_bin = shutil.which("lua5.3") or shutil.which("lua") or shutil.which("lua53") or "lua5.3"
        cmd = [lua_bin, dumper_path, input_path, output_path, key, place_id]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=120.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")
                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = f"{script_name} timed out."
                # Attempt to capture partial dump output if it was written before timeout
                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
        except Exception as e:
            console_log += f"\n{script_name} Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass
        return success, output_code, console_log

    @staticmethod
    async def run_lune_dumper_generic(script_name: str, input_code: str) -> tuple[bool, str, str]:
        """
        Runs a Lune dumper script with input and output paths.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        temp_output_name = f"out_{job_id}.lua"

        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        output_path = os.path.join(Config.DUMPED_DIR, temp_output_name)

        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)

        script_path = os.path.join("sift", "resources", script_name)
        cmd = [
            Config.LUNE_PATH,
            "run",
            script_path,
            os.path.abspath(input_path),
            os.path.abspath(output_path)
        ]

        success = False
        console_log = ""
        output_code = ""

        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=120.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")
                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = f"{script_name} timed out."
                # Still try to read output if it exists (partial dumps)
                if os.path.exists(output_path):
                    with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
        except Exception as e:
            console_log += f"\n{script_name} Error: {str(e)}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass
        return success, output_code, console_log

    @staticmethod
    async def run_zala(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("zala_dumper.lua", input_code)

    @staticmethod
    async def run_larry_premium(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_dumper_generic("larry_dumper.lua", input_code)

    @staticmethod
    async def run_larry_regular(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("larry_regular.lua", input_code)

    @staticmethod
    async def run_flame(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("flame_dumper.lua", input_code)

    @staticmethod
    async def run_polyester(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("polyester_dumper.lua", input_code)

    @staticmethod
    async def run_pengu(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("pengu_dumper.lua", input_code)

    @staticmethod
    async def run_kolenv(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("kolenv_dumper.lua", input_code)

    @staticmethod
    async def run_kolenv_new(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("kolenv_dumper_new.lua", input_code)

    @staticmethod
    async def run_httplog_25ms(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_script("httplog_25ms.lua", input_code)

    @staticmethod
    async def run_loadstringlog_25ms(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_script("loadstringlog_25ms.lua", input_code)

    @staticmethod
    async def run_45ms(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_dumper_generic("45ms_dumper.lua", input_code)

    @staticmethod
    async def run_revea(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the Revea dumper (message_1504352283192983645.lua) via Lune and captures stdout.
        """
        job_id = str(uuid.uuid4())
        temp_input_name = f"in_{job_id}.lua"
        input_path = os.path.join(Config.ORIGINAL_DIR, temp_input_name)
        
        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)
            
        script_path = os.path.join("sift", "resources", "revea_dumper.lua")
        cmd = [Config.LUNE_PATH, "run", script_path, os.path.abspath(input_path)]
        
        success = False
        console_log = ""
        output_code = ""
        try:
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=60.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")
                if process.returncode == 0:
                    success = True
                    output_code = console_log
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log = "Revea dumper timed out."
        except Exception as e:
            console_log = f"Error: {e}"
        finally:
            if os.path.exists(input_path):
                try: os.remove(input_path)
                except: pass
        return success, output_code, console_log

    @staticmethod
    async def run_moonsec(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the Moonsec deobfuscator (C# net8.0/net9.0) on the input code,
        and decompiles the resulting bytecode using Decompiler.decompile_lua.
        """
        job_id = str(uuid.uuid4())
        os.makedirs(Config.TEMP_DIR, exist_ok=True)
        
        temp_input_name = f"in_moonsec_{job_id}.lua"
        temp_output_name = f"out_moonsec_{job_id}.luac"
        temp_decompiled_name = f"decomp_moonsec_{job_id}.lua"
        
        input_path = os.path.join(Config.TEMP_DIR, temp_input_name)
        output_path = os.path.join(Config.TEMP_DIR, temp_output_name)
        decomp_path = os.path.join(Config.TEMP_DIR, temp_decompiled_name)
        
        console_log = "[*] Running Moonsec Deobfuscator...\n"
        
        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)
            
        # Select executable or dotnet dll based on platform
        is_windows = os.name == "nt"
        
        # Check workspace root bot directory, then package subdirectory, then absolute paths
        bot_base_dirs = [
            os.path.abspath("bot"),
            os.path.abspath(os.path.join("dumper-and-env-loggers-main", "bot")),
            os.path.abspath("/app/bot"),
            os.path.abspath("/app/dumper-and-env-loggers-main/bot"),
        ]
        
        bin_dir = None
        for bbd in bot_base_dirs:
            # Try net9.0 then net8.0
            for net_ver in ["net9.0", "net8.0"]:
                test_dir = os.path.join(bbd, "MoonsecDeobfuscator", "bin", "Release", net_ver)
                # Check for either the DLL or EXE inside
                if os.path.exists(test_dir):
                    dll_check = os.path.join(test_dir, "MoonsecDeobfuscator.dll")
                    exe_check = os.path.join(test_dir, "MoonsecDeobfuscator.exe")
                    if os.path.exists(dll_check) or os.path.exists(exe_check):
                        bin_dir = test_dir
                        break
            if bin_dir:
                break
                
        if not bin_dir:
            # Default fallback search directory
            bin_dir = os.path.abspath(os.path.join("bot", "MoonsecDeobfuscator", "bin", "Release", "net8.0"))
            console_log += f"[!] Warning: Could not locate Moonsec binary release directory. Defaulting to: {bin_dir}\n"
        else:
            console_log += f"[*] Located Moonsec binary release directory: {bin_dir}\n"
            
        # Ensure unluac.jar is copied to deobfuscate/unluac.jar if it exists in bot directory
        for bbd in bot_base_dirs:
            src_jar = os.path.join(bbd, "unluac.jar")
            if os.path.exists(src_jar):
                dest_jar = os.path.abspath(Config.UNLUAC_JAR_PATH)
                os.makedirs(os.path.dirname(dest_jar), exist_ok=True)
                if not os.path.exists(dest_jar) or os.path.getsize(src_jar) != os.path.getsize(dest_jar):
                    try:
                        shutil.copy(src_jar, dest_jar)
                        console_log += f"[*] Copied unluac.jar to {dest_jar}\n"
                    except Exception as jar_err:
                        console_log += f"[!] Failed to copy unluac.jar: {jar_err}\n"
                break
            
        success = False
        output_code = ""
        
        try:
            if is_windows:
                exe_path = os.path.join(bin_dir, "MoonsecDeobfuscator.exe")
                if not os.path.exists(exe_path):
                    # Check DLL format on windows if EXE is missing
                    dll_path = os.path.join(bin_dir, "MoonsecDeobfuscator.dll")
                    if os.path.exists(dll_path):
                        cmd = ["dotnet", dll_path, "-dev", "-i", input_path, "-o", output_path]
                    else:
                        raise FileNotFoundError(f"Moonsec binary not found in {bin_dir} (EXE/DLL missing)")
                else:
                    cmd = [exe_path, "-dev", "-i", input_path, "-o", output_path]
            else:
                dll_path = os.path.join(bin_dir, "MoonsecDeobfuscator.dll")
                if not os.path.exists(dll_path):
                    # Try net8.0 DLL if Net9.0 was selected but DLL is missing
                    alt_bin_dir = bin_dir.replace("net9.0", "net8.0")
                    alt_dll_path = os.path.join(alt_bin_dir, "MoonsecDeobfuscator.dll")
                    if os.path.exists(alt_dll_path):
                        dll_path = alt_dll_path
                    else:
                        raise FileNotFoundError(f"Moonsec dll not found in {bin_dir} or {alt_bin_dir}")
                cmd = ["dotnet", dll_path, "-dev", "-i", input_path, "-o", output_path]
                
            console_log += f"[*] Command: {' '.join(cmd)}\n"
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=120.0)
                console_log += stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log += "Moonsec deobfuscator execution timed out.\n"
                
            if os.path.exists(output_path):
                console_log += "[+] Moonsec successfully devirtualized code. Decompiling bytecode...\n"
                ok, decomp_details = await Decompiler.decompile(output_path, decomp_path, is_luau=False)
                console_log += f"Decompiler details: {decomp_details}\n"
                if ok and os.path.exists(decomp_path):
                    with open(decomp_path, "r", encoding="utf-8", errors="ignore") as f:
                        output_code = f.read()
                    if len(output_code.strip()) > 0:
                        success = True
                else:
                    console_log += "[-] Failed to decompile devirtualized bytecode.\n"
            else:
                console_log += "[-] Moonsec deobfuscator failed to generate bytecode output.\n"
                
        except Exception as e:
            console_log += f"\nMoonsec Runner Error: {str(e)}"
        finally:
            # Cleanup temp files
            for p in [input_path, output_path, decomp_path]:
                if os.path.exists(p):
                    try: os.remove(p)
                    except: pass
                    
        return success, output_code, console_log

    @staticmethod
    async def run_prometheus(input_code: str) -> tuple[bool, str, str]:
        """
        Runs the Prometheus deobfuscator wrapper (bot/PrometheusDumper/deobfuscator.py) on the input code.
        """
        import sys
        job_id = str(uuid.uuid4())
        
        # We need a temp folder inside Config.TEMP_DIR for this job
        job_dir = os.path.join(Config.TEMP_DIR, f"prometheus_{job_id}")
        os.makedirs(job_dir, exist_ok=True)
        
        input_path = os.path.join(job_dir, "script.lua")
        output_path = os.path.join(job_dir, "script.deobf.lua")
        
        with open(input_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(input_code)
            
        deob_script = os.path.abspath(os.path.join("bot", "PrometheusDumper", "deobfuscator.py"))
        # fallback path checks
        if not os.path.exists(deob_script):
            deob_script = os.path.abspath(os.path.join("dumper-and-env-loggers-main", "bot", "PrometheusDumper", "deobfuscator.py"))
            
        success = False
        console_log = "[*] Running Prometheus/WeAreDevs Deobfuscator...\n"
        output_code = ""
        
        cmd = [sys.executable, deob_script, os.path.abspath(input_path)]
        
        try:
            # Run in the Prometheus dumper folder as working directory
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=os.path.dirname(deob_script),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=120.0)
                console_log += stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")
            except asyncio.TimeoutError:
                try: process.kill()
                except: pass
                console_log += "Prometheus execution timed out.\n"
                
            if os.path.exists(output_path):
                with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                    output_code = f.read()
                if len(output_code.strip()) > 0:
                    success = True
            else:
                # Check for script.lua.report.txt or similar trace files and compile them
                report_path = os.path.join(job_dir, "script.lua.report.txt")
                alt_report_path = os.path.join(os.path.dirname(deob_script), "temp_deob.lua.report.txt")
                
                selected_report = None
                if os.path.exists(report_path):
                    selected_report = report_path
                elif os.path.exists(alt_report_path):
                    selected_report = alt_report_path
                    
                if selected_report:
                    console_log += f"[+] Prometheus report found at {selected_report}. Invoking trace converter...\n"
                    try:
                        import importlib
                        sys.path.append(os.path.dirname(deob_script))
                        trace_to_lua = importlib.import_module("trace_to_lua")
                        trace_to_lua.parse_trace(selected_report)
                        
                        generated_deobf = selected_report.replace(".report.txt", ".deobf.lua")
                        if os.path.exists(generated_deobf):
                            with open(generated_deobf, "r", encoding="utf-8", errors="ignore") as f:
                                output_code = f.read()
                            if len(output_code.strip()) > 0:
                                success = True
                                console_log += "[+] Successfully converted raw execution trace to Lua!\n"
                    except Exception as trace_err:
                        console_log += f"[!] Trace converter error: {trace_err}\n"
                
                if not success:
                    console_log += "[-] Prometheus deobfuscator did not produce deobf output.\n"
                
        except Exception as e:
            console_log += f"\nPrometheus Runner Error: {str(e)}"
        finally:
            # Cleanup temp directory
            shutil.rmtree(job_dir, ignore_errors=True)
            
        return success, output_code, console_log



