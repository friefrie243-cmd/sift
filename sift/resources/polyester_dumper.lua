local a = debug
local b = debug.sethook
local c = debug.getinfo
local d = debug.traceback
local niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa = debug.getinfo

-- Enhanced function body extraction system
local FUNCTION_LOGS = {}
local BODY_EXTRACTION_ENABLED = true

-- Function to log function calls with better body extraction
local function log_function_call(func_name, func_body, line_num)
    local log_key = func_name .. "_" .. tostring(line_num or 0)
    FUNCTION_LOGS[log_key] = {
        type = func_name,
        body = func_body or "NO_BODY",
        line = line_num or 0,
        timestamp = os.time()
    }
    
    if func_body and #func_body > 0 then
        local display_body = func_body
        if #display_body > 200 then
            display_body = func_body:sub(1, 200) .. "...[truncated]"
        end
    end
end

-- Enhanced debug.getinfo with body extraction
local original_debug_getinfo = debug.getinfo
debug.getinfo = function(arg1, arg2)
    if type(arg1) == "function" then
        -- Block dangerous functions
        if arg1 == require or arg1 == load or arg1 == loadstring or arg1 == loadfile or arg1 == dofile or arg1 == pcall or arg1 == xpcall or arg1 == error or arg1 == assert or arg1 == print or arg1 == warn or arg1 == tonumber or arg1 == tostring or arg1 == pairs or arg1 == ipairs or arg1 == next or arg1 == setmetatable or arg1 == getmetatable or arg1 == rawget or arg1 == rawset or arg1 == rawequal or arg1 == select or arg1 == type or arg1 == coroutine.create or arg1 == coroutine.wrap or arg1 == coroutine.resume then
            return nil
        end

        local info = original_debug_getinfo(arg1, "S")
        if info and (info.what == "C" or info.source == "=[C]" or info.short_src == "[C]" or not info.short_src:match("^@")) then
            return nil
        end

        -- Extract function body for Lua functions
        if info and info.what == "Lua" and info.source and info.linedefined then
            local func_body = "Function defined at line " .. (info.linedefined or "unknown")
            if info.short_src and info.short_src ~= "=[C]" then
                func_body = func_body .. " in " .. info.short_src
            end
            log_function_call("debug.getinfo_function", func_body, info.linedefined)
        end

        return original_debug_getinfo(arg1, arg2)
    end
    
    return original_debug_getinfo(arg1, arg2)
end

-- Kill old references
debug.getinfo = nil
c = nil

-- Reinstall with enhanced logging
debug.getinfo = function(arg1, arg2)
    if type(arg1) == "function" then
        if arg1 == require or arg1 == load or arg1 == loadstring or arg1 == loadfile or arg1 == dofile or arg1 == pcall or arg1 == xpcall or arg1 == error or arg1 == assert or arg1 == print or arg1 == warn or arg1 == tonumber or arg1 == tostring or arg1 == pairs or arg1 == ipairs or arg1 == next or arg1 == setmetatable or arg1 == getmetatable or arg1 == rawget or arg1 == rawset or arg1 == rawequal or arg1 == select or arg1 == type or arg1 == coroutine.create or arg1 == coroutine.wrap or arg1 == coroutine.resume then
            return nil
        end

        local info = niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa(arg1, "S")
        if info and (info.what == "C" or info.source == "=[C]" or info.short_src == "[C]" or not info.short_src:match("^@")) then
            return nil
        end

        if info and info.what ~= "Lua" then
            return nil
        end
    end

    return niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa(arg1, arg2)
end

debug.getregistry = function()
    return {}
end

local real_getmetatable = debug.getmetatable
debug.getmetatable = function(v)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" or t == "nil" then
        return nil
    end
    return real_getmetatable(v)
end

local e = load
local f = loadstring or load
local _original_debug_getinfo = debug.getinfo
local LUNR_PROTECTED = {}
local function LUNR_GUARD(fn)
    if type(fn) == "function" then
        LUNR_PROTECTED[fn] = true
    end
    return fn
end

local LOOP_MAX = 30
local global_loop_counter = 0

function check_loop_limit()
    global_loop_counter = global_loop_counter + 1
    if global_loop_counter > LOOP_MAX then
        local trace = d()
        error('lunr: infinite loop detected and stopped')
    end
end

local g = pcall
local h = xpcall
local i = error
local j = type
local k = getmetatable
local l = rawequal
local m = tostring
local n = tonumber
local o = io
local p = os

-- Global typeof implementation
if not typeof then
    getgenv = getgenv or function() return _G end
    getgenv().typeof = function(obj)
        if obj == game then return "Instance" end
        local t = type(obj)
        if t == "table" and rawget(obj, "ClassName") then
            return "Instance"
        end
        if t == "table" and rawget(obj, "__type") then
            return rawget(obj, "__type")
        end
        return t
    end
end
typeof = getgenv().typeof

-- Enhanced task emulation with body extraction
if task == nil then
    task = {}
    task._frame = 0
    task._last_thread = nil
    
    function task.spawn(fn, ...)
        if type(fn) == "function" then
            local info = debug.getinfo(fn, "Sl")
            local func_body = "task.spawn function"
            if info and info.linedefined then
                func_body = func_body .. " at line " .. info.linedefined
            end
            log_function_call("task.spawn", func_body, debug.getinfo(2, "l").currentline)
        end
        
        task._last_thread = coroutine.create(function() return true end)
        
        if type(fn) == "function" then
            pcall(fn, ...)
        elseif type(fn) == "thread" then
            pcall(coroutine.resume, fn, ...)
        else
            error("invalid argument #1 to 'spawn' (function or thread expected)", 2)
        end
        
        return task._last_thread
    end
    
    function task.wait(sec)
        global_loop_counter = 0
        task._frame = task._frame + 1
        return
    end
end

-- Enhanced function wrappers with body logging
local function wrap_function(func_name, original_func)
    return function(...)
        local args = {...}
        local caller_info = debug.getinfo(2, "l")
        
        if type(original_func) == "function" then
            local func_info = debug.getinfo(original_func, "Sl")
            local func_body = "Function with " .. #args .. " arguments"
            if func_info and func_info.what == "Lua" and func_info.linedefined then
                func_body = func_body .. " defined at line " .. func_info.linedefined
            end
            log_function_call(func_name, func_body, caller_info and caller_info.currentline)
        end
        
        FUNCTION_LOGS[func_name] = (FUNCTION_LOGS[func_name] or 0) + 1
        return original_func(...)
    end
end

-- Apply enhanced wrappers
pcall = wrap_function("pcall", pcall)
xpcall = wrap_function("xpcall", xpcall)

if coroutine then
    if coroutine.create then
        coroutine.create = wrap_function("coroutine.create", coroutine.create)
    end
    if coroutine.wrap then
        coroutine.wrap = wrap_function("coroutine.wrap", coroutine.wrap)
    end
end

if not spawn then spawn = function(fn, ...) return task and task.spawn(fn, ...) end end
spawn = wrap_function("spawn", spawn)
delay = wrap_function("delay", delay)

if hookfunction then
    hookfunction = wrap_function("hookfunction", hookfunction)
end

if getfenv then
    getfenv = wrap_function("getfenv", getfenv)
end

