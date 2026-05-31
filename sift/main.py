import sys
import argparse
import asyncio
import os
import uvicorn
import discord
from sift.config import Config
from sift.bot.bot import bot
from sift.bot.state import BotManager

class DualWriter:
    """
    A stream wrapper that writes to both the original stdout/stderr AND a log file.
    Implements all standard stream interface methods that libraries like uvicorn expect.
    """
    def __init__(self, original_stream, log_file_path):
        self.original_stream = original_stream
        self.log_file_path = log_file_path

    def write(self, data):
        self.original_stream.write(data)
        self.original_stream.flush()
        try:
            with open(self.log_file_path, "a", encoding="utf-8") as f:
                f.write(data)
        except Exception:
            pass

    def flush(self):
        self.original_stream.flush()

    def isatty(self):
        """Required by uvicorn's DefaultFormatter to decide color usage."""
        return False

    def fileno(self):
        """Some logging handlers need a real file descriptor."""
        try:
            return self.original_stream.fileno()
        except Exception:
            raise OSError("DualWriter does not have a real file descriptor")

    @property
    def encoding(self):
        return getattr(self.original_stream, 'encoding', 'utf-8')

    @property
    def errors(self):
        return getattr(self.original_stream, 'errors', 'strict')

    @property
    def name(self):
        return getattr(self.original_stream, 'name', '<DualWriter>')

    def writable(self):
        return True

    def readable(self):
        return False

    def seekable(self):
        return False

    def __getattr__(self, attr):
        """Proxy any other attribute access to the original stream as a fallback."""
        return getattr(self.original_stream, attr)

# Setup DualWriter redirect on start
os.makedirs("dumps", exist_ok=True)
log_file_path = os.path.join("dumps", "sift_system.log")
sys.stdout = DualWriter(sys.stdout, log_file_path)
sys.stderr = DualWriter(sys.stderr, log_file_path)

async def start_web():
    config = uvicorn.Config("sift.backend.server:app", host=Config.HOST, port=Config.PORT, log_level="info")
    server = uvicorn.Server(config)
    await server.serve()

async def start_bot():
    print("[*] Starting Discord Bot via BotManager...")
    await BotManager.start()
    # Keep task running
    while True:
        await asyncio.sleep(3600)

async def start_both():
    # Start bot concurrently
    await BotManager.start()
    
    # Run uvicorn web server
    config = uvicorn.Config("sift.backend.server:app", host=Config.HOST, port=Config.PORT, log_level="info")
    server = uvicorn.Server(config)
    
    print(f"[*] Starting FastAPI Web Server on http://{Config.HOST}:{Config.PORT}...")
    await server.serve()
    
    # Shutdown
    print("[*] Shutting down Discord Bot...")
    await BotManager.stop()

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
            asyncio.run(BotManager.stop())
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
            asyncio.run(BotManager.stop())

if __name__ == "__main__":
    main()
