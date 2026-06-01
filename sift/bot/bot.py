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
from sift.bot.access import AccessManager

# Owner ID
OWNER_ID = Config.BOT_OWNER_ID

# Set up intents
intents = discord.Intents.default()
intents.message_content = Config.DISCORD_INTENTS_MESSAGE_CONTENT

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

async def check_access(ctx) -> bool:
    """
    Check if a user has access to use bot commands.
    Returns True if allowed, False if blocked.
    """
    user_id = ctx.author.id if hasattr(ctx, 'author') else ctx.user.id
    if not AccessManager.is_allowed(user_id, OWNER_ID):
        await ctx.send(
            embed=get_premium_embed(
                "🚫 Access Denied",
                "You are blacklisted from using Sift commands. Contact the bot owner for assistance.",
                0xd90429
            ),
            ephemeral=True
        )
        return False
    return True

async def fetch_code_from_msg(ctx, arg: str = None, file: discord.Attachment = None) -> tuple[str, str]:
    """
    Utility helper that extracts code from message attachments, slash command attachments, pastebin links, or raw text.
    """
    # 1. Check slash command attachment
    if file is not None:
        try:
            content = await file.read()
            return content.decode("utf-8", errors="ignore"), file.filename
        except Exception as e:
            return "", ""

    # 2. Check prefix command message attachments
    if hasattr(ctx, "message") and ctx.message and ctx.message.attachments:
        attachment = ctx.message.attachments[0]
        try:
            content = await attachment.read()
            return content.decode("utf-8", errors="ignore"), attachment.filename
        except Exception as e:
            return "", ""

    # 3. Check pastebin/raw github link inside text
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

    # 4. Code blocks or raw text
    if arg:
        code_block_match = re.search(r"```(?:lua)?\n(.*?)```", arg, re.DOTALL | re.IGNORECASE)
        if code_block_match:
            return code_block_match.group(1), "script.lua"
        return arg, "script.lua"

    return "", ""

@bot.event
async def on_ready():
    print(f"[*] Sift Bot is online! Logged in as {bot.user} ({bot.user.id})")
    
    # Set streaming activity (purple "Live on Twitch" indicator)
    streaming_activity = discord.Streaming(
        name="Sift Engine 24/7",
        url="https://www.twitch.tv/streamerhouse"
    )
    await bot.change_presence(activity=streaming_activity, status=discord.Status.online)
    print(f"[*] Streaming status set — Live on Twitch indicator active.")
    
    # Sync slash commands
    try:
        synced = await bot.tree.sync()
        print(f"[*] Synced {len(synced)} slash commands.")
    except Exception as e:
        print(f"[*] Failed to sync slash commands: {e}")

@bot.hybrid_command(name="deobf", description="Deobfuscates a Lua script. Detects engine automatically.")
@app_commands.describe(arg="The Lua code, code block, or URL to fetch", file="The Lua file to deobfuscate")
async def cmd_deobf(ctx, arg: str = None, file: discord.Attachment = None):
    if not await check_access(ctx):
        return
    await ctx.defer()
    code, filename = await fetch_code_from_msg(ctx, arg, file)
    if not code:
        await ctx.send(embed=get_premium_embed("Error", "Please upload a Lua file, paste a link, or write code block.", 0xd90429))
        return
        
    success, out_code, log_details, detected_type, _ = await DeobfuscatorEngine.deobfuscate(code)
    
    # Render clean purple embed
    embed = get_premium_embed(
        "🔮 Sift Deobfuscation Result",
        f"**File Name**: `{filename}`\n**Detected Engine**: `{detected_type}`\n\n**Engine Output Details**:\n```ansi\n\u001b[0;35m{log_details[:400]}...\u001b[0m\n```"
    )
    
    # Prepare output attachment
    fp = io.BytesIO(out_code.encode("utf-8"))
    fp.seek(0)
    file_attachment = discord.File(fp=fp, filename=f"sift_deobf_{filename}")
    
    # Attach the interactive Sift AI renaming button
    view = SiftRenameView(out_code, ctx.author.id)
    await ctx.send(embed=embed, file=file_attachment, view=view)