if loadstring then
    local original_loadstring = loadstring
    loadstring = function(str)
        log_function_call("loadstring", "Content: " .. (str:sub(1, 100) .. (#str > 100 and "..." or "")), debug.getinfo(2, "l").currentline)
        return original_loadstring(str)
    end
end

if require then
    local original_require = require
    require = function(module)
        log_function_call("require", "Module: " .. tostring(module), debug.getinfo(2, "l").currentline)
        return original_require(module)
    end
end

-- Event connection wrapper
local original_connect = nil
local function enhance_event_connect(obj)
    if obj and obj.Connect then
        original_connect = obj.Connect
        obj.Connect = function(self, fn)
            if type(fn) == "function" then
                local info = debug.getinfo(fn, "Sl")
                local func_body = "Event connection function"
                if info and info.linedefined then
                    func_body = func_body .. " at line " .. info.linedefined
                end
                log_function_call("Event.Connect", func_body, debug.getinfo(2, "l").currentline)
            end
            return original_connect(self, fn)
        end
    end
end

-- [Continue with rest of original lunr code...]
-- (Rest of the code would be the same as original)
local a = debug
local b = debug.sethook
local c = debug.getinfo
local d = debug.traceback
local niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa = debug.getinfo

-- Kill the old references that scripts might have captured
debug.getinfo = nil   -- immediately nuke the global one
c = nil               -- also nuke your own alias if you want to be extra mean

-- Now install the lying version
debug.getinfo = function(arg1, arg2)
    -- Case 1: called with a function (most dangerous case)
    if type(arg1) == "function" then
        -- Block all known builtins that leak source
        if arg1 == require
        or arg1 == load
        or arg1 == loadstring
        or arg1 == loadfile
        or arg1 == dofile
        or arg1 == pcall
        or arg1 == xpcall
        or arg1 == error
        or arg1 == assert
        or arg1 == print
        or arg1 == warn
        or arg1 == tonumber
        or arg1 == tostring
        or arg1 == pairs
        or arg1 == ipairs
        or arg1 == next
        or arg1 == setmetatable
        or arg1 == getmetatable
        or arg1 == rawget
        or arg1 == rawset
        or arg1 == rawequal
        or arg1 == select
        or arg1 == type
        or arg1 == coroutine.create
        or arg1 == coroutine.wrap
        or arg1 == coroutine.resume
        then
            return nil
        end

        -- Extra paranoid: anything that smells like a C function in fengari
        local info = niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa(arg1, "S")
        if info and (info.what == "C" or info.source == "=[C]" or info.short_src == "[C]" or not info.short_src:match("^@")) then
            return nil
        end

        -- Also kill anything without Lua source that isn't protected by us
        if info and info.what ~= "Lua" then
            return nil
        end
    end

    -- Case 2: called with level number (debug.getinfo(1), debug.getinfo(2), etc)
    -- We usually still allow this so normal stack walking somewhat works
    -- But if you want nuclear mode → just return nil here too
    -- return nil   -- uncomment if you want to break EVERY getinfo call

    -- Normal fallback (only reaches here for real Lua functions + level calls)
    return niggerdawdjlsjgasdklajklwdjsajiwdjaskljwdsa(arg1, arg2)
end

-- Optional: also nuke debug.getregistry completely (very common leak vector)
debug.getregistry = function()
    return {}   -- boring empty table
end

-- Optional: fuck with getmetatable on primitives
local real_getmetatable = debug.getmetatable
debug.getmetatable = function(v)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" or t == "nil" then
        return nil  -- lie like normal Lua 5.1–5.4
    end
    return real_getmetatable(v)
end
local e = load
local f = loadstring or load
local _original_debug_getinfo = debug.getinfo  -- Preserve original for anti-tamper checks
local LUNR_PROTECTED = {}
local function LUNR_GUARD(fn)
    if type(fn) == "function" then
        LUNR_PROTECTED[fn] = true
    end
    return fn
end
-- Anti-infinite-loop protection
local LOOP_MAX = 30       -- global hook budget before we abort
local global_loop_counter = 0

function check_loop_limit()
    global_loop_counter = global_loop_counter + 1
    if global_loop_counter > LOOP_MAX then
        local trace = d()
        error('lunr: infinite loop detected and stopped')
    end
end
local g = pcall
local h = xpcall
local i = error
local j = type
local k = getmetatable
local l = rawequal
local m = tostring
local n = tonumber
local o = io
local p = os

-- Global typeof implementation
if not typeof then
    getgenv = getgenv or function() return _G end
    getgenv().typeof = function(obj)
        if obj == game then return "userdata" end -- Fix for user check
        local t = type(obj)
        if t == "table" and rawget(obj, "ClassName") then
            return "Instance"
        end
        if t == "table" and rawget(obj, "__type") then
            return rawget(obj, "__type")
        end
        return t
    end
end
typeof = getgenv().typeof

-- Enhanced `task` emulation for Roblox-like scheduling
if task == nil then
    task = {}
    task._frame = 0
    task._last_thread = nil  -- Store last created thread
    _G.__heartbeat_callbacks = _G.__heartbeat_callbacks or {}
    task._add_heartbeat = function(fn)
        if type(fn) == "function" then table.insert(_G.__heartbeat_callbacks, fn) end
    end
    
    function task.spawn(fn, ...)
        -- Create and store thread
        task._last_thread = coroutine.create(function() return true end)
        
        -- Execute the function
        if type(fn) == "function" then
            pcall(fn, ...)
        elseif type(fn) == "thread" then
            pcall(coroutine.resume, fn, ...)
        else
            error("invalid argument #1 to 'spawn' (function or thread expected)", 2)
        end
        
        -- Return the stored thread
        return task._last_thread
    end
    
    function task.wait(sec)
        global_loop_counter = 0 -- Reset loop counter to prevent false positives
        task._frame = task._frame + 1
        return
    end
end

local old_os = os   -- keep reference if you still want date/time

local fake_os = {
    clock     = old_os.clock,
    date      = old_os.date,
    difftime  = old_os.difftime,
    time      = old_os.time,

    -- explicitly block dangerous stuff
    execute   = function(...) error("os.execute is disabled", 0) end,
    exit      = function(...) error("os.exit is disabled", 0) end,
    remove    = function(...) error("os.remove is disabled", 0) end,
    rename    = function(...) error("os.rename is disabled", 0) end,
    tmpname   = function(...) error("os.tmpname is disabled", 0) end,
}

-- Make it look almost real (many scripts check type(os.execute) == "function")
setmetatable(fake_os, {
    __index = function(t, k)
        if k == "execute" or k == "exit" or k == "remove" or k == "rename" or k == "tmpname" then
            return function() error("Blocked os."..k.." call", 0) end
        end
        return nil   -- or error("os."..tostring(k).." is disabled")
    end,
    __newindex = function()
        error("cannot modify os table", 0)
    end,
    __metatable = "Locked os proxy"
})

-- Final replacement

-- Bonus: also nuke it from getrenv() if you control getrenv
local real_getrenv = getrenv
getrenv = function()
    local env = real_getrenv and real_getrenv() or _G
    env.os = fake_os     -- force it again
    return env
end
local script = script or {Name = "Lunr", ClassName = "LocalScript"}

-- Create Enum for MessageType
local Enum = Enum or {
    MessageType = {
        MessageOutput = "Output",
        MessageWarning = "Warning",
        MessageError = "Error"
    }
}

-- Services storage
local services_cache = {}

local game = game or {
    GetService = function(self, service)
        if services_cache[service] then
            return services_cache[service]
        end

        if service == "RunService" then
            local rs = {
                Heartbeat = {
                    Connect = function(self, fn)
                        task._add_heartbeat(fn)
                        return {
                            Disconnect = function() end
                        }
                    end,
                    Wait = function(self)
                        for _ = 1, 30 do
                            for _, cb in ipairs(_G.__heartbeat_callbacks or {}) do
                                pcall(cb, 0.016)
                            end
                        end
                        return 0.016
                    end
                }
            }
            services_cache[service] = rs
            return rs

        elseif service == "LogService" then
            local ls = {
                MessageOut = {
                    Connect = function(self, fn)
                        -- When print is called, fire the callback with the message
                        local original_print = print
                        _G.__logservice_callbacks = _G.__logservice_callbacks or {}
                        table.insert(_G.__logservice_callbacks, fn)
                        
                        if not _G.__print_hooked then
                            print = function(...)
                                local args = {...}
                                local msg = table.concat(args, "\t")
                                for _, cb in ipairs(_G.__logservice_callbacks or {}) do
                                    pcall(cb, msg, Enum.MessageType.MessageOutput)
                                end
                                original_print(...)
                            end
                            _G.__print_hooked = true
                        end
                        
                        return {
                            Disconnect = function() end
                        }
                    end
                }
            }
            services_cache[service] = ls
            return ls

        elseif service == "HttpService" then
            local hs = {
                GenerateGUID = function(self, secure)
                    return string.format("%08x-%04x-%04x-%04x-%12x",
                        math.random(0, 0xffffffff), math.random(0, 0xffff),
                        math.random(0, 0xffff), math.random(0, 0xffff),
                        string.format("%.4X", math.random(0, 0xffff)))
                end,
                JSONDecode = function(self, json_str)
                    -- Basic JSON decoder
                    local function parse_json(str)
                        str = str:match("^%s*(.-)%s*$") -- trim
                        if str == "null" then return nil end
                        if str == "true" then return true end
                        if str == "false" then return false end
                        if str:match("^%-?%d+%.?%d*$") then return tonumber(str) end
                        if str:match('^".*"$') then return str:sub(2, -2):gsub('\\"', '"') end
                        if str:match('^"%s*"$') or str:match("^'%s*'$") then 
                            return str:sub(2, -2) 
                        end
                        if str:match("^%[.*%]$") then
                            local result = {}
                            local content = str:sub(2, -2)
                            if content:len() == 0 then return result end
                            
                            local depth = 0
                            local current = ""
                            for i = 1, content:len() do
                                local c = content:sub(i, i)
                                if (c == "[" or c == "{") then
                                    depth = depth + 1
                                    current = current .. c
                                elseif (c == "]" or c == "}") then
                                    depth = depth - 1
                                    current = current .. c
                                elseif c == "," and depth == 0 then
                                    table.insert(result, parse_json(current))
                                    current = ""
                                else
                                    current = current .. c
                                end
                            end
                            if current:len() > 0 then
                                table.insert(result, parse_json(current))
                            end
                            return result
                        end
                        return str
                    end
                    return parse_json(json_str)
                end
            }
            services_cache[service] = hs
            return hs

        elseif service == "RbxAnalyticsService" then
            local ras = {
                GetClientId = function(self)
                    return string.format("%08x-%04x-%04x-%04x-%12x",
                        math.random(0, 0xffffffff), math.random(0, 0xffff),
                        math.random(0, 0xffff), math.random(0, 0xffff),
                        string.format("%.4X", math.random(0, 0xffff)),
                        math.random(0, 0xffffffffffff))
                end
            }
            services_cache[service] = ras
            return ras

        elseif service == "Players" then
            local players = {
                LocalPlayer = {
                    UserId = 1,
                    Name = "Lunr",
                    DisplayName = "Lunr",
                    AccountAge = 69143,
                    ClassName = "Player",
                    WaitForChild = function(self, name, timeout)
                        if name == "PlayerGui" then
                            return { Name = "PlayerGui", ClassName = "PlayerGui" }
                        end
                        return { Name = name, ClassName = "Instance" }
                    end
                }
            }
            players.GetPropertyChangedSignal = function(self, prop)
                return { Connect = function(self, fn) pcall(fn) return { Disconnect = function() end } end, Wait = function() end }
            end
            services_cache[service] = players
            return players
        else
            -- Return empty service that acts like a real non-existent service
            local empty_service = {}
            services_cache[service] = empty_service
            return empty_service
        end
    end,
    
    GetChildren = function(self)
        return {
            game:GetService("RunService"),
            game:GetService("LogService"),
            game:GetService("HttpService"),
            game:GetService("Players"),
            game:GetService("RbxAnalyticsService")
        }
    end,

    ClassName = "DataModel",
    Name = "game",
    HttpGet = function(self, url)
         -- Hint for next loadstring result name
         if type(url) == "string" then
             local name = url:match("([^/]+)$") 
             if name then 
                 -- Clean name
                 name = name:gsub("[^%w_]", "")
                 if #name > 0 then
                    _G._NextNameHint = name:sub(1,1):upper() .. name:sub(2)
                 end
             end
             -- Return a stub so loadstring(...)() returns a table with CreateWindow (avoids nil index on url)
             if url:match("library") or url:match("Tora") or url:match("raw%.githubusercontent") then
                 return "return { CreateWindow = function(self, ...) return {} end, Create = function(self, ...) return {} end }"
             end
         end
         return "" -- Return empty string or actual content if fetchable
    end
}

-- Make services accessible directly on game object (e.g., game.HttpService)
-- Env-check bypass: allow game.ServiceName so pcall(game.HttpService) succeeds and script continues past anti-env checks
setmetatable(game, {
    __index = function(self, key)
        if key == "ClassName" or key == "Name" then
            return rawget(game, key)
        end
        return game:GetService(key)
    end,
    __call = function(self)
        error("attempt to call a Instance value", 2)
    end,
    __pairs = function()
        error("attempt to iterate over game (not iterable)", 2)
    end,
    __ipairs = function()
        error("attempt to iterate over game (not iterable)", 2)
    end
})

-- Instance emulation (env-check bypass: support TextButton, Parent, MouseButton1Click, etc.)
local Instance = Instance or {}
Instance.new = function(class_name)
    local obj = {
        ClassName = class_name,
        Name = class_name,
        Parent = nil,
        Size = nil,
        Text = ""
    }
    if class_name == "TextButton" or class_name == "GuiButton" then
        obj.MouseButton1Click = {
            Connect = function(self, fn)
                pcall(fn)
                return { Disconnect = function() end }
            end
        }
    end
    setmetatable(obj, {
        __index = function(self, key)
            local raw = rawget(obj, key)
            if raw ~= nil then return raw end
            return function()
                error("attempt to call a nil value (method '" .. key .. "')", 2)
            end
        end,
        __call = function(self)
            error("attempt to call a " .. class_name .. " value", 2)
        end
    })
    return obj
end

-- Sync getfenv with _G
local original_getfenv = getfenv
getfenv = function(level)
    if level == nil or level == 1 then
        return _G
    end
    return original_getfenv(level)
end

local workspace = workspace or {Name = "Workspace", ClassName = "Workspace"}
local q = {}
q.__index = q
local r = {
    MAX_DEPTH = 15,
    MAX_TABLE_ITEMS = 150,
    OUTPUT_FILE = "dumped_output.lua",
    VERBOSE = false,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 9999999.0,
    MAX_REPEATED_LINES = 10,
    MIN_DEOBF_LENGTH = 75,
    MAX_OUTPUT_SIZE = 100 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true,
    TASK_WAIT_LIMIT = 30,
    LOOP_THRESHOLD = 30
}
local s = arg and arg[3]
local t = {
    output = {},
    indent = 0,
    registry = {},
    reverse_registry = {},
    names_used = {},
    parent_map = {},
    property_store = {},
    call_graph = {},
    variable_types = {},
    string_refs = {},
    proxy_id = 0,
    callback_depth = 0,
    pending_iterator = false,
    last_http_url = nil,
    last_emitted_line = nil,
    repetition_count = 0,
    current_size = 0,
    lunr_counter = 0,
    library_counter = 0,
    variable_counter = 0,
    var_counter = 0,
    filesystem = {files = {}, folders = {}},
    drawing_objects = {},
    closure_tags = {},
    readonly = {},
    script_sources = {},
    shadow_props = {},
    scripts = {script},
    script_sources = {[script] = ""},
    thread_identity = 7
}
local s = arg[3] or "NoKey"
local u = tonumber(arg[4]) or tonumber(arg[3]) or 123456789
local v = {}
local function w(x)
    if j(x) ~= "table" then
        return false
    end
    local y, z =
        pcall(
        function()
            return rawget(x, v) == true
        end
    )
    return y and z
end
local function A(x)
    if j(x) == "number" then
        return x
    end
    if w(x) then
        return rawget(x, "__value") or 0
    end
    return 0
end
local e = loadstring or load
local B = print
local C = warn or function()
    end
local D = pairs
local function LUNR_STR(x)
    return x
end
local E = ipairs
local j = type
local m = tostring
local F = {}
local function G(x)
    if j(x) ~= "table" then
        return false
    end
    local y, z =
        pcall(
        function()
            return rawget(x, F) == true
        end
    )
    return y and z
end
local function H(x)
    if not G(x) then
        return nil
    end
    return rawget(x, "__proxy_id")
end
local function I(J)
    if j(J) ~= "string" then
        return '"'\n    end\n    local K = {}\n    local L, M = 1, #J\n    local function N(O)\n        -- Handle numeric escape sequences first (multi-digit)\n        O = O:gsub("\\(%d%d%d)", function(num) return string.char(tonumber(num)) end)\n        O = O:gsub("\\(%d%d)", function(num) return string.char(tonumber(num)) end)\n        O = O:gsub("\\(%d)", function(num) return string.char(tonumber(num)) end)\n        -- Handle standard escape sequences\n        return O:gsub(\n            "\\\\(.)",\n            function(P)\n                if P:match('[abfnrtv\\\\%\'%\\"%[%]0-9xu]') then
                    return "" .. P
                end
                return P
            end
        )
    end
    local function Q(R)
        if not R or R == '"' then\n            return ""\n        end\n        -- Normalize common obfuscator formatting to reduce parse errors\n        R = R:gsub("%]%]%s*return%(", "]]\nreturn (")\n        R = R:gsub("return%(", "return (")\n\n        R =\n            R:gsub(\n            "0[bB]([01_]+)",\n            function(S)\n                local T = S:gsub("_", '"')
                local U = n(T, 2)
                return U and m(U) or "0"
            end
        )
        R =
            R:gsub(
            "0[xX]([%x_]+)",
            function(S)
                local T = S:gsub("_", "")
                return "0x" .. T
            end
        )
        while R:match("%d_+%d") do
            R = R:gsub("(%d)_+(%d)", "%1%2")
        end
        local V = {{"+=", "+"}, {"-=", "-"}, {"*=", "*"}, {"/=", "/"}, {"%%=", "%%"}, {"%^=", "^"}, {"%.%.=", ".."}}
        for W, X in ipairs(V) do
            local Y, Z = X[1], X[2]
            R =
                R:gsub(
                "([%a_][%w_]*)%s*" .. Y,
                function(_)
                    return _ .. " = " .. _ .. " " .. Z .. " "
                end
            )
            R =
                R:gsub(
                "([%a_][%w_]*%.[%a_][%w_%.]+)%s*" .. Y,
                function(_)
                    return _ .. " = " .. _ .. " " .. Z .. " "
                end
            )
            R =
                R:gsub(
                "([%a_][%w_]*%b[])%s*" .. Y,
                function(_)
                    return _ .. " = " .. _ .. " " .. Z .. " "
                end
            )
        end

        -- De-aliasing pass
        local aliases = {}
        for alias, module, func in R:gmatch("local%s+([%a_][%w_]*)%s*=%s*([%a_][%w_]*)%.([%a_][%w_]*)") do
            if module == "string" or module == "table" or module == "bit" or module == "bit32" or module == "math" then
                aliases[alias] = module .. "." .. func
            end
        end
        for alias, full in pairs(aliases) do
            R = R:gsub("([^%w_])" .. alias .. "%(", "%1" .. full .. "(")
            R = R:gsub("^" .. alias .. "%(", full .. "(")
        end
        -- Variable renaming pass - replace unrecognizable local variables with v[Number]
        local variable_map = {}
        local function is_readable_name(name)
            -- Deny variables with quotes immediately
            if name:match('"') or name:match("'") then\n                return false\n            end\n            -- Check if name is readable English or common programming terms\n            if name:match("^[%a_][%w%d]*$") or name:match("^_[%w][%w_]*$") then\n                -- Hexadecimal-style names like _0x1a2b3c are always considered unreadable\n                if name:match("^_0[xX]") then\n                    return false\n                end\n                local common_names = {\n                    ["i"] = true, ["j"] = true, ["k"] = true, ["v"] = true, ["x"] = true, ["y"] = true, ["z"] = true,\n                    ["temp"] = true, ["tmp"] = true, ["count"] = true, ["index"] = true, ["idx"] = true,\n                    ["len"] = true, ["length"] = true, ["size"] = true, ["num"] = true, ["number"] = true,\n                    ["str"] = true, ["string"] = true, ["text"] = true, ["data"] = true, ["value"] = true,\n                    ["result"] = true, ["output"] = true, ["return"] = true, ["ret"] = true, ["val"] = true,\n                    ["func"] = true, ["function"] = true, ["fn"] = true, ["method"] = true, ["callback"] = true,\n                    ["obj"] = true, ["object"] = true, ["item"] = true, ["element"] = true, ["elem"] = true,\n                    ["arr"] = true, ["array"] = true, ["list"] = true, ["table"] = true, ["map"] = true,\n                    ["key"] = true, ["value"] = true, ["pair"] = true, ["entry"] = true, ["node"] = true,\n                    ["parent"] = true, ["child"] = true, ["next"] = true, ["prev"] = true, ["current"] = true,\n                    ["first"] = true, ["last"] = true, ["start"] = true, ["begin"] = true, ["end"] = true,\n                    ["true"] = true, ["false"] = true, ["nil"] = true, ["self"] = true, ["this"] = true,\n                    ["module"] = true, ["require"] = true, ["import"] = true, ["export"] = true,\n                    ["local"] = true, ["global"] = true, ["const"] = true, ["var"] = true, ["let"] = true,\n                    ["game"] = true, ["workspace"] = true, ["players"] = true, ["script"] = true,\n                    ["task"] = true, ["t"] = true,\n                    ["event"] = true, ["signal"] = true, ["connect"] = true, ["disconnect"] = true,\n                    ["new"] = true, ["create"] = true, ["destroy"] = true, ["remove"] = true, ["delete"] = true,\n                    ["get"] = true, ["set"] = true, ["is"] = true, ["has"] = true, ["can"] = true, ["do"] = true,\n                    ["if"] = true, ["then"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true,\n                    ["while"] = true, ["for"] = true, ["in"] = true, ["do"] = true, ["repeat"] = true, ["until"] = true,\n                    ["function"] = true, ["return"] = true, ["break"] = true, ["continue"] = true, ["makefolder"] = true,\n                    ["end"] = true, ["isfile"] = true, ["isfolder"] = true, ["is"] = true, ["has"] = true, ["can"] = true\n                }\n                if common_names[name:lower()] then\n                    return true\n                end\n                -- Check if it's mostly readable characters (not random gibberish)\n                -- More strict: must have reasonable vowel-to-consonant ratio and not look like base64 or encoded\n                local lower_name = name:lower()\n                local vowels = 0\n                local consonants = 0\n                for char in lower_name:gmatch("[a-z]") do\n                    if char:match("[aeiou]") then\n                        vowels = vowels + 1\n                    else\n                        consonants = consonants + 1\n                    end\n                end\n                -- Must have reasonable vowel ratio and not be too long or look like encoded strings\n                if vowels > 0 and consonants > 0 and vowels / (vowels + consonants) >= 0.3 and #name <= 10 then\n                    return true\n                end\n            end\n            return false\n        end\n        \n        -- Find all local variable declarations (including hexadecimal-style names)\n        for var_name in R:gmatch("local%s+([%a_][%w_]*)") do\n            if not is_readable_name(var_name) and not variable_map[var_name] then\n                t.variable_counter = t.variable_counter + 1\n                if t.variable_counter == 1 then\n                    variable_map[var_name] = "v1"\n                elseif t.variable_counter == 2 then\n                    variable_map[var_name] = "v2"\n                elseif t.variable_counter == 3 then\n                    variable_map[var_name] = "v3"\n                else\n                    variable_map[var_name] = "v" .. t.variable_counter\n                end\n            end\n        end\n        for var_name in R:gmatch("local%s+(_0[xX][%w_]*)") do\n            if not is_readable_name(var_name) and not variable_map[var_name] then\n                t.variable_counter = t.variable_counter + 1\n                if t.variable_counter == 1 then\n                    variable_map[var_name] = "v1"\n                elseif t.variable_counter == 2 then\n                    variable_map[var_name] = "v2"\n                elseif t.variable_counter == 3 then\n                    variable_map[var_name] = "v3"\n                else\n                    variable_map[var_name] = "v" .. t.variable_counter\n                end\n            end\n        end\n        for var_name in R:gmatch("local%s+(_[%w][%w_]*)") do\n            if not is_readable_name(var_name) and not variable_map[var_name] then\n                t.variable_counter = t.variable_counter + 1\n                if t.variable_counter == 1 then\n                    variable_map[var_name] = "v1"\n                elseif t.variable_counter == 2 then\n                    variable_map[var_name] = "v2"\n                elseif t.variable_counter == 3 then\n                    variable_map[var_name] = "v3"\n                else\n                    variable_map[var_name] = "v" .. t.variable_counter\n                end\n            end\n        end\n        \n        -- Replace variables throughout the code (identifier-boundary aware)\n        for original_var, new_var in pairs(variable_map) do\n            R = R:gsub("%f[%w_]" .. original_var .. "%f[^%w_]", new_var)\n        end\n        \n        -- Additional pass: replace any remaining hexadecimal-style variables (identifier-boundary aware)\n        local hex_var_counter = t.variable_counter\n        R = R:gsub("%f[%w_](_0[xX][%w_]*)%f[^%w_]", function(match)\n            if not variable_map[match] then\n                hex_var_counter = hex_var_counter + 1\n                if hex_var_counter == 1 then\n                    variable_map[match] = "v1"\n                elseif hex_var_counter == 2 then\n                    variable_map[match] = "v2"\n                elseif hex_var_counter == 3 then\n                    variable_map[match] = "v3"\n                else\n                    variable_map[match] = "v" .. hex_var_counter\n                end\n            end\n            return variable_map[match]\n        end)\n        \n        -- Fix scoping issues: ensure all replaced variables are properly accessible\n        -- Add global declarations for any variables that might be accessed before declaration\n        local global_declarations = {}\n        for original_var, new_var in pairs(variable_map) do\n            -- Declare all renamed variables globally to prevent undefined reference errors\n            if new_var:match("^v%d+$") then\n                table.insert(global_declarations, new_var .. " = " .. new_var .. " or nil")\n            end\n        end\n        if #global_declarations > 0 then\n            R = "-- Auto-generated variable declarations\n" .. table.concat(global_declarations, "\n") .. "\n" .. R\n        end\n        -- Wrap probable deobfuscator calls: Function("\229...", "\126...")\n        -- We look for calls where at least one argument is a complex escaped string\n        R = R:gsub("([%a_][%w_.]+)%s*%((%s*\"[^\"]*\\[%d]+\"[^\"]*\"%s*,?%s*\"?[^\"]*\"?%s*%)", "LUNR_STR(%1(%2))")\n        \n        -- Loader pattern detection - capture patterns like return _Loader(_Code)(...)\n        R = R:gsub("return%s+([%a_][%w_]*)%s*%(([%a_][%w_]*)%)%s*%(([^%)]+)%)", function(loader, code, args)\n            -- Add debug print before the return statement\n            return "print(" .. loader .. "(" .. code .. ")(" .. args .. "))\nreturn " .. loader .. "(" .. code .. ")(" .. args .. ")"\n        end)\n        \n        -- Hook pattern detection - capture patterns like hook(print, loadstring)\n        R = R:gsub("hook%s*%(%s*([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*%)", function(target, func)\n            -- Add debug print for hook\n            return "hook(" .. target .. ", " .. func .. ")\nprint(" .. func .. " hooked to " .. target .. ")"\n        end)\n\n        R = R:gsub("([^%w_])continue([^%w_])", "%1_G.LuraphContinue()%2")\n        R = R:gsub("^continue([^%w_])", "_G.LuraphContinue()%1")\n        R = R:gsub("([^%w_])continue$", "%1_G.LuraphContinue()")\n        return R\n    end\n    local function a0(a1)\n        local a2 = 0\n        while a1 <= M and J:byte(a1) == 61 do\n            a2 = a2 + 1\n            a1 = a1 + 1\n        end\n        return a2, a1\n    end\n    local function a3(a4, a5)\n        local a6 = "]" .. string.rep("=", a5) .. "]"\n        local a7, a8 = J:find(a6, a4, true)\n        return a8 or M\n    end\n    local a9 = 1\n    while L <= M do\n        local aa = J:byte(L)\n        if aa == 91 then\n            local a5, ab = a0(L + 1)\n            if ab <= M and J:byte(ab) == 91 then\n                table.insert(K, Q(J:sub(a9, L - 1)))\n                local ac = L\n                local ad = a3(ab + 1, a5)\n                table.insert(K, J:sub(ac, ad))\n                L = ad\n                a9 = L + 1\n            end\n        elseif aa == 45 and L + 1 <= M and J:byte(L + 1) == 45 then\n            table.insert(K, Q(J:sub(a9, L - 1)))\n            local ae = L\n            if L + 2 <= M and J:byte(L + 2) == 91 then\n                local a5, ab = a0(L + 3)\n                if ab <= M and J:byte(ab) == 91 then\n                    local ad = a3(ab + 1, a5)\n                    table.insert(K, J:sub(ae, ad))\n                    L = ad\n                    a9 = L + 1\n                    L = L + 1\n                end\n            end\n            local af = J:find("\\\n", L + 2, true)\n            if af then\n                L = af\n            else\n                L = M\n            end\n            table.insert(K, J:sub(ae, L))\n            a9 = L + 1\n        elseif aa == 34 or aa == 39 or aa == 96 then\n            table.insert(K, Q(J:sub(a9, L - 1)))\n            local ag = aa\n            local ac = L\n            L = L + 1\n            while L <= M do\n                local ah = J:byte(L)\n                if ah == 92 then\n                    L = L + 1\n                elseif ah == ag then\n                    break\n                end\n                L = L + 1\n            end\n            local ai = J:sub(ac + 1, L - 1)\n            ai = N(ai)\n            if ag == 96 then\n                table.insert(K, '"' .. ai:gsub('"', '\\\\"') .. '"')\n            else\n                local aj = string.char(ag)\n                table.insert(K, aj .. ai .. aj)\n            end\n            a9 = L + 1\n        end\n        L = L + 1\n    end\n    table.insert(K, Q(J:sub(a9)))\n    return table.concat(K)\nend\nlocal function ak(al, am)\n    local R, an = e(al, am)\n    if R then\n        return R\n    end\n    B("\\\n[CRITICAL ERROR] Failed to load script!")\n    B("[LUA_LOAD_FAIL] " .. m(an))\n    local ao = tonumber(an:match(":(%d+):"))\n    local ap = an:match("near '([^']+)'")\n    if ap then\n        local a1 = al:find(ap, 1, true)\n        if a1 then\n            local aq = math.max(1, a1 - 50)\n            local ar = math.min(#al, a1 + 50)\n            B("Context around error:")\n            B("..." .. al:sub(aq, ar) .. "...")\n        end\n    end\n    local as = o.open("DEBUG_FAILED_TRANSPILE.lua", "w")\n    if as then\n        as:write(al)\n        as:close()\n        B("[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection")\n    end\n    return nil, an\nend\nlocal function at(O, au)\n    if t.limit_reached then\n        return\n    end\n    if O == nil then\n        return\n    end\n    \n    -- SECURITY: Check for binary patterns and replace with friendly message\n    local O_str = m(O)\n    if O_str:match("^[01]+$") and (#O_str >= 10 or O_str:match("have a nice day!")) then\n        O_str = "have a nice day!"\n    elseif O_str:match("have a nice day!") then\n        O_str = O_str:gsub("have a nice day!", "have a nice day!")\n    end\n    \n    local av = au and "" or string.rep("    ", t.indent)\n    local aw = av .. O_str\n    local ax = #aw + 1\n    if t.current_size + ax > r.MAX_OUTPUT_SIZE then\n        t.limit_reached = true\n        local ay = "-- [CRITICAL] Dump stopped: File size exceeded 10MB limit."\n        table.insert(t.output, ay)\n        t.current_size = t.current_size + #ay\n        error("DUMP_LIMIT_EXCEEDED")\n    end\n\n    if not av then\n        -- Advanced Cycle Detection with iteration limit\n        t.cycle_history = t.cycle_history or {}\n        local current_raw = m(O)\n        table.insert(t.cycle_history, current_raw)\n        if #t.cycle_history > 60 then\n            table.remove(t.cycle_history, 1)\n        end\n        local b_cycle = false\n        local iteration_count = 0\n        for L = 1, 15 do  -- Limit to 15 iterations to prevent infinite loops\n            iteration_count = iteration_count + 1\n            if iteration_count > 1000 then  -- Bypass after 1000 iterations\n                table.insert(t.output, (au and "" or string.rep("    ", t.indent)) .. "-- LOOP_LIMIT_EXCEEDED: Stopped after 1000 iterations")\n                t.limit_reached = true\n                break\n            end\n            if #t.cycle_history >= L * 3 then\n                local match = true\n                for i = 0, L - 1 do\n                    if t.cycle_history[#t.cycle_history - i] ~= t.cycle_history[#t.cycle_history - i - L] or \n                       t.cycle_history[#t.cycle_history - i] ~= t.cycle_history[#t.cycle_history - i - 2 * L] then\n                        match = false\n                        break\n                    end\n                end\n                if match then\n                    b_cycle = true\n                    break\n                end\n            end\n        end\n\n        if b_cycle then\n            t.cycle_miss = 0\n            if not t.in_cycle then\n                table.insert(t.output, string.rep("    ", t.indent) .. "while true do")\n                t.indent = t.indent + 1\n                t.in_cycle = true\n\n                -- emit repeated line ONCE\n                at(O, au, true)   -- original line\n\n                -- then immediately error (unless it's a wait loop) and stop execution\n                local lineStr = m(O)\n                if not (lineStr:find("wait") or lineStr:find("Wait")) then\n                    table.insert(t.output, string.rep("    ", t.indent) .. "error('lunr: infinite loop detected and stopped')")\n                    error('lunr: infinite loop detected and stopped')\n                end\n\n                -- Recalculate aw for current line after exiting cycle\n                aw = au and m(O) or (string.rep("    ", t.indent) .. m(O))\n                ax = #aw + 1\n            else\n                return false\n            end\n        end\n    end\n\n    t.last_emitted_line = aw\n    table.insert(t.output, aw)\n    t.current_size = t.current_size + ax\n    if r.VERBOSE then\n        B(aw)\n    end\n    return true\nend\nlocal function az(O)\n    at("-- " .. m(O or ""), true, true)\nend\nlocal function aA()\n    t.last_emitted_line = nil\n    table.insert(t.output, "")\nend\nlocal function aB()\n    if t.in_cycle then\n        t.indent = t.indent - 1\n        table.insert(t.output, string.rep("    ", t.indent) .. "end")\n        t.in_cycle = false\n    end\n    return table.concat(t.output, "\n")\nend\nlocal function aC(aD)\n    local as = o.open(aD or r.OUTPUT_FILE, "w")\n    if as then\n        as:write(aB())\n        as:close()\n        return true\n    end\n    return false\nend\nlocal function aE(aF)\n    if aF == nil then\n        return "nil"\n    end\n    if j(aF) == "string" then\n        return aF\n    end\n    if j(aF) == "number" or j(aF) == "boolean" then\n        return m(aF)\n    end\n    if j(aF) == "table" then\n        if t.registry[aF] then\n            return t.registry[aF]\n        end\n        if G(aF) then\n            local aG = H(aF)\n            return aG and "proxy_" .. aG or "proxy"\n        end\n    end\n    local y, O = pcall(m, aF)\n    return y and O or "unknown"\nend\nlocal function aH(aF)\n    local O = aE(aF)\n    local aI =\n        O:gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\\\n", "\\\\\n"):gsub("\\\r", "\\\\\r"):gsub("\\\t", "\\\\\t")\n    return '"' .. aI .. '"'\nend\nlocal aJ = {\n    Players = "Players",\n    Workspace = "Workspace",\n    ReplicatedStorage = "ReplicatedStorage",\n    ServerStorage = "ServerStorage",\n    ServerScriptService = "ServerScriptService",\n    StarterGui = "StarterGui",\n    StarterPack = "StarterPack",\n    StarterPlayer = "StarterPlayer",\n    Lighting = "Lighting",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    RunService = "RunService",\n    UserInputService = "UserInputService",\n    TweenService = "TweenService",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    RbxAnalyticsService = "RbxAnalyticsService",\n    TeleportService = "TeleportService",\n    PathfindingService = "PathfindingService",\n    CollectionService = "CollectionService",\n    PhysicsService = "PhysicsService",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    GuiService = "GuiService",\n    HapticService = "HapticService",\n    VRService = "VRService",\n    CoreGui = "CoreGui",\n    Teams = "Teams",\n    InsertService = "InsertService",\n    DataStoreService = "DataStoreService",\n    MessagingService = "MessagingService",\n    TextService = "TextService",\n    TextChatService = "TextChatService",\n    ContentProvider = "ContentProvider",\n    Debris = "Debris"\n}\nlocal aK = {\n    Players = "Players",\n    UserInputService = "UIS",\n    RunService = "RunService",\n    ReplicatedStorage = "ReplicatedStorage",\n    TweenService = "TweenService",\n    Workspace = "Workspace",\n    Lighting = "Lighting",\n    StarterGui = "StarterGui",\n    CoreGui = "CoreGui",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    RbxAnalyticsService = "RbxAnalyticsService",\n    DataStoreService = "DataStoreService",\n    TeleportService = "TeleportService",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    Teams = "Teams",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    CollectionService = "CollectionService",\n    PathfindingService = "PathfindingService",\n    Debris = "Debris"\n}\nlocal aL = {\n    {pattern = "window", prefix = "Window", counter = "window"},\n    {pattern = "tab", prefix = "Tab", counter = "tab"},\n    {pattern = "section", prefix = "Section", counter = "section"},\n    {pattern = "button", prefix = "Button", counter = "button"},\n    {pattern = "toggle", prefix = "Toggle", counter = "toggle"},\n    {pattern = "slider", prefix = "Slider", counter = "slider"},\n    {pattern = "dropdown", prefix = "Dropdown", counter = "dropdown"},\n    {pattern = "textbox", prefix = "Textbox", counter = "textbox"},\n    {pattern = "input", prefix = "Input", counter = "input"},\n    {pattern = "label", prefix = "Label", counter = "label"},\n    {pattern = "keybind", prefix = "Keybind", counter = "keybind"},\n    {pattern = "colorpicker", prefix = "ColorPicker", counter = "colorpicker"},\n    {pattern = "paragraph", prefix = "Paragraph", counter = "paragraph"},\n    {pattern = "notification", prefix = "Notification", counter = "notification"},\n    {pattern = "divider", prefix = "Divider", counter = "divider"},\n    {pattern = "bind", prefix = "Bind", counter = "bind"},\n    {pattern = "picker", prefix = "Picker", counter = "picker"}\n}\nlocal aM = {}\nlocal function aN(aO)\n    aM[aO] = (aM[aO] or 0) + 1\n    return aM[aO]\nend\nlocal function aP(aQ, aR, aS)\n    if not aQ then\n        aQ = "var"\n    end\n    local aT = aE(aQ)\n    if aK[aT] then\n        return aK[aT]\n    end\n    if aS then\n        local aU = aS:lower()\n        for W, aV in ipairs(aL) do\n            if aU:find(aV.pattern) then\n                local a2 = aN(aV.counter)\n                return a2 == 1 and aV.prefix or aV.prefix .. a2\n            end\n        end\n    end\n    if aT == "LocalPlayer" then\n        return "LocalPlayer"\n    end\n    if aT == "Character" then\n        return "Character"\n    end\n    if aT == "Humanoid" then\n        return "Humanoid"\n    end\n    if aT == "HumanoidRootPart" then\n        return "HumanoidRootPart"\n    end\n    if aT == "Camera" then\n        return "Camera"\n    end\n    if aT:match("^Enum%.") or aT == "TweenInfo" or aT == "CFrame" or aT == "Vector3" or aT == "Color3" then\n        return aT\n    end\n    local services = {\n        Players = "Players",\n        CoreGui = "CoreGui",\n        TweenService = "TweenService",\n        RunService = "RunService",\n        UserInputService = "UIS",\n        HttpService = "HttpService",\n        ReplicatedStorage = "ReplicatedStorage",\n        TeleportService = "TeleportService",\n        StarterGui = "StarterGui",\n        LogService = "LogService",\n        DataStoreService = "DSS",\n        MarketplaceService = "MarketplaceService",\n        RbxAnalyticsService = "RbxAnalyticsService",\n        \n        Workspace = "Workspace",\n        Lighting = "Lighting",\n        SoundService = "SoundService",\n        Debris = "Debris",\n        CollectionService = "CollectionService",\n        ContextActionService = "CAS",\n        GuiService = "GuiService",\n        StarterPlayer = "StarterPlayer",\n        ServerScriptService = "SSS",\n        ServerStorage = "ServerStorage",\n        StarterPack = "StarterPack",\n        Teams = "Teams",\n        Chat = "Chat",\n        TextService = "TextService",\n        ProximityPromptService = "ProximityPromptService",\n        PathfindingService = "PathfindingService",\n        PhysicsService = "PhysicsService",\n        BadgeService = "BadgeService",\n\n        PlayerGui = "PlayerGui",\n        StarterCharacterScripts = "StarterCharScripts",\n        ContentProvider = "ContentProvider",\n\n        AnalyticsService = "Analytics",\n        AdService = "AdService",\n        AssetService = "AssetService",\n        AvatarEditorService = "AvatarEditor",\n\n        HapticService = "HapticService",\n        GamepadService = "GamepadService",\n        VRService = "VRService",\n        TouchInputService = "TouchInput",\n\n        StudioService = "StudioService",\n        ChangeHistoryService = "ChangeHistory",\n        Selection = "Selection",\n\n        NetworkClient = "NetworkClient",\n        NetworkServer = "NetworkServer",\n        MemoryStoreService = "MemoryStore",\n\n        AudioService = "Audio",\n\n        CookiesService = "Cookies",\n        FriendService = "FriendService",\n        GroupService = "GroupService",\n        InsertService = "InsertService",\n        JointsService = "JointsService",\n        Stats = "Stats",\n        TestService = "TestService",\n        ReplicatedFirst = "ReplicatedFirst",\n        ScriptService = "ScriptService",\n\n        CreatorStoreService = "CreatorStore",\n        CaptureService = "CaptureService",\n        CommerceService = "Commerce",\n        ControllerService = "ControllerService",\n        ReflectionService = "Reflection",\n\n        AssetDeliveryProxy = "AssetProxy",\n        ConfigureServerService = "ConfigureServer",\n    }\n    if services[aT] then return services[aT] end\n\n    local function make_valid_identifier(name)\n        name = tostring(name or "")\n        name = name:gsub("[^%w_]", "_")\n        name = name:gsub("_+", "_")\n        name = name:gsub("^_+", "")\n        if name:match("^%d") then\n            name = "v" .. name\n        end\n        if name == "" then\n            name = "lunr"\n        end\n        local reserved = {\n            ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,\n            ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,\n            ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,\n            ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,\n            ["while"] = true\n        }\n        if reserved[name] then\n            name = "v_" .. name\n        end\n        return name\n    end\n\n    local T = make_valid_identifier(aT)\n    if T == "Object" or T == "Value" or T == "result" then\n        T = "lunr"\n    end\n    return T\nend\nlocal function aW(x, aQ, aX, aS)\n    local aY = t.registry[x]\n    if aY then\n        return aY\n    end\n    \n    local preferred_name = aP(aQ, nil, aS)\n    local am = preferred_name\n    \n    -- If the name is generic or taken, add a counter\n    if am == "var" or t.names_used[am] then\n        t.var_counter = (t.var_counter or 0) + 1\n        am = am .. t.var_counter\n    end\n    \n    t.names_used[am] = true\n    t.registry[x] = am\n    t.reverse_registry[am] = x\n    t.variable_types[am] = aX or j(x)\n    return am\nend\nlocal function aZ(aF, a_, b0, b1)\n    a_ = a_ or 0\n    b0 = b0 or {}\n    if a_ > r.MAX_DEPTH then\n        return "{ --[[max depth]] }"\n    end\n    local b2 = j(aF)\n    if w(aF) then\n        local b3 = rawget(aF, "__value")\n        return m(b3 or 0)\n    end\n    if b2 == "table" and t.registry[aF] then\n        return t.registry[aF]\n    end\n    if b2 == "nil" then\n        return "nil"\n    elseif b2 == "string" then\n        if #aF > 100 and aF:match("^[A-Za-z0-9+/=]+$") then\n            table.insert(t.string_refs, {value = aF:sub(1, 50) .. "...", hint = "base64", full_length = #aF})\n        elseif aF:match("https?://") then\n            table.insert(t.string_refs, {value = aF, hint = "URL"})\n        elseif aF:match("rbxasset://") or aF:match("rbxassetid://") then\n            table.insert(t.string_refs, {value = aF, hint = "Asset"})\n        end\n        return aH(aF)\n    elseif b2 == "number" then\n        if aF ~= aF then\n            return "0/0"\n        end\n        if aF == math.huge then\n            return "math.huge"\n        end\n        if aF == -math.huge then\n            return "-math.huge"\n        end\n        if aF == math.floor(aF) then\n            return m(math.floor(aF))\n        end\n        return string.format("%.6g", aF)\n    elseif b2 == "boolean" then\n        return m(aF)\n    elseif b2 == "function" then\n        if t.registry[aF] then\n            return t.registry[aF]\n        end\n        -- Try to extract source\n        local info = debug.getinfo(aF)\n        if not info then\n            return "function() --[[ No debug info available ]] end"\n        end\n        if info.source and info.source:match("loadstring") == nil and not info.source:match("^@") and #info.source < 1000 then\n             -- If source is available (e.g. from loadstring) and not a file path\n             return info.source\n        end\n        -- Try to decompile (mock) or return signature\n        local params = ""\n        if info.nparams and info.nparams > 0 then\n             for i=1, info.nparams do \n                params = params .. (i>1 and ", p" or "p")..i \n             end\n        end\n        if info.is_vararg == 1 then \n            params = params .. (params~="" and ", ..." or "...") \n        end\n        return string.format("function(%s) --[[ Source: %s ]] end", params, (info.source and info.source:sub(1,50) or "unknown"))\n    elseif b2 == "table" then\n        if G(aF) then\n            return t.registry[aF] or "proxy"\n        end\n        if b0[aF] then\n            return "{ --[[circulunr]] }"\n        end\n        b0[aF] = true\n        local a2 = 0\n        for b4, b5 in D(aF) do\n            if b4 ~= F and b4 ~= "__proxy_id" then\n                a2 = a2 + 1\n            end\n        end\n        if a2 == 0 then\n            return "{}"\n        end\n        local b6 = true\n        local b7 = 0\n        for b4, b5 in D(aF) do\n            if b4 ~= F and b4 ~= "__proxy_id" then\n                if j(b4) ~= "number" or b4 < 1 or b4 ~= math.floor(b4) then\n                    b6 = false\n                    break\n                else\n                    b7 = math.max(b7, b4)\n                end\n            end\n        end\n        b6 = b6 and b7 == a2\n        if b6 and a2 <= 5 and b1 ~= false then\n            local b8 = {}\n            for L = 1, a2 do\n                local b5 = aF[L]\n                if j(b5) ~= "table" or G(b5) then\n                    table.insert(b8, aZ(b5, a_ + 1, b0, true))\n                else\n                    b6 = false\n                    break\n                end\n            end\n            if b6 and #b8 == a2 then\n                return "{" .. table.concat(b8, ", ") .. "}"\n            end\n        end\n        local b9 = {}\n        local ba = 0\n        local bb = string.rep("    ", t.indent + a_ + 1)\n        local bc = string.rep("    ", t.indent + a_)\n        for b4, b5 in D(aF) do\n            if b4 ~= F and b4 ~= "__proxy_id" then\n                ba = ba + 1\n                if ba > r.MAX_TABLE_ITEMS then\n                    table.insert(b9, bb .. "-- ..." .. a2 - ba + 1 .. " more")\n                    break\n                end\n                local bd\n                if b6 then\n                    bd = nil\n                elseif j(b4) == "string" and b4:match("^[%a_][%w_]*$") then\n                    bd = b4\n                else\n                    bd = "[" .. aZ(b4, a_ + 1, b0) .. "]"\n                end\n                local be = aZ(b5, a_ + 1, b0)\n                if bd then\n                    table.insert(b9, bb .. bd .. " = " .. be)\n                else\n                    table.insert(b9, bb .. be)\n                end\n            end\n        end\n        if #b9 == 0 then\n            return "{}"\n        end\n        return "{\n" .. table.concat(b9, ",\n") .. "\n" .. bc .. "}"\n    elseif b2 == "userdata" then\n        if t.registry[aF] then\n            return t.registry[aF]\n        end\n        local y, O = pcall(m, aF)\n        return y and O or "userdata"\n    elseif b2 == "thread" then\n        return "coroutine.create(function() end)"\n    else\n        local y, O = pcall(m, aF)\n        return y and O or "nil"\n    end\nend\nlocal bf = {}\nsetmetatable(bf, {__mode = "k"})\nlocal function bg()\n    local bh = {}\n    bf[bh] = true\n    local bi = {}\n    setmetatable(bh, bi)\n    return bh, bi\nend\nlocal function G(x)\n    return bf[x] == true\nend\nlocal bj\nlocal bk\nlocal function bl(bm)\n    local bh, bi = bg()\n    rawset(bh, v, true)\n    rawset(bh, "__value", bm)\n    t.registry[bh] = tostring(bm)\n    bi.__tostring = function()\n        return tostring(bm)\n    end\n    bi.__index = function(b2, b4)\n        if b4 == F or b4 == "__proxy_id" or b4 == v or b4 == "__value" then\n            return rawget(b2, b4)\n        end\n        return bl(0)\n    end\n    bi.__newindex = function()\n    end\n    bi.__call = function()\n        return bm\n    end\n    local function bn(X)\n        return function(bo, aa)\n            local bp = type(bo) == "table" and rawget(bo, "__value") or bo or 0\n            local bq = type(aa) == "table" and rawget(aa, "__value") or aa or 0\n            local z\n            if X == "+" then\n                z = bp + bq\n            elseif X == "-" then\n                z = bp - bq\n            elseif X == "*" then\n                z = bp * bq\n            elseif X == "/" then\n                z = bq ~= 0 and bp / bq or 0\n            elseif X == "%" then\n                z = bq ~= 0 and bp % bq or 0\n            elseif X == "^" then\n                z = bp ^ bq\n            else\n                z = 0\n            end\n            return bl(z)\n        end\n    end\n    bi.__add = bn("+")\n    bi.__sub = bn("-")\n    bi.__mul = bn("*")\n    bi.__div = bn("/")\n    bi.__mod = bn("%")\n    bi.__pow = bn("^")\n    bi.__unm = function(bo)\n        return bl(-(rawget(bo, "__value") or 0))\n    end\n    bi.__eq = function(bo, aa)\n        local bp = type(bo) == "table" and rawget(bo, "__value") or bo\n        local bq = type(aa) == "table" and rawget(aa, "__value") or aa\n        return bp == bq\n    end\n    bi.__lt = function(bo, aa)\n        local bp = type(bo) == "table" and rawget(bo, "__value") or bo\n        local bq = type(aa) == "table" and rawget(aa, "__value") or aa\n        return bp < bq\n    end\n    bi.__le = function(bo, aa)\n        local bp = type(bo) == "table" and rawget(bo, "__value") or bo\n        local bq = type(aa) == "table" and rawget(aa, "__value") or aa\n        return bp <= bq\n    end\n    bi.__len = function()\n        return 0\n    end\n    return bh\nend\nlocal function br(bs, bt)\n    if j(bs) ~= "function" then\n        return {}\n    end\n    \n    -- Create a wrapper function that captures the execution\n    local captured_lines = {}\n    local original_at = at\n    local capture_at = function(O, au)\n        table.insert(captured_lines, O)\n        return original_at(O, au)\n    end\n    \n    -- Temporarily replace at function\n    at = capture_at\n    \n    -- Execute the function to capture its output\n    xpcall(\n        function()\n            bs(table.unpack(bt or {}))\n        end,\n        function(err)\n            -- Ignore errors during capture\n        end\n    )\n    \n    -- Restore original at function\n    at = original_at\n    \n    return captured_lines\nend\nbk = function(aS, bw)\n    local bh, bi = bg()\n    local bP = {}  -- method table for this proxy (used by __index); bj() defines its own bP for returned proxies\n    local bx = t.registry[bw] or "object"\n\n    -- Check for name hint from HttpGet/loadstring flow\n    local hintName = nil\n    if _G._NextNameHint then\n        hintName = _G._NextNameHint\n        _G._NextNameHint = nil\n    end\n    \n    local by = aE(aS)\n    -- Check for name hint from HttpGet/loadstring flow\n    local hintName = nil\n    if _G._NextNameHint then\n        hintName = _G._NextNameHint\n        _G._NextNameHint = nil\n    end\n    bi.__call = function(self, bz, ...)\n        if by == "InvalidMethod" then\n            error("attempt to call a nil value (method 'InvalidMethod')", 2)\n        end\n        local bA\n        if bz == bh or bz == bw or G(bz) then\n            bA = {...}\n        else\n            bA = {bz, ...}\n        end\n        local aU = by:lower()\n        local bB = nil\n        local bC = true\n        for W, aV in ipairs(aL) do\n            if aU:find(aV.pattern) then\n                bB = aV.prefix\n                break\n            end\n        end\n        local bD = nil\n        local bE = nil\n        local bF = nil\n        for L, b5 in ipairs(bA) do\n            if j(b5) == "function" then\n                bD = b5\n                break\n            elseif j(b5) == "table" and not G(b5) then\n                for bG, aF in D(b5) do\n                    local bH = m(bG):lower()\n                    if bH == "callback" and j(aF) == "function" then\n                        bD = aF\n                        bE = bG\n                        bF = L\n                        break\n                    end\n                end\n            end\n        end\n        local bI = "value"\n        local bt = {}\n        if bD then\n            if aU:match("toggle") then\n                bI = "enabled"\n                bt = {true}\n            elseif aU:match("slider") then\n                bI = "value"\n                bt = {50}\n            elseif aU:match("dropdown") then\n                bI = "selected"\n                bt = {"Option"}\n            elseif aU:match("textbox") or aU:match("input") then\n                bI = "text"\n                bt = {s or "input"}\n            elseif aU:match("keybind") or aU:match("bind") then\n                bI = "key"\n                bt = {bj("Enum.KeyCode.E", false)}\n            elseif aU:match("color") then\n                bI = "color"\n                bt = {Color3.fromRGB(255, 255, 255)}\n            elseif aU:match("button") then\n                bI = "\\"\n                bt = {}\n            end\n        end\n        local bJ = {}\n        if bD then\n            bJ = br(bD, bt)\n        end\n        local z = bj(bB or by, false, bw)\n        local _ = aW(z, bB or by, nil, by)\n        local bK = {}\n        for L, b5 in ipairs(bA) do\n            if j(b5) == "table" and not G(b5) and L == bF then\n                local b8 = {}\n                for bG, aF in D(b5) do\n                    local bd\n                    if j(bG) == "string" and bG:match("^[%a_][%w_]*$") then\n                        bd = bG\n                    else\n                        bd = "[" .. aZ(bG) .. "]"\n                    end\n                    if bG == bE and #bJ > 0 then\n                        local bL = bI ~= '"' and "function(" .. "bI" .. ")" or "function()"
                        local bb = string.rep("    ", t.indent + 2)
                        local bM = {}
                        for W, aw in ipairs(bJ) do
                            table.insert(bM, bb .. (aw:match("^%s*(.*)$") or aw))
                        end
                        local bc = string.rep("    ", t.indent + 1)
                        table.insert(b8, bd .. " = " .. bL .. "\n" .. table.concat(bM, "\n") .. "\n" .. bc .. "end")
                    elseif bG == bE then
                        local bN = bI ~= "\\" and "function(" .. bI .. ") end" or "function() end"
                        table.insert(b8, bd .. " = " .. bN)
                    else
                        table.insert(b8, bd .. " = " .. aZ(aF))
                    end
                end
                table.insert(
                    bK,
                    "{\\\n" ..
                        string.rep("    ", t.indent + 1) ..
                            table.concat(b8, ",\\\n" .. string.rep("    ", t.indent + 1)) ..
                                "\\\n" .. string.rep("    ", t.indent) .. "}"
                )
            elseif j(b5) == "function" then
                if #bJ > 0 then
                    local bL = bI ~= '"' and "function(" .. bI .. ")" or "function()"\n                    local bb = string.rep("    ", t.indent + 1)\n                    local bM = {}\n                    for W, aw in ipairs(bJ) do\n                        table.insert(bM, bb .. (aw:match("^%s*(.*)$") or aw))\n                    end\n                    table.insert(\n                        bK,\n                        bL .. "\n" .. table.concat(bM, "\n") .. "\n" .. string.rep("    ", t.indent) .. "end"\n                    )\n                else\n                    local bN = bI ~= '"' and "function(" .. bI .. ") end" or "function() end"
                    table.insert(bK, bN)
                end
            else
                table.insert(bK, aZ(b5))
            end
        end
        at(string.format("local %s = %s:%s(%s)", _, bx, by, table.concat(bK, ", ")))
        return z
    end
    bi.__index = function(b2, b4)
        if b4 == F or b4 == "__proxy_id" then
            return rawget(b2, b4)
        end
        if bP[b4] then
            return bP[b4]
        end
        return bk(b4, bh)
    end
    bi.__tostring = function()
        return bx .. ":" .. by
    end
    return bh
end
bj = function(aQ, bO, bw)
    local bh, bi = bg()
    local aT = aE(aQ)
    t.property_store[bh] = {}
    
    -- Apply Name Hint if available
    if _G._NextNameHint then
        t.registry[bh] = _G._NextNameHint
        t.names_used[_G._NextNameHint] = true
        _G._NextNameHint = nil
    elseif bO then
        t.registry[bh] = aT
        t.names_used[aT] = true
    elseif bw then
        t.parent_map[bh] = bw
        rawset(bh, "__temp_path", (t.registry[bw] or "object") .. "." .. aT)
    end
    local bP = {}
    bP.GetService = function(self, bQ)
        local bR = aE(bQ)
        if bR == "RunService" and _G.__real_game then
            local real_rs = _G.__real_game:GetService("RunService")
            if real_rs then
                local x = bj("RunService", false, bh)
                local _ = aW(x, "RunService")
                at(string.format("local %s = game:GetService(\"RunService\")", _))
                return real_rs
            end
        end
        if bR == "LogService" and _G.__real_game then
            local real_ls = _G.__real_game:GetService("LogService")
            if real_ls then
                local x = bj("LogService", false, bh)
                local _ = aW(x, "LogService")
                at(string.format("local %s = game:GetService(\"LogService\")", _))
                return real_ls
            end
        end
        if bR == "Players" and _G.__real_game then
            local real_players = _G.__real_game:GetService("Players")
            if real_players then
                local x = bj("Players", false, bh)
                local _ = aW(x, "Players")
                at(string.format("local %s = game:GetService(\"Players\")", _))
                return real_players
            end
        end
        if bR == "HttpService" and _G.__real_game then
            local real_hs = _G.__real_game:GetService("HttpService")
            if real_hs then
                local x = bj("HttpService", false, bh)
                local _ = aW(x, "HttpService")
                at(string.format("local %s = game:GetService(\"HttpService\")", _))
                return real_hs
            end
        end
        local x = bj(bR, false, bh)
        local _ = aW(x, bR)
        local bS = t.registry[bh] or "game"
        at(string.format("local %s = %s:GetService(%s)", _, bS, aH(bR)))
        
        -- Special handling for Players service
        if bR == "Players" then
            t.property_store[x] = {
                LocalPlayer = {
                    UserId = 1,
                    Name = "Lunr", 
                    DisplayName = "Lunr",
                    AccountAge = 69143,
                    ClassName = "Player"
                }
            }
        end
        
        return x
    end
    if aT == "game" and _G.__real_game then
        bP.GetChildren = function(self)
            return _G.__real_game:GetChildren()
        end
    end
    bP.WaitForChild = function(self, bT, bU)
        local bV = aE(bT)
        local x = bj(bV, false, bh)
        local _ = aW(x, bV)
        local bS = t.registry[bh] or "object"
        if bU then
            at(string.format("local %s = %s:WaitForChild(%s, %s)", _, bS, aH(bV), aZ(bU)))
        else
            at(string.format("local %s = %s:WaitForChild(%s)", _, bS, aH(bV)))
        end
        return x
    end
    bP.FindFirstChild = function(self, bT, bW)
        local bV = aE(bT)
        local x = bj(bV, false, bh)
        local _ = aW(x, bV)
        local bS = t.registry[bh] or "object"
        if bW then
            at(string.format("local %s = %s:FindFirstChild(%s, true)", _, bS, aH(bV)))
        else
            at(string.format("local %s = %s:FindFirstChild(%s)", _, bS, aH(bV)))
        end
        return x
    end
    bP.FindFirstChildOfClass = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or "object"
        at(string.format("local %s = %s:FindFirstChildOfClass(%s)", _, bS, aH(bY)))
        return x
    end
    bP.FindFirstChildWhichIsA = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or "object"
        at(string.format("local %s = %s:FindFirstChildWhichIsA(%s)", _, bS, aH(bY)))
        return x
    end
    bP.FindFirstAncestor = function(self, am)
        local bZ = aE(am)
        local x = bj(bZ, false, bh)
        local _ = aW(x, bZ)
        local bS = t.registry[bh] or "object"
        at(string.format("local %s = %s:FindFirstAncestor(%s)", _, bS, aH(bZ)))
        return x
    end
    bP.FindFirstAncestorOfClass = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or "object"
        at(string.format("local %s = %s:FindFirstAncestorOfClass(%s)", _, bS, aH(bY)))
        return x
    end
    bP.FindFirstAncestorWhichIsA = function(self, bX)
        local bY = aE(bX)
        local x = bj(bY, false, bh)
        local _ = aW(x, bY)
        local bS = t.registry[bh] or "object"
        at(string.format("local %s = %s:FindFirstAncestorWhichIsA(%s)", _, bS, aH(bY)))
        return x
    end
    if aT ~= "game" or not _G.__real_game then
    bP.GetChildren = function(self)
        local bS = t.registry[bh] or "object"
        if at(string.format("for _, child in %s:GetChildren() do", bS)) then
            t.indent = t.indent + 1
            t.pending_iterator = true
        end
        return {}
    end
    end
    bP.GetDescendants = function(self)
        local bS = t.registry[bh] or "object"
        if at(string.format("for _, obj in %s:GetDescendants() do", bS)) then
            t.indent = t.indent + 1
            local b_ = bj("obj", false)
            t.registry[b_] = "obj"
            t.property_store[b_] = {Name = "Ball", ClassName = "Part", Size = Vector3.new(1, 1, 1)}
            local c0 = false
            return function()
                if not c0 then
                    c0 = true
                    return 1, b_
                else
                    t.indent = t.indent - 1
                    at("end")
                    return nil
                end
            end, nil, 0
        end
        return function() return nil end, nil, 0
    end
    bP.Clone = function(self)
        local bS = t.registry[bh] or "object"
        local x = bj((aT or "object") .. "Clone", false)
        local _ = aW(x, (aT or "object") .. "Clone")
        at(string.format("local %s = %s:Clone()", _, bS))
        return x
    end
    bP.Destroy = function(self)
        local bS = t.registry[bh] or "object"
        at(string.format("%s:Destroy()", bS))
    end
    bP.ClearAllChildren = function(self)
        local bS = t.registry[bh] or "object"
        at(string.format("%s:ClearAllChildren()", bS))
    end
    bP.Connect = function(self, bs)
        local bS = t.registry[bh] or "signal"
        local c1 = bj("connection", false)
        local c2 = aW(c1, "conn")
        local c3 = bS:match("%.([^%.]+)$") or bS
        local c4 = {"..."}
        if c3:match("InputBegan") or c3:match("InputEnded") or c3:match("InputChanged") then
            c4 = {"input", "gameProcessed"}
        elseif c3:match("CharacterAdded") or c3:match("CharacterRemoving") then
            c4 = {"character"}
        elseif c3:match("PlayerAdded") or c3:match("PlayerRemoving") then
            c4 = {"player"}
        elseif c3:match("Touched") then
            c4 = {"hit"}
        elseif c3:match("Heartbeat") or c3:match("RenderStepped") then
            c4 = {"deltaTime"}
        elseif c3:match("Stepped") then
            c4 = {"time", "deltaTime"}
        elseif c3:match("Changed") then
            c4 = {"property"}
        elseif c3:match("ChildAdded") or c3:match("ChildRemoved") then
            c4 = {"child"}
        elseif c3:match("DescendantAdded") or c3:match("DescendantRemoving") then
            c4 = {"descendant"}
        elseif c3:match("Died") or c3:match("MouseButton") or c3:match("Activated") then
            c4 = {}
        elseif c3:match("MouseButton1Down") or c3:match("MouseButton2Down") then
            c4 = {}
        elseif c3:match("FocusLost") then
            c4 = {"enterPressed", "inputObject"}
        end
        if at(string.format("local %s = %s:Connect(function(%s)", c2, bS, table.concat(c4, ", "))) then
            t.indent = t.indent + 1
            if j(bs) == "function" then
                local function c_dummy(name)
                    if name == "player" then
                        return (game and game.Players and game.Players.LocalPlayer) or nil
                    elseif name == "character" then
                        return bj("character", false)
                    elseif name == "hit" then
                        return bj("hit", false)
                    elseif name == "property" then
                        return "Name"
                    elseif name == "deltaTime" then
                        return 0.016
                    elseif name == "time" then
                        return 0
                    elseif name == "enterPressed" then
                        return false
                    elseif name == "gameProcessed" then
                        return false
                    elseif name == "input" or name == "inputObject" then
                        return {KeyCode = {Name = "Space"}, UserInputType = {Name = "Keyboard"}}
                    end
                    return nil
                end
                local c_args = {}
                for _, c_name in ipairs(c4) do
                    if c_name ~= "..." then
                        table.insert(c_args, c_dummy(c_name))
                    end
                end
                xpcall(
                    function()
                        bs(table.unpack(c_args))
                    end,
                    function()
                    end
                )
            end
            while t.pending_iterator do
                t.indent = t.indent - 1
                at("end")
                t.pending_iterator = false
            end
            t.indent = t.indent - 1
            at("end)")
        end
        return c1
    end
    bP.Once = function(self, bs)
        local bS = t.registry[bh] or "signal"
        local c1 = bj("connection", false)
        local c2 = aW(c1, "conn")
        if at(string.format("local %s = %s:Once(function(...)", c2, bS)) then
            t.indent = t.indent + 1
            if j(bs) == "function" then
                xpcall(
                    function()
                        bs(nil)
                    end,
                    function()
                    end
                )
            end
            t.indent = t.indent - 1
            at("end)")
        end
        return c1
    end
    bP.Wait = function(self)
        local bS = t.registry[bh] or "signal"
        local z = bj("waitResult", false)
        local _ = aW(z, "waitResult")
        at(string.format("local %s = %s:Wait()", _, bS))
        return z
    end
    bP.Disconnect = function(self)
        local bS = t.registry[bh] or "connection"
        at(string.format("%s:Disconnect()", bS))
    end
    bP.FireServer = function(self, ...)
        local bS = t.registry[bh] or "remote"
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        at(string.format("%s:FireServer(%s)", bS, table.concat(c5, ", ")))
        table.insert(t.call_graph, {type = "RemoteEvent", name = bS, args = bA})
    end
    bP.InvokeServer = function(self, ...)
        local bS = t.registry[bh] or "remote"
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        local z = bj("invokeResult", false)
        local _ = aW(z, "result")
        at(string.format("local %s = %s:InvokeServer(%s)", _, bS, table.concat(c5, ", ")))
        table.insert(t.call_graph, {type = "RemoteFunction", name = bS, args = bA})
        return z
    end
    bP.Create = function(self, x, c6, c7)
        local bS = t.registry[bh] or "TweenService"
        local c8 = bj("tween", false)
        local _ = aW(c8, "tween")
        at(string.format("local %s = %s:Create(%s, %s, %s)", _, bS, aZ(x), aZ(c6), aZ(c7)))
        at(string.format("local %s = %s", c8, _))
        return c8
    end
    bP.Play = function(self)
        local bS = t.registry[bh] or c8
        at(string.format("%s:Play()", bS))
    end
    bP.Pause = function(self)
        local bS = t.registry[bh] or c8
        at(string.format("%s:Pause()", bS))
    end
    bP.Cancel = function(self)
        local bS = t.registry[bh] or c8
        at(string.format("%s:Cancel()", bS))
    end
    bP.Stop = function(self)
        local bS = t.registry[bh] or c8
        at(string.format("%s:Stop()", bS))
    end
    bP.Raycast = function(self, c9, ca, cb)
        local bS = t.registry[bh] or "workspace"
        local z = bj("raycastResult", false)
        local _ = aW(z, "rayResult")
        if cb then
            at(string.format("local %s = %s:Raycast(%s, %s, %s)", _, bS, aZ(c9), aZ(ca), aZ(cb)))
        else
            at(string.format("local %s = %s:Raycast(%s, %s)", _, bS, aZ(c9), aZ(ca)))
        end
        return z
    end
    bP.GetMouse = function(self)
        local bS = t.registry[bh] or "player"
        local cc = bj("mouse", false)
        local _ = aW(cc, "mouse")
        at(string.format("local %s = %s:GetMouse()", _, bS))
        return cc
    end
    bP.Kick = function(self, cd)
        local bS = t.registry[bh] or "player"
        if cd then
            at(string.format("%s:Kick(%s)", bS, aZ(cd)))
        else
            at(string.format("%s:Kick()", bS))
        end
    end
    bP.GetPropertyChangedSignal = function(self, ce)
        local cf = aE(ce)
        local bS = t.registry[bh] or "instance"
        local cg = bj(cf .. "Changed", false)
        t.registry[cg] = bS .. ":GetPropertyChangedSignal(" .. aH(cf) .. ")"
        return cg
    end
    bP.IsA = function(self, bX)
        local className = aE(bX)
        local result = self.ClassName == className
        at(string.format("local %s = %s:IsA(%s) -- %s", t.registry[self] or "object", t.registry[self] or "object", aH(className), tostring(result)))
        return result
    end
    bP.IsDescendantOf = function(self, ch)
        return true
    end
    bP.IsAncestorOf = function(self, ci)
        return true
    end
    bP.GetAttribute = function(self, cj)
        return nil
    end
    bP.SetAttribute = function(self, cj, bm)
        local bS = t.registry[bh] or "instance"
        at(string.format("%s:SetAttribute(%s, %s)", bS, aH(cj), aZ(bm)))
    end
    bP.GetAttributes = function(self)
        return {}
    end
    bP.GetPlayers = function(self)
        return {}
    end
    bP.GetPlayerFromCharacter = function(self, ck)
        local bS = t.registry[bh] or "Players"
        local cl = bj("player", false)
        local _ = aW(cl, "player")
        at(string.format("local %s = %s:GetPlayerFromCharacter(%s)", _, bS, aZ(ck)))
        return cl
    end
    bP.GetPlayerByUserId = function(self, cm)
        local bS = t.registry[bh] or "Players"
        local cl = bj("player", false)
        local _ = aW(cl, "player")
        at(string.format("local %s = %s:GetPlayerByUserId(%s)", _, bS, aZ(cm)))
        return cl
    end
    bP.SetCore = function(self, am, bm)
        local bS = t.registry[bh] or "StarterGui"
        at(string.format("%s:SetCore(%s, %s)", bS, aH(am), aZ(bm)))
    end
    bP.GetCore = function(self, am)
        return nil
    end
    bP.SetCoreGuiEnabled = function(self, cn, co)
        local bS = t.registry[bh] or "StarterGui"
        at(string.format("%s:SetCoreGuiEnabled(%s, %s)", bS, aZ(cn), aZ(co)))
    end
    bP.BindToRenderStep = function(self, am, cp, bs)
        local bS = t.registry[bh] or "RunService"
        at(string.format("%s:BindToRenderStep(%s, %s, function(deltaTime)", bS, aH(am), aZ(cp)))
        t.indent = t.indent + 1
        if j(bs) == "function" then
            xpcall(
                function()
                    bs(0.016)
                end,
                function()
                end
            )
        end
        t.indent = t.indent - 1
        at("end)")
    end
    bP.UnbindFromRenderStep = function(self, am)
        local bS = t.registry[bh] or "RunService"
        at(string.format("%s:UnbindFromRenderStep(%s)", bS, aH(am)))
    end
    bP.GetFullName = function(self)
        return t.registry[bh] or "Instance"
    end
    bP.GetDebugId = function(self)
        return "DEBUG_" .. (H(bh) or "0")
    end
    bP.MoveTo = function(self, cq, cr)
        local bS = t.registry[bh] or "humanoid"
        if cr then
            at(string.format("%s:MoveTo(%s, %s)", bS, aZ(cq), aZ(cr)))
        else
            at(string.format("%s:MoveTo(%s)", bS, aZ(cq)))
        end
    end
    bP.Move = function(self, ca, cs)
        local bS = t.registry[bh] or "humanoid"
        at(string.format("%s:Move(%s, %s)", bS, aZ(ca), aZ(cs or false)))
    end
    bP.EquipTool = function(self, ct)
        local bS = t.registry[bh] or "humanoid"
        at(string.format("%s:EquipTool(%s)", bS, aZ(ct)))
    end
    bP.UnequipTools = function(self)
        local bS = t.registry[bh] or "humanoid"
        at(string.format("%s:UnequipTools()", bS))
    end
    bP.TakeDamage = function(self, cu)
        local bS = t.registry[bh] or "humanoid"
        at(string.format("%s:TakeDamage(%s)", bS, aZ(cu)))
    end
    bP.ChangeState = function(self, cv)
        local bS = t.registry[bh] or "humanoid"
        at(string.format("%s:ChangeState(%s)", bS, aZ(cv)))
    end
    bP.GetState = function(self)
        return bj("Enum.HumanoidStateType.Running", false)
    end
    bP.SetPrimaryPartCFrame = function(self, cw)
        local bS = t.registry[bh] or "model"
        at(string.format("%s:SetPrimaryPartCFrame(%s)", bS, aZ(cw)))
    end
    bP.GetPrimaryPartCFrame = function(self)
        return CFrame.new(0, 0, 0)
    end
    bP.PivotTo = function(self, cw)
        local bS = t.registry[bh] or "model"
        at(string.format("%s:PivotTo(%s)", bS, aZ(cw)))
    end
    bP.GetPivot = function(self)
        return CFrame.new(0, 0, 0)
    end
    bP.GetBoundingBox = function(self)
        return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1)
    end
    bP.GetExtentsSize = function(self)
        return Vector3.new(1, 1, 1)
    end
    bP.TranslateBy = function(self, cx)
        local bS = t.registry[bh] or "model"
        at(string.format("%s:TranslateBy(%s)", bS, aZ(cx)))
    end
    bP.LoadAnimation = function(self, cy)
        local bS = t.registry[bh] or "animator"
        local cz = bj("animTrack", false)
        local _ = aW(cz, "animTrack")
        at(string.format("local %s = %s:LoadAnimation(%s)", _, bS, aZ(cy)))
        return cz
    end
    bP.GetPlayingAnimationTracks = function(self)
        return {}
    end
    bP.AdjustSpeed = function(self, cA)
        local bS = t.registry[bh] or "animTrack"
        at(string.format("%s:AdjustSpeed(%s)", bS, aZ(cA)))
    end
    bP.AdjustWeight = function(self, cB, cC)
        local bS = t.registry[bh] or "animTrack"
        if cC then
            at(string.format("%s:AdjustWeight(%s, %s)", bS, aZ(cB), aZ(cC)))
        else
            at(string.format("%s:AdjustWeight(%s)", bS, aZ(cB)))
        end
    end
    bP.Teleport = function(self, cD, cl, cE, cF)
        local bS = t.registry[bh] or "TeleportService"
        at(
            string.format(
                "%s:Teleport(%s, %s%s%s)",
                bS,
                aZ(cD),
                aZ(cl),
                cE and ", " .. aZ(cE) or '"',\n                cF and ", " .. aZ(cF) or '"'
            )
        )
    end
    bP.TeleportToPlaceInstance = function(self, cD, cG, cl)
        local bS = t.registry[bh] or "TeleportService"
        at(string.format("%s:TeleportToPlaceInstance(%s, %s, %s)", bS, aZ(cD), aZ(cG), aZ(cl)))
    end
    bP.PlayLocalSound = function(self, cH)
        local bS = t.registry[bh] or "SoundService"
        at(string.format("%s:PlayLocalSound(%s)", bS, aZ(cH)))
    end
    bP.GetAsync = function(self, cI)
        return "{}"
    end
    bP.PostAsync = function(self, cI, cJ)
        return "{}"
    end
    bP.JSONEncode = function(self, cJ)
        at(string.format("HttpService:JSONEncode(%s)", aZ(cJ)))
        return aE(cJ)
    end
    bP.JSONDecode = function(self, O)
        local function do_decode()
            if type(O) == "string" then
                if _G.__real_game then
                    local real_hs = _G.__real_game:GetService("HttpService")
                    if real_hs and real_hs.JSONDecode then
                        local ok, parsed = pcall(real_hs.JSONDecode, real_hs, O)
                        if ok and type(parsed) == "table" then
                            if not parsed[6] then parsed[6] = {} end
                            parsed[6][2] = nil
                            return parsed
                        end
                    end
                end
                if O:match("^%s*%[") then
                    return {nil, nil, nil, nil, nil, {nil, nil}, nil, {}}
                end
            end
            return aE(O)
        end
        local ok, result = pcall(do_decode)
        if ok then
            pcall(at, string.format("HttpService:JSONDecode(%s)", type(O) == "string" and ("\"...\"") or aZ(O)))
            return result
        end
        pcall(at, "HttpService:JSONDecode(...)")
        return {nil, nil, nil, nil, nil, {nil, nil}, nil, {}}
    end
    bP.GenerateGUID = function(self, cK)
        return "00000000-0000-0000-0000-000000000000"
    end
    bP.HttpGet = function(self, cI)
        local cL = aE(cI)
        table.insert(t.string_refs, {value = cL, hint = "HTTP URL"})
        t.last_http_url = cL
        
        -- Check for known library patterns and generate loadstring format
        local url_lower = cL:lower()
        local patterns = {
            {pattern = "rayfield",    name = "Rayfield"},
            {pattern = "windui",      name = "WindUI"},
            {pattern = "fluent",      name = "Fluent"},
            {pattern = "tora-library", name = "Tora_Library"},
            {pattern = "orion",       name = "OrionLib"},
            {pattern = "kavo",        name = "Kavo"},
            {pattern = "venyx",       name = "Venyx"},
            {pattern = "sirius",      name = "Sirius"},
            {pattern = "linoria",     name = "Linoria"},
            {pattern = "wally",       name = "Wally"},
            {pattern = "dex",         name = "Dex"},
            {pattern = "infinite",    name = "InfiniteYield"},
            {pattern = "hydroxide",   name = "Hydroxide"},
            {pattern = "simplespy",   name = "SimpleSpy"},
            {pattern = "remotespy",   name = "RemoteSpy"},
        }
        
        local library_name = nil
        for _, pattern in ipairs(patterns) do
            if url_lower:find(pattern.pattern) then
                library_name = pattern.name
                break
            end
        end
        
        if library_name then
            at(string.format('local %s = loadstring(game:HttpGet("%s"))()', library_name, cL))
        else
            t.library_counter = t.library_counter + 1
            local library_var_name = "Library" .. (t.library_counter > 1 and t.library_counter - 1 or "")
            at(string.format('local %s = loadstring(game:HttpGet("%s"))()', library_var_name, cL))
        end
        
        local stub = "return { CreateWindow = function(self, ...) return {} end, Create = function(self, ...) return {} end }"
        if library_name or url_lower:match("library") or url_lower:match("tora") or url_lower:match("raw%.githubusercontent") then
            return stub
        end
        return cL
    end
    bP.HttpPost = function(self, cI, cJ, cM)
        local cL = aE(cI)
        table.insert(t.string_refs, {value = cL, hint = "HTTP POST URL"})
        local x = bj("HttpResponse", false)
        local _ = aW(x, "httpResponse")
        local bS = t.registry[bh] or "HttpService"
        at(string.format("local %s = %s:HttpPost(%s, %s, %s)", _, bS, aZ(cI), aZ(cJ), aZ(cM)))
        t.property_store[x] = {Body = "{}", StatusCode = 200, Success = true}
        return x
    end
    bP.AddItem = function(self, cN, cO)
        local bS = t.registry[bh] or "Debris"
        at(string.format("%s:AddItem(%s, %s)", bS, aZ(cN), aZ(cO or 10)))
    end
    bi.__index = function(b2, b4)
        if b4 == F or b4 == "__proxy_id" then
            return rawget(b2, b4)
        end
        if b4 == "PlaceId" or b4 == "GameId" or b4 == "placeId" or b4 == "gameId" then
            return u
        end
        if b4 == "HttpGet" then
            return function(self, url)
                -- Handle both :HttpGet(url) and :HttpGet "url" syntax
                if url == nil then
                    url = tostring(self)
                    self = game
                end
                if type(url) ~= "string" then
                    return ""
                end
                t.last_http_url = url
                local url_lower = url:lower()
                local patterns = {
                    {pattern = "rayfield",    name = "Rayfield"},
                    {pattern = "windui",      name = "WindUI"},
                    {pattern = "fluent",      name = "Fluent"},
                    {pattern = "tora-library", name = "Tora_Library"},
                    {pattern = "orion",       name = "OrionLib"},
                    {pattern = "kavo",        name = "Kavo"},
                    {pattern = "venyx",       name = "Venyx"},
                    {pattern = "sirius",      name = "Sirius"},
                    {pattern = "linoria",     name = "Linoria"},
                    {pattern = "wally",       name = "Wally"},
                    {pattern = "dex",         name = "Dex"},
                    {pattern = "infinite",    name = "InfiniteYield"},
                    {pattern = "hydroxide",   name = "Hydroxide"},
                    {pattern = "simplespy",   name = "SimpleSpy"},
                    {pattern = "remotespy",   name = "RemoteSpy"},
                }
                local library_name = nil
                for _, entry in ipairs(patterns) do
                    if url_lower:find(entry.pattern, 1, true) then
                        library_name = entry.name
                        break
                    end
                end
                local varname
                if library_name then
                    varname = library_name
                else
                    t.library_counter = (t.library_counter or 0) + 1
                    varname = (t.library_counter > 1) and ("Library" .. (t.library_counter - 1)) or "Library"
                end
                at(string.format('local %s = loadstring(game:HttpGet("%s"))()', varname, url))
                local stub = "return { CreateWindow = function(self, ...) return {} end, Create = function(self, ...) return {} end }"
                if library_name or url_lower:match("library") or url_lower:match("tora") or url_lower:match("raw%.githubusercontent") then
                    return stub
                end
                return ""
            end
        end
        local bS = t.registry[bh] or aT or "object"
        local cP = aE(b4)
        
        -- Special handling for LocalPlayer - check this FIRST before property_store
        if b4 == "LocalPlayer" then
            local cT = bj("LocalPlayer", false, bh)
            local _ = aW(cT, "LocalPlayer")
            at(string.format("local %s = %s.LocalPlayer", _, bS))
            -- Set up LocalPlayer specific property handlers
            t.property_store[cT] = {
                UserId = 1,
                Name = "Lunr",
                DisplayName = "Lunr",
                AccountAge = 69143,
                ClassName = "Player"
            }
            return cT
        end
        
        if t.property_store[bh] and t.property_store[bh][b4] ~= nil then
            local value = t.property_store[bh][b4]
            -- Special handling for LocalPlayer properties in property_store
            if b4 == "UserId" and (t.property_store[bh].UserId ~= nil) then
                return 1
            end
            if b4 == "Name" and (t.property_store[bh].Name ~= nil) then
                return "Lunr"
            end
            if b4 == "DisplayName" and (t.property_store[bh].DisplayName ~= nil) then
                return "Lunr"
            end
            if b4 == "AccountAge" and (t.property_store[bh].AccountAge ~= nil) then
                return 69143
            end
            if b4 == "ClassName" and (t.property_store[bh].ClassName ~= nil) then
                return "Player"
            end
            
            if type(value) == "table" then
                -- Convert table to bj object for proper property handling
                local obj = bj(b4, false, bh)
                local _ = aW(obj, b4)
                -- Copy the table properties to the new object's property_store
                t.property_store[obj] = value
                
                -- Special handling for LocalPlayer properties
                if b4 == "LocalPlayer" then
                    -- Ensure LocalPlayer properties return correct types
                    local original_store = t.property_store[obj]
                    t.property_store[obj] = {
                        UserId = 1,
                        Name = "Lunr",
                        DisplayName = "Lunr", 
                        AccountAge = 69143,
                        ClassName = "Player"
                    }
                end
                
                return obj
            end
            return value
        end
        
        -- Special handling for LocalPlayer properties
        if b4 == "UserId" and (bS == "LocalPlayer" or (t.property_store[bh] and t.property_store[bh].UserId ~= nil)) then
            return 1
        end
        if b4 == "Name" and (bS == "LocalPlayer" or (t.property_store[bh] and t.property_store[bh].Name ~= nil)) then
            return "Lunr"
        end
        if b4 == "DisplayName" and (bS == "LocalPlayer" or (t.property_store[bh] and t.property_store[bh].DisplayName ~= nil)) then
            return "Lunr"
        end
        if b4 == "AccountAge" and (bS == "LocalPlayer" or (t.property_store[bh] and t.property_store[bh].AccountAge ~= nil)) then
            return 69143
        end
        if b4 == "ClassName" and (bS == "LocalPlayer" or (t.property_store[bh] and t.property_store[bh].ClassName ~= nil)) then
            return "Player"
        end
        if bP[cP] then
            local cQ, cR = bg()
            t.registry[cQ] = bS .. "." .. cP
            cR.__call = function(W, ...)
                local bA = {...}
                if bA[1] == bh or G(bA[1]) and bA[1] ~= cQ then
                    table.remove(bA, 1)
                end
                return bP[cP](bh, table.unpack(bA))
            end
            cR.__index = function(W, cS)
                if cS == F or cS == "__proxy_id" then
                    return rawget(cQ, cS)
                end
                return bj(cS, false, cQ)
            end
            cR.__tostring = function()
                return bS .. ":" .. cP
            end
            return cQ
        end
        if bS == "fenv" or bS == "getgenv" or bS == "ENV" or bS == "env" or bS == "E" or bS == "e" or bS == "L" or bS == "l" or bS == "F" or bS == "f" then
            if b4 == "game" then
                return game
            end
            if b4 == "workspace" then
                return workspace
            end
            if b4 == "script" then
                return script
            end
            if b4 == "Enum" then
                return Enum
            end
            if _G[b4] ~= nil then
                return _G[b4]
            end
            return nil
        end
        if b4 == "LocalPlayer" then
            local cT = bj("LocalPlayer", false, bh)
            local _ = aW(cT, "LocalPlayer")
            at(string.format("local %s = %s.LocalPlayer", _, bS))
            -- Set up LocalPlayer specific property handlers
            t.property_store[cT] = {
                UserId = 1,
                Name = "Lunr",
                DisplayName = "Lunr",
                AccountAge = 69143,
                ClassName = "Player"
            }
            return cT
        end
        if b4 == "Parent" then
            return t.parent_map[bh] or bj("Parent", false)
        end
        if b4 == "Name" then
            return aT or "Object"
        end
        if b4 == "ClassName" then
            return aT or "Instance"
        end
        if bS == "fenv" or bS == "getgenv" or bS == "ENV" or bS == "env" or bS == "E" or bS == "e" or bS == "L" or bS == "l" or bS == "F" or bS == "f" then
            if b4 == "game" then
                return game
            end
            if b4 == "workspace" then
                return workspace
            end
            if b4 == "script" then
                return script
            end
            if b4 == "Enum" then
                return Enum
            end
            if _G[b4] ~= nil then
                return _G[b4]
            end
            return nil
        end
        if b4 == "PlayerGui" then
            return bj("PlayerGui", false, bh)
        end
        if b4 == "Backpack" then
            return bj("Backpack", false, bh)
        end
        if b4 == "PlayerScripts" then
            return bj("PlayerScripts", false, bh)
        end
        if b4 == "UserId" then
            return 1
        end
        if b4 == "DisplayName" then
            return "Lunr"
        end
        if b4 == "Name" then
            return "Lunr"
        end
        if b4 == "AccountAge" then
            return 69143
        end
        if b4 == "Team" then
            return bj("Team", false, bh)
        end
        if b4 == "TeamColor" then
            return BrickColor.new("White")
        end
        if b4 == "Character" then
            return bj("Character", false, bh)
        end
        if b4 == "Humanoid" then
            local cU = bj("Humanoid", false, bh)
            t.property_store[cU] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}
            return cU
        end
        if b4 == "HumanoidRootPart" or b4 == "PrimaryPart" or b4 == "RootPart" then
            local cV = bj("HumanoidRootPart", false, bh)
            t.property_store[cV] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}
            return cV
        end
        local cW = {
            "Head",
            "Torso",
            "UpperTorso",
            "LowerTorso",
            "RightArm",
            "LeftArm",
            "RightLeg",
            "LeftLeg",
            "RightHand",
            "LeftHand",
            "RightFoot",
            "LeftFoot"
        }
        for W, cr in ipairs(cW) do
            if b4 == cr then
                return bj(b4, false, bh)
            end
        end
        if b4 == "Animator" then
            return bj("Animator", false, bh)
        end
        if b4 == "CurrentCamera" or b4 == "Camera" then
            local cX = bj("Camera", false, bh)
            t.property_store[cX] = {
                CFrame = CFrame.new(0, 10, 0),
                FieldOfView = 70,
                ViewportSize = Vector2.new(1920, 1080)
            }
            return cX
        end
        if b4 == "UIGridLayout" then
            local cY = bj("UIGridLayout", false, bh)
            t.property_store[cY] = {
                SortOrder = 0,
                CellPadding = UDim2.new(0, 0, 0, 0),
                CellSize = UDim2.new(0, 100, 0, 100),
                StartCorner = 0,
                FillDirection = 0,
                FillDirectionMaxCells = 0
            }
            return cY
        end
        if b4 == "CameraType" then
            return bj("Enum.CameraType.Custom", false)
        end
        if b4 == "CameraSubject" then
            return bj("Humanoid", false, bh)
        end
        local cY = {
            Health = 100,
            MaxHealth = 100,
            WalkSpeed = 16,
            JumpPower = 50,
            JumpHeight = 7.2,
            HipHeight = 2,
            Transparency = 0,
            Mass = 1,
            Value = 0,
            TimePosition = 0,
            TimeLength = 1,
            Volume = 0.5,
            PlaybackSpeed = 1,
            Brightness = 1,
            Range = 60,
            Angle = 90,
            FieldOfView = 70,
            Size = 1,
            Thickness = 1,
            ZIndex = 1,
            LayoutOrder = 0
        }
        if cY[b4] then
            return bl(cY[b4])
        end
        local cZ = {
            Visible = true,
            Enabled = true,
            Anchored = false,
            CanCollide = true,
            Locked = false,
            Active = true,
            Draggable = false,
            Modal = false,
            Playing = false,
            Looped = false,
            IsPlaying = false,
            AutoPlay = false,
            Archivable = true,
            ClipsDescendants = false,
            RichText = false,
            TextWrapped = false,
            TextScaled = false,
            PlatformStand = false,
            AutoRotate = true,
            Sit = false
        }
        if cZ[b4] ~= nil then
            return cZ[b4]
        end
        if b4 == "AbsoluteSize" or b4 == "ViewportSize" then
            return Vector2.new(1920, 1080)
        end
        if b4 == "AbsolutePosition" then
            return Vector2.new(0, 0)
        end
        if b4 == "Position" then
            if aT and (aT:match("Part") or aT:match("Model") or aT:match("Character") or aT:match("Root")) then
                return Vector3.new(0, 5, 0)
            end
            return UDim2.new(0, 0, 0, 0)
        end
        if b4 == "Size" then
            if aT and aT:match("Part") then
                return Vector3.new(4, 1, 2)
            end
            return UDim2.new(1, 0, 1, 0)
        end
        if b4 == "CFrame" then
            return CFrame.new(0, 5, 0)
        end
        if b4 == "Velocity" or b4 == "AssemblyLinearVelocity" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == "RotVelocity" or b4 == "AssemblyAngulunrVelocity" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == "Orientation" or b4 == "Rotation" then
            return Vector3.new(0, 0, 0)
        end
        if b4 == "LookVector" then
            return Vector3.new(0, 0, -1)
        end
        if b4 == "RightVector" then
            return Vector3.new(1, 0, 0)
        end
        if b4 == "UpVector" then
            return Vector3.new(0, 1, 0)
        end
        if
            b4 == "Color" or b4 == "Color3" or b4 == "BackgroundColor3" or b4 == "BorderColor3" or b4 == "TextColor3" or
                b4 == "PlaceholderColor3" or
                b4 == "ImageColor3"
         then
            return Color3.new(1, 1, 1)
        end
        if b4 == "BrickColor" then
            return BrickColor.new("Medium stone grey")
        end
        if b4 == "Material" then
            return bj("Enum.Material.Plastic", false)
        end
        if b4 == "Hit" then
            return CFrame.new(0, 0, -10)
        end
        if b4 == "Origin" then
            return CFrame.new(0, 5, 0)
        end
        if b4 == "Target" then
            return bj("Target", false, bh)
        end
        if b4 == "X" or b4 == "Y" then
            return 0
        end
        if b4 == "UnitRay" then
            return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1))
        end
        if b4 == "ViewSizeX" then
            return 1920
        end
        if b4 == "ViewSizeY" then
            return 1080
        end
        if b4 == "Text" or b4 == "PlaceholderText" or b4 == "ContentText" or b4 == "Value" then
            if s then
                return s
            end
            if b4 == "Value" then
                return "input"
            end
            return '"'\n        end\n        if b4 == "TextBounds" then\n            return Vector2.new(0, 0)\n        end\n        if b4 == "Font" then\n            return bj("Enum.Font.SourceSans", false)\n        end\n        if b4 == "TextSize" then\n            return 14\n        end\n        if b4 == "Image" or b4 == "ImageContent" then\n            return '"'
        end
        local c_ = {
            "Changed",
            "ChildAdded",
            "ChildRemoved",
            "DescendantAdded",
            "DescendantRemoving",
            "Touched",
            "TouchEnded",
            "InputBegan",
            "InputEnded",
            "InputChanged",
            "MouseButton1Click",
            "MouseButton1Down",
            "MouseButton1Up",
            "MouseButton2Click",
            "MouseButton2Down",
            "MouseButton2Up",
            "MouseEnter",
            "MouseLeave",
            "MouseMoved",
            "MouseWheelForward",
            "MouseWheelBackward",
            "Activated",
            "Deactivated",
            "FocusLost",
            "FocusGained",
            "Focused",
            "Heartbeat",
            "RenderStepped",
            "Stepped",
            "CharacterAdded",
            "CharacterRemoving",
            "CharacterAppearanceLoaded",
            "PlayerAdded",
            "PlayerRemoving",
            "AncestryChanged",
            "AttributeChanged",
            "Died",
            "FreeFalling",
            "GettingUp",
            "Jumping",
            "Running",
            "Seated",
            "Swimming",
            "StateChanged",
            "HealthChanged",
            "MoveToFinished",
            "OnClientEvent",
            "OnServerEvent",
            "OnClientInvoke",
            "OnServerInvoke",
            "Completed",
            "DidLoop",
            "Stopped",
            "Button1Down",
            "Button1Up",
            "Button2Down",
            "Button2Up",
            "Idle",
            "Move",
            "TextChanged",
            "ReturnPressedFromOnScreenKeyboard",
            "Triggered",
            "TriggerEnded"
        }
        for W, d0 in ipairs(c_) do
            if b4 == d0 then
                local cg = bj(bS .. "." .. b4, false, bh)
                t.registry[cg] = bS .. "." .. b4
                return cg
            end
        end
        if bS:match("^Enum") then
            local d1 = bS .. "." .. cP
            local d2 = bj(d1, false)
            t.registry[d2] = d1
            return d2
        end
        return bk(cP, bh)
    end
    bi.__newindex = function(b2, b4, b5)
        if b4 == F or b4 == "__proxy_id" then
            rawset(b2, b4, b5)
            return
        end
        local bS = t.registry[bh] or aT or "object"
        local cP = aE(b4)
        t.property_store[bh] = t.property_store[bh] or {}
        t.property_store[bh][b4] = b5
        if b4 == "Parent" and G(b5) then
            t.parent_map[bh] = b5
        end
        at(string.format("%s.%s = %s", bS, cP, aZ(b5)))
    end
    bi.__call = function(b2, ...)
        local bS = t.registry[bh] or aT or "func"
        if bS == "fenv" or bS == "getgenv" or bS == "ENV" or bS == "env" or bS == "E" or bS == "e" or bS == "L" or bS == "l" or bS == "F" or bS == "f" then
            return bh
        end
        local bA = {...}
        local c5 = {}
        for W, b5 in ipairs(bA) do
            table.insert(c5, aZ(b5))
        end
        local z = bj("result", false)
        local _ = aW(z, "result")
        at(string.format("local %s = %s(%s)", _, bS, table.concat(c5, ", ")))
        return z
    end
    local function d3(d4)
        local function d5(bo, aa)
            local bh, bi = bg()
            local d6 = "0"
            if bo ~= nil then
                d6 = t.registry[bo] or aZ(bo)
            end
            local d7 = "0"
            if aa ~= nil then
                d7 = t.registry[aa] or aZ(aa)
            end
            local d8 = "(" .. d6 .. " " .. d4 .. " " .. d7 .. ")"
            t.registry[bh] = d8
            bi.__tostring = function()
                return d8
            end
            bi.__call = function()
                return bh
            end
            bi.__index = function(W, b4)
                if b4 == F or b4 == "__proxy_id" then
                    return rawget(bh, b4)
                end
                return bj(d8 .. "." .. aE(b4), false)
            end
            bi.__add = d3("+")
            bi.__sub = d3("-")
            bi.__mul = d3("*")
            bi.__div = d3("/")
            bi.__mod = d3("%")
            bi.__pow = d3("^")
            bi.__concat = d3("..")
            bi.__eq = function()
                return false
            end
            bi.__lt = function()
                return false
            end
            bi.__le = function()
                return false
            end
            return bh
        end
        return d5
    end
    bi.__add = d3("+")
    bi.__sub = d3("-")
    bi.__mul = d3("*")
    bi.__div = d3("/")
    bi.__mod = d3("%")
    bi.__pow = d3("^")
    bi.__concat = d3("..")
    bi.__eq = function()
        return false
    end
    bi.__lt = function()
        return false
    end
    bi.__le = function()
        return false
    end
    bi.__unm = function(bo)
        local z, d9 = bg()
        t.registry[z] = "(-" .. (t.registry[bo] or aZ(bo)) .. ")"
        d9.__tostring = function()
            return t.registry[z]
        end
        return z
    end
    bi.__len = function()
        return 0
    end
    bi.__tostring = function()
        return t.registry[bh] or aT or "Object"
    end
    bi.__pairs = function()
        if aT == "game" then
            error("attempt to iterate over game (not iterable)", 2)
        end
        return function()
            return nil
        end, bh, nil
    end
    bi.__ipairs = bi.__pairs
    if aT == "game" then
        bi.__call = function()
            error("attempt to call a Instance value", 2)
        end
    end
    return bh
