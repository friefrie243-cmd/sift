# bot.py

import discord
from discord.ext import commands
import asyncio
import tempfile
import os
import shutil
import sys
from dotenv import load_dotenv


load_dotenv()
TOKEN = os.getenv("DISCORD_TOKEN")

PREFIX = "!"


BASE_DIR = os.path.dirname(os.path.abspath(__file__))

MOONSEC_DEOB_EXE = r"MoonsecDeobfuscator\bin\Release\net8.0\MoonsecDeobfuscator.exe"
UNLUAC_JAR = "unluac.jar"

WEAREDEVS_DEOB = os.path.join(BASE_DIR, "PrometheusDumper", "deobfuscator.py")

intents = discord.Intents.default()
intents.message_content = True

bot = commands.Bot(command_prefix=PREFIX, intents=intents)


@bot.event
async def on_ready():
    print(f"Bot online: {bot.user}")


async def run_deobfuscator(script, mode):

    await asyncio.sleep(1)

    result = f"-- Deobfuscado com {mode}\n\n{script}"

    return result


def sanitize_filename_for_display(name, default_base="file"):
    
    safe = "".join(c for c in name if c.isalnum() or c in ("_", ".", "-"))
    return safe or default_base


def detect_moonsec(content):
    
    patterns = [
        "([[This file was protected with MoonSec V3]]):gsub('.+', (function",
    ]
    
    return any(p in content for p in patterns)


def block_if_dangerous_lua(content):
    
    bad_patterns = [
        "os.execute",
        "io.popen",
        "require('socket')"
    ]
    
    for p in bad_patterns:
        if p in content:
            return True, "Script contém funções perigosas."
    
    return False, None

@bot.command(name="deob")
async def deob(ctx):

    if not ctx.message.attachments:
        await ctx.reply("❌ Envie um arquivo Lua.")
        return

    att = ctx.message.attachments[0]

    temp_dir = tempfile.mkdtemp()

    safe_name = sanitize_filename_for_display(att.filename, "deob")
    original_path = os.path.join(temp_dir, safe_name)

    progress_msg = await ctx.reply("Analisando arquivo...")

    try:

        await att.save(original_path)

        with open(original_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        blocked, reason = block_if_dangerous_lua(content)
        if blocked:
            await progress_msg.edit(content=f"{reason}")
            return

        if not content.strip():
            await progress_msg.edit(content="Arquivo vazio.")
            return

        if detect_moonsec(content):

            await progress_msg.edit(
                content="MoonSec V3 detectado. Executando deobfuscador..."
            )

            out_path = os.path.join(temp_dir, "deob_moonsec.lua")

            proc = await asyncio.create_subprocess_exec(
                MOONSEC_DEOB_EXE,
                "-dev",
                "-i", original_path,
                "-o", out_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            stdout, stderr = await asyncio.wait_for(
                proc.communicate(),
                timeout=180
            )

            if not os.path.exists(out_path):
                await progress_msg.edit(content="Falha na deobfuscação.")
                return

            await progress_msg.edit(content="Descompilando bytecode...")

            proc_unluac = await asyncio.create_subprocess_exec(
                "java",
                "-jar",
                UNLUAC_JAR,
                out_path,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            stdout_unluac, stderr_unluac = await asyncio.wait_for(
                proc_unluac.communicate(),
                timeout=60
            )

            final_code = stdout_unluac.decode("utf-8", errors="ignore")

            if not final_code.strip():
                await progress_msg.edit(content="Falha na descompilação.")
                return

            final_path = os.path.join(temp_dir, "deob.lua")

            with open(final_path, "w", encoding="utf-8") as f:
                f.write(final_code)

            files = [
                discord.File(out_path, filename="output.luac"),
                discord.File(final_path, filename="deob.lua")
            ]

            await ctx.reply(
                content="Deobfuscação concluída.",
                files=files
            )

            await progress_msg.edit(content="Deobfuscação concluída.")

        else:
            await progress_msg.edit(content="Obfuscador não reconhecido.")

    except asyncio.TimeoutError:
        await progress_msg.edit(content="Timeout.")

    except Exception as e:
        await progress_msg.edit(content=f"Erro: {str(e)}")

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

@bot.command(name="wearedevs")
async def wearedevs(ctx):

    if not ctx.message.attachments:
        await ctx.reply("Envie um script Lua.")
        return

    att = ctx.message.attachments[0]

    temp_dir = tempfile.mkdtemp()
    original_path = os.path.join(temp_dir, att.filename)

    progress_msg = await ctx.reply("Executando deobfuscador WeAreDevs...")

    try:
        await att.save(original_path)

        proc = await asyncio.create_subprocess_exec(
            sys.executable,
            WEAREDEVS_DEOB,
            original_path,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=os.path.dirname(WEAREDEVS_DEOB)
        )

        stdout, stderr = await asyncio.wait_for(
            proc.communicate(),
            timeout=120
        )

        if proc.returncode != 0:
            await progress_msg.edit(
                content=f"Erro no deobfuscador:\n{stderr.decode(errors='ignore')}"
            )
            return

        deob_files = [
            f for f in os.listdir(temp_dir)
            if f.endswith(".deobf.lua")
        ]

        if not deob_files:
            await progress_msg.edit(content="Falha na deobfuscação.")
            return

        result_path = os.path.join(temp_dir, deob_files[0])

        await ctx.reply(
            content="Deobfuscação concluída.",
            file=discord.File(result_path, filename="deob_wearedevs.lua")
        )

        await progress_msg.edit(content="Concluído.")

    except asyncio.TimeoutError:
        await progress_msg.edit(content="Timeout.")

    except Exception as e:
        await progress_msg.edit(content=f"Erro: {str(e)}")

    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


@bot.command()
async def ping(ctx):
    await ctx.send(f'Pong! {round(bot.latency * 1000)}ms')

bot.run(TOKEN)