@bot.hybrid_command(name="dump", description="Dynamic falling back constants/strings dumper.")
@app_commands.describe(arg="The Lua code, code block, or URL to fetch", file="The Lua file to dump constants from")
async def cmd_dump(ctx, arg: str = None, file: discord.Attachment = None):
    if not await check_access(ctx):
        return
    await ctx.defer()
    code, filename = await fetch_code_from_msg(ctx, arg, file)
    if not code:
        await ctx.send(embed=get_premium_embed("Error", "Please provide a script.", 0xd90429))
        return
        
    success, out_code, console_log = await LuneRunner.run_lua_dumper(code)
    
    embed = get_premium_embed(
        "📦 Constants/Upvalues Dumper",
        f"**File**: `{filename}`\n**Status**: `{'Success' if success else 'Failed'}`"
    )
    
    fp = io.BytesIO(out_code.encode("utf-8") if out_code else b"-- No Output")
    fp.seek(0)
    file_attachment = discord.File(fp=fp, filename=f"dump_{filename}")
    
    await ctx.send(embed=embed, file=file_attachment)

@bot.hybrid_command(name="envlog", description="Instruments code and log all environment interactions.")
@app_commands.describe(arg="The Lua code, code block, or URL to fetch", file="The Lua file to instrument")
async def cmd_envlog(ctx, arg: str = None, file: discord.Attachment = None):
    if not await check_access(ctx):
        return
    await ctx.defer()
    code, filename = await fetch_code_from_msg(ctx, arg, file)
    if not code:
        await ctx.send(embed=get_premium_embed("Error", "Please provide a script.", 0xd90429))
        return
        
    success, out_code, console_log = await LuneRunner.run_lune_script("httplog2.lua", code)
    
    embed = get_premium_embed(
        "📋 Environment Logging Complete",
        f"**File**: `{filename}`\n**Captured Events**: `{len(out_code.splitlines()) if out_code else 0} lines`"
    )
    
    fp = io.BytesIO(out_code.encode("utf-8") if out_code else b"-- No Logger Output")
    fp.seek(0)
    file_attachment = discord.File(fp=fp, filename=f"envlog_{filename}")
    
    await ctx.send(embed=embed, file=file_attachment)

@bot.hybrid_command(name="fetch", description="Retrieves web content bypassing blocks via user-agent rotation.")
@app_commands.describe(url="The URL to fetch")
async def cmd_fetch(ctx, url: str):
    if not await check_access(ctx):
        return
    await ctx.defer()
    success, content = await AdvancedFetcher.fetch(url)
    
    if success:
        embed = get_premium_embed("🔗 Sift Fetcher Success", f"Successfully fetched `{url}`")
        fp = io.BytesIO(content.encode("utf-8"))
        fp.seek(0)
        file_attachment = discord.File(fp=fp, filename="fetched.lua")
        await ctx.send(embed=embed, file=file_attachment)
    else:
        await ctx.send(embed=get_premium_embed("Fetch Failed", content, 0xd90429))

@bot.hybrid_command(name="decompile", description="Decompiles Lua 5.1 / Luau bytecode.")
@app_commands.describe(arg="Hex string or bytecode file content", file="The compiled .luac bytecode file to decompile")
async def cmd_decompile(ctx, arg: str = None, file: discord.Attachment = None):
    if not await check_access(ctx):
        return
    await ctx.defer()
    code, filename = await fetch_code_from_msg(ctx, arg, file)
    if not code:
        await ctx.send("Provide Hex string or .luac bytecode file.")
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
            file_attachment = discord.File(fp=fp, filename=f"decompiled_{filename.replace('.luac', '.lua')}")
            await ctx.send(embed=embed, file=file_attachment)
        else:
            await ctx.send(embed=get_premium_embed("Decompilation Failed", details, 0xd90429))
    except Exception as e:
        await ctx.send(f"Decompile failed: {str(e)}")
    finally:
        if os.path.exists(temp_in): os.remove(temp_in)
        if os.path.exists(temp_out): os.remove(temp_out)

@bot.hybrid_command(name="rename", description="Uses AI LLM to rename variables/functions to descriptive names.")
@app_commands.describe(arg="The Lua code, code block, or URL to fetch", file="The Lua file to rename variables in")
async def cmd_rename(ctx, arg: str = None, file: discord.Attachment = None):
    if not await check_access(ctx):
        return
    await ctx.defer()
    code, filename = await fetch_code_from_msg(ctx, arg, file)
    if not code:
        await ctx.send("Provide a script to rename.")
        return
        
    renamed = await AIRenamer.rename(code)
    
    embed = get_premium_embed("✨ AI Rename Refactor", f"Renamed variables in `{filename}`")
    fp = io.BytesIO(renamed.encode("utf-8"))
    fp.seek(0)
    file_attachment = discord.File(fp=fp, filename=f"renamed_{filename}")
    await ctx.send(embed=embed, file=file_attachment)