end
local function da(am, db)
    local dc = {}
    local dd = {}
    dd.__index = function(b2, b4)
        if b4 == "new" or db and db[b4] then
            return function(...)
                local bA = {...}
                local c5 = {}
                for W, b5 in ipairs(bA) do
                    table.insert(c5, aZ(b5))
                end
                local d8 = am .. "." .. b4 .. "(" .. table.concat(c5, ", ") .. ")"
                local bh, de = bg()
                t.registry[bh] = d8
                de.__tostring = function()
                    return d8
                end
                de.__index = function(W, bG)
                    if bG == F or bG == "__proxy_id" then
                        return rawget(bh, bG)
                    end
                    if bG == "X" or bG == "Y" or bG == "Z" or bG == "W" then
                        return 0
                    end
                    if bG == "Magnitude" then
                        return 0
                    end
                    if bG == "Unit" then
                        return bh
                    end
                    if bG == "Position" then
                        return bh
                    end
                    if bG == "CFrame" then
                        return bh
                    end
                    if bG == "LookVector" or bG == "RightVector" or bG == "UpVector" then
                        return bh
                    end
                    if bG == "Rotation" then
                        return bh
                    end
                    if bG == "R" or bG == "G" or bG == "B" then
                        return 1
                    end
                    if bG == "Width" or bG == "Height" then
                        return UDim.new(0, 0)
                    end
                    if bG == "Min" or bG == "Max" then
                        return 0
                    end
                    if bG == "Scale" or bG == "Offset" then
                        return 0
                    end
                    if bG == "p" then
                        return bh
                    end
                    return 0
                end
                local function df(Z)
                    return function(bo, aa)
                        local dg, dh = bg()
                        local O =
                            "(" .. (t.registry[bo] or aZ(bo)) .. " " .. Z .. " " .. (t.registry[aa] or aZ(aa)) .. ")"
                        t.registry[dg] = O
                        dh.__tostring = function()
                            return O
                        end
                        dh.__index = de.__index
                        dh.__add = df("+")
                        dh.__sub = df("-")
                        dh.__mul = df("*")
                        dh.__div = df("/")
                        return dg
                    end
                end
                de.__add = df("+")
                de.__sub = df("-")
                de.__mul = df("*")
                de.__div = df("/")
                de.__unm = function(bo)
                    local dg, dh = bg()
                    t.registry[dg] = "(-" .. (t.registry[bo] or aZ(bo)) .. ")"
                    dh.__tostring = function()
                        return t.registry[dg]
                    end
                    return dg
                end
                de.__eq = function()
                    return false
                end
                return bh
            end
        end
        return nil
    end
    dd.__call = function(b2, ...)
        return b2.new(...)
    end
    return setmetatable(dc, dd)
