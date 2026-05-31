import discord
from discord.ext import commands
from discord import app_commands
import aiohttp
import asyncio
import os
import io
import re
from sift.config import Config
from sift.core.deobfuscator import DeobfuscatorEngine
from sift.core.renamer import AIRenamer
from sift.core.decompiler import Decompiler
from sift.core.fetcher import AdvancedFetcher
from sift.core.lune_runner import LuneRunner

# Set up intents
intents = discord.Intents.default()
intents.message_content = True
intents.members = True

bot = commands.Bot(command_prefix=Config.BOT_PREFIX, intents=intents)

class SiftRenameView(discord.ui.View):
    def __init__(self, output_code: str, requester_id: int):
        super().__init__(timeout=60)
        self.output_code = output_code
        self.requester_id = requester_id
        self.is_renamed = False

    async def interaction_check(self, interaction: discord.Interaction) -> bool:
        if interaction.user.id != self.requester_id:
            await interaction.response.send_message("Only the original requester can trigger AI renaming.", ephemeral=True)
            return False
        return True

    @discord.ui.button(label="AI Rename Variables", style=discord.ButtonStyle.primary, emoji="✨")
    async def rename_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        if self.is_renamed:
            await interaction.response.send_message("Already renamed.", ephemeral=True)
            return
            
        await interaction.response.defer(ephemeral=True)
        self.is_renamed = True
        
        # Run AI Renamer
        renamed_code = await AIRenamer.rename(self.output_code)
        
        # Write to memory buffer and send
        fp = io.BytesIO(renamed_code.encode("utf-8"))
        fp.seek(0)
        file = discord.File(fp=fp, filename="sift_renamed.lua")
        
        await interaction.followup.send(
            content="✨ Variable and function names refactored semantically:",
            file=file,
            ephemeral=False
        )
        self.stop()

def get_premium_embed(title: str, description: str, color: int = 0x9d4edd) -> discord.Embed:
    """
    Creates a standardized purple-themed Sift premium UI embed.
    """
    embed = discord.Embed(title=title, description=description, color=color)
    embed.set_footer(text="Sift Reverse Engineering • Premium Edition")
    return embed

async def fetch_code_from_msg(ctx, arg: str = None) -> tuple[str, str]:
    """
    Utility helper that extracts code from message attachments, pastebin links, or raw text.
    """
    # 1. Check attachments
    if ctx.message.attachments:
        attachment = ctx.message.attachments[0]
        try:
            content = await attachment.read()
            return content.decode("utf-8", errors="ignore"), attachment.filename
        except Exception as e:
            return "", ""

    # 2. Check pastebin/raw github link inside text
    if arg and arg.startswith("https://"):
        try:
            async with aiohttp.ClientSession() as session:
                # Convert standard links to raw if possible
                url = arg
                if "pastebin.com/" in url and "/raw/" not in url:
                    url = url.replace("pastebin.com/", "pastebin.com/raw/")
                elif "github.com/" in url and "/raw/" not in url and "raw.githubusercontent.com" not in url:
                    url = url.replace("github.com/", "raw.githubusercontent.com/").replace("/blob/", "/")
                
                async with session.get(url) as r:
                    if r.status == 200:
                        text = await r.text()
                        name = url.split("/")[-1].split("?")[0] or "fetch.lua"
                        return text, name
        except:
            pass

    # 3. Code blocks or raw text
    if arg:
        code_block_match = re.search(r"```(?:lua)?\n(.*?)```", arg, re.DOTALL | re.IGNORECASE)
        if code_block_match:
            return code_block_match.group(1), "script.lua"
        return arg, "script.lua"

    return "", ""

@bot.event
async def on_ready():
    print(f"[*] Sift Bot is online! Logged in as {bot.user} ({bot.user.id})")
    # Sync slash commands
    try:
        synced = await bot.tree.sync()
        print(f"[*] Synced {len(synced)} slash commands.")
    except Exception as e:
        print(f"[*] Failed to sync slash commands: {e}")

@bot.command(name="deobf")
async def cmd_deobf(ctx, *, arg: str = None):
    """
    Deobfuscates a Lua script. Detects engine automatically.
    """
    async with ctx.typing():
        code, filename = await fetch_code_from_msg(ctx, arg)
        if not code:
            await ctx.reply(embed=get_premium_embed("Error", "Please upload a Lua file, paste a link, or write code block.", 0xd90429))
            return
            
        success, out_code, log_details, detected_type = await DeobfuscatorEngine.deobfuscate(code)
        
        # Render clean purple embed
        embed = get_premium_embed(
            "🔮 Sift Deobfuscation Result",
            f"**File Name**: `{filename}`\n**Detected Engine**: `{detected_type}`\n\n**Engine Output Details**:\n```ansi\n\u001b[0;35m{log_details[:400]}...\u001b[0m\n```"
        )
        
        # Prepare output attachment
        fp = io.BytesIO(out_code.encode("utf-8"))
        fp.seek(0)
        file = discord.File(fp=fp, filename=f"sift_deobf_{filename}")
        
        # Attach the interactive Sift AI renaming button
        view = SiftRenameView(out_code, ctx.author.id)
        await ctx.reply(embed=embed, file=file, view=view)

