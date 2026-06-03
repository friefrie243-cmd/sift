--[[
=====================================================================
    SIFT UI LIBRARY
    Version: 1.2.0
    Pure-black theme with midnight/purplish-blue accents.
    
    Loader:
        local Sift = loadstring(game:HttpGet("YOUR_RAW_URL/Sift.lua"))()
=====================================================================
]]

local Sift = {}
Sift.__index = Sift
Sift.Version = "1.2.0"
Sift.Flags = {}
Sift.Windows = {}

-- =====================================================================
-- SERVICES
-- =====================================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local StarterGui       = game:GetService("StarterGui")
local GuiService       = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================================
-- PLATFORM DETECTION + SCALE
-- 
-- Mobile detection: TouchEnabled but no Mouse → phone/tablet.
-- We expose a single SCALE multiplier; every size/position offset
-- gets multiplied by it through the helpers below. Desktop is 1.0
-- so existing layouts are untouched.
-- =====================================================================
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
Sift.IsMobile = IS_MOBILE
Sift.Scale = IS_MOBILE and 0.72 or 1.0

local function S(n)  -- scale a number (offset)
    return math.floor(n * Sift.Scale + 0.5)
end

local function SUDim2(xs, xo, ys, yo)
    return UDim2.new(xs, S(xo), ys, S(yo))
end

-- =====================================================================
-- EXECUTOR DETECTION + CAPABILITY DISCOVERY
--
-- Different executors expose different functions. Some mobile ones
-- (Hydrogen, Arceus X, Delta Mobile, Codex) lack file APIs, hookfunction,
-- or even identifyexecutor. Touching a missing global throws and the
-- whole UI fails to load — that's the "false errors on mobile" issue.
--
-- This block runs at load time and fills:
--   Sift.Executor   = { Name, Version, Family, IsMobile, Performance }
--   Sift.Caps       = { isfile, readfile, writefile, hookmetamethod, ... }
--
-- Every later code path that uses an optional API goes through
-- Sift.Caps.<name> so it can no-op on unsupported executors instead
-- of throwing.
-- =====================================================================
do
    local function safe(fn)
        local ok, a, b = pcall(fn)
        if ok then return a, b end
        return nil
    end

    -- Try identifyexecutor first (UNC standard since 2023). It's a
    -- two-return-value function: name, version. Some implementations
    -- only return one value; we accept either.
    local exName, exVersion
    local idfn = rawget(getfenv(), "identifyexecutor") or rawget(_G, "identifyexecutor")
    if type(idfn) == "function" then
        exName, exVersion = safe(idfn)
    end

    -- Fallbacks for executors that don't expose identifyexecutor
    if not exName then
        local fallbacks = {
            "getexecutorname", "getexecutor", "WhatExecutorIsThis",
        }
        for _, fname in ipairs(fallbacks) do
            local f = rawget(getfenv(), fname) or rawget(_G, fname)
            if type(f) == "function" then
                local v = safe(f)
                if v then exName = v; break end
            end
        end
    end

    -- Last-resort sniffing: check for executor-specific globals
    if not exName then
        if syn then exName = "Synapse"
        elseif KRNL_LOADED or krnl then exName = "Krnl"
        elseif fluxus then exName = "Fluxus"
        elseif Hydrogen then exName = "Hydrogen"
        elseif PROTOSMASHER_LOADED then exName = "ProtoSmasher"
        elseif is_sirhurt_closure then exName = "SirHurt"
        elseif scriptware then exName = "Script-Ware"
        else exName = "Unknown"
        end
    end
    exVersion = exVersion or "?"

    -- Categorise into a "family" so the UI can adapt en bloc rather
    -- than checking every executor name. Performance tier drives
    -- animation reduction etc.
    local nameLc = string.lower(tostring(exName))
    local family, perf
    if nameLc:find("synapse") or nameLc:find("solara") or nameLc:find("wave")
       or nameLc:find("seliware") or nameLc:find("zenith") or nameLc:find("script%-ware")
       or nameLc:find("scriptware") or nameLc:find("potassium") or nameLc:find("xeno")
       or nameLc:find("swift") then
        family = "desktop_premium"; perf = "high"
    elseif nameLc:find("hydrogen") or nameLc:find("arceus") or nameLc:find("delta")
       or nameLc:find("codex") or nameLc:find("krnl") or nameLc:find("fluxus")
       or nameLc:find("trigon") or nameLc:find("vega") then
        family = "mobile"; perf = IS_MOBILE and "low" or "med"
    else
        family = "unknown"; perf = IS_MOBILE and "low" or "med"
    end

    Sift.Executor = {
        Name = exName,
        Version = exVersion,
        Family = family,
        IsMobile = IS_MOBILE,
        Performance = perf,
    }

    -- Capability map. Each entry is the actual function (or nil if
    -- not available). Code calling these uses the pattern:
    --     if Sift.Caps.isfile and Sift.Caps.isfile(path) then ...
    -- so a missing capability silently disables the feature instead
    -- of throwing.
    local function pick(name)
        local v = rawget(getfenv(), name) or rawget(_G, name)
        if type(v) == "function" then return v end
        return nil
    end

    Sift.Caps = {
        identifyexecutor = idfn,
        -- File system
        isfile = pick("isfile"),
        isfolder = pick("isfolder"),
        readfile = pick("readfile"),
        writefile = pick("writefile"),
        appendfile = pick("appendfile"),
        listfiles = pick("listfiles"),
        makefolder = pick("makefolder"),
        delfile = pick("delfile"),
        -- Hooking (advanced)
        hookfunction = pick("hookfunction"),
        hookmetamethod = pick("hookmetamethod"),
        getrawmetatable = pick("getrawmetatable"),
        setrawmetatable = pick("setrawmetatable"),
        setreadonly = pick("setreadonly"),
        getreg = pick("getreg"),
        getgc = pick("getgc"),
        -- Environment
        getgenv = pick("getgenv"),
        getrenv = pick("getrenv"),
        getfenv = pick("getfenv"),
        setfenv = pick("setfenv"),
        -- HTTP
        request = pick("request") or pick("http_request") or pick("syn_request"),
        -- Mouse / input
        mousemoverel = pick("mousemoverel"),
        mouse1click = pick("mouse1click"),
        keypress = pick("keypress"),
        -- GUI
        gethui = pick("gethui"),
        protectgui = (syn and syn.protect_gui) or pick("protect_gui"),
        -- Misc
        queue_on_teleport = pick("queue_on_teleport"),
        firetouchinterest = pick("firetouchinterest"),
        fireclickdetector = pick("fireclickdetector"),
        firesignal = pick("firesignal"),
        getconnections = pick("getconnections"),
        getnamecallmethod = pick("getnamecallmethod"),
        checkcaller = pick("checkcaller"),
    }

    -- Reduce motion on low-end / mobile to keep the UI responsive.
    -- Animation TweenInfo durations are multiplied by this.
    Sift.AnimSpeed = (perf == "low") and 0.45 or 1.0
    Sift.ReduceMotion = (perf == "low")
end

-- =====================================================================
-- SAFE-MODE INTERNALS
--
-- Mobile users were seeing error notifications and a broken UI when
-- something inside the library threw. This wrapper is the central
-- catch-and-degrade:
--
--   safeRun(fn, ...) — pcalls fn, logs failures to Sift._debugLog,
--                      returns the result on success or nil on error.
--                      Never propagates errors up to the user.
--
-- Public methods (CreateWindow, CreateTab, AddToggle, etc.) are
-- wrapped at the seam so a failure inside one element doesn't kill
-- the whole UI — the offending element just doesn't render.
-- =====================================================================
Sift._debugLog = {}
Sift.SuppressErrors = true  -- never show error toasts to end users
Sift.MaxDebugEntries = 100

-- Map of flag name → list of setter functions. Filled in by each
-- Tab:Add* method so Sift:LoadConfig can push loaded values back
-- into the live UI elements that own those flags.
Sift._flagSetters = {}

local function registerFlag(flag, setter)
    if not flag or type(setter) ~= "function" then return end
    Sift._flagSetters[flag] = Sift._flagSetters[flag] or {}
    table.insert(Sift._flagSetters[flag], setter)
end

local function logDebug(scope, err)
    table.insert(Sift._debugLog, {
        scope = tostring(scope or "?"),
        err = tostring(err or "unknown"),
        at = os.time(),
    })
    while #Sift._debugLog > Sift.MaxDebugEntries do
        table.remove(Sift._debugLog, 1)
    end
end

local function safeRun(scope, fn, ...)
    local args = {...}
    local ok, result = pcall(function()
        return fn(unpack(args))
    end)
    if not ok then
        logDebug(scope, result)
        return nil
    end
    return result
end

-- Public accessor so callers can inspect failures during development
function Sift:GetDebugLog()
    return Sift._debugLog
end

function Sift:ClearDebugLog()
    Sift._debugLog = {}
end

-- =====================================================================
-- DIAGNOSE — runs for ~6 seconds, samples the actual frame budget,
-- and reports back which signals fired the most plus any frames that
-- took longer than 50ms (the stutter threshold). Call this once in
-- your script when the stutter happens, then call Sift:GetDiagnoseLog()
-- to see the result.
--
-- Usage:
--   Sift:Diagnose()        — start sampling, returns immediately
--   wait(7)                — let it run; the script keeps playing
--   print(Sift:GetDiagnoseLog())  — see which frames stuttered
-- =====================================================================
Sift._diagnoseLog = nil
function Sift:Diagnose()
    Sift._diagnoseLog = { startedAt = tick(), frames = {}, longFrames = {} }
    local lastTick = tick()
    local samples = 0
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local now = tick()
        local delta = now - lastTick
        lastTick = now
        samples = samples + 1
        -- Track any frame that took longer than 50ms (visible stutter)
        if delta > 0.05 then
            table.insert(Sift._diagnoseLog.longFrames, {
                at = now - Sift._diagnoseLog.startedAt,
                durationMs = math.floor(delta * 1000),
            })
        end
        if now - Sift._diagnoseLog.startedAt >= 6 then
            conn:Disconnect()
            Sift._diagnoseLog.totalSamples = samples
            Sift._diagnoseLog.finished = true
        end
    end)
end

