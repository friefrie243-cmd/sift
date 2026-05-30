import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Discord Bot Configuration
    DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", "")
    BOT_PREFIX = os.getenv("BOT_PREFIX", "!")
    
    # LLM Settings (AI Renamer)
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
    OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "codellama")
    
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

# Create directories if they do not exist
for directory in [Config.TEMP_DIR, Config.ORIGINAL_DIR, Config.DUMPED_DIR]:
    os.makedirs(directory, exist_ok=True)