@bot.command(name="dump")
async def cmd_dump(ctx, *, arg: str = None):
    """
    Dynamic falling back constants/strings dumper.
    """
    async with ctx.typing():
        code, filename = await fetch_code_from_msg(ctx, arg)
        if not code:
            await ctx.reply(embed=get_premium_embed("Error", "Please provide a script.", 0xd90429))
            return
            
        success, out_code, console_log = await LuneRunner.run_lua_dumper(code)
        
        embed = get_premium_embed(
            "📦 Constants/Upvalues Dumper",
            f"**File**: `{filename}`\n**Status**: `{'Success' if success else 'Failed'}`"
        )
        
        fp = io.BytesIO(out_code.encode("utf-8") if out_code else b"-- No Output")
        fp.seek(0)
        file = discord.File(fp=fp, filename=f"dump_{filename}")
        
        await ctx.reply(embed=embed, file=file)

@bot.command(name="envlog")
async def cmd_envlog(ctx, *, arg: str = None):
    """
    Instruments code and log all environment interactions (globals, metatables, loadstrings).
    """
    async with ctx.typing():
        code, filename = await fetch_code_from_msg(ctx, arg)
        if not code:
            await ctx.reply(embed=get_premium_embed("Error", "Please provide a script.", 0xd90429))
            return
            
        success, out_code, console_log = await LuneRunner.run_lune_script("httplog2.lua", code)
        
        embed = get_premium_embed(
            "📋 Environment Logging Complete",
            f"**File**: `{filename}`\n**Captured Events**: `{len(out_code.splitlines()) if out_code else 0} lines`"
        )
        
        fp = io.BytesIO(out_code.encode("utf-8") if out_code else b"-- No Logger Output")
        fp.seek(0)
        file = discord.File(fp=fp, filename=f"envlog_{filename}")
        
        await ctx.reply(embed=embed, file=file)

@bot.command(name="fetch")
async def cmd_fetch(ctx, url: str):
    """
    Retrieves web content bypassing blocks via user-agent rotation and TLS.
    """
    async with ctx.typing():
        success, content = await AdvancedFetcher.fetch(url)
        
        if success:
            embed = get_premium_embed("🔗 Sift Fetcher Success", f"Successfully fetched `{url}`")
            fp = io.BytesIO(content.encode("utf-8"))
            fp.seek(0)
            file = discord.File(fp=fp, filename="fetched.lua")
            await ctx.reply(embed=embed, file=file)
        else:
            await ctx.reply(embed=get_premium_embed("Fetch Failed", content, 0xd90429))

@bot.command(name="decompile")
async def cmd_decompile(ctx, *, arg: str = None):
    """
    Decompiles Lua 5.1 / Luau bytecode.
    """
    async with ctx.typing():
        code, filename = await fetch_code_from_msg(ctx, arg)
        if not code:
            await ctx.reply("Provide Hex string or .luac bytecode file.")
            return
            
        job_id = str(asyncio.get_event_loop().time())
        temp_in = os.path.join(Config.TEMP_DIR, f"cmd_{job_id}.luac")
        temp_out = os.path.join(Config.TEMP_DIR, f"cmd_{job_id}.lua")
        
        try:
            # Handle binary write
            try:
                bytecode = bytes.fromhex(code.strip())
            except:
                bytecode = code.encode("utf-8", errors="ignore")
                
            with open(temp_in, "wb") as f:
                f.write(bytecode)
                
            success, details = await Decompiler.decompile(temp_in, temp_out)
            
            if success and os.path.exists(temp_out):
                with open(temp_out, "r", encoding="utf-8", errors="ignore") as f:
                    out_src = f.read()
                
                embed = get_premium_embed("⚡ Sift Bytecode Decompiler", f"**File**: `{filename}`\n**Detail**: `{details}`")
                fp = io.BytesIO(out_src.encode("utf-8"))
                fp.seek(0)
                file = discord.File(fp=fp, filename=f"decompiled_{filename.replace('.luac', '.lua')}")
                await ctx.reply(embed=embed, file=file)
            else:
                await ctx.reply(embed=get_premium_embed("Decompilation Failed", details, 0xd90429))
        except Exception as e:
            await ctx.reply(f"Decompile failed: {str(e)}")
        finally:
            if os.path.exists(temp_in): os.remove(temp_in)
            if os.path.exists(temp_out): os.remove(temp_out)

@bot.command(name="rename")
async def cmd_rename(ctx, *, arg: str = None):
    """
    Uses OpenAI/Ollama LLM to rename variables/functions to descriptive names.
    """
    async with ctx.typing():
        code, filename = await fetch_code_from_msg(ctx, arg)
        if not code:
            await ctx.reply("Provide a script to rename.")
            return
            
        renamed = await AIRenamer.rename(code)
        
        embed = get_premium_embed("✨ AI Rename Refactor", f"Renamed variables in `{filename}`")
        fp = io.BytesIO(renamed.encode("utf-8"))
        fp.seek(0)
        file = discord.File(fp=fp, filename=f"renamed_{filename}")
        await ctx.reply(embed=embed, file=file)

# Run bot
def run_discord_bot(token: str = None):
    bot_token = token or Config.DISCORD_TOKEN
    if not bot_token:
        print("[!] Error: No Discord bot token found in env or config.")
        return
    bot.run(bot_token)
