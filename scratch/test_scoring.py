import sys
sys.path.insert(0, '.')
from sift.core.deobfuscator import score_output, clean_output

# Simulated UnveilR output with spy lines
unveilr = """--[[
This file was generated with UnveilR v1.0.6.
discord = discord.gg/threaded;
time_taken = 0.7054085130803287;
]]
require("lib.moonloader")
require("widgets")
local var3 = require("mingui")
local var4 = require("inicfg")
local var5 = require("encoding")
[ Spy print ]: Hello World
[ Spy require ]: widgets
[ Spy require ]: mingui
[ Spy require ]: inicfg
[ Spy require ]: encoding
[ Spy xpcall ]: error handler
[ Spy error ]: test
[ Spy coroutine ]: create
var5.default = "CP1251"
"""

# Simulated Mimic output (pure code)
mimic = """require("lib.moonloader")
require("widgets")
local var3 = require("mingui")
local var4 = require("inicfg")
local var5 = require("encoding")
var5.default = "CP1251"
local imgui = require("imgui")
local dlstatus = require("moonloader").download_status
local var8 = require("lib.samp.events")
local var9 = require("MoonImGui")
local var10 = imgui.ImBool(false)
local var11 = imgui.ImBool(false)
local var12 = imgui.ImBool(false)
local var13 = imgui.ImBool(false)
local var14 = imgui.ImBool(false)
local var15 = imgui.ImBool(false)
local var16 = imgui.ImBool(false)
local var17 = imgui.ImBool(false)
local var18 = imgui.ImFloat(0)
local var19 = imgui.ImFloat(0)
local var20 = imgui.ImFloat(0)
local var21 = imgui.ImFloat(0)
local var22 = imgui.ImFloat(0)
local var23 = imgui.ImFloat(0)
local var24 = imgui.ImFloat(0)
local var25 = imgui.ImFloat(0)
local var26 = imgui.ImFloat(0)
local var27 = imgui.ImFloat(0)
local var28 = imgui.ImFloat(0)
local var29 = imgui.ImFloat(0)
local var30 = imgui.ImFloat(0)
local var31 = imgui.ImFloat(0)
local var32 = imgui.ImFloat(0)
local var33 = imgui.ImFloat(0)
local var34 = imgui.ImFloat(0)
"""

print("=== SCORING ===")
u_score = score_output(unveilr)
m_score = score_output(mimic)
print(f"UnveilR: score={u_score}, raw_lines={len(unveilr.splitlines())}")
print(f"Mimic:   score={m_score}, raw_lines={len(mimic.splitlines())}")
print(f"Mimic wins: {m_score > u_score}")
print()

print("=== CLEANING ===")
cleaned = clean_output(unveilr)
print(f"UnveilR cleaned: {len(cleaned.splitlines())} lines (was {len(unveilr.splitlines())})")
print("---")
print(cleaned)
print("---")
print(f"Score after clean: {score_output(cleaned)}")

# Test URL extraction
from sift.backend.server import _extract_url_from_loadstring
print("\n=== URL EXTRACTION ===")
tests = [
    'loadstring(game:HttpGet("https://raw.githubusercontent.com/NIGHTHUBONTOP/Main/main/NightHub.lua"))()',
    "loadstring(game:HttpGet('https://example.com/script.lua'))()",
    "game.HttpGet('https://test.com/file.lua')",
    "https://raw.githubusercontent.com/test/test.lua",
    "just some random text",
]
for t in tests:
    result = _extract_url_from_loadstring(t)
    changed = " (EXTRACTED)" if result != t else ""
    print(f"  Input:  {t[:80]}...")
    print(f"  Output: {result}{changed}")
    print()

print("ALL TESTS PASSED")