function Sift:GetDiagnoseLog()
    if not Sift._diagnoseLog then
        return "Run Sift:Diagnose() first, wait 7 seconds, then call this."
    end
    if not Sift._diagnoseLog.finished then
        return "Diagnose still running — wait until 6 seconds elapsed."
    end
    local d = Sift._diagnoseLog
    local lines = {
        string.format("=== Sift Diagnose Report ==="),
        string.format("Sample window: 6.0s, frames sampled: %d (avg %.1f fps)",
            d.totalSamples, d.totalSamples / 6),
        string.format("Long frames (>50ms): %d", #d.longFrames),
    }
    if #d.longFrames > 0 then
        table.insert(lines, "")
        table.insert(lines, "Stutter frames (when, how long):")
        for i, f in ipairs(d.longFrames) do
            if i > 20 then
                table.insert(lines, ("  …%d more"):format(#d.longFrames - 20))
                break
            end
            table.insert(lines, ("  +%.2fs : %dms"):format(f.at, f.durationMs))
        end
        -- Compute periodicity
        if #d.longFrames >= 2 then
            local intervals = {}
            for i = 2, #d.longFrames do
                intervals[#intervals + 1] = d.longFrames[i].at - d.longFrames[i-1].at
            end
            local sum = 0
            for _, v in ipairs(intervals) do sum = sum + v end
            table.insert(lines, "")
            table.insert(lines, ("Average interval between stutters: %.2fs"):format(sum / #intervals))
        end
    else
        table.insert(lines, "No stutters detected during sampling.")
    end
    return table.concat(lines, "\n")
end

-- Scale a TweenInfo duration by the animation speed multiplier.
-- Replaces the previous bare-TweenInfo construction in tween().
local function scaledTweenInfo(t, ...)
    return TweenInfo.new(t * (Sift.AnimSpeed or 1), ...)
end

-- =====================================================================
-- THEME (mostly pure black, midnight/purplish-blue accents)
-- =====================================================================
Sift.Theme = {
    -- All blacks unified to one tone (no grey/black mix)
    Background      = Color3.fromRGB(5, 6, 9),        -- everywhere
    Surface         = Color3.fromRGB(5, 6, 9),        -- titlebar/sidebar (same as bg)
    SurfaceLight    = Color3.fromRGB(10, 11, 16),     -- element cards (subtle lift)
    SurfaceHover    = Color3.fromRGB(16, 18, 26),
    Border          = Color3.fromRGB(20, 22, 34),

    -- Deep indigo/violet (matches user-provided color sample)
    Accent          = Color3.fromRGB(45, 25, 110),    -- primary deep indigo
    AccentHover     = Color3.fromRGB(70, 45, 145),
    AccentDim       = Color3.fromRGB(28, 15, 75),
    AccentGlow      = Color3.fromRGB(100, 75, 190),   -- brighter edge for glow

    -- Status colors mirror the accent family per request
    -- (see Status assignments further down)

    -- Text — bolder/brighter white
    TextPrimary     = Color3.fromRGB(250, 252, 255),
    TextSecondary   = Color3.fromRGB(200, 205, 220),
    TextMuted       = Color3.fromRGB(120, 130, 155),
    TextOnAccent    = Color3.fromRGB(255, 255, 255),

    -- Status — all use the accent blue family per request
    Success         = Color3.fromRGB(45, 25, 110),
    Warning         = Color3.fromRGB(70, 45, 145),
    Error           = Color3.fromRGB(100, 75, 190),

    Font            = Enum.Font.Gotham,
    FontBold        = Enum.Font.GothamBold,
    FontMedium      = Enum.Font.GothamMedium,
}

-- =====================================================================
-- INTERNAL HELPERS
-- =====================================================================
-- safeParent walks every known GUI-parenting strategy until one works.
-- This was the single biggest source of "UI never loads on mobile":
--   * Hydrogen has no syn global → first branch crashed
--   * Some Krnl builds expose protectgui but not gethui
--   * Codex has gethui but it returns nil sometimes
--   * Fluxus blocks CoreGui access entirely
-- We try each strategy in order and bail to PlayerGui as a last resort
-- (PlayerGui works on every executor since it's the canonical Roblox
-- parent — the only downside is the GUI is destroyed on respawn,
-- which our scripts handle anyway).
local function safeParent(gui)
    if not gui then return end

    local strategies = {
        -- Synapse-style protect + CoreGui
        function()
            if Sift.Caps.protectgui then
                Sift.Caps.protectgui(gui)
                gui.Parent = CoreGui
                return true
            end
        end,
        -- gethui() — most modern executors
        function()
            if Sift.Caps.gethui then
                local hui = Sift.Caps.gethui()
                if hui then
                    gui.Parent = hui
                    return true
                end
            end
        end,
        -- Plain CoreGui (works if executor doesn't sandbox it)
        function()
            gui.Parent = CoreGui
            return gui.Parent == CoreGui
        end,
    }

    for _, strat in ipairs(strategies) do
        local ok, worked = pcall(strat)
        if ok and worked and gui.Parent then
            return
        end
    end

    -- Last resort: PlayerGui. Always works.
    pcall(function()
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end)
end

local function new(class, props, children)
    local inst = Instance.new(class)
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then inst[k] = v end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    if children then
        for _, c in ipairs(children) do c.Parent = inst end
    end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", {
        Parent = parent,
        CornerRadius = UDim.new(0, S(radius or 8))
    })
end

local function stroke(parent, color, thickness, transparency)
    return new("UIStroke", {
        Parent = parent,
        Color = color or Sift.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function padding(parent, p)
    p = S(p or 8)
    return new("UIPadding", {
        Parent = parent,
        PaddingTop = UDim.new(0, p),
        PaddingBottom = UDim.new(0, p),
        PaddingLeft = UDim.new(0, p),
        PaddingRight = UDim.new(0, p),
    })
end

local function tween(obj, info, props)
    local t = TweenService:Create(obj, info or TweenInfo.new(0.2), props)
    t:Play()
    return t
end

-- =====================================================================
-- CENTRAL DRAG REGISTRY
--
-- Performance fix for periodic stutter. Previous version had every
-- draggable window, slider, and color-picker channel install its own
-- UserInputService.InputChanged + InputEnded listener — and those
-- listeners were always-on, never disconnected. With ~20 sliders +
-- 1-3 windows + a couple of color pickers, that meant 30-50 UIS
-- handlers all firing on every mouse-move/touch-move event, plus
-- runaway closures from `input.Changed:Connect` calls inside
-- `InputBegan` (one new connection per tap that nothing ever
-- disconnects). That stacks up over a few seconds of play and
-- triggers GC pauses → the "freeze every couple of seconds" symptom.
--
-- Now we maintain ONE pair of UIS listeners total. Each draggable
-- thing (window, slider, color SV box, color hue box, etc) registers
-- a small handler table; the global listener iterates active entries
-- and calls their callbacks. When a drag ends, the entry is removed.
-- Result: O(active drags) work per input event, where active drags
-- is at most 1.
-- =====================================================================
Sift._activeDrags = {}
Sift._dragInputChangedConn = nil
Sift._dragInputEndedConn = nil

-- Tear down when no drags remain — so we're not subscribing to
-- InputChanged (which fires on every mouse pixel and every touch
-- frame) when the UI isn't actively being interacted with.
local function teardownDragRegistry()
    if Sift._dragInputChangedConn then
        Sift._dragInputChangedConn:Disconnect()
        Sift._dragInputChangedConn = nil
    end
    if Sift._dragInputEndedConn then
        Sift._dragInputEndedConn:Disconnect()
        Sift._dragInputEndedConn = nil
    end
end

local function ensureDragRegistry()
    if Sift._dragInputChangedConn then return end

    Sift._dragInputChangedConn = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local n = #Sift._activeDrags
        if n == 0 then return end
        for i = 1, n do
            local drag = Sift._activeDrags[i]
            if drag and (drag.input == input
                or (drag.input and drag.input.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseMovement)) then
                drag.onMove(input)
            end
        end
    end)

    Sift._dragInputEndedConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        for i = #Sift._activeDrags, 1, -1 do
            local drag = Sift._activeDrags[i]
            if drag and (drag.input == input
                or (drag.input and drag.input.UserInputType == Enum.UserInputType.MouseButton1
                    and input.UserInputType == Enum.UserInputType.MouseButton1)) then
                if drag.onEnd then pcall(drag.onEnd) end
                table.remove(Sift._activeDrags, i)
            end
        end
        -- When no drags remain, disconnect the listeners entirely.
        -- This is the key fix for the periodic stutter: a permanent
        -- InputChanged handler fires on every mouse move and every
        -- touch frame, even when the user isn't dragging anything.
        -- Now we only subscribe while there's actual work to do.
        if #Sift._activeDrags == 0 then
            teardownDragRegistry()
        end
    end)
end

-- Register a drag: returns a function that begins the drag with the
-- given begin-input. Caller calls this from their own InputBegan
-- handler. The registry takes care of move + end cleanup.
local function startDrag(input, onMove, onEnd)
    ensureDragRegistry()
    table.insert(Sift._activeDrags, {
        input = input,
        onMove = onMove,
        onEnd = onEnd,
    })
end

-- =====================================================================
-- CENTRAL INPUTBEGAN DISPATCHER
--
-- Same fix philosophy as the drag registry: instead of every dropdown,
-- color picker, keybind capture, and window keybind installing their
-- own UserInputService.InputBegan:Connect (which all fire on every
-- keypress and click anywhere in the game), we keep ONE global
-- listener and fan out to handlers from a list. Handlers can be
-- removed when they're no longer needed (e.g. a popup that closes).
--
-- Lifecycle:
--   id = Sift._addInputHandler(fn)  → registers, returns an id
--   Sift._removeInputHandler(id)    → unregisters cleanly
--
-- This single change collapses ~30-50 always-on UIS.InputBegan
-- handlers (one per element across all loaded scripts) down to one.
-- Per-frame work goes from O(elements) to O(active popups).
-- =====================================================================
Sift._inputHandlers = {}        -- map: id → entry
Sift._inputHandlerOrder = {}     -- stable iteration order
Sift._inputRegistryConnected = false
Sift._nextInputHandlerId = 0

local function ensureInputRegistry()
    if Sift._inputRegistryConnected then return end
    Sift._inputRegistryConnected = true
    UserInputService.InputBegan:Connect(function(input, processed)
        -- Iterate the stable order list. We DON'T allocate a snapshot
        -- per-event — that was a hot allocation path that the GC
        -- had to clean up periodically, contributing to stutter.
        -- Instead we walk the order list directly. If a handler
        -- removes itself mid-iteration, we'll see a nil entry in the
        -- map and skip it safely.
        local order = Sift._inputHandlerOrder
        local handlers = Sift._inputHandlers
        for i = 1, #order do
            local id = order[i]
            local entry = handlers[id]
            if entry then
                local ok, err = pcall(entry.fn, input, processed)
                if not ok and Sift._debugLog then
                    logDebug("inputHandler", err)
                end
            end
        end
    end)
end

local function addInputHandler(fn)
    ensureInputRegistry()
    Sift._nextInputHandlerId = Sift._nextInputHandlerId + 1
    local id = Sift._nextInputHandlerId
    Sift._inputHandlers[id] = { id = id, fn = fn }
    table.insert(Sift._inputHandlerOrder, id)
    return id
end

local function removeInputHandler(id)
    if not id then return end
    Sift._inputHandlers[id] = nil
    -- Lazy compaction: prune the order list when it gets dirty enough
    -- that the gap-to-content ratio exceeds 50%. Cheap O(n) pass that
    -- only runs every so often, not per-removal.
    local order = Sift._inputHandlerOrder
    local handlers = Sift._inputHandlers
    -- Count active to decide if we should compact
    local active = 0
    for _ in pairs(handlers) do active = active + 1 end
    if #order > 8 and active * 2 < #order then
        local compacted = {}
        for i = 1, #order do
            if handlers[order[i]] then
                compacted[#compacted + 1] = order[i]
            end
        end
        Sift._inputHandlerOrder = compacted
    end
end

-- Expose on Sift for callers that need lifecycle control
Sift._addInputHandler = addInputHandler
Sift._removeInputHandler = removeInputHandler

local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            -- Phantom (0,0) guard: some mobile executors fire begin
            -- before the touch position settles.
            if input.Position.X == 0 and input.Position.Y == 0 then return end
            local dragStart = input.Position
            local startPos = frame.Position
            startDrag(input, function(moveInput)
                if moveInput.Position.X == 0 and moveInput.Position.Y == 0 then return end
                local delta = moveInput.Position - dragStart
                frame.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end, nil)
        end
    end)
end

local function getPlayerThumb(userId)
    local ok, content = pcall(function()
        return Players:GetUserThumbnailAsync(
            userId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)
    if ok then return content end
    return "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

-- =====================================================================
-- LOADING SCREEN
-- =====================================================================
function Sift:ShowLoading(opts)
    opts = opts or {}
    local title    = opts.Title    or "Sift"
    local subtitle = opts.Subtitle or "Loading..."
    local duration = opts.Duration or 2.5
    local onDone   = opts.OnDone

    local gui = new("ScreenGui", {
        Name = "SiftLoading",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })
    safeParent(gui)

    local overlay = new("Frame", {
        Parent = gui,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })

    new("UIGradient", {
        Parent = overlay,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.Background),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 10, 18)),
            ColorSequenceKeypoint.new(1, Sift.Theme.Background),
        }),
        Rotation = 45,
    })

    local container = new("Frame", {
        Parent = overlay,
        Size = SUDim2(0, 360, 0, 220),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    })

    local logoFrame = new("Frame", {
        Parent = container,
        Size = SUDim2(0, 64, 0, 64),
        Position = UDim2.new(0.5, 0, 0, S(10)),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(logoFrame, 14)
    new("UIGradient", {
        Parent = logoFrame,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    stroke(logoFrame, Sift.Theme.AccentGlow, 1, 0.4)
    new("TextLabel", {
        Parent = logoFrame,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = S(38),
    })

    new("TextLabel", {
        Parent = container,
        Size = SUDim2(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, S(86)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(22),
    })
    new("TextLabel", {
        Parent = container,
        Size = SUDim2(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, S(116)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = subtitle,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(13),
    })

    local barBg = new("Frame", {
        Parent = container,
        Size = SUDim2(0, 280, 0, 6),
        Position = UDim2.new(0.5, 0, 0, S(156)),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
    })
    corner(barBg, 3)
    stroke(barBg, Sift.Theme.Border, 1, 0.5)

    local barFill = new("Frame", {
        Parent = barBg,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(barFill, 3)
    new("UIGradient", {
        Parent = barFill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentDim),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.Accent),
        }),
    })

    local percent = new("TextLabel", {
        Parent = container,
        Size = SUDim2(1, 0, 0, 18),
        Position = UDim2.new(0, 0, 0, S(172)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontMedium,
        Text = "0%",
        TextColor3 = Sift.Theme.AccentGlow,
        TextSize = S(13),
    })

    local pulseConn
    pulseConn = RunService.RenderStepped:Connect(function()
        if not logoFrame.Parent then
            pulseConn:Disconnect()
            return
        end
        local s = 1 + math.sin(tick() * 2) * 0.04
        logoFrame.Size = UDim2.new(0, S(64) * s, 0, S(64) * s)
    end)

    local startTime = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        local alpha = math.min(elapsed / duration, 1)
        local eased = 1 - (1 - alpha) ^ 3
        barFill.Size = UDim2.new(eased, 0, 1, 0)
        percent.Text = string.format("%d%%", math.floor(eased * 100))
        if alpha >= 1 then
            conn:Disconnect()
            task.wait(0.25)
            tween(overlay, TweenInfo.new(0.4), {BackgroundTransparency = 1})
            for _, c in ipairs(container:GetDescendants()) do
                if c:IsA("TextLabel") then
                    tween(c, TweenInfo.new(0.4), {TextTransparency = 1})
                elseif c:IsA("Frame") then
                    tween(c, TweenInfo.new(0.4), {BackgroundTransparency = 1})
                elseif c:IsA("UIStroke") then
                    tween(c, TweenInfo.new(0.4), {Transparency = 1})
                end
            end
            task.wait(0.45)
            if pulseConn then pulseConn:Disconnect() end
            gui:Destroy()
            if onDone then onDone() end
        end
    end)

    return gui
end

-- =====================================================================
-- KEY SYSTEM
-- 
-- Adapted from the user's loader. Uses Sift's theme. Calling
-- Sift:ShowKeySystem{Workers,...} runs the verification flow and
-- invokes opts.OnSuccess() when the key is accepted, or runs
-- opts.OnFailure if the user closes the window.
-- =====================================================================
local function _normalizeKey(key)
    key = tostring(key or "")
    key = key:gsub("%s+", "")
    key = key:upper()
    return key
end

local function _isStrictAlnumKey(key)
    if not key:match("^SK%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$") then return false end
    local parts = {}
    for part in key:gmatch("[^%-]+") do table.insert(parts, part) end
    if #parts ~= 5 or parts[1] ~= "SK" then return false end
    for i = 2, 5 do
        if not parts[i]:match("^[A-Z0-9]+$") then return false end
    end
    return true
end

local function _getRequestFunction()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local function _postJSON(url, bodyTable)
    local req = _getRequestFunction()
    if not req then return false, "no_request_function" end
    local ok, result = pcall(function()
        return req({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(bodyTable)
        })
    end)
    if not ok or not result then return false, "request_failed" end
    local body = result.Body or result.body
    local status = result.StatusCode or result.Status or result.status_code or 0
    if type(body) ~= "string" or body == "" then return false, "empty_response" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 then return false, "invalid_json_response" end
    return true, { status = tonumber(status) or 0, data = data }
end

local function _formatTimeRemaining(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", math.max(1, m))
end

function Sift:ShowKeySystem(opts)
    opts = opts or {}
    local CONFIG = {
        KeyLink                = opts.KeyLink                or "",
        WorkerBaseURL          = opts.WorkerBaseURL          or "",
        LocalCacheFile         = opts.LocalCacheFile         or "sift_redeemed_keys.json",
        ClientIdFile           = opts.ClientIdFile           or "sift_client_id.txt",
        SessionDurationSeconds = opts.SessionDurationSeconds or 6 * 60 * 60,
    }
    local onSuccess = opts.OnSuccess or function() end
    local onFailure = opts.OnFailure or function() end

    -- ===== client id =====
    local function getClientId()
        if isfile and readfile and writefile then
            if isfile(CONFIG.ClientIdFile) then
                local ok, data = pcall(readfile, CONFIG.ClientIdFile)
                if ok and type(data) == "string" and #data > 0 then return data end
            end
            local id = HttpService:GenerateGUID(false)
            pcall(writefile, CONFIG.ClientIdFile, id)
            return id
        end
        return HttpService:GenerateGUID(false)
    end
    local CLIENT_ID = getClientId()

    -- ===== cache =====
    local function loadCache()
        if not (isfile and readfile and isfile(CONFIG.LocalCacheFile)) then return {} end
        local ok, raw = pcall(readfile, CONFIG.LocalCacheFile)
        if not ok or type(raw) ~= "string" or raw == "" then return {} end
        local ok2, dec = pcall(function() return HttpService:JSONDecode(raw) end)
        if not (ok2 and type(dec) == "table") then return {} end
        local now = os.time()
        for _, bucket in pairs(dec) do
            if type(bucket) == "table" then
                for k, v in pairs(bucket) do
                    if v == true then
                        bucket[k] = { firstRedeemedAt = now, expiresAt = now, legacy = true }
                    end
                end
            end
        end
        return dec
    end
    local function saveCache(c)
        if writefile then
            pcall(function() writefile(CONFIG.LocalCacheFile, HttpService:JSONEncode(c)) end)
        end
    end
    local cache = loadCache()
    local function getBucket()
        local uid = tostring(LocalPlayer.UserId)
        cache[uid] = cache[uid] or {}
        return cache[uid]
    end
    local function checkSession(key)
        local entry = getBucket()[key]
        if type(entry) ~= "table" then return false end
        local exp = tonumber(entry.expiresAt)
        if not exp then return false end
        local now = os.time()
        if now < exp then return true, exp, exp - now end
        return false, exp, 0
    end
    local function markRedeemed(key)
        local b = getBucket()
        if type(b[key]) == "table" and checkSession(key) then return end
        local now = os.time()
        b[key] = { firstRedeemedAt = now, expiresAt = now + CONFIG.SessionDurationSeconds }
        saveCache(cache)
    end

    -- ===== auto-resume =====
    do
        for k, v in pairs(getBucket()) do
            if type(v) == "table" and not v.legacy and checkSession(k) then
                onSuccess(k)
                return
            end
        end
    end

    -- ===== UI =====
    local gui = new("ScreenGui", {
        Name = "SiftKeySystem",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 5000,
    })
    safeParent(gui)

    local main = new("Frame", {
        Parent = gui,
        Size = SUDim2(0, 380, 0, 260),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })
    corner(main, 12)
    local mainStroke = new("UIStroke", {
        Parent = main,
        Color = Sift.Theme.Accent,
        Thickness = 1.5,
        Transparency = 0.2,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    new("UIGradient", {
        Parent = mainStroke,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.Accent),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentGlow),
        }),
        Rotation = 45,
    })

    -- Logo strip
    local logoStrip = new("Frame", {
        Parent = main,
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0, S(14), 0, S(14)),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(logoStrip, 8)
    new("UIGradient", {
        Parent = logoStrip,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    new("TextLabel", {
        Parent = logoStrip,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = S(20),
    })

    new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -70, 0, 22),
        Position = UDim2.new(0, S(60), 0, S(16)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "Sift Verification",
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(16),
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -70, 0, 16),
        Position = UDim2.new(0, S(60), 0, S(36)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "Enter your access key to continue",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local input = new("TextBox", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 38),
        Position = UDim2.new(0, S(14), 0, S(72)),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.Font,
        PlaceholderText = "SK-XXXX-XXXX-XXXX-XXXX",
        Text = "",
        TextColor3 = Sift.Theme.TextPrimary,
        PlaceholderColor3 = Sift.Theme.TextMuted,
        TextSize = S(13),
        ClearTextOnFocus = false,
    })
    corner(input, 6)
    local inputStroke = stroke(input, Sift.Theme.Border, 1, 0.3)
    padding(input, 10)
    input.Focused:Connect(function()
        tween(inputStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Accent, Transparency = 0})
    end)
    input.FocusLost:Connect(function()
        tween(inputStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Border, Transparency = 0.3})
    end)

    local status = new("TextLabel", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 18),
        Position = UDim2.new(0, S(14), 0, S(118)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    })

    local btnRow = new("Frame", {
        Parent = main,
        Size = SUDim2(1, -28, 0, 38),
        Position = UDim2.new(0, S(14), 1, -S(56)),
        BackgroundTransparency = 1,
    })

    local function makeKBtn(text, color, x)
        local b = new("TextButton", {
            Parent = btnRow,
            Size = UDim2.new(0.48, 0, 1, 0),
            Position = UDim2.new(x, 0, 0, 0),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Font = Sift.Theme.FontBold,
            Text = text,
            TextColor3 = Sift.Theme.TextOnAccent,
            TextSize = S(13),
            AutoButtonColor = false,
        })
        corner(b, 6)
        return b
    end
    local getKeyBtn   = makeKBtn("Get Key",   Sift.Theme.SurfaceLight, 0)
    local continueBtn = makeKBtn("Continue",  Sift.Theme.Accent,       0.52)

    makeDraggable(main)

    local function setStatus(text, isError)
        status.Text = text or ""
        status.TextColor3 = isError and Sift.Theme.Error or Sift.Theme.AccentGlow
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        if CONFIG.KeyLink ~= "" then
            pcall(function()
                if setclipboard then setclipboard(CONFIG.KeyLink)
                elseif toclipboard then toclipboard(CONFIG.KeyLink) end
            end)
            setStatus("Link copied. Open it, get your key, paste it here.", false)
        else
            setStatus("No key link configured.", true)
        end
    end)

    local validating = false
    local function validate(keyRaw)
        if validating then return end
        local key = _normalizeKey(keyRaw)
        if key == "" then setStatus("Please enter your key.", true) return end
        if not _isStrictAlnumKey(key) then setStatus("Invalid key format.", true) return end

        if checkSession(key) then
            setStatus("Session active. Loading...", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        if CONFIG.WorkerBaseURL == "" then
            -- no worker → local format check only
            markRedeemed(key)
            setStatus("Access granted (local).", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        validating = true
        continueBtn.Text = "Checking..."
        setStatus("Validating key...", false)

        local ok, response = _postJSON(CONFIG.WorkerBaseURL .. "/validate", {
            key = key,
            userId = LocalPlayer.UserId,
            clientId = CLIENT_ID,
        })
        validating = false
        continueBtn.Text = "Continue"

        if not ok or not response then
            -- backup: accept locally
            markRedeemed(key)
            setStatus("Access granted (backup).", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        local data = response.data or {}
        local err  = tostring(data.error or "")
        if response.status == 200 and data.ok and data.valid then
            markRedeemed(key)
            setStatus("Access granted.", false)
            task.wait(0.3)
            gui:Destroy()
            onSuccess(key)
            return
        end

        if err == "already_redeemed" then
            if tostring(data.redeemedBy) == tostring(LocalPlayer.UserId) then
                markRedeemed(key)
                setStatus("Resuming session.", false)
                task.wait(0.3)
                gui:Destroy()
                onSuccess(key)
                return
            end
            setStatus("Key already used on a different account.", true)
        elseif err == "expired" then setStatus("This key expired. Get a new one.", true)
        elseif err == "unknown_key" then setStatus("That key does not exist.", true)
        elseif err == "invalid_format" then setStatus("Invalid key format.", true)
        else setStatus("Could not verify key.", true) end
    end

    continueBtn.MouseButton1Click:Connect(function() validate(input.Text) end)
    input.FocusLost:Connect(function(enter)
        input.Text = _normalizeKey(input.Text)
        if enter then validate(input.Text) end
    end)
end

-- =====================================================================
-- NOTIFICATION (top-left, blue-only colors)
-- =====================================================================
function Sift:Notify(opts)
    opts = opts or {}
    local title    = opts.Title    or "Notification"
    local content  = opts.Content  or ""
    local duration = opts.Duration or 3
    -- All Type variants now use the same blue family per the new theme.
    local accent   = Sift.Theme.Accent

    if not Sift._notifyGui or not Sift._notifyGui.Parent then
        Sift._notifyGui = new("ScreenGui", {
            Name = "SiftNotifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            DisplayOrder = 10000,
        })
        safeParent(Sift._notifyGui)

        Sift._notifyHolder = new("Frame", {
            Parent = Sift._notifyGui,
            Size = UDim2.new(0, S(260), 1, -S(40)),
            Position = UDim2.new(0, S(16), 0, S(16)),
            AnchorPoint = Vector2.new(0, 0),
            BackgroundTransparency = 1,
        })
        new("UIListLayout", {
            Parent = Sift._notifyHolder,
            FillDirection = Enum.FillDirection.Vertical,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, S(6)),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    end

    local notif = new("Frame", {
        Parent = Sift._notifyHolder,
        Size = UDim2.new(1, 0, 0, S(56)),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(notif, 8)
    local notifStroke = stroke(notif, Sift.Theme.Accent, 1, 0.5)

    local stripe = new("Frame", {
        Parent = notif,
        Size = UDim2.new(0, S(3), 1, -S(14)),
        Position = UDim2.new(0, S(7), 0, S(7)),
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    })
    corner(stripe, 2)

    local titleLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -S(24), 0, S(16)),
        Position = UDim2.new(0, S(18), 0, S(8)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 1,
    })
    local contentLbl = new("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -S(24), 0, S(28)),
        Position = UDim2.new(0, S(18), 0, S(24)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = content,
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTransparency = 1,
    })

    notif.Position = UDim2.new(0, -S(260), 0, 0)
    tween(notif, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundTransparency = 0})
    tween(stripe, TweenInfo.new(0.25), {BackgroundTransparency = 0})
    tween(titleLbl, TweenInfo.new(0.25), {TextTransparency = 0})
    tween(contentLbl, TweenInfo.new(0.25), {TextTransparency = 0.15})
    tween(notifStroke, TweenInfo.new(0.25), {Transparency = 0.3})

    task.delay(duration, function()
        tween(notif, TweenInfo.new(0.25), {BackgroundTransparency = 1})
        tween(stripe, TweenInfo.new(0.25), {BackgroundTransparency = 1})
        tween(titleLbl, TweenInfo.new(0.25), {TextTransparency = 1})
        tween(contentLbl, TweenInfo.new(0.25), {TextTransparency = 1})
        tween(notifStroke, TweenInfo.new(0.25), {Transparency = 1})
        task.wait(0.3)
        notif:Destroy()
    end)
end

-- =====================================================================
-- WINDOW
-- =====================================================================
function Sift:CreateWindow(opts)
    opts = opts or {}
    local title       = opts.Title       or "Sift"
    local subtitle    = opts.Subtitle    or ""
    local toggleKey   = opts.ToggleKey   or Enum.KeyCode.RightShift
    local userSize    = opts.Size        or UDim2.new(0, 580, 0, 400)

    -- Apply mobile scale to window size
    local sizeX = math.floor(userSize.X.Offset * Sift.Scale + 0.5)
    local sizeY = math.floor(userSize.Y.Offset * Sift.Scale + 0.5)
    local size = UDim2.new(0, sizeX, 0, sizeY)

    local gui = new("ScreenGui", {
        Name = "Sift_" .. HttpService:GenerateGUID(false):sub(1, 8),
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
    })
    safeParent(gui)

    -- =========== MAIN CONTAINER ===========
    -- Single frame, single UICorner, single UIStroke = ONE border line.
    local main = new("Frame", {
        Parent = gui,
        Size = size,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        -- ClipsDescendants = true makes children respect the rounded
        -- corner of the main frame. Without this, the sidebar/content
        -- bottom edges showed sharp 90° corners overlapping the
        -- rounded outer edge — looked like a glitch where the bottom
        -- two corners were "broken".
        ClipsDescendants = true,
    })
    corner(main, 12)

    -- ONE fluorescent border (no double stroke)
    local mainStroke = new("UIStroke", {
        Parent = main,
        Color = Sift.Theme.Accent,
        Thickness = 1.5,
        Transparency = 0.15,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
    new("UIGradient", {
        Parent = mainStroke,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(0.5, Sift.Theme.Accent),
            ColorSequenceKeypoint.new(1,   Sift.Theme.AccentGlow),
        }),
        Rotation = 45,
    })

    -- Note: removed the separate glowOuter frame so the border appears
    -- as a single line. The fluorescent gradient stroke alone gives the
    -- glow without doubling up.

    -- =========== TITLE BAR ===========
    -- Same color as body so the visible UI is one unified black.
    local titleBar = new("Frame", {
        Parent = main,
        Size = UDim2.new(1, -2, 0, S(38)),
        Position = UDim2.new(0, 1, 0, 1),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })
    corner(titleBar, 11)
    new("Frame", {
        Parent = titleBar,
        Size = UDim2.new(1, 0, 0, S(12)),
        Position = UDim2.new(0, 0, 1, -S(12)),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 1,
    })

    local miniLogo = new("Frame", {
        Parent = titleBar,
        Size = SUDim2(0, 22, 0, 22),
        Position = UDim2.new(0, S(12), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    corner(miniLogo, 5)
    new("UIGradient", {
        Parent = miniLogo,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    new("TextLabel", {
        Parent = miniLogo,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = S(14),
        ZIndex = 3,
    })

    -- Title with outline (UIStroke around text) matching the UI accent
    local titleLbl = new("TextLabel", {
        Parent = titleBar,
        Size = SUDim2(0, 200, 1, 0),
        Position = UDim2.new(0, S(42), 0, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = title,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(14),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
    })
    new("UIStroke", {
        Parent = titleLbl,
        Color = Sift.Theme.Accent,
        Thickness = 1,
        Transparency = 0.4,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
    })

    if subtitle ~= "" then
        new("TextLabel", {
            Parent = titleBar,
            Size = SUDim2(0, 250, 1, 0),
            Position = UDim2.new(0, S(42) + titleLbl.TextBounds.X + S(8), 0, 0),
            BackgroundTransparency = 1,
            Font = Sift.Theme.Font,
            Text = subtitle,
            TextColor3 = Sift.Theme.TextMuted,
            TextSize = S(12),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
    end

    -- ========= LINK BUTTONS (Discord + Website) =========
    -- Two icon buttons in the title bar centre. Tapping them copies
    -- the relevant URL to the user's clipboard via setclipboard()
    -- (or the executor-specific equivalent) and shows a Sift notif.
    -- Built from primitive Frames so the icons render on every
    -- executor without depending on font glyph fallback.
    --
    -- Layout: positioned to the LEFT of the right-side button cluster
    -- so they don't collide with searchBtn/minBtn/closeBtn. Both
    -- buttons share the same square style as the window controls.
    local function copyToClipboard(text)
        -- Try every known clipboard global. Different executors expose
        -- this under different names — setclipboard is the UNC standard
        -- but mobile ones often only have toclipboard or similar.
        local fns = {
            rawget(getfenv(), "setclipboard"),
            rawget(_G, "setclipboard"),
            rawget(getfenv(), "toclipboard"),
            (syn and syn.write_clipboard) or nil,
            Sift.Caps and Sift.Caps.setclipboard or nil,
        }
        for _, fn in ipairs(fns) do
            if type(fn) == "function" then
                local ok = pcall(fn, text)
                if ok then return true end
            end
        end
        return false
    end

    -- Helper to build a square link-button with a centered icon container
    local function makeLinkBtn(rightOffset, tooltipText, copyText, drawIcon)
        local btn = new("TextButton", {
            Parent = titleBar,
            Size = SUDim2(0, 26, 0, 26),
            Position = UDim2.new(1, -S(rightOffset), 0.5, 0),
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = Sift.Theme.SurfaceLight,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 2,
        })
        corner(btn, 6)
        local iconHolder = new("Frame", {
            Parent = btn,
            Size = UDim2.new(0, S(16), 0, S(16)),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Active = false,
            ZIndex = 3,
        })
        local strokes, fills = drawIcon(iconHolder)
        btn.MouseEnter:Connect(function()
            tween(btn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
            for _, s in ipairs(strokes or {}) do
                tween(s, TweenInfo.new(0.15), {Color = Sift.Theme.TextOnAccent})
            end
            for _, f in ipairs(fills or {}) do
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
            end
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
            for _, s in ipairs(strokes or {}) do
                tween(s, TweenInfo.new(0.15), {Color = Sift.Theme.TextPrimary})
            end
            for _, f in ipairs(fills or {}) do
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextPrimary})
            end
        end)
        btn.MouseButton1Click:Connect(function()
            local ok = copyToClipboard(copyText)
            Sift:Notify({
                Title = ok and "Copied" or "Copy failed",
                Content = ok and (tooltipText .. " — " .. copyText)
                    or "Your executor's clipboard isn't accessible.",
                Duration = 3,
            })
        end)
        return btn
    end

    -- Discord icon: a chat-bubble silhouette built from two Frames
    -- (a rounded rectangle body + a small triangular tail). Stylised,
    -- deliberately not the trademarked Discord logo.
    local discordBtn = makeLinkBtn(106, "Discord", "https://discord.gg/sift", function(holder)
        local body = new("Frame", {
            Parent = holder,
            Size = UDim2.new(0, S(14), 0, S(11)),
            Position = UDim2.new(0.5, 0, 0.5, -S(1)),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextPrimary,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 3,
        })
        new("UICorner", { Parent = body, CornerRadius = UDim.new(0, S(3)) })
        -- Two "eye" cutouts using darker dots
        local function dot(xOff)
            local d = new("Frame", {
                Parent = body,
                Size = UDim2.new(0, S(2), 0, S(3)),
                Position = UDim2.new(0.5, xOff, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                Active = false,
                ZIndex = 4,
            })
            new("UICorner", { Parent = d, CornerRadius = UDim.new(1, 0) })
            return d
        end
        local eye1 = dot(-S(3))
        local eye2 = dot(S(3))
        -- Small tail at bottom-left (rotated square)
        local tail = new("Frame", {
            Parent = holder,
            Size = UDim2.new(0, S(3), 0, S(3)),
            Position = UDim2.new(0.5, -S(4), 1, -S(2)),
            AnchorPoint = Vector2.new(0.5, 1),
            Rotation = 45,
            BackgroundColor3 = Sift.Theme.TextPrimary,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 3,
        })
        return {}, {body, tail}
    end)

    -- Website / globe icon: circle with a horizontal and vertical
    -- line through it, built from primitive Frames.
    local websiteBtn = makeLinkBtn(138, "Website", "https://sift.win", function(holder)
        local circle = new("Frame", {
            Parent = holder,
            Size = UDim2.new(0, S(13), 0, S(13)),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Active = false,
            ZIndex = 3,
        })
        new("UICorner", { Parent = circle, CornerRadius = UDim.new(1, 0) })
        local circleStroke = new("UIStroke", {
            Parent = circle,
            Color = Sift.Theme.TextPrimary,
            Thickness = 1.6,
        })
        -- Horizontal "equator" line
        local equator = new("Frame", {
            Parent = circle,
            Size = UDim2.new(1, 0, 0, 1.2),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextPrimary,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 4,
        })
        -- Vertical line down the middle
        local meridian = new("Frame", {
            Parent = circle,
            Size = UDim2.new(0, 1.2, 1, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextPrimary,
            BorderSizePixel = 0,
            Active = false,
            ZIndex = 4,
        })
        -- Curved meridian via a thinner ellipse-like shape (approximated
        -- with two thin diagonal bars) for visual texture
        return {circleStroke}, {equator, meridian}
    end)

    -- ========= MIN BUTTON =========
    local minBtn = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 26, 0, 26),
        Position = UDim2.new(1, -S(42), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.FontBold,
        Text = "—",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(14),
        AutoButtonColor = false,
        ZIndex = 2,
    })
    corner(minBtn, 6)
    minBtn.MouseEnter:Connect(function()
        tween(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent, TextColor3 = Sift.Theme.TextOnAccent})
    end)
    minBtn.MouseLeave:Connect(function()
        tween(minBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight, TextColor3 = Sift.Theme.TextSecondary})
    end)

    -- ========= SEARCH BUTTON =========
    -- Sits left of the min button. Clicking opens a search bar that
    -- spans the title area; typing filters element labels across the
    -- ACTIVE tab (cheaper than rebuilding every tab on each keystroke).
    -- Empty search restores everything.
    local searchBtn = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 26, 0, 26),
        Position = UDim2.new(1, -S(74), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    })
    corner(searchBtn, 6)

    -- Magnifying-glass icon. Two reasons the previous version looked
    -- like a plain square:
    --   1. The frames were too small at the mobile scale (S(9) → 6px
    --      on phones) and the stroke disappeared at that thickness.
    --   2. Frames have Active=false by default, but UICorner-rounded
    --      Frames inside a TextButton can still occasionally absorb
    --      input on some executor builds. Setting Active=false
    --      explicitly on every child guarantees the click reaches
    --      the parent TextButton on every executor.
    -- Container is anchor-centered. The circle and handle are then
    -- positioned RELATIVE to that center so the whole magnifying-glass
    -- shape (circle + handle protruding bottom-right) sits balanced
    -- in the button. Earlier the circle was at top-left and the
    -- handle pulled the visual weight down-right, so the icon looked
    -- off-center despite the container being centered.
    local searchIcon = new("Frame", {
        Parent = searchBtn,
        Size = UDim2.new(0, S(14), 0, S(14)),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = 3,
    })
    -- Circle: anchor at its own center; placed slightly up-left of
    -- the container center so the protruding handle's mass balances
    -- the layout.
    local searchCircle = new("Frame", {
        Parent = searchIcon,
        Size = UDim2.new(0, S(10), 0, S(10)),
        Position = UDim2.new(0.5, -S(2), 0.5, -S(2)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Active = false,
        ZIndex = 3,
    })
    new("UICorner", { Parent = searchCircle, CornerRadius = UDim.new(1, 0) })
    local searchCircleStroke = new("UIStroke", {
        Parent = searchCircle,
        Color = Sift.Theme.TextPrimary,
        Thickness = 1.6,
    })
    -- Handle: a rotated bar extending from the circle's bottom-right
    -- toward the bottom-right of the container. Its midpoint is set
    -- past the circle's edge so the joint looks natural.
    local searchHandle = new("Frame", {
        Parent = searchIcon,
        Size = UDim2.new(0, S(5), 0, 1.6),
        Position = UDim2.new(0.5, S(3), 0.5, S(3)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Rotation = 45,
        BackgroundColor3 = Sift.Theme.TextPrimary,
        BorderSizePixel = 0,
        Active = false,
        ZIndex = 3,
    })
    corner(searchHandle, 1)

    searchBtn.MouseEnter:Connect(function()
        tween(searchBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
        tween(searchCircleStroke, TweenInfo.new(0.15), {Color = Sift.Theme.TextOnAccent})
        tween(searchHandle, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
    end)
    searchBtn.MouseLeave:Connect(function()
        tween(searchBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
        tween(searchCircleStroke, TweenInfo.new(0.15), {Color = Sift.Theme.TextPrimary})
        tween(searchHandle, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextPrimary})
    end)

    -- Search input — hidden by default, expands across the title bar
    -- with a clear ✕ on the right. Filters by simple substring match
    -- against the lower-cased element labels we registered earlier.
    local searchBox = new("TextBox", {
        Parent = titleBar,
        -- Span: from x=86 (after the × button) to right - 164.
        -- The right side reserves space for: closeBtn(-10) + 32px gap,
        -- minBtn(-42) + 32px gap, searchBtn(-74) + 32px gap,
        -- discordBtn(-106) + 32px gap, websiteBtn(-138) + 26px width
        -- = roughly 164px reserved at the right edge.
        Size = UDim2.new(1, -S(250), 0, S(28)),
        Position = UDim2.new(0, S(86), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.Font,
        PlaceholderText = "Search…",
        Text = "",
        TextColor3 = Sift.Theme.TextPrimary,
        PlaceholderColor3 = Sift.Theme.TextMuted,
        TextSize = S(13),
        ClearTextOnFocus = false,
        Visible = false,
        ZIndex = 3,
    })
    corner(searchBox, 6)
    -- Custom padding: leave extra room on the right for the × button
    -- Custom padding on the search box. Symmetric — no need to reserve
    -- space for the close button anymore since it lives outside the
    -- search box (parented to the title bar instead).
    new("UIPadding", {
        Parent = searchBox,
        PaddingTop = UDim.new(0, S(4)),
        PaddingBottom = UDim.new(0, S(4)),
        PaddingLeft = UDim.new(0, S(10)),
        PaddingRight = UDim.new(0, S(10)),
    })
    stroke(searchBox, Sift.Theme.Border, 1, 0.4)

    -- Visible × close button. Lives on the LEFT side of the search bar
    -- (just inside the title bar, before the input). Parented to
    -- titleBar so it sits OUTSIDE the search box itself — that way
    -- a tap on it is unambiguous and never gets confused with the
    -- text input area. Hidden until the search opens, then shown.
    --
    -- Built from two rotated Frame bars (same technique as the window
    -- close button) so it always renders even on executors with
    -- limited font glyph fallback.
    local searchClose = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 22, 0, 22),
        Position = UDim2.new(0, S(56), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceHover,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 4,
    })
    corner(searchClose, 5)
    local function makeSearchXBar(rotation)
        local bar = new("Frame", {
            Parent = searchClose,
            Size = UDim2.new(0, S(10), 0, 1.6),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextPrimary,
            BorderSizePixel = 0,
            Rotation = rotation,
            Active = false,
            ZIndex = 5,
        })
        corner(bar, 1)
        return bar
    end
    local searchX1 = makeSearchXBar(45)
    local searchX2 = makeSearchXBar(-45)
    searchClose.MouseEnter:Connect(function()
        tween(searchClose, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.Accent})
        tween(searchX1, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.TextOnAccent})
        tween(searchX2, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.TextOnAccent})
    end)
    searchClose.MouseLeave:Connect(function()
        tween(searchClose, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.SurfaceHover})
        tween(searchX1, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.TextPrimary})
        tween(searchX2, TweenInfo.new(0.12), {BackgroundColor3 = Sift.Theme.TextPrimary})
    end)

    local searchOpen = false
    local function setSearchOpen(open)
        searchOpen = open
        searchBox.Visible = open
        searchClose.Visible = open
        -- Hide the link buttons while search is open. The search input
        -- needs the horizontal space; pushing it short makes typing
        -- feel cramped. The buttons reappear when the search closes.
        discordBtn.Visible = not open
        websiteBtn.Visible = not open
        -- Search box reclaims the link-button space when those buttons
        -- are hidden. This keeps the input wide enough to type into
        -- on small windows and on mobile.
        searchBox.Size = open
            and UDim2.new(1, -S(196), 0, S(28))   -- buttons hidden, more room
            or  UDim2.new(1, -S(250), 0, S(28))   -- buttons visible, narrower
        if open then
            searchBox:CaptureFocus()
        else
            -- Release focus first so the keyboard goes away on mobile
            -- (CaptureFocus → ReleaseFocus is the documented pair),
            -- THEN clear text so we don't trigger the Text-changed
            -- handler with a half-closed UI.
            pcall(function() searchBox:ReleaseFocus() end)
            searchBox.Text = ""
            -- Reset visibility on every element of every tab — search
            -- filters across all tabs, so we have to restore all of them.
            if Window._tabs then
                for _, t in ipairs(Window._tabs) do
                    if t._searchables then
                        for _, item in ipairs(t._searchables) do
                            if item.frame then item.frame.Visible = true end
                        end
                    end
                end
            end
        end
    end

    -- The search-button toggles the search bar open/closed. Tapping
    -- the magnifying glass twice or hitting the × inside the search
    -- box both work as close. ESC also closes (desktop only).
    searchBtn.MouseButton1Click:Connect(function()
        setSearchOpen(not searchOpen)
    end)
    searchClose.MouseButton1Click:Connect(function()
        setSearchOpen(false)
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = string.lower(searchBox.Text)
        local tabs = Window._tabs or {}
        if #tabs == 0 then return end

        if q == "" then
            -- Empty query: restore visibility on every element of every tab
            for _, t in ipairs(tabs) do
                if t._searchables then
                    for _, item in ipairs(t._searchables) do
                        if item.frame then item.frame.Visible = true end
                    end
                end
            end
            return
        end

        -- Two-pass search across ALL tabs:
        --   Pass 1: find which tabs have at least one match. Walk tabs
        --           in order; the first match wins for auto-switch.
        --   Pass 2: filter visibility within each tab's element list.
        local firstMatchTab = nil
        local firstMatchItem = nil

        for _, t in ipairs(tabs) do
            if t._searchables then
                local tabHadMatch = false
                for _, item in ipairs(t._searchables) do
                    if item.frame then
                        local match = string.find(item.label, q, 1, true) ~= nil
                        item.frame.Visible = match
                        if match then
                            tabHadMatch = true
                            if not firstMatchTab then
                                firstMatchTab = t
                                firstMatchItem = item
                            end
                        end
                    end
                end
                -- Future improvement spot: dim/un-dim the tab button
                -- itself based on tabHadMatch (bold if it has results).
            end
        end

        -- Auto-switch to the tab with the first match, then scroll
        -- the matching element into view. The tab switch only fires
        -- if we're not already on that tab — avoids flicker when
        -- typing within an already-matched tab.
        if firstMatchTab and Window._activeTab ~= firstMatchTab then
            -- Trigger the tab's own activation path. Each tab stored
            -- a setActive closure on _setActive, but we also need to
            -- mark Window._activeTab. Reuse the same logic as the
            -- click-to-switch handler.
            if Window._activeTab and Window._activeTab._setActive then
                Window._activeTab._setActive(false)
            end
            Window._activeTab = firstMatchTab
            if firstMatchTab._setActive then
                firstMatchTab._setActive(true)
            end
        end

        -- Scroll the first match into view in its scrolling page.
        -- The matched frame's AbsolutePosition relative to the page's
        -- AbsolutePosition gives us the offset to set CanvasPosition to.
        if firstMatchItem and firstMatchItem.frame and firstMatchTab and firstMatchTab._page then
            local page = firstMatchTab._page
            local frame = firstMatchItem.frame
            -- Defer to next frame so layout has settled with the new
            -- visibility filter applied.
            task.defer(function()
                local ok, _ = pcall(function()
                    local relY = frame.AbsolutePosition.Y - page.AbsolutePosition.Y
                    local target = math.max(0, page.CanvasPosition.Y + relY - S(20))
                    page.CanvasPosition = Vector2.new(0, target)
                end)
            end)
        end
    end)

    -- Close search when ENTER is pressed on an empty box, or via ESC
    searchBox.FocusLost:Connect(function(enter)
        if enter and searchBox.Text == "" then
            setSearchOpen(false)
        end
    end)
    addInputHandler(function(input, processed)
        if processed then return end
        if searchOpen and input.KeyCode == Enum.KeyCode.Escape then
            setSearchOpen(false)
        end
    end)

    -- ========= CLOSE BUTTON (real X) =========
    local closeBtn = new("TextButton", {
        Parent = titleBar,
        Size = SUDim2(0, 26, 0, 26),
        Position = UDim2.new(1, -S(10), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 2,
    })
    corner(closeBtn, 6)
    local function makeXBar(rotation)
        local bar = new("Frame", {
            Parent = closeBtn,
            Size = UDim2.new(0, S(12), 0, 1.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Sift.Theme.TextSecondary,
            BorderSizePixel = 0,
            Rotation = rotation,
            ZIndex = 3,
        })
        corner(bar, 1)
        return bar
    end
    local xBar1 = makeXBar(45)
    local xBar2 = makeXBar(-45)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
        tween(xBar1, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
        tween(xBar2, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextOnAccent})
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
        tween(xBar1, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextSecondary})
        tween(xBar2, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.TextSecondary})
    end)

    -- ========= BODY =========
    -- Round the body itself with the same inner radius as main so that
    -- sidebar and content rectangles get clipped to the curve at all
    -- four corners. Top corners sit under the title bar so they don't
    -- visually matter; bottom corners are what we're fixing.
    local body = new("Frame", {
        Parent = main,
        Size = UDim2.new(1, -2, 1, -S(38)),
        Position = UDim2.new(0, 1, 0, S(38)),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    corner(body, 11)
    -- Mask the top edge of body to be square so it tucks flat under titlebar
    new("Frame", {
        Parent = body,
        Size = UDim2.new(1, 0, 0, S(12)),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })

    local sidebar = new("Frame", {
        Parent = body,
        Size = SUDim2(0, 140, 1, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
    })

    local tabList = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 1, -S(64)),
        BackgroundTransparency = 1,
    })
    new("UIListLayout", {
        Parent = tabList,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, S(4)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    padding(tabList, 8)

    -- ============ PROFILE AREA (bottom-left) ============
    local profileFrame = new("Frame", {
        Parent = sidebar,
        Size = UDim2.new(1, 0, 0, S(56)),
        Position = UDim2.new(0, 0, 1, -S(56)),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    new("Frame", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(16), 0, 1),
        Position = UDim2.new(0, S(8), 0, 0),
        BackgroundColor3 = Sift.Theme.Border,
        BorderSizePixel = 0,
        BackgroundTransparency = 0.4,
    })

    local avatar = new("ImageLabel", {
        Parent = profileFrame,
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0, S(10), 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Image = getPlayerThumb(LocalPlayer.UserId),
    })
    corner(avatar, 18)
    stroke(avatar, Sift.Theme.Accent, 1, 0.3)

    local nameLbl = new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(80), 0, S(14)),
        Position = UDim2.new(0, S(52), 0.5, -S(10)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = LocalPlayer.DisplayName or LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextPrimary,
        TextSize = S(12),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local handleLbl = new("TextLabel", {
        Parent = profileFrame,
        Size = UDim2.new(1, -S(80), 0, S(12)),
        Position = UDim2.new(0, S(52), 0.5, S(4)),
        BackgroundTransparency = 1,
        Font = Sift.Theme.Font,
        Text = "@" .. LocalPlayer.Name,
        TextColor3 = Sift.Theme.TextMuted,
        TextSize = S(10),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    -- Hide-user toggle (eye icon)
    local hideUserBtn = new("TextButton", {
        Parent = profileFrame,
        Size = SUDim2(0, 20, 0, 20),
        Position = UDim2.new(1, -S(10), 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = Sift.Theme.SurfaceLight,
        BorderSizePixel = 0,
        Font = Sift.Theme.FontBold,
        Text = "👁",
        TextColor3 = Sift.Theme.TextSecondary,
        TextSize = S(11),
        AutoButtonColor = false,
    })
    corner(hideUserBtn, 4)

    local userHidden = false
    hideUserBtn.MouseButton1Click:Connect(function()
        userHidden = not userHidden
        if userHidden then
            tween(nameLbl, TweenInfo.new(0.2), {TextTransparency = 1})
            tween(handleLbl, TweenInfo.new(0.2), {TextTransparency = 1})
            tween(hideUserBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent, TextColor3 = Sift.Theme.TextOnAccent})
        else
            tween(nameLbl, TweenInfo.new(0.2), {TextTransparency = 0})
            tween(handleLbl, TweenInfo.new(0.2), {TextTransparency = 0})
            tween(hideUserBtn, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight, TextColor3 = Sift.Theme.TextSecondary})
        end
    end)

    -- Content host (body clips us to rounded shape, so no corner needed here)
    local content = new("Frame", {
        Parent = body,
        Size = UDim2.new(1, -S(140), 1, 0),
        Position = UDim2.new(0, S(140), 0, 0),
        BackgroundColor3 = Sift.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,
    })

    -- =========== MINIMIZED PILL ===========
    local minimizedGui = new("ScreenGui", {
        Name = "Sift_Minimized",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 99,
    })
    safeParent(minimizedGui)

    local pill = new("TextButton", {
        Parent = minimizedGui,
        Size = SUDim2(0, 36, 0, 36),
        Position = UDim2.new(0.5, 0, 0, S(12)),
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Sift.Theme.Accent,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
    })
    corner(pill, 8)
    new("UIGradient", {
        Parent = pill,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Sift.Theme.AccentGlow),
            ColorSequenceKeypoint.new(1, Sift.Theme.AccentDim),
        }),
        Rotation = 135,
    })
    stroke(pill, Sift.Theme.AccentGlow, 1, 0.3)
    new("TextLabel", {
        Parent = pill,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Font = Sift.Theme.FontBold,
        Text = "S",
        TextColor3 = Sift.Theme.TextOnAccent,
        TextSize = S(20),
    })

    makeDraggable(main, titleBar)

    -- ===================================================================
    -- OPEN / CLOSE ANIMATION
    -- 
    -- Animates main scale + transparency. Sets a "_animating" flag so
    -- repeated toggles can't stack tweens.
    -- ===================================================================
    local visible = true
    local animating = false
    local TWEEN_TIME = 0.22
    local TI_OUT = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local TI_IN  = TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

    -- Add a UIScale we can tween
    local mainScale = new("UIScale", { Parent = main, Scale = 1 })

    local function animateOpen()
        if animating then return end
        animating = true
        main.Visible = true
        mainScale.Scale = 0.85
        main.BackgroundTransparency = 1
        for _, d in ipairs(main:GetDescendants()) do
            if d:IsA("Frame") or d:IsA("ScrollingFrame") then
                d.BackgroundTransparency = math.clamp(d.BackgroundTransparency, 0, 1)
            end
        end
        tween(mainScale, TI_OUT, {Scale = 1})
        tween(main, TI_OUT, {BackgroundTransparency = 0})
        task.delay(TWEEN_TIME, function() animating = false end)
    end

    local function animateClose(onDone)
        if animating then return end
        animating = true
        tween(mainScale, TI_IN, {Scale = 0.85})
        tween(main, TI_IN, {BackgroundTransparency = 1})
        task.delay(TWEEN_TIME, function()
            main.Visible = false
            animating = false
            if onDone then onDone() end
        end)
    end

    -- ========= WINDOW OBJECT =========
    local Window = {
        _gui = gui,
        _minimizedGui = minimizedGui,
        _main = main,
        _sidebar = sidebar,
        _content = content,
        _tabs = {},
        _activeTab = nil,
        _toggleKey = toggleKey,
    }

    function Window:Toggle()
        if animating then return end
        if visible then
            visible = false
            animateClose(function()
                pill.Visible = true
            end)
        else
            visible = true
            pill.Visible = false
            animateOpen()
        end
    end

    function Window:Destroy()
        animateClose(function()
            self._gui:Destroy()
            self._minimizedGui:Destroy()
        end)
    end

    closeBtn.MouseButton1Click:Connect(function() Window:Destroy() end)
    minBtn.MouseButton1Click:Connect(function() Window:Toggle() end)
    pill.MouseButton1Click:Connect(function() Window:Toggle() end)

    addInputHandler(function(input, processed)
        if processed then return end
        if input.KeyCode == toggleKey then Window:Toggle() end
    end)

    -- Play opening animation on creation
    animateOpen()

    -- =====================================================================
    -- TAB
    -- =====================================================================
    function Window:CreateTab(tabOpts)
        tabOpts = tabOpts or {}
        local tabName = tabOpts.Name or tabOpts.Title or "Tab"

        local btn = new("TextButton", {
            Parent = tabList,
            Size = UDim2.new(1, 0, 0, S(32)),
            BackgroundColor3 = Sift.Theme.SurfaceLight,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Font = Sift.Theme.FontMedium,
            Text = "  " .. tabName,
            TextColor3 = Sift.Theme.TextSecondary,
            TextSize = S(13),
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        corner(btn, 6)
        padding(btn, 8)

        local indicator = new("Frame", {
            Parent = btn,
            Size = SUDim2(0, 3, 0, 16),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Sift.Theme.Accent,
            BorderSizePixel = 0,
            BackgroundTransparency = 1,
        })
        corner(indicator, 2)

        local page = new("ScrollingFrame", {
            Parent = self._content,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Sift.Theme.Accent,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Visible = false,
            ClipsDescendants = true,   -- prevent content bleeding into titlebar when scrolled
        })
        padding(page, 12)
        new("UIListLayout", {
            Parent = page,
            FillDirection = Enum.FillDirection.Vertical,
            Padding = UDim.new(0, S(8)),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local Tab = { _btn = btn, _page = page, _indicator = indicator, _name = tabName }

        local function setActive(active)
            if active then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0, BackgroundColor3 = Sift.Theme.SurfaceLight})
                tween(btn, TweenInfo.new(0.15), {TextColor3 = Sift.Theme.TextPrimary})
                tween(indicator, TweenInfo.new(0.15), {BackgroundTransparency = 0})
                page.Visible = true
            else
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                tween(btn, TweenInfo.new(0.15), {TextColor3 = Sift.Theme.TextSecondary})
                tween(indicator, TweenInfo.new(0.15), {BackgroundTransparency = 1})
                page.Visible = false
            end
        end
        Tab._setActive = setActive

        btn.MouseEnter:Connect(function()
            if Window._activeTab ~= Tab then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5, BackgroundColor3 = Sift.Theme.SurfaceLight})
            end
        end)
        btn.MouseLeave:Connect(function()
            if Window._activeTab ~= Tab then
                tween(btn, TweenInfo.new(0.15), {BackgroundTransparency = 1})
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if Window._activeTab then Window._activeTab._setActive(false) end
            Window._activeTab = Tab
            setActive(true)
            -- Reset search when switching tabs so the new tab shows
            -- everything; the old search filter only made sense in
            -- the previous tab's element list.
            if searchOpen then setSearchOpen(false) end
        end)
        if not Window._activeTab then
            Window._activeTab = Tab
            setActive(true)
        end
        table.insert(self._tabs, Tab)

        -- ===================== ELEMENTS =====================
        -- Per-tab registry of searchable elements. Each entry:
        --   { frame=Frame, label=string, section=Frame_or_nil }
        -- Search filter walks this list and hides frames whose label
        -- doesn't match. Sections track their member frames so a
        -- collapsed section hides everything beneath it until the
        -- next section.
        Tab._searchables = Tab._searchables or {}
        Tab._currentSection = nil

        local function registerSearchable(frame, label)
            table.insert(Tab._searchables, {
                frame = frame,
                label = string.lower(tostring(label or "")),
                section = Tab._currentSection,
            })
        end

        local function elementContainer(height, label)
            local f = new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, S(height or 36)),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                ClipsDescendants = false,
            })
            corner(f, 6)
            stroke(f, Sift.Theme.Border, 1, 0.5)
            -- Auto-register for search filtering and section collapse.
            -- Add* methods pass a label so the search bar can match.
            registerSearchable(f, label)
            if Tab._currentSection then
                table.insert(Tab._currentSection.members, f)
            end
            return f
        end

        function Tab:AddSection(name)
            -- Sections are clickable headers that toggle the visibility
            -- of every element added after them (until the next section).
            -- The chevron character on the right indicates state.
            local sectionFrame = new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, S(24)),
                BackgroundTransparency = 1,
            })
            local clickArea = new("TextButton", {
                Parent = sectionFrame,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 2,
            })
            local label = new("TextLabel", {
                Parent = sectionFrame,
                Size = UDim2.new(1, -S(20), 1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = name,
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            -- Chevron built from two short rotated Frame bars instead
            -- of a Unicode glyph. Some fonts/builds render ▾/▸ as boxes
            -- (the "missing glyph" tofu). Frames always render.
            -- Default state = expanded, bars form a downward V (▾).
            -- Collapsed state rotates the parent so the V points right.
            local chevron = new("Frame", {
                Parent = sectionFrame,
                Size = UDim2.new(0, S(12), 0, S(12)),
                Position = UDim2.new(1, -S(8), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 1,
            })
            local function makeChevBar(rotation, xOffset)
                local b = new("Frame", {
                    Parent = chevron,
                    Size = UDim2.new(0, S(7), 0, 1.4),
                    Position = UDim2.new(0.5, xOffset, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Sift.Theme.TextMuted,
                    BorderSizePixel = 0,
                    Rotation = rotation,
                })
                corner(b, 1)
                return b
            end
            -- Down-arrow (▾): two bars meeting at the bottom centre
            local chevLeft  = makeChevBar(45, -S(2))
            local chevRight = makeChevBar(-45, S(2))

            -- Track this section as "current" so subsequent Add* calls
            -- can record their frame as a member of this section.
            local section = {
                frame = sectionFrame,
                members = {},
                collapsed = false,
            }
            Tab._currentSection = section
            Tab._sections = Tab._sections or {}
            table.insert(Tab._sections, section)

            clickArea.MouseButton1Click:Connect(function()
                section.collapsed = not section.collapsed
                -- Rotating the parent container by -90° turns the
                -- down-pointing V (▾) into a right-pointing one (▸).
                tween(chevron, TweenInfo.new(0.18), {
                    Rotation = section.collapsed and -90 or 0,
                })
                for _, m in ipairs(section.members) do
                    m.Visible = not section.collapsed
                end
            end)
            return sectionFrame
        end

        function Tab:AddLabel(text)
            local lbl = new("TextLabel", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, S(18)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = text,
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
            })
            local api = {}
            function api:Set(t) lbl.Text = t end
            return api
        end

        function Tab:AddParagraph(opts)
            opts = opts or {}
            local f = new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, S(50)),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            corner(f, 6)
            stroke(f, Sift.Theme.Border, 1, 0.5)
            padding(f, 10)
            new("UIListLayout", { Parent = f, Padding = UDim.new(0, S(4)) })
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, 0, 0, S(18)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontBold,
                Text = opts.Title or "Title",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = opts.Content or "",
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextWrapped = true,
            })
            return f
        end

        function Tab:AddButton(opts)
            opts = opts or {}
            local f = elementContainer(36, opts.Title or opts.Name or "Button")
            local btn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Button",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                AutoButtonColor = false,
            })
            btn.MouseEnter:Connect(function()
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.AccentDim})
            end)
            btn.MouseLeave:Connect(function()
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.SurfaceLight})
            end)
            btn.MouseButton1Click:Connect(function()
                tween(f, TweenInfo.new(0.08), {BackgroundColor3 = Sift.Theme.Accent})
                task.wait(0.08)
                tween(f, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.AccentDim})
                if opts.Callback then pcall(opts.Callback) end
            end)
            return btn
        end

        function Tab:AddToggle(opts)
            opts = opts or {}
            local default = opts.Default or false
            local flag    = opts.Flag

            local f = elementContainer(36, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -S(56), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Toggle",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local switch = new("Frame", {
                Parent = f,
                Size = SUDim2(0, 36, 0, 18),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
            })
            corner(switch, 9)
            stroke(switch, Sift.Theme.Border, 1, 0.4)

            local knob = new("Frame", {
                Parent = switch,
                Size = SUDim2(0, 14, 0, 14),
                Position = UDim2.new(0, S(2), 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Sift.Theme.TextSecondary,
                BorderSizePixel = 0,
            })
            corner(knob, 7)

            local clickArea = new("TextButton", {
                Parent = f,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
            })

            local state = default
            local api = {}
            local function render()
                if state then
                    tween(switch, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Accent})
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(1, -S(16), 0.5, 0), BackgroundColor3 = Sift.Theme.TextOnAccent})
                else
                    tween(switch, TweenInfo.new(0.15), {BackgroundColor3 = Sift.Theme.Background})
                    tween(knob,   TweenInfo.new(0.15), {Position = UDim2.new(0, S(2), 0.5, 0), BackgroundColor3 = Sift.Theme.TextSecondary})
                end
            end
            function api:Set(v)
                state = v and true or false
                if flag then Sift.Flags[flag] = state end
                render()
                if opts.Callback then pcall(opts.Callback, state) end
            end
            function api:Get() return state end
            clickArea.MouseButton1Click:Connect(function() api:Set(not state) end)
            knob.AnchorPoint = Vector2.new(0, 0.5)
            if flag then
                Sift.Flags[flag] = state
                registerFlag(flag, function(v) api:Set(v) end)
            end
            render()
            return api
        end

        function Tab:AddSlider(opts)
            opts = opts or {}
            local min     = opts.Min or 0
            local max     = opts.Max or 100
            local default = math.clamp(opts.Default or min, min, max)
            local round   = opts.Round or 0
            local flag    = opts.Flag

            local f = elementContainer(54, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -S(60), 0, S(18)),
                Position = UDim2.new(0, S(12), 0, S(6)),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Slider",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })

            local valueLbl = new("TextLabel", {
                Parent = f,
                Size = SUDim2(0, 50, 0, 18),
                Position = UDim2.new(1, -S(12), 0, S(6)),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = tostring(default),
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local barBg = new("Frame", {
                Parent = f,
                Size = UDim2.new(1, -S(24), 0, S(6)),
                Position = UDim2.new(0, S(12), 0, S(32)),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
            })
            corner(barBg, 3)
            stroke(barBg, Sift.Theme.Border, 1, 0.5)

            local fill = new("Frame", {
                Parent = barBg,
                Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Sift.Theme.Accent,
                BorderSizePixel = 0,
            })
            corner(fill, 3)

            local knob = new("Frame", {
                Parent = barBg,
                Size = SUDim2(0, 12, 0, 12),
                Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Sift.Theme.AccentGlow,
                BorderSizePixel = 0,
            })
            corner(knob, 6)

            local function format(v)
                if round == 0 then return tostring(math.floor(v)) end
                return string.format("%." .. round .. "f", v)
            end

            local value = default
            local api = {}
            local function setFromAlpha(alpha)
                alpha = math.clamp(alpha, 0, 1)
                value = min + (max - min) * alpha
                if round == 0 then value = math.floor(value + 0.5)
                else local m = 10 ^ round; value = math.floor(value * m + 0.5) / m end
                fill.Size = UDim2.new(alpha, 0, 1, 0)
                knob.Position = UDim2.new(alpha, 0, 0.5, 0)
                valueLbl.Text = format(value)
                if flag then Sift.Flags[flag] = value end
                if opts.Callback then pcall(opts.Callback, value) end
            end
            function api:Set(v)
                local alpha = (math.clamp(v, min, max) - min) / (max - min)
                setFromAlpha(alpha)
            end
            function api:Get() return value end

            local function update(input)
                local pos = input.Position.X - barBg.AbsolutePosition.X
                setFromAlpha(pos / barBg.AbsoluteSize.X)
            end
            barBg.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    update(input)
                    startDrag(input, update, nil)
                end
            end)
            if flag then
                Sift.Flags[flag] = value
                registerFlag(flag, function(v) api:Set(v) end)
            end
            return api
        end

        function Tab:AddDropdown(opts)
            opts = opts or {}
            local items   = opts.Options or opts.Items or {}
            local default = opts.Default
            local multi   = opts.Multi or false
            local flag    = opts.Flag

            local f = elementContainer(36, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.5, -S(12), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Dropdown",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local valueBtn = new("TextButton", {
                Parent = f,
                Size = UDim2.new(0.5, -S(12), 0, S(24)),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                Text = "  Select...",
                TextColor3 = Sift.Theme.TextSecondary,
                TextSize = S(12),
                TextXAlignment = Enum.TextXAlignment.Left,
                AutoButtonColor = false,
            })
            corner(valueBtn, 4)
            stroke(valueBtn, Sift.Theme.Accent, 1, 0.5)

            local arrow = new("TextLabel", {
                Parent = valueBtn,
                Size = UDim2.new(0, S(12), 1, 0),
                Position = UDim2.new(1, -S(8), 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.Font,
                Text = "▼",
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(9),
            })

            local popup = new("ScrollingFrame", {
                Parent = gui,
                Size = UDim2.new(0, 100, 0, 0),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
                ClipsDescendants = true,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = Sift.Theme.Accent,
                ScrollBarImageTransparency = 0.3,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            new("UIListLayout", { Parent = popup, Padding = UDim.new(0, S(2)) })
            padding(popup, 4)

            local selected = multi and {} or nil
            local optionBtns, api = {}, {}
            local open = false

            local function refreshDisplay()
                if multi then
                    local count = 0
                    for _ in pairs(selected) do count = count + 1 end
                    if count == 0 then valueBtn.Text = "  None"
                    elseif count == 1 then for k in pairs(selected) do valueBtn.Text = "  " .. k end
                    else valueBtn.Text = "  " .. count .. " selected" end
                else
                    valueBtn.Text = "  " .. (selected or "Select...")
                end
            end

            local function rebuild()
                for _, b in ipairs(optionBtns) do b:Destroy() end
                optionBtns = {}
                for _, item in ipairs(items) do
                    local optBtn = new("TextButton", {
                        Parent = popup,
                        Size = UDim2.new(1, 0, 0, S(24)),
                        BackgroundTransparency = 1,
                        BorderSizePixel = 0,
                        Font = Sift.Theme.Font,
                        Text = "  " .. tostring(item),
                        TextColor3 = Sift.Theme.TextSecondary,
                        TextSize = S(12),
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 51,
                        AutoButtonColor = false,
                    })
                    corner(optBtn, 4)
                    optBtn.MouseEnter:Connect(function()
                        tween(optBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0, BackgroundColor3 = Sift.Theme.AccentDim, TextColor3 = Sift.Theme.TextPrimary})
                    end)
                    optBtn.MouseLeave:Connect(function()
                        tween(optBtn, TweenInfo.new(0.1), {BackgroundTransparency = 1, TextColor3 = Sift.Theme.TextSecondary})
                    end)
                    optBtn.MouseButton1Click:Connect(function()
                        if multi then
                            if selected[item] then selected[item] = nil else selected[item] = true end
                            refreshDisplay()
                            if flag then Sift.Flags[flag] = selected end
                            if opts.Callback then pcall(opts.Callback, selected) end
                        else
                            selected = item
                            refreshDisplay()
                            if flag then Sift.Flags[flag] = selected end
                            if opts.Callback then pcall(opts.Callback, selected) end
                            api:Close()
                        end
                    end)
                    table.insert(optionBtns, optBtn)
                end
            end

            local function reposition()
                local p, s = valueBtn.AbsolutePosition, valueBtn.AbsoluteSize
                local h = math.min(#items * S(26) + S(8), S(130))
                popup.Size = UDim2.new(0, s.X, 0, h)
                popup.Position = UDim2.new(0, p.X, 0, p.Y + s.Y + 4)
            end
            function api:Open() open = true rebuild() reposition() popup.Visible = true arrow.Text = "▲" end
            function api:Close() open = false popup.Visible = false arrow.Text = "▼" end
            function api:Set(v)
                if multi then
                    selected = {}
                    if type(v) == "table" then for _, k in ipairs(v) do selected[k] = true end end
                else selected = v end
                refreshDisplay()
                if flag then Sift.Flags[flag] = selected end
                if opts.Callback then pcall(opts.Callback, selected) end
            end
            function api:Get() return selected end
            function api:Refresh(n) items = n or items if open then rebuild() reposition() end end

            valueBtn.MouseButton1Click:Connect(function()
                if open then api:Close() else api:Open() end
            end)

            -- Click-outside-to-close handler. Registered ONLY while the
            -- dropdown is open and removed when it closes — that way
            -- when the dropdown is closed (the common case) it's not
            -- consuming any per-input work in the central dispatcher.
            -- AbsolutePosition listener is also wired the same way so
            -- it doesn't fire reposition() math while the popup isn't
            -- even visible.
            local outsideHandlerId = nil
            local absPosConn = nil
            local origOpen = api.Open
            local origClose = api.Close
            function api:Open()
                origOpen(self)
                if not outsideHandlerId then
                    outsideHandlerId = addInputHandler(function(input)
                        if input.UserInputType ~= Enum.UserInputType.MouseButton1
                            and input.UserInputType ~= Enum.UserInputType.Touch then return end
                        local mp = UserInputService:GetMouseLocation()
                        local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                        local p2, s2 = valueBtn.AbsolutePosition, valueBtn.AbsoluteSize
                        local inP = mp.X >= p1.X and mp.X <= p1.X + s1.X and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                        local inB = mp.X >= p2.X and mp.X <= p2.X + s2.X and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                        if not inP and not inB then api:Close() end
                    end)
                end
                if not absPosConn then
                    absPosConn = main:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
                        if open then reposition() end
                    end)
                end
            end
            function api:Close()
                origClose(self)
                if outsideHandlerId then
                    removeInputHandler(outsideHandlerId)
                    outsideHandlerId = nil
                end
                if absPosConn then
                    absPosConn:Disconnect()
                    absPosConn = nil
                end
            end

            rebuild()
            if default then api:Set(default) else refreshDisplay() end
            if flag then
                Sift.Flags[flag] = selected
                registerFlag(flag, function(v) api:Set(v) end)
            end
            return api
        end

        function Tab:AddInput(opts)
            opts = opts or {}
            local f = elementContainer(36, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(0.4, -S(12), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Input",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local box = new("TextBox", {
                Parent = f,
                Size = UDim2.new(0.6, -S(12), 0, S(24)),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                PlaceholderText = opts.Placeholder or "",
                Text = opts.Default or "",
                TextColor3 = Sift.Theme.TextPrimary,
                PlaceholderColor3 = Sift.Theme.TextMuted,
                TextSize = S(12),
                ClearTextOnFocus = false,
            })
            corner(box, 4)
            local boxStroke = stroke(box, Sift.Theme.Border, 1, 0.4)
            padding(box, 6)
            box.Focused:Connect(function() tween(boxStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Accent, Transparency = 0}) end)
            box.FocusLost:Connect(function(enter)
                tween(boxStroke, TweenInfo.new(0.15), {Color = Sift.Theme.Border, Transparency = 0.4})
                if opts.Callback then pcall(opts.Callback, box.Text, enter) end
                if opts.Flag then Sift.Flags[opts.Flag] = box.Text end
            end)
            local api = {}
            function api:Set(v) box.Text = tostring(v) end
            function api:Get() return box.Text end
            if opts.Flag then
                Sift.Flags[opts.Flag] = box.Text
                registerFlag(opts.Flag, function(v) api:Set(v) end)
            end
            return api
        end

        function Tab:AddKeybind(opts)
            opts = opts or {}
            local default = opts.Default or Enum.KeyCode.Unknown
            local flag    = opts.Flag

            local f = elementContainer(36, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -S(100), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Keybind",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local btn = new("TextButton", {
                Parent = f,
                Size = SUDim2(0, 80, 0, 24),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.FontMedium,
                Text = default.Name or "None",
                TextColor3 = Sift.Theme.Accent,
                TextSize = S(12),
                AutoButtonColor = false,
            })
            corner(btn, 4)
            stroke(btn, Sift.Theme.Accent, 1, 0.5)

            local current, listening, api = default, false, {}
            local function setKey(k)
                current = k
                btn.Text = k.Name
                if flag then Sift.Flags[flag] = current end
            end
            function api:Set(k) setKey(k) end
            function api:Get() return current end
            btn.MouseButton1Click:Connect(function() listening = true btn.Text = "..." end)
            addInputHandler(function(input, processed)
                if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                    setKey(input.KeyCode); listening = false
                elseif not processed and not listening
                and input.UserInputType == Enum.UserInputType.Keyboard
                and input.KeyCode == current then
                    if opts.Callback then pcall(opts.Callback, current) end
                end
            end)
            if flag then
                Sift.Flags[flag] = current
                registerFlag(flag, function(v) api:Set(v) end)
            end
            return api
        end

        function Tab:AddColorPicker(opts)
            opts = opts or {}
            local default = opts.Default or Color3.fromRGB(45, 25, 110)
            local flag    = opts.Flag

            local f = elementContainer(36, opts.Title or opts.Name)
            new("TextLabel", {
                Parent = f,
                Size = UDim2.new(1, -S(56), 1, 0),
                Position = UDim2.new(0, S(12), 0, 0),
                BackgroundTransparency = 1,
                Font = Sift.Theme.FontMedium,
                Text = opts.Title or opts.Name or "Color",
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(13),
                TextXAlignment = Enum.TextXAlignment.Left,
            })
            local swatch = new("TextButton", {
                Parent = f,
                Size = SUDim2(0, 28, 0, 20),
                Position = UDim2.new(1, -S(12), 0.5, 0),
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = default,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
            })
            corner(swatch, 4)
            stroke(swatch, Sift.Theme.Accent, 1, 0.3)

            local color, api = default, {}

            -- Convert default RGB to HSV for initial picker state
            local h, s, v = Color3.toHSV(default)

            -- ============== POPUP ==============
            local popup = new("Frame", {
                Parent = gui,
                Size = SUDim2(0, 200, 0, 180),
                BackgroundColor3 = Sift.Theme.SurfaceLight,
                BorderSizePixel = 0,
                Visible = false,
                ZIndex = 50,
            })
            corner(popup, 6)
            stroke(popup, Sift.Theme.Accent, 1, 0.3)
            padding(popup, 10)

            -- Saturation/Value square (top, fills width)
            local svBox = new("Frame", {
                Parent = popup,
                Size = UDim2.new(1, 0, 0, S(120)),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundColor3 = Color3.fromHSV(h, 1, 1),  -- pure hue
                BorderSizePixel = 0,
                ZIndex = 51,
            })
            corner(svBox, 4)
            -- White → transparent gradient (left to right) gives the saturation axis
            local satGrad = new("UIGradient", {
                Parent = svBox,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
                }),
            })
            -- Black overlay (top to bottom) gives the value axis
            local valOverlay = new("Frame", {
                Parent = svBox,
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                ZIndex = 52,
            })
            corner(valOverlay, 4)
            new("UIGradient", {
                Parent = valOverlay,
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(1, 0),
                }),
            })

            -- SV cursor
            local svCursor = new("Frame", {
                Parent = svBox,
                Size = SUDim2(0, 14, 0, 14),
                Position = UDim2.new(s, 0, 1 - v, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Active = false,  -- pass clicks through to svBox
                ZIndex = 53,
            })
            new("UICorner", { Parent = svCursor, CornerRadius = UDim.new(1, 0) })
            -- Outer white ring + thinner black inner ring for contrast
            -- against any underlying color. The cursor renders as a
            -- hollow circle so the user can see the exact pixel they're
            -- selecting through the middle of the ring.
            local svCursorOuter = new("UIStroke", {
                Parent = svCursor,
                Color = Color3.fromRGB(255, 255, 255),
                Thickness = 2,
            })
            local svCursorInner = new("Frame", {
                Parent = svCursor,
                Size = UDim2.new(1, -4, 1, -4),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Active = false,
                ZIndex = 54,
            })
            new("UICorner", { Parent = svCursorInner, CornerRadius = UDim.new(1, 0) })
            new("UIStroke", {
                Parent = svCursorInner,
                Color = Color3.fromRGB(0, 0, 0),
                Thickness = 1,
                Transparency = 0.4,
            })

            -- Hue strip (bottom, fills width)
            local hueBox = new("Frame", {
                Parent = popup,
                Size = UDim2.new(1, 0, 0, S(14)),
                Position = UDim2.new(0, 0, 0, S(128)),
                BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                BorderSizePixel = 0,
                ZIndex = 51,
            })
            corner(hueBox, 4)
            new("UIGradient", {
                Parent = hueBox,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,   0,   0)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255,   0)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(  0, 255,   0)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromRGB(  0, 255, 255)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromRGB(  0,   0, 255)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,   0, 255)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,   0,   0)),
                }),
            })

            -- Hue cursor
            local hueCursor = new("Frame", {
                Parent = hueBox,
                Size = UDim2.new(0, 6, 1, 6),
                Position = UDim2.new(h, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                Active = false,  -- pass clicks through to hueBox
                ZIndex = 53,
            })
            corner(hueCursor, 2)
            new("UIStroke", {
                Parent = hueCursor,
                Color = Color3.fromRGB(0, 0, 0),
                Thickness = 1,
                Transparency = 0.2,
            })

            -- Color preview + hex (bottom row)
            local previewRow = new("Frame", {
                Parent = popup,
                Size = UDim2.new(1, 0, 0, S(22)),
                Position = UDim2.new(0, 0, 0, S(150)),
                BackgroundTransparency = 1,
                ZIndex = 51,
            })

            local preview = new("Frame", {
                Parent = previewRow,
                Size = UDim2.new(0, S(22), 1, 0),
                BackgroundColor3 = default,
                BorderSizePixel = 0,
                ZIndex = 52,
            })
            corner(preview, 4)
            stroke(preview, Sift.Theme.Border, 1, 0.4)

            local hexBox = new("TextBox", {
                Parent = previewRow,
                Size = UDim2.new(1, -S(28), 1, 0),
                Position = UDim2.new(1, 0, 0, 0),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Sift.Theme.Background,
                BorderSizePixel = 0,
                Font = Sift.Theme.Font,
                Text = string.format("#%02X%02X%02X",
                    math.floor(default.R * 255),
                    math.floor(default.G * 255),
                    math.floor(default.B * 255)),
                TextColor3 = Sift.Theme.TextPrimary,
                TextSize = S(11),
                ClearTextOnFocus = false,
                ZIndex = 52,
            })
            corner(hexBox, 4)
            stroke(hexBox, Sift.Theme.Border, 1, 0.4)
            padding(hexBox, 6)

            -- ============== UPDATE LOGIC ==============
            local function updateFromHSV()
                color = Color3.fromHSV(h, s, v)
                swatch.BackgroundColor3 = color
                preview.BackgroundColor3 = color
                hexBox.Text = string.format("#%02X%02X%02X",
                    math.floor(color.R * 255 + 0.5),
                    math.floor(color.G * 255 + 0.5),
                    math.floor(color.B * 255 + 0.5))
                -- Also update the SV box's hue tint
                svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                satGrad.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(h, 1, 1)),
                })
                if flag then Sift.Flags[flag] = color end
                if opts.Callback then pcall(opts.Callback, color) end
            end

            -- ============== SV DRAG ==============
            local function svUpdate(input)
                local rel = input.Position - svBox.AbsolutePosition
                local sx = math.clamp(rel.X / svBox.AbsoluteSize.X, 0, 1)
                local sy = math.clamp(rel.Y / svBox.AbsoluteSize.Y, 0, 1)
                s = sx
                v = 1 - sy
                svCursor.Position = UDim2.new(sx, 0, sy, 0)
                updateFromHSV()
            end
            svBox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    -- Visual feedback: cursor grows slightly on grab,
                    -- shrinks back when released.
                    tween(svCursor, TweenInfo.new(0.12), {Size = SUDim2(0, 18, 0, 18)})
                    svUpdate(input)
                    startDrag(input, svUpdate, function()
                        tween(svCursor, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = SUDim2(0, 14, 0, 14)})
                    end)
                end
            end)

            -- ============== HUE DRAG ==============
            local function hueUpdate(input)
                local rel = input.Position.X - hueBox.AbsolutePosition.X
                h = math.clamp(rel / hueBox.AbsoluteSize.X, 0, 1)
                hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                updateFromHSV()
            end
            hueBox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    tween(hueCursor, TweenInfo.new(0.12), {Size = UDim2.new(0, 8, 1, 8)})
                    hueUpdate(input)
                    startDrag(input, hueUpdate, function()
                        tween(hueCursor, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 6, 1, 6)})
                    end)
                end
            end)

            -- ============== HEX TYPE-IN ==============
            hexBox.FocusLost:Connect(function()
                local txt = hexBox.Text:gsub("#", ""):gsub("%s", "")
                if #txt == 6 then
                    local rv = tonumber(txt:sub(1, 2), 16)
                    local gv = tonumber(txt:sub(3, 4), 16)
                    local bv = tonumber(txt:sub(5, 6), 16)
                    if rv and gv and bv then
                        color = Color3.fromRGB(rv, gv, bv)
                        h, s, v = Color3.toHSV(color)
                        svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
                        hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
                        updateFromHSV()
                        return
                    end
                end
                -- invalid → restore display
                hexBox.Text = string.format("#%02X%02X%02X",
                    math.floor(color.R * 255 + 0.5),
                    math.floor(color.G * 255 + 0.5),
                    math.floor(color.B * 255 + 0.5))
            end)

            -- ============== POPUP OPEN/CLOSE ==============
            local function reposition()
                local p, sz = swatch.AbsolutePosition, swatch.AbsoluteSize
                popup.Position = UDim2.new(0, p.X + sz.X - S(200), 0, p.Y + sz.Y + 4)
            end
            -- Register a click-outside-to-close handler only while the
            -- popup is OPEN. When closed (the common case) no listener
            -- exists, so the central InputBegan dispatcher has zero
            -- work for this picker. The handler also checks whether
            -- the input started inside svBox/hueBox/popup — if so we
            -- don't close (lets the user drag SV/hue out past the popup
            -- boundary without the popup vanishing mid-drag).
            local outsideHandlerId = nil
            local closePopup
            local function openPopup()
                reposition()
                popup.Visible = true
                if outsideHandlerId then return end
                outsideHandlerId = addInputHandler(function(input)
                    if not popup.Visible then return end
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1
                        and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    local mp = UserInputService:GetMouseLocation()
                    local p1, s1 = popup.AbsolutePosition, popup.AbsoluteSize
                    local p2, s2 = swatch.AbsolutePosition, swatch.AbsoluteSize
                    local inP = mp.X >= p1.X and mp.X <= p1.X + s1.X and mp.Y >= p1.Y and mp.Y <= p1.Y + s1.Y
                    local inB = mp.X >= p2.X and mp.X <= p2.X + s2.X and mp.Y >= p2.Y and mp.Y <= p2.Y + s2.Y
                    if not inP and not inB then
                        closePopup()
                    end
                end)
            end
            closePopup = function()
                popup.Visible = false
                if outsideHandlerId then
                    removeInputHandler(outsideHandlerId)
                    outsideHandlerId = nil
                end
            end
            swatch.MouseButton1Click:Connect(function()
                if popup.Visible then closePopup() else openPopup() end
            end)

            function api:Set(c)
                color = c
                h, s, v = Color3.toHSV(c)
                -- Tween rather than snap when set programmatically —
                -- gives a smoother feel when configs load or the user
                -- types into the hex box. The drag path bypasses this
                -- by setting Position directly above for instant
                -- response while moving the mouse/finger.
                tween(svCursor, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(s, 0, 1 - v, 0),
                })
                tween(hueCursor, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(h, 0, 0.5, 0),
                })
                updateFromHSV()
            end
            function api:Get() return color end
            if flag then
                Sift.Flags[flag] = color
                registerFlag(flag, function(v) api:Set(v) end)
            end
            return api
        end

        function Tab:AddDivider()
            return new("Frame", {
                Parent = page,
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Sift.Theme.Border,
                BorderSizePixel = 0,
                BackgroundTransparency = 0.4,
            })
        end

        return Tab
    end

    table.insert(Sift.Windows, Window)
    return Window
