import sys
import argparse
import asyncio
import uvicorn
from sift.config import Config
from sift.bot.bot import run_discord_bot

def main():
    parser = argparse.ArgumentParser(description="Sift Reverse Engineering Tool Suite Launcher")
    parser.add_argument("--bot", action="store_true", help="Launch the Discord Bot only")
    parser.add_argument("--web", action="store_true", help="Launch the FastAPI server only")
    parser.add_argument("--both", action="store_true", default=True, help="Launch both bot and web server in parallel (Default)")
    
    args = parser.parse_args()

    # If specifically selected only one
    if args.bot and not args.web:
        print("[*] Launching Sift Discord Bot only...")
        run_discord_bot()
    elif args.web and not args.bot:
        print(f"[*] Launching Sift FastAPI Web Server on http://{Config.HOST}:{Config.PORT}...")
        uvicorn.run("sift.backend.server:app", host=Config.HOST, port=Config.PORT, reload=False)
    else:
        # Launch both concurrently
        print("[*] Launching Sift Tool Suite (FastAPI Backend + Discord Bot) in parallel...")
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        
        # Define tasks
        async def start_web():
            config = uvicorn.Config("sift.backend.server:app", host=Config.HOST, port=Config.PORT, log_level="info")
            server = uvicorn.Server(config)
            await server.serve()

        async def start_bot():
            # Run blocking client bot in executor to prevent loop blocking
            await loop.run_in_executor(None, run_discord_bot)

        # Run tasks
        loop.create_task(start_web())
        loop.create_task(start_bot())
        
        try:
            loop.run_forever()
        except KeyboardInterrupt:
            print("\n[*] Shutting down Sift Tool Suite...")

if __name__ == "__main__":
    main()