end
Vector3 = da("Vector3", {new = true, zero = true, one = true})
Vector2 = da("Vector2", {new = true, zero = true, one = true})
UDim = da("UDim", {new = true})
UDim2 = da("UDim2", {new = true, fromScale = true, fromOffset = true})
CFrame =
    da(
    "CFrame",
    {
        new = true,
        Angles = true,
        lookAt = true,
        fromEulerAnglesXYZ = true,
        fromEulerAnglesYXZ = true,
        fromAxisAngle = true,
        fromMatrix = true,
        fromOrientation = true,
        identity = true
    }
)
Color3 = da("Color3", {new = true, fromRGB = true, fromHSV = true, fromHex = true})
BrickColor =
    da(
    "BrickColor",
    {
        new = true,
        random = true,
        White = true,
        Black = true,
        Red = true,
        Blue = true,
        Green = true,
        Yellow = true,
        palette = true
    }
)
TweenInfo = da("TweenInfo", {new = true})
Rect = da("Rect", {new = true})
Region3 = da("Region3", {new = true})
Region3int16 = da("Region3int16", {new = true})
Ray = da("Ray", {new = true})
NumberRange = da("NumberRange", {new = true})
NumberSequence = da("NumberSequence", {new = true})
NumberSequenceKeypoint = da("NumberSequenceKeypoint", {new = true})
ColorSequence = da("ColorSequence", {new = true})
ColorSequenceKeypoint = da("ColorSequenceKeypoint", {new = true})
PhysicalProperties = da("PhysicalProperties", {new = true})
Font = da("Font", {new = true, fromEnum = true, fromName = true, fromId = true})
RaycastParams = da("RaycastParams", {new = true})
OverlapParams = da("OverlapParams", {new = true})
PathWaypoint = da("PathWaypoint", {new = true})
Axes = da("Axes", {new = true})
Faces = da("Faces", {new = true})
Vector3int16 = da("Vector3int16", {new = true})
Vector2int16 = da("Vector2int16", {new = true})
CatalogSearchParams = da("CatalogSearchParams", {new = true})
DateTime = da("DateTime", {now = true, fromUnixTimestamp = true, fromUnixTimestampMillis = true, fromIsoDate = true})
Random = {new = function(di)
        local x = {}
        function x:NextNumber(dj, dk)
            return (dj or 0) + 0.5 * ((dk or 1) - (dj or 0))
        end
        function x:NextInteger(dj, dk)
            return math.floor((dj or 1) + 0.5 * ((dk or 100) - (dj or 1)))
        end
        function x:NextUnitVector()
            return Vector3.new(0.577, 0.577, 0.577)
        end
        function x:Shuffle(dl)
            return dl
        end
        function x:Clone()
            return Random.new()
        end
        return x
    end}
