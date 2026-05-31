import asyncio
import os
import discord
from sift.config import Config
from sift.bot.bot import bot

class BotManager:
    task = None
    status = "offline"  # offline, starting, online, error
    error = None

    @classmethod
    async def start(cls):
        # Check if already running
        if cls.task and not cls.task.done():
            cls.status = "online" if bot.is_ready() else "starting"
            return
        
        Config.reload()
        token = Config.DISCORD_TOKEN
        if not token:
            cls.status = "error"
            cls.error = "No Discord token found in configuration."
            print("[!] Discord Bot start failed: No token configured.")
            return

        cls.status = "starting"
        cls.error = None
        print(f"[*] Starting Discord Bot with prefix '{Config.BOT_PREFIX}'...")

        # Update bot prefix dynamically
        bot.command_prefix = Config.BOT_PREFIX

        async def _run():
            try:
                # We need to make sure the loop handles bot connection
                await bot.start(token)
            except discord.PrivilegedIntentsRequired:
                print("[!] Warning: Privileged Message Content Intent is not enabled in the Discord Developer Portal.")
                print("[*] Retrying connection without Message Content Intent...")
                try:
                    await bot.close()
                except:
                    pass
                intents = discord.Intents.default()
                intents.message_content = False
                bot.intents = intents
                try:
                    await bot.start(token)
                except Exception as ex:
                    cls.status = "error"
                    cls.error = str(ex)
                    print(f"[!] Discord Bot failed to run after retry: {ex}")
            except Exception as e:
                cls.status = "error"
                cls.error = str(e)
                print(f"[!] Discord Bot failed to run: {e}")

        cls.task = asyncio.create_task(_run())
        
        # Wait a moment to see if it starts successfully or fails immediately
        await asyncio.sleep(2)
        if cls.status == "starting":
            # If it didn't throw an error and is logged in
            if bot.is_ready():
                cls.status = "online"
            elif cls.task.done() and cls.task.exception():
                cls.status = "error"
                cls.error = str(cls.task.exception())

    @classmethod
    async def stop(cls):
        cls.status = "offline"
        try:
            if not bot.is_closed():
                print("[*] Closing Discord Bot connection...")
                await bot.close()
        except Exception as e:
            print(f"[!] Error closing bot: {e}")
        
        if cls.task and not cls.task.done():
            cls.task.cancel()
            try:
                await cls.task
            except asyncio.CancelledError:
                pass
            except Exception as e:
                print(f"[!] Error cancelling bot task: {e}")
            cls.task = None
        print("[*] Discord Bot stopped.")

    @classmethod
    async def restart(cls):
        print("[*] Triggering Discord Bot restart...")
        await cls.stop()
        await asyncio.sleep(1.5)
        await cls.start()

    @classmethod
    def get_status(cls):
        # Update status dynamically based on actual discord client connection state
        if cls.task and not cls.task.done():
            if bot.is_ready():
                cls.status = "online"
            else:
                cls.status = "starting"
        else:
            if cls.status not in ["error", "offline"]:
                cls.status = "offline"
                
        return {
            "status": cls.status,
            "username": str(bot.user) if bot.user else "N/A",
            "bot_id": bot.user.id if bot.user else None,
            "latency": round(bot.latency * 1000) if bot.user and bot.latency else None,
            "prefix": Config.BOT_PREFIX,
            "error": cls.error,
            "has_token": bool(Config.DISCORD_TOKEN)
        }