# ── Whitelist / Blacklist Commands ──────────────────────────────────────────────

@bot.hybrid_command(name="whitelist", description="Whitelist a user to use Sift bot commands. (Owner only)")
@app_commands.describe(user_id="The Discord user ID to whitelist")
async def cmd_whitelist(ctx, user_id: str):
    if ctx.author.id != OWNER_ID:
        await ctx.send(embed=get_premium_embed("🚫 Permission Denied", "Only the bot owner can manage the whitelist.", 0xd90429))
        return
    try:
        uid = int(user_id.strip("<@!>"))
        AccessManager.whitelist(uid)
        await ctx.send(embed=get_premium_embed("✅ Whitelisted", f"User `{uid}` has been whitelisted. They can now use Sift commands and add the bot to their servers."))
    except ValueError:
        await ctx.send(embed=get_premium_embed("Error", "Invalid user ID.", 0xd90429))

@bot.hybrid_command(name="blacklist", description="Blacklist a user from using Sift bot commands. (Owner only)")
@app_commands.describe(user_id="The Discord user ID to blacklist")
async def cmd_blacklist(ctx, user_id: str):
    if ctx.author.id != OWNER_ID:
        await ctx.send(embed=get_premium_embed("🚫 Permission Denied", "Only the bot owner can manage the blacklist.", 0xd90429))
        return
    try:
        uid = int(user_id.strip("<@!>"))
        if uid == OWNER_ID:
            await ctx.send(embed=get_premium_embed("Error", "Cannot blacklist the bot owner.", 0xd90429))
            return
        AccessManager.blacklist(uid)
        await ctx.send(embed=get_premium_embed("🚫 Blacklisted", f"User `{uid}` has been blacklisted. They can no longer use Sift commands or add the bot."))
    except ValueError:
        await ctx.send(embed=get_premium_embed("Error", "Invalid user ID.", 0xd90429))

@bot.hybrid_command(name="unlist", description="Remove a user from both whitelist and blacklist. (Owner only)")
@app_commands.describe(user_id="The Discord user ID to remove from all lists")
async def cmd_unlist(ctx, user_id: str):
    if ctx.author.id != OWNER_ID:
        await ctx.send(embed=get_premium_embed("🚫 Permission Denied", "Only the bot owner can manage access lists.", 0xd90429))
        return
    try:
        uid = int(user_id.strip("<@!>"))
        AccessManager.remove(uid)
        await ctx.send(embed=get_premium_embed("🔄 Removed", f"User `{uid}` has been removed from all access lists."))
    except ValueError:
        await ctx.send(embed=get_premium_embed("Error", "Invalid user ID.", 0xd90429))

@bot.hybrid_command(name="accesslist", description="View current whitelist and blacklist. (Owner only)")
async def cmd_accesslist(ctx):
    if ctx.author.id != OWNER_ID:
        await ctx.send(embed=get_premium_embed("🚫 Permission Denied", "Only the bot owner can view access lists.", 0xd90429))
        return
    
    lists = AccessManager.get_lists()
    wl = "\n".join([f"• `{uid}`" for uid in lists["whitelist"]]) or "*(empty)*"
    bl = "\n".join([f"• `{uid}`" for uid in lists["blacklist"]]) or "*(empty)*"
    
    embed = get_premium_embed(
        "📋 Sift Access Lists",
        f"**✅ Whitelisted Users:**\n{wl}\n\n**🚫 Blacklisted Users:**\n{bl}"
    )
    await ctx.send(embed=embed)

# ── Guild Join Protection ──────────────────────────────────────────────────────

@bot.event
async def on_guild_join(guild: discord.Guild):
    """
    When the bot is added to a new server, check if the person who added it
    is blacklisted. If so, leave the server.
    """
    # Check the server owner (the person who authorized the bot)
    if guild.owner_id and AccessManager.is_blacklisted(guild.owner_id):
        print(f"[*] Leaving guild '{guild.name}' — owner {guild.owner_id} is blacklisted.")
        try:
            await guild.leave()
        except Exception as e:
            print(f"[!] Error leaving blacklisted guild: {e}")

# Run bot
def run_discord_bot(token: str = None):
    bot_token = token or Config.DISCORD_TOKEN
    if not bot_token:
        print("[!] Error: No Discord bot token found in env or config.")
        return
    bot.run(bot_token)
