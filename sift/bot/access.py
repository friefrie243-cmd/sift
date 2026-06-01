import json
import os

# Persistent access list file
ACCESS_FILE = os.path.join(os.path.dirname(__file__), "access.json")

class AccessManager:
    """
    Manages whitelist and blacklist for the Discord bot.
    Data persists via a JSON file.
    """
    _whitelist: set = set()
    _blacklist: set = set()
    _loaded: bool = False

    @classmethod
    def _load(cls):
        """Load access lists from JSON file."""
        if cls._loaded:
            return
        try:
            if os.path.exists(ACCESS_FILE):
                with open(ACCESS_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                cls._whitelist = set(data.get("whitelist", []))
                cls._blacklist = set(data.get("blacklist", []))
        except Exception as e:
            print(f"[!] Error loading access file: {e}")
        cls._loaded = True

    @classmethod
    def _save(cls):
        """Save access lists to JSON file."""
        try:
            data = {
                "whitelist": list(cls._whitelist),
                "blacklist": list(cls._blacklist)
            }
            with open(ACCESS_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
        except Exception as e:
            print(f"[!] Error saving access file: {e}")

    @classmethod
    def whitelist(cls, user_id: int) -> bool:
        """Add a user to the whitelist. Removes from blacklist if present."""
        cls._load()
        cls._blacklist.discard(user_id)
        cls._whitelist.add(user_id)
        cls._save()
        return True

    @classmethod
    def blacklist(cls, user_id: int) -> bool:
        """Add a user to the blacklist. Removes from whitelist if present."""
        cls._load()
        cls._whitelist.discard(user_id)
        cls._blacklist.add(user_id)
        cls._save()
        return True

    @classmethod
    def remove(cls, user_id: int) -> bool:
        """Remove a user from both lists."""
        cls._load()
        cls._whitelist.discard(user_id)
        cls._blacklist.discard(user_id)
        cls._save()
        return True

    @classmethod
    def is_whitelisted(cls, user_id: int) -> bool:
        cls._load()
        return user_id in cls._whitelist

    @classmethod
    def is_blacklisted(cls, user_id: int) -> bool:
        cls._load()
        return user_id in cls._blacklist

    @classmethod
    def is_allowed(cls, user_id: int, owner_id: int) -> bool:
        """
        Check if a user is allowed to use the bot.
        - Owner is always allowed.
        - Blacklisted users are never allowed.
        - Everyone else is allowed by default (open access unless blacklisted).
        """
        cls._load()
        if user_id == owner_id:
            return True
        if user_id in cls._blacklist:
            return False
        return True

    @classmethod
    def get_lists(cls) -> dict:
        """Get current whitelist and blacklist."""
        cls._load()
        return {
            "whitelist": list(cls._whitelist),
            "blacklist": list(cls._blacklist)
        }