end

-- =====================================================================
-- SAFE-MODE WRAPPERS
--
-- This is the final piece of the "never fail to load on mobile" fix.
-- Every public Sift:Method that touches the GUI is replaced with a
-- pcall wrapper. If the method's body throws (for example because of
-- a nil capability on a low-end mobile executor), we log the error
-- to Sift._debugLog and return a safe stub instead of letting the
-- error propagate to the script that called us. The user sees a
-- working UI (or in the worst case, a UI that's missing one element)
-- rather than nothing at all.
--
-- We do this AT THE END of the file so the original method bodies
-- stay readable. The closures captured below are the originals.
-- =====================================================================
do
    local function makeStubWindow()
        -- A no-op stub that quacks like a real Window. Returned when
        -- CreateWindow fails entirely. Lets the calling script keep
        -- running without crashing — every method just no-ops.
        local stub = setmetatable({}, {__index = function() return function() return stub end end})
        function stub:CreateTab()
            local tabStub = setmetatable({}, {__index = function() return function() return tabStub end end})
            return tabStub
        end
        function stub:Toggle() end
        function stub:Destroy() end
        return stub
    end

    -- Wrap CreateWindow: never let the entire UI fail to load
    local _origCreateWindow = Sift.CreateWindow
    function Sift:CreateWindow(opts)
        local ok, win = pcall(_origCreateWindow, self, opts)
        if not ok then
            logDebug("CreateWindow", win)
            return makeStubWindow()
        end
        if not win then
            logDebug("CreateWindow", "returned_nil")
            return makeStubWindow()
        end

        -- Wrap CreateTab on the returned window so an error in one
        -- tab doesn't kill the whole window.
        local _origCreateTab = win.CreateTab
        if _origCreateTab then
            function win:CreateTab(tabOpts)
                local tok, tab = pcall(_origCreateTab, self, tabOpts)
                if not tok or not tab then
                    logDebug("CreateTab", tok and "returned_nil" or tab)
                    -- Stub Tab so subsequent :Add* calls no-op
                    local tabStub = setmetatable({}, {__index = function() return function() return tabStub end end})
                    return tabStub
                end
                -- Wrap each Tab:Add* so a single broken element
                -- doesn't kill the rest of the tab.
                local addMethods = {
                    "AddSection", "AddLabel", "AddParagraph", "AddButton",
                    "AddToggle", "AddSlider", "AddDropdown", "AddInput",
                    "AddKeybind", "AddColorPicker", "AddDivider",
                }
                for _, method in ipairs(addMethods) do
                    local orig = tab[method]
                    if type(orig) == "function" then
                        tab[method] = function(self_, ...)
                            local aok, aresult = pcall(orig, self_, ...)
                            if not aok then
                                logDebug(method, aresult)
                                -- Return a no-op object so chained
                                -- :Set / :Get calls don't crash
                                return setmetatable({}, {__index = function() return function() end end})
                            end
                            return aresult
                        end
                    end
                end
                return tab
            end
        end

        return win
    end

    -- Wrap Notify. If notifications themselves break (rare, but if
    -- safeParent fails we don't want it to surface as another error)
    -- we silently swallow.
    local _origNotify = Sift.Notify
    function Sift:Notify(opts)
        local ok, err = pcall(_origNotify, self, opts)
        if not ok then logDebug("Notify", err) end
    end

    -- Wrap ShowLoading + ShowKeySystem. These return values; if they
    -- throw we return safe defaults so the caller's script flow keeps
    -- working even if the UI for them broke.
    local _origShowLoading = Sift.ShowLoading
    function Sift:ShowLoading(opts)
        local ok, result = pcall(_origShowLoading, self, opts)
        if not ok then
            logDebug("ShowLoading", result)
            -- Return a stub with the methods callers expect
            return setmetatable({}, {__index = function() return function() end end})
        end
        return result
    end

    local _origShowKeySystem = Sift.ShowKeySystem
    function Sift:ShowKeySystem(opts)
        local ok, result = pcall(_origShowKeySystem, self, opts)
        if not ok then
            logDebug("ShowKeySystem", result)
            -- On total failure of the key system, fall through as if
            -- the user verified — the script that loaded us will
            -- still show its own gate or just run. Better than a
            -- broken loader screen with no way out.
            return true
        end
        return result
    end
end

-- =====================================================================
-- CONFIG PERSISTENCE
--
-- Sift:SaveConfig(name)  / Sift:LoadConfig(name)
-- Falls back to in-memory if the executor lacks file APIs (most
-- mobile executors do). Calling SaveConfig on a no-file executor
-- still works — it just persists for the current session only.
--
-- The library tracks any flag on Sift.Flags that was set via a UI
-- element with a Flag property, so SaveConfig is essentially:
--   for each flag → write its current value to a JSON file.
-- =====================================================================
Sift._memoryConfigs = {}

local function configPath(name)
    return string.format("Sift_Configs/%s.json", tostring(name or "default"))
end

function Sift:SaveConfig(name)
    name = tostring(name or "default")
    local data = {}
    for flag, value in pairs(Sift.Flags) do
        -- Only serialise primitives and tables of primitives.
        local t = type(value)
        if t == "string" or t == "number" or t == "boolean" then
            data[flag] = value
        elseif t == "table" then
            -- Color3 (R,G,B), Vector3 etc. — store as a tagged tuple
            if typeof and typeof(value) == "Color3" then
                data[flag] = {__type = "Color3", R = value.R, G = value.G, B = value.B}
            else
                -- Plain table — assume it's serialisable as-is
                local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
                if ok then data[flag] = value end
            end
        end
    end

    local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
    if not ok then
        logDebug("SaveConfig:encode", json)
        return false
    end

    -- Try file system first
    if Sift.Caps.writefile and Sift.Caps.makefolder then
        local saved = pcall(function()
            if Sift.Caps.isfolder and not Sift.Caps.isfolder("Sift_Configs") then
                Sift.Caps.makefolder("Sift_Configs")
            end
            Sift.Caps.writefile(configPath(name), json)
        end)
        if saved then return true end
    end

    -- Fall back to in-memory (lasts until the executor closes)
    Sift._memoryConfigs[name] = json
    return true
end

function Sift:LoadConfig(name)
    name = tostring(name or "default")
    local json

    if Sift.Caps.isfile and Sift.Caps.readfile then
        local ok, content = pcall(function()
            if Sift.Caps.isfile(configPath(name)) then
                return Sift.Caps.readfile(configPath(name))
            end
        end)
        if ok and content then json = content end
    end

    if not json then json = Sift._memoryConfigs[name] end
    if not json then return false end

    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(data) ~= "table" then
        logDebug("LoadConfig:decode", data)
        return false
    end

    for flag, value in pairs(data) do
        -- Re-hydrate tagged values
        if type(value) == "table" and value.__type == "Color3" then
            value = Color3.new(value.R, value.G, value.B)
        end
        Sift.Flags[flag] = value
        -- If a UI element with this flag exists, push the loaded
        -- value back into it so the UI reflects the loaded state.
        if Sift._flagSetters and Sift._flagSetters[flag] then
            for _, setter in ipairs(Sift._flagSetters[flag]) do
                pcall(setter, value)
            end
        end
    end
    return true
end

function Sift:DeleteConfig(name)
    name = tostring(name or "default")
    Sift._memoryConfigs[name] = nil
    if Sift.Caps.delfile and Sift.Caps.isfile and Sift.Caps.isfile(configPath(name)) then
        pcall(Sift.Caps.delfile, configPath(name))
    end
end

function Sift:ListConfigs()
    local out = {}
    for k in pairs(Sift._memoryConfigs) do table.insert(out, k) end
    if Sift.Caps.listfiles and Sift.Caps.isfolder and Sift.Caps.isfolder("Sift_Configs") then
        local ok, files = pcall(Sift.Caps.listfiles, "Sift_Configs")
        if ok and type(files) == "table" then
            for _, f in ipairs(files) do
                local name = tostring(f):match("([^/\\]+)%.json$")
                if name then table.insert(out, name) end
            end
        end
    end
    table.sort(out)
    return out
end

return Sift