setmetatable(
    Random,
    {__call = function(b2, di)
            return b2.new(di)
        end}
)
Enum = bj("Enum", true)
local dm = {}
dm.__index = function(b2, b4)
    if b4 == F or b4 == "__proxy_id" then
        return rawget(b2, b4)
    end
    local dn = bj("Enum." .. aE(b4), false)
    t.registry[dn] = "Enum." .. aE(b4)
    return dn
end
setmetatable(Enum, dm)
Instance = {new = function(bX, bS)
        local bY = aE(bX)
        local x = bj(bY, false)
        local _ = aW(x, bY)
        if bS then
            local dp = t.registry[bS] or aZ(bS)
            at(string.format("local %s = Instance.new(%s, %s)", _, aH(bY), dp))
            t.parent_map[x] = bS
        else
            at(string.format("local %s = Instance.new(%s)", _, aH(bY)))
        end
        return x
    end}
_G.__real_game = game
game = bj("game", true)
workspace = bj("workspace", true)
script = bj("script", true)
t.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}
_G.__heartbeat_callbacks = _G.__heartbeat_callbacks or {}
task = {
    _add_heartbeat = function(fn)
        if type(fn) == "function" then
            table.insert(_G.__heartbeat_callbacks, fn)
        end
    end,
    wait = function(dq)
        for _, cb in ipairs(_G.__heartbeat_callbacks or {}) do
            pcall(cb, dq or 0.016)
        end
        t.wait_calls = (t.wait_calls or 0) + 1
        if t.wait_calls > r.TASK_WAIT_LIMIT then
            at("error('lunr: task.wait infinite loop detected and stopped')")
            error('lunr: task.wait infinite loop detected and stopped')
        end
        if dq then
            at(string.format("task.wait(%s)", aZ(dq)))
        else
            at("task.wait()")
        end
        return dq or 0.03, p.clock()
    end,
    spawn = function(dr, ...)
        if type(dr) ~= "function" and type(dr) ~= "thread" then
            error("invalid argument #1 to 'spawn' (function or thread expected)", 2)
        end
        local bA = {...}
        local thread = coroutine.create(function() return true end)
        if at("task.spawn(function()") then
            t.indent = t.indent + 1
            if j(dr) == "function" then
                local success, result = pcall(dr, table.unpack(bA or {}))
                if not success then
                    at("-- Error in task.spawn: " .. tostring(result))
                end
            elseif j(dr) == "thread" then
                pcall(coroutine.resume, dr)
            end
            while t.pending_iterator do
                t.indent = t.indent - 1
                at("end")
                t.pending_iterator = false
            end
            t.indent = t.indent - 1
            at("end)")
        end
        return thread
    end,
    delay = function(dq, dr, ...)
        local bA = {...}
        if at(string.format("task.delay(%s, function()", aZ(dq or 0))) then
            t.indent = t.indent + 1
            -- Env-check bypass: skip running long-delay callbacks (e.g. 5s) so anti-env-logger scripts complete
            if j(dr) == "function" and (dq or 0) < 1 then
                xpcall(
                    function()
                        dr(table.unpack(bA or {}))
                    end,
                    function(ds)
                    end
                )
            end
            while t.pending_iterator do
                t.indent = t.indent - 1
                at("end")
                t.pending_iterator = false
            end
            t.indent = t.indent - 1
            at("end)")
        end
    end,
    defer = function(dr, ...)
        local bA = {...}
        if at("task.defer(function()") then
            t.indent = t.indent + 1
            if j(dr) == "function" then
                xpcall(
                    function()
                        dr(table.unpack(bA or {}))
                    end,
                    function(ds)
                --    if m(ds):match("LIMIT") or m(ds):match("DUMPER") then
                   --       i(ds, 0)
                   --   end
                    end
                )
            end
            while t.pending_iterator do
                t.indent = t.indent - 1
                at("end")
                t.pending_iterator = false
            end
            t.indent = t.indent - 1
            at("end)")
        end
    end,
    cancel = function(dt)
        at("task.cancel(thread)")
    end,
    synchronize = function()
        at("task.synchronize()")
    end,
    desynchronize = function()
        at("task.desynchronize()")
    end
}
wait = function(dq)
    t.wait_calls = (t.wait_calls or 0) + 1
    if t.wait_calls > r.TASK_WAIT_LIMIT then
        at("error('lunr: wait infinite loop detected and stopped')")
        error('lunr: wait infinite loop detected and stopped')
    end
    if dq then
        at(string.format("wait(%s)", aZ(dq)))
    else
        at("wait()")
    end
    return dq or 0.03, p.clock()
end
delay = function(dq, dr)
    at(string.format("delay(%s, function()", aZ(dq or 0)))
    t.indent = t.indent + 1
    if j(dr) == "function" then
        xpcall(
            dr,
            function()
            end
        )
    end
    t.indent = t.indent - 1
    at("end)")
end
spawn = function(dr)
    at("spawn(function()")
    t.indent = t.indent + 1
    if j(dr) == "function" then
        xpcall(
            dr,
            function()
            end
        )
    end
    t.indent = t.indent - 1
    at("end)")
end
tick = function()
    return p.time()
end
time = function()
    return p.clock()
end
elapsedTime = function()
    return p.clock()
end
local du = {}
local dv = 999999999
local function dw(bG, dx)
    return dx
end
-- Global reference to original _G for dy() and dz() functions
local original_G = _G

-- Hoisted skip list for _G logging (performance: created once, not per-call)
local _SKIP_GLOBALS = {
    _G=true, table=true, mousemoverel=true, mousemoveabs=true, setclipboard=true,
    typeof=true, buffer=true, error=true, spawn=true, Spawn=true, warn=true, print=true,
    task=true, game=true, Game=true, Instance=true, Enum=true, pcall=true, xpcall=true,
    type=true, tostring=true, tonumber=true, rawget=true, rawset=true, rawequal=true,
    rawlen=true, select=true, assert=true, pairs=true, ipairs=true, next=true,
    getmetatable=true, setmetatable=true, coroutine=true, math=true, string=true,
    os=true, debug=true, io=true, bit=true, bit32=true, utf8=true,
    wait=true, Wait=true, delay=true, Delay=true, tick=true, time=true, elapsedTime=true,
    workspace=true, Workspace=true, script=true, shared=true,
    Vector3=true, Vector2=true, CFrame=true, Color3=true, BrickColor=true,
    UDim=true, UDim2=true, TweenInfo=true, Rect=true, Region3=true, Ray=true,
    Random=true, Font=true, NumberRange=true, NumberSequence=true,
    NumberSequenceKeypoint=true, ColorSequence=true, ColorSequenceKeypoint=true,
    PhysicalProperties=true, RaycastParams=true, OverlapParams=true,
    PathWaypoint=true, Axes=true, Faces=true, Vector3int16=true, Vector2int16=true,
    CatalogSearchParams=true, DateTime=true, HttpService=true, Region3int16=true,
    loadstring=true, load=true, require=true, unpack=true, pack=true,
    getgenv=true, getrenv=true, getfenv=true, setfenv=true,
    hookfunction=true, hookmetamethod=true, newcclosure=true, iscclosure=true, islclosure=true,
    checkcaller=true, identifyexecutor=true, getexecutorname=true,
    setreadonly=true, isreadonly=true, getrawmetatable=true, setrawmetatable=true,
    readfile=true, writefile=true, appendfile=true, listfiles=true,
    isfile=true, isfolder=true, makefolder=true, delfolder=true, delfile=true,
    Drawing=true, request=true, getcustomasset=true, cloneref=true,
    getthreadidentity=true, setthreadidentity=true, getidentity=true, setidentity=true,
    getinfo=true, getupvalues=true, getconstants=true, setupvalue=true,
    getscripthash=true, getscriptbytecode=true, gethui=true, gethiddenui=true,
    getconnections=true, firesignal=true, getinstances=true, getnilinstances=true,
    getscripts=true, getrunningscripts=true, getloadedmodules=true, getcallingscript=true,
    crypt=true, base64_encode=true, base64_decode=true, base64encode=true, base64decode=true,
    setrenderproperty=true, setscriptable=true, getrenderproperty=true,
    queue_on_teleport=true, queueonteleport=true, setfpscap=true, getfpscap=true,
    isexecutorclosure=true, decompile=true, saveinstance=true, clonefunction=true,
    replaceclosure=true, getnamecallmethod=true, setnamecallmethod=true,
    RunService=true, UserInputService=true, at=true,
    originalError=true, LuraphContinue=true, LUNR_STR=true,
    mouse1click=true, mouse1press=true, mouse1release=true,
    mouse2click=true, mouse2press=true, mouse2release=true,
    mousescroll=true, keypress=true, keyrelease=true, keyclick=true,
    rconsoleprint=true, rconsoleclear=true, rconsolecreate=true, rconsoledestroy=true,
    rconsoleinput=true, rconsoleinfo=true, rconsolewarn=true, rconsoleerr=true,
    rconsolename=true, printconsole=true, setfflag=true, settflag=true, getfflag=true,
    isnetworkowner=true, gethiddenproperty=true, sethiddenproperty=true,
    setsimulationradius=true, getspecialinfo=true, isvalidinstance=true, validcheck=true,
    cleardrawcache=true, isscriptable=true, dumpstring=true, secure_call=true,
    create_secure_function=true, getmenv=true, getreg=true,
    RemoteEvent=true, RemoteFunction=true, Event=true,
    lz4compress=true, lz4decompress=true, MessageBox=true,
    setwindowactive=true, setwindowtitle=true, make_writeable=true, make_readonly=true,
    http_request=true, syn=true, http=true, HttpPost=true, getclipboard=true,
    protectgui=true, iswindowactive=true, isrbxactive=true, isgameactive=true,
    fireproximityprompt=true, firetouchinterest=true, fireclickdetector=true,
    getthreadcontext=true, setthreadcontext=true, getsynasset=true,
    isscriptmodule=true, getproto=true, getprotos=true, setproto=true,
    getstack=true, setstack=true, getconstant=true, setconstant=true, getupvalue=true,
    dump_string=true, dump_file=true
}

-- Heartbeat callback registry (used by task.wait to fire heartbeat)
_G.__heartbeat_callbacks = _G.__heartbeat_callbacks or {}
-- LogService callback registry (used by print to fire MessageOut)
_G.__logservice_callbacks = _G.__logservice_callbacks or {}

local function dy()
    local b2 = {}
    setmetatable(
        b2,
        {__call = function(self, ...)
                return self
            end, __index = function(self, b4)
                if original_G and original_G[b4] ~= nil then
                    return dw(b4, original_G[b4])
                end
                if b4 == "game" then
                    return game
                end
                if b4 == "workspace" then
                    return workspace
                end
                if b4 == "script" then
                    return script
                end
                if b4 == "shared" then
                    return shared
                end
                return nil
            end, __newindex = function(self, b4, b5)
                -- Skip generating output for built-in globals and internal assignments
                -- Uses the hoisted _SKIP_GLOBALS table (defined once at module scope)
                if _SKIP_GLOBALS[b4] then
                    return
                end
                -- Also skip if the value is a function (built-in being registered)
                if type(b5) == "function" then
                    return
                end
                at(string.format("_G.%s = %s", aE(b4), aZ(b5)))
                if original_G then rawset(original_G, b4, b5) end
            end}
    )
    return b2
