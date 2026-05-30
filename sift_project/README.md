# Sift - Unified Lua Reverse Engineering Suite

Sift is a production-ready, purple-themed Lua deobfuscation, bytecode decompilation, environment logging, and AI variable refactoring environment. It runs both as a FastAPI Web API (featuring a premium glassmorphic UI) and an interactive Discord Bot.

---

## 🚀 Features

* **Obfuscator Detection**: Auto-detects Prometheus, Moonsec, Luraph, IronBrew, Soteria, WynnSfuscate, Moonveil, and Bytecode.
* **Bytecode Decompiler**: Decompiles standard Lua 5.1 bytecode (using `unluac.jar`) and Roblox Luau bytecode (using `luau-lifter` with API fallback).
* **Environment Logging**: Sandboxes execution of obfuscated code using Lune and logs metatables, globals, and namecalls.
* **AI Code Renamer**: Uses OpenAI or local Ollama (CodeLlama/Gemma) to rename obfuscated variables and functions semantically.
* **Advanced Web Fetcher**: Integrates `curl-cffi` to rotate user-agents and TLS fingerprints to fetch protected scripts.

---

## 🛠️ Deploying to Render (Free Tier)

Render supports deploying Sift using the included `Dockerfile` natively:

1. Create a new **Web Service** on [Render](https://dashboard.render.com).
2. Connect your GitHub repository containing this project.
3. Select **Docker** as the Runtime.
4. Add the following **Environment Variables** under Render's "Environment" tab:
   * `DISCORD_TOKEN`: Your Discord bot client token.
   * `OPENAI_API_KEY`: Your OpenAI key (Optional, for AI renaming).
   * `PORT`: `8000`
5. Click **Deploy**. Sift will be online at the generated URL and your Discord bot will automatically sign in!

---

## 💻 Running Locally

### Installation
Ensure you have Python 3.10+ installed:
```bash
pip install -r sift/requirements.txt
```

### Run
```bash
python sift/main.py
```
This will launch both the web server (`http://localhost:8000`) and the Discord bot concurrently.
