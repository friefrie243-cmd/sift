import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Discord Bot Configuration
    DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", os.getenv("BOT_TOKEN", ""))
    BOT_PREFIX = os.getenv("BOT_PREFIX", "!")
    DISCORD_INTENTS_MESSAGE_CONTENT = os.getenv("DISCORD_INTENTS_MESSAGE_CONTENT", "false").lower() == "true"
    BOT_OWNER_ID = int(os.getenv("BOT_OWNER_ID", "1011417432080003152"))
    
    # LLM Settings (AI Renamer & Recovery)
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
    OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "codellama")
    OLLAMA_API_KEY = os.getenv("OLLAMA_API_KEY", "")
    
    # Vercel API Key
    VERCEL_API_KEY = os.getenv("VERCEL_API_KEY", "")
    
    # FastAPI Backend Configuration
    HOST = os.getenv("HOST", "0.0.0.0")
    PORT = int(os.getenv("PORT", 8000))
    API_KEY = os.getenv("SIFT_API_KEY", "sift_secret_key_1337")
    
    # External Binary Paths
    LUNE_PATH = os.getenv("LUNE_PATH", "lune")  # Must be installed and in path
    JAVA_PATH = os.getenv("JAVA_PATH", "java")  # For unluac.jar
    LUAU_LIFTER_PATH = os.getenv("LUAU_LIFTER_PATH", "./medal51/luau-lifter.exe")
    UNLUAC_JAR_PATH = os.getenv("UNLUAC_JAR_PATH", "./deobfuscate/unluac.jar")
    
    # Working Directories
    TEMP_DIR = os.getenv("TEMP_DIR", "./dumps/temp")
    ORIGINAL_DIR = os.getenv("ORIGINAL_DIR", "./dumps/original")
    DUMPED_DIR = os.getenv("DUMPED_DIR", "./dumps/dumped")

    @classmethod
    def reload(cls):
        from dotenv import load_dotenv
        load_dotenv(override=True)
        cls.DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", os.getenv("BOT_TOKEN", ""))
        cls.BOT_PREFIX = os.getenv("BOT_PREFIX", "!")
        cls.DISCORD_INTENTS_MESSAGE_CONTENT = os.getenv("DISCORD_INTENTS_MESSAGE_CONTENT", "false").lower() == "true"
        cls.BOT_OWNER_ID = int(os.getenv("BOT_OWNER_ID", "1011417432080003152"))
        cls.OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
        cls.DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "")
        cls.OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        cls.OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "codellama")
        cls.OLLAMA_API_KEY = os.getenv("OLLAMA_API_KEY", "")
        cls.VERCEL_API_KEY = os.getenv("VERCEL_API_KEY", "")
        cls.API_KEY = os.getenv("SIFT_API_KEY", "sift_secret_key_1337")


# Create directories if they do not exist
for directory in [Config.TEMP_DIR, Config.ORIGINAL_DIR, Config.DUMPED_DIR]:
    os.makedirs(directory, exist_ok=True)
