import os
import re
import aiohttp
from sift.config import Config

class AIService:
    @staticmethod
    def _get_rename_system_prompt() -> str:
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

    @staticmethod
    def _get_sift_ui_system_prompt(sift_ui_code: str) -> str:
        prompt = (
            "You are an expert Roblox Lua UI developer.\n"
            "Your task is to take a deobfuscated Lua script that uses an existing UI library (e.g., Orion, Rayfield, Kavo, "
            "or raw ScreenGuis) and translate/compile its entire UI layout onto the custom Sift UI library.\n\n"
            "Here is the Sift UI library API reference and layout documentation:\n"
            "----------------------------------------------------\n"
            "1. Initialization:\n"
            "   local Sift = loadstring(game:HttpGet(\"https://raw.githubusercontent.com/friefrie243-cmd/sift/main/sift/resources/sift_ui_library.lua\"))()\n\n"
            "2. Window Creation:\n"
            "   local Window = Sift:CreateWindow({\n"
            "       Title = \"Sift Premium\",\n"
            "       Subtitle = \"v1.0.0\",\n"
            "       Size = UDim2.new(0, 580, 0, 400), -- optional\n"
            "       ToggleKey = Enum.KeyCode.RightShift\n"
            "   })\n\n"
            "3. Tab Creation:\n"
            "   local Tab = Window:CreateTab(\"Tab Name\")\n\n"
            "4. Add UI Elements onto Tab:\n"
            "   - Section: Tab:AddSection(\"Section Name\")\n"
            "   - Label: Tab:AddLabel(\"Label Text\")\n"
            "   - Paragraph: Tab:AddParagraph({ Title = \"Title\", Content = \"Content\" })\n"
            "   - Button: Tab:AddButton({ Title = \"Button Text\", Callback = function() ... end })\n"
            "   - Toggle: Tab:AddToggle({ Title = \"Toggle Text\", Default = false, Flag = \"ToggleFlag\", Callback = function(state) ... end })\n"
            "   - Slider: Tab:AddSlider({ Title = \"Slider Text\", Min = 0, Max = 100, Default = 50, Flag = \"SliderFlag\", Callback = function(value) ... end })\n"
            "   - Dropdown: Tab:AddDropdown({ Title = \"Dropdown Text\", Options = {\"Opt1\", \"Opt2\"}, Default = \"Opt1\", Multi = false, Flag = \"DropdownFlag\", Callback = function(selected) ... end })\n"
            "   - Input: Tab:AddInput({ Title = \"Input Text\", Placeholder = \"Type here...\", Default = \"\", Flag = \"InputFlag\", Callback = function(text, enterPressed) ... end })\n"
            "   - Keybind: Tab:AddKeybind({ Title = \"Keybind Text\", Default = Enum.KeyCode.F, Flag = \"KeybindFlag\", Callback = function() ... end })\n"
            "   - ColorPicker: Tab:AddColorPicker({ Title = \"Color Picker\", Default = Color3.fromRGB(45, 25, 110), Flag = \"ColorFlag\", Callback = function(color) ... end })\n"
            "   - Divider: Tab:AddDivider()\n"
            "----------------------------------------------------\n\n"
            "CRITICAL CONVERSION RULES:\n"
            "1. Rewrite the UI layout of the input script using Sift UI.\n"
            "2. Map every original button click, toggle switch, slider change, dropdown selection, and text input to the corresponding Sift UI element.\n"
            "3. KEEP all original logic, exploit scripts, local variables, functions, and internal execution blocks completely intact. Do not lose any functional code.\n"
            "4. Return ONLY the fully compiled Lua code. Do not wrap it in markdown block tags (```lua ... ```). Do not include any introductory or explanatory chat response. Your output must begin directly with the script code."
        )
        if sift_ui_code:
            prompt += f"\n\nFor reference, here is the full source code of the Sift UI Library:\n----------------------------------------------------\n{sift_ui_code}\n----------------------------------------------------\n"
        return prompt

    @classmethod
    async def query_llm(cls, system_prompt: str, user_prompt: str) -> str:
        """
        Attempts to query the configured AI endpoints with fallback:
        1. DeepSeek-V3 API (if DEEPSEEK_API_KEY is configured)
        2. OpenAI API (if OPENAI_API_KEY is configured)
        3. Vercel AI renamer fallback (for rename requests only)
        """
        # Strategy 1: DeepSeek API (Standard REST request)
        deepseek_key = Config.DEEPSEEK_API_KEY
        if deepseek_key:
            try:
                url = "https://api.deepseek.com/v1/chat/completions"
                headers = {
                    "Authorization": f"Bearer {deepseek_key}",
                    "Content-Type": "application/json"
                }
                payload = {
                    "model": "deepseek-chat",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    "temperature": 0.2,
                    "max_tokens": 8000
                }
                async with aiohttp.ClientSession() as session:
                    async with session.post(url, json=payload, headers=headers, timeout=35) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            content = data["choices"][0]["message"]["content"].strip()
                            return cls._clean_code(content)
                        else:
                            print(f"[!] DeepSeek API status error {resp.status}: {await resp.text()}")
            except Exception as e:
                print(f"[!] DeepSeek API call failed: {e}")

        # Strategy 2: OpenAI API
        openai_key = Config.OPENAI_API_KEY
        if openai_key:
            try:
                url = "https://api.openai.com/v1/chat/completions"
                headers = {
                    "Authorization": f"Bearer {openai_key}",
                    "Content-Type": "application/json"
                }
                payload = {
                    "model": "gpt-4o",
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    "temperature": 0.2
                }
                async with aiohttp.ClientSession() as session:
                    async with session.post(url, json=payload, headers=headers, timeout=35) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            content = data["choices"][0]["message"]["content"].strip()
                            return cls._clean_code(content)
                        else:
                            print(f"[!] OpenAI API status error {resp.status}: {await resp.text()}")
            except Exception as e:
                print(f"[!] OpenAI API call failed: {e}")

        # Strategy 3: Vercel Free Renamer (final fallback)
        try:
            url = "https://renamer-api.vercel.app/api/rename"
            headers = {
                "x-api-key": "33ms-DHJHS-24633",
                "Content-Type": "application/json"
            }
            async with aiohttp.ClientSession() as session:
                async with session.post(url, json={"code": user_prompt}, headers=headers, timeout=35) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data.get("renamedCode", user_prompt)
        except Exception as e:
            print(f"[!] Vercel renamer fallback failed: {e}")

        return f"-- [AI Error] No AI provider responded successfully.\n\n{user_prompt}"

    @classmethod
    def _clean_code(cls, code: str) -> str:
        """Strip markdown blocks if returned by the LLM."""
        cleaned = code.strip()
        if cleaned.startswith("```"):
            cleaned = re.sub(r"^```(?:lua)?\n", "", cleaned)
            cleaned = re.sub(r"\n```$", "", cleaned)
        return cleaned.strip()

    @staticmethod
    def _get_reconstruct_system_prompt() -> str:
        return (
            "You are a professional Lua deobfuscation and code restoration assistant.\n"
            "Your task is to take a partial, truncated, or mock-heavy deobfuscated Lua script (from a dynamic dumper/logger) "
            "and reconstruct it into its original complete format. You will be provided with the partial/mocked code AND "
            "the original obfuscated source code for reference.\n\n"
            "CRITICAL INSTRUCTIONS:\n"
            "1. Match the hooked/assigned variables and functions in the partial code (e.g. module.Raycast = function(...) end) "
            "to their corresponding actual function bodies in the original obfuscated source.\n"
            "2. Extract the actual logic, conditions, calculations, and loops from the original source and write them "
            "inside the placeholder/empty functions (e.g. reconstruct function(...) end with the real body).\n"
            "3. Clean up the script: remove any boilerplate mock library tables (like string = { ... }, math = { ... }) and "
            "only keep the actual restored exploit/script logic.\n"
            "4. Fix any syntax errors or incomplete blocks.\n"
            "5. Return ONLY the reconstructed/repaired Lua code. Do not wrap in markdown blocks, and do not write any introductory or explanatory chat response."
        )

    @classmethod
    async def rename(cls, code: str) -> str:
        """Rename cryptic variables semantically using AI."""
        if not code or not code.strip():
            return ""
        system = cls._get_rename_system_prompt()
        user = f"Please rename the variables in this Lua code:\n\n{code}"
        return await cls.query_llm(system, user)

    @classmethod
    async def build_with_sift_ui(cls, deobf_code: str) -> str:
        """Translates/compiles existing UI code onto the custom Sift UI library."""
        if not deobf_code or not deobf_code.strip():
            return "-- Empty script provided."
            
        # Try to read the Sift UI library code from file
        sift_ui_path = os.path.join("sift", "resources", "sift_ui_library.lua")
        sift_ui_code = ""
        if os.path.exists(sift_ui_path):
            try:
                with open(sift_ui_path, "r", encoding="utf-8") as f:
                    sift_ui_code = f.read()
            except Exception as e:
                print(f"[!] Warning: Could not read sift_ui_library.lua: {e}")
                
        system = cls._get_sift_ui_system_prompt(sift_ui_code)
        user = f"Please translate this Lua script's UI into the Sift UI library format:\n\n{deobf_code}"
        return await cls.query_llm(system, user)

    @classmethod
    async def reconstruct_partial_output(cls, code: str, original_code: str = "", error_context: str = "") -> str:
        """Reconstructs, completes, and repairs broken or partial deobfuscation outputs using AI."""
        if not code or not code.strip():
            return ""
        system = cls._get_reconstruct_system_prompt()
        user = f"Here is the partial/mocked deobfuscated code:\n\n{code}\n\n"
        if original_code:
            ref_code = original_code if len(original_code) < 200000 else (original_code[:200000] + "\n... [Truncated for length] ...")
            user += f"Here is the original obfuscated input script for reference (reconstruct the logic/functions from here):\n\n{ref_code}\n\n"
        if error_context:
            user += f"Context/Errors observed during extraction:\n{error_context}\n\n"
        user += "Please reconstruct the full, original, cleaned Lua script by inserting the actual logic into the hooked function stubs."
        return await cls.query_llm(system, user)
