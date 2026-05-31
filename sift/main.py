import sys
import argparse
import asyncio
import uvicorn
from sift.config import Config
from sift.bot.bot import bot

async def start_web():
    config = uvicorn.Config("sift.backend.server:app", host=Config.HOST, port=Config.PORT, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()

async def start_bot():
    token = Config.DISCORD_TOKEN
    if not token:
        print("[!] Error: No Discord bot token found in env or config.")
        return
    print("[*] Starting Discord Bot...")
    try:
        await bot.start(token)
    except Exception as e:
        print(f"[!] Discord Bot failed to run: {e}")

async def start_both():
    # Run uvicorn and discord bot concurrently on the same loop
    config = uvicorn.Config("sift.backend.server:app", host=Config.HOST, port=Config.PORT, log_level="info")
    server = uvicorn.Server(config)
    
    token = Config.DISCORD_TOKEN
    bot_task = None
    if token:
        print("[*] Starting Discord Bot concurrently...")
        bot_task = asyncio.create_task(bot.start(token))
    else:
        print("[!] No Discord token found, bot will not start.")
        
    print(f"[*] Starting FastAPI Web Server on http://{Config.HOST}:{Config.PORT}...")
    await server.serve()
    
    if bot_task:
        print("[*] Shutting down Discord Bot...")
        await bot.close()
        await bot_task

def main():
    parser = argparse.ArgumentParser(description="Sift Reverse Engineering Tool Suite Launcher")
    parser.add_argument("--bot", action="store_true", help="Launch the Discord Bot only")
    parser.add_argument("--web", action="store_true", help="Launch the FastAPI server only")
    parser.add_argument("--both", action="store_true", default=True, help="Launch both bot and web server in parallel (Default)")
    
    args = parser.parse_args()

    # Determine what to run
    if args.bot and not args.web:
        print("[*] Launching Sift Discord Bot only...")
        try:
            asyncio.run(start_bot())
        except KeyboardInterrupt:
            print("\n[*] Shutting down Discord Bot...")
    elif args.web and not args.bot:
        print(f"[*] Launching Sift FastAPI Web Server on http://{Config.HOST}:{Config.PORT}...")
        try:
            asyncio.run(start_web())
        except KeyboardInterrupt:
            print("\n[*] Shutting down Web Server...")
    else:
        # Launch both concurrently
        print("[*] Launching Sift Tool Suite (FastAPI Backend + Discord Bot) in parallel...")
        try:
            asyncio.run(start_both())
        except KeyboardInterrupt:
            print("\n[*] Shutting down Sift Tool Suite...")

if __name__ == "__main__":
    main()
