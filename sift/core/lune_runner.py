import os
import subprocess
import asyncio
import shutil
import uuid
from sift.config import Config

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
            # We set a hard timeout of 30 seconds to prevent infinite loops in env loggers
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            try:
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30.0)
                console_log = stdout.decode("utf-8", errors="ignore") + "\n" + stderr.decode("utf-8", errors="ignore")

                if process.returncode == 0 or os.path.exists(output_path):
                    success = True
            except asyncio.TimeoutError:
                try:
                    process.kill()
                except:
                    pass
                console_log = "Execution timed out (30s limit exceeded). Infinite loop or anti-tamper detected."

            # If successful or output file exists, read it
            if os.path.exists(output_path):
                with open(output_path, "r", encoding="utf-8", errors="ignore") as f:
                    output_code = f.read()

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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
                stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=35.0)
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
        return await LuneRunner.run_lua_dumper_generic("larry_dumper.lua", input_code)

    @staticmethod
    async def run_larry_regular(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lua_dumper_generic("larry_regular.lua", input_code)

    @staticmethod
    async def run_flame(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_dumper_generic("flame_dumper.lua", input_code)

    @staticmethod
    async def run_polyester(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_dumper_generic("polyester_dumper.lua", input_code)

    @staticmethod
    async def run_pengu(input_code: str) -> tuple[bool, str, str]:
        return await LuneRunner.run_lune_dumper_generic("pengu_dumper.lua", input_code)

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