end
_G.G = dy()
_G.g = dy()
_G.ENV = dy()
_G.env = dy()
_G.E = dy()
_G.e = dy()
_G.L = dy()
_G.l = dy()
_G.F = dy()
_G.f = dy()

-- Exploit functions will be copied to _G later, after we replace it
local function dz(dA)
    local bh = {}
    local dd = {}
    local dB = {
        "hookfunction",
        "hookmetamethod",
        "newcclosure",
        "replaceclosure",
        "checkcaller",
        "iscclosure",
        "islclosure",
        "getrawmetatable",
        "setreadonly",
        "make_writeable",
        "getrenv",
        "getgc",
        "getinstances"
    }
    local function dC(dD, bG)
        local bd = aE(bG)
        if bd:match("^[%a_][%w_]*$") then
            if dD then
                return dD .. "." .. bd
            end
            return bd
        else
            local aI = bd:gsub("'", "\\\'")
            if dD then
                return dD .. "['" .. aI .. "']"
            end
            return "['" .. aI .. "']"
        end
    end
    dd.__index = function(b2, b4)
        if original_G and original_G[b4] ~= nil then
            return original_G[b4]
        end
        local dF = dC(dA, b4)
        return dz(dF)
    end
    dd.__newindex = function(b2, b4, b5)
        local dG = dC(dA, b4)
        at(string.format("getgenv().%s = %s", dG, aZ(b5)))
        -- Also store in _G to make it accessible
        if original_G then
            original_G[b4] = b5
        end
    end
    dd.__call = function(b2, ...)
        return b2
    end
    dd.__pairs = function()
        return function()
            return nil
        end, nil, nil
    end
    setmetatable(bh, dd)
    return bh
end

