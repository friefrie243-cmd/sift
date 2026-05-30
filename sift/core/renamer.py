import os
import re
import asyncio
import aiohttp
from openai import AsyncOpenAI
from ollama import AsyncClient
from sift.config import Config

class AIRenamer:
    @staticmethod
    def _get_system_prompt() -> str:
        return (
            "You are a professional code refactoring and reverse engineering assistant.\n"
            "Your task is to analyze the provided Lua/Luau script and rename all cryptically named "
            "variables, tables, parameters, and functions (e.g., v1, lll_IIlll, _0x82f1a, var5) to descriptive, "
            "clean, semantic, and human-readable names based on their context and usage.\n\n"
            "CRITICAL INSTRUCTIONS:\n"
            "1. DO NOT change any functional logic, operators, control flow, loops, or structure.\n"
            "2. DO NOT change standard Lua globals (print, pairs, next, setmetatable) or Roblox APIs "
            "(game, Workspace, Players, getfenv, task, etc.). Only rename custom local/global script variables.\n"
            "3. Ensure the renamed script compiles and behaves exactly like the original.\n"
            "4. Return ONLY the refactored Lua code. Do not include markdown code block formatting (```lua ... ```), "
            "and do not write any introductory or explanatory text. Your output must contain only the valid code."
        )

    @classmethod
    async def rename_openai(cls, code: str, api_key: str, model: str = "gpt-4o") -> str:
        """
        Refactors variable and function names using OpenAI API.
        """
        try:
            client = AsyncOpenAI(api_key=api_key)
            response = await client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": cls._get_system_prompt()},
                    {"role": "user", "content": f"Please rename the variables in this Lua code:\n\n{code}"}
                ],
                temperature=0.2
            )
            output = response.choices[0].message.content.strip()
            # Clean up potential markdown formatting if the model ignored instructions
            if output.startswith("```"):
                output = re.sub(r"^```(?:lua)?\n", "", output)
                output = re.sub(r"\n```$", "", output)
            return output
        except Exception as e:
            return f"-- [AI Renamer Error] OpenAI API call failed: {str(e)}\n\n{code}"

    @classmethod
    async def rename_ollama(cls, code: str, host: str, model: str = "codellama") -> str:
        """
        Refactors variable and function names using a local Ollama instance.
        """
        try:
            client = AsyncClient(host=host)
            response = await client.chat(
                model=model,
                messages=[
                    {"role": "system", "content": cls._get_system_prompt()},
                    {"role": "user", "content": f"Please rename the variables in this Lua code:\n\n{code}"}
                ],
                options={"temperature": 0.2}
            )
            output = response['message']['content'].strip()
            if output.startswith("```"):
                output = re.sub(r"^```(?:lua)?\n", "", output)
                output = re.sub(r"\n```$", "", output)
            return output
        except Exception as e:
            return f"-- [AI Renamer Error] Ollama call failed: {str(e)}\n\n{code}"

    @classmethod
    async def rename_vercel(cls, code: str) -> str:
        """
        Refactors variable and function names using the free Vercel Renamer API.
        """
        try:
            url = "https://renamer-api.vercel.app/api/rename"
            headers = {
                "x-api-key": "33ms-DHJHS-24633",
                "Content-Type": "application/json"
            }
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json={"code": code}, headers=headers) as response:
                    if response.status == 200:
                        data = await response.json()
                        renamed = data.get("renamedCode")
                        if renamed:
                            return renamed
                        else:
                            return f"-- [AI Renamer Error] Vercel API returned empty renamedCode: {data}\n\n{code}"
                    else:
                        text = await response.text()
                        return f"-- [AI Renamer Error] Vercel API status code {response.status}: {text}\n\n{code}"
        except Exception as e:
            return f"-- [AI Renamer Error] Vercel API request failed: {str(e)}\n\n{code}"

    @classmethod
    async def rename(cls, code: str, provider: str = "openai", api_key: str = None) -> str:
        """
        Renames variables/functions in Lua code. Handles key fallback to config.
        """
        if not code or not isinstance(code, str):
            return ""

        # Remove header/footer noise first
        code_str = code.strip()
        
        # Decide provider
        if provider == "openai":
            key = api_key or Config.OPENAI_API_KEY
            if not key:
                # Fallback to the free Vercel API
                return await cls.rename_vercel(code_str)
            return await cls.rename_openai(code_str, key)
        elif provider == "ollama":
            return await cls.rename_ollama(code_str, Config.OLLAMA_HOST, Config.OLLAMA_MODEL)
        elif provider == "vercel":
            return await cls.rename_vercel(code_str)
        else:
            return f"-- [AI Renamer Error] Unsupported AI provider '{provider}'.\n\n{code}"
