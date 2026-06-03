import os
import urllib.request
import json
from dotenv import load_dotenv

load_dotenv()
token = os.getenv("DISCORD_TOKEN", "")
req = urllib.request.Request(
    "https://discord.com/api/v10/users/@me",
    headers={
        "Authorization": f"Bot {token}",
        "User-Agent": "DiscordBot (https://github.com/Rapptz/discord.py 2.3.0) Python/3.11"
    }
)

try:
    with urllib.request.urlopen(req) as res:
        print("Status:", res.status)
        print("Response:", res.read().decode())
except Exception as e:
    print("Error code:", getattr(e, "code", None))
    print("Error message:", getattr(e, "read", lambda: b"")().decode() or str(e))