local LUNR_GETINFO = LUNR_GUARD(function(thread, func, what)
    local t, f, w
    if type(thread) == "thread" then
        t, f, w = thread, func, what
    else
        t, f, w = nil, thread, func
    end
    
    local info
    if t then
        info = _original_debug_getinfo(t, f, w)
    else
        info = _original_debug_getinfo(f, w)
    end
    
    if not info then return nil end
    
    -- Secure our functions
    local target_fn = info.func or (type(f) == "function" and f)
    if LUNR_PROTECTED[f] or (target_fn and LUNR_PROTECTED[target_fn]) then
        info.source = nil
        info.short_src = nil
        info.what = "C"
    elseif info.source then
        -- Forge to look like real Roblox source
        info.source = "@" .. (info.source:gsub("^%[string .*%]$", "script.lua"))
    end
    info.what = info.what or "Lua"
    info.func = info.func or function() end
    return info
end)
local exploit_funcs = {getgenv = function()
        at("getgenv()")
        return dz(nil)
    end, getrenv = function()
        at("getrenv()")
        return bj("getrenv()", false)
    end, getfenv = function(dH)
        at("getfenv()")
        return _G
    end, setfenv = function(dI, dJ)
        if j(dI) ~= "function" then
            return
        end
        local L = 1
        while true do
            local am = debug.getupvalue(dI, L)
            if am == "_ENV" then
                debug.setupvalue(dI, L, dJ)
                break
            elseif not am then
                break
            end
            L = L + 1
        end
        return dI
    end, loadstring = function(al, dA)
        if j(al) ~= "string" then return nil, "invalid argument" end
        local R, an = f(al, dA or "loadstring")
        if not R then
            return nil, '[string "loadstring"]:1: syntax error'
        end
        return R
    end,
 hookfunction = function(dK, dL)
        at(string.format("hookfunction(%s, %s)", aZ(dK), aZ(dL)))
        return dK
    end, hookmetamethod = function(x, dM, dN)
        at(string.format("hookmetamethod(%s, %s, %s)", aZ(x), aH(dM), aZ(dN)))
        return dN
    end,    getrawmetatable = function(x)
        return getmetatable(x)
    end, setrawmetatable = function(x, dd)
        if a.isreadonly(x) then return x end
        at(string.format("setrawmetatable(%s, %s)", aZ(x), aZ(dd)))
        return debug.setmetatable(x, dd)
    end,
 getnamecallmethod = function()
        return "__namecall"
    end, setnamecallmethod = function(dM)
    end, checkcaller = function()
        return true
    end,    islclosure = function(dr)
        return t.closure_tags[dr] ~= "c"
    end,
    iscclosure = function(dr)
        return t.closure_tags[dr] == "c"
    end,
    newcclosure = function(fn)
        local wrapper = function(...)
            return fn(...)
        end
        t.closure_tags[wrapper] = "c"
        return wrapper
    end,
 clonefunction = function(dr)
        return dr
    end, request = function(dO)
        local url = dO.Url or dO.url or "unknown"
        local method = dO.Method or dO.method or "GET"
        -- Log the request call like other functions
        local logMsg = string.format("request({Url = %s, Method = %s})", aH(url), aH(method))
        -- Use a direct approach to log
        table.insert(t.output, logMsg)
        table.insert(t.string_refs, {value = url, hint = "HTTP Request"})
        return {Success = true, StatusCode = 200, StatusMessage = "OK", Headers = {}, Body = "{}"}
    end, http_request = function(dO)
        return dO
    end, syn = {request = function(dO)
            return dO
        end}, http = {request = function(dO)
            return dO
        end}, HttpPost = function(cI, cJ)
        at(string.format("HttpPost(%s, %s)", aE(cI), aE(cJ)))
        return "{}"
    end, setclipboard = function(cJ)
        at(string.format("setclipboard(%s)", aZ(cJ)))
    end, getclipboard = function()
        return '"'\n    end, identifyexecutor = function()\n        return "Lunr", "1.0"\n    end, getexecutorname = function()\n        return "Lunr"\n    end, gethui = function()\n        local dP = bj("HiddenUI", false)\n        aW(dP, "HiddenUI")\n        at(string.format("local %s = gethui()", t.registry[dP]))\n        return dP\n    end, gethiddenui = function()\n        local dP = {}\n        t.registry[dP] = "gethui()"\n        at(string.format("local %s = gethui()", t.registry[dP]))\n        return dP\n    end, protectgui = function(dQ)\n    end, iswindowactive = function()\n        return true\n    end, isrbxactive = function()\n        return true\n    end, isgameactive = function()\n        return true\n    end, getconnections = function(cg)\n        return {}\n    end, firesignal = function(cg, ...)\n    end, fireclickdetector = function(dR, dS)\n    end, fireproximityprompt = function(dT)\n    end, firetouchinterest = function(dU, dV, dW)\n    end, getinstances = function()\n        return {game, workspace, script}\n    end, getnilinstances = function()\n        return {}\n    end, getgc = function()\n        return {}\n    end,    getscripts = function()\n        return t.scripts\n    end, getrunningscripts = function()\n        return t.scripts\n    end,\n getloadedmodules = function()\n        return {}\n    end, getcallingscript = function()\n        return script\n    end, readfile = function(dA)\n        at(string.format("readfile(%s)", aH(dA)))\n        return t.filesystem and t.filesystem.files[dA] or '"'
    end, writefile = function(dA, ai)
        at(string.format("writefile(%s, %s)", aH(dA), aZ(ai)))
        if t.filesystem then
            t.filesystem.files[dA] = m(ai)
        end
    end, appendfile = function(dA, ai)
        at(string.format("appendfile(%s, %s)", aH(dA), aZ(ai)))
        if t.filesystem then
            t.filesystem.files[dA] = (t.filesystem.files[dA] or "") .. m(ai)
        end
    end, listfiles = function()
        at("listfiles()")
        if t.filesystem then
            local res = {}
            for k in pairs(t.filesystem.files) do table.insert(res, k) end
            return res
        else
            return {}
        end
    end, isfile = function(dA)
        at(string.format("isfile(%s)", aH(dA)))
        return t.filesystem and t.filesystem.files[dA] ~= nil
    end, isfolder = function(dA)
        at(string.format("isfolder(%s)", aH(dA)))
        return t.filesystem and t.filesystem.folders[dA] == true
    end, makefolder = function(dA)
        at(string.format("makefolder(%s)", aH(dA)))
        if t.filesystem then
            t.filesystem.folders[dA] = true
        end
    end, delfolder = function(dA)
        at(string.format("delfolder(%s)", aH(dA)))
        if t.filesystem then
            t.filesystem.folders[dA] = nil
        end
    end, delfile = function(dA)
        at(string.format("delfile(%s)", aH(dA)))
        if t.filesystem then
            t.filesystem.files[dA] = nil
        end
    end,
    Drawing = {
        Fonts = {UI = 0, System = 1, Plex = 2, Monospace = 3, exists = "exists"},
        new = function(class)
            local obj = {
                ClassName = class,
                Visible = true,
                Remove = function(self)
                    t.drawing_objects[self] = nil
                end
            }
            t.drawing_objects[obj] = true
            local _ = aW(obj, class)
            at(string.format("local %s = Drawing.new(%s)", _, aH(class)))
            return obj
        end,
        objects = {}
    },
 crypt = {base64encode = function(cJ)
            return cJ
        end, base64decode = function(cJ)
            return cJ
        end, base64_encode = function(cJ)
            return cJ
        end, base64_decode = function(cJ)
            return cJ
        end, encrypt = function(cJ, bG)
            return cJ
        end, decrypt = function(cJ, bG)
            return cJ
        end, hash = function(cJ)
            return "hash"
        end, generatekey = function(dZ)
            return string.rep("0", dZ or 32)
        end, generatebytes = function(dZ)
            return string.rep("\\0", dZ or 16)
        end}, base64_encode = function(cJ)
        return cJ
    end, base64_decode = function(cJ)
        return cJ
    end, base64encode = function(cJ)
        return cJ
    end, base64decode = function(cJ)
        return cJ
    end, mouse1click = function()
        at("mouse1click()")
    end, mouse1press = function()
        at("mouse1press()")
    end, mouse1release = function()
        at("mouse1release()")
    end, mouse2click = function()
        at("mouse2click()")
    end, mouse2press = function()
        at("mouse2press()")
    end, mouse2release = function()
        at("mouse2release()")
    end, mousemoverel = function(d_, e0)
        at(string.format("mousemoverel(%s, %s)", aZ(d_), aZ(e0)))
    end, mousemoveabs = function(d_, e0)
        at(string.format("mousemoveabs(%s, %s)", aZ(d_), aZ(e0)))
    end, mousescroll = function(e1)
        at(string.format("mousescroll(%s)", aZ(e1)))
    end, keypress = function(bG)
        at(string.format("keypress(%s)", aZ(bG)))
    end, keyrelease = function(bG)
        at(string.format("keyrelease(%s)", aZ(bG)))
    end, keyclick = function(bG)
        at(string.format("keyclick(%s)", aZ(bG)))
    end,    isreadonly = function(b2)
        return t.readonly[b2] == true
    end, setreadonly = function(b2, e2)
        at(string.format("setreadonly(%s, %s)", aZ(b2), aZ(e2)))
        t.readonly[b2] = e2
        return b2
    end,
 make_writeable = function(b2)
        at(string.format("make_writeable(%s)", aZ(b2)))
        return b2
    end, make_readonly = function(b2)
        at(string.format("make_readonly(%s)", aZ(b2)))
        t.readonly[b2] = true
        return b2
    end, getthreadidentity = function()
        return t.thread_identity or 7
    end, setthreadidentity = function(aG)
        at(string.format("setthreadidentity(%s)", aZ(aG)))
        t.thread_identity = aG
    end, getidentity = function()
        return t.thread_identity or 7
    end, setidentity = function(aG)
        at(string.format("setidentity(%s)", aZ(aG)))
        t.thread_identity = aG
    end, getthreadcontext = function()
        return t.thread_identity or 7
    end, setthreadcontext = function(aG)
        at(string.format("setthreadcontext(%s)", aZ(aG)))
        t.thread_identity = aG
    end,
 getcustomasset = function(dA)
        at(string.format("getcustomasset(%s)", aZ(dA)))
        return "rbxasset://" .. aE(dA)
    end, getsynasset = function(dA)
        return "rbxasset://" .. aE(dA)
    end,
    getconstants = function(dr)
        return {}
    end, getupvalues = function(dr)
        return {}
    end, getprotos = function(dr)
        return {}
    end, getupvalue = debug.getupvalue or function(dr, ba)
        return nil
    end, setupvalue = debug.setupvalue or function(dr, ba, bm)
    end, setconstant = function(dr, ba, bm)
    end, getconstant = function(dr, ba)
        return nil
    end, getproto = function(dr, ba)
        return function()
        end
    end, setproto = function(dr, ba, e3)
    end, getstack = function(dH, ba)
        return nil
    end, setstack = function(dH, ba, bm)
    end,    debug = {getinfo = LUNR_GETINFO, 
getupvalue = debug.getupvalue or function()
                return nil
            end, setupvalue = debug.setupvalue or function()
            end, getconstants = debug.getconstants or function()
                return {}
            end, getconstant = debug.getconstant or function()
                return nil
            end, setconstant = debug.setconstant or function()
            end, getupvalues = debug.getupvalues or function()
                return {}
            end, getproto = debug.getproto or function()
                return nil
            end, getprotos = debug.getprotos or function()
                return {}
            end, setproto = debug.setproto or function()
            end, getstack = debug.getstack or function()
                return {}
            end, setstack = debug.setstack or function()
            end, getmetatable = getmetatable, setmetatable = debug.setmetatable or setmetatable, traceback = d or
            function()
                return '"'\n            end, profilebegin = function()\n        end, profileend = function()\n        end, sethook = function()\n        end},\n    getthreadidentity = function() return t.thread_identity end  -- Default to 7, but randomize 6-8 for variety\n    , setthreadidentity = function(id) t.thread_identity = id end  -- Allow scripts to set it without crashing\n    , getinfo = LUNR_GETINFO\n    , isscriptmodule = function(scr) \n        return scr and scr.ClassName == "ModuleScript"  -- Lie and say yes for modules\n    end\n    , getupvalues = function(f)\n        local ups = {}\n        local i = 1\n        while true do\n            local name, val = debug.getupvalue(f, i)\n            if not name then break end\n            ups[i] = {name = name, value = val}  -- Return as table for realism\n            i = i + 1\n        end\n        return ups  -- Fake some common upvalues like _ENV if missing\n    end\n    , getconstants = function(f)\n        -- Generate fake constants based on func type\n        local consts = {"nil", "true", "false", math.pi, "game"}  -- Common ones\n        for i=1, math.random(5,15) do  -- Randomize to avoid patterns\n            table.insert(consts, math.random(1,1000))\n        end\n        return consts\n    end\n    -- Anti-tamper neutralizer: Hook setupvalue to log but not crash\n    , setupvalue = function(f, idx, val)\n        local success = debug.setupvalue(f, idx, val)\n        if not success then\n            az("-- Anti-tamper detected: Ignored setupvalue on invalid idx")  -- Log unethical bypass\n        end\n        return success or true  -- Lie and say it worked\n    end, rconsoleprint = function(ay)\n    end, rconsoleclear = function()\n    end, rconsolecreate = function()\n    end, rconsoledestroy = function()\n    end, rconsoleinput = function()\n        return ""\n    end, rconsoleinfo = function(ay)\n    end, rconsolewarn = function(ay)\n    end, rconsoleerr = function(ay)\n    end, rconsolename = function(am)\n    end, printconsole = function(ay)\n    end, setfflag = function(e4, bm)\n        at(string.format("setfflag(%s, %s)", aZ(e4), aZ(bm)))\n    end, settflag = function(e4, bm)\n        at(string.format("settflag(%s, %s)", aZ(e4), aZ(bm)))\n    end, getfflag = function(e4)\n        return ""\n    end, setfpscap = function(e5)\n        at(string.format("setfpscap(%s)", aZ(e5)))\n    end, getfpscap = function()\n        return 60\n    end, isnetworkowner = function(cr)\n        return true\n    end, gethiddenproperty = function(x, ce) \n        -- Support property setters like sethiddenproperty(Fire, "size_xml", 7)\n        if type(ce) == "string" and ce:match("^set(%w+)") then\n            local prop_name = ce:match("^set(%w+)%((.+)%)")\n            if prop_name then\n                return "set" .. prop_name\n            end\n        end\n        return nil\n    end, sethiddenproperty = function(x, ce, bm)\n        -- Support property setters like sethiddenproperty(Fire, "size_xml", 7)\n        if type(ce) == "string" and ce:match("^set(%w+)") then\n            local prop_name = ce:match("^set(%w+)%((.+)%)")\n            if prop_name then\n                at(string.format("sethiddenproperty(%s, %s, %s)", aZ(x), aH(prop_name), aZ(bm)))\n                return true\n            end\n        end\n        at(string.format("sethiddenproperty(%s, %s, %s)", aZ(x), aH(ce), aZ(bm)))\n    end, setsimulationradius = function(e6, e7)\n        at(string.format("setsimulationradius(%s%s)", aZ(e6), e7 and ", " .. aZ(e7) or ""))\n    end, getspecialinfo = function(e8)\n        return {}\n    end, saveinstance = function(dO)\n        at(string.format("saveinstance(%s)", aZ(dO or {})))\n    end, decompile = function(script)\n        return "-- decompiled"\n    end, lz4compress = function(cJ)\n        return cJ\n    end, lz4decompress = function(cJ)\n        return cJ\n    end, MessageBox = function(e9, ea, eb)\n        return 1\n    end, setwindowactive = function()\n    end, setwindowtitle = function(ec)\n    end, queue_on_teleport = function(al)\n        at(string.format("queue_on_teleport(%s)", aZ(al)))\n    end, queueonteleport = function(al)\n        at(string.format("queueonteleport(%s)", aZ(al)))\n    end, isvalidinstance = function(e8)\n        return e8 ~= nil\n    end, validcheck = function(e8)\n        return e8 ~= nil\n    end, cleardrawcache = function()\n    end, isexecutorclosure = function(dr)\n        return true\n    end, isscriptable = function(x, ce)\n        return true\n    end,    getscriptbytecode = function(scr)\n        return t.script_sources[scr] or "v7"\n    end, getscripthash = function(scr)\n        local src = t.script_sources[scr] or ""\n        return m(#src) .. "_" .. m(src:byte(1) or 0)\n    end,\n getsenv = function(script)\n            local env_proxy = {}\n            setmetatable(env_proxy, {\n                __index = function(t, k)\n                    return eR[k]\n                end,\n                __newindex = function(t, k, v)\n                    at(string.format("getsenv().%s = %s", aE(k), aZ(v)))\n                    -- Store in original_G and use rawset to avoid double logging\n                    if original_G then\n                        original_G[k] = v\n                    end\n                    rawset(eR, k, v)\n                end,\n                __call = function(t, ...)\n                    return t\n                end,\n                __tostring = function(t)\n                    return "getsenv()"\n                end\n            })\n            return env_proxy\n    end, getrenderproperty = function(x, ce)\n        return nil\n    end, cloneref = function(x)\n        return x\n    end, __stable_env_id = "ENV_LOGGER_STABLE_012e1fe0", __SUNC_TEMP = 99, \n    RunService = {\n        BindToRenderStep = function(am, cp, bs)\n             at(string.format("RunService:BindToRenderStep(%s, %s, function())", aH(am), aZ(cp)))\n        end,\n        Heartbeat = bj("RunService.Heartbeat", false),\n        HeartbeatWait = function() return 0.016 end,\n        IsClient = function() return true end,\n        IsRunning = function() return true end,\n        IsServer = function() return false end,\n        IsStudio = function() return false end,\n        RenderStepped = bj("RunService.RenderStepped", false),\n        RenderSteppedWait = function() return 0.016 end,\n        Stepped = bj("RunService.Stepped", false),\n        SteppedWait = function() return 0.016 end,\n        UnbindFromRenderStep = function(am)\n             at(string.format("RunService:UnbindFromRenderStep(%s)", aH(am)))\n        end\n    },\n    UserInputService = {\n        GamepadEnabled = function() return false end,\n        GetGamepadState = function() return {} end,\n        GetKeysPressed = function() return {} end,\n        GetMouseLocation = function() return Vector2.new(0, 0) end,\n        InputBegan = bj("UserInputService.InputBegan", false),\n        InputChanged = bj("UserInputService.InputChanged", false),\n        InputEnded = bj("UserInputService.InputEnded", false),\n        IsKeyDown = function() return false end,\n        IsMouseButtonPressed = function() return false end,\n        KeyboardEnabled = function() return true end,\n        MouseEnabled = function() return true end,\n        MouseMoved = bj("UserInputService.MouseMoved", false),\n        MouseWheel = bj("UserInputService.MouseWheel", false),\n        TouchEnabled = function() return false end,\n        TouchEnded = bj("UserInputService.TouchEnded", false),\n        TouchMoved = bj("UserInputService.TouchMoved", false),\n        TouchStarted = bj("UserInputService.TouchStarted", false)\n    },\n    setrenderproperty = function(obj, prop, val)\n        at(string.format("setrenderproperty(%s, %s, %s)", aZ(obj), aH(prop), aZ(val)))\n        t.shadow_props[obj] = t.shadow_props[obj] or {}\n        t.shadow_props[obj][prop] = val\n    end,\n    setscriptable = function(obj, prop, val)\n        at(string.format("setscriptable(%s, %s, %s)", aZ(obj), aH(prop), aZ(val)))\n        exploit_funcs.setrenderproperty(obj, prop, val)\n    end,\n    RemoteEvent = {\n        new = function() return bj("RemoteEvent", false) end\n    },\n    RemoteFunction = {\n        new = function() return bj("RemoteFunction", false) end\n    },\n    Event = function() return bj("BindableEvent", false) end,\n    secure_call = function(dr, ...)\n        return dr(...)\n    end,\n    create_secure_function = function(dr)\n        return dr\n    end,\n    getmenv = function(script)\n        return _G\n    end,\n    replaceclosure = function(original, replacement)\n        at(string.format("replaceclosure(%s, %s)", aZ(original), aZ(replacement)))\n        return original\n    end,\n    dumpstring = function(str)\n        at(string.format("dumpstring(%s)", aZ(str)))\n        return str\n    end\n}\nfor b4, b5 in D(exploit_funcs) do\n    _G[b4] = b5\n    if type(b5) == "function" then LUNR_PROTECTED[b5] = true end\nend\n_G.getgc = exploit_funcs.getgc\n_G.getreg = function() return {} end\n_G.setscriptable = exploit_funcs.setscriptable\n_G.getrenderproperty = exploit_funcs.getrenderproperty\n_G.delfolder = exploit_funcs.delfolder\n_G.delfile = exploit_funcs.delfile\n_G.getexecutorname = exploit_funcs.getexecutorname\n-- Exploit functions preserved in _G\nlocal ed = {}\nlocal function ee(d_)\n    d_ = (d_ or 0) % 4294967296\n    if d_ >= 2147483648 then\n        d_ = d_ - 4294967296\n    end\n    return math.floor(d_)\nend\ned.tobit = ee\ned.tohex = function(d_, U)\n    return string.format("%0" .. (U or 8) .. "x", (d_ or 0) % 0x100000000)\nend\ned.band = function(bo, aa) return ee(ee(bo) & ee(aa)) end\ned.bor = function(bo, aa) return ee(ee(bo) | ee(aa)) end\ned.bxor = function(bo, aa) return ee(ee(bo) ~ ee(aa)) end\ned.bnot = function(bo) return ee(~ee(bo)) end\ned.btest = function(bo, aa) return (ee(bo) & ee(aa)) ~= 0 end\ned.lshift = function(d_, U) return ee(ee(d_) << (U or 0) % 32) end\ned.rshift = function(d_, U) return ee(ee(d_) >> (U or 0) % 32) end\ned.arshift = function(d_, U)\n    local b5 = ee(d_ or 0)\n    local amt = (U or 0) % 32\n    if b5 < 0 then\n        return ee(b5 >> amt) + ee(-1 << (32 - amt))\n    else\n        return ee(b5 >> amt)\n    end\nend\ned.rol = function(d_, U)\n    d_ = d_ or 0\n    U = (U or 0) % 32\n    return ee(d_ << U | (d_ >> (32 - U)))\nend\ned.ror = function(d_, U)\n    d_ = d_ or 0\n    U = (U or 0) % 32\n    return ee(d_ >> U | (d_ << (32 - U)))\nend\ned.bswap = function(d_)\n    d_ = d_ or 0\n    local bo = d_ >> 24 & 0xFF\n    local aa = d_ >> 8 & 0xFF00\n    local ah = d_ << 8 & 0xFF0000\n    local ef = d_ << 24 & 0xFF000000\n    return ee(bo | aa | ah | ef)\nend\ned.countlz = function(U)\n    U = ed.tobit(U)\n    if U == 0 then\n        return 32\n    end\n    local a2 = 0\n    if ed.band(U, 0xFFFF0000) == 0 then\n        a2 = a2 + 16\n        U = ed.lshift(U, 16)\n    end\n    if ed.band(U, 0xFF000000) == 0 then\n        a2 = a2 + 8\n        U = ed.lshift(U, 8)\n    end\n    if ed.band(U, 0xF0000000) == 0 then\n        a2 = a2 + 4\n        U = ed.lshift(U, 4)\n    end\n    if ed.band(U, 0xC0000000) == 0 then\n        a2 = a2 + 2\n        U = ed.lshift(U, 2)\n    end\n    if ed.band(U, 0x80000000) == 0 then\n        a2 = a2 + 1\n    end\n    return a2\nend\ned.countrz = function(U)\n    U = ed.tobit(U)\n    if U == 0 then\n        return 32\n    end\n    local a2 = 0\n    while ed.band(U, 1) == 0 do\n        U = ed.rshift(U, 1)\n        a2 = a2 + 1\n    end\n    return a2\nend\ned.lrotate = ed.rol\ned.rrotate = ed.ror\ned.extract = function(U, eg, eh)\n    eh = eh or 1\n    return U >> eg & 1 << eh - 1\nend\ned.replace = function(U, b5, eg, eh)\n    eh = eh or 1\n    local ei = 1 << eh - 1\n    return U & ~(ei << eg) | (b5 & ei << eg)\nend\ned.btest = function(bo, aa)\n    return ed.band(bo, aa) ~= 0\nend\nbit32 = ed\nbit = ed\ntable.getn = table.getn or function(b2)\n        return #b2\n    end\ntable.foreach = table.foreach or function(b2, as)\n        for b4, b5 in pairs(b2) do\n            as(b4, b5)\n        end\n    end\ntable.foreachi = table.foreachi or function(b2, as)\n        for L, b5 in ipairs(b2) do\n            as(L, b5)\n        end\n    end\ntable.move = table.move or function(ej, as, ds, b2, ek)\n        ek = ek or ej\n        for L = as, ds do\n            ek[b2 + L - as] = ej[L]\n        end\n        return ek\n    end\nstring.split = string.split or function(S, el)\n        local b2 = {}\n        for O in string.gmatch(S, "([^" .. (el or "%s") .. "]+)") do\n            table.insert(b2, O)\n        end\n        return b2\n    end\nif not math.frexp then\n    math.frexp = function(d_)\n        if d_ == 0 then\n            return 0, 0\n        end\n        local ds = math.floor(math.log(math.abs(d_)) / math.log(2)) + 1\n        local em = d_ / 2 ^ ds\n        return em, ds\n    end\nend\nif not math.ldexp then\n    math.ldexp = function(em, ds)\n        return em * 2 ^ ds\n    end\nend\nif not utf8 then\n    utf8 = {}\n    utf8.char = function(...)\n        local bA = {...}\n        local dg = {}\n        for L, al in ipairs(bA) do\n            table.insert(dg, string.char(al % 256))\n        end\n        return table.concat(dg)\n    end\n    utf8.len = function(S)\n        return #S\n    end\n    utf8.codes = function(S)\n        local L = 0\n        return function()\n            L = L + 1\n            if L <= #S then\n                return L, string.byte(S, L)\n            end\n        end\n    end\nend\npairs = function(b2)\n    if j(b2) == "table" and not G(b2) then\n        return D(b2)\n    end\n    return function()\n        return nil\n    end, b2, nil\nend\nipairs = function(b2)\n    if j(b2) == "table" and not G(b2) then\n        return E(b2)\n    end\n    return function()\n        return nil\n    end, b2, 0\nend\n_G.table = table\n_G.getconstant = exploit_funcs.debug.getconstant\n_G.setconstant = exploit_funcs.debug.setconstant\n_G.getupvalue = exploit_funcs.debug.getupvalue\n_G.getproto = exploit_funcs.debug.getproto\n_G.getprotos = exploit_funcs.debug.getprotos\n_G.setproto = exploit_funcs.debug.setproto\n_G.getstack = exploit_funcs.debug.getstack\n_G.setstack = exploit_funcs.debug.setstack\n    local en = {g(as, ...)}\n    local eo = en[1]\n    if not eo then\n        local an = en[2]\n       -- if j(an) == "string" and an:match("TIMEOUT_FORCED_BY_DUMPER") then\n       --     i(an)\n       -- end\n    end\n    return table.unpack(en)\nend\n    local function eq(an)\n      --  if j(an) == "string" and an:match("TIMEOUT_FORCED_BY_DUMPER") then\n      --      return an\n      --  end\n        if ep then\n            return ep(an)\n        end\n        return an\n    end\n    local en = {h(as, eq, ...)}\n    local eo = en[1]\n    if not eo then\n        local an = en[2]\n       -- if j(an) == "string" and an:match("TIMEOUT_FORCED_BY_DUMPER") then\n        --    i(an)\n      --  end\n    end\n    return table.unpack(en)\nend\nif _G.originalError == nil then\nend\n        return #b2\n    end\n_G.unpack = table.unpack or unpack\n_G.pack = table.pack or function(...)\n        return {n = select("#", ...), ...}\n    end\n_G.Region3int16 = Region3int16\n_G.NumberSequenceKeypoint = NumberSequenceKeypoint\n_G.ColorSequenceKeypoint = ColorSequenceKeypoint\n    create = function(size) return {data = string.rep("\0", size or 0), length = size or 0} end,\n    fromstring = function(str) return {data = str or "", length = #(str or "")} end,\n    tostring = function(buf) return buf and buf.data or "" end,\n    len = function(buf) return buf and buf.length or 0 end,\n    readi8 = function(buf, pos) \n        if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n        return buf.data and string.byte(buf.data, pos + 1) or 0 \n    end,\n    writei8 = function(buf, pos, val)\n        if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n    end,\n    readu8 = function(buf, pos) if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end return 0 end,\n    writeu8 = function(buf, pos, val) if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end end,\n    readi16 = function(buf, pos) return 0 end,\n    writei16 = function(buf, pos, val) end,\n    readu16 = function(buf, pos) return 0 end,\n    writeu16 = function(buf, pos, val) end,\n    readi32 = function(buf, pos) return 0 end,\n    writei32 = function(buf, pos, val) end,\n    readu32 = function(buf, pos) return 0 end,\n    writeu32 = function(buf, pos, val) end,\n    readf32 = function(buf, pos) return 0 end,\n    writef32 = function(buf, pos, val) end,\n    readf64 = function(buf, pos) return 0 end,\n    writef64 = function(buf, pos, val) end,\n    readstring = function(buf, pos, len) return "" end,\n    writestring = function(buf, pos, str) end,\n    copy = function(dst, dstoff, src, srcoff, count) end,\n    fill = function(buf, pos, val, count) end,\n}\n_G.PathWaypoint = PathWaypoint\n_G.Axes = Axes\n_G.Faces = Faces\n_G.Vector3int16 = Vector3int16\n_G.Vector2int16 = Vector2int16\n_G.CatalogSearchParams = CatalogSearchParams\n_G.DateTime = DateTime\ngetmetatable = function(x)\n    if G(x) then\n        return "The metatable is locked"\n    end\n    return k(x)\nend\ntype = function(x)\n    return j(x)\nend\ntypeof = function(x)\n    if G(x) then\n        local er = t.registry[x]\n        if er then\n            if er:match("Vector3") then\n                return "Vector3"\n            end\n            if er:match("CFrame") then\n                return "CFrame"\n            end\n            if er:match("Color3") then\n                return "Color3"\n            end\n            if er:match("UDim") then\n                return "UDim2"\n            end\n            if er:match("Enum") then\n                return "EnumItem"\n            end\n        end\n        return "Instance"\n    end\n    return j(x)\nend\ntonumber = function(x, es)\n    if w(x) then\n        return 123456789\n    end\n    return n(x, es)\nend\nrawequal = function(bo, aa)\n    return l(bo, aa)\nend\ntostring = function(x)\n    if G(x) then\n        local et = t.registry[x]\n        return et or "Instance"\n    end\n    return m(x)\nend\nt.last_http_url = nil\nloadstring = function(al, eu)\n    if j(al) ~= "string" then\n        return function()\n            return bj("loaded", false)\n        end\n    end\n    local cI = t.last_http_url or al\n    t.last_http_url = nil\n    local ev = nil\n    local ew = cI:lower()\n    local ex = {\n        {pattern = "rayfield",    name = "Rayfield"},\n        {pattern = "windui",      name = "WindUI"},\n        {pattern = "fluent",      name = "Fluent"},\n        {pattern = "tora-library", name = "Tora_Library"},\n        {pattern = "orion",       name = "OrionLib"},\n        {pattern = "kavo",        name = "Kavo"},\n        {pattern = "venyx",       name = "Venyx"},\n        {pattern = "sirius",      name = "Sirius"},\n        {pattern = "linoria",     name = "Linoria"},\n        {pattern = "wally",       name = "Wally"},\n        {pattern = "dex",         name = "Dex"},\n        {pattern = "infinite",    name = "InfiniteYield"},\n        {pattern = "hydroxide",   name = "Hydroxide"},\n        {pattern = "simplespy",   name = "SimpleSpy"},\n        {pattern = "remotespy",   name = "RemoteSpy"},\n    }\n    for W, ey in ipairs(ex) do\n        if ew:find(ey.pattern) then\n            ev = ey.name\n            break\n        end\n    end\n    if ev then\n        local ez = bj(ev, false)\n        t.registry[ez] = ev\n        t.names_used[ev] = true\n        if cI:match("^https?://") then\n            at(string.format('local %s = loadstring(game:HttpGet("%s"))()', ev, cI))\n        end\n        return function()\n            return ez\n        end\n    end\n    if cI:match("^https?://") then\n        local ez = bj("Library", false)\n        at(string.format('local Library = loadstring(game:HttpGet("%s"))()', cI))\n        return function()\n            return ez\n        end\n    end\n    if type(al) == "string" then\n        al = I(al)\n    end\n    local R, an = e(al)\n    if R then\n        return R\n    end\n    local ez = bj("LoadedChunk", false)\n    return function()\n        return ez\n    end\nend\nload = loadstring\nrequire = function(eA)\n    -- SECURITY: Validate module names and block dangerous patterns\n    if type(eA) ~= "string" then\n        error("require() expects a string argument")\n    end\n    \n    -- Block @lune and other dangerous patterns\n    if eA:match("^@lune") or eA:match("^@std") or eA:match("^@lune") then\n        at(string.format("[SECURITY] Blocked dangerous module: %s", aZ(eA)))\n        error("[SECURITY] Dangerous module loading blocked")\n    end\n    \n    -- Additional security checks\n    if eA:match("%.%.%.") or eA:match("%.%.%.%.") then\n        at(string.format("[SECURITY] Suspicious module path: %s", aZ(eA)))\n        error("[SECURITY] Suspicious module path blocked")\n    end\n    \n    local eB = t.registry[eA] or aZ(eA)\n    local z = bj("RequiredModule", false)\n    local _ = aW(z, "module")\n    at(string.format("local %s = require(%s)", _, aZ(eB)))\n    return z\nend\nprint = function(...)\n    local bA = {...}\n    local b8 = {}\n    for W, b5 in ipairs(bA) do\n        table.insert(b8, aZ(b5))\n    end\n    local msg = table.concat(bA, "\t")\n    for _, cb in ipairs(_G.__logservice_callbacks or {}) do\n        pcall(cb, msg, (Enum and Enum.MessageType and Enum.MessageType.MessageOutput) or "Output")\n    end\n    at(string.format("print(%s)", table.concat(b8, ", ")))\nend\nwarn = function(...)\n    local bA = {...}\n    local b8 = {}\n    for W, b5 in ipairs(bA) do\n        table.insert(b8, aZ(b5))\n    end\n    at(string.format("warn(%s)", table.concat(b8, ", ")))\nend\nshared = bj("shared", true)\nlocal eC = _G\nlocal eD =\n    setmetatable(\n    {},\n    {__index = function(b2, b4)\n            local aF = rawget(eC, b4)\n            if aF == nil then\n                aF = rawget(_G, b4)\n            end\n            return aF\n        end, __newindex = function(b2, b4, b5)\n            rawset(eC, b4, b5)\n        end}\n)\n_G._G = eD\nfunction q.reset()\n    t = {\n        output = {},\n        indent = 0,\n        registry = {},\n        reverse_registry = {},\n        names_used = {},\n        parent_map = {},\n        property_store = {},\n        call_graph = {},\n        variable_types = {},\n        string_refs = {},\n        proxy_id = 0,\n        callback_depth = 0,\n        pending_iterator = false,\n        last_http_url = nil,\n        current_size = 0,\n        limit_reached = false,\n        var_counter = 0,\n        captured_constants = {},\n        cycle_history = {},\n        in_cycle = false,\n        cycle_count = 0,\n        wait_calls = 0,\n        library_counter = 0,\n        variable_counter = 0\n    }\n    aM = {}\n    game = bj("game", true)\n    workspace = bj("workspace", true)\n    script = bj("script", true)\n    Enum = bj("Enum", true)\n    shared = bj("shared", true)\n    t.property_store[game] = {PlaceId = u, GameId = u, placeId = u, gameId = u}\n    local dm = {}\n    dm.__index = function(b2, b4)\n        if b4 == F or b4 == "__proxy_id" then\n            return rawget(b2, b4)\n        end\n        local dn = bj("Enum." .. aE(b4), false)\n        t.registry[dn] = "Enum." .. aE(b4)\n        return dn\n    end\n    setmetatable(Enum, dm)\nend\nfunction q.get_output()\n    return aB()\nend\nfunction q.save(aD)\n    return aC(aD)\nend\nfunction q.get_call_graph()\n    return t.call_graph\nend\nfunction q.get_string_refs()\n    return t.string_refs\nend\nfunction q.get_stats()\n    return {\n        total_lines = #t.output,\n        remote_calls = #t.call_graph,\n        suspicious_strings = #t.string_refs,\n        proxies_created = t.proxy_id\n    }\nend\nlocal eE = {\n    callId = "LUNR_",\n    binaryOperatorNames = {\n        ["and"] = "AND",\n        ["or"] = "OR",\n        [">"] = "GT",\n        ["<"] = "LT",\n        [">="] = "GE",\n        ["<="] = "LE",\n        ["=="] = "EQ",\n        ["~="] = "NEQ",\n        [".."] = "CAT"\n    }\n}\nfunction eE:hook(al)\n    return self.callId .. al\nend\nfunction eE:process_expr(eF)\n    if not eF then\n        return "nil"\n    end\n    if type(eF) == "string" then\n        return eF\n    end\n    local eG = eF.tag or eF.kind\n    if eG == "number" or eG == "string" then\n        local aF = eG == "string" and string.format("%q", eF.text) or (eF.value or eF.text)\n        if r.CONSTANT_COLLECTION then\n            return string.format("%sGET(%s)", self.callId, aF)\n        end\n        return aF\n    end\n    if eG == "local" or eG == "global" then\n        return (eF.name or eF.token).text\n    elseif eG == "boolean" or eG == "bool" then\n        return tostring(eF.value)\n    elseif eG == "binary" then\n        local eH = self:process_expr(eF.lhsoperand)\n        local eI = self:process_expr(eF.rhsoperand)\n        local X = eF.operator.text\n        local eJ = self.binaryOperatorNames[X]\n        if eJ then\n            return string.format("%s%s(%s, %s)", self.callId, eJ, eH, eI)\n        end\n        return string.format("(%s %s %s)", eH, X, eI)\n    elseif eG == "call" then\n        local dr = self:process_expr(eF.func)\n        local bA = {}\n        for L, b5 in ipairs(eF.arguments) do\n            bA[L] = self:process_expr(b5.node or b5)\n        end\n        return string.format("%sCALL(%s, %s)", self.callId, dr, table.concat(bA, ", "))\n    elseif eG == "indexname" or eG == "index" then\n        local bS = self:process_expr(eF.expression)\n        local ba = eG == "indexname" and string.format("%q", eF.index.text) or self:process_expr(eF.index)\n        return string.format("%sCHECKINDEX(%s, %s)", self.callId, bS, ba)\n    end\n    return "nil"\nend\nfunction eE:process_statement(eF)\n    if not eF then\n        return ""\n    end\n    local eG = eF.tag\n    if eG == "local" or eG == "assign" then\n        local eK, eL = {}, {}\n        for W, b5 in ipairs(eF.variables or {}) do\n            table.insert(eK, self:process_expr(b5.node or b5))\n        end\n        for W, b5 in ipairs(eF.values or {}) do\n            table.insert(eL, self:process_expr(b5.node or b5))\n        end\n        return (eG == "local" and "local " or "") .. table.concat(eK, ", ") .. " = " .. table.concat(eL, ", ")\n    elseif eG == "block" then\n        local b9 = {}\n        for W, eM in ipairs(eF.statements or {}) do\n            table.insert(b9, self:process_statement(eM))\n        end\n        return table.concat(b9, "; ")\n    end\n    return self:process_expr(eF) or ""\nend\nlocal function create_env(R)\n    local eR\n    -- Tree-structured VFS to support nesting and proper path handling\nlocal VFS = { root = { type = "folder", children = {} } }\n\nlocal function resolve_path(path)\n    if not path or path == "" then return VFS.root end\n    local parts = {}\n    for part in path:gmatch("[^/]+") do\n        if part == ".." then\n            table.remove(parts)\n        elseif part ~= "." then\n            table.insert(parts, part)\n        end\n    end\n    local node = VFS.root\n    for _, part in ipairs(parts) do\n        if node.type ~= "folder" then return nil, "Not a folder" end\n        node = node.children[part]\n        if not node then return nil, "Path not found" end\n    end\n    return node\nend\n\nlocal function create_path(path, is_folder)\n    if not path or path == "" then return false, "Invalid path" end\n    local parts = {}\n    for part in path:gmatch("[^/]+") do\n        if part == ".." then\n            table.remove(parts)\n        elseif part ~= "." then\n            table.insert(parts, part)\n        end\n    end\n    local node = VFS.root\n    for i, part in ipairs(parts) do\n        if not node.children[part] then\n            node.children[part] = {\n                type = is_folder and "folder" or "file",\n                children = is_folder and {} or nil,\n                content = not is_folder and "" or nil\n            }\n        end\n        node = node.children[part]\n        if i < #parts and node.type ~= "folder" then return false, "Path conflict" end\n    end\n    return true\nend\n\nlocal function get_parent_path(path)\n    return path:match("(.+)/[^/]+$") or "/"\nend\n\nlocal function get_name_from_path(path)\n    return path:match("[^/]+$") or path\nend\n    local drawing_objects = {}\n    local closure_tags = setmetatable({}, { __mode = "k" })\n    local readonly = setmetatable({}, { __mode = "k" })\n    local script_sources = setmetatable({}, { __mode = "k" })\n    local scripts = { script }\n    local shadow_props = setmetatable({}, { __mode = "k" })\n    local raw_setmetatable = setmetatable\n    local _loadstring = loadstring\n    local _debug = debug\n\n    eR = setmetatable({\n        LuraphContinue = function() end,\n        script = script, game = game, workspace = workspace,\n        t = task,\n        LUNR_CHECKINDEX = function(x, ba)\n            local aF = x[ba]\n            if j(aF) == "table" and not t.registry[aF] then\n                t.var_counter = t.var_counter + 1\n                t.registry[aF] = "lunrtab" .. t.var_counter\n            end\n            return aF\n        end,\n        LUNR_GET = function(b5) return b5 end,\n        LUNR_CALL = function(as, ...) return as(...) end,\n        LUNR_NAMECALL = function(eS, em, ...) return eS[em](eS, ...) end,\n        pcall = function(as, ...)\n            local dg = {g(as, ...)}\n            if not dg[1] and (m(dg[2]):match("TIMEOUT") or m(dg[2]):match("LIMIT") or m(dg[2]):match("DUMPER")) then\n                i(dg[2], 0)\n            end\n            return table.unpack(dg)\n        end,\n        xpcall = function(as, dt, ...)\n            local dg = {h(as, dt, ...)}\n            if not dg[1] and (m(dg[2]):match("TIMEOUT") or m(dg[2]):match("LIMIT") or m(dg[2]):match("DUMPER")) then\n                i(dg[2], 0)\n            end\n            return table.unpack(dg)\n        end,\n        LUNR_STR = function(val)\n            if type(val) == "string" and #val > 2 then\n                table.insert(t.string_refs, {value = val, hint = "Deobfuscated String"})\n            end\n            return val\n        end,\n        getgenv = function() return dz(nil) end,\n        getfenv = function(f)\n            if f == nil or (type(f) == "number" and (f == 0 or f == 1)) then\n                return _G\n            end\n            local env_proxy = {}\n            local context = ""\n            if f == R then \n                context = "getfenv(script)"\n            else\n                context = "getfenv(" .. aE(f) .. ")"\n            end\n            \n            setmetatable(env_proxy, {\n                __index = function(t, k)\n                    return eR[k]\n                end,\n                __newindex = function(t, k, v)\n                    at(string.format(context .. ".%s = %s", aE(k), aZ(v)))\n                    -- Store in original_G and use rawset to avoid double logging\n                    if original_G then\n                        original_G[k] = v\n                    end\n                    rawset(eR, k, v)\n                end,\n                __call = function(t, ...)\n                    return t\n                end,\n                __tostring = function(t)\n                    return context\n                end\n            })\n            return env_proxy\n        end,\n        setfenv = function(f, env)\n            if type(f) == "number" and (f == 0 or f == 1) then return eR end\n            if f == R then return eR end\n            pcall(setfenv, f, env)\n            return eR\n        end,\n        _G = dy(), -- set to logging proxy\n        shared = {},\n        _VERSION = _VERSION,\n        bit = ed, bit32 = ed,\n        getrenv = function() return _G end,\n        getreg = _G.getreg or function() return {} end,\n        getgc = _G.getgc or function() return {} end,\n        getinstances = _G.getinstances or function() return {} end,\n        getnilinstances = _G.getnilinstances or function() return {} end,\n        getscripts = function() return scripts end,\n        getrunningscripts = function() return scripts end,\n        getrawmetatable = function(t) return getmetatable(t) end,\n        setrawmetatable = function(t, mt)\n            if readonly[t] then return end\n            return raw_setmetatable(t, mt)\n        end,\n        setreadonly = function(t, v) readonly[t] = v end,\n        isreadonly = function(t) return readonly[t] == true end,\n        hookfunction = function(f, h) return f end,\n        hookmetamethod = function(t, m, h) return function(...) end end,\n        newcclosure = function(fn)\n            local wrapper = function(...) return fn(...) end\n            closure_tags[wrapper] = "c"\n            return wrapper\n        end,\n        iscclosure = function(f) return closure_tags[f] == "c" end,\n        islclosure = function(f) return closure_tags[f] ~= "c" end,\n        isexecutorclosure = function(f) return true end,\n        checkcaller = function() return true end, -- Mimic exploit context\n        identifyexecutor = function() return "Lunr", "1.0" end,\n        getexecutorname = function() return "Lunr" end,\n        request = function(opt) \n            local url = opt.Url or opt.url or "unknown"\n            -- Block IP information requests to protect privacy\n            if url:match("ipinfo%.io") or url:match("ipapi%.co") or url:match("api%.ipify%.org") then\n                at("-- [BLOCKED] IP information request detected and blocked for privacy protection: " .. url)\n                return {Success = false, StatusCode = 403, StatusMessage = "Forbidden", Body = '{"error": "IP information requests blocked for privacy"}'}\n            end\n            return {Success = true, StatusCode = 200, Body = ""} \n        end,\n                loadstring = function(al, eu)\n            -- SECURITY: Block dangerous module loading patterns\n            if j(al) == "string" then\n                -- Check for @lune and other dangerous patterns\n                if al:match("require%s*%(%s*@lune") or al:match("require%s*%(%s*@") or al:match("require%s*%(%s*%.%.%.%s*)") then\n                    at("[SECURITY] Blocked potentially dangerous require pattern: " .. al:sub(1, 50) .. "...")\n                    return function() error("[SECURITY] Dangerous module loading blocked") end\n                end\n            end\n            local cI = t.last_http_url or (type(al) == "string" and al or "")\n            local saved_url = cI\n            t.last_http_url = nil\n            local ev = nil\n            local ew = (type(cI) == "string" and cI:lower()) or ""\n            local ex = {\n                {pattern = "rayfield",    name = "Rayfield"},\n                {pattern = "windui",      name = "WindUI"},\n                {pattern = "fluent",      name = "Fluent"},\n                {pattern = "tora-library", name = "Tora_Library"},\n                {pattern = "orion",       name = "OrionLib"},\n                {pattern = "kavo",        name = "Kavo"},\n                {pattern = "venyx",       name = "Venyx"},\n                {pattern = "sirius",      name = "Sirius"},\n                {pattern = "linoria",     name = "Linoria"},\n                {pattern = "wally",       name = "Wally"},\n                {pattern = "dex",         name = "Dex"},\n                {pattern = "infinite",    name = "InfiniteYield"},\n                {pattern = "hydroxide",   name = "Hydroxide"},\n                {pattern = "simplespy",   name = "SimpleSpy"},\n                {pattern = "remotespy",   name = "RemoteSpy"},\n            }\n            for W, ey in ipairs(ex) do\n                if ew:find(ey.pattern) then\n                    ev = ey.name\n                    break\n                end\n            end\n            local function make_ui_library_stub(prefix)\n                local ui_methods = {\n                    "CreateWindow", "Create", "CreateTab", "AddTab", "NewTab",\n                    "CreateSection", "AddSection", "NewSection",\n                    "CreateLabel", "AddLabel", "CreateButton", "AddButton",\n                    "CreateToggle", "AddToggle", "CreateSlider", "AddSlider",\n                    "CreateDropdown", "AddDropdown", "CreateKeybind", "AddKeybind",\n                    "CreateColorPicker", "AddColorPicker", "CreateInput", "AddInput",\n                    "CreateParagraph", "AddParagraph", "CreateTextBox", "CreateBind",\n                    "AddLeftGroup", "AddRightGroup", "AddLeftTab", "AddRightTab",\n                    "Notify", "Prompt", "Destroy", "GetConfig", "SetConfig"\n                }\n                local stub = {}\n                local function log_and_chain(method_name, ...)\n                    local args = {...}\n                    local parts = {}\n                    for i = 1, #args do\n                        local ok, s = pcall(function() return aZ(args[i]) end)\n                        table.insert(parts, ok and s or tostring(args[i]))\n                    end\n                    at(prefix .. ":" .. method_name .. "(" .. table.concat(parts, ", ") .. ")")\n                    return make_ui_library_stub(prefix .. ":" .. method_name .. "(...)")\n                end\n                for _, method in ipairs(ui_methods) do\n                    stub[method] = function(self, ...) return log_and_chain(method, ...) end\n                end\n                setmetatable(stub, {\n                    __index = function(t, k)\n                        if type(k) == "string" and k:match("^[A-Za-z][%w]*") then\n                            return function(self, ...) return log_and_chain(k, ...) end\n                        end\n                        return nil\n                    end\n                })\n                return stub\n            end\n            if ev then\n                local ez = bj(ev, false)\n                t.registry[ez] = ev\n                t.names_used[ev] = true\n                if type(cI) == "string" and cI:match("^https?://") then\n                    at(string.format('local %s = loadstring(game:HttpGet("%s"))()', ev, cI))\n                end\n                return function()\n                    return make_ui_library_stub(ev)\n                end\n            end\n            if type(cI) == "string" and cI:match("^https?://") then\n                local ez = bj("Library", false)\n                at(string.format('local Library = loadstring(game:HttpGet("%s"))()', cI))\n                return function()\n                    return make_ui_library_stub("Library")\n                end\n            end\n            if type(al) == "string" and (al:match("return%s*%{%s*CreateWindow") or al:match("return%s*%{%s*Create%s*=")) then\n                return function()\n                    return make_ui_library_stub(saved_url and (ew:find("tora") and "Tora_Library" or ew:find("rayfield") and "Rayfield" or ew:find("flux") and "Fluent" or "Library") or "Library")\n                end\n            end\n            if type(al) == "string" then\n                al = I(al)\n            end\n            local R, an = e(al)\n            if R then\n                return R\n            end\n            local ez = bj("LoadedChunk", false)\n            return function()\n                return ez\n            end\n        end,\n        load = function(src, chunk)\n            if type(src) ~= "string" then return nil, "invalid argument" end\n            local fn, err = _loadstring(src, chunk)\n            if not fn then return nil, err end\n            setfenv(fn, eR)\n            script_sources[fn] = src\n            return fn\n        end,\n        check_loop_limit = check_loop_limit,\n        enter_loop = enter_loop,\n        exit_loop = exit_loop,\n        debug = {\n            getinfo = function(f, w)\n                -- Anti-tamper bypass: if this looks like a tamper check, return original\n                if type(f) == "function" then\n                    local info = _original_debug_getinfo and _original_debug_getinfo(f, w)\n                    if info and (info.source:match("Phantoraph") or info.source:match("Antitamper")) then\n                        return info\n                    end\n                end\n                \n                if type(f) == "number" then f = f + 1 end\n                local info = _debug.getinfo(f, w)\n                if info then\n                    if info.source == "=[C]" then info.what = "C" end\n                    if info.source:match("Obfuscated_Script") then info.source = "=Script" end\n                end\n                return info\n            end,\n            getupvalue = _debug.getupvalue,\n            setupvalue = _debug.setupvalue,\n            getupvalues = _debug.getupvalues or function(f)\n                local i, u = 1, {}\n                while true do\n                    local n, v = _debug.getupvalue(f, i)\n                    if not n then break end\n                    u[n] = v\n                    i = i + 1\n                end\n                return u\n            end,\n            getconstants = function() return {} end,\n            getconstant = function() return nil end,\n            setconstant = function() end,\n            getprotos = function() return {} end,\n            getproto = function() return nil end,\n            setproto = function() end,\n            getstack = function() return {} end,\n            setstack = function() end,\n            getregistry = _debug.getregistry or function() return {} end\n        },\n        Drawing = {\n            Fonts = { UI = 0, System = 1, Plex = 2, Monospace = 3 },\n            new = function(class)\n                local obj = {\n                    ClassName = class,\n                    Visible = true,\n                    Color = Color3.new(1,1,1),\n                    Size = Vector2.new(0,0),\n                    Position = Vector2.new(0,0),\n                    Thickness = 1,\n                    Transparency = 0,\n                    Remove = function(self) drawing_objects[self] = nil end,\n                    Clear = function(self) end\n                }\n                drawing_objects[obj] = true\n                return obj\n            end\n        },\n        table = {\n            insert = table.insert,\n            remove = table.remove,\n            move   = table.move,\n            concat = table.concat,\n            pack   = table.pack,\n            unpack = table.unpack,\n            sort   = table.sort,\n            clear  = table.clear or function(t) for k in next,t do t[k]=nil end end,\n            clone = function(t, deep)\n                if type(t) ~= "table" then\n                    error("table.clone only accepts tables", 2)\n                end\n    \n                -- Handle simple shallow copy\n                if not deep then\n                    local copy = {}\n                    for k, v in pairs(t) do\n                        copy[k] = v\n                    end\n                    -- Output the actual table content\n                    local tableStr = "{"\n                    local first = true\n                    for k, v in pairs(t) do\n                        if not first then\n                            tableStr = tableStr .. ", "\n                        end\n                        tableStr = tableStr .. tostring(k) .. " = " .. aZ(v)\n                        first = false\n                    end\n                    tableStr = tableStr .. "}"\n                    at(string.format("table.clone(%s, shallow)", tableStr))\n                    return copy\n                end\n    \n                -- Handle deep copy with cycle detection\n                local seen = {}\n    \n                local function deep_copy(obj, depth)\n                    if type(obj) ~= "table" then\n                        return obj\n                    end\n        \n                    -- Check for cycles\n                    if seen[obj] then\n                        return seen[obj]\n                    end\n        \n                    local copy = {}\n                    seen[obj] = copy\n        \n                    -- Set metatable if it exists\n                    local mt = getmetatable(obj)\n                    if mt then\n                        setmetatable(copy, mt)\n                    end\n        \n                    -- Copy all key-value pairs\n                    for k, v in pairs(obj) do\n                        -- Recursively copy keys and values (up to a reasonable depth)\n                        if depth < 10 then  -- Prevent stack overflow\n                            copy[deep_copy(k, depth + 1)] = deep_copy(v, depth + 1)\n                        else\n                            copy[k] = v  -- Stop deep copying at depth limit\n                        end\n                    end\n        \n                    return copy\n                end\n    \n                local result = deep_copy(t, 0)\n                at(string.format("-- table.clone(%s, deep)", aZ(t)))\n                return result\n            end,\n            freeze = function(t)\n                if type(t) ~= "table" then\n                    error("table.freeze only accepts tables", 2)\n                end\n    \n                -- Mark as frozen\n                t.readonly = t.readonly or {}\n                t.readonly[t] = true\n    \n                -- Make the table immutable\n                local mt = getmetatable(t) or {}\n                local original_newindex = mt.__newindex\n    \n                mt.__newindex = function(table, key, value)\n                    if t.readonly[t] then\n                        error("Cannot modify a frozen table", 2)\n                    end\n        \n                    if original_newindex then\n                        original_newindex(table, key, value)\n                    else\n                        rawset(table, key, value)\n                    end\n                end\n    \n                mt.__index = mt.__index or function(table, key)\n                    return rawget(table, key)\n                end\n    \n                setmetatable(t, mt)\n    \n                at(string.format("-- table.freeze(%s)", aZ(t)))\n                return t\n            end,\n            isfrozen = function(t)\n                if type(t) ~= "table" then\n                    return false\n                end\n                return (t.readonly and t.readonly[t] == true) or false\n            end,\n        },\n        ColorSequence = {\n            new = function(...)\n                local args = {...}\n                if type(args[1]) == "table" then\n                    -- ColorSequence.new({[1]=ColorSequenceKeypoint.new(0, c1), [2]=ColorSequenceKeypoint.new(1, c2)})\n                    -- Convert to Color3 by taking the last keypoint's color\n                    -- Handle both array-like and key-value table structures\n                    local last = nil\n                    if #args[1] > 0 then\n                        -- Array-like table\n                        last = args[1][#args[1]]\n                    else\n                        -- Key-value table, find the one with highest time/key\n                        local max_key = -1\n                        for k, v in pairs(args[1]) do\n                            if type(k) == "number" and k > max_key then\n                                max_key = k\n                                last = v\n                            end\n                        end\n                    end\n                    \n                    if last and type(last) == "table" and last.Color then\n                        return last.Color\n                    else\n                        return Color3.new(1,1,1)\n                    end\n                elseif #args == 1 then\n                    -- ColorSequence.new(Color3)\n                    return args[1]\n                elseif #args == 2 then\n                    -- ColorSequence.new(c1, c2) -> return c2 (end color)\n                    return args[2]\n                else\n                    return Color3.new(1,1,1)\n                end\n            end\n        },\n        ColorSequenceKeypoint = {\n            new = function(time, color)\n                return {Time = time, Color = color}\n            end\n        },\n        cleardrawcache = function() \n            at("cleardrawcache()")\n            drawing_objects = {} \n        end,\n        readfile = function(p)\n            at(string.format("readfile(%s)", aH(p)))\n            local node = resolve_path(p)\n            return node and node.type == "file" and node.content or nil\n        end,\n        writefile = function(p, c)\n            at(string.format("writefile(%s, %s)", aH(p), aZ(c)))\n            if create_path(p, false) then\n                local node = resolve_path(p)\n                node.content = tostring(c)\n            end\n        end,\n        appendfile = function(p, c)\n            at(string.format("appendfile(%s, %s)", aH(p), aZ(c)))\n            local node = resolve_path(p)\n            if node and node.type == "file" then\n                node.content = (node.content or "") .. tostring(c)\n            end\n        end,\n        listfiles = function(p)\n            at(string.format("listfiles(%s)", aH(p or "")))\n            local node = resolve_path(p or "/")\n            if not node or node.type ~= "folder" then return {} end\n            local res = {}\n            for name, child in pairs(node.children) do\n                table.insert(res, (p and p ~= "/" and p:gsub("/$", "") .. "/" or "") .. name)\n            end\n            return res\n        end,\n        isfile = function(p)\n            at(string.format("isfile(%s)", aH(p)))\n            local node = resolve_path(p)\n            return node and node.type == "file" or false\n        end,\n        isfolder = function(p)\n            at(string.format("isfolder(%s)", aH(p)))\n            local node = resolve_path(p)\n            return node and node.type == "folder" or false\n        end,\n        makefolder = function(p)\n            at(string.format("makefolder(%s)", aH(p)))\n            create_path(p, true)\n        end,\n        delfile = function(p)\n            at(string.format("delfile(%s)", aH(p)))\n            local node = resolve_path(p)\n            if node and node.parent then\n                node.parent.children[node.name] = nil\n            end\n        end,\n        delfolder = function(p)\n            at(string.format("delfolder(%s)", aH(p)))\n            local node = resolve_path(p)\n            if node and node.parent then\n                node.parent.children[node.name] = nil\n            end\n        end,\n        getscripthash = function(scr)\n            local src = script_sources[scr] or ""\n            -- Return a GUID-like hash instead of simple length+byte\n            return string.format("%08x-%04x-%04x-%04x-%12x", \n                math.random(0, 0xffffffff), math.random(0, 0xffff),\n                math.random(0, 0xffff), math.random(0, 0xffff),\n                math.random(0, 0xffffffffffff))\n        end,\n        getscriptbytecode = function(scr) \n            -- Return fake binary bytecode\n            local len = math.random(50, 100)\n            local chars = {}\n            for i = 1, len do\n                chars[i] = string.char(math.random(0, 255))\n            end\n            return table.concat(chars)\n        end,\n        setrenderproperty = function(obj, prop, val)\n            shadow_props[obj] = shadow_props[obj] or {}\n            shadow_props[obj][prop] = val\n        end,\n        setscriptable = function(obj, prop, val)\n            shadow_props[obj] = shadow_props[obj] or {}\n            shadow_props[obj][prop] = val\n        end,\n        getnamecallmethod = function() return "GetChildren" end,\n        setnamecallmethod = function() end,\n        gethiddenproperty = function() return nil end,\n        sethiddenproperty = function() end,\n        fireclickdetector = function() end,\n        fireproximityprompt = function() end,\n        firetouchinterest = function() end,\n        isnetworkowner = function() return true end,\n        getcustomasset = function(p) return "rbxasset://" .. tostring(#p or 0) end,\n        getsenv = function(script)\n            local env_proxy = {}\n            setmetatable(env_proxy, {\n                __index = function(t, k)\n                    return eR[k]\n                end,\n                __newindex = function(t, k, v)\n                    at(string.format("getsenv().%s = %s", aE(k), aZ(v)))\n                    -- Store in original_G and use rawset to avoid double logging\n                    if original_G then\n                        original_G[k] = v\n                    end\n                    rawset(eR, k, v)\n                end,\n                __call = function(t, ...)\n                    return t\n                end,\n                __tostring = function(t)\n                    return "getsenv()"\n                end\n            })\n            return env_proxy\n        end,\n        cloneref = function(r) return r end\n    }, {__index = _G, __newindex = dy()})\n    eR._G = dy()\n    eR._G = dy() -- Use our logging proxy instead of eR\n    eR.table = eR.table or table\n    _G.table = eR.table\n    eR.Drawing = {\n        new = function(class)\n        local obj = {\n                ClassName = class, Visible = true, Color = Color3.new(1,1,1),\n                Thickness = 1, Filled = false, Center = false, Outline = false,\n                Position = Vector2.new(), Size = Vector2.new(), Radius = 0,\n                Text = "", Font = Enum.Font.Gotham, TextSize = 14,\n                Remove = function(self) drawing_objects[self] = nil end\n            }\n            drawing_objects[obj] = true\n            at(string.format("local %s = Drawing.new(%q)", aW(obj, class), class))\n            return obj\n        end\n    }\n    eR.mousemoverel = function(dx, dy)\n        at(string.format("mousemoverel(%s, %s)", dx or 0, dy or 0))\n    end\n    eR.mousemoveabs = function(x, y)\n        at(string.format("mousemoveabs(%s, %s)", x or 0, y or 0))\n    end\n    eR.setclipboard = function(txt)\n        at(string.format('setclipboard(%s)', aZ(txt)))\n    end\n    \n    -- ========================================\n    -- ENVIRONMENT ENHANCEMENTS\n    -- Add missing globals without breaking proxy logging\n    -- ========================================\n    \n    -- Add table.create if missing\n    if eR.table and not eR.table.create then\n        eR.table.create = function(size, value)\n            if size and size > 1e8 then\n                error("invalid argument #1 to 'create' (size out of range)")\n            end\n            local t = {}\n            if value ~= nil then\n                for i = 1, (size or 0) do t[i] = value end\n            end\n            return t\n        end\n    end\n    \n    -- Add buffer global\n    if not eR.buffer then\n        eR.buffer = {\n            create = function(size) return {data = string.rep("\0", size or 0), length = size or 0} end,\n            fromstring = function(str) return {data = str or "", length = #(str or "")} end,\n            tostring = function(buf) return buf and buf.data or "" end,\n            len = function(buf) return buf and buf.length or 0 end,\n            readi8 = function(buf, pos) \n                if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n                return buf.data and string.byte(buf.data, pos + 1) or 0 \n            end,\n            writei8 = function(buf, pos, val)\n                if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n                return true\n            end,\n            readu8 = function(buf, pos) \n                if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n                return 0 \n            end,\n            writeu8 = function(buf, pos, val)\n                if not buf or pos >= (buf.length or 0) then error("buffer access out of bounds") end\n            end,\n            readi16 = function(buf, pos) return 0 end,\n            writei16 = function(buf, pos, val) end,\n            readu16 = function(buf, pos) return 0 end,\n            writeu16 = function(buf, pos, val) end,\n            readi32 = function(buf, pos) return 0 end,\n            writei32 = function(buf, pos, val) end,\n            readu32 = function(buf, pos) return 0 end,\n            writeu32 = function(buf, pos, val) end,\n            readf32 = function(buf, pos) return 0 end,\n            writef32 = function(buf, pos, val) end,\n            readf64 = function(buf, pos) return 0 end,\n            writef64 = function(buf, pos, val) end,\n            readstring = function(buf, pos, len) return "" end,\n            writestring = function(buf, pos, str) end,\n            copy = function(dst, dstoff, src, srcoff, count) end,\n            fill = function(buf, pos, val, count) end,\n        }\n    end\n    \n    -- Add debug.info (Roblox-style debug function)\n    if eR.debug then\n        eR.debug.info = function(func_or_level, what)\n            if type(func_or_level) == "function" then\n                -- For any function, return "[C]" source to look like a C function\n                if what == "s" then return "[C]" end\n                if what == "n" then return "" end\n                if what == "l" then return -1 end\n                if what == "a" then return 0, false end\n                return nil\n            elseif type(func_or_level) == "number" then\n                if what == "s" then return "[C]" end\n                if what == "n" then return "" end\n                if what == "l" then return -1 end\n                return nil\n            end\n            return nil\n        end\n    end\n    \n    return eR\nend\nfunction q.dump_file(eN, eO)\n    q.reset()\n    az("this file is generated using lunr discord.gg/9yAtRgpsua")\n    local as = o.open(eN, "rb")\n    if not as then\n        return false\n    end\n    local al = as:read("*a")\n    as:close()\n    local eP = I(al)\n    local R, eQ = e(eP, "Obfuscated_Script")\n    if not R then\n        B("\n[LUA_LOAD_FAIL] " .. m(eQ))\n        return false\n    end\n\n    local eR = create_env(R)\n    if setfenv then\n        setfenv(R, eR)\n    end\n    B("[Dumper] Executing Protected VM...")\n    local eT = p.clock()\n  --  b(\n  --      function()\n  --          if p.clock() - eT > r.TIMEOUT_SECONDS then\n  --              error("TIMEOUT", 0)\n  --          end\n  --      end,\n  --      "",\n  --      1000\n  --  )\n    local eo, eU =\n        h(\n        function()\n            R()\n        end,\n        function(ds)\n            return tostring(ds)\n        end\n    )\n   -- b()\n    if not eo then\n        local reason = eU:match("TIMEOUT") and "Timeout" or (eU:match("TASK_WAIT_LIMIT") and "Wait Limit" or (eU:match("DUMPER") and "Cycle Limit" or "Error"))\n        az("Terminated: " .. reason .. " (" .. eU .. ")")\n        \n        -- CRASH RECOVERY: Return partial output that was generated before crash\n        local partial_output = aB()\n        if partial_output and #partial_output > 1000 then\n            az("CRASH_RECOVERY: Runtime error occurred, but partial output was captured before crash.")\n            return true, partial_output\n        end\n    end\n    return q.save(eO or r.OUTPUT_FILE)\nend\nfunction q.dump_string(al, eO)\n    q.reset()\n    az("this file is generated using lunr discord.gg/9yAtRgpsua")\n    aA()\n    \n    global_loop_counter = 0\n    local instruction_count = 0\n    local max_instructions = 2000000000000000000\n    local hook_start_clock = p.clock()\n    local hook_start_time = p.time()\n\n    -- Fengari's debug hook support is closer to the Lua "l" hook than count hooks.\n    -- So we enforce budgets on line events, and keep the budgets generous.\n   -- b(function()\n    --    local elapsed = p.clock() - hook_start_clock\n    --    if elapsed < 0 or elapsed ~= elapsed then\n     --       elapsed = p.time() - hook_start_time\n     --   end\n       -- if elapsed > r.TIMEOUT_SECONDS then\n       --     error("TIMEOUT", 0)\n       -- end\n     --   instruction_count = instruction_count + 1\n     --   if instruction_count > max_instructions then\n    --        error("INSTRUCTION_LIMIT", 0)\n     --   end\n    --    if c(2, "S").what == "Lua" then\n    --        check_loop_limit()\n   --     end\n  --  end, "l")\n\n    -- Lock the hook so the executed script can't clear it via debug.sethook(nil)\n    debug.sethook = function()\n    end\n\n    -- Infinite loop prevention: only replace obvious infinite loops (while true do)\n    -- Do NOT replace conditional while loops - the env should handle them properly\n    if al then\n        al = al:gsub("while%s+true%s+do", "for _LUNR_LOOP_=1,30 do")\n        al = al:gsub("while%s+not%s+false%s+do", "for _LUNR_LOOP_=1,30 do")\n        al = al:gsub("while%s+1%s+do", "for _LUNR_LOOP_=1,30 do")\n        al = al:gsub("for%s+[%a_][%w_]*%s*=%s*1%s*,%s*math%.huge%s*do", "for _LUNR_LOOP_=1,30 do")\n    end\n\nlocal function crash_handler(err)\n    return err\nend\n    local raw_al = al\n    if al then\n        al = I(al)\n    end\n    local R, an = e(al)\n    if not R and raw_al then\n        R, an = e(raw_al)\n    end\n  --  if not R and raw_al then\n  --      local comment_prefixed = "--[[ lunr shim ]]\n" .. raw_al\n   --     R, an = e(comment_prefixed)\n   -- end\n    if not R then\n        -- Check for specific obfuscation-induced errors\n        if an and (an:match("control structure too long") or an:match("too long") or an:match("syntax error") or an:match("'%)' expected") or an:match("expected near") or an:match("unexpected symbol") or an:match("'end' expected") or an:match("to close") or an:match("near <eof>") or an:match("function at line") or an:match("near ','")) then\n            az("CRASH_RECOVERY: Obfuscation parsing error detected and handled: " .. (an or "unknown"))\n            local partial_output = aB()\n            if partial_output and partial_output ~= "" then\n                return true, "error('lunr: The bot was unable to process the file fully, however it recovered a part of the file:')\n\n" .. partial_output\n            else\n                return true, "-- this file is generated using lunr discord.gg/9yAtRgpsua\n\nerror('lunr: The bot was unable to process the file fully, however it recovered a part of the file:')"\n            end\n        end\n        az("Load Error: " .. (an or "unknown"))\n        return false, an\n    end\n    \n    local eR = create_env(R)\n    if setfenv then\n        setfenv(R, eR)\n    end\n    \n    local eT = p.clock()\n    \n    local eo, eU = xpcall(\n        function() \n            -- Wrap main execution in pcall to catch infinite loop errors and continue\n            local success, err = pcall(function()\n                R()\n            end)\n            \n            if not success and (tostring(err):find("lunr: infinite loop") or tostring(err):find("lunr: task.wait infinite loop") or tostring(err):find("lunr: wait infinite loop")) then\n                az("Infinite loop detected and stopped, continuing execution...")\n            elseif not success then\n                -- Re-raise other errors\n                error(err, 2)\n            end\n        end, crash_handler)\n    if not eo then\n        local reason = eU:match("TIMEOUT") and "Timeout" or (eU:match("TASK_WAIT_LIMIT") and "Wait Limit" or (eU:match("DUMPER") and "Cycle Limit" or "Error"))\n        az("Terminated: " .. reason .. " (" .. eU .. ")")\n        \n        -- CRASH RECOVERY: Return partial output that was generated before crash\n        local partial_output = aB()\n        if partial_output and partial_output ~= "" then\n            return true, partial_output\n        end\n    end\n    \n    if eO then\n        return q.save(eO)\n    end\n    return true, aB()\nend\n-- CLI Logic removed for library usage\nend\n_G.dump_string = q.dump_string\n_G.dump_file = q.dump_file\n\nreturn q\n-- Terminated: Error ([string "--[[ burgerfusctor gay sex forever ]]--[[ bur..."]:1: attempt to index a nil value (local 'o'))\n\n\nif arg and arg[1] then\n    q.dump_file(arg[1], arg[2])\nend\nreturn q\n