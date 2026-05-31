-- https://discord.gg/WCZghenRpw | kolenvlogger v1.25
local warn = warn or function() end

local _origPcall = pcall
local _origXpcall = xpcall
local _origError = error

local debugLibrary = debug
_G._VERSION = "Luau"
local setHook = debug.sethook
local getInfo = debug.getinfo
local getTraceback = debug.traceback
local loadFunction = load
local loadStringFunction = loadstring or load
local pcallFunction = pcall
local xpcallFunction = xpcall
local errorFunction = error
local typeFunction = type
local getMetatableFunction = getmetatable
local rawEqualFunction = rawequal
local toStringFunction = tostring
local toNumberFunction = tonumber
local ioLibrary = io
local osLibrary = os
local pairsFunction = pairs
local ipairsFunction = ipairs
local tableUnpackFunction = table.unpack or unpack
local proxyTable = {}
proxyTable.__index = proxyTable
local configuration = {
    MAX_DEPTH = 15,
    MAX_TABLE_ITEMS = 150,
    OUTPUT_FILE = "dumped_output.lua",
    VERBOSE = false,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 6.57,
    MAX_REPEATED_LINES = 8,
    MIN_DEOBF_LENGTH = 150,
    MAX_OUTPUT_SIZE = 6 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true
}
local inputKey = (arg and arg[3]) or "NoKey"
if arg and arg[3] then
    print("[Dumper] Auto-Input Key Detected: " .. toStringFunction(inputKey))
end
local dumperState = {
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
    ls_counter = 0
}
local _at = {
    mem          = {},
    tags         = {},
    sigs         = {},
    acts         = {},
    json         = {},
    enum         = {},
    svcCache     = {},
    typeOverride = {},
    connState    = {},
    debugIds     = {},
    debugIdCtr   = 0,
    instTags     = {},
    attrs        = {},
    children     = {},
    threadLike   = {},
    vectors      = {},
    buffers      = {},
    userdata     = {},
    localPlayer  = nil,
    weldRegistry = {},
    services     = {},
    folders      = {},
    files        = {},
    refBase      = {},
    metaHooks    = {},
    currentNamecallMethod = nil,
    inMetaHook   = false,
    pendingHeartbeat = {},
    locEntries = {},
    signalCallbacks = {},  -- AT5: live signal firing
    animateScript = nil,   -- AT3: getrunningscripts
}
setmetatable(_at.debugIds, {__mode = "k"})
setmetatable(_at.instTags, {__mode = "k"})
setmetatable(_at.attrs, {__mode = "k"})
setmetatable(_at.children, {__mode = "k"})
setmetatable(_at.threadLike, {__mode = "k"})
setmetatable(_at.vectors, {__mode = "k"})
setmetatable(_at.buffers, {__mode = "k"})
setmetatable(_at.userdata, {__mode = "k"})
setmetatable(_at.refBase, {__mode = "k"})
local function _getDebugId(p)
    if not _at.debugIds[p] then
        _at.debugIdCtr = _at.debugIdCtr + 1
        local n = _at.debugIdCtr
        _at.debugIds[p] = toStringFunction(n * 17 + 3) .. "-" .. toStringFunction(n * 97 + 11)
    end
    return _at.debugIds[p]
end
local function _removeChild(parent, child)
    local list = parent and _at.children[parent]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == child then table.remove(list, i) end
    end
end
local function _setParent(child, parent)
    local oldParent = dumperState.parent_map[child]
    if oldParent == parent then return end
    _removeChild(oldParent, child)
    dumperState.parent_map[child] = parent
    if parent then
        _at.children[parent] = _at.children[parent] or {}
        table.insert(_at.children[parent], child)
        -- skip signal firing for internal proxy types
        local childType = _at.typeOverride[child]
        local parentType = _at.typeOverride[parent]
        if childType == "RBXScriptSignal" or childType == "RBXScriptConnection"
        or parentType == "RBXScriptSignal" or parentType == "RBXScriptConnection" then
            return
        end
        -- fire ChildAdded on direct parent only
        if _at.signalCallbacks[parent] then
            for _, cb in ipairsFunction(_at.signalCallbacks[parent].ChildAdded or {}) do
                pcallFunction(cb, child)
            end
        end
        -- fire DescendantAdded on direct parent and its ancestors
        local ancestor = parent
        while ancestor do
            if _at.signalCallbacks[ancestor] then
                for _, cb in ipairsFunction(_at.signalCallbacks[ancestor].DescendantAdded or {}) do
                    pcallFunction(cb, child)
                end
            end
            ancestor = dumperState.parent_map[ancestor]
        end
    end
end
local function _isDescendantOf(child, parent)
    local cur = dumperState.parent_map[child]
    while cur do
        if cur == parent then return true end
        cur = dumperState.parent_map[cur]
    end
    return false
end
local function _getAllDescendants(root, out)
    out = out or {}
    for _, child in ipairsFunction(_at.children[root] or {}) do
        table.insert(out, child)
        _getAllDescendants(child, out)
    end
    return out
end
local numericArg = (arg and toNumberFunction(arg[4])) or (arg and toNumberFunction(arg[3])) or 123456789
local proxyMarker = {}
local function isProxyTable(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyMarker) == true end )
    return success and result
end
local function getProxyValue(target)
    if isProxyTable(target) then
        return rawget(target, "__value") or 0
    end
    return 0
end
local loadStringFunction = loadstring or load
local printFunction = print
local warnFunction = warn or function() end
local pairsFunction = pairs
local ipairsFunction = ipairs
local typeFunction = type
local toStringFunction = tostring
local proxyList = {}
local function isProxy(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyList) == true end )
    return success and result
end
local function getProxyId(target)
    if not isProxy(target) then
        return nil
    end
    return rawget(target, "__proxy_id")
end
local function processString(inputString)
    if typeFunction(inputString) ~= "string" then
        return '"'\n    end\n    local outputParts = {}\n    local currentIndex, totalLength = 1, #inputString\n    local function cleanEscapes(content)\n        return content:gsub( "\\\\(.)", function(escapedChar)\n            if escapedChar:match('[abfnrtv\\\\%\'%\\"%[%]0-9xu]') then
                return "" .. escapedChar
            end
            return escapedChar
        end )
    end
    local function stripLuauSyntax(rawCode)
        if not rawCode or rawCode == "" then
            return rawCode
        end
        rawCode = rawCode:gsub("\239\187\191", "")
        rawCode = rawCode:gsub("\r\n", "\n"):gsub("\r", "\n")
        rawCode = rawCode:gsub("\226\128\168", "\n"):gsub("\226\128\169", "\n")
        rawCode = rawCode:gsub("%-%-!%a+[^\n]*", "")
        rawCode = rawCode:gsub("([^\n]*)", function(line)
            if line:match("^%s*export%s+type%s+") or line:match("^%s*type%s+[%a_][%w_]*%s*=") then
                return "-- " .. line
            end
            return line
        end)
        rawCode = rawCode:gsub("local%s+([%a_][%w_]*)%s*<[%a_][%w_]*>%s*=", "local %1 =")
        rawCode = rawCode:gsub("(function%s+[%a_][%w_%.:]*)%s*<[^>\n%(]+>%s*%(", "%1(")
        rawCode = rawCode:gsub("([%(%s,])%.%.%.%s*:%s*[%a_][%w_%.]*%??", "%1...")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", "%1%2")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", "%1%2%3")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", ")")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", ")%1")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%s*%b<>%??", "")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%??", "")
        return rawCode
    end
    local function parseExpression(rawCode)
        if not rawCode or rawCode == '"' then\n            return ""\n        end\n        rawCode = stripLuauSyntax(rawCode)\n        rawCode = rawCode:gsub( "0[bB]([01_]+)", function(binaryString)\n            local cleanBinary = binaryString:gsub("_", "")\n            local decimalValue = toNumberFunction(cleanBinary, 2)\n            return decimalValue and toStringFunction(decimalValue) or "0"\n        end )\n        rawCode = rawCode:gsub( "0[xX]([%x_]+)", function(hexString)\n            local cleanHex = hexString:gsub("_", "")\n            return "0x" .. cleanHex\n        end )\n        while rawCode:match("%d_+%d") do\n            rawCode = rawCode:gsub("(%d)_+(%d)", "%1%2")\n        end\n        local operators = {{"+=", "+"}, {"-=", "-"}, {"*=", "*"}, {"/=", "/"}, {"%%=", "%%"}, {"%^=", "^"}, {"%.%.=", ".."}}\n        for _, opPair in ipairsFunction(operators) do\n            local operatorAssignment, operator = opPair[1], opPair[2]\n            rawCode = rawCode:gsub( "([%a_][%w_]*%b[])%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([%a_][%w_]*[%.%a_%d][%w_%.]*%.[%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([^%w_%.%]%):])([%a_][%w_]*)%s*" .. operatorAssignment, function(prefix, varName)\n                return prefix .. varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "^([%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n        end\n\n        rawCode = rawCode:gsub("([%a_][%w_]*%b[])%s*%+%+",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*%.[%w_%.]*[%w_])%s*%+%+","%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*)%s*%+%+",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%b[])",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%.[%w_%.]*[%w_])","%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*)",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+", "+")\n\n        rawCode = rawCode:gsub("([^%w_])continue([^%w_])", "%1__LC__()%2")\n        rawCode = rawCode:gsub("^continue([^%w_])", "__LC__()%1")\n        rawCode = rawCode:gsub("([^%w_])continue$", "%1__LC__()")\n        return rawCode\n    end\n    local function getBracketCount(index)\n        local count = 0\n        while index <= totalLength and inputString:byte(index) == 61 do\n            count = count + 1\n            index = index + 1\n        end\n        return count, index\n    end\n    local function findClosingBracket(startIndex, bracketCount)\n        local closingPattern = "]" .. string.rep("=", bracketCount) .. "]"\n        local start, finish = inputString:find(closingPattern, startIndex, true)\n        return finish or totalLength\n    end\n    local segmentStart = 1\n    while currentIndex <= totalLength do\n        local byteValue = inputString:byte(currentIndex)\n        if byteValue == 91 then\n            local bracketCount, nextIndex = getBracketCount(currentIndex + 1)\n            if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n                local startSegment = currentIndex\n                local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                currentIndex = endSegment\n                segmentStart = currentIndex + 1\n            end\n        elseif byteValue == 45 and currentIndex + 1 <= totalLength and inputString:byte(currentIndex + 1) == 45 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local startSegment = currentIndex\n            if currentIndex + 2 <= totalLength and inputString:byte(currentIndex + 2) == 91 then\n                local bracketCount, nextIndex = getBracketCount(currentIndex + 3)\n                if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                    local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                    table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                    currentIndex = endSegment\n                    segmentStart = currentIndex + 1\n                    currentIndex = currentIndex + 1\n                end\n            end\n            local lineBreak = inputString:find("\n", currentIndex + 2, true)\n            if lineBreak then\n                currentIndex = lineBreak\n            else\n                currentIndex = totalLength\n            end\n            table.insert(outputParts, inputString:sub(startSegment, currentIndex))\n            segmentStart = currentIndex + 1\n        elseif byteValue == 34 or byteValue == 39 or byteValue == 96 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local quoteType = byteValue\n            local startSegment = currentIndex\n            currentIndex = currentIndex + 1\n            while currentIndex <= totalLength do\n                local charByte = inputString:byte(currentIndex)\n                if charByte == 92 then\n                    currentIndex = currentIndex + 1\n                elseif charByte == quoteType then\n                    break\n                end\n                currentIndex = currentIndex + 1\n            end\n            local extractedContent = inputString:sub(startSegment + 1, currentIndex - 1)\n            extractedContent = cleanEscapes(extractedContent)\n            if quoteType == 96 then\n                table.insert(outputParts, '"' .. extractedContent:gsub('"', '\\\\"') .. '"')\n            else\n                local quoteChar = string.char(quoteType)\n                table.insert(outputParts, quoteChar .. extractedContent .. quoteChar)\n            end\n            segmentStart = currentIndex + 1\n        end\n        currentIndex = currentIndex + 1\n    end\n    table.insert(outputParts, parseExpression(inputString:sub(segmentStart)))\n    return table.concat(outputParts)\nend\nlocal function safeLoad(code, chunkName)\n    local loadedFunc, errorMessage = loadStringFunction(code, chunkName)\n    if loadedFunc then\n        return loadedFunc\n    end\n    printFunction("\n[CRITICAL ERROR] Failed to load script!")\n    printFunction("[LUA_LOAD_FAIL] " .. toStringFunction(errorMessage))\n    local errorLine = toNumberFunction(errorMessage:match(":(%d+):"))\n    local errorNear = errorMessage:match("near '([^']+)'")\n    if errorNear then\n        local foundIndex = code:find(errorNear, 1, true)\n        if foundIndex then\n            local startCtx = math.max(1, foundIndex - 50)\n            local endCtx = math.min(#code, foundIndex + 50)\n            printFunction("Context around error:")\n            printFunction("..." .. code:sub(startCtx, endCtx) .. "...")\n        end\n    end\n    local debugFile = ioLibrary.open("DEBUG_FAILED_TRANSPILE.lua", "w")\n    if debugFile then\n        debugFile:write(code)\n        debugFile:close()\n        printFunction("[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection")\n    end\n    return nil, errorMessage\nend\nlocal function emitOutput(data, isInline)\n    if dumperState.limit_reached then\n        return\n    end\n    if data == nil then\n        return\n    end\n    local indentPrefix = isInline and "" or string.rep("    ", dumperState.indent)\n    local lineString = indentPrefix .. toStringFunction(data)\n    local lineSize = #lineString + 1\n    if dumperState.current_size + lineSize > configuration.MAX_OUTPUT_SIZE then\n        dumperState.limit_reached = true\n        local warningMessage = "-- [CRITICAL] Dump stopped: File size exceeded 6MB limit."\n        table.insert(dumperState.output, warningMessage)\n        dumperState.current_size = dumperState.current_size + #warningMessage\n        errorFunction("DUMP_LIMIT_EXCEEDED")\n    end\n    if lineString == dumperState.last_emitted_line then\n        dumperState.repetition_count = dumperState.repetition_count + 1\n        if dumperState.repetition_count <= configuration.MAX_REPEATED_LINES then\n            table.insert(dumperState.output, lineString)\n            dumperState.current_size = dumperState.current_size + lineSize\n        elseif dumperState.repetition_count == configuration.MAX_REPEATED_LINES + 1 then\n            local suppressMessage = indentPrefix .. "-- [Repeated lines suppressed...]"\n            table.insert(dumperState.output, suppressMessage)\n            dumperState.current_size = dumperState.current_size + #suppressMessage\n        end\n    else\n        dumperState.last_emitted_line = lineString\n        dumperState.repetition_count = 0\n        table.insert(dumperState.output, lineString)\n        dumperState.current_size = dumperState.current_size + lineSize\n    end\n    if configuration.VERBOSE and dumperState.repetition_count <= 1 then\n        printFunction(lineString)\n    end\nend\nlocal function emitComment(data)\n    emitOutput("-- " .. toStringFunction(data or ""))\nend\nlocal function addEmptyLine()\n    dumperState.last_emitted_line = nil\n    table.insert(dumperState.output, "")\nend\nlocal function getFullOutput()\n    return table.concat(dumperState.output, "\n")\nend\nlocal function saveToFile(filePath)\n    local fileHandle = ioLibrary.open(filePath or configuration.OUTPUT_FILE, "w")\n    if fileHandle then\n        fileHandle:write(getFullOutput())\n        fileHandle:close()\n        return true\n    end\n    return false\nend\nlocal function formatValue(value)\n    if value == nil then\n        return "nil"\n    end\n    if typeFunction(value) == "string" then\n        return value\n    end\n    if typeFunction(value) == "number" or typeFunction(value) == "boolean" then\n        return toStringFunction(value)\n    end\n    if typeFunction(value) == "table" then\n        if dumperState.registry[value] then\n            return dumperState.registry[value]\n        end\n        if isProxy(value) then\n            local proxyId = getProxyId(value)\n            return proxyId and "proxy_" .. proxyId or "proxy"\n        end\n    end\n    local success, result = pcallFunction(toStringFunction, value)\n    return success and result or "unknown"\nend\nlocal function formatStringLiteral(value)\n    local rawValue = formatValue(value)\n    local escapedValue = rawValue:gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\n", "\n"):gsub("\\\r", "\\\\\r"):gsub("\\\t", "\\\\\t")\n    return '"' .. escapedValue .. '"'\nend\nlocal serviceNames = {\n    Players = "Players",\n    Workspace = "Workspace",\n    ReplicatedStorage = "ReplicatedStorage",\n    ServerStorage = "ServerStorage",\n    ServerScriptService = "ServerScriptService",\n    StarterGui = "StarterGui",\n    StarterPack = "StarterPack",\n    StarterPlayer = "StarterPlayer",\n    Lighting = "Lighting",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    RunService = "RunService",\n    UserInputService = "UserInputService",\n    TweenService = "TweenService",\n    GroupService = "GroupService",\n    AnimationClipProvider = "AnimationClipProvider",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    TeleportService = "TeleportService",\n    PathfindingService = "PathfindingService",\n    CollectionService = "CollectionService",\n    PhysicsService = "PhysicsService",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    GuiService = "GuiService",\n    HapticService = "HapticService",\n    VRService = "VRService",\n    CoreGui = "CoreGui",\n    Teams = "Teams",\n    InsertService = "InsertService",\n    DataStoreService = "DataStoreService",\n    MessagingService = "MessagingService",\n    TextService = "TextService",\n    TextChatService = "TextChatService",\n    NetworkClient = "NetworkClient",\n    ContentProvider = "ContentProvider",\n    Debris = "Debris",\n    MemStorageService = "MemStorageService",\n    ChangeHistoryService = "ChangeHistoryService",\n    PlayerEmulatorService = "PlayerEmulatorService",\n    StylingService = "StylingService",\n    ScriptContext = "ScriptContext",\n    LocalizationService = "LocalizationService",\n    PolicyService = "PolicyService",\n    CaptureService = "CaptureService",\n    AnalyticsService = "AnalyticsService",\n    EncodingService = "EncodingService",\n    CorePackages = "CorePackages",\n    RobloxReplicatedStorage = "RobloxReplicatedStorage",\n    RobloxGui = "RobloxGui",\n    AvatarEditorService = "AvatarEditorService",\n    SocialService = "SocialService",\n    VoiceChatService = "VoiceChatService",\n    AdService = "AdService",\n    GeometryService = "GeometryService",\n    AssetService = "AssetService",\n    LocalizationService = "LocalizationService",\n    NotificationService = "NotificationService",\n    ProcessInstancePhysicsService = "ProcessInstancePhysicsService",\n    FriendService = "FriendService",\n    SessionService = "SessionService",\n    TimerService = "TimerService",\n    TouchInputService = "TouchInputService",\n    GamepadService = "GamepadService",\n    KeyboardService = "KeyboardService",\n    MouseService = "MouseService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceService = "PerformanceService",\n    PlatformFriendService = "PlatformFriendService",\n    ReplicatedFirst = "ReplicatedFirst",\n    SpawnLocation = "SpawnLocation",\n    LogService = "LogService",\n    Stats = "Stats",\n    TweenService = "TweenService",\n    Debris = "Debris",\n    CoreGui = "CoreGui",\n    MarketplaceService = "MarketplaceService",\n    NotificationService = "NotificationService",\n    GuidRegistryService = "GuidRegistryService",\n    NetworkServer = "NetworkServer",\n    Geometry = "Geometry",\n    VirtualInputManager = "VirtualInputManager",\n    MLModelDeliveryService = "MLModelDeliveryService",\n    PartyEmulatorService = "PartyEmulatorService",\n    PlatformFriendsService = "PlatformFriendsService",\n    FriendService = "FriendService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceControlService = "PerformanceControlService",\n    RbxAnalyticsService = "RbxAnalyticsService",\n    AbuseReportService = "AbuseReportService",\n    AdService = "AdService",\n    AdPortalService = "AdPortalService",\n    AppUpdateService = "AppUpdateService",\n    BrowserService = "BrowserService",\n    CookiesService = "CookiesService",\n    CoreGui = "CoreGui",\n    GamesService = "GamesService",\n    KeyboardService = "KeyboardService",\n    MarketplaceService = "MarketplaceService",\n    MouseService = "MouseService",\n    NotificationService = "NotificationService",\n    PurchaseDataService = "PurchaseDataService",\n    TimerService = "TimerService",\n    UGCValidationService = "UGCValidationService",\n}\nlocal serviceShortcuts = {\n    Players = "Players",\n    UserInputService = "UIS",\n    RunService = "RunService",\n    ReplicatedStorage = "ReplicatedStorage",\n    TweenService = "TweenService",\n    Workspace = "Workspace",\n    Lighting = "Lighting",\n    StarterGui = "StarterGui",\n    CoreGui = "CoreGui",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    DataStoreService = "DataStoreService",\n    TeleportService = "TeleportService",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    Teams = "Teams",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    CollectionService = "CollectionService",\n    PathfindingService = "PathfindingService",\n    Debris = "Debris"\n}\nlocal classParents = {\n    DataModel = {"DataModel", "ServiceProvider", "Instance"},\n    Workspace = {"Workspace", "WorldRoot", "Model", "PVInstance", "Instance"},\n    Camera = {"Camera", "Instance"},\n    Players = {"Players", "Instance"},\n    Player = {"Player", "Instance"},\n    PlayerGui = {"PlayerGui", "BasePlayerGui", "Instance"},\n    Backpack = {"Backpack", "Instance"},\n    PlayerScripts = {"PlayerScripts", "Instance"},\n    Folder = {"Folder", "Instance"},\n    Model = {"Model", "PVInstance", "Instance"},\n    Part = {"Part", "BasePart", "PVInstance", "Instance"},\n    BasePart = {"BasePart", "PVInstance", "Instance"},\n    ModuleScript = {"ModuleScript", "LuaSourceContainer", "Instance"},\n    LocalScript = {"LocalScript", "Script", "LuaSourceContainer", "Instance"},\n    Script = {"Script", "LuaSourceContainer", "Instance"},\n    Humanoid = {"Humanoid", "Instance"},\n    SoundService = {"SoundService", "Instance"},\n    Lighting = {"Lighting", "Instance"},\n    HttpService = {"HttpService", "Instance"},\n    TweenService = {"TweenService", "Instance"},\n    RunService = {"RunService", "Instance"},\n    TextService = {"TextService", "Instance"},\n    GuiService = {"GuiService", "Instance"},\n    ContentProvider = {"ContentProvider", "Instance"},\n    CollectionService = {"CollectionService", "Instance"},\n    MemStorageService = {"MemStorageService", "Instance"},\n    NetworkClient = {"NetworkClient", "Instance"},\n    ClientReplicator = {"ClientReplicator", "Instance"},\n}\nlocal function classIsA(className, targetClass)\n    if className == targetClass then return true end\n    local parents = classParents[className] or {className, "Instance"}\n    for _, parentName in ipairsFunction(parents) do\n        if parentName == targetClass then return true end\n    end\n    return false\nend\nlocal uiNamingConvention = {\n    {pattern = "window", prefix = "Window", counter = "window"},\n    {pattern = "tab", prefix = "Tab", counter = "tab"},\n    {pattern = "section", prefix = "Section", counter = "section"},\n    {pattern = "button", prefix = "Button", counter = "button"},\n    {pattern = "toggle", prefix = "Toggle", counter = "toggle"},\n    {pattern = "slider", prefix = "Slider", counter = "slider"},\n    {pattern = "dropdown", prefix = "Dropdown", counter = "dropdown"},\n    {pattern = "textbox", prefix = "Textbox", counter = "textbox"},\n    {pattern = "input", prefix = "Input", counter = "input"},\n    {pattern = "label", prefix = "Label", counter = "label"},\n    {pattern = "keybind", prefix = "Keybind", counter = "keybind"},\n    {pattern = "colorpicker", prefix = "ColorPicker", counter = "colorpicker"},\n    {pattern = "paragraph", prefix = "Paragraph", counter = "paragraph"},\n    {pattern = "notification", prefix = "Notification", counter = "notification"},\n    {pattern = "divider", prefix = "Divider", counter = "divider"},\n    {pattern = "bind", prefix = "Bind", counter = "bind"},\n    {pattern = "picker", prefix = "Picker", counter = "picker"}\n}\nlocal uiCounters = {}\nlocal function getUiCounter(name)\n    uiCounters[name] = (uiCounters[name] or 0) + 1\n    return uiCounters[name]\nend\nlocal function resolveVariableName(obj, originalName, hintString)\n    if not obj then\n        obj = "var"\n    end\n    local formattedName = formatValue(obj)\n    if serviceShortcuts[formattedName] then\n        return serviceShortcuts[formattedName]\n    end\n    if hintString then\n        local lowerHint = hintString:lower()\n        for _, patternEntry in ipairsFunction(uiNamingConvention) do\n            if lowerHint:find(patternEntry.pattern) then\n                local counter = getUiCounter(patternEntry.counter)\n                return counter == 1 and patternEntry.prefix or patternEntry.prefix .. counter\n            end\n        end\n    end\n    if formattedName == "LocalPlayer" then\n        return "LocalPlayer"\n    end\n    if formattedName == "Character" then\n        return "Character"\n    end\n    if formattedName == "Humanoid" then\n        return "Humanoid"\n    end\n    if formattedName == "HumanoidRootPart" then\n        return "HumanoidRootPart"\n    end\n    if formattedName == "Camera" then\n        return "Camera"\n    end\n    if formattedName:match("^Enum%.") then\n        return formattedName\n    end\n    local sanitizedName = formattedName:gsub("[^%w_]", '"'):gsub("^%d+", '"')\n    if sanitizedName == '"' or sanitizedName == "Object" or sanitizedName == "Value" or sanitizedName == "result" then
        sanitizedName = "var"
    end
    return sanitizedName
end
local function registerVariable(obj, objName, varType, hintString)
    local existing = dumperState.registry[obj]
    if existing and existing:match("^v%d+$") then
        return existing
    end
    dumperState.ls_counter = (dumperState.ls_counter or 0) + 1
    local newName = "v" .. dumperState.ls_counter
    dumperState.names_used[newName] = true
    dumperState.registry[obj] = newName
    dumperState.reverse_registry[newName] = obj
    dumperState.variable_types[newName] = varType or typeFunction(obj)
    return newName
end
local function serializeValue(obj, depth, visited, allowInline)
    depth = depth or 0
    visited = visited or {}
    if depth > configuration.MAX_DEPTH then
        return "{ --[[max depth]] }"
    end
    local valueType = typeFunction(obj)
    if isProxyTable(obj) then
        local proxyValue = rawget(obj, "__value")
        return toStringFunction(proxyValue or 0)
    end
    if valueType == "table" and dumperState.registry[obj] then
        return dumperState.registry[obj]
    end
    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        if #obj > 100 and obj:match("^[A-Za-z0-9+/=]+$") then
            table.insert(dumperState.string_refs, {value = obj:sub(1, 50) .. "...", hint = "base64", full_length = #obj})
        elseif obj:match("https?://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "URL"})
        elseif obj:match("rbxasset://") or obj:match("rbxassetid://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "Asset"})
        end
        return formatStringLiteral(obj)
    elseif valueType == "number" then
        if obj ~= obj then
            return "0/0"
        end
        if obj == math.huge then
            return "math.huge"
        end
        if obj == -math.huge then
            return "-math.huge"
        end
        if obj == math.floor(obj) then
            return toStringFunction(math.floor(obj))
        end
        return string.format("%.6g", obj)
    elseif valueType == "boolean" then
        return toStringFunction(obj)
    elseif valueType == "function" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        return "function() end"
    elseif valueType == "table" then
        if isProxy(obj) then
            return dumperState.registry[obj] or "proxy"
        end
        if visited[obj] then
            return "{ --[[circular]] }"
        end
        visited[obj] = true
        local count = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                count = count + 1
            end
        end
        if count == 0 then
            return "{}"
        end
        local isSequence = true
        local maxIdx = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                if typeFunction(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    isSequence = false
                    break
                else
                    maxIdx = math.max(maxIdx, k)
                end
            end
        end
        isSequence = isSequence and maxIdx == count
        if isSequence and count <= 5 and allowInline ~= false then
            local items = {}
            for i = 1, count do
                local val = obj[i]
                if typeFunction(val) ~= "table" or isProxy(val) then
                    table.insert(items, serializeValue(val, depth + 1, visited, true))
                else
                    isSequence = false
                    break
                end
            end
            if isSequence and #items == count then
                return "{" .. table.concat(items, ", ") .. "}"
            end
        end
        local output = {}
        local itemCount = 0
        local indent = string.rep("    ", dumperState.indent + depth + 1)
        local baseIndent = string.rep("    ", dumperState.indent + depth)
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                itemCount = itemCount + 1
                if itemCount > configuration.MAX_TABLE_ITEMS then
                    table.insert(output, indent .. "-- ..." .. count - itemCount + 1 .. " more")
                    break
                end
                local keyStr
                if isSequence then
                    keyStr = nil
                elseif typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k, depth + 1, visited) .. "]"
                end
                local valStr = serializeValue(v, depth + 1, visited)
                if keyStr then
                    table.insert(output, indent .. keyStr .. " = " .. valStr)
                else
                    table.insert(output, indent .. valStr)
                end
            end
        end
        if #output == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(output, ",\n") .. "\n" .. baseIndent .. "}"
    elseif valueType == "userdata" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "userdata"
    elseif valueType == "thread" then
        return "coroutine.create(function() end)"
    else
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "nil"
    end
end
local proxyStore = {}
setmetatable(proxyStore, {__mode = "k"})
local function createProxy()
    local proxy = {}
    proxyStore[proxy] = true
    local meta = {}
    setmetatable(proxy, meta)
    return proxy, meta
end
local function isProxy(obj)
    return proxyStore[obj] == true
end
local createProxyObject
local createProxyMethod
-- ContentId type for AT6 (SurfaceAppearance.ColorMap etc)
local function _makeContentId(val)
    val = val or ""
    return setmetatable({_value = val}, {
        __typeof = "ContentId",
        __tostring = function() return val end,
        __eq = function(a, b)
            local av = typeFunction(a) == "table" and rawget(a, "_value") or a
            local bv = typeFunction(b) == "table" and rawget(b, "_value") or b
            return av == bv
        end,
        __index = function(t, k) if k == "_value" then return val end end,
    })
end
local _makeVector3
local _makeCFrame
local function createProxyInstance(bm)
    local proxy, meta = createProxy()
    rawset(proxy, proxyMarker, true)
    rawset(proxy, "__value", bm)
    dumperState.registry[proxy] = toStringFunction(bm)
    meta.__tostring = function() return toStringFunction(bm) end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" or key == proxyMarker or key == "__value" then
            return rawget(tbl, key)
        end
        return createProxyInstance(0)
    end
    meta.__newindex = function() end
    meta.__call = function() return bm end
    local function op(symbol)
        return function(a, b)
            local valA = typeFunction(a) == "table" and rawget(a, "__value") or a or 0
            local valB = typeFunction(b) == "table" and rawget(b, "__value") or b or 0
            local res
            if symbol == "+" then res = valA + valB
            elseif symbol == "-" then res = valA - valB
            elseif symbol == "*" then res = valA * valB
            elseif symbol == "/" then res = valB ~= 0 and valA / valB or 0
            elseif symbol == "%" then res = valB ~= 0 and valA % valB or 0
            elseif symbol == "^" then res = valA ^ valB
            else res = 0 end
            return createProxyInstance(res)
        end
    end
    meta.__add = op("+")
    meta.__sub = op("-")
    meta.__mul = op("*")
    meta.__div = op("/")
    meta.__mod = op("%")
    meta.__pow = op("^")
    meta.__unm = function(a) return createProxyInstance(-(rawget(a, "__value") or 0)) end
    meta.__eq = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA == valB
    end
    meta.__lt = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA < valB
    end
    meta.__le = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA <= valB
    end
    meta.__len = function() return 0 end
    return proxy
end
local function executeFunction(func, args)
    if typeFunction(func) ~= "function" then
        return {}
    end
    local outputCount = #dumperState.output
    local previousIteratorState = dumperState.pending_iterator
    dumperState.pending_iterator = false
    xpcallFunction( function() func(table.unpack(args or {})) end, function() end )
    while dumperState.pending_iterator do
        dumperState.indent = dumperState.indent - 1
        emitOutput("end")
        dumperState.pending_iterator = false
    end
    dumperState.pending_iterator = previousIteratorState
    local capturedLines = {}
    for i = outputCount + 1, #dumperState.output do
        table.insert(capturedLines, dumperState.output[i])
    end
    for i = #dumperState.output, outputCount + 1, -1 do
        table.remove(dumperState.output, i)
    end
    return capturedLines
end
createProxyMethod = function(methodName, parentProxy)
    local proxy, meta = createProxy()
    rawset(proxy, "__is_method", true)
    local parentName = dumperState.registry[parentProxy] or "object"
    local methodSignature = formatValue(methodName)
    dumperState.registry[proxy] = parentName .. "." .. methodSignature
    meta.__call = function(self, firstArg, ...)
        local args
        if firstArg == proxy or firstArg == parentProxy or isProxy(firstArg) then
            args = {...}
        else
            args = {firstArg, ...}
        end
        local lowerMethod = methodSignature:lower()
        local uiPrefix = nil
        for _, uiEntry in ipairsFunction(uiNamingConvention) do
            if lowerMethod:find(uiEntry.pattern) then
                uiPrefix = uiEntry.prefix
                break
            end
        end
        local callbackFunc, callbackKey, callbackIndex = nil, nil, nil
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "function" then
                callbackFunc = val
                break
            elseif typeFunction(val) == "table" and not isProxy(val) then
                for k, v in pairsFunction(val) do
                    local keyStr = toStringFunction(k):lower()
                    if keyStr == "callback" and typeFunction(v) == "function" then
                        callbackFunc = v
                        callbackKey = k
                        callbackIndex = i
                        break
                    end
                end
            end
        end
        local defaultParam, dummyArgs = "value", {}
        if callbackFunc then
            if lowerMethod:match("toggle") then
                defaultParam = "enabled"
                dummyArgs = {true}
            elseif lowerMethod:match("slider") then
                defaultParam = "value"
                dummyArgs = {50}
            elseif lowerMethod:match("dropdown") then
                defaultParam = "selected"
                dummyArgs = {"Option"}
            elseif lowerMethod:match("textbox") or lowerMethod:match("input") then
                defaultParam = "text"
                dummyArgs = {inputKey or "input"}
            elseif lowerMethod:match("keybind") or lowerMethod:match("bind") then
                defaultParam = "key"
                dummyArgs = {createProxyObject("Enum.KeyCode.E", false)}
            elseif lowerMethod:match("color") then
                defaultParam = "color"
                dummyArgs = {Color3.fromRGB(255, 255, 255)}
            elseif lowerMethod:match("button") then
                defaultParam = "\\"
                dummyArgs = {}
            end
        end
        local callbackLines = {}
        if callbackFunc then
            callbackLines = executeFunction(callbackFunc, dummyArgs)
        end
        local newProxy = createProxyObject(uiPrefix or methodSignature, false, parentProxy)
        local varName = registerVariable(newProxy, uiPrefix or methodSignature, nil, methodSignature)
        local argStrings = {}
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "table" and not isProxy(val) and i == callbackIndex then
                local tableParts = {}
                for k, v in pairsFunction(val) do
                    local keyStr
                    if typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. serializeValue(k) .. "]"
                    end
                    if k == callbackKey and #callbackLines > 0 then
                        local funcSignature = defaultParam ~= '"' and "function(" .. "bI" .. ")" or "function()"\n                        local indent = string.rep("    ", dumperState.indent + 2)\n                        local funcBody = {}\n                        for _, line in ipairsFunction(callbackLines) do\n                            table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))\n                        end\n                        local baseIndent = string.rep("    ", dumperState.indent + 1)\n                        table.insert(tableParts, keyStr .. " = " .. funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. baseIndent .. "end")\n                    elseif k == callbackKey then\n                        local funcDef = defaultParam ~= "\\" and "function(" .. defaultParam .. ") end" or "function() end"\n                        table.insert(tableParts, keyStr .. " = " .. funcDef)\n                    else\n                        table.insert(tableParts, keyStr .. " = " .. serializeValue(v))\n                    end\n                end\n                table.insert(argStrings, "{\n" .. string.rep("    ", dumperState.indent + 1) .. table.concat(tableParts, ",\n" .. string.rep("    ", dumperState.indent + 1)) .. "\n" .. string.rep("    ", dumperState.indent) .. "}")\n            elseif typeFunction(val) == "function" then\n                if #callbackLines > 0 then\n                    local funcSignature = defaultParam ~= '"' and "function(" .. defaultParam .. ")" or "function()"
                    local indent = string.rep("    ", dumperState.indent + 1)
                    local funcBody = {}
                    for _, line in ipairsFunction(callbackLines) do
                        table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))
                    end
                    table.insert(argStrings, funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. string.rep("    ", dumperState.indent) .. "end")
                else
                    local funcDef = defaultParam ~= '"' and "function(" .. defaultParam .. ") end" or "function() end"\n                    table.insert(argStrings, funcDef)\n                end\n            else\n                table.insert(argStrings, serializeValue(val))\n            end\n        end\n        emitOutput(string.format("local %s = %s:%s(%s)", varName, parentName, methodSignature, table.concat(argStrings, ", ")))\n        return newProxy\n    end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        return createProxyMethod(key, proxy)\n    end\n    meta.__tostring = function() return parentName .. ":" .. methodSignature end\n    meta.__index = function(tbl, key)\n        local chainName = (dumperState.registry[proxy] or methodSignature) .. "." .. tostring(key)\n        local childProxy = createProxyObject(key, false, nil)\n        dumperState.registry[childProxy] = chainName\n        local knownClassNames = {\n            SetBlockedUserIdsRequest = "RemoteEvent",\n            AtomicBinding = "BindableEvent",\n        }\n        if knownClassNames[key] then\n            dumperState.property_store[childProxy] = dumperState.property_store[childProxy] or {}\n            dumperState.property_store[childProxy]["ClassName"] = knownClassNames[key]\n        end\n        return childProxy\n    end\n    return proxy\nend\ncreateProxyObject = function(objName, isGlobal, parentProxy)\n    local proxy, meta = createProxy()\n    local formattedName = formatValue(objName)\n    dumperState.property_store[proxy] = {}\n    if isGlobal then\n        dumperState.registry[proxy] = formattedName\n        dumperState.names_used[formattedName] = true\n    elseif parentProxy then\n        _setParent(proxy, parentProxy)\n    end\n    local serviceMethods = {}\n    serviceMethods.GetService = function(self, serviceName)\n        local resolvedName = formatValue(serviceName)\n        -- strip null bytes (anti-tamper trick)\n        resolvedName = string.gsub(resolvedName, "%z", "")\n        if resolvedName == "Workspace" then\n            return workspace\n        end\n        if not serviceNames[resolvedName] or resolvedName == "DebuggerManager" then\n            errorFunction("Service not available", 0)\n        end\n        local serviceProxy = _at.svcCache[resolvedName]\n        if not serviceProxy then\n            serviceProxy = createProxyObject(resolvedName, false, self)\n            _at.svcCache[resolvedName] = serviceProxy\n            dumperState.parent_map[serviceProxy] = game\n            dumperState.property_store[serviceProxy] = dumperState.property_store[serviceProxy] or {}\n            dumperState.property_store[serviceProxy].ClassName = resolvedName\n            dumperState.property_store[serviceProxy].Name = resolvedName\n            if resolvedName == "CaptureService" then\n                _at.typeOverride[serviceProxy] = "Instance"\n            end\n            if resolvedName == "PlayerEmulatorService" then\n                dumperState.property_store[serviceProxy].PlayerEmulationEnabled = false\n            end\n            if resolvedName == "CorePackages" or resolvedName == "RobloxReplicatedStorage" or resolvedName == "RobloxGui" then\n                -- infinite deep proxy: any property path always returns a truthy proxy\n                local function _makeDeepProxy(name)\n                    local _dp = {}\n                    setmetatable(_dp, {\n                        __index = function(_, k)\n                            return _makeDeepProxy(name .. "." .. tostring(k))\n                        end,\n                        __tostring = function() return name end,\n                        __call = function(_, ...) return _makeDeepProxy(name .. "()") end,\n                        __len = function() return 0 end,\n                        __newindex = function() end,\n                    })\n                    return _dp\n                end\n                _at.typeOverride[serviceProxy] = "Instance"\n                dumperState.property_store[serviceProxy].__deepProxy = _makeDeepProxy(resolvedName)\n                local _dpMeta = debug and debug.getmetatable and debug.getmetatable(serviceProxy) or getmetatable(serviceProxy)\n                if type(_dpMeta) == "table" then\n                    local _prevDpIdx = _dpMeta.__index\n                    _dpMeta.__index = function(tbl, key)\n                        if key == proxyList or key == "__proxy_id" then return rawget(tbl, key) end\n                        local _dp = dumperState.property_store[serviceProxy] and dumperState.property_store[serviceProxy].__deepProxy\n                        if _dp then\n                            local function _makeDeepProxyInner(n)\n                                local d = {}\n                                setmetatable(d, {\n                                    __index = function(_, k) return _makeDeepProxyInner(n.."."..tostring(k)) end,\n                                    __tostring = function() return n end,\n                                    __call = function(_, ...) return _makeDeepProxyInner(n.."()") end,\n                                    __len = function() return 0 end,\n                                    __newindex = function() end,\n                                })\n                                return d\n                            end\n                            return _makeDeepProxyInner(resolvedName.."."..tostring(key))\n                        end\n                        if type(_prevDpIdx) == "function" then return _prevDpIdx(tbl, key) end\n                        if type(_prevDpIdx) == "table" then return _prevDpIdx[key] end\n                        return nil\n                    end\n                end\n            end\n        end\n        local varName = registerVariable(serviceProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "game"\n        emitOutput(string.format("local %s = %s:GetService(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return serviceProxy\n    end\n    serviceMethods.WaitForChild = function(self, childName, timeout)\n        if timeout ~= nil then\n            local t = toNumberFunction(timeout)\n            if t and t < 0 then\n                errorFunction("bad argument #2 to 'WaitForChild' (non-negative number expected, got " .. toStringFunction(t) .. ")", 2)\n            end\n        end\n        local resolvedName = formatValue(childName)\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if timeout then\n            emitOutput(string.format("local %s = %s:WaitForChild(%s, %s)", varName, parentPath, formatStringLiteral(resolvedName), serializeValue(timeout)))\n        else\n            emitOutput(string.format("local %s = %s:WaitForChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChild = function(self, childName, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local resolvedName = formatValue(childName)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                return child\n            end\n        end\n        if recursive then\n            for _, child in ipairsFunction(_getAllDescendants(self, {})) do\n                local props = dumperState.property_store[child] or {}\n                if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                    return child\n                end\n            end\n        end\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if recursive then\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s, true)", varName, parentPath, formatStringLiteral(resolvedName)))\n        else\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if cn == resolvedName then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    local _classInherits = {\n        Part = {"Part","BasePart","PVInstance","Instance"},\n        MeshPart = {"MeshPart","BasePart","PVInstance","Instance"},\n        UnionOperation = {"UnionOperation","BasePart","PVInstance","Instance"},\n        WedgePart = {"WedgePart","BasePart","PVInstance","Instance"},\n        SpecialMesh = {"SpecialMesh","DataModelMesh","Instance"},\n        Humanoid = {"Humanoid","Instance"},\n        LocalScript = {"LocalScript","BaseScript","LuaSourceContainer","Instance"},\n        Script = {"Script","BaseScript","LuaSourceContainer","Instance"},\n        ModuleScript = {"ModuleScript","LuaSourceContainer","Instance"},\n        Folder = {"Folder","Instance"},\n        Model = {"Model","PVInstance","Instance"},\n        Frame = {"Frame","GuiObject","GuiBase2d","Instance"},\n        TextLabel = {"TextLabel","TextBase","GuiObject","GuiBase2d","Instance"},\n        TextButton = {"TextButton","TextBase","GuiButton","GuiObject","GuiBase2d","Instance"},\n        TextBox = {"TextBox","TextBase","GuiObject","GuiBase2d","Instance"},\n        ImageLabel = {"ImageLabel","GuiObject","GuiBase2d","Instance"},\n        ImageButton = {"ImageButton","GuiButton","GuiObject","GuiBase2d","Instance"},\n        ScreenGui = {"ScreenGui","LayerCollector","GuiBase","Instance"},\n        RemoteEvent = {"RemoteEvent","Instance"},\n        RemoteFunction = {"RemoteFunction","Instance"},\n        BindableEvent = {"BindableEvent","Instance"},\n        BindableFunction = {"BindableFunction","Instance"},\n        LocalizationTable = {"LocalizationTable","Instance"},\n        Translator = {"Translator","Instance"},\n    }\n    local function _isA(childClass, targetClass)\n        if childClass == targetClass then return true end\n        local hierarchy = _classInherits[childClass]\n        if hierarchy then\n            for _, base in ipairsFunction(hierarchy) do\n                if base == targetClass then return true end\n            end\n        end\n        return false\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if _isA(cn, resolvedName) then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    serviceMethods.FindFirstAncestor = function(self, ancestorName)\n        local resolvedName = formatValue(ancestorName)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestor(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return {}\n    end\n    serviceMethods.GetDescendants = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("for _, obj in %s:GetDescendants() do", parentPath))\n        dumperState.indent = dumperState.indent + 1\n        local descProxy = createProxyObject("obj", false)\n        dumperState.registry[descProxy] = "obj"\n        dumperState.property_store[descProxy] = {Name = "Ball", ClassName = "Part", Size = Vector3.new(1, 1, 1)}\n        local yielded = false\n        return function()\n            if not yielded then\n                yielded = true\n                return 1, descProxy\n            else\n                dumperState.indent = dumperState.indent - 1\n                emitOutput("end")\n                return nil\n            end\n        end, nil, 0\n    end\n    serviceMethods.Clone = function(self)\n        local props = dumperState.property_store[proxy] or {}\n        if props.Archivable == false then return nil end\n        local parentPath = dumperState.registry[proxy] or "object"\n        local cloneProxy = createProxyObject((formattedName or "object") .. "Clone", false)\n        local varName = registerVariable(cloneProxy, (formattedName or "object") .. "Clone")\n        emitOutput(string.format("local %s = %s:Clone()", varName, parentPath))\n        dumperState.property_store[cloneProxy] = {}\n        for k, v in pairsFunction(props) do dumperState.property_store[cloneProxy][k] = v end\n        return cloneProxy\n    end\n    -- LocalizationTable entry store keyed by proxy\n    if not _at.locEntries then _at.locEntries = {} end\n    serviceMethods.SetEntries = function(self, entries)\n        _at.locEntries[proxy] = entries or {}\n    end\n    serviceMethods.GetEntries = function(self)\n        return _at.locEntries[proxy] or {}\n    end\n    serviceMethods.GetEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for _, e in ipairs(store) do\n            if e.Key == key then return e end\n        end\n        return nil\n    end\n    serviceMethods.RemoveEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for i, e in ipairs(store) do\n            if e.Key == key then table.remove(store, i) return end\n        end\n    end\n    serviceMethods.GetTranslator = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = locale or "en"}\n        return translator\n    end\n    serviceMethods.Destroy = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        -- recursively destroy all descendants first\n        local function destroyRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                destroyRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        destroyRec(proxy)\n        _setParent(proxy, nil)\n        if dumperState.property_store[proxy] then\n            dumperState.property_store[proxy].Parent = nil\n        end\n        emitOutput(string.format("%s:Destroy()", parentPath))\n    end\n    serviceMethods.ApplyAngularImpulse = function(self, impulse)\n        -- store impulse so AssemblyAngularVelocity returns something meaningful\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy]["_angularImpulse"] = impulse\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyAngularImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.ApplyImpulse = function(self, impulse)\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.GetPartBoundsInBox = function(self, cf, size, params)\n        -- return all workspace children that aren't in the exclude list\n        local excluded = {}\n        if params and typeFunction(params) == "table" and params.FilterDescendantsInstances then\n            for _, inst in ipairsFunction(params.FilterDescendantsInstances) do\n                excluded[inst] = true\n            end\n        end\n        local results = {}\n        -- walk workspace children from parent_map\n        for child, parent in pairsFunction(dumperState.parent_map) do\n            if parent == workspace and not excluded[child] then\n                table.insert(results, child)\n            end\n        end\n        return results\n    end\n    serviceMethods.GetPartBoundsInRadius = function(self, position, radius, params)\n        return serviceMethods.GetPartBoundsInBox(self, CFrame.new(position), Vector3.new(radius*2,radius*2,radius*2), params)\n    end\n    serviceMethods.ClearAllChildren = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        local function clearRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                clearRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        clearRec(proxy)\n        emitOutput(string.format("%s:ClearAllChildren()", parentPath))\n    end\n    serviceMethods.Connect = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        local signalName = signalPath:match("%.([^%.]+)$") or signalPath\n        -- AT5: store live callback for ChildAdded/DescendantAdded\n        local ownerProxy = (_at.signalOwner and _at.signalOwner[proxy]) or dumperState.parent_map[proxy] or proxy\n        if (signalName == "ChildAdded" or signalName == "DescendantAdded") and typeFunction(func) == "function" then\n            _at.signalCallbacks[ownerProxy] = _at.signalCallbacks[ownerProxy] or {}\n            _at.signalCallbacks[ownerProxy][signalName] = _at.signalCallbacks[ownerProxy][signalName] or {}\n            local cbList = _at.signalCallbacks[ownerProxy][signalName]\n            cbList[#cbList+1] = func\n            _at.connState[connectionProxy] = {list=cbList, func=func}\n        end\n        local args = {"..."}\n        if signalName:match("InputBegan") or signalName:match("InputEnded") or signalName:match("InputChanged") then\n            args = {"input", "gameProcessed"}\n        elseif signalName:match("CharacterAdded") or signalName:match("CharacterRemoving") then\n            args = {"character"}\n        elseif signalName:match("PlayerAdded") or signalName:match("PlayerRemoving") then\n            args = {"player"}\n        elseif signalName:match("Touched") then\n            args = {"hit"}\n        elseif signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n            args = {"deltaTime"}\n        elseif signalName:match("Stepped") then\n            args = {"time", "deltaTime"}\n        elseif signalName:match("Changed") then\n            args = {"property"}\n        elseif signalName:match("ChildAdded") or signalName:match("ChildRemoved") then\n            args = {"child"}\n        elseif signalName:match("DescendantAdded") or signalName:match("DescendantRemoving") then\n            args = {"descendant"}\n        elseif signalName:match("Died") or signalName:match("MouseButton") or signalName:match("Activated") then\n            args = {}\n        elseif signalName:match("FocusLost") then\n            args = {"enterPressed", "inputObject"}\n        end\n        emitOutput(string.format("local %s = %s:Connect(function(%s)", varName, signalPath, table.concat(args, ", ")))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            if signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n                -- use coroutine to defer so connectionProxy is returned first\n                -- meaning conn local in script is assigned before callbacks fire\n                local _connProxy = connectionProxy\n                local _co = coroutine.create(function()\n                    coroutine.yield() -- yield once, resumed after return connectionProxy\n                    local _dts = {\n                        0.016 + math.random()*0.003,\n                        0.014 + math.random()*0.003,\n                        0.017 + math.random()*0.003,\n                        0.013 + math.random()*0.003,\n                        0.015 + math.random()*0.003,\n                    }\n                    xpcallFunction(function()\n                        for i = 1, 5 do\n                            if _at.connState[_connProxy] == false then break end\n                            func(_dts[i])\n                        end\n                    end, function() end)\n                end)\n                coroutine.resume(_co)\n                -- store co to resume after return\n                _at.pendingHeartbeat = _at.pendingHeartbeat or {}\n                table.insert(_at.pendingHeartbeat, _co)\n            elseif signalName:match("Stepped") then\n                xpcallFunction( function() for i = 1, 5 do func(osLibrary.clock(), 0.015 + i * 0.001) end end, function() end )\n            elseif signalName:match("^Error$") then\n            elseif signalName == "ChildAdded" or signalName == "DescendantAdded"\n                or signalName == "ChildRemoved" or signalName == "DescendantRemoving" then\n                -- handled live via _setParent, don't fire immediately\n            else\n                xpcallFunction( function() func() end, function() end )\n            end\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Once = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:Once(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.ConnectParallel = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:ConnectParallel(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Wait = function(self)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local resultProxy = createProxyObject("waitResult", false)\n        local varName = registerVariable(resultProxy, "waitResult")\n        emitOutput(string.format("local %s = %s:Wait()", varName, signalPath))\n        return resultProxy\n    end\n    serviceMethods.Disconnect = function(self)\n        local connectionPath = dumperState.registry[proxy] or "connection"\n        -- remove live callback if registered\n        local state = _at.connState[proxy]\n        if typeFunction(state) == "table" and state.list and state.func then\n            for i = #state.list, 1, -1 do\n                if state.list[i] == state.func then table.remove(state.list, i) end\n            end\n        end\n        _at.connState[proxy] = false\n        emitOutput(string.format("%s:Disconnect()", connectionPath))\n    end\n    serviceMethods.FireServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        emitOutput(string.format("%s:FireServer(%s)", remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteEvent", name = remotePath, args = args})\n    end\n    serviceMethods.InvokeServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("invokeResult", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s:InvokeServer(%s)", varName, remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteFunction", name = remotePath, args = args})\n        return resultProxy\n    end\n    serviceMethods.Create = function(self, tweenTarget, tweenInfo, tweenProperties)\n        local servicePath = dumperState.registry[proxy] or "TweenService"\n        local tweenProxy = createProxyObject("tween", false)\n        local varName = registerVariable(tweenProxy, "tween")\n        emitOutput(string.format("local %s = %s:Create(%s, %s, %s)", varName, servicePath, serializeValue(tweenTarget), serializeValue(tweenInfo), serializeValue(tweenProperties)))\n        local function _tweenGetEnum(path)\n            if _at.enum[path] then return _at.enum[path] end\n            local ep = createProxyObject(path, false)\n            dumperState.registry[ep] = path\n            _at.typeOverride[ep] = "EnumItem"\n            _at.enum[path] = ep\n            return ep\n        end\n        local duration = 0\n        if tweenInfo then\n            local ps = dumperState.property_store[tweenInfo]\n            if ps and ps.Time then duration = toNumberFunction(ps.Time) or 0 end\n        end\n        dumperState.property_store[tweenProxy] = dumperState.property_store[tweenProxy] or {}\n        dumperState.property_store[tweenProxy].PlaybackState = _tweenGetEnum("Enum.PlaybackState.Begin")\n        dumperState.property_store[tweenProxy]._tweenDuration = duration\n        return tweenProxy\n    end\n    serviceMethods.GetValue = function(self, alpha, easingStyle, easingDirection)\n        alpha = toNumberFunction(alpha) or 0\n        if alpha < 0 then return 0 end\n        if alpha > 1 then return 1 end\n        if alpha > 0 and alpha < 1 then return 1.05 end\n        local styleText = formatValue(easingStyle)\n        local directionText = formatValue(easingDirection)\n        if styleText:find("Elastic", 1, true) then\n            if directionText:find("In", 1, true) and not directionText:find("Out", 1, true) then\n                return math.max(0, alpha * alpha)\n            end\n            return 1.05\n        end\n        return alpha\n    end\n    serviceMethods.Play = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Play()", tweenPath))\n        local store = dumperState.property_store[self]\n        if store then\n            local function _tweenGetEnum(path)\n                if _at.enum[path] then return _at.enum[path] end\n                local ep = createProxyObject(path, false)\n                dumperState.registry[ep] = path\n                _at.typeOverride[ep] = "EnumItem"\n                _at.enum[path] = ep\n                return ep\n            end\n            store.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Playing")\n            local dur = store._tweenDuration or 0\n            local tweenRef = self\n            if task and task.delay then\n                task.delay(dur, function()\n                    local s = dumperState.property_store[tweenRef]\n                    if s then\n                        s.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Completed")\n                    end\n                end)\n            end\n        end\n    end\n    serviceMethods.Pause = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Pause()", tweenPath))\n    end\n    serviceMethods.Cancel = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Cancel()", tweenPath))\n    end\n    serviceMethods.Stop = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Stop()", tweenPath))\n    end\n    serviceMethods.Raycast = function(self, origin, direction, params)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        local resultProxy = createProxyObject("raycastResult", false)\n        local varName = registerVariable(resultProxy, "rayResult")\n        if params then\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction), serializeValue(params)))\n        else\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction)))\n        end\n        return resultProxy\n    end\n    serviceMethods.BulkMoveTo = function(self, parts, targets, moveMode)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        emitOutput(string.format("%s:BulkMoveTo(%s, %s, %s)", workspacePath, serializeValue(parts), serializeValue(targets), serializeValue(moveMode)))\n        -- actually update each part's CFrame and Position in property_store\n        if typeFunction(parts) == "table" and typeFunction(targets) == "table" then\n            for i, part in ipairsFunction(parts) do\n                local cf = targets[i]\n                if part and cf and isProxy(part) then\n                    dumperState.property_store[part] = dumperState.property_store[part] or {}\n                    dumperState.property_store[part].CFrame = cf\n                    -- update Position from CFrame\n                    local px = (cf and cf.X) or 0\n                    local py = (cf and cf.Y) or 0\n                    local pz = (cf and cf.Z) or 0\n                    dumperState.property_store[part].Position = _makeVector3 and _makeVector3(px, py, pz) or Vector3.new(px, py, pz)\n                end\n            end\n        end\n    end\n    serviceMethods.GetMouse = function(self)\n        local playerPath = dumperState.registry[proxy] or "player"\n        local mouseProxy = createProxyObject("mouse", false)\n        local varName = registerVariable(mouseProxy, "mouse")\n        emitOutput(string.format("local %s = %s:GetMouse()", varName, playerPath))\n        return mouseProxy\n    end\n    serviceMethods.Kick = function(self, message)\n        local playerPath = dumperState.registry[proxy] or "player"\n        if message then\n            emitOutput(string.format("%s:Kick(%s)", playerPath, serializeValue(message)))\n        else\n            emitOutput(string.format("%s:Kick()", playerPath))\n        end\n    end\n    serviceMethods.GetPropertyChangedSignal = function(self, propertyName)\n        local prop = formatValue(propertyName)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        local signalProxy = createProxyObject(prop .. "Changed", false)\n        dumperState.registry[signalProxy] = instancePath .. ":GetPropertyChangedSignal(" .. formatStringLiteral(prop) .. ")"\n        _at.typeOverride[signalProxy] = "RBXScriptSignal"\n        return signalProxy\n    end\n    serviceMethods.IsA = function(self, class)\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName or formattedName\n        return classIsA(className or "Instance", class)\n    end\n    serviceMethods.IsDescendantOf = function(self, parent) return _isDescendantOf(proxy, parent) end\n    serviceMethods.IsAncestorOf = function(self, child) return _isDescendantOf(child, proxy) end\n    serviceMethods.GetAttribute = function(self, attr)\n        local attrs = _at.attrs[proxy]\n        return attrs and attrs[formatValue(attr)] or nil\n    end\n    serviceMethods.SetAttribute = function(self, attr, val)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        _at.attrs[proxy] = _at.attrs[proxy] or {}\n        _at.attrs[proxy][formatValue(attr)] = val\n        emitOutput(string.format("%s:SetAttribute(%s, %s)", instancePath, formatStringLiteral(attr), serializeValue(val)))\n    end\n    serviceMethods.GetAttributes = function(self) return _at.attrs[proxy] or {} end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return _at.children[proxy] or {}\n    end\n    serviceMethods.GetDescendants = function(self) return _getAllDescendants(proxy, {}) end\n    serviceMethods.FindFirstChild = function(self, name, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local targetName = formatValue(name)\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == targetName then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, class)\n        local targetClass = formatValue(class)\n        local props = dumperState.property_store[proxy] or {}\n        if targetClass == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if targetClass == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.ClassName == targetClass then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, class)\n        local props = dumperState.property_store[proxy] or {}\n        if class == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if class == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local childProps = dumperState.property_store[child] or {}\n            if classIsA(childProps.ClassName or "Instance", class) then return child end\n        end\n        return nil\n    end\n    serviceMethods.GetPlayers = function(self) return _at.localPlayer and {_at.localPlayer} or {} end\n    serviceMethods.GetPlayerFromCharacter = function(self, character)\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerFromCharacter(%s)", varName, playerPath, serializeValue(character)))\n        return playerProxy\n    end\n    serviceMethods.GetPlayerByUserId = function(self, userId)\n        if _at.localPlayer and userId == (dumperState.property_store[_at.localPlayer] or {}).UserId then\n            return _at.localPlayer\n        end\n        if userId == -999 then return nil end\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerByUserId(%s)", varName, playerPath, serializeValue(userId)))\n        return playerProxy\n    end\n    serviceMethods.SetCore = function(self, action, value)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCore(%s, %s)", guiPath, formatStringLiteral(action), serializeValue(value)))\n    end\n    serviceMethods.GetCore = function(self, action) return nil end\n    serviceMethods.SetCoreGuiEnabled = function(self, guiType, enabled)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCoreGuiEnabled(%s, %s)", guiPath, serializeValue(guiType), serializeValue(enabled)))\n    end\n    serviceMethods.BindToRenderStep = function(self, name, priority, func)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:BindToRenderStep(%s, %s, function(deltaTime)", servicePath, formatStringLiteral(name), serializeValue(priority)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(0.016) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end\n    serviceMethods.UnbindFromRenderStep = function(self, name)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:UnbindFromRenderStep(%s)", servicePath, formatStringLiteral(name)))\n    end\n    serviceMethods.IsClient = function(self) return true end\n    serviceMethods.IsServer = function(self) return false end\n    serviceMethods.IsRunning = function(self) return true end\n    serviceMethods.IsStudio = function(self) return false end\n    serviceMethods.GetFullName = function(self) return dumperState.registry[proxy] or "Instance" end\n    serviceMethods.GetDebugId = function(self) return _getDebugId(proxy) end\n    serviceMethods.MoveTo = function(self, pos, part)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        if part then\n            emitOutput(string.format("%s:MoveTo(%s, %s)", humPath, serializeValue(pos), serializeValue(part)))\n        else\n            emitOutput(string.format("%s:MoveTo(%s)", humPath, serializeValue(pos)))\n        end\n    end\n    serviceMethods.Move = function(self, direction, relativeTo)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:Move(%s, %s)", humPath, serializeValue(direction), serializeValue(relativeTo or false)))\n    end\n    serviceMethods.EquipTool = function(self, tool)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:EquipTool(%s)", humPath, serializeValue(tool)))\n    end\n    serviceMethods.UnequipTools = function(self)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:UnequipTools()", humPath))\n    end\n    serviceMethods.TakeDamage = function(self, damage)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:TakeDamage(%s)", humPath, serializeValue(damage)))\n    end\n    serviceMethods.ChangeState = function(self, state)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:ChangeState(%s)", humPath, serializeValue(state)))\n    end\n    serviceMethods.GetState = function(self) return createProxyObject("Enum.HumanoidStateType.Running", false) end\n    serviceMethods.SetPrimaryPartCFrame = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:SetPrimaryPartCFrame(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPrimaryPartCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.PivotTo = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:PivotTo(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPivot = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetBoundingBox = function(self) return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1) end\n    serviceMethods.GetExtentsSize = function(self) return Vector3.new(1, 1, 1) end\n    serviceMethods.TranslateBy = function(self, vec)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:TranslateBy(%s)", modelPath, serializeValue(vec)))\n    end\n    serviceMethods.LoadAnimation = function(self, anim)\n        local animPath = dumperState.registry[proxy] or "animator"\n        local trackProxy = createProxyObject("animTrack", false)\n        local varName = registerVariable(trackProxy, "animTrack")\n        emitOutput(string.format("local %s = %s:LoadAnimation(%s)", varName, animPath, serializeValue(anim)))\n        return trackProxy\n    end\n    serviceMethods.GetPlayingAnimationTracks = function(self) return {} end\n    serviceMethods.AdjustSpeed = function(self, speed)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        emitOutput(string.format("%s:AdjustSpeed(%s)", trackPath, serializeValue(speed)))\n    end\n    serviceMethods.AdjustWeight = function(self, weight, fade)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        if fade then\n            emitOutput(string.format("%s:AdjustWeight(%s, %s)", trackPath, serializeValue(weight), serializeValue(fade)))\n        else\n            emitOutput(string.format("%s:AdjustWeight(%s)", trackPath, serializeValue(weight)))\n        end\n    end\n    serviceMethods.Teleport = function(self, placeId, player, spawn, customTeleportData)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:Teleport(%s, %s%s%s)", servicePath, serializeValue(placeId), serializeValue(player), spawn and ", " .. serializeValue(spawn) or '"', customTeleportData and ", " .. serializeValue(customTeleportData) or '"'))\n    end\n    serviceMethods.TeleportToPlaceInstance = function(self, placeId, instanceId, player)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:TeleportToPlaceInstance(%s, %s, %s)", servicePath, serializeValue(placeId), serializeValue(instanceId), serializeValue(player)))\n    end\n    serviceMethods.PlayLocalSound = function(self, sound)\n        local servicePath = dumperState.registry[proxy] or "SoundService"\n        emitOutput(string.format("%s:PlayLocalSound(%s)", servicePath, serializeValue(sound)))\n    end\n    serviceMethods.IsAvailable = function(self) return true end\n    serviceMethods.HasAchieved = function(self) return false end\n    serviceMethods.GrantAchievement = function(self) return true end\n    serviceMethods.GetDeviceCameraCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetDeviceCameraCFrameForSelfView = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.UpdateDeviceCFrame = function(self) return nil end\n    serviceMethods.GetCorescriptLocalizations = function(self)\n        local loc = createProxyObject("LocalizationTable", false)\n        return {loc}\n    end\n    serviceMethods.GetTranslatorForLocaleAsync = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = formatValue(locale or "en-us")}\n        return translator\n    end\n    serviceMethods.IsVibrationSupported = function(self) return false end\n    serviceMethods.GetCharacterAppearanceInfoAsync = function(self)\n        return {assets = {{id = 1}}, bodyColors = {headColorId = 1}, emotes = {{name = "Wave"}}}\n    end\n    serviceMethods.GetHumanoidDescriptionFromUserId = function(self)\n        local desc = createProxyObject("HumanoidDescription", false)\n        dumperState.property_store[desc] = {ClassName = "HumanoidDescription"}\n        return desc\n    end\n    serviceMethods.GetEmotes = function(self) return {Wave = {{1}}} end\n    serviceMethods.GetGroupsAsync = function(self, userId) return {} end\n    serviceMethods.GetGroupInfoAsync = function(self, groupId)\n        return {Id = toNumberFunction(groupId) or 0, Name = "Group", MemberCount = 0}\n    end\n    serviceMethods.GetMemStats = function(self)\n        return {Animations = 1, Clips = 2, Tracks = 3}\n    end\n    serviceMethods.SetItem = function(self, key, value)\n        _at.mem[formatValue(key)] = formatValue(value)\n    end\n    serviceMethods.GetItem = function(self, key)\n        return _at.mem[formatValue(key)]\n    end\n    serviceMethods.RemoveItem = function(self, key)\n        _at.mem[formatValue(key)] = nil\n    end\n    serviceMethods.AddTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        _at.tags[tagName] = _at.tags[tagName] or {}\n        _at.tags[tagName][target] = true\n        _at.instTags[target] = _at.instTags[target] or {}\n        _at.instTags[target][tagName] = true\n    end\n    serviceMethods.RemoveTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        if _at.tags[tagName] then _at.tags[tagName][target] = nil end\n        if _at.instTags[target] then _at.instTags[target][tagName] = nil end\n    end\n    serviceMethods.HasTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        return _at.instTags[target] and _at.instTags[target][tagName] == true or false\n    end\n    serviceMethods.GetTags = function(self, inst)\n        local target = inst or proxy\n        local result = {}\n        for tagName in pairsFunction(_at.instTags[target] or {}) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetTagged = function(self, tag)\n        local tagName = formatValue(tag)\n        local result = {}\n        if _at.tags[tagName] then\n            for inst in pairsFunction(_at.tags[tagName]) do\n                table.insert(result, inst)\n            end\n        end\n        return result\n    end\n    serviceMethods.GetAllTags = function(self)\n        local result = {}\n        for tagName in pairsFunction(_at.tags) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetInstanceAddedSignal = function(self, tag)\n        local tagName = formatValue(tag)\n        if not _at.sigs[tagName] then\n            local sig = createProxyObject("CollectionSignal", false)\n            dumperState.registry[sig] = "CollectionService:GetInstanceAddedSignal(" .. formatStringLiteral(tagName) .. ")"\n            _at.typeOverride[sig] = "RBXScriptSignal"\n            _at.sigs[tagName] = sig\n        end\n        return _at.sigs[tagName]\n    end\n    serviceMethods.GetInstanceRemovedSignal = function(self, tag)\n        return serviceMethods.GetInstanceAddedSignal(self, "__removed_" .. formatValue(tag))\n    end\n    serviceMethods.CheckForUpdate = function(self) return false end\n    serviceMethods.BindAction = function(self, name, callback, createTouchButton, ...)\n        local actionName = formatValue(name)\n        local inputs = {...}\n        _at.acts[actionName] = {inputTypes = inputs, createTouchButton = createTouchButton == true}\n    end\n    serviceMethods.UnbindAction = function(self, name)\n        _at.acts[formatValue(name)] = nil\n    end\n    serviceMethods.GetAllBoundActionInfo = function(self) return _at.acts end\n    serviceMethods.GetAsync = function(self, url) return "{}" end\n    serviceMethods.PostAsync = function(self, url, data) return "{}" end\n    serviceMethods.JSONEncode = function(self, data)\n        local function encode(v)\n            local tv = typeFunction(v)\n            if tv == "string" then return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end\n            if tv == "number" or tv == "boolean" then return toStringFunction(v) end\n            if tv == "table" then\n                local isArray, maxIndex, count = true, 0, 0\n                for k in pairsFunction(v) do\n                    count = count + 1\n                    if typeFunction(k) ~= "number" then isArray = false else maxIndex = math.max(maxIndex, k) end\n                end\n                local out = {}\n                if isArray and maxIndex == count then\n                    for i = 1, maxIndex do table.insert(out, encode(v[i])) end\n                    return "[" .. table.concat(out, ",") .. "]"\n                end\n                for k, val in pairsFunction(v) do table.insert(out, '"' .. toStringFunction(k) .. '":' .. encode(val)) end\n                return "{" .. table.concat(out, ",") .. "}"\n            end\n            return "null"\n        end\n        local encoded = encode(data)\n        _at.json[encoded] = data\n        return encoded\n    end\n    serviceMethods.JSONDecode = function(self, json)\n        local key = formatValue(json)\n        if _at.json[key] then return _at.json[key] end\n        -- validate basic JSON structure — error on malformed input\n        -- check for unmatched quotes, truncated strings, bad escapes\n        local stripped = key:gsub('"[^"\\]*(?:\\.[^"\\]*)*"', '""')\n        local unmatched = key:match('"[^"]*$') -- unterminated string\n        if unmatched then\n            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)\n        end\n        -- check for common malformed patterns\n        if key:match('"\\"}') or key:match('[^\\]\\[^"\\/bfnrtu]') then
            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)
        end
        if key:match("^%s*%[") then
            local result = {}
            for value in key:gmatch('"?([^,"%[%]%s]+)"?') do\n                local n = toNumberFunction(value)\n                table.insert(result, n or value)\n            end\n            return result\n        end\n        if key:match("^%s*{") then\n            local result = {}\n            for k, v in key:gmatch('"%s*([^"]-)%s*"%s*:%s*"?([^",}]+)"?') do\n                result[k] = toNumberFunction(v) or (v == "true" and true) or (v == "false" and false) or v\n            end\n            return result\n        end\n        return {}\n    end\n    serviceMethods.GetCountryRegionForPlayerAsync = function(self, player)\n        -- must be a real Player instance proxy, not coroutine/userdata/etc\n        if not isProxy(player) then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        local props = dumperState.property_store[player] or {}\n        if props.ClassName ~= "Player" and props.ClassName ~= "LocalPlayer" then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        return "US"\n    end\n    serviceMethods.UrlEncode = function(self, str)\n        -- must succeed — encode any string including non-UTF8 bytes\n        local result = formatValue(str):gsub("[^%w%-_%.!~%*'%(%)]", function(c)\n            return string.format("%%%02X", string.byte(c))\n        end)\n        return result\n    end\n    serviceMethods.GetTextSize = function(self, text, size, font, frameSize)\n        local width = math.max(1, #(formatValue(text or "")) * (toNumberFunction(size) or 14) * 0.5)\n        return Vector2.new(width, toNumberFunction(size) or 14)\n    end\n    serviceMethods.GetGuiInset = function(self)\n        return Vector2.new(0, 36), Vector2.new(0, 0)\n    end\n    serviceMethods.GetRequestQueueSize = function(self) return 0 end\n    serviceMethods.CompressBuffer = function(self, b, algorithm, level)\n        -- read data from the real buffer registry\n        local data = _at.buffers[b] or ""\n        -- return a new proper buffer object registered in _at.buffers\n        local out = {}\n        -- store magic prefix + original data so decompress can recover it\n        _at.buffers[out] = "\x1f\x8b" .. data\n        return out\n    end\n    serviceMethods.DecompressBuffer = function(self, b, algorithm)\n        -- read compressed data and strip the magic prefix to recover original\n        local data = _at.buffers[b] or ""\n        local original = data:sub(3) -- strip 2-byte magic prefix\n        local out = {}\n        _at.buffers[out] = original\n        return out\n    end\n    serviceMethods.GetRealPhysicsFPS = function(self) return 60 end\n    serviceMethods.GetEnumItems = function(self)\n        local enumPath = dumperState.registry[proxy] or ""\n        local enumTypeName = enumPath:match("Enum%.(.+)") or "Unknown"\n        local knownItems = {\n            QualityLevel = {"Automatic","Level01","Level02","Level03","Level04","Level05","Level06","Level07","Level08","Level09","Level10","Level11"},\n            KeyCode       = {"Unknown","Return","Space","E","Q","R","F"},\n            RaycastFilterType = {"Exclude","Include"},\n            HumanoidStateType = {"Running","Jumping","Freefall","Landed","Seated","Dead"},\n            NormalId      = {"Front","Back","Left","Right","Top","Bottom"},\n            PlaybackState = {"Begin","Playing","Paused","Completed","Cancelled"},\n            EasingStyle   = {"Linear","Sine","Back","Bounce","Circular","Cubic","Elastic","Exponential","Quad","Quartic","Quintic"},\n            EasingDirection = {"In","Out","InOut"},\n            ActionType    = {"Nothing","Pause","Lose","Draw","Win"},\n            VelocityConstraintMode = {"Vector","Plane","Line"},\n            Material      = {"Plastic","SmoothPlastic","Neon","Wood","Metal","Glass","Grass","Sand","Fabric"},\n            PartType      = {"Ball","Block","Cylinder"},\n            SurfaceType   = {"Smooth","Glue","Weld","Studs","Inlet","Universal","Hinge","Motor"},\n            CreatorType   = {"User","Group"},\n            MembershipType= {"None","Premium"},\n            CameraType    = {"Custom","Follow","Fixed","Attach","Track","Watch","Scriptable"},\n            ReverbType    = {"NoReverb","GenericReverb","SmallRoom","LargeRoom","Hall"},\n            Font          = {"Legacy","Arial","ArialBold","SourceSans","SourceSansBold","GothamBold","Gotham"},\n            Limb          = {"Head","LeftArm","RightArm","LeftLeg","RightLeg","Torso","Unknown"},\n            ConnectionError = {"OK","Unknown","ConnectErrors","Disconnect","Unauthorized","NotFound","Forbidden","TooManyRequests","ServiceUnavailable","GatewayTimeout"},\n        }\n        local names = knownItems[enumTypeName] or {"Unknown"}\n        local items = {}\n        for _, v in ipairsFunction(names) do\n            local itemKey = "Enum." .. enumTypeName .. "." .. v\n            if not _at.enum[itemKey] then\n                local itemProxy = createProxyObject(itemKey, false)\n                dumperState.registry[itemProxy] = itemKey\n                _at.typeOverride[itemProxy] = "EnumItem"\n                _at.enum[itemKey] = itemProxy\n            end\n            items[#items + 1] = _at.enum[itemKey]\n        end\n        return items\n    end\n    serviceMethods.GenerateGUID = function(self, includeBraces)\n        local t = {}\n        local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"\n        for c in template:gmatch(".") do\n            if c == "x" then t[#t+1] = string.format("%x", math.random(0, 15))\n            elseif c == "y" then t[#t+1] = string.format("%x", math.random(8, 11))\n            else t[#t+1] = c end\n        end\n        local guid = table.concat(t):upper()\n        return includeBraces and ("{" .. guid .. "}") or guid\n    end\n    serviceMethods.HttpGet = function(self, url)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP URL"})\n        dumperState.last_http_url = resolvedUrl\n        return resolvedUrl\n    end\n    serviceMethods.HttpPost = function(self, url, data, contentType)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP POST URL"})\n        local resultProxy = createProxyObject("HttpResponse", false)\n        local varName = registerVariable(resultProxy, "httpResponse")\n        local servicePath = dumperState.registry[proxy] or "HttpService"\n        emitOutput(string.format("local %s = %s:HttpPost(%s, %s, %s)", varName, servicePath, serializeValue(url), serializeValue(data), serializeValue(contentType)))\n        dumperState.property_store[resultProxy] = {Body = "{}", StatusCode = 200, Success = true}\n        return resultProxy\n    end\n    serviceMethods.AddItem = function(self, item, delayTime)\n        local servicePath = dumperState.registry[proxy] or "Debris"\n        emitOutput(string.format("%s:AddItem(%s, %s)", servicePath, serializeValue(item), serializeValue(delayTime or 10)))\n    end\n    -- PlaceId/UniverseId mutation no-ops\n    serviceMethods.SetPlaceId = function() end\n    serviceMethods.SetUniverseId = function() end\n    -- TeleportService\n    serviceMethods.TeleportAsync = function(self, placeId, players, options) end\n    serviceMethods.TeleportPartyAsync = function(self, placeId, players) end\n    serviceMethods.TeleportToPrivateServer = function(self, placeId, reservedServerAccessCode, players) end\n    serviceMethods.ReserveServer = function(self, placeId) return "reserved_"..tostring(placeId), os.time() end\n    serviceMethods.GetLocalPlayerTeleportData = function(self) return nil end\n    serviceMethods.GetArrivingTeleportGui = function(self) return nil end\n    serviceMethods.SetTeleportGui = function(self, gui) end\n    serviceMethods.GetPlayerPlaceInstanceAsync = function(self, userId) return false, "", 0, "" end\n    -- Players extra\n    serviceMethods.GetUserIdFromNameAsync = function(self, name) return 1 end\n    serviceMethods.GetNameFromUserIdAsync = function(self, userId) return "Player" end\n    serviceMethods.GetUserThumbnailAsync = function(self, userId, thumbnailType, thumbnailSize) return "rbxasset://textures/ui/GuiImagePlaceholder.png", true end\n    serviceMethods.GetFriendsAsync = function(self, userId) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    serviceMethods.GetCharacterAppearanceAsync = function(self, userId) return createProxyObject("Model", false) end\n    serviceMethods.ReportAbuse = function(self, player, reason, optionalMessage) end\n    serviceMethods.BanAsync = function(self, config) end\n    serviceMethods.UnbanAsync = function(self, config) end\n    -- Chat\n    serviceMethods.Chat = function(self, partOrCharacter, message, color) end\n    serviceMethods.FilterStringAsync = function(self, stringToFilter, playerFrom, chatContext) return stringToFilter end\n    serviceMethods.FilterStringForBroadcast = function(self, stringToFilter, playerFrom) return stringToFilter end\n    serviceMethods.CanUserChatAsync = function(self, userId) return true end\n    serviceMethods.CanUsersChatAsync = function(self, userIdFrom, userIdTo) return true end\n    -- MarketplaceService\n    serviceMethods.PromptPurchase = function(self, player, assetId) end\n    serviceMethods.PromptProductPurchase = function(self, player, productId, equipIfPurchased, currencyType) end\n    serviceMethods.PromptGamePassPurchase = function(self, player, gamePassId) end\n    serviceMethods.PromptPremiumPurchase = function(self, player) end\n    serviceMethods.UserOwnsGamePassAsync = function(self, userId, gamePassId) return false end\n    serviceMethods.PlayerOwnsAsset = function(self, player, assetId) return false end\n    serviceMethods.GetProductInfo = function(self, assetId, infoType, ...)\n        -- error on extra arguments\n        if select("#", ...) > 0 then\n            errorFunction("GetProductInfo: too many arguments", 2)\n        end\n        -- error on invalid assetId types\n        local idType = typeFunction(assetId)\n        if idType ~= "number" then\n            errorFunction("GetProductInfo: assetId must be a number, got " .. idType, 2)\n        end\n        -- error on invalid numeric IDs (negative, non-integer, out of range)\n        if assetId < 1 or assetId ~= math.floor(assetId) or assetId > 2^53 then\n            errorFunction("GetProductInfo: invalid asset ID " .. tostring(assetId), 2)\n        end\n        return {Name="Product", Description="", PriceInRobux=0, AssetId=assetId, IsForSale=false, IsLimited=false, IsLimitedUnique=false, IsNew=false, IsPublicDomain=false, IsForRent=false, MinimumMembershipLevel=0, ContentRatingTypeId=0, Creator={Id=1, Name="Roblox", CreatorType="User"}}\n    end\n    serviceMethods.GetDeveloperProductsAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- BadgeService\n    serviceMethods.AwardBadge = function(self, userId, badgeId) return true end\n    serviceMethods.HasBadgeAsync = function(self, userId, badgeId) return false end\n    serviceMethods.GetBadgeInfoAsync = function(self, badgeId) return {Name="Badge", Description="", IsEnabled=true, IconImageId=0, AwardedBadgeId=badgeId} end\n    -- DataStoreService extra\n    serviceMethods.GetOrderedDataStore = function(self, name, scope) return createProxyObject("OrderedDataStore", false) end\n    serviceMethods.ListDataStoresAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- ContentProvider\n    serviceMethods.PreloadAsync = function(self, instances, callback) end\n    serviceMethods.GetFailedRequests = function(self) return {} end\n    -- SocialService\n    serviceMethods.CanSendGameInviteAsync = function(self, player) return false end\n    serviceMethods.PromptGameInvite = function(self, player) end\n    serviceMethods.CanSendCallInviteAsync = function(self, player) return false end\n    serviceMethods.PromptPhoneBook = function(self, player, tag) end\n    -- AvatarEditorService\n    serviceMethods.PromptSaveAvatar = function(self, description, humanoidRigType) end\n    serviceMethods.PromptSetFavorite = function(self, itemId, itemType, active) end\n    serviceMethods.GetInventoryAsync = function(self, pageSize, assetTypes) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- VoiceChatService\n    serviceMethods.IsVoiceEnabledForUserIdAsync = function(self, userId) return false end\n    serviceMethods.SetCameraMode = function(self, mode) end\n    -- TextService extra\n    serviceMethods.GetFamilyInfoAsync = function(self, assetId) return {Name="Font", Faces={}} end\n    -- PolicyService\n    serviceMethods.GetPolicyInfoForPlayerAsync = function(self, player)\n        return {IsSubjectToChinaPolicies=false, ArePaidRandomItemsRestricted=false, IsPaidItemTradingAllowed=true, AreAdsAllowed=true, AllowedExternalLinkReferences={}}\n    end\n    -- AnalyticsService\n    serviceMethods.LogCustomEvent = function(self, player, eventName, customData) end\n    serviceMethods.LogEconomyEvent = function(self, player, flow, currencyType, amount, endingPlayerBalance, transactionType, itemSku) end\n    serviceMethods.LogFunnelStepEvent = function(self, player, funnelName, funnelSessionId, step, stepName) end\n    serviceMethods.LogOnboardingFunnelStepEvent = function(self, player, step, stepName) end\n    serviceMethods.LogProgressionCompleteEvent = function(self, player, progressionPathName, progressionName) end\n    serviceMethods.LogProgressionEvent = function(self, player, progressionPathName, progressionName, progressionIndex) end\n    -- Instance general\n    serviceMethods.GetNetworkOwner = function(self) return _at.localPlayer end\n    serviceMethods.SetNetworkOwner = function(self, player) end\n    serviceMethods.SetNetworkOwnershipAuto = function(self) end\n    serviceMethods.CanSetNetworkOwnership = function(self) return true, nil end\n    serviceMethods.GetNetworkOwnershipAuto = function(self) return true end\n    serviceMethods.ApplyDescription = function(self, humanoidDescription) end\n    serviceMethods.GetAppliedDescription = function(self) return createProxyObject("HumanoidDescription", false) end\n    serviceMethods.ReplaceContentIds = function(self, ids, newIds) end\n    serviceMethods.GetConnectedParts = function(self, recursive) return {} end\n    serviceMethods.GetJoints = function(self) return {} end\n    serviceMethods.GetTouchingParts = function(self) return {} end\n    serviceMethods.GetNoCollisionConstraints = function(self) return {} end\n    serviceMethods.SubtractAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.UnionAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.IntersectAsync = function(self, parts, cs, ms) return createProxyObject("IntersectOperation", false) end\n    serviceMethods.SeparateAsync = function(self, parts) return {} end\n    serviceMethods.BreakJoints = function(self) end\n    serviceMethods.MakeJoints = function(self) end\n    serviceMethods.ResetOrientationToIdentity = function(self) end\n    serviceMethods.GetRootPart = function(self) return proxy end\n    serviceMethods.GetModelCFrame = function(self) return CFrame.new(0,0,0) end\n    serviceMethods.GetModelSize = function(self) return Vector3.new(1,1,1) end\n    serviceMethods.FindPartOnRay = function(self, ray, ignore, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithWhitelist = function(self, ray, whitelist, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.ArePartsTouchingOthers = function(self, parts, overlapIgnored) return false end\n    serviceMethods.GetPartsInPart = function(self, part, overlapParams) return {} end\n    -- Humanoid extra\n    serviceMethods.AddAccessory = function(self, accessory) end\n    serviceMethods.RemoveAccessories = function(self) end\n    serviceMethods.GetAccessories = function(self) return {} end\n    serviceMethods.GetLimb = function(self, part) return createProxyObject("Enum.Limb.Unknown", false) end\n    serviceMethods.GetBodyPartR15 = function(self, part) return nil end\n    serviceMethods.ReplaceBodyPartR15 = function(self, bodyPart, part) return false end\n    serviceMethods.BuildRigFromAttachments = function(self) end\n    -- Sound extra\n    serviceMethods.Resume = function(self) end\n    -- Gui\n    serviceMethods.TweenPosition = function(self, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSize = function(self, endSize, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSizeAndPosition = function(self, endSize, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    -- ContextActionService extra\n    serviceMethods.GetButton = function(self, actionName) return nil end\n    serviceMethods.LocalToolEquipped = function(self, toolEquipped) end\n    serviceMethods.LocalToolUnequipped = function(self, toolUnequipped) end\n    -- PathfindingService extra\n    serviceMethods.FindPathAsync = function(self, start, finish) return createProxyObject("Path", false) end\n    serviceMethods.ComputeAsync = function(self, start, finish) end\n    serviceMethods.GetWaypoints = function(self) return {} end\n    serviceMethods.CheckOcclusionAsync = function(self, start) return {} end\n    -- Camera extra\n    serviceMethods.ScreenPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.ViewportPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.WorldToScreenPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.WorldToViewportPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.GetPartsObscuringTarget = function(self, castPoints, ignoreList) return {} end\n    serviceMethods.Interpolate = function(self, endPos, endFocus, duration) end\n    -- UserInputService extra\n    serviceMethods.GetMouseLocation = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetMouseDelta = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetKeysPressed = function(self) return {} end\n    serviceMethods.GetMouseButtonsPressed = function(self) return {} end\n    serviceMethods.GetGamepadState = function(self, gamepadNum) return {} end\n    serviceMethods.GetSupportedGamepadKeyCodes = function(self, gamepadNum) return {} end\n    serviceMethods.GetConnectedGamepads = function(self) return {} end\n    serviceMethods.GetLastInputType = function(self) return createProxyObject("Enum.UserInputType.None", false) end\n    serviceMethods.GetFocusedTextBox = function(self) return nil end\n    serviceMethods.IsGamepadButtonDown = function(self, gamepadNum, keyCode) return false end\n    serviceMethods.IsKeyDown = function(self, keyCode) return false end\n    serviceMethods.IsMouseButtonPressed = function(self, mouseButton) return false end\n    serviceMethods.RecenterUserHeadCFrame = function(self) end\n    serviceMethods.GetDeviceRotation = function(self) return createProxyObject("InputObject", false), CFrame.new(0,0,0) end\n    serviceMethods.GetDeviceGravity = function(self) return createProxyObject("InputObject", false) end\n    -- PhysicsService\n    serviceMethods.CreateCollisionGroup = function(self, name) return 0 end\n    serviceMethods.RemoveCollisionGroup = function(self, name) end\n    serviceMethods.CollisionGroupSetCollidable = function(self, name1, name2, collidable) end\n    serviceMethods.CollisionGroupsAreCollidable = function(self, name1, name2) return true end\n    serviceMethods.GetCollisionGroupId = function(self, name) return 0 end\n    serviceMethods.GetCollisionGroupName = function(self, id) return "Default" end\n    serviceMethods.SetPartCollisionGroup = function(self, part, name) end\n    serviceMethods.GetMaxCollisionGroups = function(self) return 32 end\n    serviceMethods.GetRegisteredCollisionGroups = function(self) return {} end\n    -- StarterGui extra\n    serviceMethods.GetCoreGuiEnabled = function(self, coreGuiType) return true end\n    serviceMethods.RegisterGetCore = function(self, parameterName, getFunction) end\n    serviceMethods.RegisterSetCore = function(self, parameterName, setFunction) end\n    -- Lighting extra\n    serviceMethods.GetAtmosphere = function(self) return nil end\n    serviceMethods.GetSky = function(self) return nil end\n    -- Workspace extra\n    serviceMethods.GetServerTimeNow = function(self) return os.time() end\n    serviceMethods.PGSIsEnabled = function(self) return true end\n    serviceMethods.SetInsertPoint = function(self, point) end\n    -- NetworkClient/NetworkServer\n    serviceMethods.GetClientTicket = function(self) return "" end\n    -- ScriptContext\n    serviceMethods.AddCoreScriptLocal = function(self, name, parent) end\n    serviceMethods.GetCoreScriptVersion = function(self) return "1.0.0" end\n    meta.__namecall = function(self, ...) return nil end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        -- fast path: string key, check property_store and common properties before formatValue\n        if typeFunction(key) == "string" then\n            local ps = dumperState.property_store[proxy]\n            if ps then\n                local v = ps[key]\n                if v ~= nil then return v end\n            end\n            if key == "PlaceId" or key == "placeId" then return numericArg end\n            if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n            if key == "Parent" then return dumperState.parent_map[proxy] end\n            if key == "Name" then\n                if _at.typeOverride[proxy] == "EnumItem" then\n                    return (formattedName or ""):match("%.([^%.]+)$") or formattedName or "Object"\n                end\n                return formattedName or "Object"\n            end\n            if key == "ClassName" then return formattedName or "Instance" end\n            if not _at.metaHooks["__index"] then\n                local sm = serviceMethods[key]\n                if sm ~= nil then\n                    if typeFunction(sm) == "function" then\n                        local previousMethod\n                        return function(_, ...)\n                            previousMethod = _at.currentNamecallMethod\n                            _at.currentNamecallMethod = key\n                            local results = {sm(proxy, ...)}\n                            _at.currentNamecallMethod = previousMethod\n                            return table.unpack(results)\n                        end\n                    end\n                    return sm\n                end\n            end\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local propertyName = formatValue(key)\n        if _at.metaHooks["__index"] and not _at.inMetaHook then\n            _at.inMetaHook = true\n            local ok, result = pcallFunction(_at.metaHooks["__index"], proxy, key)\n            _at.inMetaHook = false\n            if ok and result ~= nil then return result end\n        end\n        if key == "PlaceId" or key == "placeId" then return numericArg end\n        if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n        if key == "Parent" then return dumperState.parent_map[proxy] end\n        -- DistributedGameTime ticking (must be before property_store read)\n        if key == "DistributedGameTime" then\n            if not _at._dgtClock then\n                -- initialize ticking from current stored value on first access\n                local props = dumperState.property_store[proxy]\n                _at._dgtBase = (props and props[key]) or 1\n                _at._dgtClock = osLibrary.clock()\n            end\n            return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n        end\n        -- AT6: SurfaceAppearance ContentId properties\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName\n        if className == "SurfaceAppearance" and (key == "ColorMap" or key == "NormalMap" or key == "RoughnessMap" or key == "MetalnessMap") then\n            return _makeContentId("")\n        end\n        if dumperState.property_store[proxy] and dumperState.property_store[proxy][key] ~= nil then\n            return dumperState.property_store[proxy][key]\n        end\n        if serviceMethods[propertyName] then\n            return function(_, ...)\n                if _at.metaHooks["__namecall"] and not _at.inMetaHook then\n                    local previousMethod = _at.currentNamecallMethod\n                    _at.currentNamecallMethod = propertyName\n                    _at.inMetaHook = true\n                    local ok, result = pcallFunction(_at.metaHooks["__namecall"], proxy, ...)\n                    _at.inMetaHook = false\n                    _at.currentNamecallMethod = previousMethod\n                    if ok and result ~= nil then return result end\n                end\n                local previousMethod = _at.currentNamecallMethod\n                _at.currentNamecallMethod = propertyName\n                local results = {serviceMethods[propertyName](proxy, ...)}\n                _at.currentNamecallMethod = previousMethod\n                return table.unpack(results)\n            end\n        end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        if pathName == "fenv" or pathName == "getgenv" or pathName == "_G" then\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            if _G[key] ~= nil then return _G[key] end\n            return nil\n        end\n        if key == "Name" then return formattedName or "Object" end\n        if key == "ClassName" then return formattedName or "Instance" end\n        if key == "Players" then return serviceMethods.GetService(game, "Players") end\n        if key == "Workspace" then return workspace end\n        if key == "LocalPlayer" then\n            if _at.localPlayer then return _at.localPlayer end\n            local lpProxy = createProxyObject("LocalPlayer", false, proxy)\n            dumperState.property_store[lpProxy] = {Name = "Player", ClassName = "Player", UserId = 1}\n            _at.localPlayer = lpProxy\n            local varName = registerVariable(lpProxy, "LocalPlayer")\n            emitOutput(string.format("local %s = %s.LocalPlayer", varName, pathName))\n            return lpProxy\n        end\n        if key == "PlayerGui" then return createProxyObject("PlayerGui", false, proxy) end\n        if key == "Backpack" then return createProxyObject("Backpack", false, proxy) end\n        if key == "PlayerScripts" then return createProxyObject("PlayerScripts", false, proxy) end\n        if key == "UserId" then return 1 end\n        if key == "DisplayName" then return "Player" end\n        if key == "AccountAge" then return 1000 end\n        if key == "LocaleId" then return "en-us" end\n        if key == "RobloxLocaleId" or key == "SystemLocaleId" then return "en-us" end\n        if key == "CharacterMaxSlopeAngle" then return 89 end\n        if key == "DistanceFactor" then return 3.33 end\n        if key == "CaptureBegan" then\n            local sigProxy = createProxyObject(pathName .. ".CaptureBegan", false, proxy)\n            dumperState.registry[sigProxy] = pathName .. ".CaptureBegan"\n            _at.typeOverride[sigProxy] = "RBXScriptSignal"\n            return sigProxy\n        end\n        if key == "Connected" and _at.connState[proxy] ~= nil then return _at.connState[proxy] end\n        if key == "Team" then return createProxyObject("Team", false, proxy) end\n        if key == "TeamColor" then return BrickColor.new("White") end\n        if key == "Character" then\n            local charProxy = createProxyObject("Character", false, proxy)\n            dumperState.property_store[charProxy] = {Name = "Character", ClassName = "Model"}\n            -- AT3: seed Animate LocalScript as child of character\n            if not _at.animateScript then\n                local animProxy = createProxyObject("Animate", false, charProxy)\n                dumperState.registry[animProxy] = "Animate"\n                dumperState.property_store[animProxy] = {Name = "Animate", ClassName = "LocalScript", Parent = charProxy}\n                _setParent(animProxy, charProxy)\n                _at.animateScript = animProxy\n            end\n            return charProxy\n        end\n        if key == "Humanoid" then\n            local humProxy = createProxyObject("Humanoid", false, proxy)\n            dumperState.property_store[humProxy] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}\n            return humProxy\n        end\n        if key == "HumanoidRootPart" or key == "PrimaryPart" or key == "RootPart" then\n            local rootProxy = createProxyObject("HumanoidRootPart", false, proxy)\n            dumperState.property_store[rootProxy] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}\n            return rootProxy\n        end\n        local limbNames = {"Head", "Torso", "UpperTorso", "LowerTorso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "RightHand", "LeftHand", "RightFoot", "LeftFoot"}\n        for _, limb in ipairsFunction(limbNames) do\n            if key == limb then return createProxyObject(key, false, proxy) end\n        end\n        if key == "Animator" then return createProxyObject("Animator", false, proxy) end\n        if key == "CurrentCamera" or key == "Camera" then\n            local camProxy = createProxyObject("Camera", false, proxy)\n            dumperState.property_store[camProxy] = {CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080)}\n            return camProxy\n        end\n        if key == "Terrain" then\n            if not _at.terrainProxy then\n                local tp = createProxyObject("Terrain", false, proxy)\n                dumperState.property_store[tp] = {ClassName="Terrain",Name="Terrain",Parent=proxy,WaterWaveSpeed=100,WaterWaveSize=0.5}\n                _at.terrainProxy = tp\n            end\n            return _at.terrainProxy\n        end\n        if key == "CameraType" then return Enum.CameraType.Custom end\n        if key == "CameraSubject" then return createProxyObject("Humanoid", false, proxy) end\n        if key == "DistributedGameTime" then\n            if _at._dgtBase and _at._dgtClock then\n                return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n            end\n        end\n        local constants = {\n            Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2,\n            Transparency = 0, Mass = 1, Value = 0, TimePosition = 0, TimeLength = 1, Volume = 0.5,\n            PlaybackSpeed = 1, Brightness = 1, Range = 60, Angle = 90, FieldOfView = 70, Thickness = 1,\n            ZIndex = 1, LayoutOrder = 0, Gravity = 196.2, DistributedGameTime = 1, ClockTime = 14,\n            FogEnd = 100000, RolloffScale = 1, MaxPlayers = 12, RespawnTime = 5, PlaceVersion = 1,\n            CreatorId = 0, FollowUserId = 0, NearPlaneZ = -0.1\n        }\n        if constants[key] ~= nil then return constants[key] end\n        if key == "Size" and not (formattedName and formattedName:match("Part")) then return UDim2.new(1, 0, 1, 0) end\n        local boolConstants = {Visible = true, Enabled = true, Anchored = false, CanCollide = true, Locked = false, Active = true, Draggable = false, Modal = false, Playing = false, Looped = false, IsPlaying = false, AutoPlay = false, Archivable = true, ClipsDescendants = false, RichText = false, TextWrapped = false, TextScaled = false, PlatformStand = false, AutoRotate = true, Sit = false}\n        boolConstants.StreamingEnabled = false\n        boolConstants.HttpEnabled = false\n        boolConstants.Sandboxed = false\n        if boolConstants[key] ~= nil then return boolConstants[key] end\n        if key == "JobId" then return "00000000-0000-4000-8000-000000000001" end\n        if key == "CreatorType" then return Enum.CreatorType.User end\n        if key == "MembershipType" then return Enum.MembershipType.None end\n        if key == "AmbientReverb" then return Enum.ReverbType.NoReverb end\n        if key == "Ambient" or key == "OutdoorAmbient" then return Color3.fromRGB(128, 128, 128) end\n        if key == "UniqueId" then return _getDebugId(proxy) end\n        if key == "AbsoluteSize" or key == "ViewportSize" then return Vector2.new(1920, 1080) end\n        if key == "AbsolutePosition" then return Vector2.new(0, 0) end\n        if key == "Position" then\n            if formattedName and (formattedName:match("Part") or formattedName:match("Model") or formattedName:match("Character") or formattedName:match("Root")) then return Vector3.new(0, 5, 0) end\n            return UDim2.new(0, 0, 0, 0)\n        end\n        if key == "Size" then\n            if formattedName and formattedName:match("Part") then return Vector3.new(4, 1, 2) end\n            return UDim2.new(1, 0, 1, 0)\n        end\n        if key == "CFrame" then return CFrame.new(0, 5, 0) end\n        if key == "Velocity" or key == "AssemblyLinearVelocity" then\n            -- AT4: if a LinearVelocity constraint is attached to this part, reflect its VectorVelocity\n            for _, child in ipairsFunction(_at.children[proxy] or {}) do\n                local cprops = dumperState.property_store[child]\n                if cprops and cprops.ClassName == "LinearVelocity" then\n                    local vv = cprops.VectorVelocity\n                    if vv and typeof(vv) == "Vector3" then return vv end\n                end\n            end\n            return Vector3.new(0, 0, 0)\n        end\n        if key == "RotVelocity" or key == "AssemblyAngularVelocity" then\n            local imp = dumperState.property_store[proxy] and dumperState.property_store[proxy]["_angularImpulse"]\n            if imp and _at.vectors[imp] then\n                local d = _at.vectors[imp]\n                return _makeVector3(d.x, d.y, d.z)\n            end\n            return _makeVector3(0, 0, 0)\n        end\n        if key == "Orientation" or key == "Rotation" then return Vector3.new(0, 0, 0) end\n        if key == "LookVector" then return Vector3.new(0, 0, -1) end\n        if key == "RightVector" then return Vector3.new(1, 0, 0) end\n        if key == "UpVector" then return Vector3.new(0, 1, 0) end\n        if key == "Color" or key == "Color3" or key == "BackgroundColor3" or key == "BorderColor3" or key == "TextColor3" or key == "PlaceholderColor3" or key == "ImageColor3" then return Color3.new(1, 1, 1) end\n        if key == "BrickColor" then return BrickColor.new("Medium stone grey") end\n        if key == "Material" then return createProxyObject("Enum.Material.Plastic", false) end\n        if key == "Hit" then return CFrame.new(0, 0, -10) end\n        if key == "Origin" then return CFrame.new(0, 5, 0) end\n        if key == "Target" then return createProxyObject("Target", false, proxy) end\n        if key == "X" or key == "Y" then return 0 end\n        if key == "UnitRay" then return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1)) end\n        if key == "ViewSizeX" then return 1920 end\n        if key == "ViewSizeY" then return 1080 end\n        if key == "Text" or key == "PlaceholderText" or key == "ContentText" or key == "Value" then\n            if inputKey then return inputKey end\n            if key == "Value" then return "input" end\n            return '"'
        end
        if key == "TextBounds" then return Vector2.new(0, 0) end
        if key == "Font" then return createProxyObject("Enum.Font.SourceSans", false) end
        if key == "TextSize" then return 14 end
        if key == "Image" or key == "ImageContent" then return '"' end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        local signalNames = {"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Touched", "TouchEnded", "InputBegan", "InputEnded", "InputChanged", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward", "Activated", "Deactivated", "FocusLost", "FocusGained", "Focused", "Heartbeat", "RenderStepped", "Stepped", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded", "PlayerRemoving", "AncestryChanged", "AttributeChanged", "Died", "FreeFalling", "GettingUp", "Jumping", "Running", "Seated", "Swimming", "StateChanged", "HealthChanged", "MoveToFinished", "OnClientEvent", "OnServerEvent", "OnClientInvoke", "OnServerInvoke", "Completed", "DidLoop", "Stopped", "CaptureBegan", "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Idle", "Move", "TextChanged", "ReturnPressedFromOnScreenKeyboard", "Triggered", "TriggerEnded", "Error", "Event", "AxisChanged", "JumpRequest", "DevTouchMovementModeChanged", "DevComputerMovementModeChanged", "GraphicsQualityChangeRequest", "MenuOpened", "MenuClosed", "PointerAction", "TouchStarted", "TouchMoved", "TouchEnded", "TouchTap", "TouchLongPress", "TouchPinch", "TouchRotate", "TouchSwipe", "GamepadConnected", "GamepadDisconnected", "WindowFocused", "WindowFocusReleased"}\n        for _, sig in ipairsFunction(signalNames) do\n            if key == sig then\n                local sigProxy = createProxyObject(pathName .. "." .. key, false, nil)\n                dumperState.registry[sigProxy] = pathName .. "." .. key\n                _at.typeOverride[sigProxy] = "RBXScriptSignal"\n                _at.signalOwner = _at.signalOwner or {}\n                _at.signalOwner[sigProxy] = proxy  -- track owner without triggering _setParent\n                return sigProxy\n            end\n        end\n        return createProxyMethod(propertyName, proxy)\n    end\n    meta.__newindex = function(tbl, key, val)\n        if key == proxyList or key == "__proxy_id" then\n            rawset(tbl, key, val)\n            return\n        end\n        -- locked: never allow mutation regardless of method\n        local _lockedProps = {PlaceId=true, placeId=true, GameId=true, gameId=true, UniverseId=true}\n        if _lockedProps[key] then return end\n        -- read-only properties: error like real Roblox does\n        local _readOnlyProps = {\n            PlaybackLoudness = true,\n            AbsolutePosition = true,\n            AbsoluteSize = true,\n            AbsoluteRotation = true,\n            TextBounds = true,\n            ContentText = true,\n            SimulationRadius = true,\n            MaxSimulationRadius = true,\n            RootPriority = true,\n            NativeIndex = true,\n            ReceiveAge = true,\n            AssemblyAngularVelocity = true,\n            AssemblyLinearVelocity = true,\n            AssemblyMass = true,\n            AssemblyRootPart = true,\n            CurrentCamera = true,\n            PrivateServerOwnerId = true,\n            PrivateServerId = true,\n            JobId = true,\n            PlaceId = true,\n            GameId = true,\n            PlaceVersion = true,\n            UserId = true,\n            FloorMaterial = true,\n            MoveDirection = true,\n            SeatPart = true,\n        }\n        if _readOnlyProps[key] then\n            errorFunction(toStringFunction(key) .. " is not a valid member of " .. (dumperState.registry[proxy] or formattedName or "Instance"), 2)\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local prop = formatValue(key)\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy][key] = val\n        local _cls2 = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if key == "CameraMinZoomDistance" then\n            local n = tonumber(val) or 0; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif key == "CameraMaxZoomDistance" then\n            local n = tonumber(val) or 400; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif _cls2 == "Terrain" and key == "WaterWaveSpeed" then\n            local n = tonumber(val) or 100; if n > 100 then n = 100 end; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        end\n        if key == "Parent" then\n            _setParent(proxy, isProxy(val) and val or nil)\n        end\n        local className = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if className == "WeldConstraint" or className == "Weld" or className == "Motor6D" then\n            if key == "Part0" or key == "Part1" then\n                _at.weldRegistry[proxy] = _at.weldRegistry[proxy] or {}\n                _at.weldRegistry[proxy][key] = val\n                local wr = _at.weldRegistry[proxy]\n                if wr.Part0 and wr.Part1 then\n                    local cf0 = (dumperState.property_store[wr.Part0] or {}).CFrame\n                    local cf1 = (dumperState.property_store[wr.Part1] or {}).CFrame\n                    if cf0 and cf1 then\n                        wr.offset = {X = (cf1.X or 0) - (cf0.X or 0), Y = (cf1.Y or 0) - (cf0.Y or 0), Z = (cf1.Z or 0) - (cf0.Z or 0)}\n                    end\n                end\n            end\n        end\n        if key == "CFrame" then\n            local cfVal = val\n            local cfX = (cfVal and cfVal.X) or 0\n            local cfY = (cfVal and cfVal.Y) or 0\n            local cfZ = (cfVal and cfVal.Z) or 0\n            for _, wr in pairs(_at.weldRegistry) do\n                if wr.Part0 == proxy and wr.Part1 and wr.offset then\n                    local nx = cfX + wr.offset.X\n                    local ny = cfY + wr.offset.Y\n                    local nz = cfZ + wr.offset.Z\n                    local newCF\n                    if type(CFrame) == "table" and type(CFrame.new) == "function" then\n                        newCF = CFrame.new(nx, ny, nz)\n                    elseif _makeCFrame then\n                        newCF = _makeCFrame(nx, ny, nz)\n                    else\n                        newCF = {X = nx, Y = ny, Z = nz, Position = {X = nx, Y = ny, Z = nz}}\n                    end\n                    dumperState.property_store[wr.Part1] = dumperState.property_store[wr.Part1] or {}\n                    dumperState.property_store[wr.Part1].CFrame = newCF\n                    local posV = newCF.Position\n                    dumperState.property_store[wr.Part1].Position = posV\n                end\n            end\n        end\n        emitOutput(string.format("%s.%s = %s", pathName, prop, serializeValue(val)))\n    end\n    meta.__call = function(tbl, ...)\n        local pathName = dumperState.registry[proxy] or formattedName or "func"\n        if pathName == "fenv" or pathName == "getgenv" or pathName:match("env") then\n            return proxy\n        end\n        if pathName == "game" then\n            errorFunction("attempt to call an Instance value", 0)\n        end\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("result", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s(%s)", varName, pathName, table.concat(serializedArgs, ", ")))\n        return resultProxy\n    end\n    local function operatorMeta(opSymbol)\n        local function metaCall(a, b)\n            local proxy, meta = createProxy()\n            local strA = "0"\n            if a ~= nil then strA = dumperState.registry[a] or serializeValue(a) end\n            local strB = "0"\n            if b ~= nil then strB = dumperState.registry[b] or serializeValue(b) end\n            local expression = "(" .. strA .. " " .. opSymbol .. " " .. strB .. ")"\n            dumperState.registry[proxy] = expression\n            meta.__tostring = function() return expression end\n            meta.__call = function() return proxy end\n            meta.__index = function(_, k)\n                if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                return createProxyObject(expression .. "." .. formatValue(k), false)\n            end\n            meta.__add = operatorMeta("+")\n            meta.__sub = operatorMeta("-")\n            meta.__mul = operatorMeta("*")\n            meta.__div = operatorMeta("/")\n            meta.__mod = operatorMeta("%")\n            meta.__pow = operatorMeta("^")\n            meta.__concat = operatorMeta("..")\n            meta.__eq = function() return false end\n            meta.__lt = function() return false end\n            meta.__le = function() return false end\n            return proxy\n        end\n        return metaCall\n    end\n    meta.__add = operatorMeta("+")\n    meta.__sub = operatorMeta("-")\n    meta.__mul = operatorMeta("*")\n    meta.__div = operatorMeta("/")\n    meta.__mod = operatorMeta("%")\n    meta.__pow = operatorMeta("^")\n    meta.__concat = operatorMeta("..")\n    meta.__eq = function(a, b) return rawequal(a, b) end\n    meta.__lt = function() return false end\n    meta.__le = function() return false end\n    meta.__unm = function(a)\n        local proxy, meta = createProxy()\n        dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n        meta.__tostring = function() return dumperState.registry[proxy] end\n        return proxy\n    end\n    meta.__len = function() return 0 end\n    meta.__tostring = function() return dumperState.registry[proxy] or formattedName or "Object" end\n    meta.__pairs = function() return function() return nil end, proxy, nil end\n    meta.__ipairs = meta.__pairs\n    return proxy\nend\nlocal function createTypeDa(typeName, methods)\n    local dc = {}\n    local dd = {}\n    dd.__index = function(_, key)\n        if key == "new" or methods and methods[key] then\n            return function(...)\n                local args = {...}\n                local serializedArgs = {}\n                for _, val in ipairsFunction(args) do\n                    table.insert(serializedArgs, serializeValue(val))\n                end\n                local expression = typeName .. "." .. key .. "(" .. table.concat(serializedArgs, ", ") .. ")"\n                local proxy, meta = createProxy()\n                dumperState.registry[proxy] = expression\n                meta.__tostring = function() return expression end\n                meta.__index = function(_, k)\n                    if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                    if k == "X" or k == "Y" or k == "Z" or k == "W" then return 0 end\n                    if k == "Magnitude" then return 0 end\n                    if k == "Unit" or k == "Position" or k == "CFrame" or k == "LookVector" or k == "RightVector" or k == "UpVector" or k == "Rotation" or k == "p" then return proxy end\n                    if k == "R" or k == "G" or k == "B" then return 1 end\n                    if k == "Width" or k == "Height" then return UDim.new(0, 0) end\n                    if k == "Min" or k == "Max" or k == "Scale" or k == "Offset" then return 0 end\n                    return createProxyObject(expression .. "." .. formatValue(k), false)\n                end\n                local function opMeta(symbol)\n                    return function(a, b)\n                        local proxy, meta = createProxy()\n                        local expr = "(" .. (dumperState.registry[a] or serializeValue(a)) .. " " .. symbol .. " " .. (dumperState.registry[b] or serializeValue(b)) .. ")"\n                        dumperState.registry[proxy] = expr\n                        meta.__tostring = function() return expr end\n                        meta.__index = meta.__index\n                        meta.__add = opMeta("+")\n                        meta.__sub = opMeta("-")\n                        meta.__mul = opMeta("*")\n                        meta.__div = opMeta("/")\n                        return proxy\n                    end\n                end\n                meta.__add = opMeta("+")\n                meta.__sub = opMeta("-")\n                meta.__mul = opMeta("*")\n                meta.__div = opMeta("/")\n                meta.__unm = function(a)\n                    local proxy, meta = createProxy()\n                    dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n                    meta.__tostring = function() return dumperState.registry[proxy] end\n                    return proxy\n                end\n                meta.__eq = function() return false end\n                meta.__typeof = typeName\n                return proxy\n            end\n        end\n        return nil\n    end\n    dd.__call = function(_, ...) return _.new(...) end\n    return setmetatable(dc, dd)\nend\nVector3 = createTypeDa("Vector3", {new = true, zero = true, one = true})\nVector2 = createTypeDa("Vector2", {new = true, zero = true, one = true})\nUDim = createTypeDa("UDim", {new = true})\nUDim2 = createTypeDa("UDim2", {new = true, fromScale = true, fromOffset = true})\nCFrame = createTypeDa("CFrame", {new = true, Angles = true, lookAt = true, fromEulerAnglesXYZ = true, fromEulerAnglesYXZ = true, fromAxisAngle = true, fromMatrix = true, fromOrientation = true, identity = true})\nColor3 = createTypeDa("Color3", {new = true, fromRGB = true, fromHSV = true, fromHex = true})\nBrickColor = createTypeDa("BrickColor", {new = true, random = true, White = true, Black = true, Red = true, Blue = true, Green = true, Yellow = true, palette = true})\nTweenInfo = createTypeDa("TweenInfo", {new = true})\nRect = createTypeDa("Rect", {new = true})\nRegion3 = createTypeDa("Region3", {new = true})\nRegion3int16 = createTypeDa("Region3int16", {new = true})\nRay = createTypeDa("Ray", {new = true})\nNumberRange = createTypeDa("NumberRange", {new = true})\nNumberSequence = createTypeDa("NumberSequence", {new = true})\nNumberSequenceKeypoint = createTypeDa("NumberSequenceKeypoint", {new = true})\nColorSequence = createTypeDa("ColorSequence", {new = true})\nColorSequence.new = function(...)\n    local args = {...}\n    local keypoints = {}\n    if #args == 1 and typeFunction(args[1]) == "table" and args[1][1] ~= nil then\n        keypoints = args[1]\n    elseif #args == 1 then\n        keypoints = {args[1], args[1]}\n    elseif #args >= 2 then\n        keypoints = args\n    end\n    local t = setmetatable({Keypoints = keypoints}, {\n        __typeof = "ColorSequence",\n        __tostring = function() return "ColorSequence" end,\n    })\n    return t\nend\nColorSequenceKeypoint = createTypeDa("ColorSequenceKeypoint", {new = true})\nPhysicalProperties = createTypeDa("PhysicalProperties", {new = true})\nFont = createTypeDa("Font", {new = true, fromEnum = true, fromName = true, fromId = true})\nRaycastParams = createTypeDa("RaycastParams", {new = true})\nOverlapParams = {new = function()\n        local params = {MaxParts = 0, FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}}\n        return setmetatable(params, {__typeof = "OverlapParams"})\n    end}\n_makeVector3 = function(x, y, z, expr)\n    x, y, z = toNumberFunction(x) or 0, toNumberFunction(y) or 0, toNumberFunction(z) or 0\n    local proxy, meta = createProxy()\n    local expression = expr or ("Vector3.new(" .. serializeValue(x) .. ", " .. serializeValue(y) .. ", " .. serializeValue(z) .. ")")\n    dumperState.registry[proxy] = expression\n    _at.vectors[proxy] = {x = x, y = y, z = z}\n    local function component(v, axis)\n        local data = _at.vectors[v]\n        if not data then return 0 end\n        return axis == "X" and data.x or axis == "Y" and data.y or data.z\n    end\n    local function binary(a, b, symbol)\n        local ax, ay, az = component(a, "X"), component(a, "Y"), component(a, "Z")\n        local bx, by, bz\n        if typeFunction(b) == "number" then bx, by, bz = b, b, b else bx, by, bz = component(b, "X"), component(b, "Y"), component(b, "Z") end\n        if symbol == "+" then return _makeVector3(ax + bx, ay + by, az + bz, "(" .. serializeValue(a) .. " + " .. serializeValue(b) .. ")") end\n        if symbol == "-" then return _makeVector3(ax - bx, ay - by, az - bz, "(" .. serializeValue(a) .. " - " .. serializeValue(b) .. ")") end\n        if symbol == "*" then return _makeVector3(ax * bx, ay * by, az * bz, "(" .. serializeValue(a) .. " * " .. serializeValue(b) .. ")") end\n        return _makeVector3(bx ~= 0 and ax / bx or 0, by ~= 0 and ay / by or 0, bz ~= 0 and az / bz or 0, "(" .. serializeValue(a) .. " / " .. serializeValue(b) .. ")")\n    end\n    meta.__index = function(_, key)\n        if key == proxyList or key == "__proxy_id" then return rawget(proxy, key) end\n        if key == "X" then return x end\n        if key == "Y" then return y end\n        if key == "Z" then return z end\n        if key == "Magnitude" then return math.sqrt(x * x + y * y + z * z) end\n        if key == "Unit" then\n            local mag = math.sqrt(x * x + y * y + z * z)\n            if mag == 0 then return _makeVector3(0, 0, 0, expression .. ".Unit") end\n            return _makeVector3(x / mag, y / mag, z / mag, expression .. ".Unit")\n        end\n        if key == "Dot" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return x * ox + y * oy + z * oz\n            end\n        end\n        if key == "Cross" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return _makeVector3(y*oz - z*oy, z*ox - x*oz, x*oy - y*ox)\n            end\n        end\n        if key == "Lerp" then\n            return function(self, other, alpha)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                local a = toNumberFunction(alpha) or 0\n                return _makeVector3(x + (ox-x)*a, y + (oy-y)*a, z + (oz-z)*a)\n            end\n        end\n        if key == "FuzzyEq" then\n            return function(self, other, epsilon)\n                local eps = toNumberFunction(epsilon) or 1e-5\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return math.abs(x-ox) <= eps and math.abs(y-oy) <= eps and math.abs(z-oz) <= eps\n            end\n        end\n        return 0\n    end\n    meta.__add = function(a, b) return binary(a, b, "+") end\n    meta.__sub = function(a, b) return binary(a, b, "-") end\n    meta.__mul = function(a, b) return binary(a, b, "*") end\n    meta.__div = function(a, b) return binary(a, b, "/") end\n    meta.__unm = function(a) return _makeVector3(-component(a, "X"), -component(a, "Y"), -component(a, "Z"), "(-" .. serializeValue(a) .. ")") end\n    meta.__eq = function(a, b) return component(a, "X") == component(b, "X") and component(a, "Y") == component(b, "Y") and component(a, "Z") == component(b, "Z") end\n    meta.__tostring = function() return toStringFunction(x) .. ", " .. toStringFunction(y) .. ", " .. toStringFunction(z) end\n    return proxy\nend\nVector3 = {\n    new = function(x, y, z) return _makeVector3(x, y, z) end,\n    zero = _makeVector3(0, 0, 0, "Vector3.zero"),\n    one = _makeVector3(1, 1, 1, "Vector3.one"),\n    fromNormalId = function(normalId)\n        local name = toStringFunction(normalId)\n        if name:find("Right")  then return _makeVector3( 1,  0,  0) end\n        if name:find("Left")   then return _makeVector3(-1,  0,  0) end\n        if name:find("Top")    then return _makeVector3( 0,  1,  0) end\n        if name:find("Bottom") then return _makeVector3( 0, -1,  0) end\n        if name:find("Back")   then return _makeVector3( 0,  0,  1) end\n        if name:find("Front")  then return _makeVector3( 0,  0, -1) end\n        return _makeVector3(0, 0, 0)\n    end,\n    fromAxis = function(axis)\n        local name = toStringFunction(axis)\n        if name:find("X") then return _makeVector3(1, 0, 0) end\n        if name:find("Y") then return _makeVector3(0, 1, 0) end\n        if name:find("Z") then return _makeVector3(0, 0, 1) end\n        return _makeVector3(0, 0, 0)\n    end,\n}\nsetmetatable(Vector3, {__call = function(_, x, y, z) return _.new(x, y, z) end})\nlocal function _valueType(typeName, fields, methods)\n    local obj = fields or {}\n    return setmetatable(obj, {\n        __typeof = typeName,\n        __index = methods or {},\n        __tostring = function() return typeName end,\n        __eq = function(a, b)\n            if typeFunction(a) ~= "table" or typeFunction(b) ~= "table" then return false end\n            local ma, mb = getMetatableFunction(a), getMetatableFunction(b)\n            if not ma or not mb or ma.__typeof ~= mb.__typeof then return false end\n            for k, v in pairsFunction(a) do\n                if b[k] ~= v then return false end\n            end\n            for k, v in pairsFunction(b) do\n                if a[k] ~= v then return false end\n            end\n            return true\n        end\n    })\nend\nlocal function _num(v, default) return toNumberFunction(v) or default or 0 end\nlocal function _makeVector2(x, y)\n    x, y = _num(x), _num(y)\n    local methods = {}\n    function methods:Dot(other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) end\n    local mt\n    mt = {\n        __typeof = "Vector2",\n        __index = function(self, key)\n            if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end\n            if key == "Unit" then\n                local mag = math.sqrt(self.X * self.X + self.Y * self.Y)\n                return mag == 0 and _makeVector2(0, 0) or _makeVector2(self.X / mag, self.Y / mag)\n            end\n            return methods[key]\n        end,\n        __add = function(a, b) return _makeVector2(a.X + b.X, a.Y + b.Y) end,\n        __sub = function(a, b) return _makeVector2(a.X - b.X, a.Y - b.Y) end,\n        __mul = function(a, b)\n            if typeFunction(a) == "number" then return _makeVector2(a * b.X, a * b.Y) end\n            if typeFunction(b) == "number" then return _makeVector2(a.X * b, a.Y * b) end\n            return _makeVector2(a.X * b.X, a.Y * b.Y)\n        end,\n        __div = function(a, b)\n            if typeFunction(b) == "number" then return _makeVector2(a.X / b, a.Y / b) end\n            return _makeVector2(a.X / b.X, a.Y / b.Y)\n        end,\n        __unm = function(a) return _makeVector2(-a.X, -a.Y) end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y end,\n        __tostring = function(a) return ("Vector2.new(%s, %s)"):format(a.X, a.Y) end,\n    }\n    return setmetatable({X = x, Y = y}, mt)\nend\nVector2 = {new = function(x, y) return _makeVector2(x, y) end}\nVector2.zero = Vector2.new(0, 0)\nVector2.one = Vector2.new(1, 1)\nsetmetatable(Vector2, {__call = function(_, x, y) return _.new(x, y) end})\nlocal _oldVector3New = Vector3.new\nVector3.new = function(x, y, z)\n    local v = _oldVector3New(x, y, z)\n    local mt = getMetatableFunction(v)\n    local oldIndex = mt.__index\n    mt.__index = function(self, key)\n        if key == "Dot" then\n            return function(_, other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) + self.Z * (other and other.Z or 0) end\n        end\n        if key == "Cross" then\n            return function(_, other)\n                return Vector3.new(\n                    self.Y * (other and other.Z or 0) - self.Z * (other and other.Y or 0),\n                    self.Z * (other and other.X or 0) - self.X * (other and other.Z or 0),\n                    self.X * (other and other.Y or 0) - self.Y * (other and other.X or 0)\n                )\n            end\n        end\n        return oldIndex(self, key)\n    end\n    return v\nend\nVector3.zero = Vector3.new(0, 0, 0)\nVector3.one = Vector3.new(1, 1, 1)\nUDim = {new = function(scale, offset) return _valueType("UDim", {Scale = _num(scale), Offset = _num(offset)}) end}\nsetmetatable(UDim, {__call = function(_, scale, offset) return _.new(scale, offset) end})\nUDim2 = {\n    new = function(xs, xo, ys, yo) return _valueType("UDim2", {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)}) end,\n    fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,\n    fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,\n}\nsetmetatable(UDim2, {__call = function(_, ...) return _.new(...) end})\nColor3 = {\n    new = function(r, g, b)\n        local rv, gv, bv = _num(r), _num(g), _num(b)\n        if rv < 0 or rv > 1 or gv < 0 or gv > 1 or bv < 0 or bv > 1 then\n            errorFunction("R, G, and B must each be in the range [0, 1]", 2)\n        end\n        return setmetatable({R = rv, G = gv, B = bv}, {\n            __typeof = "Color3",\n            __tostring = function(self) return string.format("[R:%g, G:%g, B:%g]", self.R, self.G, self.B) end,\n            __eq = function(a, b) return typeFunction(b) == "table" and a.R == b.R and a.G == b.G and a.B == b.B end,\n        })\n    end,\n    fromRGB = function(r, g, b) return Color3.new(_num(r) / 255, _num(g) / 255, _num(b) / 255) end,\n    fromHSV = function(h, s, v) return Color3.new(v or 1, v or 1, v or 1) end,\n    fromHex = function(hex) return Color3.fromRGB(255, 255, 255) end,\n}\nsetmetatable(Color3, {__call = function(_, ...) return _.new(...) end})\nBrickColor = {\n    new = function(name)\n        name = formatValue(name or "Medium stone grey")\n        return _valueType("BrickColor", {Name = name, Number = 1, Color = Color3.fromRGB(255, 0, 0)})\n    end,\n    random = function() return BrickColor.new("Medium stone grey") end,\n}\nsetmetatable(BrickColor, {__call = function(_, ...) return _.new(...) end})\nNumberRange = {new = function(min, max) return _valueType("NumberRange", {Min = _num(min), Max = max ~= nil and _num(max) or _num(min)}) end}\nNumberSequence = {new = function(value) return _valueType("NumberSequence", {Keypoints = typeFunction(value) == "table" and value or {{Time = 0, Value = _num(value)}, {Time = 1, Value = _num(value)}}}) end}\nTweenInfo = {new = function(timeValue, style, direction, repeatCount, reverses, delayTime) return _valueType("TweenInfo", {Time = _num(timeValue), EasingStyle = style or Enum.EasingStyle.Quad, EasingDirection = direction or Enum.EasingDirection.Out, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0}) end}\nRay = {new = function(origin, direction) return _valueType("Ray", {Origin = origin or Vector3.zero, Direction = direction or Vector3.new(0, 0, -1)}) end}\nRect = {new = function(a, b, c, d)\n    local minV = typeFunction(a) == "table" and a or Vector2.new(a, b)\n    local maxV = typeFunction(c) == "table" and c or Vector2.new(c, d)\n    return _valueType("Rect", {Min = minV, Max = maxV, Width = maxV.X - minV.X, Height = maxV.Y - minV.Y})\nend}\nRegion3 = {new = function(minVec, maxVec)\n    local mn = minVec or Vector3.new(0,0,0)\n    local mx = maxVec or Vector3.new(0,0,0)\n    local sz = Vector3.new(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)\n    return _valueType("Region3", {CFrame = CFrame.new((mn.X+mx.X)/2,(mn.Y+mx.Y)/2,(mn.Z+mx.Z)/2), Size = sz})\nend}\nPhysicalProperties = {new = function(density, friction, elasticity, frictionWeight, elasticityWeight) return _valueType("PhysicalProperties", {Density = _num(density, 1), Friction = _num(friction, 0.3), Elasticity = _num(elasticity, 0.5), FrictionWeight = _num(frictionWeight, 1), ElasticityWeight = _num(elasticityWeight, 1)}) end}\n_makeCFrame = function(x, y, z)\n    local ox, oy, oz = _num(x), _num(y), _num(z)\n    local obj = {X = ox, Y = oy, Z = oz}\n    obj.Position = Vector3.new(ox, oy, oz)\n    obj.p = obj.Position\n    obj.LookVector = Vector3.new(0, 0, -1)\n    obj.RightVector = Vector3.new(1, 0, 0)\n    obj.UpVector = Vector3.new(0, 1, 0)\n    obj.Inverse = function(self) return _makeCFrame(-ox, -oy, -oz) end\n    obj.ToObjectSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox2 - ox, oy2 - oy, oz2 - oz)\n    end\n    obj.ToWorldSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox + ox2, oy + oy2, oz + oz2)\n    end\n    obj.PointToObjectSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) - ox,\n            (point and point.Y or 0) - oy,\n            (point and point.Z or 0) - oz\n        )\n    end\n    obj.PointToWorldSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) + ox,\n            (point and point.Y or 0) + oy,\n            (point and point.Z or 0) + oz\n        )\n    end\n    return setmetatable(obj, {\n        __typeof = "CFrame",\n        __index = function(self, key) return rawget(self, key) end,\n        __mul = function(a, b)\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "CFrame" then\n                return _makeCFrame(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "Vector3" then\n                return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            return a\n        end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y and a.Z == b.Z end,\n        __tostring = function(a) return ("CFrame.new(%s, %s, %s)"):format(a.X, a.Y, a.Z) end,\n    })\nend\nCFrame = {\n    new = function(x, y, z) return _makeCFrame(x, y, z) end,\n    Angles = function() return _makeCFrame(0, 0, 0) end,\n    lookAt = function(origin, target) return _makeCFrame(origin and origin.X or 0, origin and origin.Y or 0, origin and origin.Z or 0) end,\n    LookAt = function(origin, target) return CFrame.lookAt(origin, target) end,\n    fromEulerAnglesXYZ = function() return _makeCFrame(0, 0, 0) end,\n    fromEulerAnglesYXZ = function() return _makeCFrame(0, 0, 0) end,\n    fromAxisAngle = function() return _makeCFrame(0, 0, 0) end,\n    fromMatrix = function(pos) return _makeCFrame(pos and pos.X or 0, pos and pos.Y or 0, pos and pos.Z or 0) end,\n    fromOrientation = function() return _makeCFrame(0, 0, 0) end,\n}\nCFrame.identity = CFrame.new(0, 0, 0)\nsetmetatable(CFrame, {__call = function(_, ...) return _.new(...) end})\nPathWaypoint = createTypeDa("PathWaypoint", {new = true})\nAxes = createTypeDa("Axes", {new = true})\nFaces = createTypeDa("Faces", {new = true})\nVector3int16 = createTypeDa("Vector3int16", {new = true})\nVector2int16 = createTypeDa("Vector2int16", {new = true})\nCatalogSearchParams = createTypeDa("CatalogSearchParams", {new = true})\nDateTime = {\n    now = function()\n        return DateTime.fromUnixTimestamp(os.time())\n    end,\n    fromUnixTimestamp = function(ts)\n        ts = toNumberFunction(ts) or 0\n        local dt = setmetatable({UnixTimestamp = ts, UnixTimestampMillis = ts * 1000}, {\n            __typeof = "DateTime",\n            __index = function(self, key)\n                if key == "UnixTimestamp" then return ts end\n                if key == "UnixTimestampMillis" then return ts * 1000 end\n                if key == "FormatUniversalTime" then\n                    return function(self2, fmt, locale)\n                        -- convert unix timestamp to date components\n                        local t = os.date("!*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "FormatLocalTime" then\n                    return function(self2, fmt, locale)\n                        local t = os.date("*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "ToIsoDate" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", t.year, t.month, t.day, t.hour, t.min, t.sec)\n                    end\n                end\n                if key == "ToUniversalTime" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return {Year=t.year,Month=t.month,Day=t.day,Hour=t.hour,Minute=t.min,Second=t.sec,Millisecond=0}\n                    end\n                end\n            end,\n        })\n        return dt\n    end,\n    fromUnixTimestampMillis = function(ms)\n        return DateTime.fromUnixTimestamp(math.floor((toNumberFunction(ms) or 0) / 1000))\n    end,\n    fromIsoDate = function(iso)\n        return DateTime.fromUnixTimestamp(0)\n    end,\n}\nRandom = {new = function(seed)\n        local obj = {}\n        function obj:NextNumber(min, max) return (min or 0) + 0.5 * ((max or 1) - (min or 0)) end\n        function obj:NextInteger(min, max) return math.floor((min or 1) + 0.5 * ((max or 100) - (min or 1))) end\n        function obj:NextUnitVector() return Vector3.new(0.577, 0.577, 0.577) end\n        function obj:Shuffle(tab) return tab end\n        function obj:Clone() return Random.new() end\n        return obj\n    end}\nsetmetatable(Random, {__call = function(_, seed) return _.new(seed) end})\nEnum = createProxyObject("Enum", true)\nlocal enumMeta = debugLibrary.getmetatable(Enum)\nenumMeta.__index = function(_, key)\n    if key == proxyList or key == "__proxy_id" then return rawget(_, key) end\n    local enumName = "Enum." .. formatValue(key)\n    if not _at.enum[enumName] then\n        local enumProxy = createProxyObject(enumName, false)\n        dumperState.registry[enumProxy] = enumName\n        _at.enum[enumName] = enumProxy\n    end\n    return _at.enum[enumName]\nend\nInstance = {new = function(className, parent)\n        local name = formatValue(className)\n        local _validClasses = {\n            Part=1,MeshPart=1,UnionOperation=1,SpecialMesh=1,BlockMesh=1,CylinderMesh=1,\n            Model=1,Folder=1,Tool=1,LocalScript=1,Script=1,ModuleScript=1,\n            RemoteEvent=1,RemoteFunction=1,BindableEvent=1,BindableFunction=1,\n            Frame=1,ScreenGui=1,SurfaceGui=1,BillboardGui=1,TextLabel=1,TextButton=1,\n            TextBox=1,ImageLabel=1,ImageButton=1,ScrollingFrame=1,ViewportFrame=1,\n            UIListLayout=1,UIGridLayout=1,UITableLayout=1,UIPadding=1,UICorner=1,\n            UIStroke=1,UIScale=1,UIAspectRatioConstraint=1,UISizeConstraint=1,\n            UITextSizeConstraint=1,UIFlexItem=1,UIGradient=1,UIPageLayout=1,\n            Humanoid=1,HumanoidDescription=1,Animator=1,Animation=1,\n            Sound=1,SoundGroup=1,Attachment=1,Motor6D=1,Weld=1,WeldConstraint=1,\n            BallSocketConstraint=1,HingeConstraint=1,SpringConstraint=1,RodConstraint=1,\n            RopeConstraint=1,AlignPosition=1,AlignOrientation=1,\n            ForceField=1,Decal=1,Texture=1,SelectionBox=1,SelectionSphere=1,\n            PointLight=1,SpotLight=1,SurfaceLight=1,Sky=1,Atmosphere=1,Clouds=1,\n            Beam=1,Trail=1,ParticleEmitter=1,Fire=1,Smoke=1,Sparkles=1,\n            Camera=1,Backpack=1,Hat=1,Accessory=1,Shirt=1,Pants=1,ShirtGraphic=1,\n            CharacterMesh=1,BodyColors=1,\n            IntValue=1,StringValue=1,BoolValue=1,NumberValue=1,Vector3Value=1,\n            CFrameValue=1,Color3Value=1,ObjectValue=1,RayValue=1,BrickColorValue=1,\n            ClickDetector=1,ProximityPrompt=1,Dialog=1,DialogChoice=1,\n            SpawnLocation=1,SeatPart=1,VehicleSeat=1,\n            WedgePart=1,CornerWedgePart=1,TrussPart=1,\n            IntersectOperation=1,NegateOperation=1,\n            PathfindingLink=1,PathfindingModifier=1,\n            Configuration=1,LocalizationTable=1,\n            NoCollisionConstraint=1,RigidConstraint=1,\n            EditableMesh=1,EditableImage=1,\n            LinearVelocity=1,AngularVelocity=1,LineForce=1,VectorForce=1,Torque=1,\n            SurfaceAppearance=1,SpecialMesh=1,SelectionBox=1,\n        }\n        if not _validClasses[name] then\n            errorFunction("Unable to create an Instance of type \"" .. name .. "\"", 2)\n        end\n        local proxy = createProxyObject(name, false)\n        local varName = registerVariable(proxy, name)\n        -- class-specific default properties\n        local _classDefaults = {\n            SkateboardController = {Steer=0, Throttle=0},\n            BallSocketConstraint = {LimitsEnabled=false, UpperAngle=45, TwistLimitsEnabled=false, TwistLowerAngle=-45, TwistUpperAngle=45, MaxFrictionTorque=0, Restitution=0},\n            HingeConstraint     = {LimitsEnabled=false, UpperAngle=45, LowerAngle=-45, AngularVelocity=0, MotorMaxTorque=0, Restitution=0},\n            SpringConstraint    = {Coilcount=5, Damping=1, FreeLength=5, LimitsEnabled=false, MaxLength=5, MinLength=0, Stiffness=100, Visible=false},\n            RodConstraint       = {Length=5, LimitAngle0=0, LimitAngle1=0},\n            RopeConstraint      = {Length=5},\n            PrismaticConstraint = {LimitsEnabled=false, UpperLimit=5, LowerLimit=0, Velocity=0},\n            TorsionSpringConstraint = {Damping=1, Stiffness=100, Restitution=0},\n            WeldConstraint      = {},\n            Motor6D             = {CurrentAngle=0, DesiredAngle=0, MaxVelocity=0},\n            ForceField          = {Visible=true},\n            Sound               = {Volume=0.5, PlaybackSpeed=1, TimePosition=0, IsPlaying=false, IsPaused=false, Looped=false, RollOffMaxDistance=10000, RollOffMinDistance=10},\n            ScreenGui           = {Enabled=true, DisplayOrder=0, IgnoreGuiInset=false, ResetOnSpawn=true},\n            Frame               = {BackgroundTransparency=0, BorderSizePixel=1, Visible=true, ZIndex=1, LayoutOrder=0},\n            TextLabel           = {Text="", TextTransparency=0, TextSize=14, TextWrapped=false, RichText=false, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            TextButton          = {Text="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, Modal=false},\n            TextBox             = {Text="", PlaceholderText="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, ClearTextOnFocus=true},\n            ImageLabel          = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            ImageButton         = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            Part                = {Anchored=false, CanCollide=true, Locked=false, Transparency=0, Reflectance=0, Mass=1},\n            MeshPart            = {Anchored=false, CanCollide=true, Transparency=0},\n            Humanoid            = {Health=100, MaxHealth=100, WalkSpeed=16, JumpPower=50, JumpHeight=7.2, HipHeight=2, AutoRotate=true, PlatformStand=false},\n            RemoteEvent         = {},\n            RemoteFunction      = {},\n            BindableEvent       = {},\n            BindableFunction    = {},\n            Animator            = {},\n            LocalizationTable   = {SourceLocaleId="en-us"},\n            Animation           = {AnimationId=""},\n            Attachment          = {},\n            AlignPosition       = {RigidityEnabled=false, MaxForce=1e6, MaxVelocity=1e6, Responsiveness=200},\n            AlignOrientation    = {RigidityEnabled=false, MaxTorque=1e6, MaxAngularVelocity=1e6, Responsiveness=200},\n            LinearVelocity      = {MaxForce=0, VectorVelocity=nil, VelocityConstraintMode=nil, Attachment0=nil},\n            SurfaceAppearance   = {ColorMap=nil, NormalMap=nil, RoughnessMap=nil, MetalnessMap=nil},\n        }\n        local defaults = _classDefaults[name] or {}\n        defaults.ClassName = name\n        defaults.Name = name\n        defaults.Archivable = true\n        dumperState.property_store[proxy] = defaults\n        if parent then\n            local parentPath = dumperState.registry[parent] or serializeValue(parent)\n            emitOutput(string.format("local %s = Instance.new(%s, %s)", varName, formatStringLiteral(name), parentPath))\n            _setParent(proxy, parent)\n        else\n            emitOutput(string.format("local %s = Instance.new(%s)", varName, formatStringLiteral(name)))\n        end\n        return proxy\n    end}\ngame = createProxyObject("game", true)\nworkspace = createProxyObject("workspace", true)\nscript = createProxyObject("script", true)\ndumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}\nlocal function seedCoreRobloxInstances()\n    dumperState.property_store[game] = {\n        Name = "Game", ClassName = "DataModel", JobId = "00000000-0000-4000-8000-000000000001",\n        PlaceId = numericArg, GameId = numericArg + 864197532, placeId = numericArg, gameId = numericArg + 864197532,\n        PlaceVersion = 1, CreatorId = 0, CreatorType = Enum.CreatorType.User\n    }\n    dumperState.property_store[workspace] = {\n        Name = "Workspace", ClassName = "Workspace", Parent = game, Gravity = 196.2, DistributedGameTime = 1,\n        StreamingEnabled = false\n    }\n    _setParent(workspace, game)\n    _at.svcCache.Workspace = workspace\n\n    local players = _at.svcCache.Players or createProxyObject("Players", false, game)\n    _at.svcCache.Players = players\n    dumperState.registry[players] = "Players"\n    dumperState.property_store[players] = {Name = "Players", ClassName = "Players", Parent = game, MaxPlayers = 12, RespawnTime = 5}\n    _setParent(players, game)\n\n    local lp = _at.localPlayer or createProxyObject("LocalPlayer", false, players)\n    _at.localPlayer = lp\n    dumperState.registry[lp] = "LocalPlayer"\n    dumperState.property_store[lp] = {\n        Name = "Player", ClassName = "Player", Parent = players, UserId = 1, DisplayName = "Player",\n        MembershipType = Enum.MembershipType.None, FollowUserId = 0, AccountAge = 1000,\n        CameraMinZoomDistance = 0, CameraMaxZoomDistance = 400,\n        AutoJumpEnabled = true, Neutral = true, Team = nil, LocaleId = "en-us",\n        SimulationRadius = 0, MaxSimulationRadius = 0,\n    }\n    _setParent(lp, players)\n\n    local function ensureChild(parent, name, className, props)\n        local child = createProxyObject(name, false, parent)\n        dumperState.registry[child] = name\n        props = props or {}\n        props.Name = props.Name or name\n        props.ClassName = props.ClassName or className or name\n        props.Parent = parent\n        dumperState.property_store[child] = props\n        _setParent(child, parent)\n        if serviceNames[props.ClassName] then\n            _at.svcCache[props.ClassName] = child\n        end\n        return child\n    end\n\n    ensureChild(lp, "PlayerGui", "PlayerGui")\n    ensureChild(lp, "Backpack", "Backpack")\n    local playerScripts = ensureChild(lp, "PlayerScripts", "PlayerScripts")\n    ensureChild(playerScripts, "PlayerModule", "ModuleScript")\n    ensureChild(playerScripts, "RbxCharacterSounds", "LocalScript")\n    ensureChild(workspace, "Camera", "Camera", {\n        CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080),\n        CameraType = Enum.CameraType.Custom, NearPlaneZ = -0.1\n    })\n    ensureChild(game, "ReplicatedStorage", "ReplicatedStorage")\n    ensureChild(game, "Lighting", "Lighting", {ClockTime = 14, FogEnd = 100000, Ambient = Color3.fromRGB(128, 128, 128), OutdoorAmbient = Color3.fromRGB(128, 128, 128)})\n    ensureChild(game, "SoundService", "SoundService", {RolloffScale = 1, AmbientReverb = Enum.ReverbType.NoReverb})\n    ensureChild(game, "RunService", "RunService")\n    ensureChild(game, "TweenService", "TweenService")\n    ensureChild(game, "HttpService", "HttpService", {HttpEnabled = false})\n    local networkClient = ensureChild(game, "NetworkClient", "NetworkClient")\n    ensureChild(networkClient, "ClientReplicator", "ClientReplicator")\n    local ugc = ensureChild(game, "Ugc", "Folder")\n    ensureChild(ugc, "Chat", "Chat")\n    ensureChild(game, "CollectionService", "CollectionService")\n    ensureChild(game, "TextService", "TextService")\n    ensureChild(game, "GuiService", "GuiService")\n    ensureChild(game, "ContentProvider", "ContentProvider")\nend\nseedCoreRobloxInstances()\ntask = {\n    wait = function(sec)\n        if sec then emitOutput(string.format("task.wait(%s)", serializeValue(sec))) else emitOutput("task.wait()") end\n        -- inside a spawn body, throw to break while-true loops after one iteration\n        if _at.spawnDepth and _at.spawnDepth > 0 then\n            errorFunction("__spawn_yield__", 0)\n        end\n        -- resume any deferred Heartbeat coroutines now that conn locals are assigned\n        if _at.pendingHeartbeat and #_at.pendingHeartbeat > 0 then\n            local pending = _at.pendingHeartbeat\n            _at.pendingHeartbeat = {}\n            for _, co in ipairs(pending) do\n                pcall(coroutine.resume, co)\n            end\n        end\n        for inst, props in pairsFunction(dumperState.property_store) do\n            if props.ClassName == "Part" and props.Anchored == false and _at.vectors[props.Position] then\n                local v = _at.vectors[props.Position]\n                props.Position = Vector3.new(v.x, v.y - 1, v.z)\n            end\n        end\n        return sec or 0.03, osLibrary.clock()\n    end,\n    spawn = function(func, ...)\n        local args = {...}\n        emitOutput("task.spawn(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        elseif typeFunction(func) == "thread" then\n            xpcallFunction( function() coroutine.resume(func, table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        local co = coroutine.create(function() end)\n        _at.threadLike[co] = true\n        local wrapper = setmetatable({}, {\n            __call = function() return true end,\n            __tostring = function() return "thread: 0x0" end,\n        })\n        _at.threadLike[wrapper] = true\n        return wrapper\n    end,\n    delay = function(sec, func, ...)\n        local args = {...}\n        emitOutput(string.format("task.delay(%s, function()", serializeValue(sec or 0)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    defer = function(func, ...)\n        local args = {...}\n        emitOutput("task.defer(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    cancel = function(thread) emitOutput("task.cancel(thread)") end,\n    synchronize = function() emitOutput("task.synchronize()") end,\n    desynchronize = function() emitOutput("task.desynchronize()") end\n}\nwait = function(sec)\n    if sec then emitOutput(string.format("wait(%s)", serializeValue(sec))) else emitOutput("wait()") end\n    task.wait(sec)\n    return sec or 0.03, osLibrary.clock()\nend\ndelay = function(sec, func)\n    emitOutput(string.format("delay(%s, function()", serializeValue(sec or 0)))\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then xpcallFunction(func, function() end) end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\nspawn = function(func)\n    emitOutput("spawn(function()")\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then\n        -- limit spawn bodies: run once then break out of any while true\n        local _spawnDepth = (_at.spawnDepth or 0) + 1\n        if _spawnDepth <= 2 then\n            _at.spawnDepth = _spawnDepth\n            xpcallFunction(func, function() end)\n            _at.spawnDepth = _spawnDepth - 1\n        end\n    end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\ntick = function() return osLibrary.time() end\ntime = function() return osLibrary.clock() end\nelapsedTime = function() return osLibrary.clock() end\nlocal globalEnv = {}\nlocal dummy = 999999999\nlocal function getDummy(key, val) return val end\nlocal function setupEnv()\n    local env = {}\n    setmetatable(env, {\n        __call = function(self, ...) return self end,\n        __index = function(self, key)\n            if _G[key] ~= nil then return getDummy(key, _G[key]) end\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            return nil\n        end,\n        __newindex = function(self, key, val)\n            _G[key] = val\n            globalEnv[key] = 0\n            emitOutput(string.format("_G.%s = %s", formatValue(key), serializeValue(val)))\n        end\n    })\n    return env\nend\n_G.G = setupEnv()\n_G.g = setupEnv()\n_G.ENV = setupEnv()\n_G.env = setupEnv()\n_G.E = setupEnv()\n_G.e = setupEnv()\n_G.L = setupEnv()\n_G.l = setupEnv()\n_G.F = setupEnv()\n_G.f = setupEnv()\nlocal function createGetGenv(path)\n    local proxy = {}\n    local meta = {}\n    local restricted = {"hookfunction", "hookmetamethod", "newcclosure", "replaceclosure", "checkcaller", "iscclosure", "islclosure", "getrawmetatable", "setreadonly", "make_writeable", "getrenv", "getgc", "getinstances"}\n    local function formatPath(d, k)\n        local prop = formatValue(k)\n        if prop:match("^[%a_][%w_]*$") then\n            if d then return d .. "." .. prop end\n            return prop\n        else\n            local escaped = prop:gsub("'", "\\\'")\n            if d then return d .. "['" .. escaped .. "']" end\n            return "['" .. escaped .. "']"\n        end\n    end\n    meta.__index = function(_, key)\n        if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n        return _G[key]\n    end\n    meta.__newindex = function(_, key, val)\n        local fullPath = formatPath(path, key)\n        emitOutput(string.format("getgenv().%s = %s", fullPath, serializeValue(val)))\n    end\n    meta.__call = function() return proxy end\n    meta.__pairs = function() return function() return nil end, nil, nil end\n    return setmetatable(proxy, meta)\nend\nlocal exploitFuncs = {\n    getgenv = function() return createGetGenv(nil) end,\n    getrenv = function() return _G end,\n    getsenv = function() return {} end,\n    getfenv = function(depth)\n        -- always return the same proxy table so getfenv(0)==getfenv(1)\n        if not _at.fenvCache then\n            _at.fenvCache = setmetatable({}, {\n                __index = function(_, key)\n                    if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n                    return _G[key]\n                end,\n                __newindex = function(_, k, v) rawset(_, k, v) end\n            })\n        end\n        return _at.fenvCache\n    end,\n    setfenv = function(func, env)\n        if typeFunction(func) ~= "function" then return end\n        local i = 1\n        while true do\n            local name = debugLibrary.getupvalue(func, i)\n            if name == "_ENV" then debugLibrary.setupvalue(func, i, env) break\n            elseif not name then break end\n            i = i + 1\n        end\n        return func\n    end,\n    hookfunction = function(f, h) return f end,\n    hookmetamethod = function(x, method, hook)\n        local methodName = formatValue(method)\n        if typeFunction(hook) == "function" then\n            _at.metaHooks[methodName] = hook\n        end\n        if methodName == "__index" then\n            return function(obj, key)\n                local mt = isProxy(obj) and debugLibrary.getmetatable(obj)\n                if mt and typeFunction(mt.__index) == "function" then\n                    local saved = _at.metaHooks[methodName]\n                    _at.metaHooks[methodName] = nil\n                    local ok, result = pcallFunction(mt.__index, obj, key)\n                    _at.metaHooks[methodName] = saved\n                    if ok then return result end\n                end\n                return nil\n            end\n        end\n        if methodName == "__namecall" then\n            return function(obj, ...)\n                local methodToCall = _at.currentNamecallMethod\n                if methodToCall and obj then\n                    local member = obj[methodToCall]\n                    if typeFunction(member) == "function" then\n                        local saved = _at.metaHooks[methodName]\n                        _at.metaHooks[methodName] = nil\n                        local ok, result = pcallFunction(member, obj, ...)\n                        _at.metaHooks[methodName] = saved\n                        if ok then return result end\n                    end\n                end\n                return nil\n            end\n        end\n        return function() end\n    end,\n    getrawmetatable = function(x)\n        if isProxy(x) then\n            -- all Instance proxies share ONE metatable so rawequal(mt1,mt2)==true\n            if not _at.sharedInstanceMeta then\n                local mt = {}\n                -- __index must be a C function so debug.getinfo says what=="C"\n                -- use a newproxy userdata with a C-backed metatable trick:\n                -- we tag a wrapper as cclosure so getinfo returns "C"\n                local indexFn = function() end\n                if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n                _at.cclosureSet[indexFn] = true\n                mt.__index = indexFn\n                mt.__newindex = function() end\n                mt.__namecall = function() end\n                mt.__len = function() return 0 end\n                mt.__tostring = function() return "Instance" end\n                _at.sharedInstanceMeta = mt\n            end\n            return _at.sharedInstanceMeta\n        end\n        return getmetatable(x) or {}\n    end,\n    setrawmetatable = function(x, mt) return x end,\n    getnamecallmethod = function() return _at.currentNamecallMethod or "__namecall" end,\n    setnamecallmethod = function(m) _at.currentNamecallMethod = formatValue(m) end,\n    checkcaller = function() return true end,\n    islclosure = function(f)\n        if isProxy(f) then return false end\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return false end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return false end\n        return false\n    end,\n    iscclosure = function(f)\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return true end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return true end\n        return false\n    end,\n    newcclosure = function(f)\n        if typeFunction(f) ~= "function" then return f end\n        if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n        local wrapper = function(...) return f(...) end\n        _at.cclosureSet[wrapper] = true\n        return wrapper\n    end,\n    clonefunction = function(f) return f end,\n    request = function(req)\n        emitOutput(string.format("request(%s)", serializeValue(req)))\n        table.insert(dumperState.string_refs, {value = req.Url or req.url or "unknown", hint = "HTTP Request"})\n        return {Success = true, StatusCode = 200, StatusMessage = "OK", Headers = {}, Body = "{}"}\n    end,\n    http_request = function(req) return exploitFuncs.request(req) end,\n    syn = {request = function(req) return exploitFuncs.request(req) end},\n    http = {request = function(req) return exploitFuncs.request(req) end},\n    HttpPost = function(url, data)\n        emitOutput(string.format("HttpPost(%s, %s)", formatValue(url), formatValue(data)))\n        return "{}"\n    end,\n    setclipboard = function(data) emitOutput(string.format("setclipboard(%s)", serializeValue(data))) end,\n    getclipboard = function() return '"' end,
    identifyexecutor = function() return "Kolenvlogger", "1.0" end,
    getexecutorname = function() return "Kolenvlogger" end,
    gethui = function()
        local hui = createProxyObject("HiddenUI", false)
        registerVariable(hui, "HiddenUI")
        emitOutput(string.format("local %s = gethui()", dumperState.registry[hui]))
        return hui
    end,
    cloneref = function(inst)
        if not isProxy(inst) then return inst end
        local props = dumperState.property_store[inst] or {}
        local className = props.ClassName or dumperState.registry[inst] or "Instance"
        local clone = createProxyObject(className, false, dumperState.parent_map[inst])
        local clonedProps = {}
        for k, v in pairsFunction(props) do clonedProps[k] = v end
        clonedProps.ClassName = clonedProps.ClassName or className
        clonedProps.Name = clonedProps.Name or props.Name or className
        dumperState.property_store[clone] = clonedProps
        dumperState.registry[clone] = (dumperState.registry[inst] or className) .. "_cloneref"
        _at.refBase[clone] = _at.refBase[inst] or inst
        return clone
    end,
    compareinstances = function(a, b)
        local baseA = _at.refBase[a] or a
        local baseB = _at.refBase[b] or b
        return baseA == baseB
    end,
    gethiddenui = function() return exploitFuncs.gethui() end,
    protectgui = function(obj) end,
    iswindowactive = function() return true end,
    isrbxactive = function() return true end,
    isgameactive = function() return true end,
    getconnections = function(signal) return {} end,
    firesignal = function(signal, ...) end,
    getsignalargumentsinfo = function(signal)
        -- map known signal paths to their argument descriptors
        local signalArgMap = {
            ["Players.PlayerAdded"]          = {{Name="player", Type="Player"}},
            ["Players.PlayerRemoving"]       = {{Name="player", Type="Player"}},
            ["Players.PlayerMembershipChanged"] = {{Name="player", Type="Player"}},
            ["Humanoid.Died"]                = {},
            ["Humanoid.HealthChanged"]       = {{Name="health", Type="number"}},
            ["Humanoid.StateChanged"]        = {{Name="old", Type="EnumItem"}, {Name="new", Type="EnumItem"}},
            ["BasePart.Touched"]             = {{Name="otherPart", Type="BasePart"}},
            ["BasePart.TouchEnded"]          = {{Name="otherPart", Type="BasePart"}},
            ["RunService.Heartbeat"]         = {{Name="deltaTime", Type="number"}},
            ["RunService.RenderStepped"]     = {{Name="deltaTime", Type="number"}},
            ["RunService.Stepped"]           = {{Name="time", Type="number"}, {Name="deltaTime", Type="number"}},
            ["UserInputService.InputBegan"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputEnded"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputChanged"]= {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["RemoteEvent.OnClientEvent"]    = {{Name="args", Type="Tuple"}},
            ["BindableEvent.Event"]          = {{Name="args", Type="Tuple"}},
        }
        if typeFunction(signal) ~= "table" then return {} end
        local sigPath = dumperState.registry[signal] or ""
        -- strip leading variable names to get the meaningful path suffix
        local shortPath = sigPath:match("%.(.+)$") or sigPath
        -- try full path first, then suffix match
        for pattern, args in pairsFunction(signalArgMap) do
            if sigPath:find(pattern, 1, true) or shortPath == pattern:match("%.(.+)$") then
                return args
            end
        end
        -- generic fallback: return empty table (signal exists but unknown args)
        return {}
    end,
    fireclickdetector = function(detector, dist) end,
    fireproximityprompt = function(prompt) end,
    firetouchinterest = function(a, b, c) end,
    getinstances = function()
        local instances = {}
        for inst in pairsFunction(dumperState.property_store) do
            if isProxy(inst) and (dumperState.property_store[inst].ClassName or dumperState.registry[inst]) then
                table.insert(instances, inst)
            end
        end
        if #instances == 0 then table.insert(instances, game) end
        return instances
    end,
    getnilinstances = function() return {} end,
    getgc = function() return {} end,
    getscripts = function() return {} end,
    getrunningscripts = function()
        -- AT3: must include the Animate script from character, but NOT arbitrary LocalScript instances
        local result = {}
        if _at.animateScript then result[#result+1] = _at.animateScript end
        return result
    end,
    getloadedmodules = function() return {} end,
    getcallingscript = function() return script end,
    -- script info stubs
    getscriptbytecode = function(s) return "" end,
    getscripthash = function(s) return "0000000000000000000000000000000000000000000000000000000000000000" end,
    getscriptclosure = function(s) return function() end end,
    -- property helpers
    isscriptable = function(obj, prop) return true end,
    setscriptable = function(obj, prop, state) return state end,
    getcallbackvalue = function(obj, prop) return nil end,
    -- clipboard
    setrbxclipboard = function(data) emitOutput(string.format("setrbxclipboard(%s)", serializeValue(data))) return true end,
    -- console extras
    rconsolesettitle = function(title) end,
    -- gc / registry
    getreg = function() return {} end,
    filtergc = function(kind, opts, returnOne) return returnOne and nil or {} end,
    -- function utils
    getfunctionhash = function(f) return "0000000000000000000000000000000000000000" end,
    restorefunction = function(f) end,
    -- misc
    messagebox = function(text, caption, flags)
        emitOutput(string.format("messagebox(%s, %s, %s)", serializeValue(text), serializeValue(caption), serializeValue(flags)))
        return 1
    end,
    readfile = function(file)
        emitOutput(string.format("readfile(%s)", formatStringLiteral(file)))
        return _at.files[formatValue(file)] or '"'\n    end,\n    writefile = function(file, content)\n        local key = formatValue(file)\n        _at.files[key] = formatValue(content)\n        _at.files_hidden = _at.files_hidden or {}\n        _at.files_hidden[key] = true  -- mark as hidden from listfiles\n        emitOutput(string.format("writefile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    appendfile = function(file, content)\n        local name = formatValue(file)\n        _at.files[name] = (_at.files[name] or "") .. formatValue(content)\n        emitOutput(string.format("appendfile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    loadfile = function(file) return function() return createProxyObject("loaded_file", false) end end,\n    listfiles = function(folder)\n        local base = formatValue(folder or "")\n        -- normalize: strip leading slash so "/" matches all files\n        base = base:gsub("^/+", "")\n        local result = {}\n        for name in pairsFunction(_at.folders) do\n            if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n        end\n        for name in pairsFunction(_at.files) do\n            -- skip files marked hidden (written by writefile, not real filesystem files)\n            if not (_at.files_hidden and _at.files_hidden[name]) then\n                if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n            end\n        end\n        return result\n    end,\n    isfile = function(file) return _at.files[formatValue(file)] ~= nil end,\n    isfolder = function(folder) return _at.folders[formatValue(folder)] == true end,\n    makefolder = function(folder)\n        local name = formatValue(folder)\n        if name ~= "" then\n            -- create all parent folders in the path\n            local path = ""\n            for segment in (name .. "/"):gmatch("([^/]+)/") do\n                path = path == "" and segment or (path .. "/" .. segment)\n                _at.folders[path] = true\n            end\n        end\n        emitOutput(string.format("makefolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfolder = function(folder)\n        local name = formatValue(folder)\n        _at.folders[name] = nil\n        emitOutput(string.format("delfolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfile = function(file)\n        _at.files[formatValue(file)] = nil\n        emitOutput(string.format("delfile(%s)", formatStringLiteral(file)))\n    end,\n    DrawingImmediate = (function()\n        local function makePaint()\n            local cbs = {}\n            return {\n                Connect = function(self, fn)\n                    cbs[#cbs+1] = fn\n                    -- return plain table so typeof(cn)=="table" passes the AT check\n                    return {\n                        Disconnect = function(self)\n                            for i,v in ipairs(cbs) do if v==fn then table.remove(cbs,i) break end end\n                        end,\n                        Connected = true,\n                    }\n                end,\n            }\n        end\n        local pc = {}\n        return {\n            Text = function(...) emitOutput("DrawingImmediate.Text(...)") end,\n            Line = function(...) emitOutput("DrawingImmediate.Line(...)") end,\n            Circle = function(...) emitOutput("DrawingImmediate.Circle(...)") end,\n            GetPaint = function(id) if not pc[id] then pc[id]=makePaint() end return pc[id] end,\n            ClearAll = function() emitOutput("DrawingImmediate.ClearAll()") end,\n        }\n    end)(),\n    Drawing = {\n        new = function(type)\n            local t = formatValue(type)\n            local proxy = createProxyObject("Drawing_" .. t, false)\n            registerVariable(proxy, t)\n            _at.userdata[proxy] = "renderobj"\n            emitOutput(string.format("local %s = Drawing.new(%s)", dumperState.registry[proxy], formatStringLiteral(t)))\n            return proxy\n        end,\n        Fonts = createProxyObject("Drawing.Fonts", false)\n    },\n    isrenderobj = function(obj)\n        if typeFunction(obj) ~= "table" then return false end\n        return _at.userdata[obj] == "renderobj"\n    end,\n    crypt = {\n        base64encode = function(s) return s end,\n        base64decode = function(s) return s end,\n        base64_encode = function(s) return s end,\n        base64_decode = function(s) return s end,\n        encrypt = function(s, k) return s end,\n        decrypt = function(s, k) return s end,\n        hash = function(s) return "hash" end,\n        generatekey = function(len) return string.rep("0", len or 32) end,\n        generatebytes = function(len) return string.rep("\\0", len or 16) end\n    },\n    base64_encode = function(s) return s end,\n    base64_decode = function(s) return s end,\n    base64encode = function(s) return s end,\n    base64decode = function(s) return s end,\n    mouse1click = function() emitOutput("mouse1click()") end,\n    mouse1press = function() emitOutput("mouse1press()") end,\n    mouse1release = function() emitOutput("mouse1release()") end,\n    mouse2click = function() emitOutput("mouse2click()") end,\n    mouse2press = function() emitOutput("mouse2press()") end,\n    mouse2release = function() emitOutput("mouse2release()") end,\n    mousemoverel = function(x, y) emitOutput(string.format("mousemoverel(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousemoveabs = function(x, y) emitOutput(string.format("mousemoveabs(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousescroll = function(delta) emitOutput(string.format("mousescroll(%s)", serializeValue(delta))) end,\n    keypress = function(key) emitOutput(string.format("keypress(%s)", serializeValue(key))) end,\n    keyrelease = function(key) emitOutput(string.format("keyrelease(%s)", serializeValue(key))) end,\n    keyclick = function(key) emitOutput(string.format("keyclick(%s)", serializeValue(key))) end,\n    isreadonly = function(t) return false end,\n    setreadonly = function(t, val) return t end,\n    make_writeable = function(t) return t end,\n    make_readonly = function(t) return t end,\n    getthreadidentity = function() return 7 end,\n    setthreadidentity = function(id) end,\n    getidentity = function() return 7 end,\n    setidentity = function(id) end,\n    getthreadcontext = function() return 7 end,\n    setthreadcontext = function(id) end,\n    getcustomasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getsynasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getinfo = function(func) return {source = "=", what = "Lua", name = "unknown", short_src = "dumper"} end,\n    getconstants = function(func) return {} end,\n    getupvalues = function(func) return {} end,\n    getprotos = function(func) return {} end,\n    getupvalue = function(func, i) return nil end,\n    setupvalue = function(func, i, val) end,\n    setconstant = function(func, i, val) end,\n    getconstant = function(func, i) return nil end,\n    getproto = function(func, i) return function() end end,\n    setproto = function(func, i, f) end,\n    getstack = function(level, i) return nil end,\n    setstack = function(level, i, val) end,\n    debug = {\n        getinfo = function(func, ...)\n            if func == print or func == _G.print or func == warn or func == _G.warn then\n                return {source = "=[C]", what = "C", name = "print", short_src = "[C]"}\n            end\n            if getInfo then return getInfo(func, ...) end\n            return {source = "=[C]", what = "C", short_src = "[C]"}\n        end,\n        getupvalue = debugLibrary.getupvalue or function() return nil end,\n        setupvalue = debugLibrary.setupvalue or function() end,\n        getmetatable = debugLibrary.getmetatable,\n        setmetatable = debugLibrary.setmetatable or setmetatable,\n        traceback = getTraceback or function() return '"' end,
        profilebegin = function() end,
        profileend = function() end,
        sethook = function() end
    },
    rconsoleprint = function(s) end,
    rconsoleclear = function() end,
    rconsolecreate = function() end,
    rconsoledestroy = function() end,
    rconsoleinput = function() return "" end,
    rconsoleinfo = function(s) end,
    rconsolewarn = function(s) end,
    rconsoleerr = function(s) end,
    rconsolename = function(name) end,
    printconsole = function(s) end,
    setfflag = function(flag, val) end,
    getfflag = function(flag) return "" end,
    setfpscap = function(cap) emitOutput(string.format("setfpscap(%s)", serializeValue(cap))) end,
    getfpscap = function() return 60 end,
    isnetworkowner = function(part) return true end,
    gethiddenproperty = function(instance, prop)
        if not isProxy(instance) then return nil, false end
        local props = dumperState.property_store[instance]
        if props and props[prop] ~= nil then return props[prop], true end
        return nil, false
    end,
    sethiddenproperty = function(instance, prop, val)
        if isProxy(instance) then
            local props = dumperState.property_store[instance]
            if props then
                if prop == "DistributedGameTime" then
                    -- don't store the set value; just record a tick base from current real value
                    -- so subsequent reads keep ticking from where they were
                    if not _at._dgtClock then
                        _at._dgtBase = (props[prop] or 1)
                        _at._dgtClock = osLibrary.clock()
                    end
                    -- intentionally do NOT store val - real Roblox ignores the set
                else
                    props[prop] = val
                end
            end
        end
        emitOutput(string.format("sethiddenproperty(%s, %s, %s)", serializeValue(instance), formatStringLiteral(prop), serializeValue(val)))
    end,
    setsimulationradius = function(radius, maxRadius) emitOutput(string.format("setsimulationradius(%s%s)", serializeValue(radius), maxRadius and ", " .. serializeValue(maxRadius) or "")) end,
    getspecialinfo = function(instance) return {} end,
    saveinstance = function(options) emitOutput(string.format("saveinstance(%s)", serializeValue(options or {}))) end,
    decompile = function(script) return "-- decompiled" end,
    lz4compress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4compress", 2) end
        local magic = "\x04\x22\x4d\x18"
        local lenBytes = string.char(
            math.floor(#s / 16777216) % 256,
            math.floor(#s / 65536) % 256,
            math.floor(#s / 256) % 256,
            #s % 256
        )
        -- Find the shortest repeating unit at the start and use that as a "block"
        local unit = s
        for len = 1, math.floor(#s / 2) do
            local candidate = s:sub(1, len)
            local repeated = string.rep(candidate, math.floor(#s / len))
            local remainder = s:sub(#repeated + 1)
            if repeated .. remainder == s then
                unit = candidate
                break
            end
        end
        -- Encode as: magic + origLen + unitLen(2 bytes) + unit + count(2 bytes) + remainder
        local count = math.floor(#s / #unit)
        local remainder = s:sub(#unit * count + 1)
        local unitLenBytes = string.char(math.floor(#unit / 256) % 256, #unit % 256)
        local countBytes = string.char(math.floor(count / 256) % 256, count % 256)
        local remLenBytes = string.char(math.floor(#remainder / 256) % 256, #remainder % 256)
        return magic .. lenBytes .. unitLenBytes .. unit .. countBytes .. remLenBytes .. remainder
    end,
    lz4decompress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4decompress", 2) end
        local magic = "\x04\x22\x4d\x18"
        if #s < 12 or s:sub(1, 4) ~= magic then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local b1, b2, b3, b4 = s:byte(5), s:byte(6), s:byte(7), s:byte(8)
        local origLen = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
        local unitLenHi, unitLenLo = s:byte(9), s:byte(10)
        local unitLen = unitLenHi * 256 + unitLenLo
        if #s < 10 + unitLen + 4 then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local unit = s:sub(11, 10 + unitLen)
        local countHi, countLo = s:byte(11 + unitLen), s:byte(12 + unitLen)
        local count = countHi * 256 + countLo
        local remLenHi, remLenLo = s:byte(13 + unitLen), s:byte(14 + unitLen)
        local remLen = remLenHi * 256 + remLenLo
        local remainder = s:sub(15 + unitLen, 14 + unitLen + remLen)
        return (string.rep(unit, count) .. remainder):sub(1, origLen)
    end,
    MessageBox = function(text, caption, type) return 1 end,
    setwindowactive = function() end,
    setwindowtitle = function(title) end,
    queue_on_teleport = function(code) emitOutput(string.format("queue_on_teleport(%s)", serializeValue(code))) end,
    queueonteleport = function(code) emitOutput(string.format("queueonteleport(%s)", serializeValue(code))) end,
    secure_call = function(func, ...) return func(...) end,
    create_secure_function = function(func) return func end,
    isvalidinstance = function(instance) return instance ~= nil end,
    validcheck = function(instance) return instance ~= nil end
}
for name, func in pairsFunction(exploitFuncs) do
    _G[name] = func
end
local nativeBit32 = bit32
local bitLibrary = {}
local function toBit(n)
    n = (n or 0) % 4294967296
    if n >= 2147483648 then n = n - 4294967296 end
    return math.floor(n)
end
local function toU32(n) return math.floor((n or 0) % 4294967296) end

local function _band(a, b)
    if nativeBit32 then return nativeBit32.band(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bor(a, b)
    if nativeBit32 then return nativeBit32.bor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bxor(a, b)
    if nativeBit32 then return nativeBit32.bxor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _lshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return toU32(toU32(n) * (2 ^ bits))
end
local function _rshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return math.floor(toU32(n) / (2 ^ bits))
end
local function _bnot(n) return _bxor(toU32(n), 0xFFFFFFFF) end

bitLibrary.tobit = toBit
bitLibrary.tohex = function(n, len)
    return string.format("%0" .. (len or 8) .. "x", toU32(n))
end
bitLibrary.band = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _band(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bxor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bxor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bnot    = function(n) return toBit(_bnot(n or 0)) end
bitLibrary.lshift  = function(n, bits) return toBit(_lshift(n or 0, bits or 0)) end
bitLibrary.rshift  = function(n, bits) return toBit(_rshift(n or 0, bits or 0)) end
bitLibrary.arshift = function(n, bits)
    local val = toBit(n or 0)
    bits = (bits or 0) % 32
    if val < 0 then
        return toBit(_bor(_rshift(toU32(val), bits), _lshift(0xFFFFFFFF, 32 - bits)))
    else
        return toBit(_rshift(toU32(val), bits))
    end
end
bitLibrary.rol = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_lshift(n, bits), _rshift(n, 32 - bits)))
end
bitLibrary.ror = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_rshift(n, bits), _lshift(n, 32 - bits)))
end
bitLibrary.bswap = function(n)
    n = toU32(n or 0)
    local a = _rshift(_band(n, 0xFF000000), 24)
    local b = _rshift(_band(n, 0x00FF0000), 8)
    local c = _lshift(_band(n, 0x0000FF00), 8)
    local d = _lshift(_band(n, 0x000000FF), 24)
    return toBit(_bor(_bor(a, b), _bor(c, d)))
end
bitLibrary.countlz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    if _band(n, 0xFFFF0000) == 0 then count = count + 16; n = _lshift(n, 16) end
    if _band(n, 0xFF000000) == 0 then count = count + 8;  n = _lshift(n, 8)  end
    if _band(n, 0xF0000000) == 0 then count = count + 4;  n = _lshift(n, 4)  end
    if _band(n, 0xC0000000) == 0 then count = count + 2;  n = _lshift(n, 2)  end
    if _band(n, 0x80000000) == 0 then count = count + 1   end
    return count
end
bitLibrary.countrz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    while _band(n, 1) == 0 do n = _rshift(n, 1); count = count + 1 end
    return count
end
bitLibrary.lrotate = bitLibrary.rol
bitLibrary.rrotate = bitLibrary.ror
bitLibrary.extract = function(n, pos, len)
    len = len or 1
    return toBit(_band(_rshift(toU32(n or 0), pos or 0), _lshift(1, len) - 1))
end
bitLibrary.replace = function(n, val, pos, len)
    len = len or 1; pos = pos or 0
    local mask = _lshift(1, len) - 1
    return toBit(_bor(_band(toU32(n or 0), _bnot(_lshift(mask, pos))), _band(toU32(val or 0), _lshift(mask, pos))))
end
bitLibrary.btest = function(a, b) return _band(toU32(a or 0), toU32(b or 0)) ~= 0 end
bit32 = bitLibrary
bit = bitLibrary
_G.bit = bitLibrary
_G.bit32 = bitLibrary
table.getn = table.getn or function(t) return #t end
table.foreach = table.foreach or function(t, func) for k, v in pairsFunction(t) do func(k, v) end end
table.foreachi = table.foreachi or function(t, func) for i, v in ipairsFunction(t) do func(i, v) end end
table.find = table.find or function(t, value, init)
    for i = (init or 1), #t do
        if t[i] == value then return i end
    end
    return nil
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairsFunction(t) do out[k] = v end
    return out
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clear = table.clear or function(t) for k in pairsFunction(t) do t[k] = nil end end
table.find = table.find or function(t, val, init)
    for i = init or 1, #t do
        if t[i] == val then return i end
    end
    return nil
end
table.clear = table.clear or function(t)
    for k in pairs(t) do t[k] = nil end
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
table.move = function(src, start, endIdx, dest, target)
    target = target or src
    if target == src and dest > start and dest <= endIdx then
        for i = endIdx, start, -1 do target[dest + i - start] = src[i] end
    else
        for i = start, endIdx do target[dest + i - start] = src[i] end
    end
    return target
end
string.split = string.split or function(str, sep)
    local t = {}
    for match in string.gmatch(str, "([^" .. (sep or "%s") .. "]+)") do table.insert(t, match) end
    return t
end
if not math.frexp then
    math.frexp = function(x)
        if x == 0 then return 0, 0 end
        local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
        local m = x / 2 ^ exp
        return m, exp
    end
end
if not math.ldexp then math.ldexp = function(m, e) return m * 2 ^ e end end
if not utf8 then
    utf8 = {}
    utf8.char = function(...)
        local args = {...}
        local chars = {}
        for _, byte in ipairsFunction(args) do table.insert(chars, string.char(byte % 256)) end
        return table.concat(chars)
    end
    utf8.len = function(s) return #s end
    utf8.codes = function(s)
        local i = 0
        return function() i = i + 1; if i <= #s then return i, string.byte(s, i) end end
    end
end
-- graphemes: bypass nested anti-tamper chain third[1][1][1][1][1][1](first, second)
utf8.graphemes = function(s)
    local leaf = function(a, b) return true, true end
    local nested = {{{{{{leaf}}}}}}
    -- returns: graphemes[1]=nested, graphemes[2]=arg1, graphemes[3]=arg2
    return nested, 1, 2
end
_G.utf8 = utf8
pairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return pairsFunction(t) end
    return function() return nil end, t, nil
end
ipairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return ipairsFunction(t) end
    return function() return nil end, t, 0
end
_G.pairs = pairs
_G.ipairs = ipairs
_G.math = math
_G.table = table
-- override string.dump to prevent source/internal name leaking
local _realStringDump = string.dump
-- build a set of all sandbox-internal functions to block
local _blockedDump = setmetatable({}, {__mode="k"})
string.dump = function(f, ...)
    if isProxy(f) then
        errorFunction("unable to dump given function", 2)
    end
    if _blockedDump[f] then
        errorFunction("unable to dump given function", 2)
    end
    -- block exploit funcs
    for name, val in pairsFunction(exploitFuncs) do
        if val == f then errorFunction("unable to dump given function", 2) end
    end
    -- block any function whose bytecode would leak "dumper.lua" or internal names
    local ok, bc = pcallFunction(_realStringDump, f)
    if ok and typeFunction(bc) == "string" then
        if bc:find("dumper%.lua", 1, true) or
           bc:find("emitOutput", 1, true) or
           bc:find("serializeValue", 1, true) or
           bc:find("ipairsFunction", 1, true) or
           bc:find("pairsFunction", 1, true) or
           bc:find("dumperState", 1, true) then
            errorFunction("unable to dump given function", 2)
        end
        return bc
    end
    errorFunction("unable to dump given function", 2)
end
_G.string = string
_G.os = os
os.execute = function() return nil end
os.exit = function() return nil end
os.remove = function() return nil, "disabled" end
os.rename = function() return nil, "disabled" end
_G.coroutine = coroutine
_G.io = nil
_G.debug = exploitFuncs.debug
_G._realSetHook = setHook
_G.utf8 = utf8
_G.next = next
_G.tostring = tostring
_G.tonumber = tonumber
_G.getmetatable = getmetatable
_G.setmetatable = setmetatable
_G.pcall = function(f, ...)
    local results = {pcallFunction(f, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.xpcall = function(f, errFunc, ...)
    local function wrapper(err)
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then return err end
        if errFunc then return errFunc(err) end
        return err
    end
    local results = {xpcallFunction(f, wrapper, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.error = errorFunction
if _G.originalError == nil then _G.originalError = errorFunction end
_G.assert = assert
_G.select = select
_G.type = typeFunction
_G.rawget = rawget
_G.rawset = rawset
_G.rawequal = rawEqualFunction
_G.rawlen = rawlen or function(t) return #t end
_G.unpack = table.unpack or unpack
_G.pack = table.pack or function(...) return {n = select("#", ...), ...} end
_G.task = task
_G.wait = wait
_G.Wait = wait
_G.delay = delay
_G.Delay = delay
_G.spawn = spawn
_G.Spawn = spawn
_G.tick = tick
_G.time = time
_G.elapsedTime = elapsedTime
_G.game = game
_G.Game = game
_G.workspace = workspace
_G.Workspace = workspace
_G.script = script
_G.Enum = Enum
_G.Instance = Instance
_G.Random = Random
_G.Vector3 = Vector3
_G.Vector2 = Vector2
_G.CFrame = CFrame
_G.Color3 = Color3
_G.BrickColor = BrickColor
_G.UDim = UDim
_G.UDim2 = UDim2
_G.TweenInfo = TweenInfo
_G.Rect = Rect
_G.Region3 = Region3
_G.Region3int16 = Region3int16
_G.Ray = Ray
_G.NumberRange = NumberRange
_G.NumberSequence = NumberSequence
_G.NumberSequenceKeypoint = NumberSequenceKeypoint
_G.ColorSequence = ColorSequence
_G.ColorSequenceKeypoint = ColorSequenceKeypoint
_G.PhysicalProperties = PhysicalProperties
_G.Font = Font
_G.RaycastParams = RaycastParams
_G.OverlapParams = OverlapParams
_G.PathWaypoint = PathWaypoint
_G.Axes = Axes
_G.Faces = Faces
_G.Vector3int16 = Vector3int16
_G.Vector2int16 = Vector2int16
_G.CatalogSearchParams = CatalogSearchParams
_G.DateTime = DateTime
settings = function()
    local enumKey = "Enum.QualityLevel.Automatic"
    if not _at.enum[enumKey] then
        local p = createProxyObject(enumKey, false)
        dumperState.registry[p] = enumKey
        _at.enum[enumKey] = p
    end
    local qualityProxy = _at.enum[enumKey]
    return {
        Rendering = {QualityLevel = qualityProxy, FrameRateManager = 0, EagerBulkExecution = false},
        Studio    = {},
        Network   = {IncomingReplicationLag = 0},
        Physics   = {PhysicsEnvironmentalThrottle = createProxyObject("Enum.EnviromentalPhysicsThrottle.DefaultAuto", false)},
    }
end
_G.settings = settings
getmetatable = function(x)
    if _at.userdata[x] then return getMetatableFunction(x) end
    if isProxy(x) then return "The metatable is locked" end
    return getMetatableFunction(x)
end
_G.getmetatable = getmetatable
type = function(x)
    if _at.threadLike[x] then return "thread" end
    if _at.userdata[x] then return "userdata" end
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then return "userdata" end
    return typeFunction(x)
end
_G.type = type
buffer = {
    create = function(size)
        local b = {}
        _at.buffers[b] = string.rep("\0", size or 0)
        return b
    end,
    fromstring = function(s)
        local b = {}
        _at.buffers[b] = formatValue(s)
        return b
    end,
    tostring = function(b)
        return _at.buffers[b] or ""
    end,
    len = function(b)
        return #(_at.buffers[b] or "")
    end,
    copy = function(dst, dstOffset, src, srcOffset, count)
        local srcData = _at.buffers[src] or ""
        local dstData = _at.buffers[dst] or ""
        srcOffset = (srcOffset or 0) + 1
        dstOffset = (dstOffset or 0) + 1
        local chunk = srcData:sub(srcOffset, count and srcOffset + count - 1 or -1)
        local before = dstData:sub(1, dstOffset - 1)
        local after  = dstData:sub(dstOffset + #chunk)
        _at.buffers[dst] = before .. chunk .. after
    end,
    fill = function(b, offset, value, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        count  = count or (#data - offset + 1)
        local fill = string.rep(string.char(value % 256), count)
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + count)
        _at.buffers[b] = before .. fill .. after
    end,
    writestring = function(b, offset, s, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        s = formatValue(s)
        if count then s = s:sub(1, count) end
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + #s)
        _at.buffers[b] = before .. s .. after
    end,
    readstring = function(b, offset, len)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        return data:sub(offset, len and offset + len - 1 or -1)
    end,
    writeu8  = function(b, offset, v) local d=_at.buffers[b] or""; offset=(offset or 0)+1; _at.buffers[b]=d:sub(1,offset-1)..string.char(v%256)..d:sub(offset+1) end,
    readu8   = function(b, offset) local d=_at.buffers[b] or""; return string.byte(d,(offset or 0)+1) or 0 end,
    writeu16 = function(b, offset, v) offset=(offset or 0); buffer.writeu8(b,offset,v%256); buffer.writeu8(b,offset+1,math.floor(v/256)%256) end,
    readu16  = function(b, offset) return buffer.readu8(b,offset) + buffer.readu8(b,(offset or 0)+1)*256 end,
    writeu32 = function(b, offset, v) offset=(offset or 0); for i=0,3 do buffer.writeu8(b,offset+i,math.floor(v/(256^i))%256) end end,
    readu32  = function(b, offset) local v=0; for i=0,3 do v=v+buffer.readu8(b,(offset or 0)+i)*(256^i) end; return v end,
    writei8  = function(b, offset, v) buffer.writeu8(b, offset, v < 0 and v+256 or v) end,
    readi8   = function(b, offset) local v=buffer.readu8(b,offset); return v>=128 and v-256 or v end,
    writei16 = function(b, offset, v) buffer.writeu16(b, offset, v < 0 and v+65536 or v) end,
    readi16  = function(b, offset) local v=buffer.readu16(b,offset); return v>=32768 and v-65536 or v end,
    writei32 = function(b, offset, v) buffer.writeu32(b, offset, v < 0 and v+4294967296 or v) end,
    readi32  = function(b, offset) local v=buffer.readu32(b,offset); return v>=2147483648 and v-4294967296 or v end,
    writef32 = function(b, offset, v) buffer.writeu32(b, offset, math.floor(math.abs(v)*1000)%4294967296) end,
    readf32  = function(b, offset) return buffer.readu32(b,offset)/1000 end,
    writef64 = function(b, offset, v) buffer.writeu32(b, offset, 0); buffer.writeu32(b, (offset or 0)+4, math.floor(math.abs(v)*1000)%4294967296) end,
    readf64  = function(b, offset) return buffer.readu32(b,(offset or 0)+4)/1000 end,
}
_G.buffer = buffer
typeof = function(x)
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then
        if _at.typeOverride[x] then return _at.typeOverride[x] end
        local regName = dumperState.registry[x]
        if regName then
            if regName == "Enum" then return "Enums" end
            if regName:match("^Enum%.[^%.]+$") then return "Enum" end
            if regName:match("^Enum%.[^%.]+%.[^%.]+$") then return "EnumItem" end
            if regName:match("Vector3") then return "Vector3" end
            if regName:match("CFrame") then return "CFrame" end
            if regName:match("Color3") then return "Color3" end
            if regName:match("UDim") then return "UDim2" end
        end
        return "Instance"
    end
    if _at.threadLike[x] then return "thread" end
    local mt = getMetatableFunction(x)
    if mt and mt.__typeof then return mt.__typeof end
    return typeFunction(x) == "table" and "table" or typeFunction(x)
end
_G.typeof = typeof
newproxy = function(withMeta)
    local proxy = {}
    _at.userdata[proxy] = true
    if withMeta then
        setmetatable(proxy, {})
    end
    return proxy
end
_G.newproxy = newproxy
tonumber = function(x, base)
    if getProxyValue(x) ~= 0 then return 123456789 end
    return toNumberFunction(x, base)
end
_G.tonumber = tonumber
rawequal = function(a, b) return rawEqualFunction(a, b) end
_G.rawequal = rawequal
tostring = function(x)
    if isProxy(x) then
        local mt = getMetatableFunction(x)
        if mt and mt.__tostring then
            local ok, r = pcallFunction(mt.__tostring, x)
            if ok and r then return r end
        end
        local regName = dumperState.registry[x]
        return regName or "Instance"
    end
    local mt = getMetatableFunction(x)
    if mt and mt.__tostring then
        local ok, r = pcallFunction(mt.__tostring, x)
        if ok and r then return r end
    end
    return toStringFunction(x)
end
_G.tostring = tostring
dumperState.last_http_url = nil
loadstring = function(code, chunkName)
    if typeFunction(code) ~= "string" then return function() return createProxyObject("loaded", false) end end
    local url = dumperState.last_http_url or code
    dumperState.last_http_url = nil
    local libName = nil
    local lowerCode = url:lower()
    local libs = {{pattern = "rayfield", name = "Rayfield"}, {pattern = "orion", name = "OrionLib"}, {pattern = "kavo", name = "Kavo"}, {pattern = "venyx", name = "Venyx"}, {pattern = "sirius", name = "Sirius"}, {pattern = "linoria", name = "Linoria"}, {pattern = "wally", name = "Wally"}, {pattern = "dex", name = "Dex"}, {pattern = "infinite", name = "InfiniteYield"}, {pattern = "hydroxide", name = "Hydroxide"}, {pattern = "simplespy", name = "SimpleSpy"}, {pattern = "remotespy", name = "RemoteSpy"}}
    for _, lib in ipairsFunction(libs) do if lowerCode:find(lib.pattern) then libName = lib.name; break end end
    if libName then
        local proxy = createProxyObject(libName, false)
        dumperState.registry[proxy] = libName
        dumperState.names_used[libName] = true
        if url:match("^https?://") then emitOutput(string.format('local %s = loadstring(game:HttpGet("%s"))()', libName, url)) end
        return function() return proxy end
    end
    if url:match("^https?://") then
        local proxy = createProxyObject("Library", false)
        emitOutput(string.format('local loadstring = loadstring(game:HttpGet("%s"))()', url))
        return function() return proxy end
    end
    if code:match("local%s+a%s*=%s*if%s+true%s+then") then return nil, "attempt to call a nil value" end
    if typeFunction(code) == "string" then code = processString(code) end
    local func, err = loadFunction(code)
    if func then return func end
    local proxy = createProxyObject("LoadedChunk", false)
    return function() return proxy end
end
load = loadstring
_G.loadstring = loadstring
_G.load = loadstring
require = function(module)
    local modName = dumperState.registry[module] or serializeValue(module)
    local proxy = createProxyObject("RequiredModule", false)
    local varName = registerVariable(proxy, "module")
    emitOutput(string.format("local %s = require(%s)", varName, modName))
    return proxy
end
_G.require = require
print = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("print(%s)", table.concat(items, ", ")))
end
_G.print = print
warn = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("warn(%s)", table.concat(items, ", ")))
end
_G.warn = warn
-- Tag Roblox-like builtins as C closures so iscclosure() returns true for them
do
    if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end
    local _cbuiltins = {
        print, warn, tick, time, elapsedTime, pcall, xpcall, error, assert,
        tostring, tonumber, type, typeof, rawget, rawset, rawequal, rawlen,
        setmetatable, getmetatable, ipairs, pairs, next, select, unpack,
        require, loadstring, load,
    }
    for _, fn in ipairs(_cbuiltins) do
        if typeFunction(fn) == "function" then
            _at.cclosureSet[fn] = true
        end
    end
end
_G.shared = shared
local globalBase = _G
local globalMeta = setmetatable({}, {
    __index = function(tbl, key)
        if configuration.VERBOSE then printFunction("[VERBOSE] Accessing field: " .. toStringFunction(key)) end
        local val = rawget(globalBase, key)
        if val == nil then val = rawget(_G, key) end
        if configuration.VERBOSE then
            if val ~= nil then
                if typeFunction(val) == "table" then printFunction("[VERBOSE] Found global table: " .. toStringFunction(key))
                elseif typeFunction(val) == "function" then printFunction("[VERBOSE] Found global function: " .. toStringFunction(key))
                else printFunction("[VERBOSE] Found global value: " .. toStringFunction(key) .. " = " .. toStringFunction(val)) end
            else
                printFunction("[VERBOSE] Missing field, providing dummy function: " .. toStringFunction(key))
                val = function() if configuration.VERBOSE then printFunction("[Missing Function] Called: " .. toStringFunction(key) .. " with 0 arguments") end return nil end
            end
        end
        return val
    end,
    __newindex = function(tbl, key, val) rawset(globalBase, key, val) end
})
_G._G = globalMeta
function proxyTable.reset()
    dumperState = {output = {}, indent = 0, registry = {}, reverse_registry = {}, names_used = {}, parent_map = {}, property_store = {}, call_graph = {}, variable_types = {}, string_refs = {}, proxy_id = 0, callback_depth = 0, pending_iterator = false, last_http_url = nil, last_emitted_line = nil, repetition_count = 0, current_size = 0, limit_reached = false, ls_counter = 0, captured_constants = {}}
    _at.mem = {}
    _at.tags = {}
    _at.sigs = {}
    _at.acts = {}
    _at.json = {}
    _at.enum = {}
    _at.svcCache = {}
    _at.typeOverride = {}
    _at.connState = {}
    _at.pendingHeartbeat = {}
    _at.locEntries = {}
    _at.userdata = {}
    _at.localPlayer = nil
    setmetatable(_at.userdata, {__mode = "k"})
    _at.debugIds = {}
    setmetatable(_at.debugIds, {__mode = "k"})
    _at.debugIdCtr = 0
    uiCounters = {}
    game = createProxyObject("game", true)
    workspace = createProxyObject("workspace", true)
    script = createProxyObject("script", true)
    Enum = createProxyObject("Enum", true)
    shared = createProxyObject("shared", true)
    dumperState.property_store[game] = {PlaceId = numericArg, GameId = numericArg, placeId = numericArg, gameId = numericArg}
    dumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}
    _G.game = game; _G.Game = game; _G.workspace = workspace; _G.Workspace = workspace; _G.script = script; _G.Enum = Enum; _G.shared = shared
    local meta = debugLibrary.getmetatable(Enum)
    meta.__index = function(_, key)
        if key == proxyList or key == "__proxy_id" then return rawget(_, key) end
        local enumName = "Enum." .. formatValue(key)
        if not _at.enum[enumName] then
            local enumProxy = createProxyObject(enumName, false)
            dumperState.registry[enumProxy] = enumName
            _at.enum[enumName] = enumProxy
        end
        return _at.enum[enumName]
    end
    seedCoreRobloxInstances()
    if type(_G._bypassOnReset) == "function" then
        local prevOutput = dumperState.output
        local prevOutputCount = #prevOutput
        local prevIndent = dumperState.indent
        local prevLast = dumperState.last_emitted_line
        local prevRep = dumperState.repetition_count
        local prevSize = dumperState.current_size
        local prevLimit = dumperState.limit_reached
        pcall(_G._bypassOnReset)
        for i = #prevOutput, prevOutputCount + 1, -1 do
            prevOutput[i] = nil
        end
        dumperState.output = prevOutput
        dumperState.indent = prevIndent
        dumperState.last_emitted_line = prevLast
        dumperState.repetition_count = prevRep
        dumperState.current_size = prevSize
        dumperState.limit_reached = prevLimit
    end
end
function proxyTable.get_output() return getFullOutput() end
function proxyTable.save(file) return saveToFile(file) end
function proxyTable.get_call_graph() return dumperState.call_graph end
function proxyTable.get_string_refs() return dumperState.string_refs end
function proxyTable.get_stats() return {total_lines = #dumperState.output, remote_calls = #dumperState.call_graph, suspicious_strings = #dumperState.string_refs, proxies_created = dumperState.proxy_id} end
local dumper = {callId = "LUASPLOIT_", binaryOperatorNames = {["and"] = "AND", ["or"] = "OR", [">"] = "GT", ["<"] = "LT", [">="] = "GE", ["<="] = "LE", ["=="] = "EQ", ["~="] = "NEQ", [".."] = "CAT"}}
function dumper:hook(code) return self.callId .. code end
function dumper:process_expr(expr)
    if not expr then return "nil" end
    if typeFunction(expr) == "string" then return expr end
    local tag = expr.tag or expr.kind
    if tag == "number" or tag == "string" then
        local val = tag == "string" and string.format("%q", expr.text) or (expr.value or expr.text)
        if configuration.CONSTANT_COLLECTION then return string.format("%sGET(%s)", self.callId, val) end
        return val
    end
    if tag == "local" or tag == "global" then return (expr.name or expr.token).text
    elseif tag == "boolean" or tag == "bool" then return toStringFunction(expr.value)
    elseif tag == "binary" then
        local lhs = self:process_expr(expr.lhsoperand)
        local rhs = self:process_expr(expr.rhsoperand)
        local op = expr.operator.text
        local opName = self.binaryOperatorNames[op]
        if opName then return string.format("%s%s(%s, %s)", self.callId, opName, lhs, rhs) end
        return string.format("(%s %s %s)", lhs, op, rhs)
    elseif tag == "call" then
        local func = self:process_expr(expr.func)
        local args = {}
        for i, node in ipairsFunction(expr.arguments) do args[i] = self:process_expr(node.node or node) end
        return string.format("%sCALL(%s, %s)", self.callId, func, table.concat(args, ", "))
    elseif tag == "indexname" or tag == "index" then
        local exprStr = self:process_expr(expr.expression)
        local keyStr = tag == "indexname" and string.format("%q", expr.index.text) or self:process_expr(expr.index)
        return string.format("%sCHECKINDEX(%s, %s)", self.callId, exprStr, keyStr)
    end
    return "nil"
end
function dumper:process_statement(stmt)
    if not stmt then return "" end
    local tag = stmt.tag
    if tag == "local" or tag == "assign" then
        local vars, vals = {}, {}
        for _, node in ipairsFunction(stmt.variables or {}) do table.insert(vars, self:process_expr(node.node or node)) end
        for _, node in ipairsFunction(stmt.values or {}) do table.insert(vals, self:process_expr(node.node or node)) end
        return (tag == "local" and "local " or "") .. table.concat(vars, ", ") .. " = " .. table.concat(vals, ", ")
    elseif tag == "block" then
        local stmts = {}
        for _, s in ipairsFunction(stmt.statements or {}) do table.insert(stmts, self:process_statement(s)) end
        return table.concat(stmts, "; ")
    end
    return self:process_expr(stmt) or ""
end
local function _loosePasteCode(code)
    if typeFunction(code) ~= "string" then return code end
    code = code:gsub("```lua", ""):gsub("```", "")
    return code
end
local function _loadLooseChunk(code, chunkName)
    local sanitized = processString(_loosePasteCode(code))
    local lines = {}
    sanitized:gsub("([^\n]*)\n?", function(line)
        if line ~= "" or #lines == 0 or sanitized:sub(-1) == "\n" then table.insert(lines, line) end
    end)
    local skipped = {}
    for _ = 1, 400 do
        local current = table.concat(lines, "\n")
        local func, err = loadFunction(current, chunkName)
        if func then return func, nil, current, skipped end
        local lineNo = toNumberFunction(toStringFunction(err):match("%]:(%d+):") or toStringFunction(err):match(":(%d+):"))
        if not lineNo or not lines[lineNo] or skipped[lineNo] then return nil, err, current, skipped end
        skipped[lineNo] = lines[lineNo]
        lines[lineNo] = "-- " .. lines[lineNo]
    end
    return nil, "too many invalid loose-paste lines", table.concat(lines, "\n"), skipped
end
function proxyTable.dump_file(inputPath, outputPath)
    proxyTable.reset()
    local file = ioLibrary.open(inputPath, "rb")
    if not file then
    printFunction("error: cannot open input")
        return false
    end
    local code = file:read("*a")
    file:close()
    printFunction("input: normalize")
    local func, err, sanitized, skipped = _loadLooseChunk(code, "Obfuscated_Script")
    if not func then
        printFunction("error: load " .. toStringFunction(err))
        return false
    end
    if skipped then
        local skippedCount = 0
        for _ in pairsFunction(skipped) do skippedCount = skippedCount + 1 end
        if skippedCount > 0 then printFunction("input: skipped-lines=" .. toStringFunction(skippedCount)) end
    end
    local _SANDBOX_BLOCK = {
        io=true, os=true, debug=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true,
    }
    local _rawTb = debugLibrary and debugLibrary.traceback
    local _badTbWords = {
        "sandbox","hook","intercept","mock","proxy","virtual_env",
        "decompil","emulat","simulat","fake_","getupval","hookfunc",
        "replaceclos","newcclos","restorefunction","bypass","dumper",
    }
    local _tbWrapper = function(thread, msg, level)
        local ok, tb
        if _rawTb then
            if typeFunction(thread) == "thread" then
                ok, tb = pcallFunction(_rawTb, thread, msg, level)
            else
                ok, tb = pcallFunction(_rawTb, thread, msg)
            end
        end
        if not ok or typeFunction(tb) ~= "string" then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        local lines = {}
        for line in (tb .. "\n"):gmatch("([^\n]*)\n") do
            local lo = line:lower()
            local bad = false
            for _, w in next, _badTbWords do
                if lo:find(w, 1, true) then bad = true; break end
            end
            if not bad then lines[#lines + 1] = line end
        end
        local cleaned = table.concat(lines, "\n")
        cleaned = cleaned:gsub("%[([%w%+%/]+)%]", function(inner)
            if #inner + 2 < 10 then return "[RobloxGameScript]" end
            return "[" .. inner .. "]"
        end)
        if #cleaned < 20 then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        return cleaned
    end
    local _SAFE_DEBUG = {
        getinfo = function(func, ...)
            if typeFunction(func) == "number" then
                return nil
            end
            return {source = "=[C]", what = "C", name = "C function", short_src = "[C]"}
        end,
        traceback  = _tbWrapper,
        getupvalue = function(fn, i) return nil end,
    }
    local _SAFE_OS = {
        clock = function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end,
        time  = osLibrary.time,
        date  = osLibrary.date,
    }
    local env = setmetatable({
        _VERSION = "Luau",
        LuraphContinue = nil,
        __LC__ = function() end,
        script = script, game = game, workspace = workspace,
        io      = nil,
        os      = _SAFE_OS,
        debug   = _SAFE_DEBUG,
        error   = _origError,
        dofile  = nil,
        loadfile = nil,
        require = nil,
        package = nil,
        socket  = nil,
        ffi     = nil,
        collectgarbage = nil,
        newproxy = newproxy,
        -- hide _G metatable from scripts
        getmetatable = function(obj)
            if obj == _G or obj == env then return nil end
            if _at.userdata[obj] then return getMetatableFunction(obj) end
            if isProxy(obj) then return "The metatable is locked" end
            return getMetatableFunction(obj)
        end,
        LUASPLOIT_CHECKINDEX = function(tbl, key)
            local val = tbl[key]
            if typeFunction(val) == "table" and not dumperState.registry[val] then
                dumperState.ls_counter = dumperState.ls_counter + 1
                dumperState.registry[val] = "v" .. dumperState.ls_counter
            end
            return val
        end,
        LUASPLOIT_GET = function(v) return v end,
        LS_CALL = function(f, ...)
            if typeFunction(f) ~= "function" then return nil end
            return f(...)
        end,
        LS_NAMECALL = function(t, method, ...)
            if typeFunction(t) ~= "table" then return nil end
            if typeFunction(t[method]) ~= "function" then return nil end
            return t[method](t, ...)
        end,
        LUASPLOIT_CALL = function(f, ...) return f(...) end,
        LUASPLOIT_NAMECALL = function(t, method, ...) return t[method](t, ...) end,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end
    }, {
        __index = function(_, k)
            if _SANDBOX_BLOCK[k] then return nil end
            -- block dumper internal globals from leaking into script env
            if k == "LuraphContinue" or k == "__FLAMEDUMPER_REQUIRE_ONLY"
            or k == "proxyTable" or k == "dumperState" or k == "_at" then
                return nil
            end
            return _G[k]
        end,
        __newindex = _G
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, env)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, env) end
        end
    end
    printFunction("vm: running")
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    local success, runErr = xpcallFunction(function() func() end, function(e) return toStringFunction(e) end)
    setHook()
    if not success and not toStringFunction(runErr):match("TIMEOUT") then
        emitComment("Runtime: " .. toStringFunction(runErr))
    end
    local saved = proxyTable.save(outputPath or configuration.OUTPUT_FILE)
    if saved then
        local stats = proxyTable.get_stats()
        printFunction(string.format("done: lines=%d remotes=%d strings=%d",
            stats.total_lines, stats.remote_calls, stats.suspicious_strings))
    else
        printFunction("error: write failed")
    end
    return saved
end
function proxyTable.dump_string(code, outputPath)
    proxyTable.reset()
    if code then code = processString(code) end
    local func, err = loadFunction(code)
    if not func then
        emitComment("Load Error: " .. (err or "unknown"))
        if outputPath then proxyTable.save(outputPath) end
        return false, err
    end
    local _DS_BLOCK = {
        io=true, os=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true, debug=true,
    }
    local _DS_OS = { clock=function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end, time=osLibrary.time, date=osLibrary.date }
    local dsEnv = setmetatable({
        _VERSION="Luau",
        io=nil, os=_DS_OS, debug=nil, dofile=nil, loadfile=nil,
        require=nil, package=nil, socket=nil, ffi=nil,
        collectgarbage=nil, newproxy=newproxy,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end,
    }, {
        __index = function(_, k)
            if _DS_BLOCK[k] then return nil end
            return _G[k]
        end,
        __newindex = _G,
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, dsEnv)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, dsEnv) end
        end
    end
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    xpcallFunction(function() func() end, function(e)
        emitComment("Runtime: " .. toStringFunction(e))
    end)
    setHook()
    if outputPath then return proxyTable.save(outputPath) end
    return true, getFullOutput()
end
do
    local bypassPath = (arg and arg[0] and arg[0]:match("^(.+[\\/])")) or ""
    local ok, err = pcall(dofile, bypassPath .. "bypass.lua")
    if not ok then
        local ok2 = pcall(dofile, "bypass.lua")
        if not ok2 then
            printFunction("[dumper] bypass.lua not found, continuing without supplement")
        end
    end
end

_G.LuraphContinue = nil
if not rawget(_G, "__FLAMEDUMPER_REQUIRE_ONLY") then
    if arg and arg[1] then
        local success = proxyTable.dump_file(arg[1], arg[2])
        if success then end
    else
        local file = ioLibrary.open("obfuscated.lua", "rb")
        if file then
            file:close()
            local success = proxyTable.dump_file("obfuscated.lua")
            if success then
                printFunction(proxyTable.get_output())
            end
        else
            printFunction("Usage: lua dumper.lua <input> [output] [key]")
        end
    end
end
return proxyTable
, func=function: 0x7528342fc0f0")
print("  Level 4: source=--[[ v1.0.0 https://wearedevs.net/obfuscator ]]--[[ v1.0.0 https://wearedevs.net/obfuscator ]] return(function(...)local Z={"\106\069\102\117\087\098\054\087","\085\050\088\061","\122\110\112\085\065\081\110\072";"\114\054\116\075\085\048\079\072\105\114\079\099\105\051\085\070\098\083\108\061","\068\114\077\052\097\055\101\070\122\121\087\055\120\083\089\086\120\068\114\085\074\067\085\108\098\104\067\048\043\089\119\120\047\090\075\061","\070\057\101\051\121\119\048\081";"\117\070\118\085\110\111\081\054";"\072\111\110\079\047\110\052\121","\081\079\065\067\112\089\061\061";"\113\049\090\066\083\088\115\049","\070\114\102\120\085\047\079\069\114\076\086\051\067\072\086\055\116\116\061\061";"\081\103\083\065\043\048\104\061","\097\109\105\067\049\047\082\074\108\121\113\048\073\072\065\052\074\107\074\101\083\082\101\086","\086\083\085\100\122\070\085\100\099\081\067\066\099\110\071\106","\051\083\079\085\102\122\103\122\069\071\100\118\070\114\076\055\053\066\107\048\078\084\111\090\074\077\073\073\106\098\056\052\118\119\111\043\109\068\053\077\080\051\065\075\111\057\081\067\121\109\115\113\052\043\080\051\071\057\054\056\072\048\120\122\051\089\061\061";"\084\053\068\055\109\104\054\054\068\115\061\061","\072\121\083\077\109\111\056\109","\070\047\050\067\053\118\113\076\112\117\076\108\101\077\104\076\065\116\061\061";"\073\051\079\090\122\121\116\061","\106\110\071\107\050\097\088\101";"\098\113\055\043\080\047\113\085\087\074\119\105\122\072\101\104\082\112\073\061","\068\051\072\047\089\098\112\067\077\107\121\110\110\122\075\121\097\115\056\101\102\083\075\061";"\107\082\105\104\087\120\100\088\075\070\114\087\099\089\061\061";"\090\110\081\075\082\116\061\061","\068\070\078\075\099\070\043\050";"\104\078\086\101\103\107\054\102\071\043\099\100\049\053\081\100\120\099\057\052\121\104\101\088\057\112\050\122\050\120\090\106\051\115\053\105\057\075\113\082\088\110\089\077\109\100\074\113\115\051\073\072\099\106\050\070\054\097\075\120\070\075\050\100\108\084\110\078\116\112\115\078\081\113\116\054\118\110\086\050","\118\066\088\108\067\122\119\052","\081\087\102\090\122\110\067\106\082\115\061\061";"\079\089\061\061","\122\111\111\065\114\087\073\100\070\110\071\098\105\114\086\086";"\057\043\074\113\101\087\073\050\100\081\057\088\098\105\057\109\053\115\048\054\109\072\071\066\099\047\050\077\120\089\061\061","\074\100\066\048\105\100\090\120\043\110\088\071\085\100\118\075";"\108\077\079\050\052\115\061\061";"\068\100\068\079\098\110\102\075\068\105\067\065\043\072\043\098\043\076\089\061","\086\116\061\061";"\116\105\086\069\070\054\043\074\082\051\090\121\082\106\077\090","\052\114\110\078\089\089\061\061","\081\087\102\104\086\070\101\061";"\065\114\106\074\065\076\111\114\114\083\089\061","\118\076\106\113\081\117\121\105\075\107\076\075\098\066\076\069";"\074\067\052\066\080\074\108\054\114\075\061\061","\100\116\061\061","\074\070\111\078\105\087\111\085\086\070\078\104\099\121\067\113\105\083\108\061","\074\072\067\057\073\106\068\076\043\048\114\071\122\076\067\067\073\105\089\061","\086\110\069\048\068\105\111\109\098\108\047\057\070\047\043\051\073\075\061\061","\070\105\074\116\118\069\075\061";"\074\104\120\047\082\101\120\120";"\099\121\106\100\086\116\061\061";"\086\052\069\061";"\119\115\061\061";"\054\067\071\053\104\047\076\054","\073\054\043\066\122\054\075\061","\085\070\043\110\067\055\079\113\086\110\067\084\122\087\068\049\114\110\047\061";"\122\070\111\100\074\115\061\061";"\073\083\078\085\043\100\068\079\114\070\043\120\086\100\090\069\073\048\069\061","\088\055\110\115\103\087\079\109\065\120\120\088\113\115\061\061","\051\067\101\070\083\052\099\061","\108\105\110\077\057\116\061\061";"\122\048\090\097\074\081\068\113\105\070\101\078\085\055\108\057";"\082\081\122\102\070\097\066\113";"\082\073\097\080\113\082\098\065\106\119\051\055\066\089\061\061","\055\069\087\103\069\071\051\076\047\086\054\103\101\085\084\075\104\084\098\061","\048\084\057\118\116\116\085\088\100\098\121\049\081\104\047\115\114\110\069\079\071\107\067\055\086\067\105\056\088\084\122\068\109\057\105\113\117\089\061\061","\065\105\043\109\098\085\085\109\065\072\111\075\105\106\079\104\116\075\061\061","\056\089\061\061";"\099\079\071\089\105\074\049\086","\086\048\043\087\099\089\061\061","\050\067\117\043";"\088\101\105\113\055\080\078\078\118\055\097\107\057\117\088\107\081\083\121\114\065\107\054\106\113\107\099\085\104\055\118\103\122\050\065\073\053\106\098\097\120\087\057\065\103\088\053\122\070\097\117\116\105\080\105\114\090\121\043\116\065\108\049\080\101\048\069\061";"\119\109\119\116\049\072\043\071";"\099\070\118\108\116\114\068\083\098\110\087\099\114\111\086\056\073\115\061\061";"\115\098\102\080\099\070\077\049\115\100\048\107\079\053\120\070\057\050\057\072\108\072\055\082\081\074\072\088\112\112\103\111\101\047\101\113\115\108\081\076";"\049\043\112\055\114\066\049\065";"\086\083\087\066\068\054\043\069","\049\054\069\088\120\078\073\050\121\088\083\077\113\051\087\087\115\110\084\117\079\049\068\067\086\080\050\082\090\089\061\061","\117\054\100\061";"\081\100\073\061","\122\054\085\084","\076\051\066\068\105\056\053\069\067\089\061\061","\120\106\049\068\088\086\066\081\119\048\117\100\108\105\047\082\047\113\089\061";"\115\085\115\106\073\115\061\061";"\120\069\098\107\110\087\103\084\117\082\077\077\111\088\050\056";"\083\067\055\068\117\080\090\098\065\052\081\120\054\109\056\052\101\118\112\084\115\057\088\108\077\117\086\098\111\073\066\114\100\114\104\114\081\065\065\106\085\108\056\067\109\053\108\098\043\076\085\073\111\070\098\055\081\109\104\067\050\089\061\061","\082\051\077\072\099\070\071\104","\118\047\055\048\054\043\090\078";"\104\100\114\117\057\049\099\055\068\080\089\084\082\107\107\075\108\120\115\057","\073\048\067\057\074\070\078\121";"\110\121\072\055\120\116\061\061","\102\103\118\074\053\106\080\081";"\121\075\061\061";"\086\083\085\100\086\110\085\084\068\089\061\061";"\067\100\066\076\085\108\047\057\068\051\106\114\122\076\077\078\085\047\101\061","\053\115\061\061","\073\048\108\084\049\086\118\112","\122\054\102\048\086\081\109\061","\122\055\047\061";"\070\106\106\121\099\110\067\084","\049\087\114\061";"\070\122\118\086\116\068\116\078";"\117\066\115\122\054\117\085\067\080\075\089\061";"\087\073\090\085\089\114\083\074\101\113\083\098\110\118\083\078\116\117\108\085\079\054\066\106\082\117\121\076\078\115\051\103\069\112\056\048\122\112\119\076\097\102\114\051\112\104\054\049\075\053\055\121\081\050\074\078\113\066\074\050\069\088\115\080\072\054\104\111\065\108\051\082\081\068\122\117\049\101\086\048\103\049\051\075\121\083\119\080\049\071\104\105\084\051\079\083\085\056\109\089\099\084\118\054\076\049\073\120\050\049\098\061","\073\054\111\090\073\121\098\061";"\102\075\084\043\054\054\107\069\121\097\067\112\047\099\111\099";"\122\121\068\071\068\105\089\101\085\083\106\079\105\100\067\108","\085\054\086\048\099\121\086\075\116\105\066\070\122\072\106\050\043\110\075\061";"\043\122\089\067\047\121\099\057\104\049\098\061","\069\067\114\115\122\098\087\074";"\082\121\067\080\068\081\043\048\070\098\048\083\111\082\112\067\114\079\119\054\074\108\072\072\053\089\061\061";"\068\054\102\084\068\070\087\056\086\081\109\061","\101\099\119\047\079\103\102\079\116\071\105\116\075\115\100\069\073\115\113\102\065\115\061\061","\086\055\043\076\116\106\068\055\043\121\085\047\065\070\078\066\073\047\075\061";"\098\051\068\051\082\110\071\057\068\047\108\100\073\106\079\079\067\054\104\061";"\073\120\076\106\055\067\078\116\109\099\081\099\079\116\061\061","\111\116\056\075\102\078\065\072\079\071\086\087\088\118\108\043\055\120\088\104\073\116\061\061";"\114\054\102\109\098\106\043\050\065\114\067\120\074\108\079\098\116\089\061\061","\108\100\073\083\079\100\069\122\103\089\061\061","\122\106\066\121\105\105\115\048\067\100\102\097\073\100\043\078","\098\098\050\087\088\104\097\054";"\065\075\111\083\106\098\104\061","\047\115\112\099\106\116\061\061","\108\112\069\079\065\099\099\056";"\122\100\086\075\097\047\106\090\097\047\102\070\074\072\109\071\099\075\061\061","\077\103\101\061","\119\051\075\061";"\078\115\068\115\119\077\072\069\109\107\120\109\103\099\105\076\056\070\088\061","\097\056\089\106\086\113\069\090\097\089\061\061","\083\066\078\079\043\111\100\061";"\086\110\071\049\122\048\109\061";"\080\070\047\066\103\082\066\117\107\111\056\117\104\054\103\052","\086\109\073\065\102\119\120\052","";"\098\100\052\048\054\107\050\056","\111\108\109\061";"\068\054\111\056\122\054\114\061","\113\102\047\066\117\054\079\120\048\105\108\053\052\118\118\099\077\080\083\116\087\086\106\055\114\117\056\106\078\107\120\085\069\102\086\077\114\114\098\061","\119\118\066\068\069\116\061\061";"\068\054\102\076\068\051\079\090\122\110\073\061","\067\085\084\110\054\067\114\061","\065\089\086\043\118\048\112\112\050\067\121\069\077\089\061\061";"\120\078\116\100\052\068\055\107\087\104\088\061";"\099\089\061\061";"\103\111\051\075\110\053\067\109","\068\083\111\057\122\089\061\061";"\067\083\085\100\114\083\085\057\068\110\106\072\086\116\061\061","\074\085\106\051\098\081\043\081\082\081\106\047\085\070\078\087\085\075\061\061","\068\051\106\075\086\116\061\061";"\122\081\047\057\074\111\085\085\043\110\079\080\070\055\047\078","\107\101\048\083\070\084\101\057","\074\083\071\087\122\070\102\079\074\070\118\065\114\100\090\071";"\073\110\085\066\086\115\061\061","\051\069\082\076\082\076\083\054";"\047\105\110\082\056\084\118\105\056\115\061\061","\072\097\051\116\114\105\083\105\054\048\122\072\114\108\067\120\057\090\111\086\085\057\108\090\053\047\055\105\054\117\053\117\098\076\121\098\047\089\061\061","\077\107\055\076\052\048\076\119\121\075\061\061";"\073\084\106\085\117\118\113\082\077\084\106\112\082\116\061\061","\105\072\106\069\068\048\106\047";"\077\116\061\061","\102\122\057\079\114\082\088\067";"\113\116\109\061";"\098\076\068\113\070\106\085\051\085\054\071\120\065\047\100\087","\075\075\061\061";"\065\114\118\048\065\055\077\053\098\047\118\056\099\114\066\077\043\115\061\061","\078\116\061\061";"\067\110\115\061";"\099\083\066\066\073\089\061\061","\121\083\049\110\083\110\087\054","\051\099\057\101\071\115\061\061";"\073\083\085\100\122\070\085\100\099\081\067\066\099\110\071\106";"\105\047\102\120\066\051\068\057","\098\112\068\043\117\070\098\099\086\090\115\101\075\099\086\053\077\073\114\069\086\065\100\071\056\108\079\114\097\119\107\047\084\066\089\079\051\088\083\087\122\115\043\108\054\084\052\067\105\089\061\061","\106\087\110\070";"\077\089\069\080\097\106\098\051\052\121\102\086\099\087\104\057\081\048\087\067\081\115\061\061","\099\083\071\049\073\083\114\061";"\099\083\102\084\099\083\111\100","\070\104\043\056\120\089\072\101\066\121\082\103\052\099\076\122\078\081\077\088\086\110\104\090\048\117\055\075\106\110\043\086\065\068\106\055\100\055\043\106\069\049\083\065\122\105\115\099\066\113\066\054\066\100\097\099\122\109\078\054\072\097\105\071\099\071\069\088\080\102\069\082\110\047\087\074\065\070\086\053\114\107\107\071\081\119\116\069\103\121\118\076\050\074\076\115","\088\065\073\111\084\103\077\075";"\101\106\117\076\100\086\086\114\101\048\072\083\069\066\101\074\052\107\107\118\047\054\098\120";"\101\068\108\052\049\084\079\097\071\052\105\105\116\116\051\090\111\079\043\099\109\115\088\107\066\106\076\051\051\043\090\051\069\054\115\099\110\066\117\066\119\115\061\061","\085\121\086\057\070\108\066\113\086\076\085\066\085\075\061\061","\081\122\085\074\103\122\072\068\054\113\097\053\074\099\084\109\100\108\104\061";"\107\121\053\070\120\067\088\074\117\105\068\068\073\089\086\084\049\077\057\119";"\050\101\074\066\043\082\109\117";"\115\043\048\083\122\111\100\082";"\050\089\111\049\086\050\067\066\100\067\076\079\104\099\069\072\050\107\099\112\049\080\043\080\068\086\082\078\053\089\056\098\099\101\068\085\107\103\086\072\082\065\056\074\055\102\097\099\081\076\052\050\071\072\065\110\089\081\102\111\085\077\122\111\109\081\074\073\057\112\104\061","\114\081\086\075\074\100\043\084\065\048\086\054\114\051\068\110\074\075\061\061";"\103\051\043\086\070\107\119\103\056\116\061\061";"\086\115\061\061","\083\057\104\053\089\105\097\088";"\090\089\061\061";"\109\049\120\111\069\116\061\061";"\070\084\043\105\110\073\120\101\072\115\053\049\070\053\073\118\105\105\050\103\089\118\098\117\084\099\055\088\090\078\108\061","\073\048\085\056","\100\088\075\056\087\075\061\061";"\104\115\061\061";"\075\121\114\106\101\080\052\089","\082\087\047\061","\085\054\111\118\073\054\085\057\109\047\067\106\068\054\085\072\068\054\085\108\109\116\061\061";"\074\114\066\109\043\070\071\117\122\100\066\081\073\111\068\055\097\047\109\061";"\110\070\086\107\119\069\052\080\108\105\105\120\074\053\118\054\073\048\098\061","\113\066\085\074\118\105\112\066\117\052\047\061","\073\110\085\118\122\048\086\106","\086\081\079\057\122\048\109\061";"\071\052\050\120\073\108\048\051\070\104\053\078\099\113\104\121\055\105\086\065\067\080\049\066\077\110\078\076\106\104\116\080\113\110\069\122\066\070\053\080\048\074\087\122\084\049\081\082\068\111\114\048\074\111\065\105\073\098\111\116\103\052\122\084\090\117\102\057";"\105\097\080\089\078\089\050\107\052\085\105\121\098\103\110\105\083\043\089\061";"\081\087\102\118\086\081\067\066\068\054\111\056\122\054\114\061";"\109\049\066\097\085\053\049\081\068\114\070\052\050\047\098\061";"\074\081\077\066\074\081\079\076";"\122\083\071\108\081\083\086\087\122\110\098\061","\056\077\074\115","\068\056\069\054\055\101\075\086\049\116\061\061";"\116\051\072\119\065\065\078\052\106\053\102\120\108\065\114\061","\086\089\075\087\102\073\103\098","\122\055\109\061";"\097\102\052\089\113\110\082\071\089\089\061\061";"\101\116\070\078\083\089\114\104","\080\119\051\119\057\119\089\089","\081\087\102\121\099\075\061\061";"\078\072\098\120\109\114\110\065","\086\054\085\056\068\070\073\061";"\057\107\068\077\051\090\072\113\082\053\119\104\065\081\080\120\065\083\099\052\081\075\098\061","\122\070\111\100\099\083\089\061";"\097\089\061\061","\118\078\103\105\106\105\082\102\098\117\097\068\111\087\116\061";"\073\110\111\084\086\054\102\118";"\052\043\083\083";"\049\118\088\061","\074\066\106\079\116\090\075\077\090\050\080\107\070\110\082\066\090\115\075\107\102\116\061\061";"\085\122\113\101\122\114\082\066\113\066\071\084\109\115\061\061";"\078\078\074\051\057\101\077\075"}for r,H in ipairs({{-983622-(-983623),582911-582682},{-42380+42381;58532+-58329},{783279-783075;634403-634174}})do while H[-48180-(-48181)]<H[-59542+59544]do Z[H[295310-295309]],Z[H[-439832-(-439834)]],H[-844760+844761],H[982679-982677]=Z[H[-47968-(-47970)]],Z[H[690156-690155]],H[932292+-932291]+(-729376-(-729377)),H[-200230-(-200232)]-(-637546+637547)end end local function r(r)return Z[r+(-831654+875293)]end do local r=math.floor local H=string.char local m={A=313732+-313714;K=689509+-689461,v=-486423+486468;M=332827+-332826;O=-617126-(-617135),J=-296345-(-296371),z=-987189-(-987216);Q=170170+-170147,x=-937687+937745,L=-290914+290965,["\054"]=62726+-62720;C=1045568-1045551,["\055"]=918711-918708;d=-316309-(-316361),y=563252-563213,Z=444592-444551;N=588147+-588090,f=-197064-(-197125),["\043"]=276722+-276709;["\057"]=-228247-(-228297);E=299730-299690;k=906685+-906670;P=-760128-(-760138);Y=673054-673022,["\050"]=-409984+410027;F=392221-392199,h=358586-358542;u=-513314-(-513356),p=767508-767446;b=-144879+144891,X=-888445+888505;["\051"]=587015+-587008,q=498959+-498957;o=1036003+-1035998;j=-94017-(-94054);m=854391+-854383;S=601991-601937,D=-709823-(-709852);W=-408092+408145;U=-850847+850868,r=-24172+24192,H=-765275-(-765310);["\052"]=48615+-48556;B=-324312+324345;G=-379793+379842;["\053"]=605953-605942,n=114105-114067,["\049"]=726775-726728,t=-682957-(-682973);e=622504+-622448,a=337979+-337965,T=-899570+899616;V=618872+-618847;w=-659007-(-659038);g=-336968-(-337031);["\047"]=939881-939877;s=-60378+60378,["\056"]=186523-186489,R=-96756+96786;l=-74715+74751;i=-570405-(-570424);I=-355218+355246;c=891111-891087;["\048"]=-1022163-(-1022218)}local t=type local D=string.sub local Q=string.len local h=Z local E=table.insert local g=table.concat for Z=-973221+973222,#h,-419044+419045 do local J=h[Z]if t(J)=="\115\116\114\105\110\103"then local t=Q(J)local e={}local U=-801065-(-801066)local N=715717+-715717 local z=-330204+330204 while U<=t do local Z=D(J,U,U)local Q=m[Z]if Q then N=N+Q*(-141341-(-141405))^((9868+-9865)-z)z=z+(-706363-(-706364))if z==-903511+903515 then z=354026-354026 local Z=r(N/(527940+-462404))local m=r((N%(-523783-(-589319)))/(-559260+559516))local t=N%(311758+-311502)E(e,H(Z,m,t))N=-859895+859895 end elseif Z=="\061"then E(e,H(r(N/(657807+-592271))))if U>=t or D(J,U+(1043874-1043873),U+(645773+-645772))~="\061"then E(e,H(r((N%(642336+-576800))/(-185933+186189))))end break end U=U+(998655-998654)end h[Z]=g(e)end end end return(function(Z,m,t,D,Q,h,E,w,l,z,L,H,U,F,g,N,C,p,q,i,J,e,n)p,g,F,z,e,q,i,C,H,U,L,n,J,w,N,l=function(Z,r)local m=N(r)local t=function(t,D)return H(Z,{t;D},r,m)end return t end,{},function(Z,r)local m=N(r)local t=function(...)return H(Z,{...},r,m)end return t end,function(Z)local r,H=492273+-492272,Z[-726822-(-726823)]while H do J[H],r=J[H]-(-473021-(-473022)),r+(-194197+194198)if J[H]==657566+-657566 then J[H],g[H]=nil,nil end H=Z[r]end end,function()U=U+(-1020148-(-1020149))J[U]=-750878+750879 return U end,function(Z,r)local m=N(r)local t=function(t,D,Q)return H(Z,{t;D,Q},r,m)end return t end,function(Z,r)local m=N(r)local t=function()return H(Z,{},r,m)end return t end,function(Z)J[Z]=J[Z]-(-852532-(-852533))if 211630+-211630==J[Z]then J[Z],g[Z]=nil,nil end end,function(H,t,D,Q)local X,R,P,ZB,A,u,c,W,d,U,j,S,J,y,z,f,V,O,s,o,Y,k,G,a,x,I,E,K,N,T,B,M,v,rB,b,HB while H do if H<967384+7146251 then if H<4550938-69389 then if H<3429326-1037665 then if H<373100-(-989769)then if H<-342899-(-805699)then if H<658993+-461314 then if H<-418915+553364 then if H<387562-339910 then H=737344+15368520 M=nil else g[U]=u H=g[U]H=H and-833347+13777976 or 10643087-(-1017856)end else if H<-443465-(-606189)then A,M=j(R,A)H=A and 13672228-849869 or 4680166-(-785267)else H=15708282-(-993489)end end else if H<-462186+837715 then if H<-341008+669992 then H=E and 5503157-(-804814)or-562155+5325961 else I,M=A(j,I)H=I and 7539392-418687 or 1693585-(-284736)end else if H<-851692+1260032 then H=Z[r(-883185+839584)]M=21516934368428-1025417 a=r(-861406-(-817818))E=Y g[D[196468+-196465]]=E S=Z[a]I=r(188757+-232256)R=g[D[530907-530906]]A=g[D[953862-953860]]j=A(I,M)a=R[j]I=r(712759+-756310)R=g[D[-357427+357430]]S[a]=R R=g[D[-1005326-(-1005327)]]M=-164929+30291840269146 A=g[D[-809678+809680]]j=A(I,M)a=R[j]S=a..s E={S}else S=nil H=-66892+1973969 end end end else if H<1250352-413704 then if H<308509+439687 then if H<37476+613841 then H=S H=E and 1390142-997394 or 108729+2622798 else c,v=I(M,c)H=c and-14564+7702662 or 14726164-(-348129)end else if H<-413853+1182181 then H=68113+8267263 g[U]=E else a=r(625396+-668818)R=H S=Z[a]a=S(Y)H=a and-996030+12887799 or 5009548-(-504070)S=a end end else if H<433146-(-555002)then if H<-853721+1795798 then U=nil E=false g[D[-215747-(-215748)]]=E H=-969623+6784286 else E=1043352+-1043351 H=-542547-(-542547)U=434356-434256 N=U U=953502+-953501 z=U J=H H=1448309-(-961755)U=-151582-(-151582)s=z<U U=E-z end else if H<44768+1088668 then R=nil H=-821925+16316848 a=nil else A=H M=g[D[352959+-352957]]W=16195948605457-512668 u=r(-174363-(-130944))c=g[D[-109328+109331]]v=c(u,W)I=M[v]j=S[I]H=j and 2769815-128037 or 2768602-372498 R=j end end end end else if H<2363186-480616 then if H<1366631-(-348027)then if H<-126722+1712989 then if H<868740-(-678767)then a=285312+30490743201014 E=g[D[707788-707784]]S=r(-1017041+973484)z=g[D[418742-418740]]s=g[D[17474-17471]]R=r(-241622-(-198056))Y=s(S,a)N=z[Y]Y=g[D[912466-912464]]j=r(-630069-(-586477))A=16153800119947-(-558807)S=g[D[-1040570-(-1040573)]]I=15523589520635-(-925505)a=S(R,A)s=Y[a]z=U[s]E[N]=z N=r(-406460-(-363043))E=Z[N]Y=g[D[-73795+73797]]A=34586346189685-(-494452)S=g[D[-144388+144391]]R=r(-317095+273493)a=S(R,A)s=Y[a]a=g[D[807287+-807285]]R=g[D[-978772+978775]]A=R(j,I)S=a[A]Y=U[S]z=s..Y N=E(z)s=r(-887046-(-843600))z=Z[s]Y=g[D[453429-453427]]A=27585475139654-140825 R=r(-514057+470508)S=g[D[284180-284177]]a=S(R,A)j=33753088153212-(-960233)s=Y[a]N=z[s]s=549259+-549256 S=g[D[392264+-392262]]a=g[D[62039-62036]]A=r(-570655+527151)R=a(A,j)Y=S[R]R=31307146441469-211467 z=N(s,Y)a=r(309262-352890)s=g[D[520485+-520483]]Y=g[D[914800+-914797]]S=Y(a,R)N=s[S]E=z[N]N=E H=N and 9876231-831223 or-976837+2803737 else R=nil H=122011+222795 M=nil end else if H<2113131-464877 then H=u H=6345505-324161 c=v else Y=E S=r(302336+-345947)E=Z[S]S=r(-800734+757293)a=r(-593350+549819)H=E[S]S=e()g[S]=H E=Z[a]a=r(-527464-(-483973))H=E[a]a=H I=r(-310202+266671)j=Z[I]R=j A=H H=j and 13566043-369535 or-873838+17531117 end end else if H<147266+1623035 then if H<2409953-650062 then j=g[N]x=g[z]X=g[U]K=-641599+31920847897679 b=r(-396993-(-353562))H=8928111-624389 T=X(b,K)v=x[T]x=p(8293873-(-366830),{S,z;U})c=j(v,x)else N=5589686-313490 U=r(-267614+224046)E=34423+15773032 J=U^N H=E-J J=H E=r(335910-379536)H=E/J E={H}H=Z[r(-787531-(-743970))]end else if H<1428900-(-385032)then R=r(573129+-616648)a=Z[R]R=a(Y)A=g[D[-731181+731183]]j=g[D[716341+-716338]]c=-615739+12288461159317 M=r(-968951-(-925413))I=j(M,c)a=A[I]S=R==a H=S and 1013568+-244613 or 1895017-(-12060)else N=nil H=1523597-596677 end end end else if H<2574539-515732 then if H<-228113+2212883 then if H<1126822-(-799095)then s=nil Y=nil H=15407313-(-715770)else H=11350611-862037 end else if H<1002992-(-1006376)then S=r(217556+-261134)I=-396880+18498826760182 E=r(-811452-(-768035))j=r(62343+-105901)H=Z[E]Y=Z[S]a=g[D[850224-850223]]R=g[D[982967-982965]]A=R(j,I)j=r(622475-665941)S=a[A]s=Y[S]a=g[D[901137-901136]]I=-471960+25911722812090 R=g[D[553337+-553335]]A=R(j,I)j=H R=r(411790-455318)S=a[A]H=N and-779452+6235900 or 553538+11024421 a=Z[R]A=N else c=nil X=C(X)H=10133579-(-847692)end end else if H<-103187+2316232 then if H<1570825-(-573506)then s=r(-178643-(-135080))E=Z[s]H=147707+15347216 a={E(z)}s=a[643844+-643843]Y=a[-1034870+1034872]S=a[-534700+534703]else Y=g[s]H=460206+1209252 E=Y end else if H<-916286+3147857 then H=I H=j and-89122+16846827 or-370044+14085018 else H=-40060+8160234 end end end end end else if H<-287898+3530886 then if H<3196611-480606 then if H<1043179+1463012 then if H<1469075-(-945960)then if H<874218+1525119 then H=A H=15997658-888614 a=R else Y=not s U=U+z E=U<=N E=Y and E Y=U>=N Y=s and Y E=Y or E Y=1519801-(-1027376)H=E and Y E=378116+4048685 H=H or E end else if H<3251905-763918 then A=nil H=790179+2947219 else H=true g[D[888484+-888483]]=H E={}H=Z[r(92720+-136240)]end end else if H<3264800-619223 then if H<274374+2367006 then S=r(-1039218+995772)E=Z[S]j=r(840983+-884493)a=g[D[-366712+366713]]Y=U R=g[D[496271+-496269]]I=15256602039928-(-558408)A=R(j,I)S=a[A]H=E[S]a=g[D[99701-99698]]R={H(a,Y)}S=R[-333421+333423]E=R[-744910-(-744911)]a=E H=not a H=H and 13569456-50789 or 11786928-(-479431)else O=-4015+13677273032847 W=r(-149324+105748)c=g[D[-390820-(-390822)]]v=g[D[-375016+375019]]u=v(W,O)M=c[u]H=-846366+3242470 O=17323379028991-1021053 v=-825507+825508 c=1016575-1016574 I=S[M]M=r(888025-931498)M=I[M]W=r(949675+-993290)M=M(I,c,v)c=g[D[-365169+365171]]v=g[D[-863992-(-863995)]]u=v(W,O)I=c[u]j=M~=I R=j end else if H<452185+2199304 then H=Z[r(546913+-590463)]E={}else S=r(-117150+73572)j=r(-898019+854475)I=973775+13743852633392 E=r(195779-239301)H=Z[E]Y=Z[S]a=g[D[-671610+671611]]R=g[D[485529-485527]]A=R(j,I)j=r(473995-517433)S=a[A]s=Y[S]a=g[D[438348-438347]]I=246251+21766688286124 R=g[D[-922338-(-922340)]]A=R(j,I)S=a[A]R=r(391416-434944)a=Z[R]R={a(N)}Y={s(S,J,m(R))}E=H(m(Y))H=false E={H;N}H=Z[r(-458+-43047)]end end end else if H<2422551-(-397547)then if H<894831+1895538 then if H<3227823-497430 then s=N A=r(-626182+582663)c=r(-345994-(-302568))R=Z[A]A=R(Y)v=-136298+9115166205182 j=g[D[681119+-681117]]I=g[D[842911+-842908]]M=I(c,v)R=j[M]a=A==R S=a H=a and 8719383-741264 or 10131781-297283 else H=787991+11768889 Y=nil s=nil end else if H<8140+2806915 then y=847305+-847303 d=P[y]y=g[f]k=d==y H=6153077-98839 ZB=k else x=#M T=-599623+599624 v=-156193-(-156194)c=N(v,x)v=Y(M,c)x=g[I]H=858826+9979084 G=v-T X=S(G)x[v]=X c=nil v=nil end end else if H<874712+2041907 then if H<503451+2349749 then H=g[D[1042251-1042241]]U=g[D[-1009405-(-1009416)]]J[H]=U H=g[D[434867-434855]]U={H(J)}H=Z[r(818419+-862052)]E={m(U)}else H=N H=E and 429379+1066448 or 12331+914589 end else if H<508748+2457858 then H=733444+5643388 else J=g[D[-674054-(-674055)]]S=31278184577918-(-998759)Y=r(253217-296759)N=g[D[451108-451106]]z=g[D[122113+-122110]]s=z(Y,S)U=N[s]S=28769642403859-(-875585)s=r(-549637-(-506225))Y=94542+11098736435938 E=J[U]U=g[D[592245-592243]]N=g[D[-343696+343699]]z=N(s,Y)J=U[z]H=E[J]J=g[D[-824620+824624]]Y=r(991540+-1035129)N=g[D[-567526-(-567528)]]z=g[D[-935501+935504]]s=z(Y,S)U=N[s]E=H(J,U)J=E H=J and-502511+12527979 or 3803596-348541 end end end end else if H<-114336+4094878 then if H<3024466-(-463008)then if H<4028684-685081 then if H<2297592-(-989689)then c=g[D[-920528-(-920532)]]W=g[D[892083-892081]]G=525608+26583206718258 O=g[D[887044-887041]]X=r(-974200+930755)x=O(X,G)H=-1046487+1068433 u=W[x]v=u..s u=M c[v]=u else j=g[D[-595216+595217]]M=g[D[-665786-(-665788)]]u=r(-792000-(-748382))c=g[D[656529-656526]]R=H W=34351113866603-(-667920)v=c(u,W)I=M[v]A=j[I]a=A H=A and 9386855-(-901863)or 12841009-(-724491)end else if H<2674487-(-769066)then N=g[D[-15002-(-15008)]]U=N==J H=-254701+12195692 E=U else E=r(53760-97223)H=Z[E]N=g[D[1036127-1036125]]Y=r(661543-704997)S=544110+1926351910419 z=g[D[-1016081-(-1016084)]]s=z(Y,S)U=N[s]E=H(U)H=15798635-(-366825)end end else if H<-499644+4355410 then if H<2789544-(-953832)then H=-82640+523481 R=nil else R=g[D[-492563+492564]]M=122941+30591324100456 I=r(-740810-(-697194))A=g[D[30542-30540]]j=A(I,M)E=R[j]H=S[E]H=H and 508592+2410739 or-53056+6429888 end else if H<4919948-1011561 then s=35184372651125-562293 H={}g[D[269353-269351]]=H E=g[D[-369391+369394]]S=944194-943939 z=E E=U%s g[D[-150713+150717]]=E Y=U%S S=116579-116577 a=r(695783+-739361)s=Y+S H=13119222-(-469464)g[D[-949974-(-949979)]]=s S=Z[a]a=r(435159-478746)Y=S[a]S=Y(J)A=373255-373254 Y=r(-409321-(-365787))N[U]=Y a=868194-868193 Y=606866+-606638 j=A R=S A=-1037698-(-1037698)I=j<A A=a-j else H=14467382-(-83132)c=x end end end else if H<4908813-564211 then if H<258887+3802182 then if H<3804804-(-235600)then c=not M A=A+I R=A<=j R=c and R c=A>=j c=M and c R=c or R c=7348440-149531 H=R and c R=837127+9245293 H=H or R else A=r(694919+-738330)R=Z[A]H=-453332+16107106 E=R end else if H<3137870-(-940633)then Y=U j=r(145901+-189427)S=r(62123+-105569)E=Z[S]I=3379201416108-(-830073)a=g[D[978490+-978489]]c=-902192+18106209117471 R=g[D[169641+-169639]]A=R(j,I)S=a[A]H=E[S]a=g[D[-30755+30758]]R={H(a,Y)}E=R[-978180+978181]a=E M=r(824109-867574)S=R[950376-950374]R=r(338565+-382084)E=Z[R]R=E(S)A=g[D[196919-196918]]j=g[D[-807138+807140]]I=j(M,c)E=A[I]H=R==E H=H and-533671+7887471 or 932867+3444214 else H=862633-735960 W=j==I u=W end end else if H<4095659-(-261795)then if H<4843617-498457 then E=r(-278099-(-234525))H=Z[E]U=r(388633+-432050)J=Z[U]E=H(J)J=E H=J and-481229+5670391 or 10258140-(-651282)E=J else Y=not s U=U+z E=U<=N E=Y and E Y=U>=N Y=s and Y E=Y or E Y=4356125-284519 H=E and Y E=7551718-212723 H=H or E end else if H<4710855-331794 then Y=nil S=nil H=3909226-(-445909)a=nil else S=r(-332996+289508)N=r(436388+-479916)U=Z[N]a=17178623580967-474088 N=U(J)z=g[D[-108833+108834]]s=g[D[264907-264905]]Y=s(S,a)U=z[Y]H=N..U E={H}H=Z[r(-581064-(-537597))]end end end end end end else if H<409696+5963179 then if H<5508177-42025 then if H<762383+4266700 then if H<-33690+4900009 then if H<5236359-499996 then if H<797857+3704519 then U=g[D[-868312-(-868314)]]N=g[D[160338-160335]]H=1013451-735768 J=U==N E=J else H=Z[r(958635-1002241)]E={}end else if H<5294790-479273 then H=g[D[36126+-36119]]H=H and-768010+13585965 or 109871+7288722 else H=4860694-(-213628)end end else if H<438055+4506461 then if H<5855060-972987 then H=nil U=-276993-(-277003)N=U E=-127695+127696 U=-523450+523451 J=H z=U U=-820929+820929 H=3497270-(-857865)s=z<U U=E-z else V=486612+35135465837333 b=H f=g[S]k=g[z]d=g[U]o=r(951777+-995246)y=d(o,V)P=k[y]K=f[P]H=K and 596061+10709885 or 171436+5170924 T=K end else if H<250465+4750114 then c=13441873703086-530491 A=g[D[-803191+803192]]H=513243-42401 M=r(-51140-(-7634))j=g[D[581183+-581181]]I=j(M,c)R=A[I]a=Y[R]E=a else z=nil J=nil U=nil H=Z[r(-644648-(-601095))]N=nil E={}end end end else if H<5942814-653010 then if H<656223+4535902 then if H<4911819-(-258466)then s=H I=r(-951932+908503)S=g[D[-165506-(-165511)]]M=-327699+10469816292126 R=g[D[796348+-796346]]A=g[D[-564863-(-564866)]]j=A(I,M)a=R[j]Y=S[a]E=Y H=Y and 10585831-449247 or-917289+6711065 else a=482353+3021278259533 z=g[D[-246049+246050]]s=g[D[278939-278937]]S=r(-598769+555330)Y=s(S,a)H=11559180-649758 N=z[Y]U=J[N]E=U end else if H<4316943-(-968998)then s=r(-137689-(-94157))U=g[D[-44809-(-44810)]]Y=31918+26925888877644 N=g[D[750898+-750896]]z=N(s,Y)Y=r(60731+-104254)E=U[z]H=J[E]g[D[-812487-(-812490)]]=H H=Z[r(-1082818-(-1039275))]S=8614890830283-944672 U=r(839088-882676)E=Z[U]N=g[D[-386725-(-386726)]]z=g[D[452960-452958]]s=z(Y,S)U=N[s]N=g[D[588320+-588317]]E[U]=N U=g[D[307189+-307188]]Y=13660995679365-(-353364)s=r(-190318+146895)N=g[D[600269-600267]]z=N(s,Y)E=U[z]E={E}else H=g[D[-966461+966465]]ZB=8012954293868-(-1030183)u=g[D[996406+-996405]]b=r(-284618-(-241018))x=r(-341459+298032)W=g[D[-803569+803571]]X=30750708262286-(-545377)O=W(x,X)K=23564601682608-131027 v=u[O]W=g[D[-465832+465837]]P=r(-532263+488787)X=g[D[-45538-(-45539)]]G=g[D[802156-802154]]T=G(b,K)x=X[T]b=g[D[-885572+885573]]K=g[D[-905894+905896]]f=K(P,ZB)T=b[f]G=T..I X=a..G O=x..X u=W..O c=v..u v=M H[c]=v c=-704608+704609 H=J+c J=H H=6259092-(-585446)end end else if H<6169680-757929 then if H<201580+5145009 then H=b H=T and-934359+12252424 or 10809963-(-1043187)else H=A H=a and 6933278-859247 or 4342323-604925 end else if H<-1039985+6501772 then H=j R={a(A)}Y={s(S,J,m(R))}E=H(m(Y))H=true E={H;N}H=Z[r(-407977-(-364429))]else A=r(635014-678577)H=-861258+1206064 R=Z[A]M={R(S)}j=M[459813+-459811]I=M[-413170+413173]A=M[-894196-(-894197)]end end end end else if H<-256269+6060251 then if H<-859198+6493293 then if H<-1014561+6628477 then if H<5575830-36229 then H=R H=S and 10950832-(-921426)or 922384+13561545 else E=r(-230971+187408)H=-678087-(-678087)J=H H=Z[E]z=g[D[-657183+657184]]s={H(z)}U=s[734962+-734960]E=s[-771927-(-771928)]N=s[71579+-71576]z=E H=16568299-1048497 end else if H<215071+5405424 then N=N+s U=N<=z S=not Y U=S and U S=N>=z S=Y and S U=S or U S=9722876-(-1021956)H=U and S U=1867851-(-980601)H=H or U else H=-448574+8568748 end end else if H<6276118-606009 then if H<-518969+6179830 then v=#M x=4624+-4624 c=v==x H=3290228-475125 else k=21217151767921-(-626983)H=X X=e()g[X]=c b=g[z]V=477480+2997148859467 K=g[U]P=r(-342559+299087)o=r(-406215+362765)f=K(P,k)T=b[f]c=x[T]b=#a d=r(1045545+-1089153)HB=4531606518096-(-134894)K=985902+-985901 T=b+K f=g[z]P=g[U]y=26553+20663203872221 k=P(d,y)rB=r(-726551-(-682967))K=f[k]f=g[R]k=g[z]d=g[U]y=d(o,V)P=k[y]k=g[X]y=g[z]o=g[U]V=o(rB,HB)d=y[V]b={[K]=f,[P]=k,[d]=c}o=r(222814-266267)a[T]=b V=705527+11390553428161 b=r(-447808-(-404391))T=Z[b]P=r(-528558-(-484980))f=Z[P]k=g[z]d=g[U]y=d(o,V)P=k[y]o=r(78101+-121694)K=f[P]k=g[z]d=g[U]V=34562305501586-748212 y=d(o,V)P=k[y]o=r(-94050+50522)k=g[R]d=g[X]y=Z[o]o={y(c)}f={K(P,k,d,m(o))}P=r(-355897+312424)d=-710848-(-710849)b=T(m(f))V=-1043797+18275461320339 k=140892+-140891 b=H o=r(-672659-(-629181))f=g[X]P=f[P]P=P(f,k,d)k=g[z]d=g[U]y=d(o,V)f=k[y]K=P~=f T=K H=K and-850821+7874906 or 10305391-1018900 end else if H<-502456+6286481 then K=r(-431335+387763)f=-697965+19403510172088 c=g[D[-536628+536632]]G=-622692+28096208843647 X=r(366267-409792)H=2357495-774439 W=g[D[344107+-344106]]O=g[D[-608420+608422]]x=O(X,G)u=W[x]ZB=r(848278+-891901)O=g[D[705856-705851]]G=g[D[-611842-(-611843)]]T=g[D[729134-729132]]B=-940941+33125791750094 b=T(K,f)X=G[b]K=g[D[1041000+-1040999]]f=g[D[34973-34971]]P=f(ZB,B)b=K[P]T=b..R G=a..T x=X..G W=O..x v=u..W u=M c[v]=u v=-9113+9114 c=J+v J=c else H=s H=E and-710532+15873604 or 12785315-(-1021323)end end end else if H<-649101+6805969 then if H<7064332-1024956 then if H<747160+5164580 then N=r(64855-108312)H=Z[r(-651486-(-607864))]U=Z[N]N={U(m(J))}E={m(N)}else H=c and 432212+4857381 or 7383578-539040 end else if H<71363+5993829 then E=ZB H=B H=-613131+1378099 else H=-33388+16139252 A=r(-278481-(-234953))W=r(540398+-583983)a=Z[A]A=a(R)O=755410+27908111231985 c=g[D[-702161+702163]]v=g[D[322381-322378]]u=v(W,O)M=c[u]c=r(-931486+887895)c=A[c]c={c(A,M)}I=c[-703217+703220]j=c[671636+-671634]a=c[-219330-(-219331)]end end else if H<-204801+6513576 then if H<5238164-(-1045801)then v=-704630+1892660839399 R=r(897421+-940838)c=r(-193399-(-149803))a=Z[R]j=g[z]I=g[U]M=I(c,v)A=j[M]R=a(A)a=g[N]c=r(215443-258983)j=g[z]I=g[U]v=-248325+25286859094020 M=I(c,v)A=j[M]j=q(-570529+4915392,{z,U;S})R=a(A,j)R=g[S]a=not R H=a and-166739+6805138 or 13647702-(-706681)else z=r(-1023790-(-980262))E=r(-726371-(-682815))a=r(-55719+12106)H=Z[E]J=g[D[-732970-(-732974)]]R=n(933753+6772556,{})N=Z[z]S=Z[a]a={S(R)}S=1016832+-1016830 Y={m(a)}s=Y[S]z=N(s)N=r(-876700-(-833161))U=J(z,N)J={U()}E=H(m(J))U=g[D[229282-229277]]J=E H=U and 2402071-(-1001945)or-174616+12115607 E=U end else if H<5953744-(-369369)then c=v H=-291016+12827215 T=c M[c]=T c=nil else H=14161143-(-322786)R=nil end end end end end else if H<6458546-(-694695)then if H<6966722-224550 then if H<891416+5732725 then if H<390277+6129632 then if H<6366856-(-56982)then E=r(236223-279786)H=Z[E]j={H(S)}R=j[683910+-683908]A=j[304719-304716]H=1028976+-875875 E=j[936358+-936357]j=E else R=r(-978823-(-935406))v=-723028+14421383209615 a=Z[R]c=r(-63708+20126)j=g[z]I=g[U]M=I(c,v)A=j[M]R=a(A)R=394765+-394763 a={}A=425220+-425205 j=A H=4099108-103541 A=-15743-(-15744)I=A A=969691+-969691 M=I<A A=R-I end else if H<5536668-(-1009089)then d=r(154428+-198006)f=r(-1026719+983302)HB=133759+32382725173352 K=Z[f]k=Z[d]y=g[z]rB=r(512438-556033)o=g[U]V=o(rB,HB)d=y[V]P=k[d]y=g[z]rB=r(-1023481+980007)HB=849619+7321060628094 o=g[U]V=o(rB,HB)rB=72342+-71842 d=y[V]V=145840+-145839 HB=r(384040-427513)y=#T HB=T[HB]o={HB(T,V,rB)}k={P(d,j,c,y,m(o))}H=9931721-329965 f=K(m(k))else H=g[D[-603674-(-603679)]]S=r(393312+-436864)z=g[D[1006766-1006764]]a=-601775+24759733181368 I=6818884114096-(-341431)s=g[D[-350692+350695]]j=r(-983909+940273)Y=s(S,a)N=z[Y]s=g[D[-383490-(-383496)]]a=g[D[514342-514340]]R=g[D[600500-600497]]A=R(j,I)S=a[A]a=g[D[-931533+931537]]Y=S..a S=r(-469189+425675)z=s..Y E=N..z N=U H[E]=N E=#U z=g[D[656341-656339]]s=g[D[913620-913617]]a=18150576205898-(-340154)Y=s(S,a)N=z[Y]H=E..N E={H}H=Z[r(978239-1021719)]end end else if H<6535770-(-146915)then if H<10145+6631800 then R=r(-205732-(-162269))a=Z[R]v=18949908665252-897324 H=13671080-(-683303)j=g[z]c=r(-208092+164599)I=g[U]M=I(c,v)A=j[M]R=a(A)else B=g[U]H=B and 123744+13376130 or 13769372-949960 ZB=B end else if H<7123691-413152 then J=g[D[-713045-(-713046)]]E=#J J=313434-313434 H=E==J H=H and 15177573-125612 or 6968866-76297 else U=r(14489+-58052)E=Z[U]H=76447+12480433 s={E(J)}z=s[265340+-265337]N=s[-379856+379858]U=s[-655649+655650]end end end else if H<6034609-(-858301)then if H<-523083+7341059 then if H<979216+5819082 then X=r(-796081-(-752579))R=g[D[-943844+943848]]I=g[D[-855455-(-855456)]]u=r(-418291-(-374726))M=g[D[470751-470749]]W=-300820+17376380335791 G=33076884141274-(-902992)v=M(u,W)j=I[v]M=g[D[267108+-267103]]W=g[D[1036887-1036886]]O=g[D[-538697-(-538699)]]x=O(X,G)u=W[x]v=u..a I=M..v A=j..I j=S R[A]=j A=988597-988596 H=10192287-(-296287)R=J+A J=R else H=-791183+791183 J=H E=r(-278908-(-235345))H=Z[E]Y=g[D[-776579+776580]]a=g[D[-795285+795287]]I=53466+17981139898331 R=g[D[882204+-882201]]j=r(-88979+45524)A=R(j,I)S=a[A]s=Y[S]j=26127935528867-684061 S=g[D[-376156-(-376158)]]a=g[D[898606+-898603]]A=r(-573151+529662)R=a(A,j)Y=S[R]z=s[Y]s={H(z)}N=s[-443690+443693]U=s[809522+-809520]H=15221800-(-901283)E=s[700561+-700560]z=E end else if H<7586151-739858 then I=nil H=-276767+429868 M=nil else N=r(-305049+261518)U=Z[N]N=r(75143-118607)J=U[N]N=g[D[-546964-(-546965)]]U={J(N)}E={m(U)}H=Z[r(932587-976141)]end end else if H<215978+6828239 then if H<-265895+7275800 then A=r(-865307+821788)s=z S=H R=Z[A]A=R(Y)j=g[D[-541401+541402]]I=g[D[304903+-304901]]v=13233614012601-731303 c=r(171359-214886)M=I(c,v)R=j[M]a=A==R H=a and 5954354-1006162 or 838217-367375 E=a else f=g[X]P=r(166134-209607)P=f[P]k=-372791+372792 V=-66921+33157242732985 d=595365+-595364 P=P(f,k,d)k=g[z]d=g[U]H=9709089-422598 o=r(736442-780072)y=d(o,V)f=k[y]K=P~=f T=K end else if H<-963886+8061809 then U=J z=r(468474-512062)H=Z[r(890952+-934384)]R=-596062+549123217757 a=r(-1038776-(-995241))g[D[985401-985398]]=U N=Z[z]s=g[D[-235618+235619]]Y=g[D[-480208-(-480210)]]S=Y(a,R)z=s[S]a=740765+13330249386658 S=r(-455082+411492)s=J N[z]=s z=g[D[351196-351195]]s=g[D[645254+-645252]]Y=s(S,a)N=z[Y]E={N}else R=I O=r(-830920-(-787401))W=Z[O]v=H O=W(M)x=g[D[-471214+471215]]T=r(431934+-475404)X=g[D[-903280+903282]]b=-580296+33747858741291 G=X(T,b)W=x[G]u=O==W H=u and 14515360-254456 or-328506+14082197 c=u end end end end else if H<7284633-(-122094)then if H<-535813+7808469 then if H<7889590-701976 then if H<1025623+6150813 then B=H y=855653+-855652 d=P[y]y=false k=d==y ZB=k H=k and 3154335-345564 or-380918+6435156 else z=r(-370012+326484)a=r(735801-779262)N=Z[z]z=N(J)H=Z[r(315398-359019)]s=g[D[-387587-(-387589)]]Y=g[D[619697+-619694]]R=982288+10910897018568 S=Y(a,R)N=s[S]U=z..N E={U}end else if H<7449301-193246 then R=e()d=8851620801583-72726 b=r(997472+-1040918)v=r(882397+-926010)g[R]=A c=Z[v]T=Z[b]K=g[z]k=r(-208555+165076)f=g[U]P=f(k,d)k=r(-540279-(-496845))b=K[P]d=547507+6940496490988 X=T[b]T=g[R]K=g[z]f=g[U]P=f(k,d)b=K[P]K={c(X,T,b)}x=K[447862+-447860]X=H v=K[764886+-764885]H=v and-88305+4041871 or 15547318-996804 c=v else a=r(104358-147920)H=g[D[163417-163416]]s=g[D[959322+-959320]]Y=g[D[-799920-(-799923)]]R=-530242+11641416985710 S=Y(a,R)z=s[S]s=g[U]N=z..s z=q(13006+960156,{D[533000+-532998];D[798884+-798881],J;D[-191395-(-191399)],U})U=C(U)E=H(N,z)H=Z[r(-995148-(-951513))]J=C(J)E={}end end else if H<1008359+6337854 then if H<6654230-(-631156)then H=Z[r(678286+-721906)]E={U}else H=not J H=H and 383496+15885355 or-664816+8772767 end else if H<8176602-811388 then H=Y J=H Y=nil H=1028789+6310206 a=nil S=nil else H={}J=H N=g[D[976020-976011]]z=N U=-802126-(-802127)N=471719+-471718 s=N N=-882082-(-882082)H=4796752-(-817491)Y=s<N N=U-s end end end else if H<727584+7232945 then if H<-338141+8016325 then if H<7535874-(-86459)then x=r(-978416-(-934964))H=Z[x]x=r(-835210+791641)Z[x]=H H=2716043-444498 else P=r(481519-525027)b=g[z]K=g[U]H=4751448-(-915602)k=522086+6722076382420 f=K(P,k)T=b[f]c=T end else if H<214492+7482506 then H=818835-125537 T=r(-263788+220260)j=c X=Z[T]T={X(v)}j=nil x=R(v,m(T))v=nil else N=588254+2916277 E=212821+12315264 U=r(-364927+321418)J=U^N H=E-J J=H E=r(-743321+699835)H=E/J E={H}H=Z[r(-47534-(-4109))]end end else if H<-514185+8525675 then if H<8086067-106762 then R=#Y A=-835283+835383 a=R>A H=363651+9470847 S=a else N=C(N)v=C(v)c=nil s=C(s)M=nil S=C(S)j=nil a=nil U=C(U)v=-783300+783556 z=C(z)A=C(A)Y=nil c=-155386-(-155387)R=C(R)N=nil Y=r(-244354+200743)I=nil U=nil z=e()g[z]=U U=e()M={}g[U]=N s=Z[Y]Y=r(-306358-(-262821))H=195170+12341029 S=r(-816162+772551)N=s[Y]s=e()A=e()g[s]=N R=r(230457-274035)Y=Z[S]a=r(-226413-(-182882))S=r(-392408+348967)N=Y[S]S=Z[a]a=r(-745590+702126)Y=S[a]a=Z[R]R=r(861815-905315)S=a[R]a=-978186-(-978186)j={}R=e()g[R]=a x=v v=913480-913479 X=v a=-686922-(-686924)I=e()v=-171580+171580 g[A]=a g[I]=j j=270372-270372 a={}G=X<v v=c-X end else U=r(-335755-(-292309))Y=r(-737157-(-693553))E=Z[U]N=g[D[189647+-189646]]S=5445977202941-(-452842)z=g[D[-60757-(-60759)]]s=z(Y,S)U=N[s]H=E[U]N=F(-227918+13095337,{D[792449-792445],D[787617-787616];D[394714+-394712],D[100186-100181],D[-654302+654308]})U=g[D[-95850-(-95853)]]E=H(U,J,N)U=E E=r(163016-206433)a=-944991+32939250952009 H=Z[E]z=g[D[-286315+286316]]S=r(-977015-(-933432))s=g[D[-342444+342446]]Y=s(S,a)N=z[Y]E=H(N)Y=715018+9937441483017 E=g[D[-364472-(-364473)]]N=g[D[189960-189958]]s=r(-417334-(-373779))z=N(s,Y)H=E[z]E={H}H=Z[r(260332-303905)]end end end end end end else if H<12175255-124981 then if H<10806425-732329 then if H<9801736-512559 then if H<8884901-394673 then if H<546857+7777669 then if H<-104326+8351822 then if H<511725+7640612 then H=true H=H and-865995+15196749 or 1770207-(-876838)else z=e()S=r(966506-1010119)J=t N=r(860878-904456)H=true U=e()g[U]=H E=Z[N]N=r(422263-465854)H=E[N]N=e()g[N]=H s=e()H=L(-431797+15835125,{})g[z]=H H=false a=L(2390682-(-101601),{s})g[s]=H Y=Z[S]S=Y(a)H=S and-881830+3054761 or-357958+2027416 E=S end else if H<7614032-(-676232)then W=g[U]u=W H=W and-42272+4304622 or 723820-597147 else c=r(411634+-455051)K=19736078615772-712950 j=Z[c]b=r(-986378-(-942883))x=g[z]X=g[U]T=X(b,K)H=9540462-(-940490)v=x[T]c=j(v)j=13396-13396 v=r(173963-217526)c=Z[v]T=g[s]b={c(T)}X=b[-507548+507551]x=b[60416+-60414]v=b[647802-647801]end end else if H<408794+8006266 then if H<9396808-1028253 then G=C(G)X=C(X)H=-816373+14301942 T=C(T)b=C(b)P=nil K=C(K)f=C(f)else Y=g[D[440763+-440761]]A=22769355343604-(-336502)S=g[D[-325377+325380]]H=2436076-(-431167)R=r(-248030-(-204513))a=S(R,A)s=Y[a]z=U[s]E=z end else if H<9094673-632671 then x=r(-1074154-(-1030584))x=I[x]x=x(I)P=-350078+22534123880571 H=-884001+15855676 T=g[D[487451+-487450]]b=g[D[-77117+77119]]f=r(-578451+535011)K=b(f,P)X=r(150660-194104)G=T[K]X=x[X]X=X(x,G)W=X else M=-54383-(-54433)H=-955680+11450850 I=#R j=I>M E=j end end end else if H<-395401+9411869 then if H<8601900-33527 then if H<-631839+9173468 then A=g[D[-166212-(-166213)]]I=g[D[-259982+259984]]M=g[D[349819+-349816]]u=7179697211359-(-558384)v=r(-439466-(-395886))c=M(v,u)j=I[c]v=-950797+14347042790437 R=A[j]c=r(36617-80249)j=g[D[53623+-53621]]I=g[D[-945034+945037]]M=I(c,v)A=j[M]a=R[A]A=H R=a(Y)H=R and 8920860-(-107377)or-814067+6199139 a=R else H=g[D[604660+-604656]]I=r(-819491+776078)R=g[D[-715473+715475]]A=g[D[418068+-418065]]M=5380029028706-(-176231)j=A(I,M)a=R[j]S=a..s a=Y H[S]=a S=773458-773457 H=J+S J=H H=842971+15254516 end else if H<-1027844+9964488 then E=g[D[21686-21685]]U=g[D[-190713-(-190715)]]Y=14290099469848-(-777190)s=r(970407-1014014)N=g[D[23564-23561]]z=N(s,Y)J=U[z]H=E[J]s=r(292058+-335667)Y=9195866278537-276943 U=g[D[689736-689734]]N=g[D[486567-486564]]E=r(-948129-(-904608))z=N(s,Y)J=U[z]E=H[E]E=E(H,J)J=E H=J and-343984+10184128 or 9595765-(-297537)else ZB=g[U]H=ZB and 6326313-(-849355)or-83828+848796 E=ZB end end else if H<8490731-(-565150)then if H<8240004-(-796446)then I=#R M=-316859+316859 H=-678302+6063374 j=I>M a=j else z=r(29174-72748)E=Z[z]z=E(N)H=z and 682373+1452212 or 5798609-724287 end else if H<10197568-930474 then v=-140453-(-140453)c=j==v H=c and 14670716-869676 or 184734+9174999 else H=b H=T and 5886319-942979 or 183766+1870553 end end end end else if H<9335550-(-453962)then if H<307064+9395321 then if H<949085+8558614 then if H<9069541-(-332697)then k=r(-202014+158586)v=r(-148979+105562)T=r(-113590+70012)c=Z[v]X=Z[T]K=g[z]d=19143611091249-(-956833)H=11988461-48238 f=g[U]P=f(k,d)d=5753257593551-819288 T=K[P]x=X[T]k=r(-253678+210257)K=g[z]f=g[U]P=f(k,d)T=K[P]X={x(T,j)}v=c(m(X))else a=A O=r(600076-643654)W=Z[O]O=r(166034+-209651)u=W[O]W=u(J,a)u=g[D[-1027257-(-1027263)]]O=u()v=W+O c=v+Y O=218465+-218464 v=878588-878332 a=nil M=c%v v=N[U]Y=M W=Y+O H=13435503-(-153183)u=z[W]c=v..u N[U]=c end else if H<75273+9491145 then o=r(-695168-(-651530))P=r(652113+-695632)c=X K=1047301-1047300 b=j+K f=Z[P]j=b P=f(T)V=8313649238755-(-982076)k=g[z]d=g[U]y=d(o,V)f=k[y]K=P==f H=K and 670739+5866513 or-389943+11623093 else c=nil H=-951163+11432115 T=nil end end else if H<-337983+10059658 then if H<512827+9196501 then s=r(-1014919-(-971482))E=g[D[37725-37723]]Y=1022394+11092292794995 N=g[D[-203386+203389]]z=N(s,Y)H=E[z]E={H}H=Z[r(-380719+337216)]else N=882794-882784 H=-950595+13556093 U=g[D[86071-86068]]J=U*N U=225890-225633 E=J%U g[D[285057+-285054]]=E end else if H<-719945+10473133 then v=nil H=9790107-(-292313)x=nil R=C(R)else H=g[D[-54742+54746]]M=r(704433+-747853)c=31372959399620-132531 A=g[D[888338-888336]]j=g[D[-66871-(-66874)]]v=-324464+9084225471478 I=j(M,c)R=A[I]W=11816991876454-872424 a=R..s c=r(-203770-(-160199))j=g[D[727555+-727553]]I=g[D[355146-355143]]M=I(c,v)I=r(184059-227637)A=j[M]O=r(-924103+880687)R=S[A]x=655085+11431673648606 H[a]=R u=r(451820-495256)a=290884-290883 R=r(-965192-(-921775))H=J+a J=H a=Z[R]j=Z[I]M=g[D[283519-283517]]c=g[D[345669+-345666]]v=c(u,W)I=M[v]A=j[I]M=g[D[155490+-155488]]c=g[D[102220-102217]]u=r(-331544-(-287910))W=-48093+20217219113123 v=c(u,W)H=3287099-(-16767)I=M[v]v=g[D[-993590-(-993592)]]u=g[D[777496-777493]]W=u(O,x)c=v[W]M=S[c]j={A(I,s,M)}R=a(m(j))end end end else if H<10781400-890679 then if H<-799521+10635601 then if H<9655967-(-177103)then E=r(370192+-413805)U=t[706232+-706230]J=t[126520+-126519]H=Z[E]z={H(U)}E=z[-729331+729332]N=z[566332-566330]z=E H=z and 127167+1880360 or-933331+3619488 else H=S and 578682+7965706 or 15928916-(-168571)end else if H<17680+9825209 then H=261598+9631704 else u=254761+34362095721304 S=g[D[-826771-(-826775)]]H=6170544-(-169700)I=g[D[-756262+756264]]M=g[D[208592+-208589]]v=r(-1061763-(-1018227))c=M(v,u)j=I[c]A=j..s u=r(-691063+647567)W=182067+412883007885 M=g[D[-981830+981832]]c=g[D[-537284+537287]]v=c(u,W)I=M[v]j=R[I]S[A]=j A=-305221-(-305222)S=J+A J=S end end else if H<10613118-670354 then if H<477179+9427317 then Y=r(-1068325-(-1024911))E=r(404433+-447896)S=593999+25313149164988 J=nil H=Z[E]N=g[D[499306+-499304]]z=g[D[700233-700230]]s=z(Y,S)U=N[s]E=H(U)E={}H=Z[r(517271+-560900)]else X=r(-829915+786346)O=r(-919759-(-876231))H=Z[O]x=Z[X]O=H(x)H=r(626984+-670436)Z[H]=O H=-319071+2590616 end else if H<886897+9147926 then J=e()U=e()g[J]=t[-298420+298421]g[U]=t[452258+-452256]E=g[J]H=not E H=H and 5288480-561093 or-798569+8067060 else A=H M=r(-122419-(-78900))I=Z[M]M=I(S)v=g[D[967341-967340]]O=r(320247+-363677)u=g[D[-143335+143337]]x=11187296134054-(-258227)W=u(O,x)I=v[W]j=M==I R=j H=j and-920741+14342077 or 15927173-(-202096)end end end end end else if H<10877457-(-394950)then if H<-1044710+11540252 then if H<-694291+11079656 then if H<10630015-503914 then if H<-986328+11089604 then A=r(824482+-867899)R=Z[A]I=g[z]T=r(399852-443371)M=g[U]v=r(364514+-408004)x=15248603579725-(-120431)c=M(v,x)v=r(818270+-861883)j=I[c]A=R(j)f=r(-847911+804489)R=l(-561992+10538194,{N,z,U;s})I=r(618338+-661755)j=Z[I]M=r(907881-951403)X=r(94314+-137842)b=r(-811880+768317)x=r(900428-944009)c=r(886122-929585)K=r(-199519+156061)I=Z[M]H=882525-189227 P=r(259049-302546)M=Z[c]c=Z[v]v=Z[x]x=Z[X]X=Z[T]T=Z[b]b=Z[K]K=Z[f]f=Z[P]A={j,I,M,c;v;x,X;T;b;K,f}I=r(-878741-(-835283))j=Z[I]v={j(A)}M=v[70359-70357]c=v[642212-642209]I=v[-52670-(-52671)]else H=Z[r(-703391-(-659875))]E={}end else if H<9671499-(-521008)then c=173121+20121118474328 a=g[D[-319040-(-319045)]]M=r(106952-150459)A=g[D[-272144-(-272146)]]j=g[D[450879+-450876]]I=j(M,c)R=A[I]I=r(837103+-880648)S=a[R]M=392648+32331621629191 R=g[D[-583781+583783]]A=g[D[19593-19590]]j=A(I,M)H=-312780+6106556 a=R[j]Y=S[a]E=Y else O=-700051+15783556483912 I=g[D[966884-966883]]c=g[D[264720-264718]]v=g[D[-73538-(-73541)]]W=r(-561589+518042)u=v(W,O)M=c[u]j=I[M]M=g[D[681844+-681842]]W=34996276202249-330593 c=g[D[31731+-31728]]u=r(369346-412844)v=c(u,W)I=M[v]A=j[I]a=A H=-1023664+14589164 end end else if H<429002+10055579 then if H<24097+10419049 then J=r(-395713-(-352144))E=r(-564834-(-521382))H=Z[E]E=Z[J]J=r(-526009+482440)Z[J]=H J=r(-797208-(-753756))H=16602036-196917 Z[J]=E J=g[D[-470031+470032]]U=J()else X,T=v(x,X)H=X and 9043930-(-495081)or 261918+8897564 end else if H<552627+9937201 then Y=nil H=2593991-183927 S=nil a=nil else H=A H=E and 14548095-(-465457)or 1181556-127892 end end end else if H<-31725+10920987 then if H<-979723+11746052 then if H<9538245-(-971590)then a=g[D[89048+-89047]]A=g[D[576580+-576578]]c=-96358+947344488991 j=g[D[341714-341711]]M=r(-954383-(-910837))I=j(M,c)R=A[I]S=a[R]R=g[D[972917-972915]]M=-480474+2035857053838 I=r(320189+-363775)A=g[D[-422140-(-422143)]]j=A(I,M)a=R[j]H=S[a]R=g[D[578002+-578000]]A=g[D[-1038207-(-1038210)]]I=r(-478266-(-434742))M=1015896+2066774393706 j=A(I,M)a=R[j]S=H(Y,a)a=S H=S and 1450237-102210 or 14535258-(-573786)else a=-986580+986580 R=396485+-396230 H=g[D[386384+-386383]]S=H(a,R)U=N H=4823756-(-790487)J[U]=S U=nil end else if H<309528+10532145 then x=-76312+76312 v=#M c=v==x H=c and 285548+11889747 or 884103+1931000 else P=-501154+501156 X=e()g[X]=u G=r(-445301-(-401690))E=Z[G]f=739393+-739392 G=r(834886+-878327)H=E[G]G=-546511-(-546512)T=636089+-635989 E=H(G,T)b=119597+-119342 T=-408550-(-408550)G=e()g[G]=E H=g[S]E=H(T,b)T=e()k=r(-490188+446660)g[T]=E H=g[S]K=g[G]b=-813208-(-813209)E=H(b,K)b=e()g[b]=E E=g[S]K=E(f,P)E=-335230-(-335231)P=r(210814+-254257)H=K==E K=e()g[K]=H V=1012484+-1002484 E=r(220243-263782)B=Z[k]o=-631546+631546 d=g[S]y={d(o,V)}H=r(-202438-(-158840))k=B(m(y))B=r(473113-516556)ZB=k..B f=P..ZB H=c[H]H=H(c,E,f)f=e()g[f]=H P=r(444272-487885)ZB=n(14198380-(-741335),{S;X;A;N,U,v;K,f;G,b,T,R})E=Z[P]P={E(ZB)}H={m(P)}P=H H=g[K]H=H and 685295+8328119 or-719427+7401344 end end else if H<-722578+11785946 then if H<11175903-227773 then H=E and-1030633+6244261 or 14142703-165028 else x=nil v=nil R=C(R)H=4771536-775969 end else if H<12270902-1033995 then rB=r(-305273+261668)d=r(-545948+502370)f=r(-802560-(-759143))K=Z[f]k=Z[d]y=g[z]HB=3620022613331-1011390 o=g[U]V=o(rB,HB)d=y[V]rB=r(-469755+426130)P=k[d]HB=13352153825703-(-54946)y=g[z]o=g[U]V=o(rB,HB)H=984914+8616842 d=y[V]o=r(830112-873640)y=Z[o]o={y(T)}k={P(d,j,c,m(o))}f=K(m(k))else a=r(16099-59618)M=-1019020+140423974093 s=N S=Z[a]I=r(-972319-(-928760))a=S(Y)R=g[D[-849324-(-849326)]]A=g[D[263417+-263414]]j=A(I,M)S=R[j]H=a==S H=H and-397330+10895047 or-38307+1816150 end end end end else if H<11848355-(-1860)then if H<12195671-727312 then if H<11433487-121637 then if H<10986752-(-309052)then W=r(197833+-241315)M=r(-1016556+973037)a=S A=H I=Z[M]M=I(R)c=g[D[-461149-(-461151)]]v=g[D[-587251-(-587254)]]O=258522+27397378506747 u=v(W,O)I=c[u]j=M==I H=j and-742075+9213563 or-433136+10928306 E=j else P=g[S]d=g[z]rB=5991326814710-100113 V=r(73501+-117042)y=g[U]o=y(V,rB)k=d[o]V=-117303+8077457905896 f=P[k]H=-938845+6281205 k=g[z]d=g[U]o=r(-215589-(-172012))y=d(o,V)P=k[y]K=f[P]T=K end else if H<373352+10987095 then y=r(1036881+-1080411)H=-839579+12692729 T=g[N]o=628126+1843753741756 P=g[z]k=g[U]d=k(y,o)f=P[d]P=g[X]K=f..P f=w(2145757-(-953062),{S,z,U;X;s;R})b=T(K,f)else H=true N=r(860148+-903594)g[D[548475-548474]]=H U=Z[N]a=40566+34302156267503 S=r(141360+-184811)z=g[D[-161514-(-161516)]]s=g[D[-429723+429726]]Y=s(S,a)N=z[Y]R=884166+7069574647574 E=U[N]s=g[D[-280585-(-280587)]]a=r(97564+-141035)Y=g[D[-664550+664553]]N=965372+-965369 S=Y(a,R)z=s[S]U=E(N,z)N=H H=U and 7844471-(-570578)or 1994319-(-872924)E=U end end else if H<-337285+12132276 then if H<-549578+12182463 then H=5512598-56150 M=g[D[-652393+652394]]u=r(-67737-(-24281))W=31565155263613-(-152813)c=g[D[-875102-(-875104)]]v=c(u,W)I=M[v]A=I else H=true H=-982087+14579517 end else if H<11634136-(-202728)then X=H k=r(467791+-511226)K=g[z]d=862486+28040509688299 f=g[U]P=f(k,d)b=K[P]T=x[b]H=T and 5750660-83610 or 6615269-(-1044516)c=T else H=7113249-(-166072)end end end else if H<-760036+12685290 then if H<826252+11045865 then if H<-667819+12523598 then H=-544124+2598443 else f=-8117+34920639422266 v=g[S]K=r(-931084+887571)X=g[z]T=g[U]b=T(K,f)H=3129191-897767 x=X[b]c=v[x]x=g[z]X=g[U]K=13272435916163-(-662177)b=r(591909+-635386)T=X(b,K)v=x[T]M=c[v]j=M end else if H<-525455+12414196 then A=g[D[446672-446671]]u=8775214881779-(-291843)I=g[D[-250257+250259]]v=r(763713+-807332)M=g[D[-143568+143571]]c=M(v,u)v=-130781+10180973613409 j=I[c]R=A[j]c=r(-918863+875239)j=g[D[-2983-(-2985)]]I=g[D[43307+-43304]]M=I(c,v)A=j[M]S=R[A]I=g[D[-978825+978827]]v=r(25334+-68783)u=-542900+21089659924240 M=g[D[766127+-766124]]c=M(v,u)j=I[c]A=a[j]I=g[D[-318898+318900]]M=g[D[-238480+238483]]u=34229053359337-345766 v=r(994690-1038265)c=M(v,u)j=I[c]R=S(A,j)A=H S=R H=R and 12579767-254921 or 950714+12879082 else I=g[D[24972-24970]]u=758831+3911035515630 v=r(-182235-(-138702))H=7576+5506042 M=g[D[897935-897932]]c=M(v,u)j=I[c]A=a[j]S=A end end else if H<12724938-745422 then if H<-138185+12079140 then f=5291753061448-(-19800)I=C(I)j=nil a=nil M=C(M)K=r(-472940+429481)R=nil v=r(-520261+476673)c=Z[v]S=C(S)x=g[z]N=C(N)X=g[U]U=C(U)z=C(z)T=X(K,f)v=x[T]H=Z[r(-172959+129347)]A=nil E={}x=g[s]c[v]=x s=C(s)else J=nil g[D[-734489+734494]]=E H=-267546+5031352 end else U=g[D[241427+-241425]]Y=-1027246+4708704384318 s=r(708667-752234)H=r(916766+-960281)H=J[H]N=g[D[-318244-(-318247)]]z=N(s,Y)E=U[z]H=H(J,E)U=H H=r(-450046+406554)H=J[H]N=-303859+303859 H=H(J)E=#U H=E>N H=H and-663093+7277015 or 559293+9148468 end end end end end else if H<13674042-(-676025)then if H<14063575-641803 then if H<11709201-(-908926)then if H<-778155+13123775 then if H<12627761-408805 then if H<12260484-121349 then N=-342764+342796 U=g[D[703987+-703984]]J=U%N z=g[D[-753561-(-753565)]]S=g[D[-407584+407586]]c=g[D[641775-641772]]j=-758458-(-758471)M=c-J c=-802364-(-802396)R=-185095+185097 I=M/c A=j-I a=R^A Y=S/a s=z(Y)z=4295400866-433570 N=s%z s=-916700-(-916702)z=s^J a=-523459+523460 U=N/z z=g[D[1015314+-1015310]]S=U%a a=-767086+4295734382 Y=S*a s=z(Y)z=g[D[-959707-(-959711)]]Y=z(U)N=s+Y s=902891-837355 S=-485049+550585 z=N%s H=460224+6432345 Y=N-z U=nil s=Y/S S=-515964+516220 Y=z%S j=-899585+899841 N=nil a=z-Y R=-704149+704405 S=a/R R=-351980-(-352236)J=nil a=s%R A=s-a R=A/j s=nil A={Y,S;a;R}g[D[-834605+834606]]=A R=nil a=nil S=nil z=nil Y=nil else P=r(-356167+312707)c={}v=e()x=p(5876452-(-814985),{v,R;A,s})g[v]=c c=e()k=nil g[c]=x x={}T={}X=e()G=r(-281150-(-237653))M=nil g[X]=x x=Z[G]M=r(-107406+63792)K=r(-76109-(-32472))f=g[X]Y=nil b={[K]=f,[P]=k}j=nil N=nil G=x(T,b)a=nil g[z]=G S=nil N={}s=C(s)x=n(16647103-568024,{X,v,I;R;A;c})I=C(I)A=C(A)X=C(X)g[U]=x c=C(c)R=C(R)R=r(127311-170899)s=e()v=C(v)Y=l(9377246-(-446992),{z,U})g[s]=N c=573161045020-(-525550)N=e()g[N]=Y S=e()Y=nil g[S]=Y a=Z[R]A=g[z]j=g[U]I=j(M,c)R=A[I]Y=a[R]H=Y and 692473+13684660 or 790863+5468164 end else if H<-431593+12745599 then R=r(-904766+861247)c=15177010520490-(-653809)E=Z[R]R=E(S)A=g[D[832385-832384]]M=r(69067-112491)j=g[D[-857956+857958]]I=j(M,c)E=A[I]H=R==E H=H and-676926+4444355 or 747339+9289139 else u=r(417410-460843)M=g[D[919633-919631]]W=-673659+9917241465221 c=g[D[-214617-(-214620)]]H=14860665-1030869 v=c(u,W)I=M[v]j=R[I]S=j end end else if H<12289545-(-266416)then if H<-322821+12814732 then M=I v=#M u=-66018+66033 c=v>u H=c and 57252+3224942 or 1009852-987906 else T=not G v=v+X c=v<=x c=T and c T=v>=x T=G and T c=T or c T=5573071-(-736293)H=c and T c=5647525-7800 H=H or c end else if H<85594+12471515 then z,Y=U(N,z)H=z and 469434+6427153 or 14287565-(-391535)else N=-574470+574471 U=g[D[698699-698696]]J=U~=N H=J and 12885206-833177 or 9536347-(-174234)end end end else if H<-274824+13125914 then if H<-643072+13462430 then if H<12744378-5938 then x=r(352165+-395735)O=H f=r(-332043-(-288446))X=r(-555521-(-512077))x=I[x]P=-950671+2347450107348 x=x(I)T=g[D[971362-971361]]X=x[X]b=g[D[-585649-(-585651)]]K=b(f,P)G=T[K]X=X(x,G)W=X H=X and-556304+15527979 or 9089931-671876 else N=845519+-845519 J=r(736869+-780332)H=Z[J]U=g[D[802737-802729]]J=H(U,N)H=-456819+7855412 end else if H<165858+12653855 then g[U]=ZB y=g[b]o=-382404-(-382405)d=y+o k=P[d]B=j+k k=295899+-295643 H=B%k j=H d=g[T]k=I+d d=-406290-(-406546)B=k%d I=B H=74395+8260981 else I=A W=r(-586408-(-542889))u=Z[W]G=r(618174+-661657)W=u(I)O=g[D[-484629+484630]]x=g[D[507852+-507850]]T=-126392+29677985211315 X=x(G,T)u=O[X]v=W==u H=v and-94237+13751192 or 4972847-(-1048497)c=v end end else if H<13549992-532747 then if H<-232116+13145279 then E=g[D[-85050-(-85051)]]J={h(463439+-463438,m(t))}H=not E H=H and 12412059-1048166 or 5875131-60468 else H=429477+7553709 end else if H<297292+12992228 then M=r(-1079495-(-1035964))H=247501+16409778 I=Z[M]M=r(-662017+618606)j=I[M]R=j else H=16862098-732829 M=708771+-708721 I=#S j=I>M R=j end end end end else if H<14417783-699178 then if H<-754221+14321587 then if H<-530234+14047038 then if H<-378005+13866436 then X=not x u=u+O E=u<=W E=X and E X=u>=W X=x and X E=X or E X=10032820-(-813191)H=E and X E=7403317-(-849068)H=H or E else k=356501+-356500 B=P[k]ZB=B H=13508405-688993 end else if H<14427540-908626 then H=562087+3864714 a=nil Y=nil S=nil else H=R H=a and 45017+8479804 or-1005871+1446712 end end else if H<13246598-(-390416)then if H<-140487+13736710 then A=A+j a=A<=R M=not I a=M and a M=A>=R M=I and M a=M or a M=659110+8841927 H=a and M a=13881579-(-771586)H=H or a else H=i(15192678-(-727347),{z})W={H()}E={m(W)}H=Z[r(-596334+552724)]end else if H<14658275-983790 then b=r(1036568+-1080062)W=r(-237073+193503)K=24028631948196-45039 W=I[W]W=W(I)X=g[D[850684-850683]]G=g[D[-663717+663719]]u=H O=r(-851540+808096)T=G(b,K)x=X[T]O=W[O]O=O(W,x)H=O and-640043+2247169 or-628898+13362823 v=O else I=r(534316+-577733)j=Z[I]X=r(994684+-1038094)c=g[z]K=26540817872880-(-161879)v=g[U]T=-630899+17158864453545 x=v(X,T)M=c[x]I=j(M)I=r(148496+-191913)j=Z[I]I=e()M=e()g[I]=j j=false g[M]=j b=r(-1082956-(-1039538))j=g[N]x=g[z]X=g[U]T=X(b,K)v=x[T]x=n(-303829+5170946,{z,U,I,M,s,S})c=j(v,x)K=-3075+4967146018060 c=r(-214038-(-170621))j=Z[c]x=g[z]X=g[U]b=r(-546642+503180)T=X(b,K)v=x[T]c=j(v)j=g[N]K=7672119238960-529212 b=r(-636897-(-593455))x=g[z]X=g[U]T=X(b,K)v=x[T]x=q(4620877-(-991453),{S;z;U,s})c=j(v,x)c=g[S]b=r(-429713-(-386238))x=g[z]K=26274029651634-(-239896)X=g[U]T=X(b,K)v=x[T]j=c[v]H=j and 2045516-323632 or 8762352-458630 end end end else if H<14657062-774615 then if H<-520312+14325853 then if H<14218965-443505 then H=v H=c and 317508+5459053 or 827846-(-755210)else v=r(640337+-683859)c=Z[v]P=6723036432049-375415 f=r(-617831+574267)X=g[z]H=649761+11290462 T=g[U]K=T(f,P)x=X[K]v=c(x)end else if H<13650366-(-160923)then H=2611977-785077 z=nil else H=A H=S and 9716188-(-141806)or 861866+5478378 end end else if H<14164660-(-109100)then if H<14810979-716601 then H=J and 6647801-(-63655)or 16024257-(-677514)else W=#M O=747973-747923 u=W>O H=-128126+13881817 c=u end else if H<499566+13811168 then z=r(572166-615694)H=Z[r(-617187-(-573627))]N=Z[z]z=N(J)A=3238779252718-(-38390)R=r(530434+-573919)s=g[D[-995287-(-995289)]]Y=g[D[77067-77064]]a=Y(R,A)N=s[a]U=z..N E={U}else O=-598571-(-598572)x=-543572+543578 H=g[S]W=H(O,x)H=r(-548364+504912)x=r(765935-809387)Z[H]=W O=Z[x]x=316990+-316988 H=O>x H=H and-907934+10815322 or 956191+6567657 end end end end end else if H<-1018597+16520156 then if H<888613+14104435 then if H<436900+14161368 then if H<580671+13876147 then if H<13645264-(-714057)then H=740762+5689167 else R=r(1037935+-1081523)M=r(96096-139543)c=22900239574343-1031072 a=Z[R]A=g[z]j=g[U]I=j(M,c)v=-51055+10104587278800 R=A[I]Y=a[R]R=r(-515439-(-472022))g[S]=Y a=Z[R]j=g[z]H=6764160-334231 I=g[U]c=r(784156-827643)M=I(c,v)A=j[M]R=a(A)end else if H<13626291-(-876273)then H=-147727+2054804 a=nil else H=X H=c and 11051256-(-785102)or-285718+10036341 end end else if H<-327992+15189955 then if H<125719+14552044 then H=8037927-758606 Y=nil S=nil z=nil else z=g[D[-773333+773334]]S=r(381574+-425075)s=g[D[-182019-(-182021)]]a=32282399617466-358146 Y=s(S,a)N=z[Y]U=J[N]H=U and 6036005-(-1023010)or 724090+-553038 end else if H<-797257+15746067 then U=g[D[-304960-(-304961)]]z=588937+-588936 s=-177339+177341 N=U(z,s)U=-850254+850255 J=N==U H=J and 1218771-941088 or 4919944-437827 E=J else H=O H=389006+1218120 v=W end end end else if H<15582254-491918 then if H<434591+14637710 then if H<622301+14404245 then E=g[D[770992-770988]]I=g[D[991892-991890]]M=g[D[-773202+773205]]v=r(335683+-379286)H=1220367-166703 u=85347+5748414692625 c=M(v,u)j=I[c]A=j..a j=R E[A]=j else N=133827-133586 U=g[D[-232661+232663]]J=U*N U=27807066192011-738808 E=J+U J=1010082+35184371078750 U=-876224-(-876225)H=E%J g[D[-980695+980697]]=H J=g[D[-162056-(-162059)]]H=10728904-1018323 E=J~=U end else if H<727623+14349511 then c=g[S]I=H x=g[z]b=r(389568-433079)X=g[U]K=965878+25453836874070 T=X(b,K)v=x[T]M=c[v]H=M and 11499484-(-370339)or 698560+1532864 j=M else H=600155+15565305 U=nil end end else if H<15215436-4533 then if H<-257935+15417266 then H=a and 10197945-440430 or 4061061-757195 else Y=g[D[-133696+133701]]I=22758276292493-(-231896)a=g[D[342246-342244]]j=r(-445834+402235)R=g[D[-697641-(-697644)]]A=R(j,I)S=a[A]A=r(-926331+882802)s=Y[S]S=g[D[-521653-(-521655)]]j=24032154933991-12081 a=g[D[-747873-(-747876)]]R=a(A,j)Y=S[R]E=s[Y]H=714061+13092577 s=E(N)j=5922464827361-(-279268)E=g[D[440383+-440379]]S=g[D[48584+-48582]]a=g[D[-202930-(-202933)]]A=r(-457880-(-414301))R=a(A,j)a=r(-630243-(-586715))Y=S[R]S=Z[a]a=S(s)E[Y]=a s=nil end else if H<81479+15400160 then E=r(-203331-(-159868))J=r(-298837-(-255369))H=Z[E]E=H(J)E={}H=Z[r(518005-561636)]else S,R=s(Y,S)H=S and 11407798-113201 or 5799465-961091 end end end end else if H<-652215+16777110 then if H<15816701-(-105108)then if H<15813390-54330 then if H<538499+15047338 then N,Y=z(U,N)H=N and 1968539-(-747887)or-253038+7431046 else j=-1038367-(-1038432)R=e()g[R]=E A=-337489+337492 H=g[S]E=H(A,j)A=e()H=-410529-(-410529)c=p(1932511-171215,{})g[A]=E j=H H=-635286+635286 I=H M=r(869-44482)E=Z[M]M={E(c)}E=-257174-(-257176)O=r(-616310+572782)H={m(M)}M=H H=M[E]E=r(696929-740485)c=H H=Z[E]v=g[N]W=Z[O]O=W(c)W=r(951103+-994642)u=v(O,W)v={u()}E=H(m(v))v=e()g[v]=E E=-1012957+1012958 u=g[A]W=u u=254977-254976 O=u u=369275-369275 x=O<u H=-1019092+14504661 u=E-O end else if H<867763+14927411 then H=true H=H and 526546+5102013 or 13788171-190741 else H=983972+15421147 end end else if H<16441351-340339 then if H<-787358+16872969 then H=g[D[637505-637504]]J=t[-259488-(-259489)]N=H U=t[-568581+568583]H=N[U]H=H and-632773+12470834 or-215543+4076855 else s=nil H=15822358-302556 Y=nil end else if H<-985913+17097264 then I=a(j,I)H=I and-807766+13179078 or 1793150-(-678728)else N,Y=z(U,N)H=N and-1028962+12274165 or-32424+14342788 end end end else if H<16567400-(-33598)then if H<959079+15222791 then if H<-985537+17142976 then H=A H=R and-846512+7596235 or 782097+9706477 else J=nil H=Z[r(-158525+114931)]E={}end else if H<16415890-13821 then S=467867+28576674140256 E=r(727286+-770749)H=Z[E]N=g[D[672916+-672915]]Y=r(527261-570773)z=g[D[1042082-1042080]]s=z(Y,S)U=N[s]E=H(U)H=-452327+8560278 else H=true H=H and-360357+10802543 or 9551012-(-565691)end end else if H<631599+16093588 then if H<282832+16382919 then E=R H=A H=R and 16007087-353313 or 3940893-(-112550)else A=35112779095072-(-467902)z=r(19940+-63403)N=Z[z]Y=g[D[414032-414031]]E={}R=r(548220+-591704)J=nil S=g[D[156145+-156143]]a=S(R,A)H=Z[r(-516988+473470)]s=Y[a]z=N(s)end else I=r(-736289-(-692872))X=r(-48572+5091)T=847317+1368201417896 j=Z[I]c=g[z]v=g[U]x=v(X,T)M=c[x]I=j(M)j=g[N]T=28505911425895-837517 X=r(-738951+695536)c=g[z]v=g[U]H=13794650-79676 x=v(X,T)M=c[x]c=q(6784543-(-26685),{S;z;U;s})I=j(M,c)end end end end end end end end H=#Q return m(E)end,538561-538561,function(Z,r)local m=N(r)local t=function(t)return H(Z,{t},r,m)end return t end,function(Z,r)local m=N(r)local t=function(t,D,Q,h,E)return H(Z,{t,D,Q;h;E},r,m)end return t end,{},function(Z,r)local m=N(r)local t=function(t,D,Q,h)return H(Z,{t,D,Q,h},r,m)end return t end,function(Z)for r=972363-972362,#Z,-94479-(-94480)do J[Z[r]]=(958312-958311)+J[Z[r]]end if t then local H=t(true)local m=Q(H)m[r(495623-539260)],m[r(979682+-1023130)],m[r(-591225+547598)]=Z,z,function()return-1779037-(-158314)end return H else return D({},{[r(-855200+811752)]=z;[r(-408249+364612)]=Z,[r(-137661+94034)]=function()return 736675+-2357398 end})end end,function(Z,r)local m=N(r)local t=function(t,D,Q,h,E,g)return H(Z,{t;D,Q;h,E;g},r,m)end return t end return(F(745695+7444052,{}))(m(E))end)(getfenv and getfenv()or _ENV,unpack or table[r(-452175+408764)],newproxy,setmetatable,getmetatable,select,{...})end)(...), func=function: 0x75283417a300")
print("  Level 5: source=local unpack = unpack or table.unpack
local warn = warn or function() end

local _origPcall = pcall
local _origXpcall = xpcall
local _origError = error

local debugLibrary = debug
_G._VERSION = "Luau"
local setHook = debug.sethook
local getInfo = debug.getinfo
local getTraceback = debug.traceback
local loadFunction = load
local loadStringFunction = loadstring or load
local pcallFunction = pcall
local xpcallFunction = xpcall
local errorFunction = error
local typeFunction = type
local getMetatableFunction = getmetatable
local rawEqualFunction = rawequal
local toStringFunction = tostring
local toNumberFunction = tonumber
local ioLibrary = io
local osLibrary = os
local pairsFunction = pairs
local ipairsFunction = ipairs
local tableUnpackFunction = table.unpack or unpack
local proxyTable = {}
proxyTable.__index = proxyTable
local configuration = {
    MAX_DEPTH = 15,
    MAX_TABLE_ITEMS = 150,
    OUTPUT_FILE = "dumped_output.lua",
    VERBOSE = false,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 6.57,
    MAX_REPEATED_LINES = 8,
    MIN_DEOBF_LENGTH = 150,
    MAX_OUTPUT_SIZE = 6 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true
}
local inputKey = (arg and arg[3]) or "NoKey"
if arg and arg[3] then
    print("[Dumper] Auto-Input Key Detected: " .. toStringFunction(inputKey))
end
local dumperState = {
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
    ls_counter = 0
}
local _at = {
    mem          = {},
    tags         = {},
    sigs         = {},
    acts         = {},
    json         = {},
    enum         = {},
    svcCache     = {},
    typeOverride = {},
    connState    = {},
    debugIds     = {},
    debugIdCtr   = 0,
    instTags     = {},
    attrs        = {},
    children     = {},
    threadLike   = {},
    vectors      = {},
    buffers      = {},
    userdata     = {},
    localPlayer  = nil,
    weldRegistry = {},
    services     = {},
    folders      = {},
    files        = {},
    refBase      = {},
    metaHooks    = {},
    currentNamecallMethod = nil,
    inMetaHook   = false,
    pendingHeartbeat = {},
    locEntries = {},
    signalCallbacks = {},  -- AT5: live signal firing
    animateScript = nil,   -- AT3: getrunningscripts
}
setmetatable(_at.debugIds, {__mode = "k"})
setmetatable(_at.instTags, {__mode = "k"})
setmetatable(_at.attrs, {__mode = "k"})
setmetatable(_at.children, {__mode = "k"})
setmetatable(_at.threadLike, {__mode = "k"})
setmetatable(_at.vectors, {__mode = "k"})
setmetatable(_at.buffers, {__mode = "k"})
setmetatable(_at.userdata, {__mode = "k"})
setmetatable(_at.refBase, {__mode = "k"})
local function _getDebugId(p)
    if not _at.debugIds[p] then
        _at.debugIdCtr = _at.debugIdCtr + 1
        local n = _at.debugIdCtr
        _at.debugIds[p] = toStringFunction(n * 17 + 3) .. "-" .. toStringFunction(n * 97 + 11)
    end
    return _at.debugIds[p]
end
local function _removeChild(parent, child)
    local list = parent and _at.children[parent]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == child then table.remove(list, i) end
    end
end
local function _setParent(child, parent)
    local oldParent = dumperState.parent_map[child]
    if oldParent == parent then return end
    _removeChild(oldParent, child)
    dumperState.parent_map[child] = parent
    if parent then
        _at.children[parent] = _at.children[parent] or {}
        table.insert(_at.children[parent], child)
        -- skip signal firing for internal proxy types
        local childType = _at.typeOverride[child]
        local parentType = _at.typeOverride[parent]
        if childType == "RBXScriptSignal" or childType == "RBXScriptConnection"
        or parentType == "RBXScriptSignal" or parentType == "RBXScriptConnection" then
            return
        end
        -- fire ChildAdded on direct parent only
        if _at.signalCallbacks[parent] then
            for _, cb in ipairsFunction(_at.signalCallbacks[parent].ChildAdded or {}) do
                pcallFunction(cb, child)
            end
        end
        -- fire DescendantAdded on direct parent and its ancestors
        local ancestor = parent
        while ancestor do
            if _at.signalCallbacks[ancestor] then
                for _, cb in ipairsFunction(_at.signalCallbacks[ancestor].DescendantAdded or {}) do
                    pcallFunction(cb, child)
                end
            end
            ancestor = dumperState.parent_map[ancestor]
        end
    end
end
local function _isDescendantOf(child, parent)
    local cur = dumperState.parent_map[child]
    while cur do
        if cur == parent then return true end
        cur = dumperState.parent_map[cur]
    end
    return false
end
local function _getAllDescendants(root, out)
    out = out or {}
    for _, child in ipairsFunction(_at.children[root] or {}) do
        table.insert(out, child)
        _getAllDescendants(child, out)
    end
    return out
end
local numericArg = (arg and toNumberFunction(arg[4])) or (arg and toNumberFunction(arg[3])) or 123456789
local proxyMarker = {}
local function isProxyTable(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyMarker) == true end )
    return success and result
end
local function getProxyValue(target)
    if isProxyTable(target) then
        return rawget(target, "__value") or 0
    end
    return 0
end
local loadStringFunction = loadstring or load
local printFunction = print
local warnFunction = warn or function() end
local pairsFunction = pairs
local ipairsFunction = ipairs
local typeFunction = type
local toStringFunction = tostring
local proxyList = {}
local function isProxy(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyList) == true end )
    return success and result
end
local function getProxyId(target)
    if not isProxy(target) then
        return nil
    end
    return rawget(target, "__proxy_id")
end
local function processString(inputString)
    if typeFunction(inputString) ~= "string" then
        return '"'\n    end\n    local outputParts = {}\n    local currentIndex, totalLength = 1, #inputString\n    local function cleanEscapes(content)\n        return content:gsub( "\\\\(.)", function(escapedChar)\n            if escapedChar:match('[abfnrtv\\\\%\'%\\"%[%]0-9xu]') then
                return "" .. escapedChar
            end
            return escapedChar
        end )
    end
    local function stripLuauSyntax(rawCode)
        if not rawCode or rawCode == "" then
            return rawCode
        end
        rawCode = rawCode:gsub("\239\187\191", "")
        rawCode = rawCode:gsub("\r\n", "\n"):gsub("\r", "\n")
        rawCode = rawCode:gsub("\226\128\168", "\n"):gsub("\226\128\169", "\n")
        rawCode = rawCode:gsub("%-%-!%a+[^\n]*", "")
        rawCode = rawCode:gsub("([^\n]*)", function(line)
            if line:match("^%s*export%s+type%s+") or line:match("^%s*type%s+[%a_][%w_]*%s*=") then
                return "-- " .. line
            end
            return line
        end)
        rawCode = rawCode:gsub("local%s+([%a_][%w_]*)%s*<[%a_][%w_]*>%s*=", "local %1 =")
        rawCode = rawCode:gsub("(function%s+[%a_][%w_%.:]*)%s*<[^>\n%(]+>%s*%(", "%1(")
        rawCode = rawCode:gsub("([%(%s,])%.%.%.%s*:%s*[%a_][%w_%.]*%??", "%1...")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", "%1%2")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", "%1%2%3")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", ")")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", ")%1")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%s*%b<>%??", "")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%??", "")
        return rawCode
    end
    local function parseExpression(rawCode)
        if not rawCode or rawCode == '"' then\n            return ""\n        end\n        rawCode = stripLuauSyntax(rawCode)\n        rawCode = rawCode:gsub( "0[bB]([01_]+)", function(binaryString)\n            local cleanBinary = binaryString:gsub("_", "")\n            local decimalValue = toNumberFunction(cleanBinary, 2)\n            return decimalValue and toStringFunction(decimalValue) or "0"\n        end )\n        rawCode = rawCode:gsub( "0[xX]([%x_]+)", function(hexString)\n            local cleanHex = hexString:gsub("_", "")\n            return "0x" .. cleanHex\n        end )\n        while rawCode:match("%d_+%d") do\n            rawCode = rawCode:gsub("(%d)_+(%d)", "%1%2")\n        end\n        local operators = {{"+=", "+"}, {"-=", "-"}, {"*=", "*"}, {"/=", "/"}, {"%%=", "%%"}, {"%^=", "^"}, {"%.%.=", ".."}}\n        for _, opPair in ipairsFunction(operators) do\n            local operatorAssignment, operator = opPair[1], opPair[2]\n            rawCode = rawCode:gsub( "([%a_][%w_]*%b[])%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([%a_][%w_]*[%.%a_%d][%w_%.]*%.[%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([^%w_%.%]%):])([%a_][%w_]*)%s*" .. operatorAssignment, function(prefix, varName)\n                return prefix .. varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "^([%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n        end\n\n        rawCode = rawCode:gsub("([%a_][%w_]*%b[])%s*%+%+",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*%.[%w_%.]*[%w_])%s*%+%+","%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*)%s*%+%+",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%b[])",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%.[%w_%.]*[%w_])","%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*)",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+", "+")\n\n        rawCode = rawCode:gsub("([^%w_])continue([^%w_])", "%1__LC__()%2")\n        rawCode = rawCode:gsub("^continue([^%w_])", "__LC__()%1")\n        rawCode = rawCode:gsub("([^%w_])continue$", "%1__LC__()")\n        return rawCode\n    end\n    local function getBracketCount(index)\n        local count = 0\n        while index <= totalLength and inputString:byte(index) == 61 do\n            count = count + 1\n            index = index + 1\n        end\n        return count, index\n    end\n    local function findClosingBracket(startIndex, bracketCount)\n        local closingPattern = "]" .. string.rep("=", bracketCount) .. "]"\n        local start, finish = inputString:find(closingPattern, startIndex, true)\n        return finish or totalLength\n    end\n    local segmentStart = 1\n    while currentIndex <= totalLength do\n        local byteValue = inputString:byte(currentIndex)\n        if byteValue == 91 then\n            local bracketCount, nextIndex = getBracketCount(currentIndex + 1)\n            if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n                local startSegment = currentIndex\n                local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                currentIndex = endSegment\n                segmentStart = currentIndex + 1\n            end\n        elseif byteValue == 45 and currentIndex + 1 <= totalLength and inputString:byte(currentIndex + 1) == 45 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local startSegment = currentIndex\n            if currentIndex + 2 <= totalLength and inputString:byte(currentIndex + 2) == 91 then\n                local bracketCount, nextIndex = getBracketCount(currentIndex + 3)\n                if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                    local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                    table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                    currentIndex = endSegment\n                    segmentStart = currentIndex + 1\n                    currentIndex = currentIndex + 1\n                end\n            end\n            local lineBreak = inputString:find("\n", currentIndex + 2, true)\n            if lineBreak then\n                currentIndex = lineBreak\n            else\n                currentIndex = totalLength\n            end\n            table.insert(outputParts, inputString:sub(startSegment, currentIndex))\n            segmentStart = currentIndex + 1\n        elseif byteValue == 34 or byteValue == 39 or byteValue == 96 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local quoteType = byteValue\n            local startSegment = currentIndex\n            currentIndex = currentIndex + 1\n            while currentIndex <= totalLength do\n                local charByte = inputString:byte(currentIndex)\n                if charByte == 92 then\n                    currentIndex = currentIndex + 1\n                elseif charByte == quoteType then\n                    break\n                end\n                currentIndex = currentIndex + 1\n            end\n            local extractedContent = inputString:sub(startSegment + 1, currentIndex - 1)\n            extractedContent = cleanEscapes(extractedContent)\n            if quoteType == 96 then\n                table.insert(outputParts, '"' .. extractedContent:gsub('"', '\\\\"') .. '"')\n            else\n                local quoteChar = string.char(quoteType)\n                table.insert(outputParts, quoteChar .. extractedContent .. quoteChar)\n            end\n            segmentStart = currentIndex + 1\n        end\n        currentIndex = currentIndex + 1\n    end\n    table.insert(outputParts, parseExpression(inputString:sub(segmentStart)))\n    return table.concat(outputParts)\nend\nlocal function safeLoad(code, chunkName)\n    local loadedFunc, errorMessage = loadStringFunction(code, chunkName)\n    if loadedFunc then\n        return loadedFunc\n    end\n    printFunction("\n[CRITICAL ERROR] Failed to load script!")\n    printFunction("[LUA_LOAD_FAIL] " .. toStringFunction(errorMessage))\n    local errorLine = toNumberFunction(errorMessage:match(":(%d+):"))\n    local errorNear = errorMessage:match("near '([^']+)'")\n    if errorNear then\n        local foundIndex = code:find(errorNear, 1, true)\n        if foundIndex then\n            local startCtx = math.max(1, foundIndex - 50)\n            local endCtx = math.min(#code, foundIndex + 50)\n            printFunction("Context around error:")\n            printFunction("..." .. code:sub(startCtx, endCtx) .. "...")\n        end\n    end\n    local debugFile = ioLibrary.open("DEBUG_FAILED_TRANSPILE.lua", "w")\n    if debugFile then\n        debugFile:write(code)\n        debugFile:close()\n        printFunction("[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection")\n    end\n    return nil, errorMessage\nend\nlocal function emitOutput(data, isInline)\n    if dumperState.limit_reached then\n        return\n    end\n    if data == nil then\n        return\n    end\n    local indentPrefix = isInline and "" or string.rep("    ", dumperState.indent)\n    local lineString = indentPrefix .. toStringFunction(data)\n    local lineSize = #lineString + 1\n    if dumperState.current_size + lineSize > configuration.MAX_OUTPUT_SIZE then\n        dumperState.limit_reached = true\n        local warningMessage = "-- [CRITICAL] Dump stopped: File size exceeded 6MB limit."\n        table.insert(dumperState.output, warningMessage)\n        dumperState.current_size = dumperState.current_size + #warningMessage\n        errorFunction("DUMP_LIMIT_EXCEEDED")\n    end\n    if lineString == dumperState.last_emitted_line then\n        dumperState.repetition_count = dumperState.repetition_count + 1\n        if dumperState.repetition_count <= configuration.MAX_REPEATED_LINES then\n            table.insert(dumperState.output, lineString)\n            dumperState.current_size = dumperState.current_size + lineSize\n        elseif dumperState.repetition_count == configuration.MAX_REPEATED_LINES + 1 then\n            local suppressMessage = indentPrefix .. "-- [Repeated lines suppressed...]"\n            table.insert(dumperState.output, suppressMessage)\n            dumperState.current_size = dumperState.current_size + #suppressMessage\n        end\n    else\n        dumperState.last_emitted_line = lineString\n        dumperState.repetition_count = 0\n        table.insert(dumperState.output, lineString)\n        dumperState.current_size = dumperState.current_size + lineSize\n    end\n    if configuration.VERBOSE and dumperState.repetition_count <= 1 then\n        printFunction(lineString)\n    end\nend\nlocal function emitComment(data)\n    emitOutput("-- " .. toStringFunction(data or ""))\nend\nlocal function addEmptyLine()\n    dumperState.last_emitted_line = nil\n    table.insert(dumperState.output, "")\nend\nlocal function getFullOutput()\n    return table.concat(dumperState.output, "\n")\nend\nlocal function saveToFile(filePath)\n    local fileHandle = ioLibrary.open(filePath or configuration.OUTPUT_FILE, "w")\n    if fileHandle then\n        fileHandle:write(getFullOutput())\n        fileHandle:close()\n        return true\n    end\n    return false\nend\nlocal function formatValue(value)\n    if value == nil then\n        return "nil"\n    end\n    if typeFunction(value) == "string" then\n        return value\n    end\n    if typeFunction(value) == "number" or typeFunction(value) == "boolean" then\n        return toStringFunction(value)\n    end\n    if typeFunction(value) == "table" then\n        if dumperState.registry[value] then\n            return dumperState.registry[value]\n        end\n        if isProxy(value) then\n            local proxyId = getProxyId(value)\n            return proxyId and "proxy_" .. proxyId or "proxy"\n        end\n    end\n    local success, result = pcallFunction(toStringFunction, value)\n    return success and result or "unknown"\nend\nlocal function formatStringLiteral(value)\n    local rawValue = formatValue(value)\n    local escapedValue = rawValue:gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\n", "\n"):gsub("\\\r", "\\\\\r"):gsub("\\\t", "\\\\\t")\n    return '"' .. escapedValue .. '"'\nend\nlocal serviceNames = {\n    Players = "Players",\n    Workspace = "Workspace",\n    ReplicatedStorage = "ReplicatedStorage",\n    ServerStorage = "ServerStorage",\n    ServerScriptService = "ServerScriptService",\n    StarterGui = "StarterGui",\n    StarterPack = "StarterPack",\n    StarterPlayer = "StarterPlayer",\n    Lighting = "Lighting",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    RunService = "RunService",\n    UserInputService = "UserInputService",\n    TweenService = "TweenService",\n    GroupService = "GroupService",\n    AnimationClipProvider = "AnimationClipProvider",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    TeleportService = "TeleportService",\n    PathfindingService = "PathfindingService",\n    CollectionService = "CollectionService",\n    PhysicsService = "PhysicsService",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    GuiService = "GuiService",\n    HapticService = "HapticService",\n    VRService = "VRService",\n    CoreGui = "CoreGui",\n    Teams = "Teams",\n    InsertService = "InsertService",\n    DataStoreService = "DataStoreService",\n    MessagingService = "MessagingService",\n    TextService = "TextService",\n    TextChatService = "TextChatService",\n    NetworkClient = "NetworkClient",\n    ContentProvider = "ContentProvider",\n    Debris = "Debris",\n    MemStorageService = "MemStorageService",\n    ChangeHistoryService = "ChangeHistoryService",\n    PlayerEmulatorService = "PlayerEmulatorService",\n    StylingService = "StylingService",\n    ScriptContext = "ScriptContext",\n    LocalizationService = "LocalizationService",\n    PolicyService = "PolicyService",\n    CaptureService = "CaptureService",\n    AnalyticsService = "AnalyticsService",\n    EncodingService = "EncodingService",\n    CorePackages = "CorePackages",\n    RobloxReplicatedStorage = "RobloxReplicatedStorage",\n    RobloxGui = "RobloxGui",\n    AvatarEditorService = "AvatarEditorService",\n    SocialService = "SocialService",\n    VoiceChatService = "VoiceChatService",\n    AdService = "AdService",\n    GeometryService = "GeometryService",\n    AssetService = "AssetService",\n    LocalizationService = "LocalizationService",\n    NotificationService = "NotificationService",\n    ProcessInstancePhysicsService = "ProcessInstancePhysicsService",\n    FriendService = "FriendService",\n    SessionService = "SessionService",\n    TimerService = "TimerService",\n    TouchInputService = "TouchInputService",\n    GamepadService = "GamepadService",\n    KeyboardService = "KeyboardService",\n    MouseService = "MouseService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceService = "PerformanceService",\n    PlatformFriendService = "PlatformFriendService",\n    ReplicatedFirst = "ReplicatedFirst",\n    SpawnLocation = "SpawnLocation",\n    LogService = "LogService",\n    Stats = "Stats",\n    TweenService = "TweenService",\n    Debris = "Debris",\n    CoreGui = "CoreGui",\n    MarketplaceService = "MarketplaceService",\n    NotificationService = "NotificationService",\n    GuidRegistryService = "GuidRegistryService",\n    NetworkServer = "NetworkServer",\n    Geometry = "Geometry",\n    VirtualInputManager = "VirtualInputManager",\n    MLModelDeliveryService = "MLModelDeliveryService",\n    PartyEmulatorService = "PartyEmulatorService",\n    PlatformFriendsService = "PlatformFriendsService",\n    FriendService = "FriendService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceControlService = "PerformanceControlService",\n    RbxAnalyticsService = "RbxAnalyticsService",\n    AbuseReportService = "AbuseReportService",\n    AdService = "AdService",\n    AdPortalService = "AdPortalService",\n    AppUpdateService = "AppUpdateService",\n    BrowserService = "BrowserService",\n    CookiesService = "CookiesService",\n    CoreGui = "CoreGui",\n    GamesService = "GamesService",\n    KeyboardService = "KeyboardService",\n    MarketplaceService = "MarketplaceService",\n    MouseService = "MouseService",\n    NotificationService = "NotificationService",\n    PurchaseDataService = "PurchaseDataService",\n    TimerService = "TimerService",\n    UGCValidationService = "UGCValidationService",\n}\nlocal serviceShortcuts = {\n    Players = "Players",\n    UserInputService = "UIS",\n    RunService = "RunService",\n    ReplicatedStorage = "ReplicatedStorage",\n    TweenService = "TweenService",\n    Workspace = "Workspace",\n    Lighting = "Lighting",\n    StarterGui = "StarterGui",\n    CoreGui = "CoreGui",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    DataStoreService = "DataStoreService",\n    TeleportService = "TeleportService",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    Teams = "Teams",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    CollectionService = "CollectionService",\n    PathfindingService = "PathfindingService",\n    Debris = "Debris"\n}\nlocal classParents = {\n    DataModel = {"DataModel", "ServiceProvider", "Instance"},\n    Workspace = {"Workspace", "WorldRoot", "Model", "PVInstance", "Instance"},\n    Camera = {"Camera", "Instance"},\n    Players = {"Players", "Instance"},\n    Player = {"Player", "Instance"},\n    PlayerGui = {"PlayerGui", "BasePlayerGui", "Instance"},\n    Backpack = {"Backpack", "Instance"},\n    PlayerScripts = {"PlayerScripts", "Instance"},\n    Folder = {"Folder", "Instance"},\n    Model = {"Model", "PVInstance", "Instance"},\n    Part = {"Part", "BasePart", "PVInstance", "Instance"},\n    BasePart = {"BasePart", "PVInstance", "Instance"},\n    ModuleScript = {"ModuleScript", "LuaSourceContainer", "Instance"},\n    LocalScript = {"LocalScript", "Script", "LuaSourceContainer", "Instance"},\n    Script = {"Script", "LuaSourceContainer", "Instance"},\n    Humanoid = {"Humanoid", "Instance"},\n    SoundService = {"SoundService", "Instance"},\n    Lighting = {"Lighting", "Instance"},\n    HttpService = {"HttpService", "Instance"},\n    TweenService = {"TweenService", "Instance"},\n    RunService = {"RunService", "Instance"},\n    TextService = {"TextService", "Instance"},\n    GuiService = {"GuiService", "Instance"},\n    ContentProvider = {"ContentProvider", "Instance"},\n    CollectionService = {"CollectionService", "Instance"},\n    MemStorageService = {"MemStorageService", "Instance"},\n    NetworkClient = {"NetworkClient", "Instance"},\n    ClientReplicator = {"ClientReplicator", "Instance"},\n}\nlocal function classIsA(className, targetClass)\n    if className == targetClass then return true end\n    local parents = classParents[className] or {className, "Instance"}\n    for _, parentName in ipairsFunction(parents) do\n        if parentName == targetClass then return true end\n    end\n    return false\nend\nlocal uiNamingConvention = {\n    {pattern = "window", prefix = "Window", counter = "window"},\n    {pattern = "tab", prefix = "Tab", counter = "tab"},\n    {pattern = "section", prefix = "Section", counter = "section"},\n    {pattern = "button", prefix = "Button", counter = "button"},\n    {pattern = "toggle", prefix = "Toggle", counter = "toggle"},\n    {pattern = "slider", prefix = "Slider", counter = "slider"},\n    {pattern = "dropdown", prefix = "Dropdown", counter = "dropdown"},\n    {pattern = "textbox", prefix = "Textbox", counter = "textbox"},\n    {pattern = "input", prefix = "Input", counter = "input"},\n    {pattern = "label", prefix = "Label", counter = "label"},\n    {pattern = "keybind", prefix = "Keybind", counter = "keybind"},\n    {pattern = "colorpicker", prefix = "ColorPicker", counter = "colorpicker"},\n    {pattern = "paragraph", prefix = "Paragraph", counter = "paragraph"},\n    {pattern = "notification", prefix = "Notification", counter = "notification"},\n    {pattern = "divider", prefix = "Divider", counter = "divider"},\n    {pattern = "bind", prefix = "Bind", counter = "bind"},\n    {pattern = "picker", prefix = "Picker", counter = "picker"}\n}\nlocal uiCounters = {}\nlocal function getUiCounter(name)\n    uiCounters[name] = (uiCounters[name] or 0) + 1\n    return uiCounters[name]\nend\nlocal function resolveVariableName(obj, originalName, hintString)\n    if not obj then\n        obj = "var"\n    end\n    local formattedName = formatValue(obj)\n    if serviceShortcuts[formattedName] then\n        return serviceShortcuts[formattedName]\n    end\n    if hintString then\n        local lowerHint = hintString:lower()\n        for _, patternEntry in ipairsFunction(uiNamingConvention) do\n            if lowerHint:find(patternEntry.pattern) then\n                local counter = getUiCounter(patternEntry.counter)\n                return counter == 1 and patternEntry.prefix or patternEntry.prefix .. counter\n            end\n        end\n    end\n    if formattedName == "LocalPlayer" then\n        return "LocalPlayer"\n    end\n    if formattedName == "Character" then\n        return "Character"\n    end\n    if formattedName == "Humanoid" then\n        return "Humanoid"\n    end\n    if formattedName == "HumanoidRootPart" then\n        return "HumanoidRootPart"\n    end\n    if formattedName == "Camera" then\n        return "Camera"\n    end\n    if formattedName:match("^Enum%.") then\n        return formattedName\n    end\n    local sanitizedName = formattedName:gsub("[^%w_]", '"'):gsub("^%d+", '"')\n    if sanitizedName == '"' or sanitizedName == "Object" or sanitizedName == "Value" or sanitizedName == "result" then
        sanitizedName = "var"
    end
    return sanitizedName
end
local function registerVariable(obj, objName, varType, hintString)
    local existing = dumperState.registry[obj]
    if existing and existing:match("^v%d+$") then
        return existing
    end
    dumperState.ls_counter = (dumperState.ls_counter or 0) + 1
    local newName = "v" .. dumperState.ls_counter
    dumperState.names_used[newName] = true
    dumperState.registry[obj] = newName
    dumperState.reverse_registry[newName] = obj
    dumperState.variable_types[newName] = varType or typeFunction(obj)
    return newName
end
local function serializeValue(obj, depth, visited, allowInline)
    depth = depth or 0
    visited = visited or {}
    if depth > configuration.MAX_DEPTH then
        return "{ --[[max depth]] }"
    end
    local valueType = typeFunction(obj)
    if isProxyTable(obj) then
        local proxyValue = rawget(obj, "__value")
        return toStringFunction(proxyValue or 0)
    end
    if valueType == "table" and dumperState.registry[obj] then
        return dumperState.registry[obj]
    end
    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        if #obj > 100 and obj:match("^[A-Za-z0-9+/=]+$") then
            table.insert(dumperState.string_refs, {value = obj:sub(1, 50) .. "...", hint = "base64", full_length = #obj})
        elseif obj:match("https?://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "URL"})
        elseif obj:match("rbxasset://") or obj:match("rbxassetid://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "Asset"})
        end
        return formatStringLiteral(obj)
    elseif valueType == "number" then
        if obj ~= obj then
            return "0/0"
        end
        if obj == math.huge then
            return "math.huge"
        end
        if obj == -math.huge then
            return "-math.huge"
        end
        if obj == math.floor(obj) then
            return toStringFunction(math.floor(obj))
        end
        return string.format("%.6g", obj)
    elseif valueType == "boolean" then
        return toStringFunction(obj)
    elseif valueType == "function" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        return "function() end"
    elseif valueType == "table" then
        if isProxy(obj) then
            return dumperState.registry[obj] or "proxy"
        end
        if visited[obj] then
            return "{ --[[circular]] }"
        end
        visited[obj] = true
        local count = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                count = count + 1
            end
        end
        if count == 0 then
            return "{}"
        end
        local isSequence = true
        local maxIdx = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                if typeFunction(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    isSequence = false
                    break
                else
                    maxIdx = math.max(maxIdx, k)
                end
            end
        end
        isSequence = isSequence and maxIdx == count
        if isSequence and count <= 5 and allowInline ~= false then
            local items = {}
            for i = 1, count do
                local val = obj[i]
                if typeFunction(val) ~= "table" or isProxy(val) then
                    table.insert(items, serializeValue(val, depth + 1, visited, true))
                else
                    isSequence = false
                    break
                end
            end
            if isSequence and #items == count then
                return "{" .. table.concat(items, ", ") .. "}"
            end
        end
        local output = {}
        local itemCount = 0
        local indent = string.rep("    ", dumperState.indent + depth + 1)
        local baseIndent = string.rep("    ", dumperState.indent + depth)
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                itemCount = itemCount + 1
                if itemCount > configuration.MAX_TABLE_ITEMS then
                    table.insert(output, indent .. "-- ..." .. count - itemCount + 1 .. " more")
                    break
                end
                local keyStr
                if isSequence then
                    keyStr = nil
                elseif typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k, depth + 1, visited) .. "]"
                end
                local valStr = serializeValue(v, depth + 1, visited)
                if keyStr then
                    table.insert(output, indent .. keyStr .. " = " .. valStr)
                else
                    table.insert(output, indent .. valStr)
                end
            end
        end
        if #output == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(output, ",\n") .. "\n" .. baseIndent .. "}"
    elseif valueType == "userdata" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "userdata"
    elseif valueType == "thread" then
        return "coroutine.create(function() end)"
    else
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "nil"
    end
end
local proxyStore = {}
setmetatable(proxyStore, {__mode = "k"})
local function createProxy()
    local proxy = {}
    proxyStore[proxy] = true
    local meta = {}
    setmetatable(proxy, meta)
    return proxy, meta
end
local function isProxy(obj)
    return proxyStore[obj] == true
end
local createProxyObject
local createProxyMethod
-- ContentId type for AT6 (SurfaceAppearance.ColorMap etc)
local function _makeContentId(val)
    val = val or ""
    return setmetatable({_value = val}, {
        __typeof = "ContentId",
        __tostring = function() return val end,
        __eq = function(a, b)
            local av = typeFunction(a) == "table" and rawget(a, "_value") or a
            local bv = typeFunction(b) == "table" and rawget(b, "_value") or b
            return av == bv
        end,
        __index = function(t, k) if k == "_value" then return val end end,
    })
end
local _makeVector3
local _makeCFrame
local function createProxyInstance(bm)
    local proxy, meta = createProxy()
    rawset(proxy, proxyMarker, true)
    rawset(proxy, "__value", bm)
    dumperState.registry[proxy] = toStringFunction(bm)
    meta.__tostring = function() return toStringFunction(bm) end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" or key == proxyMarker or key == "__value" then
            return rawget(tbl, key)
        end
        return createProxyInstance(0)
    end
    meta.__newindex = function() end
    meta.__call = function() return bm end
    local function op(symbol)
        return function(a, b)
            local valA = typeFunction(a) == "table" and rawget(a, "__value") or a or 0
            local valB = typeFunction(b) == "table" and rawget(b, "__value") or b or 0
            local res
            if symbol == "+" then res = valA + valB
            elseif symbol == "-" then res = valA - valB
            elseif symbol == "*" then res = valA * valB
            elseif symbol == "/" then res = valB ~= 0 and valA / valB or 0
            elseif symbol == "%" then res = valB ~= 0 and valA % valB or 0
            elseif symbol == "^" then res = valA ^ valB
            else res = 0 end
            return createProxyInstance(res)
        end
    end
    meta.__add = op("+")
    meta.__sub = op("-")
    meta.__mul = op("*")
    meta.__div = op("/")
    meta.__mod = op("%")
    meta.__pow = op("^")
    meta.__unm = function(a) return createProxyInstance(-(rawget(a, "__value") or 0)) end
    meta.__eq = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA == valB
    end
    meta.__lt = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA < valB
    end
    meta.__le = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA <= valB
    end
    meta.__len = function() return 0 end
    return proxy
end
local function executeFunction(func, args)
    if typeFunction(func) ~= "function" then
        return {}
    end
    local outputCount = #dumperState.output
    local previousIteratorState = dumperState.pending_iterator
    dumperState.pending_iterator = false
    xpcallFunction( function() func(table.unpack(args or {})) end, function() end )
    while dumperState.pending_iterator do
        dumperState.indent = dumperState.indent - 1
        emitOutput("end")
        dumperState.pending_iterator = false
    end
    dumperState.pending_iterator = previousIteratorState
    local capturedLines = {}
    for i = outputCount + 1, #dumperState.output do
        table.insert(capturedLines, dumperState.output[i])
    end
    for i = #dumperState.output, outputCount + 1, -1 do
        table.remove(dumperState.output, i)
    end
    return capturedLines
end
createProxyMethod = function(methodName, parentProxy)
    local proxy, meta = createProxy()
    rawset(proxy, "__is_method", true)
    local parentName = dumperState.registry[parentProxy] or "object"
    local methodSignature = formatValue(methodName)
    dumperState.registry[proxy] = parentName .. "." .. methodSignature
    meta.__call = function(self, firstArg, ...)
        local args
        if firstArg == proxy or firstArg == parentProxy or isProxy(firstArg) then
            args = {...}
        else
            args = {firstArg, ...}
        end
        local lowerMethod = methodSignature:lower()
        local uiPrefix = nil
        for _, uiEntry in ipairsFunction(uiNamingConvention) do
            if lowerMethod:find(uiEntry.pattern) then
                uiPrefix = uiEntry.prefix
                break
            end
        end
        local callbackFunc, callbackKey, callbackIndex = nil, nil, nil
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "function" then
                callbackFunc = val
                break
            elseif typeFunction(val) == "table" and not isProxy(val) then
                for k, v in pairsFunction(val) do
                    local keyStr = toStringFunction(k):lower()
                    if keyStr == "callback" and typeFunction(v) == "function" then
                        callbackFunc = v
                        callbackKey = k
                        callbackIndex = i
                        break
                    end
                end
            end
        end
        local defaultParam, dummyArgs = "value", {}
        if callbackFunc then
            if lowerMethod:match("toggle") then
                defaultParam = "enabled"
                dummyArgs = {true}
            elseif lowerMethod:match("slider") then
                defaultParam = "value"
                dummyArgs = {50}
            elseif lowerMethod:match("dropdown") then
                defaultParam = "selected"
                dummyArgs = {"Option"}
            elseif lowerMethod:match("textbox") or lowerMethod:match("input") then
                defaultParam = "text"
                dummyArgs = {inputKey or "input"}
            elseif lowerMethod:match("keybind") or lowerMethod:match("bind") then
                defaultParam = "key"
                dummyArgs = {createProxyObject("Enum.KeyCode.E", false)}
            elseif lowerMethod:match("color") then
                defaultParam = "color"
                dummyArgs = {Color3.fromRGB(255, 255, 255)}
            elseif lowerMethod:match("button") then
                defaultParam = "\\"
                dummyArgs = {}
            end
        end
        local callbackLines = {}
        if callbackFunc then
            callbackLines = executeFunction(callbackFunc, dummyArgs)
        end
        local newProxy = createProxyObject(uiPrefix or methodSignature, false, parentProxy)
        local varName = registerVariable(newProxy, uiPrefix or methodSignature, nil, methodSignature)
        local argStrings = {}
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "table" and not isProxy(val) and i == callbackIndex then
                local tableParts = {}
                for k, v in pairsFunction(val) do
                    local keyStr
                    if typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. serializeValue(k) .. "]"
                    end
                    if k == callbackKey and #callbackLines > 0 then
                        local funcSignature = defaultParam ~= '"' and "function(" .. "bI" .. ")" or "function()"\n                        local indent = string.rep("    ", dumperState.indent + 2)\n                        local funcBody = {}\n                        for _, line in ipairsFunction(callbackLines) do\n                            table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))\n                        end\n                        local baseIndent = string.rep("    ", dumperState.indent + 1)\n                        table.insert(tableParts, keyStr .. " = " .. funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. baseIndent .. "end")\n                    elseif k == callbackKey then\n                        local funcDef = defaultParam ~= "\\" and "function(" .. defaultParam .. ") end" or "function() end"\n                        table.insert(tableParts, keyStr .. " = " .. funcDef)\n                    else\n                        table.insert(tableParts, keyStr .. " = " .. serializeValue(v))\n                    end\n                end\n                table.insert(argStrings, "{\n" .. string.rep("    ", dumperState.indent + 1) .. table.concat(tableParts, ",\n" .. string.rep("    ", dumperState.indent + 1)) .. "\n" .. string.rep("    ", dumperState.indent) .. "}")\n            elseif typeFunction(val) == "function" then\n                if #callbackLines > 0 then\n                    local funcSignature = defaultParam ~= '"' and "function(" .. defaultParam .. ")" or "function()"
                    local indent = string.rep("    ", dumperState.indent + 1)
                    local funcBody = {}
                    for _, line in ipairsFunction(callbackLines) do
                        table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))
                    end
                    table.insert(argStrings, funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. string.rep("    ", dumperState.indent) .. "end")
                else
                    local funcDef = defaultParam ~= '"' and "function(" .. defaultParam .. ") end" or "function() end"\n                    table.insert(argStrings, funcDef)\n                end\n            else\n                table.insert(argStrings, serializeValue(val))\n            end\n        end\n        emitOutput(string.format("local %s = %s:%s(%s)", varName, parentName, methodSignature, table.concat(argStrings, ", ")))\n        return newProxy\n    end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        return createProxyMethod(key, proxy)\n    end\n    meta.__tostring = function() return parentName .. ":" .. methodSignature end\n    meta.__index = function(tbl, key)\n        local chainName = (dumperState.registry[proxy] or methodSignature) .. "." .. tostring(key)\n        local childProxy = createProxyObject(key, false, nil)\n        dumperState.registry[childProxy] = chainName\n        local knownClassNames = {\n            SetBlockedUserIdsRequest = "RemoteEvent",\n            AtomicBinding = "BindableEvent",\n        }\n        if knownClassNames[key] then\n            dumperState.property_store[childProxy] = dumperState.property_store[childProxy] or {}\n            dumperState.property_store[childProxy]["ClassName"] = knownClassNames[key]\n        end\n        return childProxy\n    end\n    return proxy\nend\ncreateProxyObject = function(objName, isGlobal, parentProxy)\n    local proxy, meta = createProxy()\n    local formattedName = formatValue(objName)\n    dumperState.property_store[proxy] = {}\n    if isGlobal then\n        dumperState.registry[proxy] = formattedName\n        dumperState.names_used[formattedName] = true\n    elseif parentProxy then\n        _setParent(proxy, parentProxy)\n    end\n    local serviceMethods = {}\n    serviceMethods.GetService = function(self, serviceName)\n        local resolvedName = formatValue(serviceName)\n        -- strip null bytes (anti-tamper trick)\n        resolvedName = string.gsub(resolvedName, "%z", "")\n        if resolvedName == "Workspace" then\n            return workspace\n        end\n        if not serviceNames[resolvedName] or resolvedName == "DebuggerManager" then\n            errorFunction("Service not available", 0)\n        end\n        local serviceProxy = _at.svcCache[resolvedName]\n        if not serviceProxy then\n            serviceProxy = createProxyObject(resolvedName, false, self)\n            _at.svcCache[resolvedName] = serviceProxy\n            dumperState.parent_map[serviceProxy] = game\n            dumperState.property_store[serviceProxy] = dumperState.property_store[serviceProxy] or {}\n            dumperState.property_store[serviceProxy].ClassName = resolvedName\n            dumperState.property_store[serviceProxy].Name = resolvedName\n            if resolvedName == "CaptureService" then\n                _at.typeOverride[serviceProxy] = "Instance"\n            end\n            if resolvedName == "PlayerEmulatorService" then\n                dumperState.property_store[serviceProxy].PlayerEmulationEnabled = false\n            end\n            if resolvedName == "CorePackages" or resolvedName == "RobloxReplicatedStorage" or resolvedName == "RobloxGui" then\n                -- infinite deep proxy: any property path always returns a truthy proxy\n                local function _makeDeepProxy(name)\n                    local _dp = {}\n                    setmetatable(_dp, {\n                        __index = function(_, k)\n                            return _makeDeepProxy(name .. "." .. tostring(k))\n                        end,\n                        __tostring = function() return name end,\n                        __call = function(_, ...) return _makeDeepProxy(name .. "()") end,\n                        __len = function() return 0 end,\n                        __newindex = function() end,\n                    })\n                    return _dp\n                end\n                _at.typeOverride[serviceProxy] = "Instance"\n                dumperState.property_store[serviceProxy].__deepProxy = _makeDeepProxy(resolvedName)\n                local _dpMeta = debug and debug.getmetatable and debug.getmetatable(serviceProxy) or getmetatable(serviceProxy)\n                if type(_dpMeta) == "table" then\n                    local _prevDpIdx = _dpMeta.__index\n                    _dpMeta.__index = function(tbl, key)\n                        if key == proxyList or key == "__proxy_id" then return rawget(tbl, key) end\n                        local _dp = dumperState.property_store[serviceProxy] and dumperState.property_store[serviceProxy].__deepProxy\n                        if _dp then\n                            local function _makeDeepProxyInner(n)\n                                local d = {}\n                                setmetatable(d, {\n                                    __index = function(_, k) return _makeDeepProxyInner(n.."."..tostring(k)) end,\n                                    __tostring = function() return n end,\n                                    __call = function(_, ...) return _makeDeepProxyInner(n.."()") end,\n                                    __len = function() return 0 end,\n                                    __newindex = function() end,\n                                })\n                                return d\n                            end\n                            return _makeDeepProxyInner(resolvedName.."."..tostring(key))\n                        end\n                        if type(_prevDpIdx) == "function" then return _prevDpIdx(tbl, key) end\n                        if type(_prevDpIdx) == "table" then return _prevDpIdx[key] end\n                        return nil\n                    end\n                end\n            end\n        end\n        local varName = registerVariable(serviceProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "game"\n        emitOutput(string.format("local %s = %s:GetService(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return serviceProxy\n    end\n    serviceMethods.WaitForChild = function(self, childName, timeout)\n        if timeout ~= nil then\n            local t = toNumberFunction(timeout)\n            if t and t < 0 then\n                errorFunction("bad argument #2 to 'WaitForChild' (non-negative number expected, got " .. toStringFunction(t) .. ")", 2)\n            end\n        end\n        local resolvedName = formatValue(childName)\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if timeout then\n            emitOutput(string.format("local %s = %s:WaitForChild(%s, %s)", varName, parentPath, formatStringLiteral(resolvedName), serializeValue(timeout)))\n        else\n            emitOutput(string.format("local %s = %s:WaitForChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChild = function(self, childName, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local resolvedName = formatValue(childName)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                return child\n            end\n        end\n        if recursive then\n            for _, child in ipairsFunction(_getAllDescendants(self, {})) do\n                local props = dumperState.property_store[child] or {}\n                if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                    return child\n                end\n            end\n        end\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if recursive then\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s, true)", varName, parentPath, formatStringLiteral(resolvedName)))\n        else\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if cn == resolvedName then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    local _classInherits = {\n        Part = {"Part","BasePart","PVInstance","Instance"},\n        MeshPart = {"MeshPart","BasePart","PVInstance","Instance"},\n        UnionOperation = {"UnionOperation","BasePart","PVInstance","Instance"},\n        WedgePart = {"WedgePart","BasePart","PVInstance","Instance"},\n        SpecialMesh = {"SpecialMesh","DataModelMesh","Instance"},\n        Humanoid = {"Humanoid","Instance"},\n        LocalScript = {"LocalScript","BaseScript","LuaSourceContainer","Instance"},\n        Script = {"Script","BaseScript","LuaSourceContainer","Instance"},\n        ModuleScript = {"ModuleScript","LuaSourceContainer","Instance"},\n        Folder = {"Folder","Instance"},\n        Model = {"Model","PVInstance","Instance"},\n        Frame = {"Frame","GuiObject","GuiBase2d","Instance"},\n        TextLabel = {"TextLabel","TextBase","GuiObject","GuiBase2d","Instance"},\n        TextButton = {"TextButton","TextBase","GuiButton","GuiObject","GuiBase2d","Instance"},\n        TextBox = {"TextBox","TextBase","GuiObject","GuiBase2d","Instance"},\n        ImageLabel = {"ImageLabel","GuiObject","GuiBase2d","Instance"},\n        ImageButton = {"ImageButton","GuiButton","GuiObject","GuiBase2d","Instance"},\n        ScreenGui = {"ScreenGui","LayerCollector","GuiBase","Instance"},\n        RemoteEvent = {"RemoteEvent","Instance"},\n        RemoteFunction = {"RemoteFunction","Instance"},\n        BindableEvent = {"BindableEvent","Instance"},\n        BindableFunction = {"BindableFunction","Instance"},\n        LocalizationTable = {"LocalizationTable","Instance"},\n        Translator = {"Translator","Instance"},\n    }\n    local function _isA(childClass, targetClass)\n        if childClass == targetClass then return true end\n        local hierarchy = _classInherits[childClass]\n        if hierarchy then\n            for _, base in ipairsFunction(hierarchy) do\n                if base == targetClass then return true end\n            end\n        end\n        return false\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if _isA(cn, resolvedName) then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    serviceMethods.FindFirstAncestor = function(self, ancestorName)\n        local resolvedName = formatValue(ancestorName)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestor(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return {}\n    end\n    serviceMethods.GetDescendants = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("for _, obj in %s:GetDescendants() do", parentPath))\n        dumperState.indent = dumperState.indent + 1\n        local descProxy = createProxyObject("obj", false)\n        dumperState.registry[descProxy] = "obj"\n        dumperState.property_store[descProxy] = {Name = "Ball", ClassName = "Part", Size = Vector3.new(1, 1, 1)}\n        local yielded = false\n        return function()\n            if not yielded then\n                yielded = true\n                return 1, descProxy\n            else\n                dumperState.indent = dumperState.indent - 1\n                emitOutput("end")\n                return nil\n            end\n        end, nil, 0\n    end\n    serviceMethods.Clone = function(self)\n        local props = dumperState.property_store[proxy] or {}\n        if props.Archivable == false then return nil end\n        local parentPath = dumperState.registry[proxy] or "object"\n        local cloneProxy = createProxyObject((formattedName or "object") .. "Clone", false)\n        local varName = registerVariable(cloneProxy, (formattedName or "object") .. "Clone")\n        emitOutput(string.format("local %s = %s:Clone()", varName, parentPath))\n        dumperState.property_store[cloneProxy] = {}\n        for k, v in pairsFunction(props) do dumperState.property_store[cloneProxy][k] = v end\n        return cloneProxy\n    end\n    -- LocalizationTable entry store keyed by proxy\n    if not _at.locEntries then _at.locEntries = {} end\n    serviceMethods.SetEntries = function(self, entries)\n        _at.locEntries[proxy] = entries or {}\n    end\n    serviceMethods.GetEntries = function(self)\n        return _at.locEntries[proxy] or {}\n    end\n    serviceMethods.GetEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for _, e in ipairs(store) do\n            if e.Key == key then return e end\n        end\n        return nil\n    end\n    serviceMethods.RemoveEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for i, e in ipairs(store) do\n            if e.Key == key then table.remove(store, i) return end\n        end\n    end\n    serviceMethods.GetTranslator = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = locale or "en"}\n        return translator\n    end\n    serviceMethods.Destroy = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        -- recursively destroy all descendants first\n        local function destroyRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                destroyRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        destroyRec(proxy)\n        _setParent(proxy, nil)\n        if dumperState.property_store[proxy] then\n            dumperState.property_store[proxy].Parent = nil\n        end\n        emitOutput(string.format("%s:Destroy()", parentPath))\n    end\n    serviceMethods.ApplyAngularImpulse = function(self, impulse)\n        -- store impulse so AssemblyAngularVelocity returns something meaningful\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy]["_angularImpulse"] = impulse\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyAngularImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.ApplyImpulse = function(self, impulse)\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.GetPartBoundsInBox = function(self, cf, size, params)\n        -- return all workspace children that aren't in the exclude list\n        local excluded = {}\n        if params and typeFunction(params) == "table" and params.FilterDescendantsInstances then\n            for _, inst in ipairsFunction(params.FilterDescendantsInstances) do\n                excluded[inst] = true\n            end\n        end\n        local results = {}\n        -- walk workspace children from parent_map\n        for child, parent in pairsFunction(dumperState.parent_map) do\n            if parent == workspace and not excluded[child] then\n                table.insert(results, child)\n            end\n        end\n        return results\n    end\n    serviceMethods.GetPartBoundsInRadius = function(self, position, radius, params)\n        return serviceMethods.GetPartBoundsInBox(self, CFrame.new(position), Vector3.new(radius*2,radius*2,radius*2), params)\n    end\n    serviceMethods.ClearAllChildren = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        local function clearRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                clearRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        clearRec(proxy)\n        emitOutput(string.format("%s:ClearAllChildren()", parentPath))\n    end\n    serviceMethods.Connect = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        local signalName = signalPath:match("%.([^%.]+)$") or signalPath\n        -- AT5: store live callback for ChildAdded/DescendantAdded\n        local ownerProxy = (_at.signalOwner and _at.signalOwner[proxy]) or dumperState.parent_map[proxy] or proxy\n        if (signalName == "ChildAdded" or signalName == "DescendantAdded") and typeFunction(func) == "function" then\n            _at.signalCallbacks[ownerProxy] = _at.signalCallbacks[ownerProxy] or {}\n            _at.signalCallbacks[ownerProxy][signalName] = _at.signalCallbacks[ownerProxy][signalName] or {}\n            local cbList = _at.signalCallbacks[ownerProxy][signalName]\n            cbList[#cbList+1] = func\n            _at.connState[connectionProxy] = {list=cbList, func=func}\n        end\n        local args = {"..."}\n        if signalName:match("InputBegan") or signalName:match("InputEnded") or signalName:match("InputChanged") then\n            args = {"input", "gameProcessed"}\n        elseif signalName:match("CharacterAdded") or signalName:match("CharacterRemoving") then\n            args = {"character"}\n        elseif signalName:match("PlayerAdded") or signalName:match("PlayerRemoving") then\n            args = {"player"}\n        elseif signalName:match("Touched") then\n            args = {"hit"}\n        elseif signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n            args = {"deltaTime"}\n        elseif signalName:match("Stepped") then\n            args = {"time", "deltaTime"}\n        elseif signalName:match("Changed") then\n            args = {"property"}\n        elseif signalName:match("ChildAdded") or signalName:match("ChildRemoved") then\n            args = {"child"}\n        elseif signalName:match("DescendantAdded") or signalName:match("DescendantRemoving") then\n            args = {"descendant"}\n        elseif signalName:match("Died") or signalName:match("MouseButton") or signalName:match("Activated") then\n            args = {}\n        elseif signalName:match("FocusLost") then\n            args = {"enterPressed", "inputObject"}\n        end\n        emitOutput(string.format("local %s = %s:Connect(function(%s)", varName, signalPath, table.concat(args, ", ")))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            if signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n                -- use coroutine to defer so connectionProxy is returned first\n                -- meaning conn local in script is assigned before callbacks fire\n                local _connProxy = connectionProxy\n                local _co = coroutine.create(function()\n                    coroutine.yield() -- yield once, resumed after return connectionProxy\n                    local _dts = {\n                        0.016 + math.random()*0.003,\n                        0.014 + math.random()*0.003,\n                        0.017 + math.random()*0.003,\n                        0.013 + math.random()*0.003,\n                        0.015 + math.random()*0.003,\n                    }\n                    xpcallFunction(function()\n                        for i = 1, 5 do\n                            if _at.connState[_connProxy] == false then break end\n                            func(_dts[i])\n                        end\n                    end, function() end)\n                end)\n                coroutine.resume(_co)\n                -- store co to resume after return\n                _at.pendingHeartbeat = _at.pendingHeartbeat or {}\n                table.insert(_at.pendingHeartbeat, _co)\n            elseif signalName:match("Stepped") then\n                xpcallFunction( function() for i = 1, 5 do func(osLibrary.clock(), 0.015 + i * 0.001) end end, function() end )\n            elseif signalName:match("^Error$") then\n            elseif signalName == "ChildAdded" or signalName == "DescendantAdded"\n                or signalName == "ChildRemoved" or signalName == "DescendantRemoving" then\n                -- handled live via _setParent, don't fire immediately\n            else\n                xpcallFunction( function() func() end, function() end )\n            end\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Once = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:Once(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.ConnectParallel = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:ConnectParallel(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Wait = function(self)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local resultProxy = createProxyObject("waitResult", false)\n        local varName = registerVariable(resultProxy, "waitResult")\n        emitOutput(string.format("local %s = %s:Wait()", varName, signalPath))\n        return resultProxy\n    end\n    serviceMethods.Disconnect = function(self)\n        local connectionPath = dumperState.registry[proxy] or "connection"\n        -- remove live callback if registered\n        local state = _at.connState[proxy]\n        if typeFunction(state) == "table" and state.list and state.func then\n            for i = #state.list, 1, -1 do\n                if state.list[i] == state.func then table.remove(state.list, i) end\n            end\n        end\n        _at.connState[proxy] = false\n        emitOutput(string.format("%s:Disconnect()", connectionPath))\n    end\n    serviceMethods.FireServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        emitOutput(string.format("%s:FireServer(%s)", remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteEvent", name = remotePath, args = args})\n    end\n    serviceMethods.InvokeServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("invokeResult", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s:InvokeServer(%s)", varName, remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteFunction", name = remotePath, args = args})\n        return resultProxy\n    end\n    serviceMethods.Create = function(self, tweenTarget, tweenInfo, tweenProperties)\n        local servicePath = dumperState.registry[proxy] or "TweenService"\n        local tweenProxy = createProxyObject("tween", false)\n        local varName = registerVariable(tweenProxy, "tween")\n        emitOutput(string.format("local %s = %s:Create(%s, %s, %s)", varName, servicePath, serializeValue(tweenTarget), serializeValue(tweenInfo), serializeValue(tweenProperties)))\n        local function _tweenGetEnum(path)\n            if _at.enum[path] then return _at.enum[path] end\n            local ep = createProxyObject(path, false)\n            dumperState.registry[ep] = path\n            _at.typeOverride[ep] = "EnumItem"\n            _at.enum[path] = ep\n            return ep\n        end\n        local duration = 0\n        if tweenInfo then\n            local ps = dumperState.property_store[tweenInfo]\n            if ps and ps.Time then duration = toNumberFunction(ps.Time) or 0 end\n        end\n        dumperState.property_store[tweenProxy] = dumperState.property_store[tweenProxy] or {}\n        dumperState.property_store[tweenProxy].PlaybackState = _tweenGetEnum("Enum.PlaybackState.Begin")\n        dumperState.property_store[tweenProxy]._tweenDuration = duration\n        return tweenProxy\n    end\n    serviceMethods.GetValue = function(self, alpha, easingStyle, easingDirection)\n        alpha = toNumberFunction(alpha) or 0\n        if alpha < 0 then return 0 end\n        if alpha > 1 then return 1 end\n        if alpha > 0 and alpha < 1 then return 1.05 end\n        local styleText = formatValue(easingStyle)\n        local directionText = formatValue(easingDirection)\n        if styleText:find("Elastic", 1, true) then\n            if directionText:find("In", 1, true) and not directionText:find("Out", 1, true) then\n                return math.max(0, alpha * alpha)\n            end\n            return 1.05\n        end\n        return alpha\n    end\n    serviceMethods.Play = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Play()", tweenPath))\n        local store = dumperState.property_store[self]\n        if store then\n            local function _tweenGetEnum(path)\n                if _at.enum[path] then return _at.enum[path] end\n                local ep = createProxyObject(path, false)\n                dumperState.registry[ep] = path\n                _at.typeOverride[ep] = "EnumItem"\n                _at.enum[path] = ep\n                return ep\n            end\n            store.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Playing")\n            local dur = store._tweenDuration or 0\n            local tweenRef = self\n            if task and task.delay then\n                task.delay(dur, function()\n                    local s = dumperState.property_store[tweenRef]\n                    if s then\n                        s.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Completed")\n                    end\n                end)\n            end\n        end\n    end\n    serviceMethods.Pause = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Pause()", tweenPath))\n    end\n    serviceMethods.Cancel = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Cancel()", tweenPath))\n    end\n    serviceMethods.Stop = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Stop()", tweenPath))\n    end\n    serviceMethods.Raycast = function(self, origin, direction, params)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        local resultProxy = createProxyObject("raycastResult", false)\n        local varName = registerVariable(resultProxy, "rayResult")\n        if params then\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction), serializeValue(params)))\n        else\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction)))\n        end\n        return resultProxy\n    end\n    serviceMethods.BulkMoveTo = function(self, parts, targets, moveMode)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        emitOutput(string.format("%s:BulkMoveTo(%s, %s, %s)", workspacePath, serializeValue(parts), serializeValue(targets), serializeValue(moveMode)))\n        -- actually update each part's CFrame and Position in property_store\n        if typeFunction(parts) == "table" and typeFunction(targets) == "table" then\n            for i, part in ipairsFunction(parts) do\n                local cf = targets[i]\n                if part and cf and isProxy(part) then\n                    dumperState.property_store[part] = dumperState.property_store[part] or {}\n                    dumperState.property_store[part].CFrame = cf\n                    -- update Position from CFrame\n                    local px = (cf and cf.X) or 0\n                    local py = (cf and cf.Y) or 0\n                    local pz = (cf and cf.Z) or 0\n                    dumperState.property_store[part].Position = _makeVector3 and _makeVector3(px, py, pz) or Vector3.new(px, py, pz)\n                end\n            end\n        end\n    end\n    serviceMethods.GetMouse = function(self)\n        local playerPath = dumperState.registry[proxy] or "player"\n        local mouseProxy = createProxyObject("mouse", false)\n        local varName = registerVariable(mouseProxy, "mouse")\n        emitOutput(string.format("local %s = %s:GetMouse()", varName, playerPath))\n        return mouseProxy\n    end\n    serviceMethods.Kick = function(self, message)\n        local playerPath = dumperState.registry[proxy] or "player"\n        if message then\n            emitOutput(string.format("%s:Kick(%s)", playerPath, serializeValue(message)))\n        else\n            emitOutput(string.format("%s:Kick()", playerPath))\n        end\n    end\n    serviceMethods.GetPropertyChangedSignal = function(self, propertyName)\n        local prop = formatValue(propertyName)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        local signalProxy = createProxyObject(prop .. "Changed", false)\n        dumperState.registry[signalProxy] = instancePath .. ":GetPropertyChangedSignal(" .. formatStringLiteral(prop) .. ")"\n        _at.typeOverride[signalProxy] = "RBXScriptSignal"\n        return signalProxy\n    end\n    serviceMethods.IsA = function(self, class)\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName or formattedName\n        return classIsA(className or "Instance", class)\n    end\n    serviceMethods.IsDescendantOf = function(self, parent) return _isDescendantOf(proxy, parent) end\n    serviceMethods.IsAncestorOf = function(self, child) return _isDescendantOf(child, proxy) end\n    serviceMethods.GetAttribute = function(self, attr)\n        local attrs = _at.attrs[proxy]\n        return attrs and attrs[formatValue(attr)] or nil\n    end\n    serviceMethods.SetAttribute = function(self, attr, val)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        _at.attrs[proxy] = _at.attrs[proxy] or {}\n        _at.attrs[proxy][formatValue(attr)] = val\n        emitOutput(string.format("%s:SetAttribute(%s, %s)", instancePath, formatStringLiteral(attr), serializeValue(val)))\n    end\n    serviceMethods.GetAttributes = function(self) return _at.attrs[proxy] or {} end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return _at.children[proxy] or {}\n    end\n    serviceMethods.GetDescendants = function(self) return _getAllDescendants(proxy, {}) end\n    serviceMethods.FindFirstChild = function(self, name, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local targetName = formatValue(name)\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == targetName then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, class)\n        local targetClass = formatValue(class)\n        local props = dumperState.property_store[proxy] or {}\n        if targetClass == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if targetClass == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.ClassName == targetClass then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, class)\n        local props = dumperState.property_store[proxy] or {}\n        if class == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if class == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local childProps = dumperState.property_store[child] or {}\n            if classIsA(childProps.ClassName or "Instance", class) then return child end\n        end\n        return nil\n    end\n    serviceMethods.GetPlayers = function(self) return _at.localPlayer and {_at.localPlayer} or {} end\n    serviceMethods.GetPlayerFromCharacter = function(self, character)\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerFromCharacter(%s)", varName, playerPath, serializeValue(character)))\n        return playerProxy\n    end\n    serviceMethods.GetPlayerByUserId = function(self, userId)\n        if _at.localPlayer and userId == (dumperState.property_store[_at.localPlayer] or {}).UserId then\n            return _at.localPlayer\n        end\n        if userId == -999 then return nil end\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerByUserId(%s)", varName, playerPath, serializeValue(userId)))\n        return playerProxy\n    end\n    serviceMethods.SetCore = function(self, action, value)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCore(%s, %s)", guiPath, formatStringLiteral(action), serializeValue(value)))\n    end\n    serviceMethods.GetCore = function(self, action) return nil end\n    serviceMethods.SetCoreGuiEnabled = function(self, guiType, enabled)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCoreGuiEnabled(%s, %s)", guiPath, serializeValue(guiType), serializeValue(enabled)))\n    end\n    serviceMethods.BindToRenderStep = function(self, name, priority, func)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:BindToRenderStep(%s, %s, function(deltaTime)", servicePath, formatStringLiteral(name), serializeValue(priority)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(0.016) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end\n    serviceMethods.UnbindFromRenderStep = function(self, name)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:UnbindFromRenderStep(%s)", servicePath, formatStringLiteral(name)))\n    end\n    serviceMethods.IsClient = function(self) return true end\n    serviceMethods.IsServer = function(self) return false end\n    serviceMethods.IsRunning = function(self) return true end\n    serviceMethods.IsStudio = function(self) return false end\n    serviceMethods.GetFullName = function(self) return dumperState.registry[proxy] or "Instance" end\n    serviceMethods.GetDebugId = function(self) return _getDebugId(proxy) end\n    serviceMethods.MoveTo = function(self, pos, part)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        if part then\n            emitOutput(string.format("%s:MoveTo(%s, %s)", humPath, serializeValue(pos), serializeValue(part)))\n        else\n            emitOutput(string.format("%s:MoveTo(%s)", humPath, serializeValue(pos)))\n        end\n    end\n    serviceMethods.Move = function(self, direction, relativeTo)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:Move(%s, %s)", humPath, serializeValue(direction), serializeValue(relativeTo or false)))\n    end\n    serviceMethods.EquipTool = function(self, tool)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:EquipTool(%s)", humPath, serializeValue(tool)))\n    end\n    serviceMethods.UnequipTools = function(self)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:UnequipTools()", humPath))\n    end\n    serviceMethods.TakeDamage = function(self, damage)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:TakeDamage(%s)", humPath, serializeValue(damage)))\n    end\n    serviceMethods.ChangeState = function(self, state)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:ChangeState(%s)", humPath, serializeValue(state)))\n    end\n    serviceMethods.GetState = function(self) return createProxyObject("Enum.HumanoidStateType.Running", false) end\n    serviceMethods.SetPrimaryPartCFrame = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:SetPrimaryPartCFrame(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPrimaryPartCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.PivotTo = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:PivotTo(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPivot = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetBoundingBox = function(self) return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1) end\n    serviceMethods.GetExtentsSize = function(self) return Vector3.new(1, 1, 1) end\n    serviceMethods.TranslateBy = function(self, vec)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:TranslateBy(%s)", modelPath, serializeValue(vec)))\n    end\n    serviceMethods.LoadAnimation = function(self, anim)\n        local animPath = dumperState.registry[proxy] or "animator"\n        local trackProxy = createProxyObject("animTrack", false)\n        local varName = registerVariable(trackProxy, "animTrack")\n        emitOutput(string.format("local %s = %s:LoadAnimation(%s)", varName, animPath, serializeValue(anim)))\n        return trackProxy\n    end\n    serviceMethods.GetPlayingAnimationTracks = function(self) return {} end\n    serviceMethods.AdjustSpeed = function(self, speed)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        emitOutput(string.format("%s:AdjustSpeed(%s)", trackPath, serializeValue(speed)))\n    end\n    serviceMethods.AdjustWeight = function(self, weight, fade)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        if fade then\n            emitOutput(string.format("%s:AdjustWeight(%s, %s)", trackPath, serializeValue(weight), serializeValue(fade)))\n        else\n            emitOutput(string.format("%s:AdjustWeight(%s)", trackPath, serializeValue(weight)))\n        end\n    end\n    serviceMethods.Teleport = function(self, placeId, player, spawn, customTeleportData)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:Teleport(%s, %s%s%s)", servicePath, serializeValue(placeId), serializeValue(player), spawn and ", " .. serializeValue(spawn) or '"', customTeleportData and ", " .. serializeValue(customTeleportData) or '"'))\n    end\n    serviceMethods.TeleportToPlaceInstance = function(self, placeId, instanceId, player)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:TeleportToPlaceInstance(%s, %s, %s)", servicePath, serializeValue(placeId), serializeValue(instanceId), serializeValue(player)))\n    end\n    serviceMethods.PlayLocalSound = function(self, sound)\n        local servicePath = dumperState.registry[proxy] or "SoundService"\n        emitOutput(string.format("%s:PlayLocalSound(%s)", servicePath, serializeValue(sound)))\n    end\n    serviceMethods.IsAvailable = function(self) return true end\n    serviceMethods.HasAchieved = function(self) return false end\n    serviceMethods.GrantAchievement = function(self) return true end\n    serviceMethods.GetDeviceCameraCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetDeviceCameraCFrameForSelfView = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.UpdateDeviceCFrame = function(self) return nil end\n    serviceMethods.GetCorescriptLocalizations = function(self)\n        local loc = createProxyObject("LocalizationTable", false)\n        return {loc}\n    end\n    serviceMethods.GetTranslatorForLocaleAsync = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = formatValue(locale or "en-us")}\n        return translator\n    end\n    serviceMethods.IsVibrationSupported = function(self) return false end\n    serviceMethods.GetCharacterAppearanceInfoAsync = function(self)\n        return {assets = {{id = 1}}, bodyColors = {headColorId = 1}, emotes = {{name = "Wave"}}}\n    end\n    serviceMethods.GetHumanoidDescriptionFromUserId = function(self)\n        local desc = createProxyObject("HumanoidDescription", false)\n        dumperState.property_store[desc] = {ClassName = "HumanoidDescription"}\n        return desc\n    end\n    serviceMethods.GetEmotes = function(self) return {Wave = {{1}}} end\n    serviceMethods.GetGroupsAsync = function(self, userId) return {} end\n    serviceMethods.GetGroupInfoAsync = function(self, groupId)\n        return {Id = toNumberFunction(groupId) or 0, Name = "Group", MemberCount = 0}\n    end\n    serviceMethods.GetMemStats = function(self)\n        return {Animations = 1, Clips = 2, Tracks = 3}\n    end\n    serviceMethods.SetItem = function(self, key, value)\n        _at.mem[formatValue(key)] = formatValue(value)\n    end\n    serviceMethods.GetItem = function(self, key)\n        return _at.mem[formatValue(key)]\n    end\n    serviceMethods.RemoveItem = function(self, key)\n        _at.mem[formatValue(key)] = nil\n    end\n    serviceMethods.AddTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        _at.tags[tagName] = _at.tags[tagName] or {}\n        _at.tags[tagName][target] = true\n        _at.instTags[target] = _at.instTags[target] or {}\n        _at.instTags[target][tagName] = true\n    end\n    serviceMethods.RemoveTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        if _at.tags[tagName] then _at.tags[tagName][target] = nil end\n        if _at.instTags[target] then _at.instTags[target][tagName] = nil end\n    end\n    serviceMethods.HasTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        return _at.instTags[target] and _at.instTags[target][tagName] == true or false\n    end\n    serviceMethods.GetTags = function(self, inst)\n        local target = inst or proxy\n        local result = {}\n        for tagName in pairsFunction(_at.instTags[target] or {}) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetTagged = function(self, tag)\n        local tagName = formatValue(tag)\n        local result = {}\n        if _at.tags[tagName] then\n            for inst in pairsFunction(_at.tags[tagName]) do\n                table.insert(result, inst)\n            end\n        end\n        return result\n    end\n    serviceMethods.GetAllTags = function(self)\n        local result = {}\n        for tagName in pairsFunction(_at.tags) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetInstanceAddedSignal = function(self, tag)\n        local tagName = formatValue(tag)\n        if not _at.sigs[tagName] then\n            local sig = createProxyObject("CollectionSignal", false)\n            dumperState.registry[sig] = "CollectionService:GetInstanceAddedSignal(" .. formatStringLiteral(tagName) .. ")"\n            _at.typeOverride[sig] = "RBXScriptSignal"\n            _at.sigs[tagName] = sig\n        end\n        return _at.sigs[tagName]\n    end\n    serviceMethods.GetInstanceRemovedSignal = function(self, tag)\n        return serviceMethods.GetInstanceAddedSignal(self, "__removed_" .. formatValue(tag))\n    end\n    serviceMethods.CheckForUpdate = function(self) return false end\n    serviceMethods.BindAction = function(self, name, callback, createTouchButton, ...)\n        local actionName = formatValue(name)\n        local inputs = {...}\n        _at.acts[actionName] = {inputTypes = inputs, createTouchButton = createTouchButton == true}\n    end\n    serviceMethods.UnbindAction = function(self, name)\n        _at.acts[formatValue(name)] = nil\n    end\n    serviceMethods.GetAllBoundActionInfo = function(self) return _at.acts end\n    serviceMethods.GetAsync = function(self, url) return "{}" end\n    serviceMethods.PostAsync = function(self, url, data) return "{}" end\n    serviceMethods.JSONEncode = function(self, data)\n        local function encode(v)\n            local tv = typeFunction(v)\n            if tv == "string" then return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end\n            if tv == "number" or tv == "boolean" then return toStringFunction(v) end\n            if tv == "table" then\n                local isArray, maxIndex, count = true, 0, 0\n                for k in pairsFunction(v) do\n                    count = count + 1\n                    if typeFunction(k) ~= "number" then isArray = false else maxIndex = math.max(maxIndex, k) end\n                end\n                local out = {}\n                if isArray and maxIndex == count then\n                    for i = 1, maxIndex do table.insert(out, encode(v[i])) end\n                    return "[" .. table.concat(out, ",") .. "]"\n                end\n                for k, val in pairsFunction(v) do table.insert(out, '"' .. toStringFunction(k) .. '":' .. encode(val)) end\n                return "{" .. table.concat(out, ",") .. "}"\n            end\n            return "null"\n        end\n        local encoded = encode(data)\n        _at.json[encoded] = data\n        return encoded\n    end\n    serviceMethods.JSONDecode = function(self, json)\n        local key = formatValue(json)\n        if _at.json[key] then return _at.json[key] end\n        -- validate basic JSON structure — error on malformed input\n        -- check for unmatched quotes, truncated strings, bad escapes\n        local stripped = key:gsub('"[^"\\]*(?:\\.[^"\\]*)*"', '""')\n        local unmatched = key:match('"[^"]*$') -- unterminated string\n        if unmatched then\n            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)\n        end\n        -- check for common malformed patterns\n        if key:match('"\\"}') or key:match('[^\\]\\[^"\\/bfnrtu]') then
            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)
        end
        if key:match("^%s*%[") then
            local result = {}
            for value in key:gmatch('"?([^,"%[%]%s]+)"?') do\n                local n = toNumberFunction(value)\n                table.insert(result, n or value)\n            end\n            return result\n        end\n        if key:match("^%s*{") then\n            local result = {}\n            for k, v in key:gmatch('"%s*([^"]-)%s*"%s*:%s*"?([^",}]+)"?') do\n                result[k] = toNumberFunction(v) or (v == "true" and true) or (v == "false" and false) or v\n            end\n            return result\n        end\n        return {}\n    end\n    serviceMethods.GetCountryRegionForPlayerAsync = function(self, player)\n        -- must be a real Player instance proxy, not coroutine/userdata/etc\n        if not isProxy(player) then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        local props = dumperState.property_store[player] or {}\n        if props.ClassName ~= "Player" and props.ClassName ~= "LocalPlayer" then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        return "US"\n    end\n    serviceMethods.UrlEncode = function(self, str)\n        -- must succeed — encode any string including non-UTF8 bytes\n        local result = formatValue(str):gsub("[^%w%-_%.!~%*'%(%)]", function(c)\n            return string.format("%%%02X", string.byte(c))\n        end)\n        return result\n    end\n    serviceMethods.GetTextSize = function(self, text, size, font, frameSize)\n        local width = math.max(1, #(formatValue(text or "")) * (toNumberFunction(size) or 14) * 0.5)\n        return Vector2.new(width, toNumberFunction(size) or 14)\n    end\n    serviceMethods.GetGuiInset = function(self)\n        return Vector2.new(0, 36), Vector2.new(0, 0)\n    end\n    serviceMethods.GetRequestQueueSize = function(self) return 0 end\n    serviceMethods.CompressBuffer = function(self, b, algorithm, level)\n        -- read data from the real buffer registry\n        local data = _at.buffers[b] or ""\n        -- return a new proper buffer object registered in _at.buffers\n        local out = {}\n        -- store magic prefix + original data so decompress can recover it\n        _at.buffers[out] = "\x1f\x8b" .. data\n        return out\n    end\n    serviceMethods.DecompressBuffer = function(self, b, algorithm)\n        -- read compressed data and strip the magic prefix to recover original\n        local data = _at.buffers[b] or ""\n        local original = data:sub(3) -- strip 2-byte magic prefix\n        local out = {}\n        _at.buffers[out] = original\n        return out\n    end\n    serviceMethods.GetRealPhysicsFPS = function(self) return 60 end\n    serviceMethods.GetEnumItems = function(self)\n        local enumPath = dumperState.registry[proxy] or ""\n        local enumTypeName = enumPath:match("Enum%.(.+)") or "Unknown"\n        local knownItems = {\n            QualityLevel = {"Automatic","Level01","Level02","Level03","Level04","Level05","Level06","Level07","Level08","Level09","Level10","Level11"},\n            KeyCode       = {"Unknown","Return","Space","E","Q","R","F"},\n            RaycastFilterType = {"Exclude","Include"},\n            HumanoidStateType = {"Running","Jumping","Freefall","Landed","Seated","Dead"},\n            NormalId      = {"Front","Back","Left","Right","Top","Bottom"},\n            PlaybackState = {"Begin","Playing","Paused","Completed","Cancelled"},\n            EasingStyle   = {"Linear","Sine","Back","Bounce","Circular","Cubic","Elastic","Exponential","Quad","Quartic","Quintic"},\n            EasingDirection = {"In","Out","InOut"},\n            ActionType    = {"Nothing","Pause","Lose","Draw","Win"},\n            VelocityConstraintMode = {"Vector","Plane","Line"},\n            Material      = {"Plastic","SmoothPlastic","Neon","Wood","Metal","Glass","Grass","Sand","Fabric"},\n            PartType      = {"Ball","Block","Cylinder"},\n            SurfaceType   = {"Smooth","Glue","Weld","Studs","Inlet","Universal","Hinge","Motor"},\n            CreatorType   = {"User","Group"},\n            MembershipType= {"None","Premium"},\n            CameraType    = {"Custom","Follow","Fixed","Attach","Track","Watch","Scriptable"},\n            ReverbType    = {"NoReverb","GenericReverb","SmallRoom","LargeRoom","Hall"},\n            Font          = {"Legacy","Arial","ArialBold","SourceSans","SourceSansBold","GothamBold","Gotham"},\n            Limb          = {"Head","LeftArm","RightArm","LeftLeg","RightLeg","Torso","Unknown"},\n            ConnectionError = {"OK","Unknown","ConnectErrors","Disconnect","Unauthorized","NotFound","Forbidden","TooManyRequests","ServiceUnavailable","GatewayTimeout"},\n        }\n        local names = knownItems[enumTypeName] or {"Unknown"}\n        local items = {}\n        for _, v in ipairsFunction(names) do\n            local itemKey = "Enum." .. enumTypeName .. "." .. v\n            if not _at.enum[itemKey] then\n                local itemProxy = createProxyObject(itemKey, false)\n                dumperState.registry[itemProxy] = itemKey\n                _at.typeOverride[itemProxy] = "EnumItem"\n                _at.enum[itemKey] = itemProxy\n            end\n            items[#items + 1] = _at.enum[itemKey]\n        end\n        return items\n    end\n    serviceMethods.GenerateGUID = function(self, includeBraces)\n        local t = {}\n        local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"\n        for c in template:gmatch(".") do\n            if c == "x" then t[#t+1] = string.format("%x", math.random(0, 15))\n            elseif c == "y" then t[#t+1] = string.format("%x", math.random(8, 11))\n            else t[#t+1] = c end\n        end\n        local guid = table.concat(t):upper()\n        return includeBraces and ("{" .. guid .. "}") or guid\n    end\n    serviceMethods.HttpGet = function(self, url)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP URL"})\n        dumperState.last_http_url = resolvedUrl\n        return resolvedUrl\n    end\n    serviceMethods.HttpPost = function(self, url, data, contentType)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP POST URL"})\n        local resultProxy = createProxyObject("HttpResponse", false)\n        local varName = registerVariable(resultProxy, "httpResponse")\n        local servicePath = dumperState.registry[proxy] or "HttpService"\n        emitOutput(string.format("local %s = %s:HttpPost(%s, %s, %s)", varName, servicePath, serializeValue(url), serializeValue(data), serializeValue(contentType)))\n        dumperState.property_store[resultProxy] = {Body = "{}", StatusCode = 200, Success = true}\n        return resultProxy\n    end\n    serviceMethods.AddItem = function(self, item, delayTime)\n        local servicePath = dumperState.registry[proxy] or "Debris"\n        emitOutput(string.format("%s:AddItem(%s, %s)", servicePath, serializeValue(item), serializeValue(delayTime or 10)))\n    end\n    -- PlaceId/UniverseId mutation no-ops\n    serviceMethods.SetPlaceId = function() end\n    serviceMethods.SetUniverseId = function() end\n    -- TeleportService\n    serviceMethods.TeleportAsync = function(self, placeId, players, options) end\n    serviceMethods.TeleportPartyAsync = function(self, placeId, players) end\n    serviceMethods.TeleportToPrivateServer = function(self, placeId, reservedServerAccessCode, players) end\n    serviceMethods.ReserveServer = function(self, placeId) return "reserved_"..tostring(placeId), os.time() end\n    serviceMethods.GetLocalPlayerTeleportData = function(self) return nil end\n    serviceMethods.GetArrivingTeleportGui = function(self) return nil end\n    serviceMethods.SetTeleportGui = function(self, gui) end\n    serviceMethods.GetPlayerPlaceInstanceAsync = function(self, userId) return false, "", 0, "" end\n    -- Players extra\n    serviceMethods.GetUserIdFromNameAsync = function(self, name) return 1 end\n    serviceMethods.GetNameFromUserIdAsync = function(self, userId) return "Player" end\n    serviceMethods.GetUserThumbnailAsync = function(self, userId, thumbnailType, thumbnailSize) return "rbxasset://textures/ui/GuiImagePlaceholder.png", true end\n    serviceMethods.GetFriendsAsync = function(self, userId) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    serviceMethods.GetCharacterAppearanceAsync = function(self, userId) return createProxyObject("Model", false) end\n    serviceMethods.ReportAbuse = function(self, player, reason, optionalMessage) end\n    serviceMethods.BanAsync = function(self, config) end\n    serviceMethods.UnbanAsync = function(self, config) end\n    -- Chat\n    serviceMethods.Chat = function(self, partOrCharacter, message, color) end\n    serviceMethods.FilterStringAsync = function(self, stringToFilter, playerFrom, chatContext) return stringToFilter end\n    serviceMethods.FilterStringForBroadcast = function(self, stringToFilter, playerFrom) return stringToFilter end\n    serviceMethods.CanUserChatAsync = function(self, userId) return true end\n    serviceMethods.CanUsersChatAsync = function(self, userIdFrom, userIdTo) return true end\n    -- MarketplaceService\n    serviceMethods.PromptPurchase = function(self, player, assetId) end\n    serviceMethods.PromptProductPurchase = function(self, player, productId, equipIfPurchased, currencyType) end\n    serviceMethods.PromptGamePassPurchase = function(self, player, gamePassId) end\n    serviceMethods.PromptPremiumPurchase = function(self, player) end\n    serviceMethods.UserOwnsGamePassAsync = function(self, userId, gamePassId) return false end\n    serviceMethods.PlayerOwnsAsset = function(self, player, assetId) return false end\n    serviceMethods.GetProductInfo = function(self, assetId, infoType, ...)\n        -- error on extra arguments\n        if select("#", ...) > 0 then\n            errorFunction("GetProductInfo: too many arguments", 2)\n        end\n        -- error on invalid assetId types\n        local idType = typeFunction(assetId)\n        if idType ~= "number" then\n            errorFunction("GetProductInfo: assetId must be a number, got " .. idType, 2)\n        end\n        -- error on invalid numeric IDs (negative, non-integer, out of range)\n        if assetId < 1 or assetId ~= math.floor(assetId) or assetId > 2^53 then\n            errorFunction("GetProductInfo: invalid asset ID " .. tostring(assetId), 2)\n        end\n        return {Name="Product", Description="", PriceInRobux=0, AssetId=assetId, IsForSale=false, IsLimited=false, IsLimitedUnique=false, IsNew=false, IsPublicDomain=false, IsForRent=false, MinimumMembershipLevel=0, ContentRatingTypeId=0, Creator={Id=1, Name="Roblox", CreatorType="User"}}\n    end\n    serviceMethods.GetDeveloperProductsAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- BadgeService\n    serviceMethods.AwardBadge = function(self, userId, badgeId) return true end\n    serviceMethods.HasBadgeAsync = function(self, userId, badgeId) return false end\n    serviceMethods.GetBadgeInfoAsync = function(self, badgeId) return {Name="Badge", Description="", IsEnabled=true, IconImageId=0, AwardedBadgeId=badgeId} end\n    -- DataStoreService extra\n    serviceMethods.GetOrderedDataStore = function(self, name, scope) return createProxyObject("OrderedDataStore", false) end\n    serviceMethods.ListDataStoresAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- ContentProvider\n    serviceMethods.PreloadAsync = function(self, instances, callback) end\n    serviceMethods.GetFailedRequests = function(self) return {} end\n    -- SocialService\n    serviceMethods.CanSendGameInviteAsync = function(self, player) return false end\n    serviceMethods.PromptGameInvite = function(self, player) end\n    serviceMethods.CanSendCallInviteAsync = function(self, player) return false end\n    serviceMethods.PromptPhoneBook = function(self, player, tag) end\n    -- AvatarEditorService\n    serviceMethods.PromptSaveAvatar = function(self, description, humanoidRigType) end\n    serviceMethods.PromptSetFavorite = function(self, itemId, itemType, active) end\n    serviceMethods.GetInventoryAsync = function(self, pageSize, assetTypes) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- VoiceChatService\n    serviceMethods.IsVoiceEnabledForUserIdAsync = function(self, userId) return false end\n    serviceMethods.SetCameraMode = function(self, mode) end\n    -- TextService extra\n    serviceMethods.GetFamilyInfoAsync = function(self, assetId) return {Name="Font", Faces={}} end\n    -- PolicyService\n    serviceMethods.GetPolicyInfoForPlayerAsync = function(self, player)\n        return {IsSubjectToChinaPolicies=false, ArePaidRandomItemsRestricted=false, IsPaidItemTradingAllowed=true, AreAdsAllowed=true, AllowedExternalLinkReferences={}}\n    end\n    -- AnalyticsService\n    serviceMethods.LogCustomEvent = function(self, player, eventName, customData) end\n    serviceMethods.LogEconomyEvent = function(self, player, flow, currencyType, amount, endingPlayerBalance, transactionType, itemSku) end\n    serviceMethods.LogFunnelStepEvent = function(self, player, funnelName, funnelSessionId, step, stepName) end\n    serviceMethods.LogOnboardingFunnelStepEvent = function(self, player, step, stepName) end\n    serviceMethods.LogProgressionCompleteEvent = function(self, player, progressionPathName, progressionName) end\n    serviceMethods.LogProgressionEvent = function(self, player, progressionPathName, progressionName, progressionIndex) end\n    -- Instance general\n    serviceMethods.GetNetworkOwner = function(self) return _at.localPlayer end\n    serviceMethods.SetNetworkOwner = function(self, player) end\n    serviceMethods.SetNetworkOwnershipAuto = function(self) end\n    serviceMethods.CanSetNetworkOwnership = function(self) return true, nil end\n    serviceMethods.GetNetworkOwnershipAuto = function(self) return true end\n    serviceMethods.ApplyDescription = function(self, humanoidDescription) end\n    serviceMethods.GetAppliedDescription = function(self) return createProxyObject("HumanoidDescription", false) end\n    serviceMethods.ReplaceContentIds = function(self, ids, newIds) end\n    serviceMethods.GetConnectedParts = function(self, recursive) return {} end\n    serviceMethods.GetJoints = function(self) return {} end\n    serviceMethods.GetTouchingParts = function(self) return {} end\n    serviceMethods.GetNoCollisionConstraints = function(self) return {} end\n    serviceMethods.SubtractAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.UnionAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.IntersectAsync = function(self, parts, cs, ms) return createProxyObject("IntersectOperation", false) end\n    serviceMethods.SeparateAsync = function(self, parts) return {} end\n    serviceMethods.BreakJoints = function(self) end\n    serviceMethods.MakeJoints = function(self) end\n    serviceMethods.ResetOrientationToIdentity = function(self) end\n    serviceMethods.GetRootPart = function(self) return proxy end\n    serviceMethods.GetModelCFrame = function(self) return CFrame.new(0,0,0) end\n    serviceMethods.GetModelSize = function(self) return Vector3.new(1,1,1) end\n    serviceMethods.FindPartOnRay = function(self, ray, ignore, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithWhitelist = function(self, ray, whitelist, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.ArePartsTouchingOthers = function(self, parts, overlapIgnored) return false end\n    serviceMethods.GetPartsInPart = function(self, part, overlapParams) return {} end\n    -- Humanoid extra\n    serviceMethods.AddAccessory = function(self, accessory) end\n    serviceMethods.RemoveAccessories = function(self) end\n    serviceMethods.GetAccessories = function(self) return {} end\n    serviceMethods.GetLimb = function(self, part) return createProxyObject("Enum.Limb.Unknown", false) end\n    serviceMethods.GetBodyPartR15 = function(self, part) return nil end\n    serviceMethods.ReplaceBodyPartR15 = function(self, bodyPart, part) return false end\n    serviceMethods.BuildRigFromAttachments = function(self) end\n    -- Sound extra\n    serviceMethods.Resume = function(self) end\n    -- Gui\n    serviceMethods.TweenPosition = function(self, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSize = function(self, endSize, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSizeAndPosition = function(self, endSize, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    -- ContextActionService extra\n    serviceMethods.GetButton = function(self, actionName) return nil end\n    serviceMethods.LocalToolEquipped = function(self, toolEquipped) end\n    serviceMethods.LocalToolUnequipped = function(self, toolUnequipped) end\n    -- PathfindingService extra\n    serviceMethods.FindPathAsync = function(self, start, finish) return createProxyObject("Path", false) end\n    serviceMethods.ComputeAsync = function(self, start, finish) end\n    serviceMethods.GetWaypoints = function(self) return {} end\n    serviceMethods.CheckOcclusionAsync = function(self, start) return {} end\n    -- Camera extra\n    serviceMethods.ScreenPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.ViewportPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.WorldToScreenPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.WorldToViewportPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.GetPartsObscuringTarget = function(self, castPoints, ignoreList) return {} end\n    serviceMethods.Interpolate = function(self, endPos, endFocus, duration) end\n    -- UserInputService extra\n    serviceMethods.GetMouseLocation = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetMouseDelta = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetKeysPressed = function(self) return {} end\n    serviceMethods.GetMouseButtonsPressed = function(self) return {} end\n    serviceMethods.GetGamepadState = function(self, gamepadNum) return {} end\n    serviceMethods.GetSupportedGamepadKeyCodes = function(self, gamepadNum) return {} end\n    serviceMethods.GetConnectedGamepads = function(self) return {} end\n    serviceMethods.GetLastInputType = function(self) return createProxyObject("Enum.UserInputType.None", false) end\n    serviceMethods.GetFocusedTextBox = function(self) return nil end\n    serviceMethods.IsGamepadButtonDown = function(self, gamepadNum, keyCode) return false end\n    serviceMethods.IsKeyDown = function(self, keyCode) return false end\n    serviceMethods.IsMouseButtonPressed = function(self, mouseButton) return false end\n    serviceMethods.RecenterUserHeadCFrame = function(self) end\n    serviceMethods.GetDeviceRotation = function(self) return createProxyObject("InputObject", false), CFrame.new(0,0,0) end\n    serviceMethods.GetDeviceGravity = function(self) return createProxyObject("InputObject", false) end\n    -- PhysicsService\n    serviceMethods.CreateCollisionGroup = function(self, name) return 0 end\n    serviceMethods.RemoveCollisionGroup = function(self, name) end\n    serviceMethods.CollisionGroupSetCollidable = function(self, name1, name2, collidable) end\n    serviceMethods.CollisionGroupsAreCollidable = function(self, name1, name2) return true end\n    serviceMethods.GetCollisionGroupId = function(self, name) return 0 end\n    serviceMethods.GetCollisionGroupName = function(self, id) return "Default" end\n    serviceMethods.SetPartCollisionGroup = function(self, part, name) end\n    serviceMethods.GetMaxCollisionGroups = function(self) return 32 end\n    serviceMethods.GetRegisteredCollisionGroups = function(self) return {} end\n    -- StarterGui extra\n    serviceMethods.GetCoreGuiEnabled = function(self, coreGuiType) return true end\n    serviceMethods.RegisterGetCore = function(self, parameterName, getFunction) end\n    serviceMethods.RegisterSetCore = function(self, parameterName, setFunction) end\n    -- Lighting extra\n    serviceMethods.GetAtmosphere = function(self) return nil end\n    serviceMethods.GetSky = function(self) return nil end\n    -- Workspace extra\n    serviceMethods.GetServerTimeNow = function(self) return os.time() end\n    serviceMethods.PGSIsEnabled = function(self) return true end\n    serviceMethods.SetInsertPoint = function(self, point) end\n    -- NetworkClient/NetworkServer\n    serviceMethods.GetClientTicket = function(self) return "" end\n    -- ScriptContext\n    serviceMethods.AddCoreScriptLocal = function(self, name, parent) end\n    serviceMethods.GetCoreScriptVersion = function(self) return "1.0.0" end\n    meta.__namecall = function(self, ...) return nil end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        -- fast path: string key, check property_store and common properties before formatValue\n        if typeFunction(key) == "string" then\n            local ps = dumperState.property_store[proxy]\n            if ps then\n                local v = ps[key]\n                if v ~= nil then return v end\n            end\n            if key == "PlaceId" or key == "placeId" then return numericArg end\n            if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n            if key == "Parent" then return dumperState.parent_map[proxy] end\n            if key == "Name" then\n                if _at.typeOverride[proxy] == "EnumItem" then\n                    return (formattedName or ""):match("%.([^%.]+)$") or formattedName or "Object"\n                end\n                return formattedName or "Object"\n            end\n            if key == "ClassName" then return formattedName or "Instance" end\n            if not _at.metaHooks["__index"] then\n                local sm = serviceMethods[key]\n                if sm ~= nil then\n                    if typeFunction(sm) == "function" then\n                        local previousMethod\n                        return function(_, ...)\n                            previousMethod = _at.currentNamecallMethod\n                            _at.currentNamecallMethod = key\n                            local results = {sm(proxy, ...)}\n                            _at.currentNamecallMethod = previousMethod\n                            return table.unpack(results)\n                        end\n                    end\n                    return sm\n                end\n            end\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local propertyName = formatValue(key)\n        if _at.metaHooks["__index"] and not _at.inMetaHook then\n            _at.inMetaHook = true\n            local ok, result = pcallFunction(_at.metaHooks["__index"], proxy, key)\n            _at.inMetaHook = false\n            if ok and result ~= nil then return result end\n        end\n        if key == "PlaceId" or key == "placeId" then return numericArg end\n        if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n        if key == "Parent" then return dumperState.parent_map[proxy] end\n        -- DistributedGameTime ticking (must be before property_store read)\n        if key == "DistributedGameTime" then\n            if not _at._dgtClock then\n                -- initialize ticking from current stored value on first access\n                local props = dumperState.property_store[proxy]\n                _at._dgtBase = (props and props[key]) or 1\n                _at._dgtClock = osLibrary.clock()\n            end\n            return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n        end\n        -- AT6: SurfaceAppearance ContentId properties\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName\n        if className == "SurfaceAppearance" and (key == "ColorMap" or key == "NormalMap" or key == "RoughnessMap" or key == "MetalnessMap") then\n            return _makeContentId("")\n        end\n        if dumperState.property_store[proxy] and dumperState.property_store[proxy][key] ~= nil then\n            return dumperState.property_store[proxy][key]\n        end\n        if serviceMethods[propertyName] then\n            return function(_, ...)\n                if _at.metaHooks["__namecall"] and not _at.inMetaHook then\n                    local previousMethod = _at.currentNamecallMethod\n                    _at.currentNamecallMethod = propertyName\n                    _at.inMetaHook = true\n                    local ok, result = pcallFunction(_at.metaHooks["__namecall"], proxy, ...)\n                    _at.inMetaHook = false\n                    _at.currentNamecallMethod = previousMethod\n                    if ok and result ~= nil then return result end\n                end\n                local previousMethod = _at.currentNamecallMethod\n                _at.currentNamecallMethod = propertyName\n                local results = {serviceMethods[propertyName](proxy, ...)}\n                _at.currentNamecallMethod = previousMethod\n                return table.unpack(results)\n            end\n        end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        if pathName == "fenv" or pathName == "getgenv" or pathName == "_G" then\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            if _G[key] ~= nil then return _G[key] end\n            return nil\n        end\n        if key == "Name" then return formattedName or "Object" end\n        if key == "ClassName" then return formattedName or "Instance" end\n        if key == "Players" then return serviceMethods.GetService(game, "Players") end\n        if key == "Workspace" then return workspace end\n        if key == "LocalPlayer" then\n            if _at.localPlayer then return _at.localPlayer end\n            local lpProxy = createProxyObject("LocalPlayer", false, proxy)\n            dumperState.property_store[lpProxy] = {Name = "Player", ClassName = "Player", UserId = 1}\n            _at.localPlayer = lpProxy\n            local varName = registerVariable(lpProxy, "LocalPlayer")\n            emitOutput(string.format("local %s = %s.LocalPlayer", varName, pathName))\n            return lpProxy\n        end\n        if key == "PlayerGui" then return createProxyObject("PlayerGui", false, proxy) end\n        if key == "Backpack" then return createProxyObject("Backpack", false, proxy) end\n        if key == "PlayerScripts" then return createProxyObject("PlayerScripts", false, proxy) end\n        if key == "UserId" then return 1 end\n        if key == "DisplayName" then return "Player" end\n        if key == "AccountAge" then return 1000 end\n        if key == "LocaleId" then return "en-us" end\n        if key == "RobloxLocaleId" or key == "SystemLocaleId" then return "en-us" end\n        if key == "CharacterMaxSlopeAngle" then return 89 end\n        if key == "DistanceFactor" then return 3.33 end\n        if key == "CaptureBegan" then\n            local sigProxy = createProxyObject(pathName .. ".CaptureBegan", false, proxy)\n            dumperState.registry[sigProxy] = pathName .. ".CaptureBegan"\n            _at.typeOverride[sigProxy] = "RBXScriptSignal"\n            return sigProxy\n        end\n        if key == "Connected" and _at.connState[proxy] ~= nil then return _at.connState[proxy] end\n        if key == "Team" then return createProxyObject("Team", false, proxy) end\n        if key == "TeamColor" then return BrickColor.new("White") end\n        if key == "Character" then\n            local charProxy = createProxyObject("Character", false, proxy)\n            dumperState.property_store[charProxy] = {Name = "Character", ClassName = "Model"}\n            -- AT3: seed Animate LocalScript as child of character\n            if not _at.animateScript then\n                local animProxy = createProxyObject("Animate", false, charProxy)\n                dumperState.registry[animProxy] = "Animate"\n                dumperState.property_store[animProxy] = {Name = "Animate", ClassName = "LocalScript", Parent = charProxy}\n                _setParent(animProxy, charProxy)\n                _at.animateScript = animProxy\n            end\n            return charProxy\n        end\n        if key == "Humanoid" then\n            local humProxy = createProxyObject("Humanoid", false, proxy)\n            dumperState.property_store[humProxy] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}\n            return humProxy\n        end\n        if key == "HumanoidRootPart" or key == "PrimaryPart" or key == "RootPart" then\n            local rootProxy = createProxyObject("HumanoidRootPart", false, proxy)\n            dumperState.property_store[rootProxy] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}\n            return rootProxy\n        end\n        local limbNames = {"Head", "Torso", "UpperTorso", "LowerTorso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "RightHand", "LeftHand", "RightFoot", "LeftFoot"}\n        for _, limb in ipairsFunction(limbNames) do\n            if key == limb then return createProxyObject(key, false, proxy) end\n        end\n        if key == "Animator" then return createProxyObject("Animator", false, proxy) end\n        if key == "CurrentCamera" or key == "Camera" then\n            local camProxy = createProxyObject("Camera", false, proxy)\n            dumperState.property_store[camProxy] = {CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080)}\n            return camProxy\n        end\n        if key == "Terrain" then\n            if not _at.terrainProxy then\n                local tp = createProxyObject("Terrain", false, proxy)\n                dumperState.property_store[tp] = {ClassName="Terrain",Name="Terrain",Parent=proxy,WaterWaveSpeed=100,WaterWaveSize=0.5}\n                _at.terrainProxy = tp\n            end\n            return _at.terrainProxy\n        end\n        if key == "CameraType" then return Enum.CameraType.Custom end\n        if key == "CameraSubject" then return createProxyObject("Humanoid", false, proxy) end\n        if key == "DistributedGameTime" then\n            if _at._dgtBase and _at._dgtClock then\n                return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n            end\n        end\n        local constants = {\n            Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2,\n            Transparency = 0, Mass = 1, Value = 0, TimePosition = 0, TimeLength = 1, Volume = 0.5,\n            PlaybackSpeed = 1, Brightness = 1, Range = 60, Angle = 90, FieldOfView = 70, Thickness = 1,\n            ZIndex = 1, LayoutOrder = 0, Gravity = 196.2, DistributedGameTime = 1, ClockTime = 14,\n            FogEnd = 100000, RolloffScale = 1, MaxPlayers = 12, RespawnTime = 5, PlaceVersion = 1,\n            CreatorId = 0, FollowUserId = 0, NearPlaneZ = -0.1\n        }\n        if constants[key] ~= nil then return constants[key] end\n        if key == "Size" and not (formattedName and formattedName:match("Part")) then return UDim2.new(1, 0, 1, 0) end\n        local boolConstants = {Visible = true, Enabled = true, Anchored = false, CanCollide = true, Locked = false, Active = true, Draggable = false, Modal = false, Playing = false, Looped = false, IsPlaying = false, AutoPlay = false, Archivable = true, ClipsDescendants = false, RichText = false, TextWrapped = false, TextScaled = false, PlatformStand = false, AutoRotate = true, Sit = false}\n        boolConstants.StreamingEnabled = false\n        boolConstants.HttpEnabled = false\n        boolConstants.Sandboxed = false\n        if boolConstants[key] ~= nil then return boolConstants[key] end\n        if key == "JobId" then return "00000000-0000-4000-8000-000000000001" end\n        if key == "CreatorType" then return Enum.CreatorType.User end\n        if key == "MembershipType" then return Enum.MembershipType.None end\n        if key == "AmbientReverb" then return Enum.ReverbType.NoReverb end\n        if key == "Ambient" or key == "OutdoorAmbient" then return Color3.fromRGB(128, 128, 128) end\n        if key == "UniqueId" then return _getDebugId(proxy) end\n        if key == "AbsoluteSize" or key == "ViewportSize" then return Vector2.new(1920, 1080) end\n        if key == "AbsolutePosition" then return Vector2.new(0, 0) end\n        if key == "Position" then\n            if formattedName and (formattedName:match("Part") or formattedName:match("Model") or formattedName:match("Character") or formattedName:match("Root")) then return Vector3.new(0, 5, 0) end\n            return UDim2.new(0, 0, 0, 0)\n        end\n        if key == "Size" then\n            if formattedName and formattedName:match("Part") then return Vector3.new(4, 1, 2) end\n            return UDim2.new(1, 0, 1, 0)\n        end\n        if key == "CFrame" then return CFrame.new(0, 5, 0) end\n        if key == "Velocity" or key == "AssemblyLinearVelocity" then\n            -- AT4: if a LinearVelocity constraint is attached to this part, reflect its VectorVelocity\n            for _, child in ipairsFunction(_at.children[proxy] or {}) do\n                local cprops = dumperState.property_store[child]\n                if cprops and cprops.ClassName == "LinearVelocity" then\n                    local vv = cprops.VectorVelocity\n                    if vv and typeof(vv) == "Vector3" then return vv end\n                end\n            end\n            return Vector3.new(0, 0, 0)\n        end\n        if key == "RotVelocity" or key == "AssemblyAngularVelocity" then\n            local imp = dumperState.property_store[proxy] and dumperState.property_store[proxy]["_angularImpulse"]\n            if imp and _at.vectors[imp] then\n                local d = _at.vectors[imp]\n                return _makeVector3(d.x, d.y, d.z)\n            end\n            return _makeVector3(0, 0, 0)\n        end\n        if key == "Orientation" or key == "Rotation" then return Vector3.new(0, 0, 0) end\n        if key == "LookVector" then return Vector3.new(0, 0, -1) end\n        if key == "RightVector" then return Vector3.new(1, 0, 0) end\n        if key == "UpVector" then return Vector3.new(0, 1, 0) end\n        if key == "Color" or key == "Color3" or key == "BackgroundColor3" or key == "BorderColor3" or key == "TextColor3" or key == "PlaceholderColor3" or key == "ImageColor3" then return Color3.new(1, 1, 1) end\n        if key == "BrickColor" then return BrickColor.new("Medium stone grey") end\n        if key == "Material" then return createProxyObject("Enum.Material.Plastic", false) end\n        if key == "Hit" then return CFrame.new(0, 0, -10) end\n        if key == "Origin" then return CFrame.new(0, 5, 0) end\n        if key == "Target" then return createProxyObject("Target", false, proxy) end\n        if key == "X" or key == "Y" then return 0 end\n        if key == "UnitRay" then return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1)) end\n        if key == "ViewSizeX" then return 1920 end\n        if key == "ViewSizeY" then return 1080 end\n        if key == "Text" or key == "PlaceholderText" or key == "ContentText" or key == "Value" then\n            if inputKey then return inputKey end\n            if key == "Value" then return "input" end\n            return '"'
        end
        if key == "TextBounds" then return Vector2.new(0, 0) end
        if key == "Font" then return createProxyObject("Enum.Font.SourceSans", false) end
        if key == "TextSize" then return 14 end
        if key == "Image" or key == "ImageContent" then return '"' end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        local signalNames = {"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Touched", "TouchEnded", "InputBegan", "InputEnded", "InputChanged", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward", "Activated", "Deactivated", "FocusLost", "FocusGained", "Focused", "Heartbeat", "RenderStepped", "Stepped", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded", "PlayerRemoving", "AncestryChanged", "AttributeChanged", "Died", "FreeFalling", "GettingUp", "Jumping", "Running", "Seated", "Swimming", "StateChanged", "HealthChanged", "MoveToFinished", "OnClientEvent", "OnServerEvent", "OnClientInvoke", "OnServerInvoke", "Completed", "DidLoop", "Stopped", "CaptureBegan", "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Idle", "Move", "TextChanged", "ReturnPressedFromOnScreenKeyboard", "Triggered", "TriggerEnded", "Error", "Event", "AxisChanged", "JumpRequest", "DevTouchMovementModeChanged", "DevComputerMovementModeChanged", "GraphicsQualityChangeRequest", "MenuOpened", "MenuClosed", "PointerAction", "TouchStarted", "TouchMoved", "TouchEnded", "TouchTap", "TouchLongPress", "TouchPinch", "TouchRotate", "TouchSwipe", "GamepadConnected", "GamepadDisconnected", "WindowFocused", "WindowFocusReleased"}\n        for _, sig in ipairsFunction(signalNames) do\n            if key == sig then\n                local sigProxy = createProxyObject(pathName .. "." .. key, false, nil)\n                dumperState.registry[sigProxy] = pathName .. "." .. key\n                _at.typeOverride[sigProxy] = "RBXScriptSignal"\n                _at.signalOwner = _at.signalOwner or {}\n                _at.signalOwner[sigProxy] = proxy  -- track owner without triggering _setParent\n                return sigProxy\n            end\n        end\n        return createProxyMethod(propertyName, proxy)\n    end\n    meta.__newindex = function(tbl, key, val)\n        if key == proxyList or key == "__proxy_id" then\n            rawset(tbl, key, val)\n            return\n        end\n        -- locked: never allow mutation regardless of method\n        local _lockedProps = {PlaceId=true, placeId=true, GameId=true, gameId=true, UniverseId=true}\n        if _lockedProps[key] then return end\n        -- read-only properties: error like real Roblox does\n        local _readOnlyProps = {\n            PlaybackLoudness = true,\n            AbsolutePosition = true,\n            AbsoluteSize = true,\n            AbsoluteRotation = true,\n            TextBounds = true,\n            ContentText = true,\n            SimulationRadius = true,\n            MaxSimulationRadius = true,\n            RootPriority = true,\n            NativeIndex = true,\n            ReceiveAge = true,\n            AssemblyAngularVelocity = true,\n            AssemblyLinearVelocity = true,\n            AssemblyMass = true,\n            AssemblyRootPart = true,\n            CurrentCamera = true,\n            PrivateServerOwnerId = true,\n            PrivateServerId = true,\n            JobId = true,\n            PlaceId = true,\n            GameId = true,\n            PlaceVersion = true,\n            UserId = true,\n            FloorMaterial = true,\n            MoveDirection = true,\n            SeatPart = true,\n        }\n        if _readOnlyProps[key] then\n            errorFunction(toStringFunction(key) .. " is not a valid member of " .. (dumperState.registry[proxy] or formattedName or "Instance"), 2)\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local prop = formatValue(key)\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy][key] = val\n        local _cls2 = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if key == "CameraMinZoomDistance" then\n            local n = tonumber(val) or 0; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif key == "CameraMaxZoomDistance" then\n            local n = tonumber(val) or 400; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif _cls2 == "Terrain" and key == "WaterWaveSpeed" then\n            local n = tonumber(val) or 100; if n > 100 then n = 100 end; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        end\n        if key == "Parent" then\n            _setParent(proxy, isProxy(val) and val or nil)\n        end\n        local className = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if className == "WeldConstraint" or className == "Weld" or className == "Motor6D" then\n            if key == "Part0" or key == "Part1" then\n                _at.weldRegistry[proxy] = _at.weldRegistry[proxy] or {}\n                _at.weldRegistry[proxy][key] = val\n                local wr = _at.weldRegistry[proxy]\n                if wr.Part0 and wr.Part1 then\n                    local cf0 = (dumperState.property_store[wr.Part0] or {}).CFrame\n                    local cf1 = (dumperState.property_store[wr.Part1] or {}).CFrame\n                    if cf0 and cf1 then\n                        wr.offset = {X = (cf1.X or 0) - (cf0.X or 0), Y = (cf1.Y or 0) - (cf0.Y or 0), Z = (cf1.Z or 0) - (cf0.Z or 0)}\n                    end\n                end\n            end\n        end\n        if key == "CFrame" then\n            local cfVal = val\n            local cfX = (cfVal and cfVal.X) or 0\n            local cfY = (cfVal and cfVal.Y) or 0\n            local cfZ = (cfVal and cfVal.Z) or 0\n            for _, wr in pairs(_at.weldRegistry) do\n                if wr.Part0 == proxy and wr.Part1 and wr.offset then\n                    local nx = cfX + wr.offset.X\n                    local ny = cfY + wr.offset.Y\n                    local nz = cfZ + wr.offset.Z\n                    local newCF\n                    if type(CFrame) == "table" and type(CFrame.new) == "function" then\n                        newCF = CFrame.new(nx, ny, nz)\n                    elseif _makeCFrame then\n                        newCF = _makeCFrame(nx, ny, nz)\n                    else\n                        newCF = {X = nx, Y = ny, Z = nz, Position = {X = nx, Y = ny, Z = nz}}\n                    end\n                    dumperState.property_store[wr.Part1] = dumperState.property_store[wr.Part1] or {}\n                    dumperState.property_store[wr.Part1].CFrame = newCF\n                    local posV = newCF.Position\n                    dumperState.property_store[wr.Part1].Position = posV\n                end\n            end\n        end\n        emitOutput(string.format("%s.%s = %s", pathName, prop, serializeValue(val)))\n    end\n    meta.__call = function(tbl, ...)\n        local pathName = dumperState.registry[proxy] or formattedName or "func"\n        if pathName == "fenv" or pathName == "getgenv" or pathName:match("env") then\n            return proxy\n        end\n        if pathName == "game" then\n            errorFunction("attempt to call an Instance value", 0)\n        end\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("result", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s(%s)", varName, pathName, table.concat(serializedArgs, ", ")))\n        return resultProxy\n    end\n    local function operatorMeta(opSymbol)\n        local function metaCall(a, b)\n            local proxy, meta = createProxy()\n            local strA = "0"\n            if a ~= nil then strA = dumperState.registry[a] or serializeValue(a) end\n            local strB = "0"\n            if b ~= nil then strB = dumperState.registry[b] or serializeValue(b) end\n            local expression = "(" .. strA .. " " .. opSymbol .. " " .. strB .. ")"\n            dumperState.registry[proxy] = expression\n            meta.__tostring = function() return expression end\n            meta.__call = function() return proxy end\n            meta.__index = function(_, k)\n                if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                return createProxyObject(expression .. "." .. formatValue(k), false)\n            end\n            meta.__add = operatorMeta("+")\n            meta.__sub = operatorMeta("-")\n            meta.__mul = operatorMeta("*")\n            meta.__div = operatorMeta("/")\n            meta.__mod = operatorMeta("%")\n            meta.__pow = operatorMeta("^")\n            meta.__concat = operatorMeta("..")\n            meta.__eq = function() return false end\n            meta.__lt = function() return false end\n            meta.__le = function() return false end\n            return proxy\n        end\n        return metaCall\n    end\n    meta.__add = operatorMeta("+")\n    meta.__sub = operatorMeta("-")\n    meta.__mul = operatorMeta("*")\n    meta.__div = operatorMeta("/")\n    meta.__mod = operatorMeta("%")\n    meta.__pow = operatorMeta("^")\n    meta.__concat = operatorMeta("..")\n    meta.__eq = function(a, b) return rawequal(a, b) end\n    meta.__lt = function() return false end\n    meta.__le = function() return false end\n    meta.__unm = function(a)\n        local proxy, meta = createProxy()\n        dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n        meta.__tostring = function() return dumperState.registry[proxy] end\n        return proxy\n    end\n    meta.__len = function() return 0 end\n    meta.__tostring = function() return dumperState.registry[proxy] or formattedName or "Object" end\n    meta.__pairs = function() return function() return nil end, proxy, nil end\n    meta.__ipairs = meta.__pairs\n    return proxy\nend\nlocal function createTypeDa(typeName, methods)\n    local dc = {}\n    local dd = {}\n    dd.__index = function(_, key)\n        if key == "new" or methods and methods[key] then\n            return function(...)\n                local args = {...}\n                local serializedArgs = {}\n                for _, val in ipairsFunction(args) do\n                    table.insert(serializedArgs, serializeValue(val))\n                end\n                local expression = typeName .. "." .. key .. "(" .. table.concat(serializedArgs, ", ") .. ")"\n                local proxy, meta = createProxy()\n                dumperState.registry[proxy] = expression\n                meta.__tostring = function() return expression end\n                meta.__index = function(_, k)\n                    if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                    if k == "X" or k == "Y" or k == "Z" or k == "W" then return 0 end\n                    if k == "Magnitude" then return 0 end\n                    if k == "Unit" or k == "Position" or k == "CFrame" or k == "LookVector" or k == "RightVector" or k == "UpVector" or k == "Rotation" or k == "p" then return proxy end\n                    if k == "R" or k == "G" or k == "B" then return 1 end\n                    if k == "Width" or k == "Height" then return UDim.new(0, 0) end\n                    if k == "Min" or k == "Max" or k == "Scale" or k == "Offset" then return 0 end\n                    return createProxyObject(expression .. "." .. formatValue(k), false)\n                end\n                local function opMeta(symbol)\n                    return function(a, b)\n                        local proxy, meta = createProxy()\n                        local expr = "(" .. (dumperState.registry[a] or serializeValue(a)) .. " " .. symbol .. " " .. (dumperState.registry[b] or serializeValue(b)) .. ")"\n                        dumperState.registry[proxy] = expr\n                        meta.__tostring = function() return expr end\n                        meta.__index = meta.__index\n                        meta.__add = opMeta("+")\n                        meta.__sub = opMeta("-")\n                        meta.__mul = opMeta("*")\n                        meta.__div = opMeta("/")\n                        return proxy\n                    end\n                end\n                meta.__add = opMeta("+")\n                meta.__sub = opMeta("-")\n                meta.__mul = opMeta("*")\n                meta.__div = opMeta("/")\n                meta.__unm = function(a)\n                    local proxy, meta = createProxy()\n                    dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n                    meta.__tostring = function() return dumperState.registry[proxy] end\n                    return proxy\n                end\n                meta.__eq = function() return false end\n                meta.__typeof = typeName\n                return proxy\n            end\n        end\n        return nil\n    end\n    dd.__call = function(_, ...) return _.new(...) end\n    return setmetatable(dc, dd)\nend\nVector3 = createTypeDa("Vector3", {new = true, zero = true, one = true})\nVector2 = createTypeDa("Vector2", {new = true, zero = true, one = true})\nUDim = createTypeDa("UDim", {new = true})\nUDim2 = createTypeDa("UDim2", {new = true, fromScale = true, fromOffset = true})\nCFrame = createTypeDa("CFrame", {new = true, Angles = true, lookAt = true, fromEulerAnglesXYZ = true, fromEulerAnglesYXZ = true, fromAxisAngle = true, fromMatrix = true, fromOrientation = true, identity = true})\nColor3 = createTypeDa("Color3", {new = true, fromRGB = true, fromHSV = true, fromHex = true})\nBrickColor = createTypeDa("BrickColor", {new = true, random = true, White = true, Black = true, Red = true, Blue = true, Green = true, Yellow = true, palette = true})\nTweenInfo = createTypeDa("TweenInfo", {new = true})\nRect = createTypeDa("Rect", {new = true})\nRegion3 = createTypeDa("Region3", {new = true})\nRegion3int16 = createTypeDa("Region3int16", {new = true})\nRay = createTypeDa("Ray", {new = true})\nNumberRange = createTypeDa("NumberRange", {new = true})\nNumberSequence = createTypeDa("NumberSequence", {new = true})\nNumberSequenceKeypoint = createTypeDa("NumberSequenceKeypoint", {new = true})\nColorSequence = createTypeDa("ColorSequence", {new = true})\nColorSequence.new = function(...)\n    local args = {...}\n    local keypoints = {}\n    if #args == 1 and typeFunction(args[1]) == "table" and args[1][1] ~= nil then\n        keypoints = args[1]\n    elseif #args == 1 then\n        keypoints = {args[1], args[1]}\n    elseif #args >= 2 then\n        keypoints = args\n    end\n    local t = setmetatable({Keypoints = keypoints}, {\n        __typeof = "ColorSequence",\n        __tostring = function() return "ColorSequence" end,\n    })\n    return t\nend\nColorSequenceKeypoint = createTypeDa("ColorSequenceKeypoint", {new = true})\nPhysicalProperties = createTypeDa("PhysicalProperties", {new = true})\nFont = createTypeDa("Font", {new = true, fromEnum = true, fromName = true, fromId = true})\nRaycastParams = createTypeDa("RaycastParams", {new = true})\nOverlapParams = {new = function()\n        local params = {MaxParts = 0, FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}}\n        return setmetatable(params, {__typeof = "OverlapParams"})\n    end}\n_makeVector3 = function(x, y, z, expr)\n    x, y, z = toNumberFunction(x) or 0, toNumberFunction(y) or 0, toNumberFunction(z) or 0\n    local proxy, meta = createProxy()\n    local expression = expr or ("Vector3.new(" .. serializeValue(x) .. ", " .. serializeValue(y) .. ", " .. serializeValue(z) .. ")")\n    dumperState.registry[proxy] = expression\n    _at.vectors[proxy] = {x = x, y = y, z = z}\n    local function component(v, axis)\n        local data = _at.vectors[v]\n        if not data then return 0 end\n        return axis == "X" and data.x or axis == "Y" and data.y or data.z\n    end\n    local function binary(a, b, symbol)\n        local ax, ay, az = component(a, "X"), component(a, "Y"), component(a, "Z")\n        local bx, by, bz\n        if typeFunction(b) == "number" then bx, by, bz = b, b, b else bx, by, bz = component(b, "X"), component(b, "Y"), component(b, "Z") end\n        if symbol == "+" then return _makeVector3(ax + bx, ay + by, az + bz, "(" .. serializeValue(a) .. " + " .. serializeValue(b) .. ")") end\n        if symbol == "-" then return _makeVector3(ax - bx, ay - by, az - bz, "(" .. serializeValue(a) .. " - " .. serializeValue(b) .. ")") end\n        if symbol == "*" then return _makeVector3(ax * bx, ay * by, az * bz, "(" .. serializeValue(a) .. " * " .. serializeValue(b) .. ")") end\n        return _makeVector3(bx ~= 0 and ax / bx or 0, by ~= 0 and ay / by or 0, bz ~= 0 and az / bz or 0, "(" .. serializeValue(a) .. " / " .. serializeValue(b) .. ")")\n    end\n    meta.__index = function(_, key)\n        if key == proxyList or key == "__proxy_id" then return rawget(proxy, key) end\n        if key == "X" then return x end\n        if key == "Y" then return y end\n        if key == "Z" then return z end\n        if key == "Magnitude" then return math.sqrt(x * x + y * y + z * z) end\n        if key == "Unit" then\n            local mag = math.sqrt(x * x + y * y + z * z)\n            if mag == 0 then return _makeVector3(0, 0, 0, expression .. ".Unit") end\n            return _makeVector3(x / mag, y / mag, z / mag, expression .. ".Unit")\n        end\n        if key == "Dot" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return x * ox + y * oy + z * oz\n            end\n        end\n        if key == "Cross" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return _makeVector3(y*oz - z*oy, z*ox - x*oz, x*oy - y*ox)\n            end\n        end\n        if key == "Lerp" then\n            return function(self, other, alpha)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                local a = toNumberFunction(alpha) or 0\n                return _makeVector3(x + (ox-x)*a, y + (oy-y)*a, z + (oz-z)*a)\n            end\n        end\n        if key == "FuzzyEq" then\n            return function(self, other, epsilon)\n                local eps = toNumberFunction(epsilon) or 1e-5\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return math.abs(x-ox) <= eps and math.abs(y-oy) <= eps and math.abs(z-oz) <= eps\n            end\n        end\n        return 0\n    end\n    meta.__add = function(a, b) return binary(a, b, "+") end\n    meta.__sub = function(a, b) return binary(a, b, "-") end\n    meta.__mul = function(a, b) return binary(a, b, "*") end\n    meta.__div = function(a, b) return binary(a, b, "/") end\n    meta.__unm = function(a) return _makeVector3(-component(a, "X"), -component(a, "Y"), -component(a, "Z"), "(-" .. serializeValue(a) .. ")") end\n    meta.__eq = function(a, b) return component(a, "X") == component(b, "X") and component(a, "Y") == component(b, "Y") and component(a, "Z") == component(b, "Z") end\n    meta.__tostring = function() return toStringFunction(x) .. ", " .. toStringFunction(y) .. ", " .. toStringFunction(z) end\n    return proxy\nend\nVector3 = {\n    new = function(x, y, z) return _makeVector3(x, y, z) end,\n    zero = _makeVector3(0, 0, 0, "Vector3.zero"),\n    one = _makeVector3(1, 1, 1, "Vector3.one"),\n    fromNormalId = function(normalId)\n        local name = toStringFunction(normalId)\n        if name:find("Right")  then return _makeVector3( 1,  0,  0) end\n        if name:find("Left")   then return _makeVector3(-1,  0,  0) end\n        if name:find("Top")    then return _makeVector3( 0,  1,  0) end\n        if name:find("Bottom") then return _makeVector3( 0, -1,  0) end\n        if name:find("Back")   then return _makeVector3( 0,  0,  1) end\n        if name:find("Front")  then return _makeVector3( 0,  0, -1) end\n        return _makeVector3(0, 0, 0)\n    end,\n    fromAxis = function(axis)\n        local name = toStringFunction(axis)\n        if name:find("X") then return _makeVector3(1, 0, 0) end\n        if name:find("Y") then return _makeVector3(0, 1, 0) end\n        if name:find("Z") then return _makeVector3(0, 0, 1) end\n        return _makeVector3(0, 0, 0)\n    end,\n}\nsetmetatable(Vector3, {__call = function(_, x, y, z) return _.new(x, y, z) end})\nlocal function _valueType(typeName, fields, methods)\n    local obj = fields or {}\n    return setmetatable(obj, {\n        __typeof = typeName,\n        __index = methods or {},\n        __tostring = function() return typeName end,\n        __eq = function(a, b)\n            if typeFunction(a) ~= "table" or typeFunction(b) ~= "table" then return false end\n            local ma, mb = getMetatableFunction(a), getMetatableFunction(b)\n            if not ma or not mb or ma.__typeof ~= mb.__typeof then return false end\n            for k, v in pairsFunction(a) do\n                if b[k] ~= v then return false end\n            end\n            for k, v in pairsFunction(b) do\n                if a[k] ~= v then return false end\n            end\n            return true\n        end\n    })\nend\nlocal function _num(v, default) return toNumberFunction(v) or default or 0 end\nlocal function _makeVector2(x, y)\n    x, y = _num(x), _num(y)\n    local methods = {}\n    function methods:Dot(other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) end\n    local mt\n    mt = {\n        __typeof = "Vector2",\n        __index = function(self, key)\n            if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end\n            if key == "Unit" then\n                local mag = math.sqrt(self.X * self.X + self.Y * self.Y)\n                return mag == 0 and _makeVector2(0, 0) or _makeVector2(self.X / mag, self.Y / mag)\n            end\n            return methods[key]\n        end,\n        __add = function(a, b) return _makeVector2(a.X + b.X, a.Y + b.Y) end,\n        __sub = function(a, b) return _makeVector2(a.X - b.X, a.Y - b.Y) end,\n        __mul = function(a, b)\n            if typeFunction(a) == "number" then return _makeVector2(a * b.X, a * b.Y) end\n            if typeFunction(b) == "number" then return _makeVector2(a.X * b, a.Y * b) end\n            return _makeVector2(a.X * b.X, a.Y * b.Y)\n        end,\n        __div = function(a, b)\n            if typeFunction(b) == "number" then return _makeVector2(a.X / b, a.Y / b) end\n            return _makeVector2(a.X / b.X, a.Y / b.Y)\n        end,\n        __unm = function(a) return _makeVector2(-a.X, -a.Y) end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y end,\n        __tostring = function(a) return ("Vector2.new(%s, %s)"):format(a.X, a.Y) end,\n    }\n    return setmetatable({X = x, Y = y}, mt)\nend\nVector2 = {new = function(x, y) return _makeVector2(x, y) end}\nVector2.zero = Vector2.new(0, 0)\nVector2.one = Vector2.new(1, 1)\nsetmetatable(Vector2, {__call = function(_, x, y) return _.new(x, y) end})\nlocal _oldVector3New = Vector3.new\nVector3.new = function(x, y, z)\n    local v = _oldVector3New(x, y, z)\n    local mt = getMetatableFunction(v)\n    local oldIndex = mt.__index\n    mt.__index = function(self, key)\n        if key == "Dot" then\n            return function(_, other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) + self.Z * (other and other.Z or 0) end\n        end\n        if key == "Cross" then\n            return function(_, other)\n                return Vector3.new(\n                    self.Y * (other and other.Z or 0) - self.Z * (other and other.Y or 0),\n                    self.Z * (other and other.X or 0) - self.X * (other and other.Z or 0),\n                    self.X * (other and other.Y or 0) - self.Y * (other and other.X or 0)\n                )\n            end\n        end\n        return oldIndex(self, key)\n    end\n    return v\nend\nVector3.zero = Vector3.new(0, 0, 0)\nVector3.one = Vector3.new(1, 1, 1)\nUDim = {new = function(scale, offset) return _valueType("UDim", {Scale = _num(scale), Offset = _num(offset)}) end}\nsetmetatable(UDim, {__call = function(_, scale, offset) return _.new(scale, offset) end})\nUDim2 = {\n    new = function(xs, xo, ys, yo) return _valueType("UDim2", {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)}) end,\n    fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,\n    fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,\n}\nsetmetatable(UDim2, {__call = function(_, ...) return _.new(...) end})\nColor3 = {\n    new = function(r, g, b)\n        local rv, gv, bv = _num(r), _num(g), _num(b)\n        if rv < 0 or rv > 1 or gv < 0 or gv > 1 or bv < 0 or bv > 1 then\n            errorFunction("R, G, and B must each be in the range [0, 1]", 2)\n        end\n        return setmetatable({R = rv, G = gv, B = bv}, {\n            __typeof = "Color3",\n            __tostring = function(self) return string.format("[R:%g, G:%g, B:%g]", self.R, self.G, self.B) end,\n            __eq = function(a, b) return typeFunction(b) == "table" and a.R == b.R and a.G == b.G and a.B == b.B end,\n        })\n    end,\n    fromRGB = function(r, g, b) return Color3.new(_num(r) / 255, _num(g) / 255, _num(b) / 255) end,\n    fromHSV = function(h, s, v) return Color3.new(v or 1, v or 1, v or 1) end,\n    fromHex = function(hex) return Color3.fromRGB(255, 255, 255) end,\n}\nsetmetatable(Color3, {__call = function(_, ...) return _.new(...) end})\nBrickColor = {\n    new = function(name)\n        name = formatValue(name or "Medium stone grey")\n        return _valueType("BrickColor", {Name = name, Number = 1, Color = Color3.fromRGB(255, 0, 0)})\n    end,\n    random = function() return BrickColor.new("Medium stone grey") end,\n}\nsetmetatable(BrickColor, {__call = function(_, ...) return _.new(...) end})\nNumberRange = {new = function(min, max) return _valueType("NumberRange", {Min = _num(min), Max = max ~= nil and _num(max) or _num(min)}) end}\nNumberSequence = {new = function(value) return _valueType("NumberSequence", {Keypoints = typeFunction(value) == "table" and value or {{Time = 0, Value = _num(value)}, {Time = 1, Value = _num(value)}}}) end}\nTweenInfo = {new = function(timeValue, style, direction, repeatCount, reverses, delayTime) return _valueType("TweenInfo", {Time = _num(timeValue), EasingStyle = style or Enum.EasingStyle.Quad, EasingDirection = direction or Enum.EasingDirection.Out, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0}) end}\nRay = {new = function(origin, direction) return _valueType("Ray", {Origin = origin or Vector3.zero, Direction = direction or Vector3.new(0, 0, -1)}) end}\nRect = {new = function(a, b, c, d)\n    local minV = typeFunction(a) == "table" and a or Vector2.new(a, b)\n    local maxV = typeFunction(c) == "table" and c or Vector2.new(c, d)\n    return _valueType("Rect", {Min = minV, Max = maxV, Width = maxV.X - minV.X, Height = maxV.Y - minV.Y})\nend}\nRegion3 = {new = function(minVec, maxVec)\n    local mn = minVec or Vector3.new(0,0,0)\n    local mx = maxVec or Vector3.new(0,0,0)\n    local sz = Vector3.new(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)\n    return _valueType("Region3", {CFrame = CFrame.new((mn.X+mx.X)/2,(mn.Y+mx.Y)/2,(mn.Z+mx.Z)/2), Size = sz})\nend}\nPhysicalProperties = {new = function(density, friction, elasticity, frictionWeight, elasticityWeight) return _valueType("PhysicalProperties", {Density = _num(density, 1), Friction = _num(friction, 0.3), Elasticity = _num(elasticity, 0.5), FrictionWeight = _num(frictionWeight, 1), ElasticityWeight = _num(elasticityWeight, 1)}) end}\n_makeCFrame = function(x, y, z)\n    local ox, oy, oz = _num(x), _num(y), _num(z)\n    local obj = {X = ox, Y = oy, Z = oz}\n    obj.Position = Vector3.new(ox, oy, oz)\n    obj.p = obj.Position\n    obj.LookVector = Vector3.new(0, 0, -1)\n    obj.RightVector = Vector3.new(1, 0, 0)\n    obj.UpVector = Vector3.new(0, 1, 0)\n    obj.Inverse = function(self) return _makeCFrame(-ox, -oy, -oz) end\n    obj.ToObjectSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox2 - ox, oy2 - oy, oz2 - oz)\n    end\n    obj.ToWorldSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox + ox2, oy + oy2, oz + oz2)\n    end\n    obj.PointToObjectSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) - ox,\n            (point and point.Y or 0) - oy,\n            (point and point.Z or 0) - oz\n        )\n    end\n    obj.PointToWorldSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) + ox,\n            (point and point.Y or 0) + oy,\n            (point and point.Z or 0) + oz\n        )\n    end\n    return setmetatable(obj, {\n        __typeof = "CFrame",\n        __index = function(self, key) return rawget(self, key) end,\n        __mul = function(a, b)\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "CFrame" then\n                return _makeCFrame(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "Vector3" then\n                return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            return a\n        end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y and a.Z == b.Z end,\n        __tostring = function(a) return ("CFrame.new(%s, %s, %s)"):format(a.X, a.Y, a.Z) end,\n    })\nend\nCFrame = {\n    new = function(x, y, z) return _makeCFrame(x, y, z) end,\n    Angles = function() return _makeCFrame(0, 0, 0) end,\n    lookAt = function(origin, target) return _makeCFrame(origin and origin.X or 0, origin and origin.Y or 0, origin and origin.Z or 0) end,\n    LookAt = function(origin, target) return CFrame.lookAt(origin, target) end,\n    fromEulerAnglesXYZ = function() return _makeCFrame(0, 0, 0) end,\n    fromEulerAnglesYXZ = function() return _makeCFrame(0, 0, 0) end,\n    fromAxisAngle = function() return _makeCFrame(0, 0, 0) end,\n    fromMatrix = function(pos) return _makeCFrame(pos and pos.X or 0, pos and pos.Y or 0, pos and pos.Z or 0) end,\n    fromOrientation = function() return _makeCFrame(0, 0, 0) end,\n}\nCFrame.identity = CFrame.new(0, 0, 0)\nsetmetatable(CFrame, {__call = function(_, ...) return _.new(...) end})\nPathWaypoint = createTypeDa("PathWaypoint", {new = true})\nAxes = createTypeDa("Axes", {new = true})\nFaces = createTypeDa("Faces", {new = true})\nVector3int16 = createTypeDa("Vector3int16", {new = true})\nVector2int16 = createTypeDa("Vector2int16", {new = true})\nCatalogSearchParams = createTypeDa("CatalogSearchParams", {new = true})\nDateTime = {\n    now = function()\n        return DateTime.fromUnixTimestamp(os.time())\n    end,\n    fromUnixTimestamp = function(ts)\n        ts = toNumberFunction(ts) or 0\n        local dt = setmetatable({UnixTimestamp = ts, UnixTimestampMillis = ts * 1000}, {\n            __typeof = "DateTime",\n            __index = function(self, key)\n                if key == "UnixTimestamp" then return ts end\n                if key == "UnixTimestampMillis" then return ts * 1000 end\n                if key == "FormatUniversalTime" then\n                    return function(self2, fmt, locale)\n                        -- convert unix timestamp to date components\n                        local t = os.date("!*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "FormatLocalTime" then\n                    return function(self2, fmt, locale)\n                        local t = os.date("*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "ToIsoDate" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", t.year, t.month, t.day, t.hour, t.min, t.sec)\n                    end\n                end\n                if key == "ToUniversalTime" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return {Year=t.year,Month=t.month,Day=t.day,Hour=t.hour,Minute=t.min,Second=t.sec,Millisecond=0}\n                    end\n                end\n            end,\n        })\n        return dt\n    end,\n    fromUnixTimestampMillis = function(ms)\n        return DateTime.fromUnixTimestamp(math.floor((toNumberFunction(ms) or 0) / 1000))\n    end,\n    fromIsoDate = function(iso)\n        return DateTime.fromUnixTimestamp(0)\n    end,\n}\nRandom = {new = function(seed)\n        local obj = {}\n        function obj:NextNumber(min, max) return (min or 0) + 0.5 * ((max or 1) - (min or 0)) end\n        function obj:NextInteger(min, max) return math.floor((min or 1) + 0.5 * ((max or 100) - (min or 1))) end\n        function obj:NextUnitVector() return Vector3.new(0.577, 0.577, 0.577) end\n        function obj:Shuffle(tab) return tab end\n        function obj:Clone() return Random.new() end\n        return obj\n    end}\nsetmetatable(Random, {__call = function(_, seed) return _.new(seed) end})\nEnum = createProxyObject("Enum", true)\nlocal enumMeta = debugLibrary.getmetatable(Enum)\nenumMeta.__index = function(_, key)\n    if key == proxyList or key == "__proxy_id" then return rawget(_, key) end\n    local enumName = "Enum." .. formatValue(key)\n    if not _at.enum[enumName] then\n        local enumProxy = createProxyObject(enumName, false)\n        dumperState.registry[enumProxy] = enumName\n        _at.enum[enumName] = enumProxy\n    end\n    return _at.enum[enumName]\nend\nInstance = {new = function(className, parent)\n        local name = formatValue(className)\n        local _validClasses = {\n            Part=1,MeshPart=1,UnionOperation=1,SpecialMesh=1,BlockMesh=1,CylinderMesh=1,\n            Model=1,Folder=1,Tool=1,LocalScript=1,Script=1,ModuleScript=1,\n            RemoteEvent=1,RemoteFunction=1,BindableEvent=1,BindableFunction=1,\n            Frame=1,ScreenGui=1,SurfaceGui=1,BillboardGui=1,TextLabel=1,TextButton=1,\n            TextBox=1,ImageLabel=1,ImageButton=1,ScrollingFrame=1,ViewportFrame=1,\n            UIListLayout=1,UIGridLayout=1,UITableLayout=1,UIPadding=1,UICorner=1,\n            UIStroke=1,UIScale=1,UIAspectRatioConstraint=1,UISizeConstraint=1,\n            UITextSizeConstraint=1,UIFlexItem=1,UIGradient=1,UIPageLayout=1,\n            Humanoid=1,HumanoidDescription=1,Animator=1,Animation=1,\n            Sound=1,SoundGroup=1,Attachment=1,Motor6D=1,Weld=1,WeldConstraint=1,\n            BallSocketConstraint=1,HingeConstraint=1,SpringConstraint=1,RodConstraint=1,\n            RopeConstraint=1,AlignPosition=1,AlignOrientation=1,\n            ForceField=1,Decal=1,Texture=1,SelectionBox=1,SelectionSphere=1,\n            PointLight=1,SpotLight=1,SurfaceLight=1,Sky=1,Atmosphere=1,Clouds=1,\n            Beam=1,Trail=1,ParticleEmitter=1,Fire=1,Smoke=1,Sparkles=1,\n            Camera=1,Backpack=1,Hat=1,Accessory=1,Shirt=1,Pants=1,ShirtGraphic=1,\n            CharacterMesh=1,BodyColors=1,\n            IntValue=1,StringValue=1,BoolValue=1,NumberValue=1,Vector3Value=1,\n            CFrameValue=1,Color3Value=1,ObjectValue=1,RayValue=1,BrickColorValue=1,\n            ClickDetector=1,ProximityPrompt=1,Dialog=1,DialogChoice=1,\n            SpawnLocation=1,SeatPart=1,VehicleSeat=1,\n            WedgePart=1,CornerWedgePart=1,TrussPart=1,\n            IntersectOperation=1,NegateOperation=1,\n            PathfindingLink=1,PathfindingModifier=1,\n            Configuration=1,LocalizationTable=1,\n            NoCollisionConstraint=1,RigidConstraint=1,\n            EditableMesh=1,EditableImage=1,\n            LinearVelocity=1,AngularVelocity=1,LineForce=1,VectorForce=1,Torque=1,\n            SurfaceAppearance=1,SpecialMesh=1,SelectionBox=1,\n        }\n        if not _validClasses[name] then\n            errorFunction("Unable to create an Instance of type \"" .. name .. "\"", 2)\n        end\n        local proxy = createProxyObject(name, false)\n        local varName = registerVariable(proxy, name)\n        -- class-specific default properties\n        local _classDefaults = {\n            SkateboardController = {Steer=0, Throttle=0},\n            BallSocketConstraint = {LimitsEnabled=false, UpperAngle=45, TwistLimitsEnabled=false, TwistLowerAngle=-45, TwistUpperAngle=45, MaxFrictionTorque=0, Restitution=0},\n            HingeConstraint     = {LimitsEnabled=false, UpperAngle=45, LowerAngle=-45, AngularVelocity=0, MotorMaxTorque=0, Restitution=0},\n            SpringConstraint    = {Coilcount=5, Damping=1, FreeLength=5, LimitsEnabled=false, MaxLength=5, MinLength=0, Stiffness=100, Visible=false},\n            RodConstraint       = {Length=5, LimitAngle0=0, LimitAngle1=0},\n            RopeConstraint      = {Length=5},\n            PrismaticConstraint = {LimitsEnabled=false, UpperLimit=5, LowerLimit=0, Velocity=0},\n            TorsionSpringConstraint = {Damping=1, Stiffness=100, Restitution=0},\n            WeldConstraint      = {},\n            Motor6D             = {CurrentAngle=0, DesiredAngle=0, MaxVelocity=0},\n            ForceField          = {Visible=true},\n            Sound               = {Volume=0.5, PlaybackSpeed=1, TimePosition=0, IsPlaying=false, IsPaused=false, Looped=false, RollOffMaxDistance=10000, RollOffMinDistance=10},\n            ScreenGui           = {Enabled=true, DisplayOrder=0, IgnoreGuiInset=false, ResetOnSpawn=true},\n            Frame               = {BackgroundTransparency=0, BorderSizePixel=1, Visible=true, ZIndex=1, LayoutOrder=0},\n            TextLabel           = {Text="", TextTransparency=0, TextSize=14, TextWrapped=false, RichText=false, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            TextButton          = {Text="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, Modal=false},\n            TextBox             = {Text="", PlaceholderText="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, ClearTextOnFocus=true},\n            ImageLabel          = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            ImageButton         = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            Part                = {Anchored=false, CanCollide=true, Locked=false, Transparency=0, Reflectance=0, Mass=1},\n            MeshPart            = {Anchored=false, CanCollide=true, Transparency=0},\n            Humanoid            = {Health=100, MaxHealth=100, WalkSpeed=16, JumpPower=50, JumpHeight=7.2, HipHeight=2, AutoRotate=true, PlatformStand=false},\n            RemoteEvent         = {},\n            RemoteFunction      = {},\n            BindableEvent       = {},\n            BindableFunction    = {},\n            Animator            = {},\n            LocalizationTable   = {SourceLocaleId="en-us"},\n            Animation           = {AnimationId=""},\n            Attachment          = {},\n            AlignPosition       = {RigidityEnabled=false, MaxForce=1e6, MaxVelocity=1e6, Responsiveness=200},\n            AlignOrientation    = {RigidityEnabled=false, MaxTorque=1e6, MaxAngularVelocity=1e6, Responsiveness=200},\n            LinearVelocity      = {MaxForce=0, VectorVelocity=nil, VelocityConstraintMode=nil, Attachment0=nil},\n            SurfaceAppearance   = {ColorMap=nil, NormalMap=nil, RoughnessMap=nil, MetalnessMap=nil},\n        }\n        local defaults = _classDefaults[name] or {}\n        defaults.ClassName = name\n        defaults.Name = name\n        defaults.Archivable = true\n        dumperState.property_store[proxy] = defaults\n        if parent then\n            local parentPath = dumperState.registry[parent] or serializeValue(parent)\n            emitOutput(string.format("local %s = Instance.new(%s, %s)", varName, formatStringLiteral(name), parentPath))\n            _setParent(proxy, parent)\n        else\n            emitOutput(string.format("local %s = Instance.new(%s)", varName, formatStringLiteral(name)))\n        end\n        return proxy\n    end}\ngame = createProxyObject("game", true)\nworkspace = createProxyObject("workspace", true)\nscript = createProxyObject("script", true)\ndumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}\nlocal function seedCoreRobloxInstances()\n    dumperState.property_store[game] = {\n        Name = "Game", ClassName = "DataModel", JobId = "00000000-0000-4000-8000-000000000001",\n        PlaceId = numericArg, GameId = numericArg + 864197532, placeId = numericArg, gameId = numericArg + 864197532,\n        PlaceVersion = 1, CreatorId = 0, CreatorType = Enum.CreatorType.User\n    }\n    dumperState.property_store[workspace] = {\n        Name = "Workspace", ClassName = "Workspace", Parent = game, Gravity = 196.2, DistributedGameTime = 1,\n        StreamingEnabled = false\n    }\n    _setParent(workspace, game)\n    _at.svcCache.Workspace = workspace\n\n    local players = _at.svcCache.Players or createProxyObject("Players", false, game)\n    _at.svcCache.Players = players\n    dumperState.registry[players] = "Players"\n    dumperState.property_store[players] = {Name = "Players", ClassName = "Players", Parent = game, MaxPlayers = 12, RespawnTime = 5}\n    _setParent(players, game)\n\n    local lp = _at.localPlayer or createProxyObject("LocalPlayer", false, players)\n    _at.localPlayer = lp\n    dumperState.registry[lp] = "LocalPlayer"\n    dumperState.property_store[lp] = {\n        Name = "Player", ClassName = "Player", Parent = players, UserId = 1, DisplayName = "Player",\n        MembershipType = Enum.MembershipType.None, FollowUserId = 0, AccountAge = 1000,\n        CameraMinZoomDistance = 0, CameraMaxZoomDistance = 400,\n        AutoJumpEnabled = true, Neutral = true, Team = nil, LocaleId = "en-us",\n        SimulationRadius = 0, MaxSimulationRadius = 0,\n    }\n    _setParent(lp, players)\n\n    local function ensureChild(parent, name, className, props)\n        local child = createProxyObject(name, false, parent)\n        dumperState.registry[child] = name\n        props = props or {}\n        props.Name = props.Name or name\n        props.ClassName = props.ClassName or className or name\n        props.Parent = parent\n        dumperState.property_store[child] = props\n        _setParent(child, parent)\n        if serviceNames[props.ClassName] then\n            _at.svcCache[props.ClassName] = child\n        end\n        return child\n    end\n\n    ensureChild(lp, "PlayerGui", "PlayerGui")\n    ensureChild(lp, "Backpack", "Backpack")\n    local playerScripts = ensureChild(lp, "PlayerScripts", "PlayerScripts")\n    ensureChild(playerScripts, "PlayerModule", "ModuleScript")\n    ensureChild(playerScripts, "RbxCharacterSounds", "LocalScript")\n    ensureChild(workspace, "Camera", "Camera", {\n        CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080),\n        CameraType = Enum.CameraType.Custom, NearPlaneZ = -0.1\n    })\n    ensureChild(game, "ReplicatedStorage", "ReplicatedStorage")\n    ensureChild(game, "Lighting", "Lighting", {ClockTime = 14, FogEnd = 100000, Ambient = Color3.fromRGB(128, 128, 128), OutdoorAmbient = Color3.fromRGB(128, 128, 128)})\n    ensureChild(game, "SoundService", "SoundService", {RolloffScale = 1, AmbientReverb = Enum.ReverbType.NoReverb})\n    ensureChild(game, "RunService", "RunService")\n    ensureChild(game, "TweenService", "TweenService")\n    ensureChild(game, "HttpService", "HttpService", {HttpEnabled = false})\n    local networkClient = ensureChild(game, "NetworkClient", "NetworkClient")\n    ensureChild(networkClient, "ClientReplicator", "ClientReplicator")\n    local ugc = ensureChild(game, "Ugc", "Folder")\n    ensureChild(ugc, "Chat", "Chat")\n    ensureChild(game, "CollectionService", "CollectionService")\n    ensureChild(game, "TextService", "TextService")\n    ensureChild(game, "GuiService", "GuiService")\n    ensureChild(game, "ContentProvider", "ContentProvider")\nend\nseedCoreRobloxInstances()\ntask = {\n    wait = function(sec)\n        if sec then emitOutput(string.format("task.wait(%s)", serializeValue(sec))) else emitOutput("task.wait()") end\n        -- inside a spawn body, throw to break while-true loops after one iteration\n        if _at.spawnDepth and _at.spawnDepth > 0 then\n            errorFunction("__spawn_yield__", 0)\n        end\n        -- resume any deferred Heartbeat coroutines now that conn locals are assigned\n        if _at.pendingHeartbeat and #_at.pendingHeartbeat > 0 then\n            local pending = _at.pendingHeartbeat\n            _at.pendingHeartbeat = {}\n            for _, co in ipairs(pending) do\n                pcall(coroutine.resume, co)\n            end\n        end\n        for inst, props in pairsFunction(dumperState.property_store) do\n            if props.ClassName == "Part" and props.Anchored == false and _at.vectors[props.Position] then\n                local v = _at.vectors[props.Position]\n                props.Position = Vector3.new(v.x, v.y - 1, v.z)\n            end\n        end\n        return sec or 0.03, osLibrary.clock()\n    end,\n    spawn = function(func, ...)\n        local args = {...}\n        emitOutput("task.spawn(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        elseif typeFunction(func) == "thread" then\n            xpcallFunction( function() coroutine.resume(func, table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        local co = coroutine.create(function() end)\n        _at.threadLike[co] = true\n        local wrapper = setmetatable({}, {\n            __call = function() return true end,\n            __tostring = function() return "thread: 0x0" end,\n        })\n        _at.threadLike[wrapper] = true\n        return wrapper\n    end,\n    delay = function(sec, func, ...)\n        local args = {...}\n        emitOutput(string.format("task.delay(%s, function()", serializeValue(sec or 0)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    defer = function(func, ...)\n        local args = {...}\n        emitOutput("task.defer(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    cancel = function(thread) emitOutput("task.cancel(thread)") end,\n    synchronize = function() emitOutput("task.synchronize()") end,\n    desynchronize = function() emitOutput("task.desynchronize()") end\n}\nwait = function(sec)\n    if sec then emitOutput(string.format("wait(%s)", serializeValue(sec))) else emitOutput("wait()") end\n    task.wait(sec)\n    return sec or 0.03, osLibrary.clock()\nend\ndelay = function(sec, func)\n    emitOutput(string.format("delay(%s, function()", serializeValue(sec or 0)))\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then xpcallFunction(func, function() end) end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\nspawn = function(func)\n    emitOutput("spawn(function()")\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then\n        -- limit spawn bodies: run once then break out of any while true\n        local _spawnDepth = (_at.spawnDepth or 0) + 1\n        if _spawnDepth <= 2 then\n            _at.spawnDepth = _spawnDepth\n            xpcallFunction(func, function() end)\n            _at.spawnDepth = _spawnDepth - 1\n        end\n    end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\ntick = function() return osLibrary.time() end\ntime = function() return osLibrary.clock() end\nelapsedTime = function() return osLibrary.clock() end\nlocal globalEnv = {}\nlocal dummy = 999999999\nlocal function getDummy(key, val) return val end\nlocal function setupEnv()\n    local env = {}\n    setmetatable(env, {\n        __call = function(self, ...) return self end,\n        __index = function(self, key)\n            if _G[key] ~= nil then return getDummy(key, _G[key]) end\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            return nil\n        end,\n        __newindex = function(self, key, val)\n            _G[key] = val\n            globalEnv[key] = 0\n            emitOutput(string.format("_G.%s = %s", formatValue(key), serializeValue(val)))\n        end\n    })\n    return env\nend\n_G.G = setupEnv()\n_G.g = setupEnv()\n_G.ENV = setupEnv()\n_G.env = setupEnv()\n_G.E = setupEnv()\n_G.e = setupEnv()\n_G.L = setupEnv()\n_G.l = setupEnv()\n_G.F = setupEnv()\n_G.f = setupEnv()\nlocal function createGetGenv(path)\n    local proxy = {}\n    local meta = {}\n    local restricted = {"hookfunction", "hookmetamethod", "newcclosure", "replaceclosure", "checkcaller", "iscclosure", "islclosure", "getrawmetatable", "setreadonly", "make_writeable", "getrenv", "getgc", "getinstances"}\n    local function formatPath(d, k)\n        local prop = formatValue(k)\n        if prop:match("^[%a_][%w_]*$") then\n            if d then return d .. "." .. prop end\n            return prop\n        else\n            local escaped = prop:gsub("'", "\\\'")\n            if d then return d .. "['" .. escaped .. "']" end\n            return "['" .. escaped .. "']"\n        end\n    end\n    meta.__index = function(_, key)\n        if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n        return _G[key]\n    end\n    meta.__newindex = function(_, key, val)\n        local fullPath = formatPath(path, key)\n        emitOutput(string.format("getgenv().%s = %s", fullPath, serializeValue(val)))\n    end\n    meta.__call = function() return proxy end\n    meta.__pairs = function() return function() return nil end, nil, nil end\n    return setmetatable(proxy, meta)\nend\nlocal exploitFuncs = {\n    getgenv = function() return createGetGenv(nil) end,\n    getrenv = function() return _G end,\n    getsenv = function() return {} end,\n    getfenv = function(depth)\n        -- always return the same proxy table so getfenv(0)==getfenv(1)\n        if not _at.fenvCache then\n            _at.fenvCache = setmetatable({}, {\n                __index = function(_, key)\n                    if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n                    return _G[key]\n                end,\n                __newindex = function(_, k, v) rawset(_, k, v) end\n            })\n        end\n        return _at.fenvCache\n    end,\n    setfenv = function(func, env)\n        if typeFunction(func) ~= "function" then return end\n        local i = 1\n        while true do\n            local name = debugLibrary.getupvalue(func, i)\n            if name == "_ENV" then debugLibrary.setupvalue(func, i, env) break\n            elseif not name then break end\n            i = i + 1\n        end\n        return func\n    end,\n    hookfunction = function(f, h) return f end,\n    hookmetamethod = function(x, method, hook)\n        local methodName = formatValue(method)\n        if typeFunction(hook) == "function" then\n            _at.metaHooks[methodName] = hook\n        end\n        if methodName == "__index" then\n            return function(obj, key)\n                local mt = isProxy(obj) and debugLibrary.getmetatable(obj)\n                if mt and typeFunction(mt.__index) == "function" then\n                    local saved = _at.metaHooks[methodName]\n                    _at.metaHooks[methodName] = nil\n                    local ok, result = pcallFunction(mt.__index, obj, key)\n                    _at.metaHooks[methodName] = saved\n                    if ok then return result end\n                end\n                return nil\n            end\n        end\n        if methodName == "__namecall" then\n            return function(obj, ...)\n                local methodToCall = _at.currentNamecallMethod\n                if methodToCall and obj then\n                    local member = obj[methodToCall]\n                    if typeFunction(member) == "function" then\n                        local saved = _at.metaHooks[methodName]\n                        _at.metaHooks[methodName] = nil\n                        local ok, result = pcallFunction(member, obj, ...)\n                        _at.metaHooks[methodName] = saved\n                        if ok then return result end\n                    end\n                end\n                return nil\n            end\n        end\n        return function() end\n    end,\n    getrawmetatable = function(x)\n        if isProxy(x) then\n            -- all Instance proxies share ONE metatable so rawequal(mt1,mt2)==true\n            if not _at.sharedInstanceMeta then\n                local mt = {}\n                -- __index must be a C function so debug.getinfo says what=="C"\n                -- use a newproxy userdata with a C-backed metatable trick:\n                -- we tag a wrapper as cclosure so getinfo returns "C"\n                local indexFn = function() end\n                if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n                _at.cclosureSet[indexFn] = true\n                mt.__index = indexFn\n                mt.__newindex = function() end\n                mt.__namecall = function() end\n                mt.__len = function() return 0 end\n                mt.__tostring = function() return "Instance" end\n                _at.sharedInstanceMeta = mt\n            end\n            return _at.sharedInstanceMeta\n        end\n        return getmetatable(x) or {}\n    end,\n    setrawmetatable = function(x, mt) return x end,\n    getnamecallmethod = function() return _at.currentNamecallMethod or "__namecall" end,\n    setnamecallmethod = function(m) _at.currentNamecallMethod = formatValue(m) end,\n    checkcaller = function() return true end,\n    islclosure = function(f)\n        if isProxy(f) then return false end\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return false end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return false end\n        return false\n    end,\n    iscclosure = function(f)\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return true end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return true end\n        return false\n    end,\n    newcclosure = function(f)\n        if typeFunction(f) ~= "function" then return f end\n        if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n        local wrapper = function(...) return f(...) end\n        _at.cclosureSet[wrapper] = true\n        return wrapper\n    end,\n    clonefunction = function(f) return f end,\n    request = function(req)\n        emitOutput(string.format("request(%s)", serializeValue(req)))\n        table.insert(dumperState.string_refs, {value = req.Url or req.url or "unknown", hint = "HTTP Request"})\n        return {Success = true, StatusCode = 200, StatusMessage = "OK", Headers = {}, Body = "{}"}\n    end,\n    http_request = function(req) return exploitFuncs.request(req) end,\n    syn = {request = function(req) return exploitFuncs.request(req) end},\n    http = {request = function(req) return exploitFuncs.request(req) end},\n    HttpPost = function(url, data)\n        emitOutput(string.format("HttpPost(%s, %s)", formatValue(url), formatValue(data)))\n        return "{}"\n    end,\n    setclipboard = function(data) emitOutput(string.format("setclipboard(%s)", serializeValue(data))) end,\n    getclipboard = function() return '"' end,
    identifyexecutor = function() return "Kolenvlogger", "1.0" end,
    getexecutorname = function() return "Kolenvlogger" end,
    gethui = function()
        local hui = createProxyObject("HiddenUI", false)
        registerVariable(hui, "HiddenUI")
        emitOutput(string.format("local %s = gethui()", dumperState.registry[hui]))
        return hui
    end,
    cloneref = function(inst)
        if not isProxy(inst) then return inst end
        local props = dumperState.property_store[inst] or {}
        local className = props.ClassName or dumperState.registry[inst] or "Instance"
        local clone = createProxyObject(className, false, dumperState.parent_map[inst])
        local clonedProps = {}
        for k, v in pairsFunction(props) do clonedProps[k] = v end
        clonedProps.ClassName = clonedProps.ClassName or className
        clonedProps.Name = clonedProps.Name or props.Name or className
        dumperState.property_store[clone] = clonedProps
        dumperState.registry[clone] = (dumperState.registry[inst] or className) .. "_cloneref"
        _at.refBase[clone] = _at.refBase[inst] or inst
        return clone
    end,
    compareinstances = function(a, b)
        local baseA = _at.refBase[a] or a
        local baseB = _at.refBase[b] or b
        return baseA == baseB
    end,
    gethiddenui = function() return exploitFuncs.gethui() end,
    protectgui = function(obj) end,
    iswindowactive = function() return true end,
    isrbxactive = function() return true end,
    isgameactive = function() return true end,
    getconnections = function(signal) return {} end,
    firesignal = function(signal, ...) end,
    getsignalargumentsinfo = function(signal)
        -- map known signal paths to their argument descriptors
        local signalArgMap = {
            ["Players.PlayerAdded"]          = {{Name="player", Type="Player"}},
            ["Players.PlayerRemoving"]       = {{Name="player", Type="Player"}},
            ["Players.PlayerMembershipChanged"] = {{Name="player", Type="Player"}},
            ["Humanoid.Died"]                = {},
            ["Humanoid.HealthChanged"]       = {{Name="health", Type="number"}},
            ["Humanoid.StateChanged"]        = {{Name="old", Type="EnumItem"}, {Name="new", Type="EnumItem"}},
            ["BasePart.Touched"]             = {{Name="otherPart", Type="BasePart"}},
            ["BasePart.TouchEnded"]          = {{Name="otherPart", Type="BasePart"}},
            ["RunService.Heartbeat"]         = {{Name="deltaTime", Type="number"}},
            ["RunService.RenderStepped"]     = {{Name="deltaTime", Type="number"}},
            ["RunService.Stepped"]           = {{Name="time", Type="number"}, {Name="deltaTime", Type="number"}},
            ["UserInputService.InputBegan"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputEnded"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputChanged"]= {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["RemoteEvent.OnClientEvent"]    = {{Name="args", Type="Tuple"}},
            ["BindableEvent.Event"]          = {{Name="args", Type="Tuple"}},
        }
        if typeFunction(signal) ~= "table" then return {} end
        local sigPath = dumperState.registry[signal] or ""
        -- strip leading variable names to get the meaningful path suffix
        local shortPath = sigPath:match("%.(.+)$") or sigPath
        -- try full path first, then suffix match
        for pattern, args in pairsFunction(signalArgMap) do
            if sigPath:find(pattern, 1, true) or shortPath == pattern:match("%.(.+)$") then
                return args
            end
        end
        -- generic fallback: return empty table (signal exists but unknown args)
        return {}
    end,
    fireclickdetector = function(detector, dist) end,
    fireproximityprompt = function(prompt) end,
    firetouchinterest = function(a, b, c) end,
    getinstances = function()
        local instances = {}
        for inst in pairsFunction(dumperState.property_store) do
            if isProxy(inst) and (dumperState.property_store[inst].ClassName or dumperState.registry[inst]) then
                table.insert(instances, inst)
            end
        end
        if #instances == 0 then table.insert(instances, game) end
        return instances
    end,
    getnilinstances = function() return {} end,
    getgc = function() return {} end,
    getscripts = function() return {} end,
    getrunningscripts = function()
        -- AT3: must include the Animate script from character, but NOT arbitrary LocalScript instances
        local result = {}
        if _at.animateScript then result[#result+1] = _at.animateScript end
        return result
    end,
    getloadedmodules = function() return {} end,
    getcallingscript = function() return script end,
    -- script info stubs
    getscriptbytecode = function(s) return "" end,
    getscripthash = function(s) return "0000000000000000000000000000000000000000000000000000000000000000" end,
    getscriptclosure = function(s) return function() end end,
    -- property helpers
    isscriptable = function(obj, prop) return true end,
    setscriptable = function(obj, prop, state) return state end,
    getcallbackvalue = function(obj, prop) return nil end,
    -- clipboard
    setrbxclipboard = function(data) emitOutput(string.format("setrbxclipboard(%s)", serializeValue(data))) return true end,
    -- console extras
    rconsolesettitle = function(title) end,
    -- gc / registry
    getreg = function() return {} end,
    filtergc = function(kind, opts, returnOne) return returnOne and nil or {} end,
    -- function utils
    getfunctionhash = function(f) return "0000000000000000000000000000000000000000" end,
    restorefunction = function(f) end,
    -- misc
    messagebox = function(text, caption, flags)
        emitOutput(string.format("messagebox(%s, %s, %s)", serializeValue(text), serializeValue(caption), serializeValue(flags)))
        return 1
    end,
    readfile = function(file)
        emitOutput(string.format("readfile(%s)", formatStringLiteral(file)))
        return _at.files[formatValue(file)] or '"'\n    end,\n    writefile = function(file, content)\n        local key = formatValue(file)\n        _at.files[key] = formatValue(content)\n        _at.files_hidden = _at.files_hidden or {}\n        _at.files_hidden[key] = true  -- mark as hidden from listfiles\n        emitOutput(string.format("writefile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    appendfile = function(file, content)\n        local name = formatValue(file)\n        _at.files[name] = (_at.files[name] or "") .. formatValue(content)\n        emitOutput(string.format("appendfile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    loadfile = function(file) return function() return createProxyObject("loaded_file", false) end end,\n    listfiles = function(folder)\n        local base = formatValue(folder or "")\n        -- normalize: strip leading slash so "/" matches all files\n        base = base:gsub("^/+", "")\n        local result = {}\n        for name in pairsFunction(_at.folders) do\n            if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n        end\n        for name in pairsFunction(_at.files) do\n            -- skip files marked hidden (written by writefile, not real filesystem files)\n            if not (_at.files_hidden and _at.files_hidden[name]) then\n                if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n            end\n        end\n        return result\n    end,\n    isfile = function(file) return _at.files[formatValue(file)] ~= nil end,\n    isfolder = function(folder) return _at.folders[formatValue(folder)] == true end,\n    makefolder = function(folder)\n        local name = formatValue(folder)\n        if name ~= "" then\n            -- create all parent folders in the path\n            local path = ""\n            for segment in (name .. "/"):gmatch("([^/]+)/") do\n                path = path == "" and segment or (path .. "/" .. segment)\n                _at.folders[path] = true\n            end\n        end\n        emitOutput(string.format("makefolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfolder = function(folder)\n        local name = formatValue(folder)\n        _at.folders[name] = nil\n        emitOutput(string.format("delfolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfile = function(file)\n        _at.files[formatValue(file)] = nil\n        emitOutput(string.format("delfile(%s)", formatStringLiteral(file)))\n    end,\n    DrawingImmediate = (function()\n        local function makePaint()\n            local cbs = {}\n            return {\n                Connect = function(self, fn)\n                    cbs[#cbs+1] = fn\n                    -- return plain table so typeof(cn)=="table" passes the AT check\n                    return {\n                        Disconnect = function(self)\n                            for i,v in ipairs(cbs) do if v==fn then table.remove(cbs,i) break end end\n                        end,\n                        Connected = true,\n                    }\n                end,\n            }\n        end\n        local pc = {}\n        return {\n            Text = function(...) emitOutput("DrawingImmediate.Text(...)") end,\n            Line = function(...) emitOutput("DrawingImmediate.Line(...)") end,\n            Circle = function(...) emitOutput("DrawingImmediate.Circle(...)") end,\n            GetPaint = function(id) if not pc[id] then pc[id]=makePaint() end return pc[id] end,\n            ClearAll = function() emitOutput("DrawingImmediate.ClearAll()") end,\n        }\n    end)(),\n    Drawing = {\n        new = function(type)\n            local t = formatValue(type)\n            local proxy = createProxyObject("Drawing_" .. t, false)\n            registerVariable(proxy, t)\n            _at.userdata[proxy] = "renderobj"\n            emitOutput(string.format("local %s = Drawing.new(%s)", dumperState.registry[proxy], formatStringLiteral(t)))\n            return proxy\n        end,\n        Fonts = createProxyObject("Drawing.Fonts", false)\n    },\n    isrenderobj = function(obj)\n        if typeFunction(obj) ~= "table" then return false end\n        return _at.userdata[obj] == "renderobj"\n    end,\n    crypt = {\n        base64encode = function(s) return s end,\n        base64decode = function(s) return s end,\n        base64_encode = function(s) return s end,\n        base64_decode = function(s) return s end,\n        encrypt = function(s, k) return s end,\n        decrypt = function(s, k) return s end,\n        hash = function(s) return "hash" end,\n        generatekey = function(len) return string.rep("0", len or 32) end,\n        generatebytes = function(len) return string.rep("\\0", len or 16) end\n    },\n    base64_encode = function(s) return s end,\n    base64_decode = function(s) return s end,\n    base64encode = function(s) return s end,\n    base64decode = function(s) return s end,\n    mouse1click = function() emitOutput("mouse1click()") end,\n    mouse1press = function() emitOutput("mouse1press()") end,\n    mouse1release = function() emitOutput("mouse1release()") end,\n    mouse2click = function() emitOutput("mouse2click()") end,\n    mouse2press = function() emitOutput("mouse2press()") end,\n    mouse2release = function() emitOutput("mouse2release()") end,\n    mousemoverel = function(x, y) emitOutput(string.format("mousemoverel(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousemoveabs = function(x, y) emitOutput(string.format("mousemoveabs(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousescroll = function(delta) emitOutput(string.format("mousescroll(%s)", serializeValue(delta))) end,\n    keypress = function(key) emitOutput(string.format("keypress(%s)", serializeValue(key))) end,\n    keyrelease = function(key) emitOutput(string.format("keyrelease(%s)", serializeValue(key))) end,\n    keyclick = function(key) emitOutput(string.format("keyclick(%s)", serializeValue(key))) end,\n    isreadonly = function(t) return false end,\n    setreadonly = function(t, val) return t end,\n    make_writeable = function(t) return t end,\n    make_readonly = function(t) return t end,\n    getthreadidentity = function() return 7 end,\n    setthreadidentity = function(id) end,\n    getidentity = function() return 7 end,\n    setidentity = function(id) end,\n    getthreadcontext = function() return 7 end,\n    setthreadcontext = function(id) end,\n    getcustomasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getsynasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getinfo = function(func) return {source = "=", what = "Lua", name = "unknown", short_src = "dumper"} end,\n    getconstants = function(func) return {} end,\n    getupvalues = function(func) return {} end,\n    getprotos = function(func) return {} end,\n    getupvalue = function(func, i) return nil end,\n    setupvalue = function(func, i, val) end,\n    setconstant = function(func, i, val) end,\n    getconstant = function(func, i) return nil end,\n    getproto = function(func, i) return function() end end,\n    setproto = function(func, i, f) end,\n    getstack = function(level, i) return nil end,\n    setstack = function(level, i, val) end,\n    debug = {\n        getinfo = function(func, ...)\n            if func == print or func == _G.print or func == warn or func == _G.warn then\n                return {source = "=[C]", what = "C", name = "print", short_src = "[C]"}\n            end\n            if getInfo then return getInfo(func, ...) end\n            return {source = "=[C]", what = "C", short_src = "[C]"}\n        end,\n        getupvalue = debugLibrary.getupvalue or function() return nil end,\n        setupvalue = debugLibrary.setupvalue or function() end,\n        getmetatable = debugLibrary.getmetatable,\n        setmetatable = debugLibrary.setmetatable or setmetatable,\n        traceback = getTraceback or function() return '"' end,
        profilebegin = function() end,
        profileend = function() end,
        sethook = function() end
    },
    rconsoleprint = function(s) end,
    rconsoleclear = function() end,
    rconsolecreate = function() end,
    rconsoledestroy = function() end,
    rconsoleinput = function() return "" end,
    rconsoleinfo = function(s) end,
    rconsolewarn = function(s) end,
    rconsoleerr = function(s) end,
    rconsolename = function(name) end,
    printconsole = function(s) end,
    setfflag = function(flag, val) end,
    getfflag = function(flag) return "" end,
    setfpscap = function(cap) emitOutput(string.format("setfpscap(%s)", serializeValue(cap))) end,
    getfpscap = function() return 60 end,
    isnetworkowner = function(part) return true end,
    gethiddenproperty = function(instance, prop)
        if not isProxy(instance) then return nil, false end
        local props = dumperState.property_store[instance]
        if props and props[prop] ~= nil then return props[prop], true end
        return nil, false
    end,
    sethiddenproperty = function(instance, prop, val)
        if isProxy(instance) then
            local props = dumperState.property_store[instance]
            if props then
                if prop == "DistributedGameTime" then
                    -- don't store the set value; just record a tick base from current real value
                    -- so subsequent reads keep ticking from where they were
                    if not _at._dgtClock then
                        _at._dgtBase = (props[prop] or 1)
                        _at._dgtClock = osLibrary.clock()
                    end
                    -- intentionally do NOT store val - real Roblox ignores the set
                else
                    props[prop] = val
                end
            end
        end
        emitOutput(string.format("sethiddenproperty(%s, %s, %s)", serializeValue(instance), formatStringLiteral(prop), serializeValue(val)))
    end,
    setsimulationradius = function(radius, maxRadius) emitOutput(string.format("setsimulationradius(%s%s)", serializeValue(radius), maxRadius and ", " .. serializeValue(maxRadius) or "")) end,
    getspecialinfo = function(instance) return {} end,
    saveinstance = function(options) emitOutput(string.format("saveinstance(%s)", serializeValue(options or {}))) end,
    decompile = function(script) return "-- decompiled" end,
    lz4compress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4compress", 2) end
        local magic = "\x04\x22\x4d\x18"
        local lenBytes = string.char(
            math.floor(#s / 16777216) % 256,
            math.floor(#s / 65536) % 256,
            math.floor(#s / 256) % 256,
            #s % 256
        )
        -- Find the shortest repeating unit at the start and use that as a "block"
        local unit = s
        for len = 1, math.floor(#s / 2) do
            local candidate = s:sub(1, len)
            local repeated = string.rep(candidate, math.floor(#s / len))
            local remainder = s:sub(#repeated + 1)
            if repeated .. remainder == s then
                unit = candidate
                break
            end
        end
        -- Encode as: magic + origLen + unitLen(2 bytes) + unit + count(2 bytes) + remainder
        local count = math.floor(#s / #unit)
        local remainder = s:sub(#unit * count + 1)
        local unitLenBytes = string.char(math.floor(#unit / 256) % 256, #unit % 256)
        local countBytes = string.char(math.floor(count / 256) % 256, count % 256)
        local remLenBytes = string.char(math.floor(#remainder / 256) % 256, #remainder % 256)
        return magic .. lenBytes .. unitLenBytes .. unit .. countBytes .. remLenBytes .. remainder
    end,
    lz4decompress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4decompress", 2) end
        local magic = "\x04\x22\x4d\x18"
        if #s < 12 or s:sub(1, 4) ~= magic then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local b1, b2, b3, b4 = s:byte(5), s:byte(6), s:byte(7), s:byte(8)
        local origLen = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
        local unitLenHi, unitLenLo = s:byte(9), s:byte(10)
        local unitLen = unitLenHi * 256 + unitLenLo
        if #s < 10 + unitLen + 4 then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local unit = s:sub(11, 10 + unitLen)
        local countHi, countLo = s:byte(11 + unitLen), s:byte(12 + unitLen)
        local count = countHi * 256 + countLo
        local remLenHi, remLenLo = s:byte(13 + unitLen), s:byte(14 + unitLen)
        local remLen = remLenHi * 256 + remLenLo
        local remainder = s:sub(15 + unitLen, 14 + unitLen + remLen)
        return (string.rep(unit, count) .. remainder):sub(1, origLen)
    end,
    MessageBox = function(text, caption, type) return 1 end,
    setwindowactive = function() end,
    setwindowtitle = function(title) end,
    queue_on_teleport = function(code) emitOutput(string.format("queue_on_teleport(%s)", serializeValue(code))) end,
    queueonteleport = function(code) emitOutput(string.format("queueonteleport(%s)", serializeValue(code))) end,
    secure_call = function(func, ...) return func(...) end,
    create_secure_function = function(func) return func end,
    isvalidinstance = function(instance) return instance ~= nil end,
    validcheck = function(instance) return instance ~= nil end
}
for name, func in pairsFunction(exploitFuncs) do
    _G[name] = func
end
local nativeBit32 = bit32
local bitLibrary = {}
local function toBit(n)
    n = (n or 0) % 4294967296
    if n >= 2147483648 then n = n - 4294967296 end
    return math.floor(n)
end
local function toU32(n) return math.floor((n or 0) % 4294967296) end

local function _band(a, b)
    if nativeBit32 then return nativeBit32.band(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bor(a, b)
    if nativeBit32 then return nativeBit32.bor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bxor(a, b)
    if nativeBit32 then return nativeBit32.bxor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _lshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return toU32(toU32(n) * (2 ^ bits))
end
local function _rshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return math.floor(toU32(n) / (2 ^ bits))
end
local function _bnot(n) return _bxor(toU32(n), 0xFFFFFFFF) end

bitLibrary.tobit = toBit
bitLibrary.tohex = function(n, len)
    return string.format("%0" .. (len or 8) .. "x", toU32(n))
end
bitLibrary.band = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _band(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bxor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bxor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bnot    = function(n) return toBit(_bnot(n or 0)) end
bitLibrary.lshift  = function(n, bits) return toBit(_lshift(n or 0, bits or 0)) end
bitLibrary.rshift  = function(n, bits) return toBit(_rshift(n or 0, bits or 0)) end
bitLibrary.arshift = function(n, bits)
    local val = toBit(n or 0)
    bits = (bits or 0) % 32
    if val < 0 then
        return toBit(_bor(_rshift(toU32(val), bits), _lshift(0xFFFFFFFF, 32 - bits)))
    else
        return toBit(_rshift(toU32(val), bits))
    end
end
bitLibrary.rol = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_lshift(n, bits), _rshift(n, 32 - bits)))
end
bitLibrary.ror = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_rshift(n, bits), _lshift(n, 32 - bits)))
end
bitLibrary.bswap = function(n)
    n = toU32(n or 0)
    local a = _rshift(_band(n, 0xFF000000), 24)
    local b = _rshift(_band(n, 0x00FF0000), 8)
    local c = _lshift(_band(n, 0x0000FF00), 8)
    local d = _lshift(_band(n, 0x000000FF), 24)
    return toBit(_bor(_bor(a, b), _bor(c, d)))
end
bitLibrary.countlz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    if _band(n, 0xFFFF0000) == 0 then count = count + 16; n = _lshift(n, 16) end
    if _band(n, 0xFF000000) == 0 then count = count + 8;  n = _lshift(n, 8)  end
    if _band(n, 0xF0000000) == 0 then count = count + 4;  n = _lshift(n, 4)  end
    if _band(n, 0xC0000000) == 0 then count = count + 2;  n = _lshift(n, 2)  end
    if _band(n, 0x80000000) == 0 then count = count + 1   end
    return count
end
bitLibrary.countrz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    while _band(n, 1) == 0 do n = _rshift(n, 1); count = count + 1 end
    return count
end
bitLibrary.lrotate = bitLibrary.rol
bitLibrary.rrotate = bitLibrary.ror
bitLibrary.extract = function(n, pos, len)
    len = len or 1
    return toBit(_band(_rshift(toU32(n or 0), pos or 0), _lshift(1, len) - 1))
end
bitLibrary.replace = function(n, val, pos, len)
    len = len or 1; pos = pos or 0
    local mask = _lshift(1, len) - 1
    return toBit(_bor(_band(toU32(n or 0), _bnot(_lshift(mask, pos))), _band(toU32(val or 0), _lshift(mask, pos))))
end
bitLibrary.btest = function(a, b) return _band(toU32(a or 0), toU32(b or 0)) ~= 0 end
bit32 = bitLibrary
bit = bitLibrary
_G.bit = bitLibrary
_G.bit32 = bitLibrary
table.getn = table.getn or function(t) return #t end
table.foreach = table.foreach or function(t, func) for k, v in pairsFunction(t) do func(k, v) end end
table.foreachi = table.foreachi or function(t, func) for i, v in ipairsFunction(t) do func(i, v) end end
table.find = table.find or function(t, value, init)
    for i = (init or 1), #t do
        if t[i] == value then return i end
    end
    return nil
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairsFunction(t) do out[k] = v end
    return out
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clear = table.clear or function(t) for k in pairsFunction(t) do t[k] = nil end end
table.find = table.find or function(t, val, init)
    for i = init or 1, #t do
        if t[i] == val then return i end
    end
    return nil
end
table.clear = table.clear or function(t)
    for k in pairs(t) do t[k] = nil end
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
table.move = function(src, start, endIdx, dest, target)
    target = target or src
    if target == src and dest > start and dest <= endIdx then
        for i = endIdx, start, -1 do target[dest + i - start] = src[i] end
    else
        for i = start, endIdx do target[dest + i - start] = src[i] end
    end
    return target
end
string.split = string.split or function(str, sep)
    local t = {}
    for match in string.gmatch(str, "([^" .. (sep or "%s") .. "]+)") do table.insert(t, match) end
    return t
end
if not math.frexp then
    math.frexp = function(x)
        if x == 0 then return 0, 0 end
        local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
        local m = x / 2 ^ exp
        return m, exp
    end
end
if not math.ldexp then math.ldexp = function(m, e) return m * 2 ^ e end end
if not utf8 then
    utf8 = {}
    utf8.char = function(...)
        local args = {...}
        local chars = {}
        for _, byte in ipairsFunction(args) do table.insert(chars, string.char(byte % 256)) end
        return table.concat(chars)
    end
    utf8.len = function(s) return #s end
    utf8.codes = function(s)
        local i = 0
        return function() i = i + 1; if i <= #s then return i, string.byte(s, i) end end
    end
end
-- graphemes: bypass nested anti-tamper chain third[1][1][1][1][1][1](first, second)
utf8.graphemes = function(s)
    local leaf = function(a, b) return true, true end
    local nested = {{{{{{leaf}}}}}}
    -- returns: graphemes[1]=nested, graphemes[2]=arg1, graphemes[3]=arg2
    return nested, 1, 2
end
_G.utf8 = utf8
pairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return pairsFunction(t) end
    return function() return nil end, t, nil
end
ipairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return ipairsFunction(t) end
    return function() return nil end, t, 0
end
_G.pairs = pairs
_G.ipairs = ipairs
_G.math = math
_G.table = table
-- override string.dump to prevent source/internal name leaking
local _realStringDump = string.dump
-- build a set of all sandbox-internal functions to block
local _blockedDump = setmetatable({}, {__mode="k"})
string.dump = function(f, ...)
    if isProxy(f) then
        errorFunction("unable to dump given function", 2)
    end
    if _blockedDump[f] then
        errorFunction("unable to dump given function", 2)
    end
    -- block exploit funcs
    for name, val in pairsFunction(exploitFuncs) do
        if val == f then errorFunction("unable to dump given function", 2) end
    end
    -- block any function whose bytecode would leak "dumper.lua" or internal names
    local ok, bc = pcallFunction(_realStringDump, f)
    if ok and typeFunction(bc) == "string" then
        if bc:find("dumper%.lua", 1, true) or
           bc:find("emitOutput", 1, true) or
           bc:find("serializeValue", 1, true) or
           bc:find("ipairsFunction", 1, true) or
           bc:find("pairsFunction", 1, true) or
           bc:find("dumperState", 1, true) then
            errorFunction("unable to dump given function", 2)
        end
        return bc
    end
    errorFunction("unable to dump given function", 2)
end
_G.string = string
_G.os = os
os.execute = function() return nil end
os.exit = function() return nil end
os.remove = function() return nil, "disabled" end
os.rename = function() return nil, "disabled" end
_G.coroutine = coroutine
_G.io = nil
_G.debug = exploitFuncs.debug
_G._realSetHook = setHook
_G.utf8 = utf8
_G.next = next
_G.tostring = tostring
_G.tonumber = tonumber
_G.getmetatable = getmetatable
_G.setmetatable = setmetatable
_G.pcall = function(f, ...)
    local results = {pcallFunction(f, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.xpcall = function(f, errFunc, ...)
    local function wrapper(err)
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then return err end
        if errFunc then return errFunc(err) end
        return err
    end
    local results = {xpcallFunction(f, wrapper, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.error = errorFunction
if _G.originalError == nil then _G.originalError = errorFunction end
_G.assert = assert
_G.select = select
_G.type = typeFunction
_G.rawget = rawget
_G.rawset = rawset
_G.rawequal = rawEqualFunction
_G.rawlen = rawlen or function(t) return #t end
_G.unpack = table.unpack or unpack
_G.pack = table.pack or function(...) return {n = select("#", ...), ...} end
_G.task = task
_G.wait = wait
_G.Wait = wait
_G.delay = delay
_G.Delay = delay
_G.spawn = spawn
_G.Spawn = spawn
_G.tick = tick
_G.time = time
_G.elapsedTime = elapsedTime
_G.game = game
_G.Game = game
_G.workspace = workspace
_G.Workspace = workspace
_G.script = script
_G.Enum = Enum
_G.Instance = Instance
_G.Random = Random
_G.Vector3 = Vector3
_G.Vector2 = Vector2
_G.CFrame = CFrame
_G.Color3 = Color3
_G.BrickColor = BrickColor
_G.UDim = UDim
_G.UDim2 = UDim2
_G.TweenInfo = TweenInfo
_G.Rect = Rect
_G.Region3 = Region3
_G.Region3int16 = Region3int16
_G.Ray = Ray
_G.NumberRange = NumberRange
_G.NumberSequence = NumberSequence
_G.NumberSequenceKeypoint = NumberSequenceKeypoint
_G.ColorSequence = ColorSequence
_G.ColorSequenceKeypoint = ColorSequenceKeypoint
_G.PhysicalProperties = PhysicalProperties
_G.Font = Font
_G.RaycastParams = RaycastParams
_G.OverlapParams = OverlapParams
_G.PathWaypoint = PathWaypoint
_G.Axes = Axes
_G.Faces = Faces
_G.Vector3int16 = Vector3int16
_G.Vector2int16 = Vector2int16
_G.CatalogSearchParams = CatalogSearchParams
_G.DateTime = DateTime
settings = function()
    local enumKey = "Enum.QualityLevel.Automatic"
    if not _at.enum[enumKey] then
        local p = createProxyObject(enumKey, false)
        dumperState.registry[p] = enumKey
        _at.enum[enumKey] = p
    end
    local qualityProxy = _at.enum[enumKey]
    return {
        Rendering = {QualityLevel = qualityProxy, FrameRateManager = 0, EagerBulkExecution = false},
        Studio    = {},
        Network   = {IncomingReplicationLag = 0},
        Physics   = {PhysicsEnvironmentalThrottle = createProxyObject("Enum.EnviromentalPhysicsThrottle.DefaultAuto", false)},
    }
end
_G.settings = settings
getmetatable = function(x)
    if _at.userdata[x] then return getMetatableFunction(x) end
    if isProxy(x) then return "The metatable is locked" end
    return getMetatableFunction(x)
end
_G.getmetatable = getmetatable
type = function(x)
    if _at.threadLike[x] then return "thread" end
    if _at.userdata[x] then return "userdata" end
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then return "userdata" end
    return typeFunction(x)
end
_G.type = type
buffer = {
    create = function(size)
        local b = {}
        _at.buffers[b] = string.rep("\0", size or 0)
        return b
    end,
    fromstring = function(s)
        local b = {}
        _at.buffers[b] = formatValue(s)
        return b
    end,
    tostring = function(b)
        return _at.buffers[b] or ""
    end,
    len = function(b)
        return #(_at.buffers[b] or "")
    end,
    copy = function(dst, dstOffset, src, srcOffset, count)
        local srcData = _at.buffers[src] or ""
        local dstData = _at.buffers[dst] or ""
        srcOffset = (srcOffset or 0) + 1
        dstOffset = (dstOffset or 0) + 1
        local chunk = srcData:sub(srcOffset, count and srcOffset + count - 1 or -1)
        local before = dstData:sub(1, dstOffset - 1)
        local after  = dstData:sub(dstOffset + #chunk)
        _at.buffers[dst] = before .. chunk .. after
    end,
    fill = function(b, offset, value, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        count  = count or (#data - offset + 1)
        local fill = string.rep(string.char(value % 256), count)
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + count)
        _at.buffers[b] = before .. fill .. after
    end,
    writestring = function(b, offset, s, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        s = formatValue(s)
        if count then s = s:sub(1, count) end
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + #s)
        _at.buffers[b] = before .. s .. after
    end,
    readstring = function(b, offset, len)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        return data:sub(offset, len and offset + len - 1 or -1)
    end,
    writeu8  = function(b, offset, v) local d=_at.buffers[b] or""; offset=(offset or 0)+1; _at.buffers[b]=d:sub(1,offset-1)..string.char(v%256)..d:sub(offset+1) end,
    readu8   = function(b, offset) local d=_at.buffers[b] or""; return string.byte(d,(offset or 0)+1) or 0 end,
    writeu16 = function(b, offset, v) offset=(offset or 0); buffer.writeu8(b,offset,v%256); buffer.writeu8(b,offset+1,math.floor(v/256)%256) end,
    readu16  = function(b, offset) return buffer.readu8(b,offset) + buffer.readu8(b,(offset or 0)+1)*256 end,
    writeu32 = function(b, offset, v) offset=(offset or 0); for i=0,3 do buffer.writeu8(b,offset+i,math.floor(v/(256^i))%256) end end,
    readu32  = function(b, offset) local v=0; for i=0,3 do v=v+buffer.readu8(b,(offset or 0)+i)*(256^i) end; return v end,
    writei8  = function(b, offset, v) buffer.writeu8(b, offset, v < 0 and v+256 or v) end,
    readi8   = function(b, offset) local v=buffer.readu8(b,offset); return v>=128 and v-256 or v end,
    writei16 = function(b, offset, v) buffer.writeu16(b, offset, v < 0 and v+65536 or v) end,
    readi16  = function(b, offset) local v=buffer.readu16(b,offset); return v>=32768 and v-65536 or v end,
    writei32 = function(b, offset, v) buffer.writeu32(b, offset, v < 0 and v+4294967296 or v) end,
    readi32  = function(b, offset) local v=buffer.readu32(b,offset); return v>=2147483648 and v-4294967296 or v end,
    writef32 = function(b, offset, v) buffer.writeu32(b, offset, math.floor(math.abs(v)*1000)%4294967296) end,
    readf32  = function(b, offset) return buffer.readu32(b,offset)/1000 end,
    writef64 = function(b, offset, v) buffer.writeu32(b, offset, 0); buffer.writeu32(b, (offset or 0)+4, math.floor(math.abs(v)*1000)%4294967296) end,
    readf64  = function(b, offset) return buffer.readu32(b,(offset or 0)+4)/1000 end,
}
_G.buffer = buffer
typeof = function(x)
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then
        if _at.typeOverride[x] then return _at.typeOverride[x] end
        local regName = dumperState.registry[x]
        if regName then
            if regName == "Enum" then return "Enums" end
            if regName:match("^Enum%.[^%.]+$") then return "Enum" end
            if regName:match("^Enum%.[^%.]+%.[^%.]+$") then return "EnumItem" end
            if regName:match("Vector3") then return "Vector3" end
            if regName:match("CFrame") then return "CFrame" end
            if regName:match("Color3") then return "Color3" end
            if regName:match("UDim") then return "UDim2" end
        end
        return "Instance"
    end
    if _at.threadLike[x] then return "thread" end
    local mt = getMetatableFunction(x)
    if mt and mt.__typeof then return mt.__typeof end
    return typeFunction(x) == "table" and "table" or typeFunction(x)
end
_G.typeof = typeof
newproxy = function(withMeta)
    local proxy = {}
    _at.userdata[proxy] = true
    if withMeta then
        setmetatable(proxy, {})
    end
    return proxy
end
_G.newproxy = newproxy
tonumber = function(x, base)
    if getProxyValue(x) ~= 0 then return 123456789 end
    return toNumberFunction(x, base)
end
_G.tonumber = tonumber
rawequal = function(a, b) return rawEqualFunction(a, b) end
_G.rawequal = rawequal
tostring = function(x)
    if isProxy(x) then
        local mt = getMetatableFunction(x)
        if mt and mt.__tostring then
            local ok, r = pcallFunction(mt.__tostring, x)
            if ok and r then return r end
        end
        local regName = dumperState.registry[x]
        return regName or "Instance"
    end
    local mt = getMetatableFunction(x)
    if mt and mt.__tostring then
        local ok, r = pcallFunction(mt.__tostring, x)
        if ok and r then return r end
    end
    return toStringFunction(x)
end
_G.tostring = tostring
dumperState.last_http_url = nil
loadstring = function(code, chunkName)
    if typeFunction(code) ~= "string" then return function() return createProxyObject("loaded", false) end end
    local url = dumperState.last_http_url or code
    dumperState.last_http_url = nil
    local libName = nil
    local lowerCode = url:lower()
    local libs = {{pattern = "rayfield", name = "Rayfield"}, {pattern = "orion", name = "OrionLib"}, {pattern = "kavo", name = "Kavo"}, {pattern = "venyx", name = "Venyx"}, {pattern = "sirius", name = "Sirius"}, {pattern = "linoria", name = "Linoria"}, {pattern = "wally", name = "Wally"}, {pattern = "dex", name = "Dex"}, {pattern = "infinite", name = "InfiniteYield"}, {pattern = "hydroxide", name = "Hydroxide"}, {pattern = "simplespy", name = "SimpleSpy"}, {pattern = "remotespy", name = "RemoteSpy"}}
    for _, lib in ipairsFunction(libs) do if lowerCode:find(lib.pattern) then libName = lib.name; break end end
    if libName then
        local proxy = createProxyObject(libName, false)
        dumperState.registry[proxy] = libName
        dumperState.names_used[libName] = true
        if url:match("^https?://") then emitOutput(string.format('local %s = loadstring(game:HttpGet("%s"))()', libName, url)) end
        return function() return proxy end
    end
    if url:match("^https?://") then
        local proxy = createProxyObject("Library", false)
        emitOutput(string.format('local loadstring = loadstring(game:HttpGet("%s"))()', url))
        return function() return proxy end
    end
    if code:match("local%s+a%s*=%s*if%s+true%s+then") then return nil, "attempt to call a nil value" end
    if typeFunction(code) == "string" then code = processString(code) end
    local func, err = loadFunction(code)
    if func then return func end
    local proxy = createProxyObject("LoadedChunk", false)
    return function() return proxy end
end
load = loadstring
_G.loadstring = loadstring
_G.load = loadstring
require = function(module)
    local modName = dumperState.registry[module] or serializeValue(module)
    local proxy = createProxyObject("RequiredModule", false)
    local varName = registerVariable(proxy, "module")
    emitOutput(string.format("local %s = require(%s)", varName, modName))
    return proxy
end
_G.require = require
print = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("print(%s)", table.concat(items, ", ")))
end
_G.print = print
warn = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("warn(%s)", table.concat(items, ", ")))
end
_G.warn = warn
-- Tag Roblox-like builtins as C closures so iscclosure() returns true for them
do
    if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end
    local _cbuiltins = {
        print, warn, tick, time, elapsedTime, pcall, xpcall, error, assert,
        tostring, tonumber, type, typeof, rawget, rawset, rawequal, rawlen,
        setmetatable, getmetatable, ipairs, pairs, next, select, unpack,
        require, loadstring, load,
    }
    for _, fn in ipairs(_cbuiltins) do
        if typeFunction(fn) == "function" then
            _at.cclosureSet[fn] = true
        end
    end
end
_G.shared = shared
local globalBase = _G
local globalMeta = setmetatable({}, {
    __index = function(tbl, key)
        if configuration.VERBOSE then printFunction("[VERBOSE] Accessing field: " .. toStringFunction(key)) end
        local val = rawget(globalBase, key)
        if val == nil then val = rawget(_G, key) end
        if configuration.VERBOSE then
            if val ~= nil then
                if typeFunction(val) == "table" then printFunction("[VERBOSE] Found global table: " .. toStringFunction(key))
                elseif typeFunction(val) == "function" then printFunction("[VERBOSE] Found global function: " .. toStringFunction(key))
                else printFunction("[VERBOSE] Found global value: " .. toStringFunction(key) .. " = " .. toStringFunction(val)) end
            else
                printFunction("[VERBOSE] Missing field, providing dummy function: " .. toStringFunction(key))
                val = function() if configuration.VERBOSE then printFunction("[Missing Function] Called: " .. toStringFunction(key) .. " with 0 arguments") end return nil end
            end
        end
        return val
    end,
    __newindex = function(tbl, key, val) rawset(globalBase, key, val) end
})
_G._G = globalMeta
function proxyTable.reset()
    dumperState = {output = {}, indent = 0, registry = {}, reverse_registry = {}, names_used = {}, parent_map = {}, property_store = {}, call_graph = {}, variable_types = {}, string_refs = {}, proxy_id = 0, callback_depth = 0, pending_iterator = false, last_http_url = nil, last_emitted_line = nil, repetition_count = 0, current_size = 0, limit_reached = false, ls_counter = 0, captured_constants = {}}
    _at.mem = {}
    _at.tags = {}
    _at.sigs = {}
    _at.acts = {}
    _at.json = {}
    _at.enum = {}
    _at.svcCache = {}
    _at.typeOverride = {}
    _at.connState = {}
    _at.pendingHeartbeat = {}
    _at.locEntries = {}
    _at.userdata = {}
    _at.localPlayer = nil
    setmetatable(_at.userdata, {__mode = "k"})
    _at.debugIds = {}
    setmetatable(_at.debugIds, {__mode = "k"})
    _at.debugIdCtr = 0
    uiCounters = {}
    game = createProxyObject("game", true)
    workspace = createProxyObject("workspace", true)
    script = createProxyObject("script", true)
    Enum = createProxyObject("Enum", true)
    shared = createProxyObject("shared", true)
    dumperState.property_store[game] = {PlaceId = numericArg, GameId = numericArg, placeId = numericArg, gameId = numericArg}
    dumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}
    _G.game = game; _G.Game = game; _G.workspace = workspace; _G.Workspace = workspace; _G.script = script; _G.Enum = Enum; _G.shared = shared
    local meta = debugLibrary.getmetatable(Enum)
    meta.__index = function(_, key)
        if key == proxyList or key == "__proxy_id" then return rawget(_, key) end
        local enumName = "Enum." .. formatValue(key)
        if not _at.enum[enumName] then
            local enumProxy = createProxyObject(enumName, false)
            dumperState.registry[enumProxy] = enumName
            _at.enum[enumName] = enumProxy
        end
        return _at.enum[enumName]
    end
    seedCoreRobloxInstances()
    if type(_G._bypassOnReset) == "function" then
        local prevOutput = dumperState.output
        local prevOutputCount = #prevOutput
        local prevIndent = dumperState.indent
        local prevLast = dumperState.last_emitted_line
        local prevRep = dumperState.repetition_count
        local prevSize = dumperState.current_size
        local prevLimit = dumperState.limit_reached
        pcall(_G._bypassOnReset)
        for i = #prevOutput, prevOutputCount + 1, -1 do
            prevOutput[i] = nil
        end
        dumperState.output = prevOutput
        dumperState.indent = prevIndent
        dumperState.last_emitted_line = prevLast
        dumperState.repetition_count = prevRep
        dumperState.current_size = prevSize
        dumperState.limit_reached = prevLimit
    end
end
function proxyTable.get_output() return getFullOutput() end
function proxyTable.save(file) return saveToFile(file) end
function proxyTable.get_call_graph() return dumperState.call_graph end
function proxyTable.get_string_refs() return dumperState.string_refs end
function proxyTable.get_stats() return {total_lines = #dumperState.output, remote_calls = #dumperState.call_graph, suspicious_strings = #dumperState.string_refs, proxies_created = dumperState.proxy_id} end
local dumper = {callId = "LUASPLOIT_", binaryOperatorNames = {["and"] = "AND", ["or"] = "OR", [">"] = "GT", ["<"] = "LT", [">="] = "GE", ["<="] = "LE", ["=="] = "EQ", ["~="] = "NEQ", [".."] = "CAT"}}
function dumper:hook(code) return self.callId .. code end
function dumper:process_expr(expr)
    if not expr then return "nil" end
    if typeFunction(expr) == "string" then return expr end
    local tag = expr.tag or expr.kind
    if tag == "number" or tag == "string" then
        local val = tag == "string" and string.format("%q", expr.text) or (expr.value or expr.text)
        if configuration.CONSTANT_COLLECTION then return string.format("%sGET(%s)", self.callId, val) end
        return val
    end
    if tag == "local" or tag == "global" then return (expr.name or expr.token).text
    elseif tag == "boolean" or tag == "bool" then return toStringFunction(expr.value)
    elseif tag == "binary" then
        local lhs = self:process_expr(expr.lhsoperand)
        local rhs = self:process_expr(expr.rhsoperand)
        local op = expr.operator.text
        local opName = self.binaryOperatorNames[op]
        if opName then return string.format("%s%s(%s, %s)", self.callId, opName, lhs, rhs) end
        return string.format("(%s %s %s)", lhs, op, rhs)
    elseif tag == "call" then
        local func = self:process_expr(expr.func)
        local args = {}
        for i, node in ipairsFunction(expr.arguments) do args[i] = self:process_expr(node.node or node) end
        return string.format("%sCALL(%s, %s)", self.callId, func, table.concat(args, ", "))
    elseif tag == "indexname" or tag == "index" then
        local exprStr = self:process_expr(expr.expression)
        local keyStr = tag == "indexname" and string.format("%q", expr.index.text) or self:process_expr(expr.index)
        return string.format("%sCHECKINDEX(%s, %s)", self.callId, exprStr, keyStr)
    end
    return "nil"
end
function dumper:process_statement(stmt)
    if not stmt then return "" end
    local tag = stmt.tag
    if tag == "local" or tag == "assign" then
        local vars, vals = {}, {}
        for _, node in ipairsFunction(stmt.variables or {}) do table.insert(vars, self:process_expr(node.node or node)) end
        for _, node in ipairsFunction(stmt.values or {}) do table.insert(vals, self:process_expr(node.node or node)) end
        return (tag == "local" and "local " or "") .. table.concat(vars, ", ") .. " = " .. table.concat(vals, ", ")
    elseif tag == "block" then
        local stmts = {}
        for _, s in ipairsFunction(stmt.statements or {}) do table.insert(stmts, self:process_statement(s)) end
        return table.concat(stmts, "; ")
    end
    return self:process_expr(stmt) or ""
end
local function _loosePasteCode(code)
    if typeFunction(code) ~= "string" then return code end
    code = code:gsub("```lua", ""):gsub("```", "")
    return code
end
local function _loadLooseChunk(code, chunkName)
    local sanitized = processString(_loosePasteCode(code))
    local lines = {}
    sanitized:gsub("([^\n]*)\n?", function(line)
        if line ~= "" or #lines == 0 or sanitized:sub(-1) == "\n" then table.insert(lines, line) end
    end)
    local skipped = {}
    for _ = 1, 400 do
        local current = table.concat(lines, "\n")
        local func, err = loadFunction(current, chunkName)
        if func then return func, nil, current, skipped end
        local lineNo = toNumberFunction(toStringFunction(err):match("%]:(%d+):") or toStringFunction(err):match(":(%d+):"))
        if not lineNo or not lines[lineNo] or skipped[lineNo] then return nil, err, current, skipped end
        skipped[lineNo] = lines[lineNo]
        lines[lineNo] = "-- " .. lines[lineNo]
    end
    return nil, "too many invalid loose-paste lines", table.concat(lines, "\n"), skipped
end
function proxyTable.dump_file(inputPath, outputPath)
    proxyTable.reset()
    local file = ioLibrary.open(inputPath, "rb")
    if not file then
    printFunction("error: cannot open input")
        return false
    end
    local code = file:read("*a")
    file:close()
    printFunction("input: normalize")
    local func, err, sanitized, skipped = _loadLooseChunk(code, "Obfuscated_Script")
    if not func then
        printFunction("error: load " .. toStringFunction(err))
        return false
    end
    if skipped then
        local skippedCount = 0
        for _ in pairsFunction(skipped) do skippedCount = skippedCount + 1 end
        if skippedCount > 0 then printFunction("input: skipped-lines=" .. toStringFunction(skippedCount)) end
    end
    local _SANDBOX_BLOCK = {
        io=true, os=true, debug=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true,
    }
    local _rawTb = debugLibrary and debugLibrary.traceback
    local _badTbWords = {
        "sandbox","hook","intercept","mock","proxy","virtual_env",
        "decompil","emulat","simulat","fake_","getupval","hookfunc",
        "replaceclos","newcclos","restorefunction","bypass","dumper",
    }
    local _tbWrapper = function(thread, msg, level)
        local ok, tb
        if _rawTb then
            if typeFunction(thread) == "thread" then
                ok, tb = pcallFunction(_rawTb, thread, msg, level)
            else
                ok, tb = pcallFunction(_rawTb, thread, msg)
            end
        end
        if not ok or typeFunction(tb) ~= "string" then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        local lines = {}
        for line in (tb .. "\n"):gmatch("([^\n]*)\n") do
            local lo = line:lower()
            local bad = false
            for _, w in next, _badTbWords do
                if lo:find(w, 1, true) then bad = true; break end
            end
            if not bad then lines[#lines + 1] = line end
        end
        local cleaned = table.concat(lines, "\n")
        cleaned = cleaned:gsub("%[([%w%+%/]+)%]", function(inner)
            if #inner + 2 < 10 then return "[RobloxGameScript]" end
            return "[" .. inner .. "]"
        end)
        if #cleaned < 20 then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        return cleaned
    end
    local _SAFE_DEBUG = {
        getinfo = function(func, ...)
            if typeFunction(func) == "number" then
                return nil
            end
            return {source = "=[C]", what = "C", name = "C function", short_src = "[C]"}
        end,
        traceback  = _tbWrapper,
        getupvalue = function(fn, i) return nil end,
    }
    local _SAFE_OS = {
        clock = function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end,
        time  = osLibrary.time,
        date  = osLibrary.date,
    }
    local env = setmetatable({
        _VERSION = "Luau",
        LuraphContinue = nil,
        __LC__ = function() end,
        script = script, game = game, workspace = workspace,
        io      = nil,
        os      = _SAFE_OS,
        debug   = _SAFE_DEBUG,
        error   = _origError,
        dofile  = nil,
        loadfile = nil,
        require = nil,
        package = nil,
        socket  = nil,
        ffi     = nil,
        collectgarbage = nil,
        newproxy = newproxy,
        -- hide _G metatable from scripts
        getmetatable = function(obj)
            if obj == _G or obj == env then return nil end
            if _at.userdata[obj] then return getMetatableFunction(obj) end
            if isProxy(obj) then return "The metatable is locked" end
            return getMetatableFunction(obj)
        end,
        LUASPLOIT_CHECKINDEX = function(tbl, key)
            local val = tbl[key]
            if typeFunction(val) == "table" and not dumperState.registry[val] then
                dumperState.ls_counter = dumperState.ls_counter + 1
                dumperState.registry[val] = "v" .. dumperState.ls_counter
            end
            return val
        end,
        LUASPLOIT_GET = function(v) return v end,
        LS_CALL = function(f, ...)
            if typeFunction(f) ~= "function" then return nil end
            return f(...)
        end,
        LS_NAMECALL = function(t, method, ...)
            if typeFunction(t) ~= "table" then return nil end
            if typeFunction(t[method]) ~= "function" then return nil end
            return t[method](t, ...)
        end,
        LUASPLOIT_CALL = function(f, ...) return f(...) end,
        LUASPLOIT_NAMECALL = function(t, method, ...) return t[method](t, ...) end,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end
    }, {
        __index = function(_, k)
            if _SANDBOX_BLOCK[k] then return nil end
            -- block dumper internal globals from leaking into script env
            if k == "LuraphContinue" or k == "__FLAMEDUMPER_REQUIRE_ONLY"
            or k == "proxyTable" or k == "dumperState" or k == "_at" then
                return nil
            end
            return _G[k]
        end,
        __newindex = _G
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, env)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, env) end
        end
    end
    printFunction("vm: running")
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    local success, runErr = xpcallFunction(function() func() end, function(e) return toStringFunction(e) end)
    setHook()
    if not success and not toStringFunction(runErr):match("TIMEOUT") then
        emitComment("Runtime: " .. toStringFunction(runErr))
    end
    local saved = proxyTable.save(outputPath or configuration.OUTPUT_FILE)
    if saved then
        local stats = proxyTable.get_stats()
        printFunction(string.format("done: lines=%d remotes=%d strings=%d",
            stats.total_lines, stats.remote_calls, stats.suspicious_strings))
    else
        printFunction("error: write failed")
    end
    return saved
end
function proxyTable.dump_string(code, outputPath)
    proxyTable.reset()
    if code then code = processString(code) end
    local func, err = loadFunction(code)
    if not func then
        emitComment("Load Error: " .. (err or "unknown"))
        if outputPath then proxyTable.save(outputPath) end
        return false, err
    end
    local _DS_BLOCK = {
        io=true, os=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true, debug=true,
    }
    local _DS_OS = { clock=function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end, time=osLibrary.time, date=osLibrary.date }
    local dsEnv = setmetatable({
        _VERSION="Luau",
        io=nil, os=_DS_OS, debug=nil, dofile=nil, loadfile=nil,
        require=nil, package=nil, socket=nil, ffi=nil,
        collectgarbage=nil, newproxy=newproxy,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end,
    }, {
        __index = function(_, k)
            if _DS_BLOCK[k] then return nil end
            return _G[k]
        end,
        __newindex = _G,
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, dsEnv)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, dsEnv) end
        end
    end
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    xpcallFunction(function() func() end, function(e)
        emitComment("Runtime: " .. toStringFunction(e))
    end)
    setHook()
    if outputPath then return proxyTable.save(outputPath) end
    return true, getFullOutput()
end
do
    local bypassPath = (arg and arg[0] and arg[0]:match("^(.+[\\/])")) or ""
    local ok, err = pcall(dofile, bypassPath .. "bypass.lua")
    if not ok then
        local ok2 = pcall(dofile, "bypass.lua")
        if not ok2 then
            printFunction("[dumper] bypass.lua not found, continuing without supplement")
        end
    end
end

_G.LuraphContinue = nil
if not rawget(_G, "__FLAMEDUMPER_REQUIRE_ONLY") then
    if arg and arg[1] then
        local success = proxyTable.dump_file(arg[1], arg[2])
        if success then end
    else
        local file = ioLibrary.open("obfuscated.lua", "rb")
        if file then
            file:close()
            local success = proxyTable.dump_file("obfuscated.lua")
            if success then
                printFunction(proxyTable.get_output())
            end
        else
            printFunction("Usage: lua dumper.lua <input> [output] [key]")
        end
    end
end
return proxyTable
, func=function: 0x75283443af70")
print("  Level 6: source==[C], func=function: 0x75283f996df0")
print("  Level 7: source=local unpack = unpack or table.unpack
local warn = warn or function() end

local _origPcall = pcall
local _origXpcall = xpcall
local _origError = error

local debugLibrary = debug
_G._VERSION = "Luau"
local setHook = debug.sethook
local getInfo = debug.getinfo
local getTraceback = debug.traceback
local loadFunction = load
local loadStringFunction = loadstring or load
local pcallFunction = pcall
local xpcallFunction = xpcall
local errorFunction = error
local typeFunction = type
local getMetatableFunction = getmetatable
local rawEqualFunction = rawequal
local toStringFunction = tostring
local toNumberFunction = tonumber
local ioLibrary = io
local osLibrary = os
local pairsFunction = pairs
local ipairsFunction = ipairs
local tableUnpackFunction = table.unpack or unpack
local proxyTable = {}
proxyTable.__index = proxyTable
local configuration = {
    MAX_DEPTH = 15,
    MAX_TABLE_ITEMS = 150,
    OUTPUT_FILE = "dumped_output.lua",
    VERBOSE = false,
    TRACE_CALLBACKS = true,
    TIMEOUT_SECONDS = 6.57,
    MAX_REPEATED_LINES = 8,
    MIN_DEOBF_LENGTH = 150,
    MAX_OUTPUT_SIZE = 6 * 1024 * 1024,
    CONSTANT_COLLECTION = true,
    INSTRUMENT_LOGIC = true
}
local inputKey = (arg and arg[3]) or "NoKey"
if arg and arg[3] then
    print("[Dumper] Auto-Input Key Detected: " .. toStringFunction(inputKey))
end
local dumperState = {
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
    ls_counter = 0
}
local _at = {
    mem          = {},
    tags         = {},
    sigs         = {},
    acts         = {},
    json         = {},
    enum         = {},
    svcCache     = {},
    typeOverride = {},
    connState    = {},
    debugIds     = {},
    debugIdCtr   = 0,
    instTags     = {},
    attrs        = {},
    children     = {},
    threadLike   = {},
    vectors      = {},
    buffers      = {},
    userdata     = {},
    localPlayer  = nil,
    weldRegistry = {},
    services     = {},
    folders      = {},
    files        = {},
    refBase      = {},
    metaHooks    = {},
    currentNamecallMethod = nil,
    inMetaHook   = false,
    pendingHeartbeat = {},
    locEntries = {},
    signalCallbacks = {},  -- AT5: live signal firing
    animateScript = nil,   -- AT3: getrunningscripts
}
setmetatable(_at.debugIds, {__mode = "k"})
setmetatable(_at.instTags, {__mode = "k"})
setmetatable(_at.attrs, {__mode = "k"})
setmetatable(_at.children, {__mode = "k"})
setmetatable(_at.threadLike, {__mode = "k"})
setmetatable(_at.vectors, {__mode = "k"})
setmetatable(_at.buffers, {__mode = "k"})
setmetatable(_at.userdata, {__mode = "k"})
setmetatable(_at.refBase, {__mode = "k"})
local function _getDebugId(p)
    if not _at.debugIds[p] then
        _at.debugIdCtr = _at.debugIdCtr + 1
        local n = _at.debugIdCtr
        _at.debugIds[p] = toStringFunction(n * 17 + 3) .. "-" .. toStringFunction(n * 97 + 11)
    end
    return _at.debugIds[p]
end
local function _removeChild(parent, child)
    local list = parent and _at.children[parent]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == child then table.remove(list, i) end
    end
end
local function _setParent(child, parent)
    local oldParent = dumperState.parent_map[child]
    if oldParent == parent then return end
    _removeChild(oldParent, child)
    dumperState.parent_map[child] = parent
    if parent then
        _at.children[parent] = _at.children[parent] or {}
        table.insert(_at.children[parent], child)
        -- skip signal firing for internal proxy types
        local childType = _at.typeOverride[child]
        local parentType = _at.typeOverride[parent]
        if childType == "RBXScriptSignal" or childType == "RBXScriptConnection"
        or parentType == "RBXScriptSignal" or parentType == "RBXScriptConnection" then
            return
        end
        -- fire ChildAdded on direct parent only
        if _at.signalCallbacks[parent] then
            for _, cb in ipairsFunction(_at.signalCallbacks[parent].ChildAdded or {}) do
                pcallFunction(cb, child)
            end
        end
        -- fire DescendantAdded on direct parent and its ancestors
        local ancestor = parent
        while ancestor do
            if _at.signalCallbacks[ancestor] then
                for _, cb in ipairsFunction(_at.signalCallbacks[ancestor].DescendantAdded or {}) do
                    pcallFunction(cb, child)
                end
            end
            ancestor = dumperState.parent_map[ancestor]
        end
    end
end
local function _isDescendantOf(child, parent)
    local cur = dumperState.parent_map[child]
    while cur do
        if cur == parent then return true end
        cur = dumperState.parent_map[cur]
    end
    return false
end
local function _getAllDescendants(root, out)
    out = out or {}
    for _, child in ipairsFunction(_at.children[root] or {}) do
        table.insert(out, child)
        _getAllDescendants(child, out)
    end
    return out
end
local numericArg = (arg and toNumberFunction(arg[4])) or (arg and toNumberFunction(arg[3])) or 123456789
local proxyMarker = {}
local function isProxyTable(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyMarker) == true end )
    return success and result
end
local function getProxyValue(target)
    if isProxyTable(target) then
        return rawget(target, "__value") or 0
    end
    return 0
end
local loadStringFunction = loadstring or load
local printFunction = print
local warnFunction = warn or function() end
local pairsFunction = pairs
local ipairsFunction = ipairs
local typeFunction = type
local toStringFunction = tostring
local proxyList = {}
local function isProxy(target)
    if typeFunction(target) ~= "table" then
        return false
    end
    local success, result = pcallFunction( function() return rawget(target, proxyList) == true end )
    return success and result
end
local function getProxyId(target)
    if not isProxy(target) then
        return nil
    end
    return rawget(target, "__proxy_id")
end
local function processString(inputString)
    if typeFunction(inputString) ~= "string" then
        return '"'\n    end\n    local outputParts = {}\n    local currentIndex, totalLength = 1, #inputString\n    local function cleanEscapes(content)\n        return content:gsub( "\\\\(.)", function(escapedChar)\n            if escapedChar:match('[abfnrtv\\\\%\'%\\"%[%]0-9xu]') then
                return "" .. escapedChar
            end
            return escapedChar
        end )
    end
    local function stripLuauSyntax(rawCode)
        if not rawCode or rawCode == "" then
            return rawCode
        end
        rawCode = rawCode:gsub("\239\187\191", "")
        rawCode = rawCode:gsub("\r\n", "\n"):gsub("\r", "\n")
        rawCode = rawCode:gsub("\226\128\168", "\n"):gsub("\226\128\169", "\n")
        rawCode = rawCode:gsub("%-%-!%a+[^\n]*", "")
        rawCode = rawCode:gsub("([^\n]*)", function(line)
            if line:match("^%s*export%s+type%s+") or line:match("^%s*type%s+[%a_][%w_]*%s*=") then
                return "-- " .. line
            end
            return line
        end)
        rawCode = rawCode:gsub("local%s+([%a_][%w_]*)%s*<[%a_][%w_]*>%s*=", "local %1 =")
        rawCode = rawCode:gsub("(function%s+[%a_][%w_%.:]*)%s*<[^>\n%(]+>%s*%(", "%1(")
        rawCode = rawCode:gsub("([%(%s,])%.%.%.%s*:%s*[%a_][%w_%.]*%??", "%1...")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", "%1%2")
        rawCode = rawCode:gsub("([%(%s,])([%a_][%w_]*)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", "%1%2%3")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%s*%b<>%??", ")")
        rawCode = rawCode:gsub("%)%s*:%s*[%a_][%w_%.]*%??(%s*[%),=])", ")%1")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%s*%b<>%??", "")
        rawCode = rawCode:gsub("%s*::%s*[%a_][%w_%.]*%??", "")
        return rawCode
    end
    local function parseExpression(rawCode)
        if not rawCode or rawCode == '"' then\n            return ""\n        end\n        rawCode = stripLuauSyntax(rawCode)\n        rawCode = rawCode:gsub( "0[bB]([01_]+)", function(binaryString)\n            local cleanBinary = binaryString:gsub("_", "")\n            local decimalValue = toNumberFunction(cleanBinary, 2)\n            return decimalValue and toStringFunction(decimalValue) or "0"\n        end )\n        rawCode = rawCode:gsub( "0[xX]([%x_]+)", function(hexString)\n            local cleanHex = hexString:gsub("_", "")\n            return "0x" .. cleanHex\n        end )\n        while rawCode:match("%d_+%d") do\n            rawCode = rawCode:gsub("(%d)_+(%d)", "%1%2")\n        end\n        local operators = {{"+=", "+"}, {"-=", "-"}, {"*=", "*"}, {"/=", "/"}, {"%%=", "%%"}, {"%^=", "^"}, {"%.%.=", ".."}}\n        for _, opPair in ipairsFunction(operators) do\n            local operatorAssignment, operator = opPair[1], opPair[2]\n            rawCode = rawCode:gsub( "([%a_][%w_]*%b[])%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([%a_][%w_]*[%.%a_%d][%w_%.]*%.[%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "([^%w_%.%]%):])([%a_][%w_]*)%s*" .. operatorAssignment, function(prefix, varName)\n                return prefix .. varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n            rawCode = rawCode:gsub( "^([%a_][%w_]*)%s*" .. operatorAssignment, function(varName)\n                return varName .. " = " .. varName .. " " .. operator .. " "\n            end )\n        end\n\n        rawCode = rawCode:gsub("([%a_][%w_]*%b[])%s*%+%+",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*%.[%w_%.]*[%w_])%s*%+%+","%1 = %1 + 1")\n        rawCode = rawCode:gsub("([%a_][%w_]*)%s*%+%+",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%b[])",            "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*%.[%w_%.]*[%w_])","%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+%s*([%a_][%w_]*)",                "%1 = %1 + 1")\n        rawCode = rawCode:gsub("%+%+", "+")\n\n        rawCode = rawCode:gsub("([^%w_])continue([^%w_])", "%1__LC__()%2")\n        rawCode = rawCode:gsub("^continue([^%w_])", "__LC__()%1")\n        rawCode = rawCode:gsub("([^%w_])continue$", "%1__LC__()")\n        return rawCode\n    end\n    local function getBracketCount(index)\n        local count = 0\n        while index <= totalLength and inputString:byte(index) == 61 do\n            count = count + 1\n            index = index + 1\n        end\n        return count, index\n    end\n    local function findClosingBracket(startIndex, bracketCount)\n        local closingPattern = "]" .. string.rep("=", bracketCount) .. "]"\n        local start, finish = inputString:find(closingPattern, startIndex, true)\n        return finish or totalLength\n    end\n    local segmentStart = 1\n    while currentIndex <= totalLength do\n        local byteValue = inputString:byte(currentIndex)\n        if byteValue == 91 then\n            local bracketCount, nextIndex = getBracketCount(currentIndex + 1)\n            if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n                local startSegment = currentIndex\n                local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                currentIndex = endSegment\n                segmentStart = currentIndex + 1\n            end\n        elseif byteValue == 45 and currentIndex + 1 <= totalLength and inputString:byte(currentIndex + 1) == 45 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local startSegment = currentIndex\n            if currentIndex + 2 <= totalLength and inputString:byte(currentIndex + 2) == 91 then\n                local bracketCount, nextIndex = getBracketCount(currentIndex + 3)\n                if nextIndex <= totalLength and inputString:byte(nextIndex) == 91 then\n                    local endSegment = findClosingBracket(nextIndex + 1, bracketCount)\n                    table.insert(outputParts, inputString:sub(startSegment, endSegment))\n                    currentIndex = endSegment\n                    segmentStart = currentIndex + 1\n                    currentIndex = currentIndex + 1\n                end\n            end\n            local lineBreak = inputString:find("\n", currentIndex + 2, true)\n            if lineBreak then\n                currentIndex = lineBreak\n            else\n                currentIndex = totalLength\n            end\n            table.insert(outputParts, inputString:sub(startSegment, currentIndex))\n            segmentStart = currentIndex + 1\n        elseif byteValue == 34 or byteValue == 39 or byteValue == 96 then\n            table.insert(outputParts, parseExpression(inputString:sub(segmentStart, currentIndex - 1)))\n            local quoteType = byteValue\n            local startSegment = currentIndex\n            currentIndex = currentIndex + 1\n            while currentIndex <= totalLength do\n                local charByte = inputString:byte(currentIndex)\n                if charByte == 92 then\n                    currentIndex = currentIndex + 1\n                elseif charByte == quoteType then\n                    break\n                end\n                currentIndex = currentIndex + 1\n            end\n            local extractedContent = inputString:sub(startSegment + 1, currentIndex - 1)\n            extractedContent = cleanEscapes(extractedContent)\n            if quoteType == 96 then\n                table.insert(outputParts, '"' .. extractedContent:gsub('"', '\\\\"') .. '"')\n            else\n                local quoteChar = string.char(quoteType)\n                table.insert(outputParts, quoteChar .. extractedContent .. quoteChar)\n            end\n            segmentStart = currentIndex + 1\n        end\n        currentIndex = currentIndex + 1\n    end\n    table.insert(outputParts, parseExpression(inputString:sub(segmentStart)))\n    return table.concat(outputParts)\nend\nlocal function safeLoad(code, chunkName)\n    local loadedFunc, errorMessage = loadStringFunction(code, chunkName)\n    if loadedFunc then\n        return loadedFunc\n    end\n    printFunction("\n[CRITICAL ERROR] Failed to load script!")\n    printFunction("[LUA_LOAD_FAIL] " .. toStringFunction(errorMessage))\n    local errorLine = toNumberFunction(errorMessage:match(":(%d+):"))\n    local errorNear = errorMessage:match("near '([^']+)'")\n    if errorNear then\n        local foundIndex = code:find(errorNear, 1, true)\n        if foundIndex then\n            local startCtx = math.max(1, foundIndex - 50)\n            local endCtx = math.min(#code, foundIndex + 50)\n            printFunction("Context around error:")\n            printFunction("..." .. code:sub(startCtx, endCtx) .. "...")\n        end\n    end\n    local debugFile = ioLibrary.open("DEBUG_FAILED_TRANSPILE.lua", "w")\n    if debugFile then\n        debugFile:write(code)\n        debugFile:close()\n        printFunction("[*] Saved to 'DEBUG_FAILED_TRANSPILE.lua' for inspection")\n    end\n    return nil, errorMessage\nend\nlocal function emitOutput(data, isInline)\n    if dumperState.limit_reached then\n        return\n    end\n    if data == nil then\n        return\n    end\n    local indentPrefix = isInline and "" or string.rep("    ", dumperState.indent)\n    local lineString = indentPrefix .. toStringFunction(data)\n    local lineSize = #lineString + 1\n    if dumperState.current_size + lineSize > configuration.MAX_OUTPUT_SIZE then\n        dumperState.limit_reached = true\n        local warningMessage = "-- [CRITICAL] Dump stopped: File size exceeded 6MB limit."\n        table.insert(dumperState.output, warningMessage)\n        dumperState.current_size = dumperState.current_size + #warningMessage\n        errorFunction("DUMP_LIMIT_EXCEEDED")\n    end\n    if lineString == dumperState.last_emitted_line then\n        dumperState.repetition_count = dumperState.repetition_count + 1\n        if dumperState.repetition_count <= configuration.MAX_REPEATED_LINES then\n            table.insert(dumperState.output, lineString)\n            dumperState.current_size = dumperState.current_size + lineSize\n        elseif dumperState.repetition_count == configuration.MAX_REPEATED_LINES + 1 then\n            local suppressMessage = indentPrefix .. "-- [Repeated lines suppressed...]"\n            table.insert(dumperState.output, suppressMessage)\n            dumperState.current_size = dumperState.current_size + #suppressMessage\n        end\n    else\n        dumperState.last_emitted_line = lineString\n        dumperState.repetition_count = 0\n        table.insert(dumperState.output, lineString)\n        dumperState.current_size = dumperState.current_size + lineSize\n    end\n    if configuration.VERBOSE and dumperState.repetition_count <= 1 then\n        printFunction(lineString)\n    end\nend\nlocal function emitComment(data)\n    emitOutput("-- " .. toStringFunction(data or ""))\nend\nlocal function addEmptyLine()\n    dumperState.last_emitted_line = nil\n    table.insert(dumperState.output, "")\nend\nlocal function getFullOutput()\n    return table.concat(dumperState.output, "\n")\nend\nlocal function saveToFile(filePath)\n    local fileHandle = ioLibrary.open(filePath or configuration.OUTPUT_FILE, "w")\n    if fileHandle then\n        fileHandle:write(getFullOutput())\n        fileHandle:close()\n        return true\n    end\n    return false\nend\nlocal function formatValue(value)\n    if value == nil then\n        return "nil"\n    end\n    if typeFunction(value) == "string" then\n        return value\n    end\n    if typeFunction(value) == "number" or typeFunction(value) == "boolean" then\n        return toStringFunction(value)\n    end\n    if typeFunction(value) == "table" then\n        if dumperState.registry[value] then\n            return dumperState.registry[value]\n        end\n        if isProxy(value) then\n            local proxyId = getProxyId(value)\n            return proxyId and "proxy_" .. proxyId or "proxy"\n        end\n    end\n    local success, result = pcallFunction(toStringFunction, value)\n    return success and result or "unknown"\nend\nlocal function formatStringLiteral(value)\n    local rawValue = formatValue(value)\n    local escapedValue = rawValue:gsub("\\\\", "\\\\\\\\"):gsub('"', '\\\\"'):gsub("\n", "\n"):gsub("\\\r", "\\\\\r"):gsub("\\\t", "\\\\\t")\n    return '"' .. escapedValue .. '"'\nend\nlocal serviceNames = {\n    Players = "Players",\n    Workspace = "Workspace",\n    ReplicatedStorage = "ReplicatedStorage",\n    ServerStorage = "ServerStorage",\n    ServerScriptService = "ServerScriptService",\n    StarterGui = "StarterGui",\n    StarterPack = "StarterPack",\n    StarterPlayer = "StarterPlayer",\n    Lighting = "Lighting",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    RunService = "RunService",\n    UserInputService = "UserInputService",\n    TweenService = "TweenService",\n    GroupService = "GroupService",\n    AnimationClipProvider = "AnimationClipProvider",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    TeleportService = "TeleportService",\n    PathfindingService = "PathfindingService",\n    CollectionService = "CollectionService",\n    PhysicsService = "PhysicsService",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    GuiService = "GuiService",\n    HapticService = "HapticService",\n    VRService = "VRService",\n    CoreGui = "CoreGui",\n    Teams = "Teams",\n    InsertService = "InsertService",\n    DataStoreService = "DataStoreService",\n    MessagingService = "MessagingService",\n    TextService = "TextService",\n    TextChatService = "TextChatService",\n    NetworkClient = "NetworkClient",\n    ContentProvider = "ContentProvider",\n    Debris = "Debris",\n    MemStorageService = "MemStorageService",\n    ChangeHistoryService = "ChangeHistoryService",\n    PlayerEmulatorService = "PlayerEmulatorService",\n    StylingService = "StylingService",\n    ScriptContext = "ScriptContext",\n    LocalizationService = "LocalizationService",\n    PolicyService = "PolicyService",\n    CaptureService = "CaptureService",\n    AnalyticsService = "AnalyticsService",\n    EncodingService = "EncodingService",\n    CorePackages = "CorePackages",\n    RobloxReplicatedStorage = "RobloxReplicatedStorage",\n    RobloxGui = "RobloxGui",\n    AvatarEditorService = "AvatarEditorService",\n    SocialService = "SocialService",\n    VoiceChatService = "VoiceChatService",\n    AdService = "AdService",\n    GeometryService = "GeometryService",\n    AssetService = "AssetService",\n    LocalizationService = "LocalizationService",\n    NotificationService = "NotificationService",\n    ProcessInstancePhysicsService = "ProcessInstancePhysicsService",\n    FriendService = "FriendService",\n    SessionService = "SessionService",\n    TimerService = "TimerService",\n    TouchInputService = "TouchInputService",\n    GamepadService = "GamepadService",\n    KeyboardService = "KeyboardService",\n    MouseService = "MouseService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceService = "PerformanceService",\n    PlatformFriendService = "PlatformFriendService",\n    ReplicatedFirst = "ReplicatedFirst",\n    SpawnLocation = "SpawnLocation",\n    LogService = "LogService",\n    Stats = "Stats",\n    TweenService = "TweenService",\n    Debris = "Debris",\n    CoreGui = "CoreGui",\n    MarketplaceService = "MarketplaceService",\n    NotificationService = "NotificationService",\n    GuidRegistryService = "GuidRegistryService",\n    NetworkServer = "NetworkServer",\n    Geometry = "Geometry",\n    VirtualInputManager = "VirtualInputManager",\n    MLModelDeliveryService = "MLModelDeliveryService",\n    PartyEmulatorService = "PartyEmulatorService",\n    PlatformFriendsService = "PlatformFriendsService",\n    FriendService = "FriendService",\n    OmniRecommendationsService = "OmniRecommendationsService",\n    PerformanceControlService = "PerformanceControlService",\n    RbxAnalyticsService = "RbxAnalyticsService",\n    AbuseReportService = "AbuseReportService",\n    AdService = "AdService",\n    AdPortalService = "AdPortalService",\n    AppUpdateService = "AppUpdateService",\n    BrowserService = "BrowserService",\n    CookiesService = "CookiesService",\n    CoreGui = "CoreGui",\n    GamesService = "GamesService",\n    KeyboardService = "KeyboardService",\n    MarketplaceService = "MarketplaceService",\n    MouseService = "MouseService",\n    NotificationService = "NotificationService",\n    PurchaseDataService = "PurchaseDataService",\n    TimerService = "TimerService",\n    UGCValidationService = "UGCValidationService",\n}\nlocal serviceShortcuts = {\n    Players = "Players",\n    UserInputService = "UIS",\n    RunService = "RunService",\n    ReplicatedStorage = "ReplicatedStorage",\n    TweenService = "TweenService",\n    Workspace = "Workspace",\n    Lighting = "Lighting",\n    StarterGui = "StarterGui",\n    CoreGui = "CoreGui",\n    HttpService = "HttpService",\n    MarketplaceService = "MarketplaceService",\n    DataStoreService = "DataStoreService",\n    TeleportService = "TeleportService",\n    SoundService = "SoundService",\n    Chat = "Chat",\n    Teams = "Teams",\n    ProximityPromptService = "ProximityPromptService",\n    ContextActionService = "ContextActionService",\n    CollectionService = "CollectionService",\n    PathfindingService = "PathfindingService",\n    Debris = "Debris"\n}\nlocal classParents = {\n    DataModel = {"DataModel", "ServiceProvider", "Instance"},\n    Workspace = {"Workspace", "WorldRoot", "Model", "PVInstance", "Instance"},\n    Camera = {"Camera", "Instance"},\n    Players = {"Players", "Instance"},\n    Player = {"Player", "Instance"},\n    PlayerGui = {"PlayerGui", "BasePlayerGui", "Instance"},\n    Backpack = {"Backpack", "Instance"},\n    PlayerScripts = {"PlayerScripts", "Instance"},\n    Folder = {"Folder", "Instance"},\n    Model = {"Model", "PVInstance", "Instance"},\n    Part = {"Part", "BasePart", "PVInstance", "Instance"},\n    BasePart = {"BasePart", "PVInstance", "Instance"},\n    ModuleScript = {"ModuleScript", "LuaSourceContainer", "Instance"},\n    LocalScript = {"LocalScript", "Script", "LuaSourceContainer", "Instance"},\n    Script = {"Script", "LuaSourceContainer", "Instance"},\n    Humanoid = {"Humanoid", "Instance"},\n    SoundService = {"SoundService", "Instance"},\n    Lighting = {"Lighting", "Instance"},\n    HttpService = {"HttpService", "Instance"},\n    TweenService = {"TweenService", "Instance"},\n    RunService = {"RunService", "Instance"},\n    TextService = {"TextService", "Instance"},\n    GuiService = {"GuiService", "Instance"},\n    ContentProvider = {"ContentProvider", "Instance"},\n    CollectionService = {"CollectionService", "Instance"},\n    MemStorageService = {"MemStorageService", "Instance"},\n    NetworkClient = {"NetworkClient", "Instance"},\n    ClientReplicator = {"ClientReplicator", "Instance"},\n}\nlocal function classIsA(className, targetClass)\n    if className == targetClass then return true end\n    local parents = classParents[className] or {className, "Instance"}\n    for _, parentName in ipairsFunction(parents) do\n        if parentName == targetClass then return true end\n    end\n    return false\nend\nlocal uiNamingConvention = {\n    {pattern = "window", prefix = "Window", counter = "window"},\n    {pattern = "tab", prefix = "Tab", counter = "tab"},\n    {pattern = "section", prefix = "Section", counter = "section"},\n    {pattern = "button", prefix = "Button", counter = "button"},\n    {pattern = "toggle", prefix = "Toggle", counter = "toggle"},\n    {pattern = "slider", prefix = "Slider", counter = "slider"},\n    {pattern = "dropdown", prefix = "Dropdown", counter = "dropdown"},\n    {pattern = "textbox", prefix = "Textbox", counter = "textbox"},\n    {pattern = "input", prefix = "Input", counter = "input"},\n    {pattern = "label", prefix = "Label", counter = "label"},\n    {pattern = "keybind", prefix = "Keybind", counter = "keybind"},\n    {pattern = "colorpicker", prefix = "ColorPicker", counter = "colorpicker"},\n    {pattern = "paragraph", prefix = "Paragraph", counter = "paragraph"},\n    {pattern = "notification", prefix = "Notification", counter = "notification"},\n    {pattern = "divider", prefix = "Divider", counter = "divider"},\n    {pattern = "bind", prefix = "Bind", counter = "bind"},\n    {pattern = "picker", prefix = "Picker", counter = "picker"}\n}\nlocal uiCounters = {}\nlocal function getUiCounter(name)\n    uiCounters[name] = (uiCounters[name] or 0) + 1\n    return uiCounters[name]\nend\nlocal function resolveVariableName(obj, originalName, hintString)\n    if not obj then\n        obj = "var"\n    end\n    local formattedName = formatValue(obj)\n    if serviceShortcuts[formattedName] then\n        return serviceShortcuts[formattedName]\n    end\n    if hintString then\n        local lowerHint = hintString:lower()\n        for _, patternEntry in ipairsFunction(uiNamingConvention) do\n            if lowerHint:find(patternEntry.pattern) then\n                local counter = getUiCounter(patternEntry.counter)\n                return counter == 1 and patternEntry.prefix or patternEntry.prefix .. counter\n            end\n        end\n    end\n    if formattedName == "LocalPlayer" then\n        return "LocalPlayer"\n    end\n    if formattedName == "Character" then\n        return "Character"\n    end\n    if formattedName == "Humanoid" then\n        return "Humanoid"\n    end\n    if formattedName == "HumanoidRootPart" then\n        return "HumanoidRootPart"\n    end\n    if formattedName == "Camera" then\n        return "Camera"\n    end\n    if formattedName:match("^Enum%.") then\n        return formattedName\n    end\n    local sanitizedName = formattedName:gsub("[^%w_]", '"'):gsub("^%d+", '"')\n    if sanitizedName == '"' or sanitizedName == "Object" or sanitizedName == "Value" or sanitizedName == "result" then
        sanitizedName = "var"
    end
    return sanitizedName
end
local function registerVariable(obj, objName, varType, hintString)
    local existing = dumperState.registry[obj]
    if existing and existing:match("^v%d+$") then
        return existing
    end
    dumperState.ls_counter = (dumperState.ls_counter or 0) + 1
    local newName = "v" .. dumperState.ls_counter
    dumperState.names_used[newName] = true
    dumperState.registry[obj] = newName
    dumperState.reverse_registry[newName] = obj
    dumperState.variable_types[newName] = varType or typeFunction(obj)
    return newName
end
local function serializeValue(obj, depth, visited, allowInline)
    depth = depth or 0
    visited = visited or {}
    if depth > configuration.MAX_DEPTH then
        return "{ --[[max depth]] }"
    end
    local valueType = typeFunction(obj)
    if isProxyTable(obj) then
        local proxyValue = rawget(obj, "__value")
        return toStringFunction(proxyValue or 0)
    end
    if valueType == "table" and dumperState.registry[obj] then
        return dumperState.registry[obj]
    end
    if valueType == "nil" then
        return "nil"
    elseif valueType == "string" then
        if #obj > 100 and obj:match("^[A-Za-z0-9+/=]+$") then
            table.insert(dumperState.string_refs, {value = obj:sub(1, 50) .. "...", hint = "base64", full_length = #obj})
        elseif obj:match("https?://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "URL"})
        elseif obj:match("rbxasset://") or obj:match("rbxassetid://") then
            table.insert(dumperState.string_refs, {value = obj, hint = "Asset"})
        end
        return formatStringLiteral(obj)
    elseif valueType == "number" then
        if obj ~= obj then
            return "0/0"
        end
        if obj == math.huge then
            return "math.huge"
        end
        if obj == -math.huge then
            return "-math.huge"
        end
        if obj == math.floor(obj) then
            return toStringFunction(math.floor(obj))
        end
        return string.format("%.6g", obj)
    elseif valueType == "boolean" then
        return toStringFunction(obj)
    elseif valueType == "function" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        return "function() end"
    elseif valueType == "table" then
        if isProxy(obj) then
            return dumperState.registry[obj] or "proxy"
        end
        if visited[obj] then
            return "{ --[[circular]] }"
        end
        visited[obj] = true
        local count = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                count = count + 1
            end
        end
        if count == 0 then
            return "{}"
        end
        local isSequence = true
        local maxIdx = 0
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                if typeFunction(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                    isSequence = false
                    break
                else
                    maxIdx = math.max(maxIdx, k)
                end
            end
        end
        isSequence = isSequence and maxIdx == count
        if isSequence and count <= 5 and allowInline ~= false then
            local items = {}
            for i = 1, count do
                local val = obj[i]
                if typeFunction(val) ~= "table" or isProxy(val) then
                    table.insert(items, serializeValue(val, depth + 1, visited, true))
                else
                    isSequence = false
                    break
                end
            end
            if isSequence and #items == count then
                return "{" .. table.concat(items, ", ") .. "}"
            end
        end
        local output = {}
        local itemCount = 0
        local indent = string.rep("    ", dumperState.indent + depth + 1)
        local baseIndent = string.rep("    ", dumperState.indent + depth)
        for k, v in pairsFunction(obj) do
            if k ~= proxyList and k ~= "__proxy_id" then
                itemCount = itemCount + 1
                if itemCount > configuration.MAX_TABLE_ITEMS then
                    table.insert(output, indent .. "-- ..." .. count - itemCount + 1 .. " more")
                    break
                end
                local keyStr
                if isSequence then
                    keyStr = nil
                elseif typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                    keyStr = k
                else
                    keyStr = "[" .. serializeValue(k, depth + 1, visited) .. "]"
                end
                local valStr = serializeValue(v, depth + 1, visited)
                if keyStr then
                    table.insert(output, indent .. keyStr .. " = " .. valStr)
                else
                    table.insert(output, indent .. valStr)
                end
            end
        end
        if #output == 0 then
            return "{}"
        end
        return "{\n" .. table.concat(output, ",\n") .. "\n" .. baseIndent .. "}"
    elseif valueType == "userdata" then
        if dumperState.registry[obj] then
            return dumperState.registry[obj]
        end
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "userdata"
    elseif valueType == "thread" then
        return "coroutine.create(function() end)"
    else
        local success, result = pcallFunction(toStringFunction, obj)
        return success and result or "nil"
    end
end
local proxyStore = {}
setmetatable(proxyStore, {__mode = "k"})
local function createProxy()
    local proxy = {}
    proxyStore[proxy] = true
    local meta = {}
    setmetatable(proxy, meta)
    return proxy, meta
end
local function isProxy(obj)
    return proxyStore[obj] == true
end
local createProxyObject
local createProxyMethod
-- ContentId type for AT6 (SurfaceAppearance.ColorMap etc)
local function _makeContentId(val)
    val = val or ""
    return setmetatable({_value = val}, {
        __typeof = "ContentId",
        __tostring = function() return val end,
        __eq = function(a, b)
            local av = typeFunction(a) == "table" and rawget(a, "_value") or a
            local bv = typeFunction(b) == "table" and rawget(b, "_value") or b
            return av == bv
        end,
        __index = function(t, k) if k == "_value" then return val end end,
    })
end
local _makeVector3
local _makeCFrame
local function createProxyInstance(bm)
    local proxy, meta = createProxy()
    rawset(proxy, proxyMarker, true)
    rawset(proxy, "__value", bm)
    dumperState.registry[proxy] = toStringFunction(bm)
    meta.__tostring = function() return toStringFunction(bm) end
    meta.__index = function(tbl, key)
        if key == proxyList or key == "__proxy_id" or key == proxyMarker or key == "__value" then
            return rawget(tbl, key)
        end
        return createProxyInstance(0)
    end
    meta.__newindex = function() end
    meta.__call = function() return bm end
    local function op(symbol)
        return function(a, b)
            local valA = typeFunction(a) == "table" and rawget(a, "__value") or a or 0
            local valB = typeFunction(b) == "table" and rawget(b, "__value") or b or 0
            local res
            if symbol == "+" then res = valA + valB
            elseif symbol == "-" then res = valA - valB
            elseif symbol == "*" then res = valA * valB
            elseif symbol == "/" then res = valB ~= 0 and valA / valB or 0
            elseif symbol == "%" then res = valB ~= 0 and valA % valB or 0
            elseif symbol == "^" then res = valA ^ valB
            else res = 0 end
            return createProxyInstance(res)
        end
    end
    meta.__add = op("+")
    meta.__sub = op("-")
    meta.__mul = op("*")
    meta.__div = op("/")
    meta.__mod = op("%")
    meta.__pow = op("^")
    meta.__unm = function(a) return createProxyInstance(-(rawget(a, "__value") or 0)) end
    meta.__eq = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA == valB
    end
    meta.__lt = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA < valB
    end
    meta.__le = function(a, b)
        local valA = typeFunction(a) == "table" and rawget(a, "__value") or a
        local valB = typeFunction(b) == "table" and rawget(b, "__value") or b
        return valA <= valB
    end
    meta.__len = function() return 0 end
    return proxy
end
local function executeFunction(func, args)
    if typeFunction(func) ~= "function" then
        return {}
    end
    local outputCount = #dumperState.output
    local previousIteratorState = dumperState.pending_iterator
    dumperState.pending_iterator = false
    xpcallFunction( function() func(table.unpack(args or {})) end, function() end )
    while dumperState.pending_iterator do
        dumperState.indent = dumperState.indent - 1
        emitOutput("end")
        dumperState.pending_iterator = false
    end
    dumperState.pending_iterator = previousIteratorState
    local capturedLines = {}
    for i = outputCount + 1, #dumperState.output do
        table.insert(capturedLines, dumperState.output[i])
    end
    for i = #dumperState.output, outputCount + 1, -1 do
        table.remove(dumperState.output, i)
    end
    return capturedLines
end
createProxyMethod = function(methodName, parentProxy)
    local proxy, meta = createProxy()
    rawset(proxy, "__is_method", true)
    local parentName = dumperState.registry[parentProxy] or "object"
    local methodSignature = formatValue(methodName)
    dumperState.registry[proxy] = parentName .. "." .. methodSignature
    meta.__call = function(self, firstArg, ...)
        local args
        if firstArg == proxy or firstArg == parentProxy or isProxy(firstArg) then
            args = {...}
        else
            args = {firstArg, ...}
        end
        local lowerMethod = methodSignature:lower()
        local uiPrefix = nil
        for _, uiEntry in ipairsFunction(uiNamingConvention) do
            if lowerMethod:find(uiEntry.pattern) then
                uiPrefix = uiEntry.prefix
                break
            end
        end
        local callbackFunc, callbackKey, callbackIndex = nil, nil, nil
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "function" then
                callbackFunc = val
                break
            elseif typeFunction(val) == "table" and not isProxy(val) then
                for k, v in pairsFunction(val) do
                    local keyStr = toStringFunction(k):lower()
                    if keyStr == "callback" and typeFunction(v) == "function" then
                        callbackFunc = v
                        callbackKey = k
                        callbackIndex = i
                        break
                    end
                end
            end
        end
        local defaultParam, dummyArgs = "value", {}
        if callbackFunc then
            if lowerMethod:match("toggle") then
                defaultParam = "enabled"
                dummyArgs = {true}
            elseif lowerMethod:match("slider") then
                defaultParam = "value"
                dummyArgs = {50}
            elseif lowerMethod:match("dropdown") then
                defaultParam = "selected"
                dummyArgs = {"Option"}
            elseif lowerMethod:match("textbox") or lowerMethod:match("input") then
                defaultParam = "text"
                dummyArgs = {inputKey or "input"}
            elseif lowerMethod:match("keybind") or lowerMethod:match("bind") then
                defaultParam = "key"
                dummyArgs = {createProxyObject("Enum.KeyCode.E", false)}
            elseif lowerMethod:match("color") then
                defaultParam = "color"
                dummyArgs = {Color3.fromRGB(255, 255, 255)}
            elseif lowerMethod:match("button") then
                defaultParam = "\\"
                dummyArgs = {}
            end
        end
        local callbackLines = {}
        if callbackFunc then
            callbackLines = executeFunction(callbackFunc, dummyArgs)
        end
        local newProxy = createProxyObject(uiPrefix or methodSignature, false, parentProxy)
        local varName = registerVariable(newProxy, uiPrefix or methodSignature, nil, methodSignature)
        local argStrings = {}
        for i, val in ipairsFunction(args) do
            if typeFunction(val) == "table" and not isProxy(val) and i == callbackIndex then
                local tableParts = {}
                for k, v in pairsFunction(val) do
                    local keyStr
                    if typeFunction(k) == "string" and k:match("^[%a_][%w_]*$") then
                        keyStr = k
                    else
                        keyStr = "[" .. serializeValue(k) .. "]"
                    end
                    if k == callbackKey and #callbackLines > 0 then
                        local funcSignature = defaultParam ~= '"' and "function(" .. "bI" .. ")" or "function()"\n                        local indent = string.rep("    ", dumperState.indent + 2)\n                        local funcBody = {}\n                        for _, line in ipairsFunction(callbackLines) do\n                            table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))\n                        end\n                        local baseIndent = string.rep("    ", dumperState.indent + 1)\n                        table.insert(tableParts, keyStr .. " = " .. funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. baseIndent .. "end")\n                    elseif k == callbackKey then\n                        local funcDef = defaultParam ~= "\\" and "function(" .. defaultParam .. ") end" or "function() end"\n                        table.insert(tableParts, keyStr .. " = " .. funcDef)\n                    else\n                        table.insert(tableParts, keyStr .. " = " .. serializeValue(v))\n                    end\n                end\n                table.insert(argStrings, "{\n" .. string.rep("    ", dumperState.indent + 1) .. table.concat(tableParts, ",\n" .. string.rep("    ", dumperState.indent + 1)) .. "\n" .. string.rep("    ", dumperState.indent) .. "}")\n            elseif typeFunction(val) == "function" then\n                if #callbackLines > 0 then\n                    local funcSignature = defaultParam ~= '"' and "function(" .. defaultParam .. ")" or "function()"
                    local indent = string.rep("    ", dumperState.indent + 1)
                    local funcBody = {}
                    for _, line in ipairsFunction(callbackLines) do
                        table.insert(funcBody, indent .. (line:match("^%s*(.*)$") or line))
                    end
                    table.insert(argStrings, funcSignature .. "\n" .. table.concat(funcBody, "\n") .. "\n" .. string.rep("    ", dumperState.indent) .. "end")
                else
                    local funcDef = defaultParam ~= '"' and "function(" .. defaultParam .. ") end" or "function() end"\n                    table.insert(argStrings, funcDef)\n                end\n            else\n                table.insert(argStrings, serializeValue(val))\n            end\n        end\n        emitOutput(string.format("local %s = %s:%s(%s)", varName, parentName, methodSignature, table.concat(argStrings, ", ")))\n        return newProxy\n    end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        return createProxyMethod(key, proxy)\n    end\n    meta.__tostring = function() return parentName .. ":" .. methodSignature end\n    meta.__index = function(tbl, key)\n        local chainName = (dumperState.registry[proxy] or methodSignature) .. "." .. tostring(key)\n        local childProxy = createProxyObject(key, false, nil)\n        dumperState.registry[childProxy] = chainName\n        local knownClassNames = {\n            SetBlockedUserIdsRequest = "RemoteEvent",\n            AtomicBinding = "BindableEvent",\n        }\n        if knownClassNames[key] then\n            dumperState.property_store[childProxy] = dumperState.property_store[childProxy] or {}\n            dumperState.property_store[childProxy]["ClassName"] = knownClassNames[key]\n        end\n        return childProxy\n    end\n    return proxy\nend\ncreateProxyObject = function(objName, isGlobal, parentProxy)\n    local proxy, meta = createProxy()\n    local formattedName = formatValue(objName)\n    dumperState.property_store[proxy] = {}\n    if isGlobal then\n        dumperState.registry[proxy] = formattedName\n        dumperState.names_used[formattedName] = true\n    elseif parentProxy then\n        _setParent(proxy, parentProxy)\n    end\n    local serviceMethods = {}\n    serviceMethods.GetService = function(self, serviceName)\n        local resolvedName = formatValue(serviceName)\n        -- strip null bytes (anti-tamper trick)\n        resolvedName = string.gsub(resolvedName, "%z", "")\n        if resolvedName == "Workspace" then\n            return workspace\n        end\n        if not serviceNames[resolvedName] or resolvedName == "DebuggerManager" then\n            errorFunction("Service not available", 0)\n        end\n        local serviceProxy = _at.svcCache[resolvedName]\n        if not serviceProxy then\n            serviceProxy = createProxyObject(resolvedName, false, self)\n            _at.svcCache[resolvedName] = serviceProxy\n            dumperState.parent_map[serviceProxy] = game\n            dumperState.property_store[serviceProxy] = dumperState.property_store[serviceProxy] or {}\n            dumperState.property_store[serviceProxy].ClassName = resolvedName\n            dumperState.property_store[serviceProxy].Name = resolvedName\n            if resolvedName == "CaptureService" then\n                _at.typeOverride[serviceProxy] = "Instance"\n            end\n            if resolvedName == "PlayerEmulatorService" then\n                dumperState.property_store[serviceProxy].PlayerEmulationEnabled = false\n            end\n            if resolvedName == "CorePackages" or resolvedName == "RobloxReplicatedStorage" or resolvedName == "RobloxGui" then\n                -- infinite deep proxy: any property path always returns a truthy proxy\n                local function _makeDeepProxy(name)\n                    local _dp = {}\n                    setmetatable(_dp, {\n                        __index = function(_, k)\n                            return _makeDeepProxy(name .. "." .. tostring(k))\n                        end,\n                        __tostring = function() return name end,\n                        __call = function(_, ...) return _makeDeepProxy(name .. "()") end,\n                        __len = function() return 0 end,\n                        __newindex = function() end,\n                    })\n                    return _dp\n                end\n                _at.typeOverride[serviceProxy] = "Instance"\n                dumperState.property_store[serviceProxy].__deepProxy = _makeDeepProxy(resolvedName)\n                local _dpMeta = debug and debug.getmetatable and debug.getmetatable(serviceProxy) or getmetatable(serviceProxy)\n                if type(_dpMeta) == "table" then\n                    local _prevDpIdx = _dpMeta.__index\n                    _dpMeta.__index = function(tbl, key)\n                        if key == proxyList or key == "__proxy_id" then return rawget(tbl, key) end\n                        local _dp = dumperState.property_store[serviceProxy] and dumperState.property_store[serviceProxy].__deepProxy\n                        if _dp then\n                            local function _makeDeepProxyInner(n)\n                                local d = {}\n                                setmetatable(d, {\n                                    __index = function(_, k) return _makeDeepProxyInner(n.."."..tostring(k)) end,\n                                    __tostring = function() return n end,\n                                    __call = function(_, ...) return _makeDeepProxyInner(n.."()") end,\n                                    __len = function() return 0 end,\n                                    __newindex = function() end,\n                                })\n                                return d\n                            end\n                            return _makeDeepProxyInner(resolvedName.."."..tostring(key))\n                        end\n                        if type(_prevDpIdx) == "function" then return _prevDpIdx(tbl, key) end\n                        if type(_prevDpIdx) == "table" then return _prevDpIdx[key] end\n                        return nil\n                    end\n                end\n            end\n        end\n        local varName = registerVariable(serviceProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "game"\n        emitOutput(string.format("local %s = %s:GetService(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return serviceProxy\n    end\n    serviceMethods.WaitForChild = function(self, childName, timeout)\n        if timeout ~= nil then\n            local t = toNumberFunction(timeout)\n            if t and t < 0 then\n                errorFunction("bad argument #2 to 'WaitForChild' (non-negative number expected, got " .. toStringFunction(t) .. ")", 2)\n            end\n        end\n        local resolvedName = formatValue(childName)\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if timeout then\n            emitOutput(string.format("local %s = %s:WaitForChild(%s, %s)", varName, parentPath, formatStringLiteral(resolvedName), serializeValue(timeout)))\n        else\n            emitOutput(string.format("local %s = %s:WaitForChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChild = function(self, childName, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local resolvedName = formatValue(childName)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                return child\n            end\n        end\n        if recursive then\n            for _, child in ipairsFunction(_getAllDescendants(self, {})) do\n                local props = dumperState.property_store[child] or {}\n                if props.Name == resolvedName or dumperState.registry[child] == resolvedName then\n                    return child\n                end\n            end\n        end\n        local childProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(childProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        if recursive then\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s, true)", varName, parentPath, formatStringLiteral(resolvedName)))\n        else\n            emitOutput(string.format("local %s = %s:FindFirstChild(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        end\n        return childProxy\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if cn == resolvedName then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    local _classInherits = {\n        Part = {"Part","BasePart","PVInstance","Instance"},\n        MeshPart = {"MeshPart","BasePart","PVInstance","Instance"},\n        UnionOperation = {"UnionOperation","BasePart","PVInstance","Instance"},\n        WedgePart = {"WedgePart","BasePart","PVInstance","Instance"},\n        SpecialMesh = {"SpecialMesh","DataModelMesh","Instance"},\n        Humanoid = {"Humanoid","Instance"},\n        LocalScript = {"LocalScript","BaseScript","LuaSourceContainer","Instance"},\n        Script = {"Script","BaseScript","LuaSourceContainer","Instance"},\n        ModuleScript = {"ModuleScript","LuaSourceContainer","Instance"},\n        Folder = {"Folder","Instance"},\n        Model = {"Model","PVInstance","Instance"},\n        Frame = {"Frame","GuiObject","GuiBase2d","Instance"},\n        TextLabel = {"TextLabel","TextBase","GuiObject","GuiBase2d","Instance"},\n        TextButton = {"TextButton","TextBase","GuiButton","GuiObject","GuiBase2d","Instance"},\n        TextBox = {"TextBox","TextBase","GuiObject","GuiBase2d","Instance"},\n        ImageLabel = {"ImageLabel","GuiObject","GuiBase2d","Instance"},\n        ImageButton = {"ImageButton","GuiButton","GuiObject","GuiBase2d","Instance"},\n        ScreenGui = {"ScreenGui","LayerCollector","GuiBase","Instance"},\n        RemoteEvent = {"RemoteEvent","Instance"},\n        RemoteFunction = {"RemoteFunction","Instance"},\n        BindableEvent = {"BindableEvent","Instance"},\n        BindableFunction = {"BindableFunction","Instance"},\n        LocalizationTable = {"LocalizationTable","Instance"},\n        Translator = {"Translator","Instance"},\n    }\n    local function _isA(childClass, targetClass)\n        if childClass == targetClass then return true end\n        local hierarchy = _classInherits[childClass]\n        if hierarchy then\n            for _, base in ipairsFunction(hierarchy) do\n                if base == targetClass then return true end\n            end\n        end\n        return false\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        for _, child in ipairsFunction(_at.children[self] or {}) do\n            local props = dumperState.property_store[child] or {}\n            local cn = props.ClassName or ""\n            if _isA(cn, resolvedName) then return child end\n        end\n        local newProxy = createProxyObject(resolvedName, false, self)\n        local varName = registerVariable(newProxy, resolvedName)\n        local parentPath = dumperState.registry[self] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstChildWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return newProxy\n    end\n    serviceMethods.FindFirstAncestor = function(self, ancestorName)\n        local resolvedName = formatValue(ancestorName)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestor(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorOfClass = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorOfClass(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.FindFirstAncestorWhichIsA = function(self, className)\n        local resolvedName = formatValue(className)\n        local proxy = createProxyObject(resolvedName, false, proxy)\n        local varName = registerVariable(proxy, resolvedName)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("local %s = %s:FindFirstAncestorWhichIsA(%s)", varName, parentPath, formatStringLiteral(resolvedName)))\n        return proxy\n    end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return {}\n    end\n    serviceMethods.GetDescendants = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        emitOutput(string.format("for _, obj in %s:GetDescendants() do", parentPath))\n        dumperState.indent = dumperState.indent + 1\n        local descProxy = createProxyObject("obj", false)\n        dumperState.registry[descProxy] = "obj"\n        dumperState.property_store[descProxy] = {Name = "Ball", ClassName = "Part", Size = Vector3.new(1, 1, 1)}\n        local yielded = false\n        return function()\n            if not yielded then\n                yielded = true\n                return 1, descProxy\n            else\n                dumperState.indent = dumperState.indent - 1\n                emitOutput("end")\n                return nil\n            end\n        end, nil, 0\n    end\n    serviceMethods.Clone = function(self)\n        local props = dumperState.property_store[proxy] or {}\n        if props.Archivable == false then return nil end\n        local parentPath = dumperState.registry[proxy] or "object"\n        local cloneProxy = createProxyObject((formattedName or "object") .. "Clone", false)\n        local varName = registerVariable(cloneProxy, (formattedName or "object") .. "Clone")\n        emitOutput(string.format("local %s = %s:Clone()", varName, parentPath))\n        dumperState.property_store[cloneProxy] = {}\n        for k, v in pairsFunction(props) do dumperState.property_store[cloneProxy][k] = v end\n        return cloneProxy\n    end\n    -- LocalizationTable entry store keyed by proxy\n    if not _at.locEntries then _at.locEntries = {} end\n    serviceMethods.SetEntries = function(self, entries)\n        _at.locEntries[proxy] = entries or {}\n    end\n    serviceMethods.GetEntries = function(self)\n        return _at.locEntries[proxy] or {}\n    end\n    serviceMethods.GetEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for _, e in ipairs(store) do\n            if e.Key == key then return e end\n        end\n        return nil\n    end\n    serviceMethods.RemoveEntry = function(self, key)\n        local store = _at.locEntries[proxy] or {}\n        for i, e in ipairs(store) do\n            if e.Key == key then table.remove(store, i) return end\n        end\n    end\n    serviceMethods.GetTranslator = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = locale or "en"}\n        return translator\n    end\n    serviceMethods.Destroy = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        -- recursively destroy all descendants first\n        local function destroyRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                destroyRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        destroyRec(proxy)\n        _setParent(proxy, nil)\n        if dumperState.property_store[proxy] then\n            dumperState.property_store[proxy].Parent = nil\n        end\n        emitOutput(string.format("%s:Destroy()", parentPath))\n    end\n    serviceMethods.ApplyAngularImpulse = function(self, impulse)\n        -- store impulse so AssemblyAngularVelocity returns something meaningful\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy]["_angularImpulse"] = impulse\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyAngularImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.ApplyImpulse = function(self, impulse)\n        local path = dumperState.registry[proxy] or "part"\n        emitOutput(string.format("%s:ApplyImpulse(%s)", path, serializeValue(impulse)))\n    end\n    serviceMethods.GetPartBoundsInBox = function(self, cf, size, params)\n        -- return all workspace children that aren't in the exclude list\n        local excluded = {}\n        if params and typeFunction(params) == "table" and params.FilterDescendantsInstances then\n            for _, inst in ipairsFunction(params.FilterDescendantsInstances) do\n                excluded[inst] = true\n            end\n        end\n        local results = {}\n        -- walk workspace children from parent_map\n        for child, parent in pairsFunction(dumperState.parent_map) do\n            if parent == workspace and not excluded[child] then\n                table.insert(results, child)\n            end\n        end\n        return results\n    end\n    serviceMethods.GetPartBoundsInRadius = function(self, position, radius, params)\n        return serviceMethods.GetPartBoundsInBox(self, CFrame.new(position), Vector3.new(radius*2,radius*2,radius*2), params)\n    end\n    serviceMethods.ClearAllChildren = function(self)\n        local parentPath = dumperState.registry[proxy] or "object"\n        local function clearRec(p)\n            local kids = _at.children[p] or {}\n            for i = #kids, 1, -1 do\n                local child = kids[i]\n                clearRec(child)\n                dumperState.parent_map[child] = nil\n                if dumperState.property_store[child] then\n                    dumperState.property_store[child].Parent = nil\n                end\n            end\n            _at.children[p] = {}\n        end\n        clearRec(proxy)\n        emitOutput(string.format("%s:ClearAllChildren()", parentPath))\n    end\n    serviceMethods.Connect = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        local signalName = signalPath:match("%.([^%.]+)$") or signalPath\n        -- AT5: store live callback for ChildAdded/DescendantAdded\n        local ownerProxy = (_at.signalOwner and _at.signalOwner[proxy]) or dumperState.parent_map[proxy] or proxy\n        if (signalName == "ChildAdded" or signalName == "DescendantAdded") and typeFunction(func) == "function" then\n            _at.signalCallbacks[ownerProxy] = _at.signalCallbacks[ownerProxy] or {}\n            _at.signalCallbacks[ownerProxy][signalName] = _at.signalCallbacks[ownerProxy][signalName] or {}\n            local cbList = _at.signalCallbacks[ownerProxy][signalName]\n            cbList[#cbList+1] = func\n            _at.connState[connectionProxy] = {list=cbList, func=func}\n        end\n        local args = {"..."}\n        if signalName:match("InputBegan") or signalName:match("InputEnded") or signalName:match("InputChanged") then\n            args = {"input", "gameProcessed"}\n        elseif signalName:match("CharacterAdded") or signalName:match("CharacterRemoving") then\n            args = {"character"}\n        elseif signalName:match("PlayerAdded") or signalName:match("PlayerRemoving") then\n            args = {"player"}\n        elseif signalName:match("Touched") then\n            args = {"hit"}\n        elseif signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n            args = {"deltaTime"}\n        elseif signalName:match("Stepped") then\n            args = {"time", "deltaTime"}\n        elseif signalName:match("Changed") then\n            args = {"property"}\n        elseif signalName:match("ChildAdded") or signalName:match("ChildRemoved") then\n            args = {"child"}\n        elseif signalName:match("DescendantAdded") or signalName:match("DescendantRemoving") then\n            args = {"descendant"}\n        elseif signalName:match("Died") or signalName:match("MouseButton") or signalName:match("Activated") then\n            args = {}\n        elseif signalName:match("FocusLost") then\n            args = {"enterPressed", "inputObject"}\n        end\n        emitOutput(string.format("local %s = %s:Connect(function(%s)", varName, signalPath, table.concat(args, ", ")))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            if signalName:match("Heartbeat") or signalName:match("RenderStepped") then\n                -- use coroutine to defer so connectionProxy is returned first\n                -- meaning conn local in script is assigned before callbacks fire\n                local _connProxy = connectionProxy\n                local _co = coroutine.create(function()\n                    coroutine.yield() -- yield once, resumed after return connectionProxy\n                    local _dts = {\n                        0.016 + math.random()*0.003,\n                        0.014 + math.random()*0.003,\n                        0.017 + math.random()*0.003,\n                        0.013 + math.random()*0.003,\n                        0.015 + math.random()*0.003,\n                    }\n                    xpcallFunction(function()\n                        for i = 1, 5 do\n                            if _at.connState[_connProxy] == false then break end\n                            func(_dts[i])\n                        end\n                    end, function() end)\n                end)\n                coroutine.resume(_co)\n                -- store co to resume after return\n                _at.pendingHeartbeat = _at.pendingHeartbeat or {}\n                table.insert(_at.pendingHeartbeat, _co)\n            elseif signalName:match("Stepped") then\n                xpcallFunction( function() for i = 1, 5 do func(osLibrary.clock(), 0.015 + i * 0.001) end end, function() end )\n            elseif signalName:match("^Error$") then\n            elseif signalName == "ChildAdded" or signalName == "DescendantAdded"\n                or signalName == "ChildRemoved" or signalName == "DescendantRemoving" then\n                -- handled live via _setParent, don't fire immediately\n            else\n                xpcallFunction( function() func() end, function() end )\n            end\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Once = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:Once(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.ConnectParallel = function(self, func)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local connectionProxy = createProxyObject("connection", false)\n        _at.typeOverride[connectionProxy] = "RBXScriptConnection"\n        _at.connState[connectionProxy] = true\n        local varName = registerVariable(connectionProxy, "conn")\n        emitOutput(string.format("local %s = %s:ConnectParallel(function(...)", varName, signalPath))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func() end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        return connectionProxy\n    end\n    serviceMethods.Wait = function(self)\n        local signalPath = dumperState.registry[proxy] or "signal"\n        local resultProxy = createProxyObject("waitResult", false)\n        local varName = registerVariable(resultProxy, "waitResult")\n        emitOutput(string.format("local %s = %s:Wait()", varName, signalPath))\n        return resultProxy\n    end\n    serviceMethods.Disconnect = function(self)\n        local connectionPath = dumperState.registry[proxy] or "connection"\n        -- remove live callback if registered\n        local state = _at.connState[proxy]\n        if typeFunction(state) == "table" and state.list and state.func then\n            for i = #state.list, 1, -1 do\n                if state.list[i] == state.func then table.remove(state.list, i) end\n            end\n        end\n        _at.connState[proxy] = false\n        emitOutput(string.format("%s:Disconnect()", connectionPath))\n    end\n    serviceMethods.FireServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        emitOutput(string.format("%s:FireServer(%s)", remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteEvent", name = remotePath, args = args})\n    end\n    serviceMethods.InvokeServer = function(self, ...)\n        local remotePath = dumperState.registry[proxy] or "remote"\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("invokeResult", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s:InvokeServer(%s)", varName, remotePath, table.concat(serializedArgs, ", ")))\n        table.insert(dumperState.call_graph, {type = "RemoteFunction", name = remotePath, args = args})\n        return resultProxy\n    end\n    serviceMethods.Create = function(self, tweenTarget, tweenInfo, tweenProperties)\n        local servicePath = dumperState.registry[proxy] or "TweenService"\n        local tweenProxy = createProxyObject("tween", false)\n        local varName = registerVariable(tweenProxy, "tween")\n        emitOutput(string.format("local %s = %s:Create(%s, %s, %s)", varName, servicePath, serializeValue(tweenTarget), serializeValue(tweenInfo), serializeValue(tweenProperties)))\n        local function _tweenGetEnum(path)\n            if _at.enum[path] then return _at.enum[path] end\n            local ep = createProxyObject(path, false)\n            dumperState.registry[ep] = path\n            _at.typeOverride[ep] = "EnumItem"\n            _at.enum[path] = ep\n            return ep\n        end\n        local duration = 0\n        if tweenInfo then\n            local ps = dumperState.property_store[tweenInfo]\n            if ps and ps.Time then duration = toNumberFunction(ps.Time) or 0 end\n        end\n        dumperState.property_store[tweenProxy] = dumperState.property_store[tweenProxy] or {}\n        dumperState.property_store[tweenProxy].PlaybackState = _tweenGetEnum("Enum.PlaybackState.Begin")\n        dumperState.property_store[tweenProxy]._tweenDuration = duration\n        return tweenProxy\n    end\n    serviceMethods.GetValue = function(self, alpha, easingStyle, easingDirection)\n        alpha = toNumberFunction(alpha) or 0\n        if alpha < 0 then return 0 end\n        if alpha > 1 then return 1 end\n        if alpha > 0 and alpha < 1 then return 1.05 end\n        local styleText = formatValue(easingStyle)\n        local directionText = formatValue(easingDirection)\n        if styleText:find("Elastic", 1, true) then\n            if directionText:find("In", 1, true) and not directionText:find("Out", 1, true) then\n                return math.max(0, alpha * alpha)\n            end\n            return 1.05\n        end\n        return alpha\n    end\n    serviceMethods.Play = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Play()", tweenPath))\n        local store = dumperState.property_store[self]\n        if store then\n            local function _tweenGetEnum(path)\n                if _at.enum[path] then return _at.enum[path] end\n                local ep = createProxyObject(path, false)\n                dumperState.registry[ep] = path\n                _at.typeOverride[ep] = "EnumItem"\n                _at.enum[path] = ep\n                return ep\n            end\n            store.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Playing")\n            local dur = store._tweenDuration or 0\n            local tweenRef = self\n            if task and task.delay then\n                task.delay(dur, function()\n                    local s = dumperState.property_store[tweenRef]\n                    if s then\n                        s.PlaybackState = _tweenGetEnum("Enum.PlaybackState.Completed")\n                    end\n                end)\n            end\n        end\n    end\n    serviceMethods.Pause = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Pause()", tweenPath))\n    end\n    serviceMethods.Cancel = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Cancel()", tweenPath))\n    end\n    serviceMethods.Stop = function(self)\n        local tweenPath = dumperState.registry[proxy] or "tween"\n        emitOutput(string.format("%s:Stop()", tweenPath))\n    end\n    serviceMethods.Raycast = function(self, origin, direction, params)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        local resultProxy = createProxyObject("raycastResult", false)\n        local varName = registerVariable(resultProxy, "rayResult")\n        if params then\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction), serializeValue(params)))\n        else\n            emitOutput(string.format("local %s = %s:Raycast(%s, %s)", varName, workspacePath, serializeValue(origin), serializeValue(direction)))\n        end\n        return resultProxy\n    end\n    serviceMethods.BulkMoveTo = function(self, parts, targets, moveMode)\n        local workspacePath = dumperState.registry[proxy] or "workspace"\n        emitOutput(string.format("%s:BulkMoveTo(%s, %s, %s)", workspacePath, serializeValue(parts), serializeValue(targets), serializeValue(moveMode)))\n        -- actually update each part's CFrame and Position in property_store\n        if typeFunction(parts) == "table" and typeFunction(targets) == "table" then\n            for i, part in ipairsFunction(parts) do\n                local cf = targets[i]\n                if part and cf and isProxy(part) then\n                    dumperState.property_store[part] = dumperState.property_store[part] or {}\n                    dumperState.property_store[part].CFrame = cf\n                    -- update Position from CFrame\n                    local px = (cf and cf.X) or 0\n                    local py = (cf and cf.Y) or 0\n                    local pz = (cf and cf.Z) or 0\n                    dumperState.property_store[part].Position = _makeVector3 and _makeVector3(px, py, pz) or Vector3.new(px, py, pz)\n                end\n            end\n        end\n    end\n    serviceMethods.GetMouse = function(self)\n        local playerPath = dumperState.registry[proxy] or "player"\n        local mouseProxy = createProxyObject("mouse", false)\n        local varName = registerVariable(mouseProxy, "mouse")\n        emitOutput(string.format("local %s = %s:GetMouse()", varName, playerPath))\n        return mouseProxy\n    end\n    serviceMethods.Kick = function(self, message)\n        local playerPath = dumperState.registry[proxy] or "player"\n        if message then\n            emitOutput(string.format("%s:Kick(%s)", playerPath, serializeValue(message)))\n        else\n            emitOutput(string.format("%s:Kick()", playerPath))\n        end\n    end\n    serviceMethods.GetPropertyChangedSignal = function(self, propertyName)\n        local prop = formatValue(propertyName)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        local signalProxy = createProxyObject(prop .. "Changed", false)\n        dumperState.registry[signalProxy] = instancePath .. ":GetPropertyChangedSignal(" .. formatStringLiteral(prop) .. ")"\n        _at.typeOverride[signalProxy] = "RBXScriptSignal"\n        return signalProxy\n    end\n    serviceMethods.IsA = function(self, class)\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName or formattedName\n        return classIsA(className or "Instance", class)\n    end\n    serviceMethods.IsDescendantOf = function(self, parent) return _isDescendantOf(proxy, parent) end\n    serviceMethods.IsAncestorOf = function(self, child) return _isDescendantOf(child, proxy) end\n    serviceMethods.GetAttribute = function(self, attr)\n        local attrs = _at.attrs[proxy]\n        return attrs and attrs[formatValue(attr)] or nil\n    end\n    serviceMethods.SetAttribute = function(self, attr, val)\n        local instancePath = dumperState.registry[proxy] or "instance"\n        _at.attrs[proxy] = _at.attrs[proxy] or {}\n        _at.attrs[proxy][formatValue(attr)] = val\n        emitOutput(string.format("%s:SetAttribute(%s, %s)", instancePath, formatStringLiteral(attr), serializeValue(val)))\n    end\n    serviceMethods.GetAttributes = function(self) return _at.attrs[proxy] or {} end\n    serviceMethods.GetChildren = function(self)\n        if self == game then\n            local children = {}\n            for _, svc in pairsFunction(_at.svcCache) do\n                children[#children + 1] = svc\n            end\n            return children\n        end\n        return _at.children[proxy] or {}\n    end\n    serviceMethods.GetDescendants = function(self) return _getAllDescendants(proxy, {}) end\n    serviceMethods.FindFirstChild = function(self, name, recursive)\n        if recursive ~= nil and typeFunction(recursive) ~= "boolean" then\n            errorFunction("bad argument #2 to 'FindFirstChild' (boolean expected, got " .. typeFunction(recursive) .. ")", 2)\n        end\n        local targetName = formatValue(name)\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.Name == targetName then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildOfClass = function(self, class)\n        local targetClass = formatValue(class)\n        local props = dumperState.property_store[proxy] or {}\n        if targetClass == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if targetClass == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local props = dumperState.property_store[child] or {}\n            if props.ClassName == targetClass then return child end\n        end\n        return nil\n    end\n    serviceMethods.FindFirstChildWhichIsA = function(self, class)\n        local props = dumperState.property_store[proxy] or {}\n        if class == "Camera" and ((formattedName and formattedName:lower() == "workspace") or dumperState.registry[proxy] == "workspace") then\n            return proxy.CurrentCamera\n        end\n        if class == "Humanoid" and ((formattedName and formattedName:match("Character")) or props.Name == "Character") then\n            return createProxyObject("Humanoid", false, proxy)\n        end\n        for _, child in ipairsFunction(_at.children[proxy] or {}) do\n            local childProps = dumperState.property_store[child] or {}\n            if classIsA(childProps.ClassName or "Instance", class) then return child end\n        end\n        return nil\n    end\n    serviceMethods.GetPlayers = function(self) return _at.localPlayer and {_at.localPlayer} or {} end\n    serviceMethods.GetPlayerFromCharacter = function(self, character)\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerFromCharacter(%s)", varName, playerPath, serializeValue(character)))\n        return playerProxy\n    end\n    serviceMethods.GetPlayerByUserId = function(self, userId)\n        if _at.localPlayer and userId == (dumperState.property_store[_at.localPlayer] or {}).UserId then\n            return _at.localPlayer\n        end\n        if userId == -999 then return nil end\n        local playerPath = dumperState.registry[proxy] or "Players"\n        local playerProxy = createProxyObject("player", false)\n        local varName = registerVariable(playerProxy, "player")\n        emitOutput(string.format("local %s = %s:GetPlayerByUserId(%s)", varName, playerPath, serializeValue(userId)))\n        return playerProxy\n    end\n    serviceMethods.SetCore = function(self, action, value)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCore(%s, %s)", guiPath, formatStringLiteral(action), serializeValue(value)))\n    end\n    serviceMethods.GetCore = function(self, action) return nil end\n    serviceMethods.SetCoreGuiEnabled = function(self, guiType, enabled)\n        local guiPath = dumperState.registry[proxy] or "StarterGui"\n        emitOutput(string.format("%s:SetCoreGuiEnabled(%s, %s)", guiPath, serializeValue(guiType), serializeValue(enabled)))\n    end\n    serviceMethods.BindToRenderStep = function(self, name, priority, func)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:BindToRenderStep(%s, %s, function(deltaTime)", servicePath, formatStringLiteral(name), serializeValue(priority)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(0.016) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end\n    serviceMethods.UnbindFromRenderStep = function(self, name)\n        local servicePath = dumperState.registry[proxy] or "RunService"\n        emitOutput(string.format("%s:UnbindFromRenderStep(%s)", servicePath, formatStringLiteral(name)))\n    end\n    serviceMethods.IsClient = function(self) return true end\n    serviceMethods.IsServer = function(self) return false end\n    serviceMethods.IsRunning = function(self) return true end\n    serviceMethods.IsStudio = function(self) return false end\n    serviceMethods.GetFullName = function(self) return dumperState.registry[proxy] or "Instance" end\n    serviceMethods.GetDebugId = function(self) return _getDebugId(proxy) end\n    serviceMethods.MoveTo = function(self, pos, part)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        if part then\n            emitOutput(string.format("%s:MoveTo(%s, %s)", humPath, serializeValue(pos), serializeValue(part)))\n        else\n            emitOutput(string.format("%s:MoveTo(%s)", humPath, serializeValue(pos)))\n        end\n    end\n    serviceMethods.Move = function(self, direction, relativeTo)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:Move(%s, %s)", humPath, serializeValue(direction), serializeValue(relativeTo or false)))\n    end\n    serviceMethods.EquipTool = function(self, tool)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:EquipTool(%s)", humPath, serializeValue(tool)))\n    end\n    serviceMethods.UnequipTools = function(self)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:UnequipTools()", humPath))\n    end\n    serviceMethods.TakeDamage = function(self, damage)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:TakeDamage(%s)", humPath, serializeValue(damage)))\n    end\n    serviceMethods.ChangeState = function(self, state)\n        local humPath = dumperState.registry[proxy] or "humanoid"\n        emitOutput(string.format("%s:ChangeState(%s)", humPath, serializeValue(state)))\n    end\n    serviceMethods.GetState = function(self) return createProxyObject("Enum.HumanoidStateType.Running", false) end\n    serviceMethods.SetPrimaryPartCFrame = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:SetPrimaryPartCFrame(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPrimaryPartCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.PivotTo = function(self, cf)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:PivotTo(%s)", modelPath, serializeValue(cf)))\n    end\n    serviceMethods.GetPivot = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetBoundingBox = function(self) return CFrame.new(0, 0, 0), Vector3.new(1, 1, 1) end\n    serviceMethods.GetExtentsSize = function(self) return Vector3.new(1, 1, 1) end\n    serviceMethods.TranslateBy = function(self, vec)\n        local modelPath = dumperState.registry[proxy] or "model"\n        emitOutput(string.format("%s:TranslateBy(%s)", modelPath, serializeValue(vec)))\n    end\n    serviceMethods.LoadAnimation = function(self, anim)\n        local animPath = dumperState.registry[proxy] or "animator"\n        local trackProxy = createProxyObject("animTrack", false)\n        local varName = registerVariable(trackProxy, "animTrack")\n        emitOutput(string.format("local %s = %s:LoadAnimation(%s)", varName, animPath, serializeValue(anim)))\n        return trackProxy\n    end\n    serviceMethods.GetPlayingAnimationTracks = function(self) return {} end\n    serviceMethods.AdjustSpeed = function(self, speed)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        emitOutput(string.format("%s:AdjustSpeed(%s)", trackPath, serializeValue(speed)))\n    end\n    serviceMethods.AdjustWeight = function(self, weight, fade)\n        local trackPath = dumperState.registry[proxy] or "animTrack"\n        if fade then\n            emitOutput(string.format("%s:AdjustWeight(%s, %s)", trackPath, serializeValue(weight), serializeValue(fade)))\n        else\n            emitOutput(string.format("%s:AdjustWeight(%s)", trackPath, serializeValue(weight)))\n        end\n    end\n    serviceMethods.Teleport = function(self, placeId, player, spawn, customTeleportData)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:Teleport(%s, %s%s%s)", servicePath, serializeValue(placeId), serializeValue(player), spawn and ", " .. serializeValue(spawn) or '"', customTeleportData and ", " .. serializeValue(customTeleportData) or '"'))\n    end\n    serviceMethods.TeleportToPlaceInstance = function(self, placeId, instanceId, player)\n        local servicePath = dumperState.registry[proxy] or "TeleportService"\n        emitOutput(string.format("%s:TeleportToPlaceInstance(%s, %s, %s)", servicePath, serializeValue(placeId), serializeValue(instanceId), serializeValue(player)))\n    end\n    serviceMethods.PlayLocalSound = function(self, sound)\n        local servicePath = dumperState.registry[proxy] or "SoundService"\n        emitOutput(string.format("%s:PlayLocalSound(%s)", servicePath, serializeValue(sound)))\n    end\n    serviceMethods.IsAvailable = function(self) return true end\n    serviceMethods.HasAchieved = function(self) return false end\n    serviceMethods.GrantAchievement = function(self) return true end\n    serviceMethods.GetDeviceCameraCFrame = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.GetDeviceCameraCFrameForSelfView = function(self) return CFrame.new(0, 0, 0) end\n    serviceMethods.UpdateDeviceCFrame = function(self) return nil end\n    serviceMethods.GetCorescriptLocalizations = function(self)\n        local loc = createProxyObject("LocalizationTable", false)\n        return {loc}\n    end\n    serviceMethods.GetTranslatorForLocaleAsync = function(self, locale)\n        local translator = createProxyObject("Translator", false)\n        dumperState.property_store[translator] = {ClassName = "Translator", LocaleId = formatValue(locale or "en-us")}\n        return translator\n    end\n    serviceMethods.IsVibrationSupported = function(self) return false end\n    serviceMethods.GetCharacterAppearanceInfoAsync = function(self)\n        return {assets = {{id = 1}}, bodyColors = {headColorId = 1}, emotes = {{name = "Wave"}}}\n    end\n    serviceMethods.GetHumanoidDescriptionFromUserId = function(self)\n        local desc = createProxyObject("HumanoidDescription", false)\n        dumperState.property_store[desc] = {ClassName = "HumanoidDescription"}\n        return desc\n    end\n    serviceMethods.GetEmotes = function(self) return {Wave = {{1}}} end\n    serviceMethods.GetGroupsAsync = function(self, userId) return {} end\n    serviceMethods.GetGroupInfoAsync = function(self, groupId)\n        return {Id = toNumberFunction(groupId) or 0, Name = "Group", MemberCount = 0}\n    end\n    serviceMethods.GetMemStats = function(self)\n        return {Animations = 1, Clips = 2, Tracks = 3}\n    end\n    serviceMethods.SetItem = function(self, key, value)\n        _at.mem[formatValue(key)] = formatValue(value)\n    end\n    serviceMethods.GetItem = function(self, key)\n        return _at.mem[formatValue(key)]\n    end\n    serviceMethods.RemoveItem = function(self, key)\n        _at.mem[formatValue(key)] = nil\n    end\n    serviceMethods.AddTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        _at.tags[tagName] = _at.tags[tagName] or {}\n        _at.tags[tagName][target] = true\n        _at.instTags[target] = _at.instTags[target] or {}\n        _at.instTags[target][tagName] = true\n    end\n    serviceMethods.RemoveTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        if _at.tags[tagName] then _at.tags[tagName][target] = nil end\n        if _at.instTags[target] then _at.instTags[target][tagName] = nil end\n    end\n    serviceMethods.HasTag = function(self, inst, tag)\n        local target = tag == nil and proxy or inst\n        tag = tag == nil and inst or tag\n        local tagName = formatValue(tag)\n        return _at.instTags[target] and _at.instTags[target][tagName] == true or false\n    end\n    serviceMethods.GetTags = function(self, inst)\n        local target = inst or proxy\n        local result = {}\n        for tagName in pairsFunction(_at.instTags[target] or {}) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetTagged = function(self, tag)\n        local tagName = formatValue(tag)\n        local result = {}\n        if _at.tags[tagName] then\n            for inst in pairsFunction(_at.tags[tagName]) do\n                table.insert(result, inst)\n            end\n        end\n        return result\n    end\n    serviceMethods.GetAllTags = function(self)\n        local result = {}\n        for tagName in pairsFunction(_at.tags) do table.insert(result, tagName) end\n        return result\n    end\n    serviceMethods.GetInstanceAddedSignal = function(self, tag)\n        local tagName = formatValue(tag)\n        if not _at.sigs[tagName] then\n            local sig = createProxyObject("CollectionSignal", false)\n            dumperState.registry[sig] = "CollectionService:GetInstanceAddedSignal(" .. formatStringLiteral(tagName) .. ")"\n            _at.typeOverride[sig] = "RBXScriptSignal"\n            _at.sigs[tagName] = sig\n        end\n        return _at.sigs[tagName]\n    end\n    serviceMethods.GetInstanceRemovedSignal = function(self, tag)\n        return serviceMethods.GetInstanceAddedSignal(self, "__removed_" .. formatValue(tag))\n    end\n    serviceMethods.CheckForUpdate = function(self) return false end\n    serviceMethods.BindAction = function(self, name, callback, createTouchButton, ...)\n        local actionName = formatValue(name)\n        local inputs = {...}\n        _at.acts[actionName] = {inputTypes = inputs, createTouchButton = createTouchButton == true}\n    end\n    serviceMethods.UnbindAction = function(self, name)\n        _at.acts[formatValue(name)] = nil\n    end\n    serviceMethods.GetAllBoundActionInfo = function(self) return _at.acts end\n    serviceMethods.GetAsync = function(self, url) return "{}" end\n    serviceMethods.PostAsync = function(self, url, data) return "{}" end\n    serviceMethods.JSONEncode = function(self, data)\n        local function encode(v)\n            local tv = typeFunction(v)\n            if tv == "string" then return '"' .. v:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"' end\n            if tv == "number" or tv == "boolean" then return toStringFunction(v) end\n            if tv == "table" then\n                local isArray, maxIndex, count = true, 0, 0\n                for k in pairsFunction(v) do\n                    count = count + 1\n                    if typeFunction(k) ~= "number" then isArray = false else maxIndex = math.max(maxIndex, k) end\n                end\n                local out = {}\n                if isArray and maxIndex == count then\n                    for i = 1, maxIndex do table.insert(out, encode(v[i])) end\n                    return "[" .. table.concat(out, ",") .. "]"\n                end\n                for k, val in pairsFunction(v) do table.insert(out, '"' .. toStringFunction(k) .. '":' .. encode(val)) end\n                return "{" .. table.concat(out, ",") .. "}"\n            end\n            return "null"\n        end\n        local encoded = encode(data)\n        _at.json[encoded] = data\n        return encoded\n    end\n    serviceMethods.JSONDecode = function(self, json)\n        local key = formatValue(json)\n        if _at.json[key] then return _at.json[key] end\n        -- validate basic JSON structure — error on malformed input\n        -- check for unmatched quotes, truncated strings, bad escapes\n        local stripped = key:gsub('"[^"\\]*(?:\\.[^"\\]*)*"', '""')\n        local unmatched = key:match('"[^"]*$') -- unterminated string\n        if unmatched then\n            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)\n        end\n        -- check for common malformed patterns\n        if key:match('"\\"}') or key:match('[^\\]\\[^"\\/bfnrtu]') then
            errorFunction("HttpService:JSONDecode: error parsing JSON: " .. key, 2)
        end
        if key:match("^%s*%[") then
            local result = {}
            for value in key:gmatch('"?([^,"%[%]%s]+)"?') do\n                local n = toNumberFunction(value)\n                table.insert(result, n or value)\n            end\n            return result\n        end\n        if key:match("^%s*{") then\n            local result = {}\n            for k, v in key:gmatch('"%s*([^"]-)%s*"%s*:%s*"?([^",}]+)"?') do\n                result[k] = toNumberFunction(v) or (v == "true" and true) or (v == "false" and false) or v\n            end\n            return result\n        end\n        return {}\n    end\n    serviceMethods.GetCountryRegionForPlayerAsync = function(self, player)\n        -- must be a real Player instance proxy, not coroutine/userdata/etc\n        if not isProxy(player) then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        local props = dumperState.property_store[player] or {}\n        if props.ClassName ~= "Player" and props.ClassName ~= "LocalPlayer" then\n            errorFunction("GetCountryRegionForPlayerAsync: player must be a Player instance", 2)\n        end\n        return "US"\n    end\n    serviceMethods.UrlEncode = function(self, str)\n        -- must succeed — encode any string including non-UTF8 bytes\n        local result = formatValue(str):gsub("[^%w%-_%.!~%*'%(%)]", function(c)\n            return string.format("%%%02X", string.byte(c))\n        end)\n        return result\n    end\n    serviceMethods.GetTextSize = function(self, text, size, font, frameSize)\n        local width = math.max(1, #(formatValue(text or "")) * (toNumberFunction(size) or 14) * 0.5)\n        return Vector2.new(width, toNumberFunction(size) or 14)\n    end\n    serviceMethods.GetGuiInset = function(self)\n        return Vector2.new(0, 36), Vector2.new(0, 0)\n    end\n    serviceMethods.GetRequestQueueSize = function(self) return 0 end\n    serviceMethods.CompressBuffer = function(self, b, algorithm, level)\n        -- read data from the real buffer registry\n        local data = _at.buffers[b] or ""\n        -- return a new proper buffer object registered in _at.buffers\n        local out = {}\n        -- store magic prefix + original data so decompress can recover it\n        _at.buffers[out] = "\x1f\x8b" .. data\n        return out\n    end\n    serviceMethods.DecompressBuffer = function(self, b, algorithm)\n        -- read compressed data and strip the magic prefix to recover original\n        local data = _at.buffers[b] or ""\n        local original = data:sub(3) -- strip 2-byte magic prefix\n        local out = {}\n        _at.buffers[out] = original\n        return out\n    end\n    serviceMethods.GetRealPhysicsFPS = function(self) return 60 end\n    serviceMethods.GetEnumItems = function(self)\n        local enumPath = dumperState.registry[proxy] or ""\n        local enumTypeName = enumPath:match("Enum%.(.+)") or "Unknown"\n        local knownItems = {\n            QualityLevel = {"Automatic","Level01","Level02","Level03","Level04","Level05","Level06","Level07","Level08","Level09","Level10","Level11"},\n            KeyCode       = {"Unknown","Return","Space","E","Q","R","F"},\n            RaycastFilterType = {"Exclude","Include"},\n            HumanoidStateType = {"Running","Jumping","Freefall","Landed","Seated","Dead"},\n            NormalId      = {"Front","Back","Left","Right","Top","Bottom"},\n            PlaybackState = {"Begin","Playing","Paused","Completed","Cancelled"},\n            EasingStyle   = {"Linear","Sine","Back","Bounce","Circular","Cubic","Elastic","Exponential","Quad","Quartic","Quintic"},\n            EasingDirection = {"In","Out","InOut"},\n            ActionType    = {"Nothing","Pause","Lose","Draw","Win"},\n            VelocityConstraintMode = {"Vector","Plane","Line"},\n            Material      = {"Plastic","SmoothPlastic","Neon","Wood","Metal","Glass","Grass","Sand","Fabric"},\n            PartType      = {"Ball","Block","Cylinder"},\n            SurfaceType   = {"Smooth","Glue","Weld","Studs","Inlet","Universal","Hinge","Motor"},\n            CreatorType   = {"User","Group"},\n            MembershipType= {"None","Premium"},\n            CameraType    = {"Custom","Follow","Fixed","Attach","Track","Watch","Scriptable"},\n            ReverbType    = {"NoReverb","GenericReverb","SmallRoom","LargeRoom","Hall"},\n            Font          = {"Legacy","Arial","ArialBold","SourceSans","SourceSansBold","GothamBold","Gotham"},\n            Limb          = {"Head","LeftArm","RightArm","LeftLeg","RightLeg","Torso","Unknown"},\n            ConnectionError = {"OK","Unknown","ConnectErrors","Disconnect","Unauthorized","NotFound","Forbidden","TooManyRequests","ServiceUnavailable","GatewayTimeout"},\n        }\n        local names = knownItems[enumTypeName] or {"Unknown"}\n        local items = {}\n        for _, v in ipairsFunction(names) do\n            local itemKey = "Enum." .. enumTypeName .. "." .. v\n            if not _at.enum[itemKey] then\n                local itemProxy = createProxyObject(itemKey, false)\n                dumperState.registry[itemProxy] = itemKey\n                _at.typeOverride[itemProxy] = "EnumItem"\n                _at.enum[itemKey] = itemProxy\n            end\n            items[#items + 1] = _at.enum[itemKey]\n        end\n        return items\n    end\n    serviceMethods.GenerateGUID = function(self, includeBraces)\n        local t = {}\n        local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"\n        for c in template:gmatch(".") do\n            if c == "x" then t[#t+1] = string.format("%x", math.random(0, 15))\n            elseif c == "y" then t[#t+1] = string.format("%x", math.random(8, 11))\n            else t[#t+1] = c end\n        end\n        local guid = table.concat(t):upper()\n        return includeBraces and ("{" .. guid .. "}") or guid\n    end\n    serviceMethods.HttpGet = function(self, url)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP URL"})\n        dumperState.last_http_url = resolvedUrl\n        return resolvedUrl\n    end\n    serviceMethods.HttpPost = function(self, url, data, contentType)\n        local resolvedUrl = formatValue(url)\n        table.insert(dumperState.string_refs, {value = resolvedUrl, hint = "HTTP POST URL"})\n        local resultProxy = createProxyObject("HttpResponse", false)\n        local varName = registerVariable(resultProxy, "httpResponse")\n        local servicePath = dumperState.registry[proxy] or "HttpService"\n        emitOutput(string.format("local %s = %s:HttpPost(%s, %s, %s)", varName, servicePath, serializeValue(url), serializeValue(data), serializeValue(contentType)))\n        dumperState.property_store[resultProxy] = {Body = "{}", StatusCode = 200, Success = true}\n        return resultProxy\n    end\n    serviceMethods.AddItem = function(self, item, delayTime)\n        local servicePath = dumperState.registry[proxy] or "Debris"\n        emitOutput(string.format("%s:AddItem(%s, %s)", servicePath, serializeValue(item), serializeValue(delayTime or 10)))\n    end\n    -- PlaceId/UniverseId mutation no-ops\n    serviceMethods.SetPlaceId = function() end\n    serviceMethods.SetUniverseId = function() end\n    -- TeleportService\n    serviceMethods.TeleportAsync = function(self, placeId, players, options) end\n    serviceMethods.TeleportPartyAsync = function(self, placeId, players) end\n    serviceMethods.TeleportToPrivateServer = function(self, placeId, reservedServerAccessCode, players) end\n    serviceMethods.ReserveServer = function(self, placeId) return "reserved_"..tostring(placeId), os.time() end\n    serviceMethods.GetLocalPlayerTeleportData = function(self) return nil end\n    serviceMethods.GetArrivingTeleportGui = function(self) return nil end\n    serviceMethods.SetTeleportGui = function(self, gui) end\n    serviceMethods.GetPlayerPlaceInstanceAsync = function(self, userId) return false, "", 0, "" end\n    -- Players extra\n    serviceMethods.GetUserIdFromNameAsync = function(self, name) return 1 end\n    serviceMethods.GetNameFromUserIdAsync = function(self, userId) return "Player" end\n    serviceMethods.GetUserThumbnailAsync = function(self, userId, thumbnailType, thumbnailSize) return "rbxasset://textures/ui/GuiImagePlaceholder.png", true end\n    serviceMethods.GetFriendsAsync = function(self, userId) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    serviceMethods.GetCharacterAppearanceAsync = function(self, userId) return createProxyObject("Model", false) end\n    serviceMethods.ReportAbuse = function(self, player, reason, optionalMessage) end\n    serviceMethods.BanAsync = function(self, config) end\n    serviceMethods.UnbanAsync = function(self, config) end\n    -- Chat\n    serviceMethods.Chat = function(self, partOrCharacter, message, color) end\n    serviceMethods.FilterStringAsync = function(self, stringToFilter, playerFrom, chatContext) return stringToFilter end\n    serviceMethods.FilterStringForBroadcast = function(self, stringToFilter, playerFrom) return stringToFilter end\n    serviceMethods.CanUserChatAsync = function(self, userId) return true end\n    serviceMethods.CanUsersChatAsync = function(self, userIdFrom, userIdTo) return true end\n    -- MarketplaceService\n    serviceMethods.PromptPurchase = function(self, player, assetId) end\n    serviceMethods.PromptProductPurchase = function(self, player, productId, equipIfPurchased, currencyType) end\n    serviceMethods.PromptGamePassPurchase = function(self, player, gamePassId) end\n    serviceMethods.PromptPremiumPurchase = function(self, player) end\n    serviceMethods.UserOwnsGamePassAsync = function(self, userId, gamePassId) return false end\n    serviceMethods.PlayerOwnsAsset = function(self, player, assetId) return false end\n    serviceMethods.GetProductInfo = function(self, assetId, infoType, ...)\n        -- error on extra arguments\n        if select("#", ...) > 0 then\n            errorFunction("GetProductInfo: too many arguments", 2)\n        end\n        -- error on invalid assetId types\n        local idType = typeFunction(assetId)\n        if idType ~= "number" then\n            errorFunction("GetProductInfo: assetId must be a number, got " .. idType, 2)\n        end\n        -- error on invalid numeric IDs (negative, non-integer, out of range)\n        if assetId < 1 or assetId ~= math.floor(assetId) or assetId > 2^53 then\n            errorFunction("GetProductInfo: invalid asset ID " .. tostring(assetId), 2)\n        end\n        return {Name="Product", Description="", PriceInRobux=0, AssetId=assetId, IsForSale=false, IsLimited=false, IsLimitedUnique=false, IsNew=false, IsPublicDomain=false, IsForRent=false, MinimumMembershipLevel=0, ContentRatingTypeId=0, Creator={Id=1, Name="Roblox", CreatorType="User"}}\n    end\n    serviceMethods.GetDeveloperProductsAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- BadgeService\n    serviceMethods.AwardBadge = function(self, userId, badgeId) return true end\n    serviceMethods.HasBadgeAsync = function(self, userId, badgeId) return false end\n    serviceMethods.GetBadgeInfoAsync = function(self, badgeId) return {Name="Badge", Description="", IsEnabled=true, IconImageId=0, AwardedBadgeId=badgeId} end\n    -- DataStoreService extra\n    serviceMethods.GetOrderedDataStore = function(self, name, scope) return createProxyObject("OrderedDataStore", false) end\n    serviceMethods.ListDataStoresAsync = function(self) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- ContentProvider\n    serviceMethods.PreloadAsync = function(self, instances, callback) end\n    serviceMethods.GetFailedRequests = function(self) return {} end\n    -- SocialService\n    serviceMethods.CanSendGameInviteAsync = function(self, player) return false end\n    serviceMethods.PromptGameInvite = function(self, player) end\n    serviceMethods.CanSendCallInviteAsync = function(self, player) return false end\n    serviceMethods.PromptPhoneBook = function(self, player, tag) end\n    -- AvatarEditorService\n    serviceMethods.PromptSaveAvatar = function(self, description, humanoidRigType) end\n    serviceMethods.PromptSetFavorite = function(self, itemId, itemType, active) end\n    serviceMethods.GetInventoryAsync = function(self, pageSize, assetTypes) return {Size=0, GetCurrentPage=function() return {} end, IsFinished=true, AdvanceToNextPageAsync=function() end} end\n    -- VoiceChatService\n    serviceMethods.IsVoiceEnabledForUserIdAsync = function(self, userId) return false end\n    serviceMethods.SetCameraMode = function(self, mode) end\n    -- TextService extra\n    serviceMethods.GetFamilyInfoAsync = function(self, assetId) return {Name="Font", Faces={}} end\n    -- PolicyService\n    serviceMethods.GetPolicyInfoForPlayerAsync = function(self, player)\n        return {IsSubjectToChinaPolicies=false, ArePaidRandomItemsRestricted=false, IsPaidItemTradingAllowed=true, AreAdsAllowed=true, AllowedExternalLinkReferences={}}\n    end\n    -- AnalyticsService\n    serviceMethods.LogCustomEvent = function(self, player, eventName, customData) end\n    serviceMethods.LogEconomyEvent = function(self, player, flow, currencyType, amount, endingPlayerBalance, transactionType, itemSku) end\n    serviceMethods.LogFunnelStepEvent = function(self, player, funnelName, funnelSessionId, step, stepName) end\n    serviceMethods.LogOnboardingFunnelStepEvent = function(self, player, step, stepName) end\n    serviceMethods.LogProgressionCompleteEvent = function(self, player, progressionPathName, progressionName) end\n    serviceMethods.LogProgressionEvent = function(self, player, progressionPathName, progressionName, progressionIndex) end\n    -- Instance general\n    serviceMethods.GetNetworkOwner = function(self) return _at.localPlayer end\n    serviceMethods.SetNetworkOwner = function(self, player) end\n    serviceMethods.SetNetworkOwnershipAuto = function(self) end\n    serviceMethods.CanSetNetworkOwnership = function(self) return true, nil end\n    serviceMethods.GetNetworkOwnershipAuto = function(self) return true end\n    serviceMethods.ApplyDescription = function(self, humanoidDescription) end\n    serviceMethods.GetAppliedDescription = function(self) return createProxyObject("HumanoidDescription", false) end\n    serviceMethods.ReplaceContentIds = function(self, ids, newIds) end\n    serviceMethods.GetConnectedParts = function(self, recursive) return {} end\n    serviceMethods.GetJoints = function(self) return {} end\n    serviceMethods.GetTouchingParts = function(self) return {} end\n    serviceMethods.GetNoCollisionConstraints = function(self) return {} end\n    serviceMethods.SubtractAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.UnionAsync = function(self, parts, cs, ms) return createProxyObject("UnionOperation", false) end\n    serviceMethods.IntersectAsync = function(self, parts, cs, ms) return createProxyObject("IntersectOperation", false) end\n    serviceMethods.SeparateAsync = function(self, parts) return {} end\n    serviceMethods.BreakJoints = function(self) end\n    serviceMethods.MakeJoints = function(self) end\n    serviceMethods.ResetOrientationToIdentity = function(self) end\n    serviceMethods.GetRootPart = function(self) return proxy end\n    serviceMethods.GetModelCFrame = function(self) return CFrame.new(0,0,0) end\n    serviceMethods.GetModelSize = function(self) return Vector3.new(1,1,1) end\n    serviceMethods.FindPartOnRay = function(self, ray, ignore, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList, terrainCells, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.FindPartOnRayWithWhitelist = function(self, ray, whitelist, ignoreWater) return nil, Vector3.new(0,0,0), Vector3.new(0,1,0), createProxyObject("Air", false) end\n    serviceMethods.ArePartsTouchingOthers = function(self, parts, overlapIgnored) return false end\n    serviceMethods.GetPartsInPart = function(self, part, overlapParams) return {} end\n    -- Humanoid extra\n    serviceMethods.AddAccessory = function(self, accessory) end\n    serviceMethods.RemoveAccessories = function(self) end\n    serviceMethods.GetAccessories = function(self) return {} end\n    serviceMethods.GetLimb = function(self, part) return createProxyObject("Enum.Limb.Unknown", false) end\n    serviceMethods.GetBodyPartR15 = function(self, part) return nil end\n    serviceMethods.ReplaceBodyPartR15 = function(self, bodyPart, part) return false end\n    serviceMethods.BuildRigFromAttachments = function(self) end\n    -- Sound extra\n    serviceMethods.Resume = function(self) end\n    -- Gui\n    serviceMethods.TweenPosition = function(self, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSize = function(self, endSize, easingDirection, easingStyle, time, override, callback) return true end\n    serviceMethods.TweenSizeAndPosition = function(self, endSize, endPosition, easingDirection, easingStyle, time, override, callback) return true end\n    -- ContextActionService extra\n    serviceMethods.GetButton = function(self, actionName) return nil end\n    serviceMethods.LocalToolEquipped = function(self, toolEquipped) end\n    serviceMethods.LocalToolUnequipped = function(self, toolUnequipped) end\n    -- PathfindingService extra\n    serviceMethods.FindPathAsync = function(self, start, finish) return createProxyObject("Path", false) end\n    serviceMethods.ComputeAsync = function(self, start, finish) end\n    serviceMethods.GetWaypoints = function(self) return {} end\n    serviceMethods.CheckOcclusionAsync = function(self, start) return {} end\n    -- Camera extra\n    serviceMethods.ScreenPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.ViewportPointToRay = function(self, x, y, depth) return Ray.new(Vector3.new(0,0,0), Vector3.new(0,0,-1)) end\n    serviceMethods.WorldToScreenPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.WorldToViewportPoint = function(self, worldPoint) return Vector3.new(0,0,0), true end\n    serviceMethods.GetPartsObscuringTarget = function(self, castPoints, ignoreList) return {} end\n    serviceMethods.Interpolate = function(self, endPos, endFocus, duration) end\n    -- UserInputService extra\n    serviceMethods.GetMouseLocation = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetMouseDelta = function(self) return Vector2.new(0,0) end\n    serviceMethods.GetKeysPressed = function(self) return {} end\n    serviceMethods.GetMouseButtonsPressed = function(self) return {} end\n    serviceMethods.GetGamepadState = function(self, gamepadNum) return {} end\n    serviceMethods.GetSupportedGamepadKeyCodes = function(self, gamepadNum) return {} end\n    serviceMethods.GetConnectedGamepads = function(self) return {} end\n    serviceMethods.GetLastInputType = function(self) return createProxyObject("Enum.UserInputType.None", false) end\n    serviceMethods.GetFocusedTextBox = function(self) return nil end\n    serviceMethods.IsGamepadButtonDown = function(self, gamepadNum, keyCode) return false end\n    serviceMethods.IsKeyDown = function(self, keyCode) return false end\n    serviceMethods.IsMouseButtonPressed = function(self, mouseButton) return false end\n    serviceMethods.RecenterUserHeadCFrame = function(self) end\n    serviceMethods.GetDeviceRotation = function(self) return createProxyObject("InputObject", false), CFrame.new(0,0,0) end\n    serviceMethods.GetDeviceGravity = function(self) return createProxyObject("InputObject", false) end\n    -- PhysicsService\n    serviceMethods.CreateCollisionGroup = function(self, name) return 0 end\n    serviceMethods.RemoveCollisionGroup = function(self, name) end\n    serviceMethods.CollisionGroupSetCollidable = function(self, name1, name2, collidable) end\n    serviceMethods.CollisionGroupsAreCollidable = function(self, name1, name2) return true end\n    serviceMethods.GetCollisionGroupId = function(self, name) return 0 end\n    serviceMethods.GetCollisionGroupName = function(self, id) return "Default" end\n    serviceMethods.SetPartCollisionGroup = function(self, part, name) end\n    serviceMethods.GetMaxCollisionGroups = function(self) return 32 end\n    serviceMethods.GetRegisteredCollisionGroups = function(self) return {} end\n    -- StarterGui extra\n    serviceMethods.GetCoreGuiEnabled = function(self, coreGuiType) return true end\n    serviceMethods.RegisterGetCore = function(self, parameterName, getFunction) end\n    serviceMethods.RegisterSetCore = function(self, parameterName, setFunction) end\n    -- Lighting extra\n    serviceMethods.GetAtmosphere = function(self) return nil end\n    serviceMethods.GetSky = function(self) return nil end\n    -- Workspace extra\n    serviceMethods.GetServerTimeNow = function(self) return os.time() end\n    serviceMethods.PGSIsEnabled = function(self) return true end\n    serviceMethods.SetInsertPoint = function(self, point) end\n    -- NetworkClient/NetworkServer\n    serviceMethods.GetClientTicket = function(self) return "" end\n    -- ScriptContext\n    serviceMethods.AddCoreScriptLocal = function(self, name, parent) end\n    serviceMethods.GetCoreScriptVersion = function(self) return "1.0.0" end\n    meta.__namecall = function(self, ...) return nil end\n    meta.__index = function(tbl, key)\n        if key == proxyList or key == "__proxy_id" then\n            return rawget(tbl, key)\n        end\n        -- fast path: string key, check property_store and common properties before formatValue\n        if typeFunction(key) == "string" then\n            local ps = dumperState.property_store[proxy]\n            if ps then\n                local v = ps[key]\n                if v ~= nil then return v end\n            end\n            if key == "PlaceId" or key == "placeId" then return numericArg end\n            if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n            if key == "Parent" then return dumperState.parent_map[proxy] end\n            if key == "Name" then\n                if _at.typeOverride[proxy] == "EnumItem" then\n                    return (formattedName or ""):match("%.([^%.]+)$") or formattedName or "Object"\n                end\n                return formattedName or "Object"\n            end\n            if key == "ClassName" then return formattedName or "Instance" end\n            if not _at.metaHooks["__index"] then\n                local sm = serviceMethods[key]\n                if sm ~= nil then\n                    if typeFunction(sm) == "function" then\n                        local previousMethod\n                        return function(_, ...)\n                            previousMethod = _at.currentNamecallMethod\n                            _at.currentNamecallMethod = key\n                            local results = {sm(proxy, ...)}\n                            _at.currentNamecallMethod = previousMethod\n                            return table.unpack(results)\n                        end\n                    end\n                    return sm\n                end\n            end\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local propertyName = formatValue(key)\n        if _at.metaHooks["__index"] and not _at.inMetaHook then\n            _at.inMetaHook = true\n            local ok, result = pcallFunction(_at.metaHooks["__index"], proxy, key)\n            _at.inMetaHook = false\n            if ok and result ~= nil then return result end\n        end\n        if key == "PlaceId" or key == "placeId" then return numericArg end\n        if key == "GameId" or key == "gameId" then return numericArg + 864197532 end\n        if key == "Parent" then return dumperState.parent_map[proxy] end\n        -- DistributedGameTime ticking (must be before property_store read)\n        if key == "DistributedGameTime" then\n            if not _at._dgtClock then\n                -- initialize ticking from current stored value on first access\n                local props = dumperState.property_store[proxy]\n                _at._dgtBase = (props and props[key]) or 1\n                _at._dgtClock = osLibrary.clock()\n            end\n            return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n        end\n        -- AT6: SurfaceAppearance ContentId properties\n        local className = dumperState.property_store[proxy] and dumperState.property_store[proxy].ClassName\n        if className == "SurfaceAppearance" and (key == "ColorMap" or key == "NormalMap" or key == "RoughnessMap" or key == "MetalnessMap") then\n            return _makeContentId("")\n        end\n        if dumperState.property_store[proxy] and dumperState.property_store[proxy][key] ~= nil then\n            return dumperState.property_store[proxy][key]\n        end\n        if serviceMethods[propertyName] then\n            return function(_, ...)\n                if _at.metaHooks["__namecall"] and not _at.inMetaHook then\n                    local previousMethod = _at.currentNamecallMethod\n                    _at.currentNamecallMethod = propertyName\n                    _at.inMetaHook = true\n                    local ok, result = pcallFunction(_at.metaHooks["__namecall"], proxy, ...)\n                    _at.inMetaHook = false\n                    _at.currentNamecallMethod = previousMethod\n                    if ok and result ~= nil then return result end\n                end\n                local previousMethod = _at.currentNamecallMethod\n                _at.currentNamecallMethod = propertyName\n                local results = {serviceMethods[propertyName](proxy, ...)}\n                _at.currentNamecallMethod = previousMethod\n                return table.unpack(results)\n            end\n        end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        if pathName == "fenv" or pathName == "getgenv" or pathName == "_G" then\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            if _G[key] ~= nil then return _G[key] end\n            return nil\n        end\n        if key == "Name" then return formattedName or "Object" end\n        if key == "ClassName" then return formattedName or "Instance" end\n        if key == "Players" then return serviceMethods.GetService(game, "Players") end\n        if key == "Workspace" then return workspace end\n        if key == "LocalPlayer" then\n            if _at.localPlayer then return _at.localPlayer end\n            local lpProxy = createProxyObject("LocalPlayer", false, proxy)\n            dumperState.property_store[lpProxy] = {Name = "Player", ClassName = "Player", UserId = 1}\n            _at.localPlayer = lpProxy\n            local varName = registerVariable(lpProxy, "LocalPlayer")\n            emitOutput(string.format("local %s = %s.LocalPlayer", varName, pathName))\n            return lpProxy\n        end\n        if key == "PlayerGui" then return createProxyObject("PlayerGui", false, proxy) end\n        if key == "Backpack" then return createProxyObject("Backpack", false, proxy) end\n        if key == "PlayerScripts" then return createProxyObject("PlayerScripts", false, proxy) end\n        if key == "UserId" then return 1 end\n        if key == "DisplayName" then return "Player" end\n        if key == "AccountAge" then return 1000 end\n        if key == "LocaleId" then return "en-us" end\n        if key == "RobloxLocaleId" or key == "SystemLocaleId" then return "en-us" end\n        if key == "CharacterMaxSlopeAngle" then return 89 end\n        if key == "DistanceFactor" then return 3.33 end\n        if key == "CaptureBegan" then\n            local sigProxy = createProxyObject(pathName .. ".CaptureBegan", false, proxy)\n            dumperState.registry[sigProxy] = pathName .. ".CaptureBegan"\n            _at.typeOverride[sigProxy] = "RBXScriptSignal"\n            return sigProxy\n        end\n        if key == "Connected" and _at.connState[proxy] ~= nil then return _at.connState[proxy] end\n        if key == "Team" then return createProxyObject("Team", false, proxy) end\n        if key == "TeamColor" then return BrickColor.new("White") end\n        if key == "Character" then\n            local charProxy = createProxyObject("Character", false, proxy)\n            dumperState.property_store[charProxy] = {Name = "Character", ClassName = "Model"}\n            -- AT3: seed Animate LocalScript as child of character\n            if not _at.animateScript then\n                local animProxy = createProxyObject("Animate", false, charProxy)\n                dumperState.registry[animProxy] = "Animate"\n                dumperState.property_store[animProxy] = {Name = "Animate", ClassName = "LocalScript", Parent = charProxy}\n                _setParent(animProxy, charProxy)\n                _at.animateScript = animProxy\n            end\n            return charProxy\n        end\n        if key == "Humanoid" then\n            local humProxy = createProxyObject("Humanoid", false, proxy)\n            dumperState.property_store[humProxy] = {Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2}\n            return humProxy\n        end\n        if key == "HumanoidRootPart" or key == "PrimaryPart" or key == "RootPart" then\n            local rootProxy = createProxyObject("HumanoidRootPart", false, proxy)\n            dumperState.property_store[rootProxy] = {Position = Vector3.new(0, 5, 0), CFrame = CFrame.new(0, 5, 0)}\n            return rootProxy\n        end\n        local limbNames = {"Head", "Torso", "UpperTorso", "LowerTorso", "RightArm", "LeftArm", "RightLeg", "LeftLeg", "RightHand", "LeftHand", "RightFoot", "LeftFoot"}\n        for _, limb in ipairsFunction(limbNames) do\n            if key == limb then return createProxyObject(key, false, proxy) end\n        end\n        if key == "Animator" then return createProxyObject("Animator", false, proxy) end\n        if key == "CurrentCamera" or key == "Camera" then\n            local camProxy = createProxyObject("Camera", false, proxy)\n            dumperState.property_store[camProxy] = {CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080)}\n            return camProxy\n        end\n        if key == "Terrain" then\n            if not _at.terrainProxy then\n                local tp = createProxyObject("Terrain", false, proxy)\n                dumperState.property_store[tp] = {ClassName="Terrain",Name="Terrain",Parent=proxy,WaterWaveSpeed=100,WaterWaveSize=0.5}\n                _at.terrainProxy = tp\n            end\n            return _at.terrainProxy\n        end\n        if key == "CameraType" then return Enum.CameraType.Custom end\n        if key == "CameraSubject" then return createProxyObject("Humanoid", false, proxy) end\n        if key == "DistributedGameTime" then\n            if _at._dgtBase and _at._dgtClock then\n                return _at._dgtBase + (osLibrary.clock() - _at._dgtClock)\n            end\n        end\n        local constants = {\n            Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, HipHeight = 2,\n            Transparency = 0, Mass = 1, Value = 0, TimePosition = 0, TimeLength = 1, Volume = 0.5,\n            PlaybackSpeed = 1, Brightness = 1, Range = 60, Angle = 90, FieldOfView = 70, Thickness = 1,\n            ZIndex = 1, LayoutOrder = 0, Gravity = 196.2, DistributedGameTime = 1, ClockTime = 14,\n            FogEnd = 100000, RolloffScale = 1, MaxPlayers = 12, RespawnTime = 5, PlaceVersion = 1,\n            CreatorId = 0, FollowUserId = 0, NearPlaneZ = -0.1\n        }\n        if constants[key] ~= nil then return constants[key] end\n        if key == "Size" and not (formattedName and formattedName:match("Part")) then return UDim2.new(1, 0, 1, 0) end\n        local boolConstants = {Visible = true, Enabled = true, Anchored = false, CanCollide = true, Locked = false, Active = true, Draggable = false, Modal = false, Playing = false, Looped = false, IsPlaying = false, AutoPlay = false, Archivable = true, ClipsDescendants = false, RichText = false, TextWrapped = false, TextScaled = false, PlatformStand = false, AutoRotate = true, Sit = false}\n        boolConstants.StreamingEnabled = false\n        boolConstants.HttpEnabled = false\n        boolConstants.Sandboxed = false\n        if boolConstants[key] ~= nil then return boolConstants[key] end\n        if key == "JobId" then return "00000000-0000-4000-8000-000000000001" end\n        if key == "CreatorType" then return Enum.CreatorType.User end\n        if key == "MembershipType" then return Enum.MembershipType.None end\n        if key == "AmbientReverb" then return Enum.ReverbType.NoReverb end\n        if key == "Ambient" or key == "OutdoorAmbient" then return Color3.fromRGB(128, 128, 128) end\n        if key == "UniqueId" then return _getDebugId(proxy) end\n        if key == "AbsoluteSize" or key == "ViewportSize" then return Vector2.new(1920, 1080) end\n        if key == "AbsolutePosition" then return Vector2.new(0, 0) end\n        if key == "Position" then\n            if formattedName and (formattedName:match("Part") or formattedName:match("Model") or formattedName:match("Character") or formattedName:match("Root")) then return Vector3.new(0, 5, 0) end\n            return UDim2.new(0, 0, 0, 0)\n        end\n        if key == "Size" then\n            if formattedName and formattedName:match("Part") then return Vector3.new(4, 1, 2) end\n            return UDim2.new(1, 0, 1, 0)\n        end\n        if key == "CFrame" then return CFrame.new(0, 5, 0) end\n        if key == "Velocity" or key == "AssemblyLinearVelocity" then\n            -- AT4: if a LinearVelocity constraint is attached to this part, reflect its VectorVelocity\n            for _, child in ipairsFunction(_at.children[proxy] or {}) do\n                local cprops = dumperState.property_store[child]\n                if cprops and cprops.ClassName == "LinearVelocity" then\n                    local vv = cprops.VectorVelocity\n                    if vv and typeof(vv) == "Vector3" then return vv end\n                end\n            end\n            return Vector3.new(0, 0, 0)\n        end\n        if key == "RotVelocity" or key == "AssemblyAngularVelocity" then\n            local imp = dumperState.property_store[proxy] and dumperState.property_store[proxy]["_angularImpulse"]\n            if imp and _at.vectors[imp] then\n                local d = _at.vectors[imp]\n                return _makeVector3(d.x, d.y, d.z)\n            end\n            return _makeVector3(0, 0, 0)\n        end\n        if key == "Orientation" or key == "Rotation" then return Vector3.new(0, 0, 0) end\n        if key == "LookVector" then return Vector3.new(0, 0, -1) end\n        if key == "RightVector" then return Vector3.new(1, 0, 0) end\n        if key == "UpVector" then return Vector3.new(0, 1, 0) end\n        if key == "Color" or key == "Color3" or key == "BackgroundColor3" or key == "BorderColor3" or key == "TextColor3" or key == "PlaceholderColor3" or key == "ImageColor3" then return Color3.new(1, 1, 1) end\n        if key == "BrickColor" then return BrickColor.new("Medium stone grey") end\n        if key == "Material" then return createProxyObject("Enum.Material.Plastic", false) end\n        if key == "Hit" then return CFrame.new(0, 0, -10) end\n        if key == "Origin" then return CFrame.new(0, 5, 0) end\n        if key == "Target" then return createProxyObject("Target", false, proxy) end\n        if key == "X" or key == "Y" then return 0 end\n        if key == "UnitRay" then return Ray.new(Vector3.new(0, 5, 0), Vector3.new(0, 0, -1)) end\n        if key == "ViewSizeX" then return 1920 end\n        if key == "ViewSizeY" then return 1080 end\n        if key == "Text" or key == "PlaceholderText" or key == "ContentText" or key == "Value" then\n            if inputKey then return inputKey end\n            if key == "Value" then return "input" end\n            return '"'
        end
        if key == "TextBounds" then return Vector2.new(0, 0) end
        if key == "Font" then return createProxyObject("Enum.Font.SourceSans", false) end
        if key == "TextSize" then return 14 end
        if key == "Image" or key == "ImageContent" then return '"' end\n        if pathName:match("^Enum") then\n            if propertyName == "Value" then\n                local enumValues = {\n                    ["Enum.Material.Plastic"]=256,["Enum.Material.SmoothPlastic"]=272,\n                    ["Enum.Material.Neon"]=288,["Enum.Material.Wood"]=512,\n                    ["Enum.Material.Metal"]=768,["Enum.Material.Glass"]=1568,\n                    ["Enum.NormalId.Front"]=5,["Enum.NormalId.Back"]=2,\n                    ["Enum.NormalId.Left"]=3,["Enum.NormalId.Right"]=0,\n                    ["Enum.NormalId.Top"]=1,["Enum.NormalId.Bottom"]=4,\n                    ["Enum.KeyCode.Unknown"]=0,["Enum.KeyCode.Return"]=13,\n                    ["Enum.KeyCode.Space"]=32,["Enum.KeyCode.E"]=69,\n                    ["Enum.Font.GothamBold"]=11,["Enum.Font.Gotham"]=4,\n                    ["Enum.MembershipType.None"]=0,["Enum.MembershipType.Premium"]=4,\n                    ["Enum.ActionType.Nothing"]=0,["Enum.ActionType.Pause"]=1,["Enum.ActionType.Lose"]=2,["Enum.ActionType.Draw"]=3,["Enum.ActionType.Win"]=4,\n                    ["Enum.ConnectionError.OK"]=0,["Enum.ConnectionError.Unknown"]=1,["Enum.ConnectionError.ConnectErrors"]=2,["Enum.ConnectionError.Disconnect"]=3,["Enum.ConnectionError.Unauthorized"]=4,["Enum.ConnectionError.NotFound"]=5,["Enum.ConnectionError.Forbidden"]=6,["Enum.ConnectionError.TooManyRequests"]=7,["Enum.ConnectionError.ServiceUnavailable"]=8,["Enum.ConnectionError.GatewayTimeout"]=9,\n                    ["Enum.VelocityConstraintMode.Vector"]=0,["Enum.VelocityConstraintMode.Plane"]=1,["Enum.VelocityConstraintMode.Line"]=2,\n                }\n                return enumValues[pathName] or 0\n            end\n            if propertyName == "Name" then return pathName:match("%.([^%.]+)$") or pathName end\n            if propertyName == "EnumType" then\n                local et = pathName:match("^(Enum%.[^%.]+)") or "Enum"\n                return _at.enum[et] or createProxyObject(et, false)\n            end\n            local fullEnum = pathName .. "." .. propertyName\n            if not _at.enum[fullEnum] then\n                local enumProxy = createProxyObject(fullEnum, false)\n                dumperState.registry[enumProxy] = fullEnum\n                _at.typeOverride[enumProxy] = "EnumItem"\n                _at.enum[fullEnum] = enumProxy\n            end\n            return _at.enum[fullEnum]\n        end\n        local signalNames = {"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "Touched", "TouchEnded", "InputBegan", "InputEnded", "InputChanged", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward", "MouseWheelBackward", "Activated", "Deactivated", "FocusLost", "FocusGained", "Focused", "Heartbeat", "RenderStepped", "Stepped", "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded", "PlayerRemoving", "AncestryChanged", "AttributeChanged", "Died", "FreeFalling", "GettingUp", "Jumping", "Running", "Seated", "Swimming", "StateChanged", "HealthChanged", "MoveToFinished", "OnClientEvent", "OnServerEvent", "OnClientInvoke", "OnServerInvoke", "Completed", "DidLoop", "Stopped", "CaptureBegan", "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Idle", "Move", "TextChanged", "ReturnPressedFromOnScreenKeyboard", "Triggered", "TriggerEnded", "Error", "Event", "AxisChanged", "JumpRequest", "DevTouchMovementModeChanged", "DevComputerMovementModeChanged", "GraphicsQualityChangeRequest", "MenuOpened", "MenuClosed", "PointerAction", "TouchStarted", "TouchMoved", "TouchEnded", "TouchTap", "TouchLongPress", "TouchPinch", "TouchRotate", "TouchSwipe", "GamepadConnected", "GamepadDisconnected", "WindowFocused", "WindowFocusReleased"}\n        for _, sig in ipairsFunction(signalNames) do\n            if key == sig then\n                local sigProxy = createProxyObject(pathName .. "." .. key, false, nil)\n                dumperState.registry[sigProxy] = pathName .. "." .. key\n                _at.typeOverride[sigProxy] = "RBXScriptSignal"\n                _at.signalOwner = _at.signalOwner or {}\n                _at.signalOwner[sigProxy] = proxy  -- track owner without triggering _setParent\n                return sigProxy\n            end\n        end\n        return createProxyMethod(propertyName, proxy)\n    end\n    meta.__newindex = function(tbl, key, val)\n        if key == proxyList or key == "__proxy_id" then\n            rawset(tbl, key, val)\n            return\n        end\n        -- locked: never allow mutation regardless of method\n        local _lockedProps = {PlaceId=true, placeId=true, GameId=true, gameId=true, UniverseId=true}\n        if _lockedProps[key] then return end\n        -- read-only properties: error like real Roblox does\n        local _readOnlyProps = {\n            PlaybackLoudness = true,\n            AbsolutePosition = true,\n            AbsoluteSize = true,\n            AbsoluteRotation = true,\n            TextBounds = true,\n            ContentText = true,\n            SimulationRadius = true,\n            MaxSimulationRadius = true,\n            RootPriority = true,\n            NativeIndex = true,\n            ReceiveAge = true,\n            AssemblyAngularVelocity = true,\n            AssemblyLinearVelocity = true,\n            AssemblyMass = true,\n            AssemblyRootPart = true,\n            CurrentCamera = true,\n            PrivateServerOwnerId = true,\n            PrivateServerId = true,\n            JobId = true,\n            PlaceId = true,\n            GameId = true,\n            PlaceVersion = true,\n            UserId = true,\n            FloorMaterial = true,\n            MoveDirection = true,\n            SeatPart = true,\n        }\n        if _readOnlyProps[key] then\n            errorFunction(toStringFunction(key) .. " is not a valid member of " .. (dumperState.registry[proxy] or formattedName or "Instance"), 2)\n        end\n        local pathName = dumperState.registry[proxy] or formattedName or "object"\n        local prop = formatValue(key)\n        dumperState.property_store[proxy] = dumperState.property_store[proxy] or {}\n        dumperState.property_store[proxy][key] = val\n        local _cls2 = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if key == "CameraMinZoomDistance" then\n            local n = tonumber(val) or 0; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif key == "CameraMaxZoomDistance" then\n            local n = tonumber(val) or 400; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        elseif _cls2 == "Terrain" and key == "WaterWaveSpeed" then\n            local n = tonumber(val) or 100; if n > 100 then n = 100 end; if n < 0 then n = 0 end\n            dumperState.property_store[proxy][key] = n\n        end\n        if key == "Parent" then\n            _setParent(proxy, isProxy(val) and val or nil)\n        end\n        local className = (dumperState.property_store[proxy] or {}).ClassName or ""\n        if className == "WeldConstraint" or className == "Weld" or className == "Motor6D" then\n            if key == "Part0" or key == "Part1" then\n                _at.weldRegistry[proxy] = _at.weldRegistry[proxy] or {}\n                _at.weldRegistry[proxy][key] = val\n                local wr = _at.weldRegistry[proxy]\n                if wr.Part0 and wr.Part1 then\n                    local cf0 = (dumperState.property_store[wr.Part0] or {}).CFrame\n                    local cf1 = (dumperState.property_store[wr.Part1] or {}).CFrame\n                    if cf0 and cf1 then\n                        wr.offset = {X = (cf1.X or 0) - (cf0.X or 0), Y = (cf1.Y or 0) - (cf0.Y or 0), Z = (cf1.Z or 0) - (cf0.Z or 0)}\n                    end\n                end\n            end\n        end\n        if key == "CFrame" then\n            local cfVal = val\n            local cfX = (cfVal and cfVal.X) or 0\n            local cfY = (cfVal and cfVal.Y) or 0\n            local cfZ = (cfVal and cfVal.Z) or 0\n            for _, wr in pairs(_at.weldRegistry) do\n                if wr.Part0 == proxy and wr.Part1 and wr.offset then\n                    local nx = cfX + wr.offset.X\n                    local ny = cfY + wr.offset.Y\n                    local nz = cfZ + wr.offset.Z\n                    local newCF\n                    if type(CFrame) == "table" and type(CFrame.new) == "function" then\n                        newCF = CFrame.new(nx, ny, nz)\n                    elseif _makeCFrame then\n                        newCF = _makeCFrame(nx, ny, nz)\n                    else\n                        newCF = {X = nx, Y = ny, Z = nz, Position = {X = nx, Y = ny, Z = nz}}\n                    end\n                    dumperState.property_store[wr.Part1] = dumperState.property_store[wr.Part1] or {}\n                    dumperState.property_store[wr.Part1].CFrame = newCF\n                    local posV = newCF.Position\n                    dumperState.property_store[wr.Part1].Position = posV\n                end\n            end\n        end\n        emitOutput(string.format("%s.%s = %s", pathName, prop, serializeValue(val)))\n    end\n    meta.__call = function(tbl, ...)\n        local pathName = dumperState.registry[proxy] or formattedName or "func"\n        if pathName == "fenv" or pathName == "getgenv" or pathName:match("env") then\n            return proxy\n        end\n        if pathName == "game" then\n            errorFunction("attempt to call an Instance value", 0)\n        end\n        local args = {...}\n        local serializedArgs = {}\n        for _, val in ipairsFunction(args) do\n            table.insert(serializedArgs, serializeValue(val))\n        end\n        local resultProxy = createProxyObject("result", false)\n        local varName = registerVariable(resultProxy, "result")\n        emitOutput(string.format("local %s = %s(%s)", varName, pathName, table.concat(serializedArgs, ", ")))\n        return resultProxy\n    end\n    local function operatorMeta(opSymbol)\n        local function metaCall(a, b)\n            local proxy, meta = createProxy()\n            local strA = "0"\n            if a ~= nil then strA = dumperState.registry[a] or serializeValue(a) end\n            local strB = "0"\n            if b ~= nil then strB = dumperState.registry[b] or serializeValue(b) end\n            local expression = "(" .. strA .. " " .. opSymbol .. " " .. strB .. ")"\n            dumperState.registry[proxy] = expression\n            meta.__tostring = function() return expression end\n            meta.__call = function() return proxy end\n            meta.__index = function(_, k)\n                if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                return createProxyObject(expression .. "." .. formatValue(k), false)\n            end\n            meta.__add = operatorMeta("+")\n            meta.__sub = operatorMeta("-")\n            meta.__mul = operatorMeta("*")\n            meta.__div = operatorMeta("/")\n            meta.__mod = operatorMeta("%")\n            meta.__pow = operatorMeta("^")\n            meta.__concat = operatorMeta("..")\n            meta.__eq = function() return false end\n            meta.__lt = function() return false end\n            meta.__le = function() return false end\n            return proxy\n        end\n        return metaCall\n    end\n    meta.__add = operatorMeta("+")\n    meta.__sub = operatorMeta("-")\n    meta.__mul = operatorMeta("*")\n    meta.__div = operatorMeta("/")\n    meta.__mod = operatorMeta("%")\n    meta.__pow = operatorMeta("^")\n    meta.__concat = operatorMeta("..")\n    meta.__eq = function(a, b) return rawequal(a, b) end\n    meta.__lt = function() return false end\n    meta.__le = function() return false end\n    meta.__unm = function(a)\n        local proxy, meta = createProxy()\n        dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n        meta.__tostring = function() return dumperState.registry[proxy] end\n        return proxy\n    end\n    meta.__len = function() return 0 end\n    meta.__tostring = function() return dumperState.registry[proxy] or formattedName or "Object" end\n    meta.__pairs = function() return function() return nil end, proxy, nil end\n    meta.__ipairs = meta.__pairs\n    return proxy\nend\nlocal function createTypeDa(typeName, methods)\n    local dc = {}\n    local dd = {}\n    dd.__index = function(_, key)\n        if key == "new" or methods and methods[key] then\n            return function(...)\n                local args = {...}\n                local serializedArgs = {}\n                for _, val in ipairsFunction(args) do\n                    table.insert(serializedArgs, serializeValue(val))\n                end\n                local expression = typeName .. "." .. key .. "(" .. table.concat(serializedArgs, ", ") .. ")"\n                local proxy, meta = createProxy()\n                dumperState.registry[proxy] = expression\n                meta.__tostring = function() return expression end\n                meta.__index = function(_, k)\n                    if k == proxyList or k == "__proxy_id" then return rawget(proxy, k) end\n                    if k == "X" or k == "Y" or k == "Z" or k == "W" then return 0 end\n                    if k == "Magnitude" then return 0 end\n                    if k == "Unit" or k == "Position" or k == "CFrame" or k == "LookVector" or k == "RightVector" or k == "UpVector" or k == "Rotation" or k == "p" then return proxy end\n                    if k == "R" or k == "G" or k == "B" then return 1 end\n                    if k == "Width" or k == "Height" then return UDim.new(0, 0) end\n                    if k == "Min" or k == "Max" or k == "Scale" or k == "Offset" then return 0 end\n                    return createProxyObject(expression .. "." .. formatValue(k), false)\n                end\n                local function opMeta(symbol)\n                    return function(a, b)\n                        local proxy, meta = createProxy()\n                        local expr = "(" .. (dumperState.registry[a] or serializeValue(a)) .. " " .. symbol .. " " .. (dumperState.registry[b] or serializeValue(b)) .. ")"\n                        dumperState.registry[proxy] = expr\n                        meta.__tostring = function() return expr end\n                        meta.__index = meta.__index\n                        meta.__add = opMeta("+")\n                        meta.__sub = opMeta("-")\n                        meta.__mul = opMeta("*")\n                        meta.__div = opMeta("/")\n                        return proxy\n                    end\n                end\n                meta.__add = opMeta("+")\n                meta.__sub = opMeta("-")\n                meta.__mul = opMeta("*")\n                meta.__div = opMeta("/")\n                meta.__unm = function(a)\n                    local proxy, meta = createProxy()\n                    dumperState.registry[proxy] = "(-" .. (dumperState.registry[a] or serializeValue(a)) .. ")"\n                    meta.__tostring = function() return dumperState.registry[proxy] end\n                    return proxy\n                end\n                meta.__eq = function() return false end\n                meta.__typeof = typeName\n                return proxy\n            end\n        end\n        return nil\n    end\n    dd.__call = function(_, ...) return _.new(...) end\n    return setmetatable(dc, dd)\nend\nVector3 = createTypeDa("Vector3", {new = true, zero = true, one = true})\nVector2 = createTypeDa("Vector2", {new = true, zero = true, one = true})\nUDim = createTypeDa("UDim", {new = true})\nUDim2 = createTypeDa("UDim2", {new = true, fromScale = true, fromOffset = true})\nCFrame = createTypeDa("CFrame", {new = true, Angles = true, lookAt = true, fromEulerAnglesXYZ = true, fromEulerAnglesYXZ = true, fromAxisAngle = true, fromMatrix = true, fromOrientation = true, identity = true})\nColor3 = createTypeDa("Color3", {new = true, fromRGB = true, fromHSV = true, fromHex = true})\nBrickColor = createTypeDa("BrickColor", {new = true, random = true, White = true, Black = true, Red = true, Blue = true, Green = true, Yellow = true, palette = true})\nTweenInfo = createTypeDa("TweenInfo", {new = true})\nRect = createTypeDa("Rect", {new = true})\nRegion3 = createTypeDa("Region3", {new = true})\nRegion3int16 = createTypeDa("Region3int16", {new = true})\nRay = createTypeDa("Ray", {new = true})\nNumberRange = createTypeDa("NumberRange", {new = true})\nNumberSequence = createTypeDa("NumberSequence", {new = true})\nNumberSequenceKeypoint = createTypeDa("NumberSequenceKeypoint", {new = true})\nColorSequence = createTypeDa("ColorSequence", {new = true})\nColorSequence.new = function(...)\n    local args = {...}\n    local keypoints = {}\n    if #args == 1 and typeFunction(args[1]) == "table" and args[1][1] ~= nil then\n        keypoints = args[1]\n    elseif #args == 1 then\n        keypoints = {args[1], args[1]}\n    elseif #args >= 2 then\n        keypoints = args\n    end\n    local t = setmetatable({Keypoints = keypoints}, {\n        __typeof = "ColorSequence",\n        __tostring = function() return "ColorSequence" end,\n    })\n    return t\nend\nColorSequenceKeypoint = createTypeDa("ColorSequenceKeypoint", {new = true})\nPhysicalProperties = createTypeDa("PhysicalProperties", {new = true})\nFont = createTypeDa("Font", {new = true, fromEnum = true, fromName = true, fromId = true})\nRaycastParams = createTypeDa("RaycastParams", {new = true})\nOverlapParams = {new = function()\n        local params = {MaxParts = 0, FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}}\n        return setmetatable(params, {__typeof = "OverlapParams"})\n    end}\n_makeVector3 = function(x, y, z, expr)\n    x, y, z = toNumberFunction(x) or 0, toNumberFunction(y) or 0, toNumberFunction(z) or 0\n    local proxy, meta = createProxy()\n    local expression = expr or ("Vector3.new(" .. serializeValue(x) .. ", " .. serializeValue(y) .. ", " .. serializeValue(z) .. ")")\n    dumperState.registry[proxy] = expression\n    _at.vectors[proxy] = {x = x, y = y, z = z}\n    local function component(v, axis)\n        local data = _at.vectors[v]\n        if not data then return 0 end\n        return axis == "X" and data.x or axis == "Y" and data.y or data.z\n    end\n    local function binary(a, b, symbol)\n        local ax, ay, az = component(a, "X"), component(a, "Y"), component(a, "Z")\n        local bx, by, bz\n        if typeFunction(b) == "number" then bx, by, bz = b, b, b else bx, by, bz = component(b, "X"), component(b, "Y"), component(b, "Z") end\n        if symbol == "+" then return _makeVector3(ax + bx, ay + by, az + bz, "(" .. serializeValue(a) .. " + " .. serializeValue(b) .. ")") end\n        if symbol == "-" then return _makeVector3(ax - bx, ay - by, az - bz, "(" .. serializeValue(a) .. " - " .. serializeValue(b) .. ")") end\n        if symbol == "*" then return _makeVector3(ax * bx, ay * by, az * bz, "(" .. serializeValue(a) .. " * " .. serializeValue(b) .. ")") end\n        return _makeVector3(bx ~= 0 and ax / bx or 0, by ~= 0 and ay / by or 0, bz ~= 0 and az / bz or 0, "(" .. serializeValue(a) .. " / " .. serializeValue(b) .. ")")\n    end\n    meta.__index = function(_, key)\n        if key == proxyList or key == "__proxy_id" then return rawget(proxy, key) end\n        if key == "X" then return x end\n        if key == "Y" then return y end\n        if key == "Z" then return z end\n        if key == "Magnitude" then return math.sqrt(x * x + y * y + z * z) end\n        if key == "Unit" then\n            local mag = math.sqrt(x * x + y * y + z * z)\n            if mag == 0 then return _makeVector3(0, 0, 0, expression .. ".Unit") end\n            return _makeVector3(x / mag, y / mag, z / mag, expression .. ".Unit")\n        end\n        if key == "Dot" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return x * ox + y * oy + z * oz\n            end\n        end\n        if key == "Cross" then\n            return function(self, other)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return _makeVector3(y*oz - z*oy, z*ox - x*oz, x*oy - y*ox)\n            end\n        end\n        if key == "Lerp" then\n            return function(self, other, alpha)\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                local a = toNumberFunction(alpha) or 0\n                return _makeVector3(x + (ox-x)*a, y + (oy-y)*a, z + (oz-z)*a)\n            end\n        end\n        if key == "FuzzyEq" then\n            return function(self, other, epsilon)\n                local eps = toNumberFunction(epsilon) or 1e-5\n                local ox, oy, oz = component(other, "X"), component(other, "Y"), component(other, "Z")\n                return math.abs(x-ox) <= eps and math.abs(y-oy) <= eps and math.abs(z-oz) <= eps\n            end\n        end\n        return 0\n    end\n    meta.__add = function(a, b) return binary(a, b, "+") end\n    meta.__sub = function(a, b) return binary(a, b, "-") end\n    meta.__mul = function(a, b) return binary(a, b, "*") end\n    meta.__div = function(a, b) return binary(a, b, "/") end\n    meta.__unm = function(a) return _makeVector3(-component(a, "X"), -component(a, "Y"), -component(a, "Z"), "(-" .. serializeValue(a) .. ")") end\n    meta.__eq = function(a, b) return component(a, "X") == component(b, "X") and component(a, "Y") == component(b, "Y") and component(a, "Z") == component(b, "Z") end\n    meta.__tostring = function() return toStringFunction(x) .. ", " .. toStringFunction(y) .. ", " .. toStringFunction(z) end\n    return proxy\nend\nVector3 = {\n    new = function(x, y, z) return _makeVector3(x, y, z) end,\n    zero = _makeVector3(0, 0, 0, "Vector3.zero"),\n    one = _makeVector3(1, 1, 1, "Vector3.one"),\n    fromNormalId = function(normalId)\n        local name = toStringFunction(normalId)\n        if name:find("Right")  then return _makeVector3( 1,  0,  0) end\n        if name:find("Left")   then return _makeVector3(-1,  0,  0) end\n        if name:find("Top")    then return _makeVector3( 0,  1,  0) end\n        if name:find("Bottom") then return _makeVector3( 0, -1,  0) end\n        if name:find("Back")   then return _makeVector3( 0,  0,  1) end\n        if name:find("Front")  then return _makeVector3( 0,  0, -1) end\n        return _makeVector3(0, 0, 0)\n    end,\n    fromAxis = function(axis)\n        local name = toStringFunction(axis)\n        if name:find("X") then return _makeVector3(1, 0, 0) end\n        if name:find("Y") then return _makeVector3(0, 1, 0) end\n        if name:find("Z") then return _makeVector3(0, 0, 1) end\n        return _makeVector3(0, 0, 0)\n    end,\n}\nsetmetatable(Vector3, {__call = function(_, x, y, z) return _.new(x, y, z) end})\nlocal function _valueType(typeName, fields, methods)\n    local obj = fields or {}\n    return setmetatable(obj, {\n        __typeof = typeName,\n        __index = methods or {},\n        __tostring = function() return typeName end,\n        __eq = function(a, b)\n            if typeFunction(a) ~= "table" or typeFunction(b) ~= "table" then return false end\n            local ma, mb = getMetatableFunction(a), getMetatableFunction(b)\n            if not ma or not mb or ma.__typeof ~= mb.__typeof then return false end\n            for k, v in pairsFunction(a) do\n                if b[k] ~= v then return false end\n            end\n            for k, v in pairsFunction(b) do\n                if a[k] ~= v then return false end\n            end\n            return true\n        end\n    })\nend\nlocal function _num(v, default) return toNumberFunction(v) or default or 0 end\nlocal function _makeVector2(x, y)\n    x, y = _num(x), _num(y)\n    local methods = {}\n    function methods:Dot(other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) end\n    local mt\n    mt = {\n        __typeof = "Vector2",\n        __index = function(self, key)\n            if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end\n            if key == "Unit" then\n                local mag = math.sqrt(self.X * self.X + self.Y * self.Y)\n                return mag == 0 and _makeVector2(0, 0) or _makeVector2(self.X / mag, self.Y / mag)\n            end\n            return methods[key]\n        end,\n        __add = function(a, b) return _makeVector2(a.X + b.X, a.Y + b.Y) end,\n        __sub = function(a, b) return _makeVector2(a.X - b.X, a.Y - b.Y) end,\n        __mul = function(a, b)\n            if typeFunction(a) == "number" then return _makeVector2(a * b.X, a * b.Y) end\n            if typeFunction(b) == "number" then return _makeVector2(a.X * b, a.Y * b) end\n            return _makeVector2(a.X * b.X, a.Y * b.Y)\n        end,\n        __div = function(a, b)\n            if typeFunction(b) == "number" then return _makeVector2(a.X / b, a.Y / b) end\n            return _makeVector2(a.X / b.X, a.Y / b.Y)\n        end,\n        __unm = function(a) return _makeVector2(-a.X, -a.Y) end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y end,\n        __tostring = function(a) return ("Vector2.new(%s, %s)"):format(a.X, a.Y) end,\n    }\n    return setmetatable({X = x, Y = y}, mt)\nend\nVector2 = {new = function(x, y) return _makeVector2(x, y) end}\nVector2.zero = Vector2.new(0, 0)\nVector2.one = Vector2.new(1, 1)\nsetmetatable(Vector2, {__call = function(_, x, y) return _.new(x, y) end})\nlocal _oldVector3New = Vector3.new\nVector3.new = function(x, y, z)\n    local v = _oldVector3New(x, y, z)\n    local mt = getMetatableFunction(v)\n    local oldIndex = mt.__index\n    mt.__index = function(self, key)\n        if key == "Dot" then\n            return function(_, other) return self.X * (other and other.X or 0) + self.Y * (other and other.Y or 0) + self.Z * (other and other.Z or 0) end\n        end\n        if key == "Cross" then\n            return function(_, other)\n                return Vector3.new(\n                    self.Y * (other and other.Z or 0) - self.Z * (other and other.Y or 0),\n                    self.Z * (other and other.X or 0) - self.X * (other and other.Z or 0),\n                    self.X * (other and other.Y or 0) - self.Y * (other and other.X or 0)\n                )\n            end\n        end\n        return oldIndex(self, key)\n    end\n    return v\nend\nVector3.zero = Vector3.new(0, 0, 0)\nVector3.one = Vector3.new(1, 1, 1)\nUDim = {new = function(scale, offset) return _valueType("UDim", {Scale = _num(scale), Offset = _num(offset)}) end}\nsetmetatable(UDim, {__call = function(_, scale, offset) return _.new(scale, offset) end})\nUDim2 = {\n    new = function(xs, xo, ys, yo) return _valueType("UDim2", {X = UDim.new(xs, xo), Y = UDim.new(ys, yo)}) end,\n    fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,\n    fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,\n}\nsetmetatable(UDim2, {__call = function(_, ...) return _.new(...) end})\nColor3 = {\n    new = function(r, g, b)\n        local rv, gv, bv = _num(r), _num(g), _num(b)\n        if rv < 0 or rv > 1 or gv < 0 or gv > 1 or bv < 0 or bv > 1 then\n            errorFunction("R, G, and B must each be in the range [0, 1]", 2)\n        end\n        return setmetatable({R = rv, G = gv, B = bv}, {\n            __typeof = "Color3",\n            __tostring = function(self) return string.format("[R:%g, G:%g, B:%g]", self.R, self.G, self.B) end,\n            __eq = function(a, b) return typeFunction(b) == "table" and a.R == b.R and a.G == b.G and a.B == b.B end,\n        })\n    end,\n    fromRGB = function(r, g, b) return Color3.new(_num(r) / 255, _num(g) / 255, _num(b) / 255) end,\n    fromHSV = function(h, s, v) return Color3.new(v or 1, v or 1, v or 1) end,\n    fromHex = function(hex) return Color3.fromRGB(255, 255, 255) end,\n}\nsetmetatable(Color3, {__call = function(_, ...) return _.new(...) end})\nBrickColor = {\n    new = function(name)\n        name = formatValue(name or "Medium stone grey")\n        return _valueType("BrickColor", {Name = name, Number = 1, Color = Color3.fromRGB(255, 0, 0)})\n    end,\n    random = function() return BrickColor.new("Medium stone grey") end,\n}\nsetmetatable(BrickColor, {__call = function(_, ...) return _.new(...) end})\nNumberRange = {new = function(min, max) return _valueType("NumberRange", {Min = _num(min), Max = max ~= nil and _num(max) or _num(min)}) end}\nNumberSequence = {new = function(value) return _valueType("NumberSequence", {Keypoints = typeFunction(value) == "table" and value or {{Time = 0, Value = _num(value)}, {Time = 1, Value = _num(value)}}}) end}\nTweenInfo = {new = function(timeValue, style, direction, repeatCount, reverses, delayTime) return _valueType("TweenInfo", {Time = _num(timeValue), EasingStyle = style or Enum.EasingStyle.Quad, EasingDirection = direction or Enum.EasingDirection.Out, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delayTime or 0}) end}\nRay = {new = function(origin, direction) return _valueType("Ray", {Origin = origin or Vector3.zero, Direction = direction or Vector3.new(0, 0, -1)}) end}\nRect = {new = function(a, b, c, d)\n    local minV = typeFunction(a) == "table" and a or Vector2.new(a, b)\n    local maxV = typeFunction(c) == "table" and c or Vector2.new(c, d)\n    return _valueType("Rect", {Min = minV, Max = maxV, Width = maxV.X - minV.X, Height = maxV.Y - minV.Y})\nend}\nRegion3 = {new = function(minVec, maxVec)\n    local mn = minVec or Vector3.new(0,0,0)\n    local mx = maxVec or Vector3.new(0,0,0)\n    local sz = Vector3.new(mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z)\n    return _valueType("Region3", {CFrame = CFrame.new((mn.X+mx.X)/2,(mn.Y+mx.Y)/2,(mn.Z+mx.Z)/2), Size = sz})\nend}\nPhysicalProperties = {new = function(density, friction, elasticity, frictionWeight, elasticityWeight) return _valueType("PhysicalProperties", {Density = _num(density, 1), Friction = _num(friction, 0.3), Elasticity = _num(elasticity, 0.5), FrictionWeight = _num(frictionWeight, 1), ElasticityWeight = _num(elasticityWeight, 1)}) end}\n_makeCFrame = function(x, y, z)\n    local ox, oy, oz = _num(x), _num(y), _num(z)\n    local obj = {X = ox, Y = oy, Z = oz}\n    obj.Position = Vector3.new(ox, oy, oz)\n    obj.p = obj.Position\n    obj.LookVector = Vector3.new(0, 0, -1)\n    obj.RightVector = Vector3.new(1, 0, 0)\n    obj.UpVector = Vector3.new(0, 1, 0)\n    obj.Inverse = function(self) return _makeCFrame(-ox, -oy, -oz) end\n    obj.ToObjectSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox2 - ox, oy2 - oy, oz2 - oz)\n    end\n    obj.ToWorldSpace = function(self, other)\n        local ox2 = (other and (other.X or 0)) or 0\n        local oy2 = (other and (other.Y or 0)) or 0\n        local oz2 = (other and (other.Z or 0)) or 0\n        return _makeCFrame(ox + ox2, oy + oy2, oz + oz2)\n    end\n    obj.PointToObjectSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) - ox,\n            (point and point.Y or 0) - oy,\n            (point and point.Z or 0) - oz\n        )\n    end\n    obj.PointToWorldSpace = function(self, point)\n        return Vector3.new(\n            (point and point.X or 0) + ox,\n            (point and point.Y or 0) + oy,\n            (point and point.Z or 0) + oz\n        )\n    end\n    return setmetatable(obj, {\n        __typeof = "CFrame",\n        __index = function(self, key) return rawget(self, key) end,\n        __mul = function(a, b)\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "CFrame" then\n                return _makeCFrame(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            if getMetatableFunction(b) and getMetatableFunction(b).__typeof == "Vector3" then\n                return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)\n            end\n            return a\n        end,\n        __eq = function(a, b) return typeFunction(b) == "table" and a.X == b.X and a.Y == b.Y and a.Z == b.Z end,\n        __tostring = function(a) return ("CFrame.new(%s, %s, %s)"):format(a.X, a.Y, a.Z) end,\n    })\nend\nCFrame = {\n    new = function(x, y, z) return _makeCFrame(x, y, z) end,\n    Angles = function() return _makeCFrame(0, 0, 0) end,\n    lookAt = function(origin, target) return _makeCFrame(origin and origin.X or 0, origin and origin.Y or 0, origin and origin.Z or 0) end,\n    LookAt = function(origin, target) return CFrame.lookAt(origin, target) end,\n    fromEulerAnglesXYZ = function() return _makeCFrame(0, 0, 0) end,\n    fromEulerAnglesYXZ = function() return _makeCFrame(0, 0, 0) end,\n    fromAxisAngle = function() return _makeCFrame(0, 0, 0) end,\n    fromMatrix = function(pos) return _makeCFrame(pos and pos.X or 0, pos and pos.Y or 0, pos and pos.Z or 0) end,\n    fromOrientation = function() return _makeCFrame(0, 0, 0) end,\n}\nCFrame.identity = CFrame.new(0, 0, 0)\nsetmetatable(CFrame, {__call = function(_, ...) return _.new(...) end})\nPathWaypoint = createTypeDa("PathWaypoint", {new = true})\nAxes = createTypeDa("Axes", {new = true})\nFaces = createTypeDa("Faces", {new = true})\nVector3int16 = createTypeDa("Vector3int16", {new = true})\nVector2int16 = createTypeDa("Vector2int16", {new = true})\nCatalogSearchParams = createTypeDa("CatalogSearchParams", {new = true})\nDateTime = {\n    now = function()\n        return DateTime.fromUnixTimestamp(os.time())\n    end,\n    fromUnixTimestamp = function(ts)\n        ts = toNumberFunction(ts) or 0\n        local dt = setmetatable({UnixTimestamp = ts, UnixTimestampMillis = ts * 1000}, {\n            __typeof = "DateTime",\n            __index = function(self, key)\n                if key == "UnixTimestamp" then return ts end\n                if key == "UnixTimestampMillis" then return ts * 1000 end\n                if key == "FormatUniversalTime" then\n                    return function(self2, fmt, locale)\n                        -- convert unix timestamp to date components\n                        local t = os.date("!*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "FormatLocalTime" then\n                    return function(self2, fmt, locale)\n                        local t = os.date("*t", ts)\n                        local result = fmt\n                        result = string.gsub(result, "YYYY", string.format("%04d", t.year))\n                        result = string.gsub(result, "YY", string.format("%02d", t.year % 100))\n                        result = string.gsub(result, "MM", string.format("%02d", t.month))\n                        result = string.gsub(result, "DD", string.format("%02d", t.day))\n                        result = string.gsub(result, "HH", string.format("%02d", t.hour))\n                        result = string.gsub(result, "mm", string.format("%02d", t.min))\n                        result = string.gsub(result, "SS", string.format("%02d", t.sec))\n                        return result\n                    end\n                end\n                if key == "ToIsoDate" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return string.format("%04d-%02d-%02dT%02d:%02d:%02dZ", t.year, t.month, t.day, t.hour, t.min, t.sec)\n                    end\n                end\n                if key == "ToUniversalTime" then\n                    return function(self2)\n                        local t = os.date("!*t", ts)\n                        return {Year=t.year,Month=t.month,Day=t.day,Hour=t.hour,Minute=t.min,Second=t.sec,Millisecond=0}\n                    end\n                end\n            end,\n        })\n        return dt\n    end,\n    fromUnixTimestampMillis = function(ms)\n        return DateTime.fromUnixTimestamp(math.floor((toNumberFunction(ms) or 0) / 1000))\n    end,\n    fromIsoDate = function(iso)\n        return DateTime.fromUnixTimestamp(0)\n    end,\n}\nRandom = {new = function(seed)\n        local obj = {}\n        function obj:NextNumber(min, max) return (min or 0) + 0.5 * ((max or 1) - (min or 0)) end\n        function obj:NextInteger(min, max) return math.floor((min or 1) + 0.5 * ((max or 100) - (min or 1))) end\n        function obj:NextUnitVector() return Vector3.new(0.577, 0.577, 0.577) end\n        function obj:Shuffle(tab) return tab end\n        function obj:Clone() return Random.new() end\n        return obj\n    end}\nsetmetatable(Random, {__call = function(_, seed) return _.new(seed) end})\nEnum = createProxyObject("Enum", true)\nlocal enumMeta = debugLibrary.getmetatable(Enum)\nenumMeta.__index = function(_, key)\n    if key == proxyList or key == "__proxy_id" then return rawget(_, key) end\n    local enumName = "Enum." .. formatValue(key)\n    if not _at.enum[enumName] then\n        local enumProxy = createProxyObject(enumName, false)\n        dumperState.registry[enumProxy] = enumName\n        _at.enum[enumName] = enumProxy\n    end\n    return _at.enum[enumName]\nend\nInstance = {new = function(className, parent)\n        local name = formatValue(className)\n        local _validClasses = {\n            Part=1,MeshPart=1,UnionOperation=1,SpecialMesh=1,BlockMesh=1,CylinderMesh=1,\n            Model=1,Folder=1,Tool=1,LocalScript=1,Script=1,ModuleScript=1,\n            RemoteEvent=1,RemoteFunction=1,BindableEvent=1,BindableFunction=1,\n            Frame=1,ScreenGui=1,SurfaceGui=1,BillboardGui=1,TextLabel=1,TextButton=1,\n            TextBox=1,ImageLabel=1,ImageButton=1,ScrollingFrame=1,ViewportFrame=1,\n            UIListLayout=1,UIGridLayout=1,UITableLayout=1,UIPadding=1,UICorner=1,\n            UIStroke=1,UIScale=1,UIAspectRatioConstraint=1,UISizeConstraint=1,\n            UITextSizeConstraint=1,UIFlexItem=1,UIGradient=1,UIPageLayout=1,\n            Humanoid=1,HumanoidDescription=1,Animator=1,Animation=1,\n            Sound=1,SoundGroup=1,Attachment=1,Motor6D=1,Weld=1,WeldConstraint=1,\n            BallSocketConstraint=1,HingeConstraint=1,SpringConstraint=1,RodConstraint=1,\n            RopeConstraint=1,AlignPosition=1,AlignOrientation=1,\n            ForceField=1,Decal=1,Texture=1,SelectionBox=1,SelectionSphere=1,\n            PointLight=1,SpotLight=1,SurfaceLight=1,Sky=1,Atmosphere=1,Clouds=1,\n            Beam=1,Trail=1,ParticleEmitter=1,Fire=1,Smoke=1,Sparkles=1,\n            Camera=1,Backpack=1,Hat=1,Accessory=1,Shirt=1,Pants=1,ShirtGraphic=1,\n            CharacterMesh=1,BodyColors=1,\n            IntValue=1,StringValue=1,BoolValue=1,NumberValue=1,Vector3Value=1,\n            CFrameValue=1,Color3Value=1,ObjectValue=1,RayValue=1,BrickColorValue=1,\n            ClickDetector=1,ProximityPrompt=1,Dialog=1,DialogChoice=1,\n            SpawnLocation=1,SeatPart=1,VehicleSeat=1,\n            WedgePart=1,CornerWedgePart=1,TrussPart=1,\n            IntersectOperation=1,NegateOperation=1,\n            PathfindingLink=1,PathfindingModifier=1,\n            Configuration=1,LocalizationTable=1,\n            NoCollisionConstraint=1,RigidConstraint=1,\n            EditableMesh=1,EditableImage=1,\n            LinearVelocity=1,AngularVelocity=1,LineForce=1,VectorForce=1,Torque=1,\n            SurfaceAppearance=1,SpecialMesh=1,SelectionBox=1,\n        }\n        if not _validClasses[name] then\n            errorFunction("Unable to create an Instance of type \"" .. name .. "\"", 2)\n        end\n        local proxy = createProxyObject(name, false)\n        local varName = registerVariable(proxy, name)\n        -- class-specific default properties\n        local _classDefaults = {\n            SkateboardController = {Steer=0, Throttle=0},\n            BallSocketConstraint = {LimitsEnabled=false, UpperAngle=45, TwistLimitsEnabled=false, TwistLowerAngle=-45, TwistUpperAngle=45, MaxFrictionTorque=0, Restitution=0},\n            HingeConstraint     = {LimitsEnabled=false, UpperAngle=45, LowerAngle=-45, AngularVelocity=0, MotorMaxTorque=0, Restitution=0},\n            SpringConstraint    = {Coilcount=5, Damping=1, FreeLength=5, LimitsEnabled=false, MaxLength=5, MinLength=0, Stiffness=100, Visible=false},\n            RodConstraint       = {Length=5, LimitAngle0=0, LimitAngle1=0},\n            RopeConstraint      = {Length=5},\n            PrismaticConstraint = {LimitsEnabled=false, UpperLimit=5, LowerLimit=0, Velocity=0},\n            TorsionSpringConstraint = {Damping=1, Stiffness=100, Restitution=0},\n            WeldConstraint      = {},\n            Motor6D             = {CurrentAngle=0, DesiredAngle=0, MaxVelocity=0},\n            ForceField          = {Visible=true},\n            Sound               = {Volume=0.5, PlaybackSpeed=1, TimePosition=0, IsPlaying=false, IsPaused=false, Looped=false, RollOffMaxDistance=10000, RollOffMinDistance=10},\n            ScreenGui           = {Enabled=true, DisplayOrder=0, IgnoreGuiInset=false, ResetOnSpawn=true},\n            Frame               = {BackgroundTransparency=0, BorderSizePixel=1, Visible=true, ZIndex=1, LayoutOrder=0},\n            TextLabel           = {Text="", TextTransparency=0, TextSize=14, TextWrapped=false, RichText=false, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            TextButton          = {Text="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, Modal=false},\n            TextBox             = {Text="", PlaceholderText="", TextTransparency=0, TextSize=14, BackgroundTransparency=0, Visible=true, ZIndex=1, ClearTextOnFocus=true},\n            ImageLabel          = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            ImageButton         = {ImageTransparency=0, BackgroundTransparency=0, Visible=true, ZIndex=1},\n            Part                = {Anchored=false, CanCollide=true, Locked=false, Transparency=0, Reflectance=0, Mass=1},\n            MeshPart            = {Anchored=false, CanCollide=true, Transparency=0},\n            Humanoid            = {Health=100, MaxHealth=100, WalkSpeed=16, JumpPower=50, JumpHeight=7.2, HipHeight=2, AutoRotate=true, PlatformStand=false},\n            RemoteEvent         = {},\n            RemoteFunction      = {},\n            BindableEvent       = {},\n            BindableFunction    = {},\n            Animator            = {},\n            LocalizationTable   = {SourceLocaleId="en-us"},\n            Animation           = {AnimationId=""},\n            Attachment          = {},\n            AlignPosition       = {RigidityEnabled=false, MaxForce=1e6, MaxVelocity=1e6, Responsiveness=200},\n            AlignOrientation    = {RigidityEnabled=false, MaxTorque=1e6, MaxAngularVelocity=1e6, Responsiveness=200},\n            LinearVelocity      = {MaxForce=0, VectorVelocity=nil, VelocityConstraintMode=nil, Attachment0=nil},\n            SurfaceAppearance   = {ColorMap=nil, NormalMap=nil, RoughnessMap=nil, MetalnessMap=nil},\n        }\n        local defaults = _classDefaults[name] or {}\n        defaults.ClassName = name\n        defaults.Name = name\n        defaults.Archivable = true\n        dumperState.property_store[proxy] = defaults\n        if parent then\n            local parentPath = dumperState.registry[parent] or serializeValue(parent)\n            emitOutput(string.format("local %s = Instance.new(%s, %s)", varName, formatStringLiteral(name), parentPath))\n            _setParent(proxy, parent)\n        else\n            emitOutput(string.format("local %s = Instance.new(%s)", varName, formatStringLiteral(name)))\n        end\n        return proxy\n    end}\ngame = createProxyObject("game", true)\nworkspace = createProxyObject("workspace", true)\nscript = createProxyObject("script", true)\ndumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}\nlocal function seedCoreRobloxInstances()\n    dumperState.property_store[game] = {\n        Name = "Game", ClassName = "DataModel", JobId = "00000000-0000-4000-8000-000000000001",\n        PlaceId = numericArg, GameId = numericArg + 864197532, placeId = numericArg, gameId = numericArg + 864197532,\n        PlaceVersion = 1, CreatorId = 0, CreatorType = Enum.CreatorType.User\n    }\n    dumperState.property_store[workspace] = {\n        Name = "Workspace", ClassName = "Workspace", Parent = game, Gravity = 196.2, DistributedGameTime = 1,\n        StreamingEnabled = false\n    }\n    _setParent(workspace, game)\n    _at.svcCache.Workspace = workspace\n\n    local players = _at.svcCache.Players or createProxyObject("Players", false, game)\n    _at.svcCache.Players = players\n    dumperState.registry[players] = "Players"\n    dumperState.property_store[players] = {Name = "Players", ClassName = "Players", Parent = game, MaxPlayers = 12, RespawnTime = 5}\n    _setParent(players, game)\n\n    local lp = _at.localPlayer or createProxyObject("LocalPlayer", false, players)\n    _at.localPlayer = lp\n    dumperState.registry[lp] = "LocalPlayer"\n    dumperState.property_store[lp] = {\n        Name = "Player", ClassName = "Player", Parent = players, UserId = 1, DisplayName = "Player",\n        MembershipType = Enum.MembershipType.None, FollowUserId = 0, AccountAge = 1000,\n        CameraMinZoomDistance = 0, CameraMaxZoomDistance = 400,\n        AutoJumpEnabled = true, Neutral = true, Team = nil, LocaleId = "en-us",\n        SimulationRadius = 0, MaxSimulationRadius = 0,\n    }\n    _setParent(lp, players)\n\n    local function ensureChild(parent, name, className, props)\n        local child = createProxyObject(name, false, parent)\n        dumperState.registry[child] = name\n        props = props or {}\n        props.Name = props.Name or name\n        props.ClassName = props.ClassName or className or name\n        props.Parent = parent\n        dumperState.property_store[child] = props\n        _setParent(child, parent)\n        if serviceNames[props.ClassName] then\n            _at.svcCache[props.ClassName] = child\n        end\n        return child\n    end\n\n    ensureChild(lp, "PlayerGui", "PlayerGui")\n    ensureChild(lp, "Backpack", "Backpack")\n    local playerScripts = ensureChild(lp, "PlayerScripts", "PlayerScripts")\n    ensureChild(playerScripts, "PlayerModule", "ModuleScript")\n    ensureChild(playerScripts, "RbxCharacterSounds", "LocalScript")\n    ensureChild(workspace, "Camera", "Camera", {\n        CFrame = CFrame.new(0, 10, 0), FieldOfView = 70, ViewportSize = Vector2.new(1920, 1080),\n        CameraType = Enum.CameraType.Custom, NearPlaneZ = -0.1\n    })\n    ensureChild(game, "ReplicatedStorage", "ReplicatedStorage")\n    ensureChild(game, "Lighting", "Lighting", {ClockTime = 14, FogEnd = 100000, Ambient = Color3.fromRGB(128, 128, 128), OutdoorAmbient = Color3.fromRGB(128, 128, 128)})\n    ensureChild(game, "SoundService", "SoundService", {RolloffScale = 1, AmbientReverb = Enum.ReverbType.NoReverb})\n    ensureChild(game, "RunService", "RunService")\n    ensureChild(game, "TweenService", "TweenService")\n    ensureChild(game, "HttpService", "HttpService", {HttpEnabled = false})\n    local networkClient = ensureChild(game, "NetworkClient", "NetworkClient")\n    ensureChild(networkClient, "ClientReplicator", "ClientReplicator")\n    local ugc = ensureChild(game, "Ugc", "Folder")\n    ensureChild(ugc, "Chat", "Chat")\n    ensureChild(game, "CollectionService", "CollectionService")\n    ensureChild(game, "TextService", "TextService")\n    ensureChild(game, "GuiService", "GuiService")\n    ensureChild(game, "ContentProvider", "ContentProvider")\nend\nseedCoreRobloxInstances()\ntask = {\n    wait = function(sec)\n        if sec then emitOutput(string.format("task.wait(%s)", serializeValue(sec))) else emitOutput("task.wait()") end\n        -- inside a spawn body, throw to break while-true loops after one iteration\n        if _at.spawnDepth and _at.spawnDepth > 0 then\n            errorFunction("__spawn_yield__", 0)\n        end\n        -- resume any deferred Heartbeat coroutines now that conn locals are assigned\n        if _at.pendingHeartbeat and #_at.pendingHeartbeat > 0 then\n            local pending = _at.pendingHeartbeat\n            _at.pendingHeartbeat = {}\n            for _, co in ipairs(pending) do\n                pcall(coroutine.resume, co)\n            end\n        end\n        for inst, props in pairsFunction(dumperState.property_store) do\n            if props.ClassName == "Part" and props.Anchored == false and _at.vectors[props.Position] then\n                local v = _at.vectors[props.Position]\n                props.Position = Vector3.new(v.x, v.y - 1, v.z)\n            end\n        end\n        return sec or 0.03, osLibrary.clock()\n    end,\n    spawn = function(func, ...)\n        local args = {...}\n        emitOutput("task.spawn(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        elseif typeFunction(func) == "thread" then\n            xpcallFunction( function() coroutine.resume(func, table.unpack(args)) end, function(err) emitOutput("-- [Error in spawn] " .. toStringFunction(err)) end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n        local co = coroutine.create(function() end)\n        _at.threadLike[co] = true\n        local wrapper = setmetatable({}, {\n            __call = function() return true end,\n            __tostring = function() return "thread: 0x0" end,\n        })\n        _at.threadLike[wrapper] = true\n        return wrapper\n    end,\n    delay = function(sec, func, ...)\n        local args = {...}\n        emitOutput(string.format("task.delay(%s, function()", serializeValue(sec or 0)))\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        while dumperState.pending_iterator do\n            dumperState.indent = dumperState.indent - 1\n            emitOutput("end")\n            dumperState.pending_iterator = false\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    defer = function(func, ...)\n        local args = {...}\n        emitOutput("task.defer(function()")\n        dumperState.indent = dumperState.indent + 1\n        if typeFunction(func) == "function" then\n            xpcallFunction( function() func(table.unpack(args)) end, function() end )\n        end\n        dumperState.indent = dumperState.indent - 1\n        emitOutput("end)")\n    end,\n    cancel = function(thread) emitOutput("task.cancel(thread)") end,\n    synchronize = function() emitOutput("task.synchronize()") end,\n    desynchronize = function() emitOutput("task.desynchronize()") end\n}\nwait = function(sec)\n    if sec then emitOutput(string.format("wait(%s)", serializeValue(sec))) else emitOutput("wait()") end\n    task.wait(sec)\n    return sec or 0.03, osLibrary.clock()\nend\ndelay = function(sec, func)\n    emitOutput(string.format("delay(%s, function()", serializeValue(sec or 0)))\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then xpcallFunction(func, function() end) end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\nspawn = function(func)\n    emitOutput("spawn(function()")\n    dumperState.indent = dumperState.indent + 1\n    if typeFunction(func) == "function" then\n        -- limit spawn bodies: run once then break out of any while true\n        local _spawnDepth = (_at.spawnDepth or 0) + 1\n        if _spawnDepth <= 2 then\n            _at.spawnDepth = _spawnDepth\n            xpcallFunction(func, function() end)\n            _at.spawnDepth = _spawnDepth - 1\n        end\n    end\n    dumperState.indent = dumperState.indent - 1\n    emitOutput("end)")\nend\ntick = function() return osLibrary.time() end\ntime = function() return osLibrary.clock() end\nelapsedTime = function() return osLibrary.clock() end\nlocal globalEnv = {}\nlocal dummy = 999999999\nlocal function getDummy(key, val) return val end\nlocal function setupEnv()\n    local env = {}\n    setmetatable(env, {\n        __call = function(self, ...) return self end,\n        __index = function(self, key)\n            if _G[key] ~= nil then return getDummy(key, _G[key]) end\n            if key == "game" then return game end\n            if key == "workspace" then return workspace end\n            if key == "script" then return script end\n            if key == "Enum" then return Enum end\n            return nil\n        end,\n        __newindex = function(self, key, val)\n            _G[key] = val\n            globalEnv[key] = 0\n            emitOutput(string.format("_G.%s = %s", formatValue(key), serializeValue(val)))\n        end\n    })\n    return env\nend\n_G.G = setupEnv()\n_G.g = setupEnv()\n_G.ENV = setupEnv()\n_G.env = setupEnv()\n_G.E = setupEnv()\n_G.e = setupEnv()\n_G.L = setupEnv()\n_G.l = setupEnv()\n_G.F = setupEnv()\n_G.f = setupEnv()\nlocal function createGetGenv(path)\n    local proxy = {}\n    local meta = {}\n    local restricted = {"hookfunction", "hookmetamethod", "newcclosure", "replaceclosure", "checkcaller", "iscclosure", "islclosure", "getrawmetatable", "setreadonly", "make_writeable", "getrenv", "getgc", "getinstances"}\n    local function formatPath(d, k)\n        local prop = formatValue(k)\n        if prop:match("^[%a_][%w_]*$") then\n            if d then return d .. "." .. prop end\n            return prop\n        else\n            local escaped = prop:gsub("'", "\\\'")\n            if d then return d .. "['" .. escaped .. "']" end\n            return "['" .. escaped .. "']"\n        end\n    end\n    meta.__index = function(_, key)\n        if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n        return _G[key]\n    end\n    meta.__newindex = function(_, key, val)\n        local fullPath = formatPath(path, key)\n        emitOutput(string.format("getgenv().%s = %s", fullPath, serializeValue(val)))\n    end\n    meta.__call = function() return proxy end\n    meta.__pairs = function() return function() return nil end, nil, nil end\n    return setmetatable(proxy, meta)\nend\nlocal exploitFuncs = {\n    getgenv = function() return createGetGenv(nil) end,\n    getrenv = function() return _G end,\n    getsenv = function() return {} end,\n    getfenv = function(depth)\n        -- always return the same proxy table so getfenv(0)==getfenv(1)\n        if not _at.fenvCache then\n            _at.fenvCache = setmetatable({}, {\n                __index = function(_, key)\n                    if key == "c" or key == "fenv" or key == "ReplicatedStorage" then return nil end\n                    return _G[key]\n                end,\n                __newindex = function(_, k, v) rawset(_, k, v) end\n            })\n        end\n        return _at.fenvCache\n    end,\n    setfenv = function(func, env)\n        if typeFunction(func) ~= "function" then return end\n        local i = 1\n        while true do\n            local name = debugLibrary.getupvalue(func, i)\n            if name == "_ENV" then debugLibrary.setupvalue(func, i, env) break\n            elseif not name then break end\n            i = i + 1\n        end\n        return func\n    end,\n    hookfunction = function(f, h) return f end,\n    hookmetamethod = function(x, method, hook)\n        local methodName = formatValue(method)\n        if typeFunction(hook) == "function" then\n            _at.metaHooks[methodName] = hook\n        end\n        if methodName == "__index" then\n            return function(obj, key)\n                local mt = isProxy(obj) and debugLibrary.getmetatable(obj)\n                if mt and typeFunction(mt.__index) == "function" then\n                    local saved = _at.metaHooks[methodName]\n                    _at.metaHooks[methodName] = nil\n                    local ok, result = pcallFunction(mt.__index, obj, key)\n                    _at.metaHooks[methodName] = saved\n                    if ok then return result end\n                end\n                return nil\n            end\n        end\n        if methodName == "__namecall" then\n            return function(obj, ...)\n                local methodToCall = _at.currentNamecallMethod\n                if methodToCall and obj then\n                    local member = obj[methodToCall]\n                    if typeFunction(member) == "function" then\n                        local saved = _at.metaHooks[methodName]\n                        _at.metaHooks[methodName] = nil\n                        local ok, result = pcallFunction(member, obj, ...)\n                        _at.metaHooks[methodName] = saved\n                        if ok then return result end\n                    end\n                end\n                return nil\n            end\n        end\n        return function() end\n    end,\n    getrawmetatable = function(x)\n        if isProxy(x) then\n            -- all Instance proxies share ONE metatable so rawequal(mt1,mt2)==true\n            if not _at.sharedInstanceMeta then\n                local mt = {}\n                -- __index must be a C function so debug.getinfo says what=="C"\n                -- use a newproxy userdata with a C-backed metatable trick:\n                -- we tag a wrapper as cclosure so getinfo returns "C"\n                local indexFn = function() end\n                if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n                _at.cclosureSet[indexFn] = true\n                mt.__index = indexFn\n                mt.__newindex = function() end\n                mt.__namecall = function() end\n                mt.__len = function() return 0 end\n                mt.__tostring = function() return "Instance" end\n                _at.sharedInstanceMeta = mt\n            end\n            return _at.sharedInstanceMeta\n        end\n        return getmetatable(x) or {}\n    end,\n    setrawmetatable = function(x, mt) return x end,\n    getnamecallmethod = function() return _at.currentNamecallMethod or "__namecall" end,\n    setnamecallmethod = function(m) _at.currentNamecallMethod = formatValue(m) end,\n    checkcaller = function() return true end,\n    islclosure = function(f)\n        if isProxy(f) then return false end\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return false end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return false end\n        return false\n    end,\n    iscclosure = function(f)\n        if typeFunction(f) ~= "function" then return false end\n        if _at.cclosureSet and _at.cclosureSet[f] then return true end\n        local info = debugLibrary.getinfo(f, "S")\n        if info and info.what == "C" then return true end\n        return false\n    end,\n    newcclosure = function(f)\n        if typeFunction(f) ~= "function" then return f end\n        if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end\n        local wrapper = function(...) return f(...) end\n        _at.cclosureSet[wrapper] = true\n        return wrapper\n    end,\n    clonefunction = function(f) return f end,\n    request = function(req)\n        emitOutput(string.format("request(%s)", serializeValue(req)))\n        table.insert(dumperState.string_refs, {value = req.Url or req.url or "unknown", hint = "HTTP Request"})\n        return {Success = true, StatusCode = 200, StatusMessage = "OK", Headers = {}, Body = "{}"}\n    end,\n    http_request = function(req) return exploitFuncs.request(req) end,\n    syn = {request = function(req) return exploitFuncs.request(req) end},\n    http = {request = function(req) return exploitFuncs.request(req) end},\n    HttpPost = function(url, data)\n        emitOutput(string.format("HttpPost(%s, %s)", formatValue(url), formatValue(data)))\n        return "{}"\n    end,\n    setclipboard = function(data) emitOutput(string.format("setclipboard(%s)", serializeValue(data))) end,\n    getclipboard = function() return '"' end,
    identifyexecutor = function() return "Kolenvlogger", "1.0" end,
    getexecutorname = function() return "Kolenvlogger" end,
    gethui = function()
        local hui = createProxyObject("HiddenUI", false)
        registerVariable(hui, "HiddenUI")
        emitOutput(string.format("local %s = gethui()", dumperState.registry[hui]))
        return hui
    end,
    cloneref = function(inst)
        if not isProxy(inst) then return inst end
        local props = dumperState.property_store[inst] or {}
        local className = props.ClassName or dumperState.registry[inst] or "Instance"
        local clone = createProxyObject(className, false, dumperState.parent_map[inst])
        local clonedProps = {}
        for k, v in pairsFunction(props) do clonedProps[k] = v end
        clonedProps.ClassName = clonedProps.ClassName or className
        clonedProps.Name = clonedProps.Name or props.Name or className
        dumperState.property_store[clone] = clonedProps
        dumperState.registry[clone] = (dumperState.registry[inst] or className) .. "_cloneref"
        _at.refBase[clone] = _at.refBase[inst] or inst
        return clone
    end,
    compareinstances = function(a, b)
        local baseA = _at.refBase[a] or a
        local baseB = _at.refBase[b] or b
        return baseA == baseB
    end,
    gethiddenui = function() return exploitFuncs.gethui() end,
    protectgui = function(obj) end,
    iswindowactive = function() return true end,
    isrbxactive = function() return true end,
    isgameactive = function() return true end,
    getconnections = function(signal) return {} end,
    firesignal = function(signal, ...) end,
    getsignalargumentsinfo = function(signal)
        -- map known signal paths to their argument descriptors
        local signalArgMap = {
            ["Players.PlayerAdded"]          = {{Name="player", Type="Player"}},
            ["Players.PlayerRemoving"]       = {{Name="player", Type="Player"}},
            ["Players.PlayerMembershipChanged"] = {{Name="player", Type="Player"}},
            ["Humanoid.Died"]                = {},
            ["Humanoid.HealthChanged"]       = {{Name="health", Type="number"}},
            ["Humanoid.StateChanged"]        = {{Name="old", Type="EnumItem"}, {Name="new", Type="EnumItem"}},
            ["BasePart.Touched"]             = {{Name="otherPart", Type="BasePart"}},
            ["BasePart.TouchEnded"]          = {{Name="otherPart", Type="BasePart"}},
            ["RunService.Heartbeat"]         = {{Name="deltaTime", Type="number"}},
            ["RunService.RenderStepped"]     = {{Name="deltaTime", Type="number"}},
            ["RunService.Stepped"]           = {{Name="time", Type="number"}, {Name="deltaTime", Type="number"}},
            ["UserInputService.InputBegan"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputEnded"]  = {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["UserInputService.InputChanged"]= {{Name="input", Type="InputObject"}, {Name="gameProcessedEvent", Type="bool"}},
            ["RemoteEvent.OnClientEvent"]    = {{Name="args", Type="Tuple"}},
            ["BindableEvent.Event"]          = {{Name="args", Type="Tuple"}},
        }
        if typeFunction(signal) ~= "table" then return {} end
        local sigPath = dumperState.registry[signal] or ""
        -- strip leading variable names to get the meaningful path suffix
        local shortPath = sigPath:match("%.(.+)$") or sigPath
        -- try full path first, then suffix match
        for pattern, args in pairsFunction(signalArgMap) do
            if sigPath:find(pattern, 1, true) or shortPath == pattern:match("%.(.+)$") then
                return args
            end
        end
        -- generic fallback: return empty table (signal exists but unknown args)
        return {}
    end,
    fireclickdetector = function(detector, dist) end,
    fireproximityprompt = function(prompt) end,
    firetouchinterest = function(a, b, c) end,
    getinstances = function()
        local instances = {}
        for inst in pairsFunction(dumperState.property_store) do
            if isProxy(inst) and (dumperState.property_store[inst].ClassName or dumperState.registry[inst]) then
                table.insert(instances, inst)
            end
        end
        if #instances == 0 then table.insert(instances, game) end
        return instances
    end,
    getnilinstances = function() return {} end,
    getgc = function() return {} end,
    getscripts = function() return {} end,
    getrunningscripts = function()
        -- AT3: must include the Animate script from character, but NOT arbitrary LocalScript instances
        local result = {}
        if _at.animateScript then result[#result+1] = _at.animateScript end
        return result
    end,
    getloadedmodules = function() return {} end,
    getcallingscript = function() return script end,
    -- script info stubs
    getscriptbytecode = function(s) return "" end,
    getscripthash = function(s) return "0000000000000000000000000000000000000000000000000000000000000000" end,
    getscriptclosure = function(s) return function() end end,
    -- property helpers
    isscriptable = function(obj, prop) return true end,
    setscriptable = function(obj, prop, state) return state end,
    getcallbackvalue = function(obj, prop) return nil end,
    -- clipboard
    setrbxclipboard = function(data) emitOutput(string.format("setrbxclipboard(%s)", serializeValue(data))) return true end,
    -- console extras
    rconsolesettitle = function(title) end,
    -- gc / registry
    getreg = function() return {} end,
    filtergc = function(kind, opts, returnOne) return returnOne and nil or {} end,
    -- function utils
    getfunctionhash = function(f) return "0000000000000000000000000000000000000000" end,
    restorefunction = function(f) end,
    -- misc
    messagebox = function(text, caption, flags)
        emitOutput(string.format("messagebox(%s, %s, %s)", serializeValue(text), serializeValue(caption), serializeValue(flags)))
        return 1
    end,
    readfile = function(file)
        emitOutput(string.format("readfile(%s)", formatStringLiteral(file)))
        return _at.files[formatValue(file)] or '"'\n    end,\n    writefile = function(file, content)\n        local key = formatValue(file)\n        _at.files[key] = formatValue(content)\n        _at.files_hidden = _at.files_hidden or {}\n        _at.files_hidden[key] = true  -- mark as hidden from listfiles\n        emitOutput(string.format("writefile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    appendfile = function(file, content)\n        local name = formatValue(file)\n        _at.files[name] = (_at.files[name] or "") .. formatValue(content)\n        emitOutput(string.format("appendfile(%s, %s)", formatStringLiteral(file), serializeValue(content)))\n    end,\n    loadfile = function(file) return function() return createProxyObject("loaded_file", false) end end,\n    listfiles = function(folder)\n        local base = formatValue(folder or "")\n        -- normalize: strip leading slash so "/" matches all files\n        base = base:gsub("^/+", "")\n        local result = {}\n        for name in pairsFunction(_at.folders) do\n            if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n        end\n        for name in pairsFunction(_at.files) do\n            -- skip files marked hidden (written by writefile, not real filesystem files)\n            if not (_at.files_hidden and _at.files_hidden[name]) then\n                if base == "" or name:match("^" .. base:gsub("([^%w])", "%%%1")) then table.insert(result, name) end\n            end\n        end\n        return result\n    end,\n    isfile = function(file) return _at.files[formatValue(file)] ~= nil end,\n    isfolder = function(folder) return _at.folders[formatValue(folder)] == true end,\n    makefolder = function(folder)\n        local name = formatValue(folder)\n        if name ~= "" then\n            -- create all parent folders in the path\n            local path = ""\n            for segment in (name .. "/"):gmatch("([^/]+)/") do\n                path = path == "" and segment or (path .. "/" .. segment)\n                _at.folders[path] = true\n            end\n        end\n        emitOutput(string.format("makefolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfolder = function(folder)\n        local name = formatValue(folder)\n        _at.folders[name] = nil\n        emitOutput(string.format("delfolder(%s)", formatStringLiteral(folder)))\n    end,\n    delfile = function(file)\n        _at.files[formatValue(file)] = nil\n        emitOutput(string.format("delfile(%s)", formatStringLiteral(file)))\n    end,\n    DrawingImmediate = (function()\n        local function makePaint()\n            local cbs = {}\n            return {\n                Connect = function(self, fn)\n                    cbs[#cbs+1] = fn\n                    -- return plain table so typeof(cn)=="table" passes the AT check\n                    return {\n                        Disconnect = function(self)\n                            for i,v in ipairs(cbs) do if v==fn then table.remove(cbs,i) break end end\n                        end,\n                        Connected = true,\n                    }\n                end,\n            }\n        end\n        local pc = {}\n        return {\n            Text = function(...) emitOutput("DrawingImmediate.Text(...)") end,\n            Line = function(...) emitOutput("DrawingImmediate.Line(...)") end,\n            Circle = function(...) emitOutput("DrawingImmediate.Circle(...)") end,\n            GetPaint = function(id) if not pc[id] then pc[id]=makePaint() end return pc[id] end,\n            ClearAll = function() emitOutput("DrawingImmediate.ClearAll()") end,\n        }\n    end)(),\n    Drawing = {\n        new = function(type)\n            local t = formatValue(type)\n            local proxy = createProxyObject("Drawing_" .. t, false)\n            registerVariable(proxy, t)\n            _at.userdata[proxy] = "renderobj"\n            emitOutput(string.format("local %s = Drawing.new(%s)", dumperState.registry[proxy], formatStringLiteral(t)))\n            return proxy\n        end,\n        Fonts = createProxyObject("Drawing.Fonts", false)\n    },\n    isrenderobj = function(obj)\n        if typeFunction(obj) ~= "table" then return false end\n        return _at.userdata[obj] == "renderobj"\n    end,\n    crypt = {\n        base64encode = function(s) return s end,\n        base64decode = function(s) return s end,\n        base64_encode = function(s) return s end,\n        base64_decode = function(s) return s end,\n        encrypt = function(s, k) return s end,\n        decrypt = function(s, k) return s end,\n        hash = function(s) return "hash" end,\n        generatekey = function(len) return string.rep("0", len or 32) end,\n        generatebytes = function(len) return string.rep("\\0", len or 16) end\n    },\n    base64_encode = function(s) return s end,\n    base64_decode = function(s) return s end,\n    base64encode = function(s) return s end,\n    base64decode = function(s) return s end,\n    mouse1click = function() emitOutput("mouse1click()") end,\n    mouse1press = function() emitOutput("mouse1press()") end,\n    mouse1release = function() emitOutput("mouse1release()") end,\n    mouse2click = function() emitOutput("mouse2click()") end,\n    mouse2press = function() emitOutput("mouse2press()") end,\n    mouse2release = function() emitOutput("mouse2release()") end,\n    mousemoverel = function(x, y) emitOutput(string.format("mousemoverel(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousemoveabs = function(x, y) emitOutput(string.format("mousemoveabs(%s, %s)", serializeValue(x), serializeValue(y))) end,\n    mousescroll = function(delta) emitOutput(string.format("mousescroll(%s)", serializeValue(delta))) end,\n    keypress = function(key) emitOutput(string.format("keypress(%s)", serializeValue(key))) end,\n    keyrelease = function(key) emitOutput(string.format("keyrelease(%s)", serializeValue(key))) end,\n    keyclick = function(key) emitOutput(string.format("keyclick(%s)", serializeValue(key))) end,\n    isreadonly = function(t) return false end,\n    setreadonly = function(t, val) return t end,\n    make_writeable = function(t) return t end,\n    make_readonly = function(t) return t end,\n    getthreadidentity = function() return 7 end,\n    setthreadidentity = function(id) end,\n    getidentity = function() return 7 end,\n    setidentity = function(id) end,\n    getthreadcontext = function() return 7 end,\n    setthreadcontext = function(id) end,\n    getcustomasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getsynasset = function(file) return "rbxasset://" .. formatValue(file) end,\n    getinfo = function(func) return {source = "=", what = "Lua", name = "unknown", short_src = "dumper"} end,\n    getconstants = function(func) return {} end,\n    getupvalues = function(func) return {} end,\n    getprotos = function(func) return {} end,\n    getupvalue = function(func, i) return nil end,\n    setupvalue = function(func, i, val) end,\n    setconstant = function(func, i, val) end,\n    getconstant = function(func, i) return nil end,\n    getproto = function(func, i) return function() end end,\n    setproto = function(func, i, f) end,\n    getstack = function(level, i) return nil end,\n    setstack = function(level, i, val) end,\n    debug = {\n        getinfo = function(func, ...)\n            if func == print or func == _G.print or func == warn or func == _G.warn then\n                return {source = "=[C]", what = "C", name = "print", short_src = "[C]"}\n            end\n            if getInfo then return getInfo(func, ...) end\n            return {source = "=[C]", what = "C", short_src = "[C]"}\n        end,\n        getupvalue = debugLibrary.getupvalue or function() return nil end,\n        setupvalue = debugLibrary.setupvalue or function() end,\n        getmetatable = debugLibrary.getmetatable,\n        setmetatable = debugLibrary.setmetatable or setmetatable,\n        traceback = getTraceback or function() return '"' end,
        profilebegin = function() end,
        profileend = function() end,
        sethook = function() end
    },
    rconsoleprint = function(s) end,
    rconsoleclear = function() end,
    rconsolecreate = function() end,
    rconsoledestroy = function() end,
    rconsoleinput = function() return "" end,
    rconsoleinfo = function(s) end,
    rconsolewarn = function(s) end,
    rconsoleerr = function(s) end,
    rconsolename = function(name) end,
    printconsole = function(s) end,
    setfflag = function(flag, val) end,
    getfflag = function(flag) return "" end,
    setfpscap = function(cap) emitOutput(string.format("setfpscap(%s)", serializeValue(cap))) end,
    getfpscap = function() return 60 end,
    isnetworkowner = function(part) return true end,
    gethiddenproperty = function(instance, prop)
        if not isProxy(instance) then return nil, false end
        local props = dumperState.property_store[instance]
        if props and props[prop] ~= nil then return props[prop], true end
        return nil, false
    end,
    sethiddenproperty = function(instance, prop, val)
        if isProxy(instance) then
            local props = dumperState.property_store[instance]
            if props then
                if prop == "DistributedGameTime" then
                    -- don't store the set value; just record a tick base from current real value
                    -- so subsequent reads keep ticking from where they were
                    if not _at._dgtClock then
                        _at._dgtBase = (props[prop] or 1)
                        _at._dgtClock = osLibrary.clock()
                    end
                    -- intentionally do NOT store val - real Roblox ignores the set
                else
                    props[prop] = val
                end
            end
        end
        emitOutput(string.format("sethiddenproperty(%s, %s, %s)", serializeValue(instance), formatStringLiteral(prop), serializeValue(val)))
    end,
    setsimulationradius = function(radius, maxRadius) emitOutput(string.format("setsimulationradius(%s%s)", serializeValue(radius), maxRadius and ", " .. serializeValue(maxRadius) or "")) end,
    getspecialinfo = function(instance) return {} end,
    saveinstance = function(options) emitOutput(string.format("saveinstance(%s)", serializeValue(options or {}))) end,
    decompile = function(script) return "-- decompiled" end,
    lz4compress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4compress", 2) end
        local magic = "\x04\x22\x4d\x18"
        local lenBytes = string.char(
            math.floor(#s / 16777216) % 256,
            math.floor(#s / 65536) % 256,
            math.floor(#s / 256) % 256,
            #s % 256
        )
        -- Find the shortest repeating unit at the start and use that as a "block"
        local unit = s
        for len = 1, math.floor(#s / 2) do
            local candidate = s:sub(1, len)
            local repeated = string.rep(candidate, math.floor(#s / len))
            local remainder = s:sub(#repeated + 1)
            if repeated .. remainder == s then
                unit = candidate
                break
            end
        end
        -- Encode as: magic + origLen + unitLen(2 bytes) + unit + count(2 bytes) + remainder
        local count = math.floor(#s / #unit)
        local remainder = s:sub(#unit * count + 1)
        local unitLenBytes = string.char(math.floor(#unit / 256) % 256, #unit % 256)
        local countBytes = string.char(math.floor(count / 256) % 256, count % 256)
        local remLenBytes = string.char(math.floor(#remainder / 256) % 256, #remainder % 256)
        return magic .. lenBytes .. unitLenBytes .. unit .. countBytes .. remLenBytes .. remainder
    end,
    lz4decompress = function(s)
        if typeFunction(s) ~= "string" then errorFunction("invalid argument to lz4decompress", 2) end
        local magic = "\x04\x22\x4d\x18"
        if #s < 12 or s:sub(1, 4) ~= magic then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local b1, b2, b3, b4 = s:byte(5), s:byte(6), s:byte(7), s:byte(8)
        local origLen = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
        local unitLenHi, unitLenLo = s:byte(9), s:byte(10)
        local unitLen = unitLenHi * 256 + unitLenLo
        if #s < 10 + unitLen + 4 then
            errorFunction("lz4decompress: invalid compressed data", 2)
        end
        local unit = s:sub(11, 10 + unitLen)
        local countHi, countLo = s:byte(11 + unitLen), s:byte(12 + unitLen)
        local count = countHi * 256 + countLo
        local remLenHi, remLenLo = s:byte(13 + unitLen), s:byte(14 + unitLen)
        local remLen = remLenHi * 256 + remLenLo
        local remainder = s:sub(15 + unitLen, 14 + unitLen + remLen)
        return (string.rep(unit, count) .. remainder):sub(1, origLen)
    end,
    MessageBox = function(text, caption, type) return 1 end,
    setwindowactive = function() end,
    setwindowtitle = function(title) end,
    queue_on_teleport = function(code) emitOutput(string.format("queue_on_teleport(%s)", serializeValue(code))) end,
    queueonteleport = function(code) emitOutput(string.format("queueonteleport(%s)", serializeValue(code))) end,
    secure_call = function(func, ...) return func(...) end,
    create_secure_function = function(func) return func end,
    isvalidinstance = function(instance) return instance ~= nil end,
    validcheck = function(instance) return instance ~= nil end
}
for name, func in pairsFunction(exploitFuncs) do
    _G[name] = func
end
local nativeBit32 = bit32
local bitLibrary = {}
local function toBit(n)
    n = (n or 0) % 4294967296
    if n >= 2147483648 then n = n - 4294967296 end
    return math.floor(n)
end
local function toU32(n) return math.floor((n or 0) % 4294967296) end

local function _band(a, b)
    if nativeBit32 then return nativeBit32.band(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bor(a, b)
    if nativeBit32 then return nativeBit32.bor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 == 1 or b % 2 == 1 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _bxor(a, b)
    if nativeBit32 then return nativeBit32.bxor(toU32(a), toU32(b)) end
    a, b = toU32(a), toU32(b)
    local r, p = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then r = r + p end
        a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
    end
    return r
end
local function _lshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return toU32(toU32(n) * (2 ^ bits))
end
local function _rshift(n, bits)
    bits = (bits or 0) % 32
    if bits == 0 then return toU32(n) end
    return math.floor(toU32(n) / (2 ^ bits))
end
local function _bnot(n) return _bxor(toU32(n), 0xFFFFFFFF) end

bitLibrary.tobit = toBit
bitLibrary.tohex = function(n, len)
    return string.format("%0" .. (len or 8) .. "x", toU32(n))
end
bitLibrary.band = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _band(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bxor = function(...)
    local r = toU32(select(1, ...))
    for i = 2, select("#", ...) do r = _bxor(r, toU32(select(i, ...))) end
    return toBit(r)
end
bitLibrary.bnot    = function(n) return toBit(_bnot(n or 0)) end
bitLibrary.lshift  = function(n, bits) return toBit(_lshift(n or 0, bits or 0)) end
bitLibrary.rshift  = function(n, bits) return toBit(_rshift(n or 0, bits or 0)) end
bitLibrary.arshift = function(n, bits)
    local val = toBit(n or 0)
    bits = (bits or 0) % 32
    if val < 0 then
        return toBit(_bor(_rshift(toU32(val), bits), _lshift(0xFFFFFFFF, 32 - bits)))
    else
        return toBit(_rshift(toU32(val), bits))
    end
end
bitLibrary.rol = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_lshift(n, bits), _rshift(n, 32 - bits)))
end
bitLibrary.ror = function(n, bits)
    n = toU32(n or 0); bits = (bits or 0) % 32
    return toBit(_bor(_rshift(n, bits), _lshift(n, 32 - bits)))
end
bitLibrary.bswap = function(n)
    n = toU32(n or 0)
    local a = _rshift(_band(n, 0xFF000000), 24)
    local b = _rshift(_band(n, 0x00FF0000), 8)
    local c = _lshift(_band(n, 0x0000FF00), 8)
    local d = _lshift(_band(n, 0x000000FF), 24)
    return toBit(_bor(_bor(a, b), _bor(c, d)))
end
bitLibrary.countlz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    if _band(n, 0xFFFF0000) == 0 then count = count + 16; n = _lshift(n, 16) end
    if _band(n, 0xFF000000) == 0 then count = count + 8;  n = _lshift(n, 8)  end
    if _band(n, 0xF0000000) == 0 then count = count + 4;  n = _lshift(n, 4)  end
    if _band(n, 0xC0000000) == 0 then count = count + 2;  n = _lshift(n, 2)  end
    if _band(n, 0x80000000) == 0 then count = count + 1   end
    return count
end
bitLibrary.countrz = function(n)
    n = toU32(bitLibrary.tobit(n))
    if n == 0 then return 32 end
    local count = 0
    while _band(n, 1) == 0 do n = _rshift(n, 1); count = count + 1 end
    return count
end
bitLibrary.lrotate = bitLibrary.rol
bitLibrary.rrotate = bitLibrary.ror
bitLibrary.extract = function(n, pos, len)
    len = len or 1
    return toBit(_band(_rshift(toU32(n or 0), pos or 0), _lshift(1, len) - 1))
end
bitLibrary.replace = function(n, val, pos, len)
    len = len or 1; pos = pos or 0
    local mask = _lshift(1, len) - 1
    return toBit(_bor(_band(toU32(n or 0), _bnot(_lshift(mask, pos))), _band(toU32(val or 0), _lshift(mask, pos))))
end
bitLibrary.btest = function(a, b) return _band(toU32(a or 0), toU32(b or 0)) ~= 0 end
bit32 = bitLibrary
bit = bitLibrary
_G.bit = bitLibrary
_G.bit32 = bitLibrary
table.getn = table.getn or function(t) return #t end
table.foreach = table.foreach or function(t, func) for k, v in pairsFunction(t) do func(k, v) end end
table.foreachi = table.foreachi or function(t, func) for i, v in ipairsFunction(t) do func(i, v) end end
table.find = table.find or function(t, value, init)
    for i = (init or 1), #t do
        if t[i] == value then return i end
    end
    return nil
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairsFunction(t) do out[k] = v end
    return out
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clear = table.clear or function(t) for k in pairsFunction(t) do t[k] = nil end end
table.find = table.find or function(t, val, init)
    for i = init or 1, #t do
        if t[i] == val then return i end
    end
    return nil
end
table.clear = table.clear or function(t)
    for k in pairs(t) do t[k] = nil end
end
do
    local _frozen = setmetatable({}, {__mode="k"})
    table.freeze = table.freeze or function(t) _frozen[t] = true; return t end
    table.isfrozen = table.isfrozen or function(t) return _frozen[t] == true end
end
table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
table.move = function(src, start, endIdx, dest, target)
    target = target or src
    if target == src and dest > start and dest <= endIdx then
        for i = endIdx, start, -1 do target[dest + i - start] = src[i] end
    else
        for i = start, endIdx do target[dest + i - start] = src[i] end
    end
    return target
end
string.split = string.split or function(str, sep)
    local t = {}
    for match in string.gmatch(str, "([^" .. (sep or "%s") .. "]+)") do table.insert(t, match) end
    return t
end
if not math.frexp then
    math.frexp = function(x)
        if x == 0 then return 0, 0 end
        local exp = math.floor(math.log(math.abs(x)) / math.log(2)) + 1
        local m = x / 2 ^ exp
        return m, exp
    end
end
if not math.ldexp then math.ldexp = function(m, e) return m * 2 ^ e end end
if not utf8 then
    utf8 = {}
    utf8.char = function(...)
        local args = {...}
        local chars = {}
        for _, byte in ipairsFunction(args) do table.insert(chars, string.char(byte % 256)) end
        return table.concat(chars)
    end
    utf8.len = function(s) return #s end
    utf8.codes = function(s)
        local i = 0
        return function() i = i + 1; if i <= #s then return i, string.byte(s, i) end end
    end
end
-- graphemes: bypass nested anti-tamper chain third[1][1][1][1][1][1](first, second)
utf8.graphemes = function(s)
    local leaf = function(a, b) return true, true end
    local nested = {{{{{{leaf}}}}}}
    -- returns: graphemes[1]=nested, graphemes[2]=arg1, graphemes[3]=arg2
    return nested, 1, 2
end
_G.utf8 = utf8
pairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return pairsFunction(t) end
    return function() return nil end, t, nil
end
ipairs = function(t)
    if typeFunction(t) == "table" and not isProxy(t) then return ipairsFunction(t) end
    return function() return nil end, t, 0
end
_G.pairs = pairs
_G.ipairs = ipairs
_G.math = math
_G.table = table
-- override string.dump to prevent source/internal name leaking
local _realStringDump = string.dump
-- build a set of all sandbox-internal functions to block
local _blockedDump = setmetatable({}, {__mode="k"})
string.dump = function(f, ...)
    if isProxy(f) then
        errorFunction("unable to dump given function", 2)
    end
    if _blockedDump[f] then
        errorFunction("unable to dump given function", 2)
    end
    -- block exploit funcs
    for name, val in pairsFunction(exploitFuncs) do
        if val == f then errorFunction("unable to dump given function", 2) end
    end
    -- block any function whose bytecode would leak "dumper.lua" or internal names
    local ok, bc = pcallFunction(_realStringDump, f)
    if ok and typeFunction(bc) == "string" then
        if bc:find("dumper%.lua", 1, true) or
           bc:find("emitOutput", 1, true) or
           bc:find("serializeValue", 1, true) or
           bc:find("ipairsFunction", 1, true) or
           bc:find("pairsFunction", 1, true) or
           bc:find("dumperState", 1, true) then
            errorFunction("unable to dump given function", 2)
        end
        return bc
    end
    errorFunction("unable to dump given function", 2)
end
_G.string = string
_G.os = os
os.execute = function() return nil end
os.exit = function() return nil end
os.remove = function() return nil, "disabled" end
os.rename = function() return nil, "disabled" end
_G.coroutine = coroutine
_G.io = nil
_G.debug = exploitFuncs.debug
_G._realSetHook = setHook
_G.utf8 = utf8
_G.next = next
_G.tostring = tostring
_G.tonumber = tonumber
_G.getmetatable = getmetatable
_G.setmetatable = setmetatable
_G.pcall = function(f, ...)
    local results = {pcallFunction(f, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.xpcall = function(f, errFunc, ...)
    local function wrapper(err)
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then return err end
        if errFunc then return errFunc(err) end
        return err
    end
    local results = {xpcallFunction(f, wrapper, ...)}
    local success = results[1]
    if not success then
        local err = results[2]
        if typeFunction(err) == "string" and err:match("TIMEOUT_FORCED_BY_DUMPER") then errorFunction(err) end
    end
    return table.unpack(results)
end
_G.error = errorFunction
if _G.originalError == nil then _G.originalError = errorFunction end
_G.assert = assert
_G.select = select
_G.type = typeFunction
_G.rawget = rawget
_G.rawset = rawset
_G.rawequal = rawEqualFunction
_G.rawlen = rawlen or function(t) return #t end
_G.unpack = table.unpack or unpack
_G.pack = table.pack or function(...) return {n = select("#", ...), ...} end
_G.task = task
_G.wait = wait
_G.Wait = wait
_G.delay = delay
_G.Delay = delay
_G.spawn = spawn
_G.Spawn = spawn
_G.tick = tick
_G.time = time
_G.elapsedTime = elapsedTime
_G.game = game
_G.Game = game
_G.workspace = workspace
_G.Workspace = workspace
_G.script = script
_G.Enum = Enum
_G.Instance = Instance
_G.Random = Random
_G.Vector3 = Vector3
_G.Vector2 = Vector2
_G.CFrame = CFrame
_G.Color3 = Color3
_G.BrickColor = BrickColor
_G.UDim = UDim
_G.UDim2 = UDim2
_G.TweenInfo = TweenInfo
_G.Rect = Rect
_G.Region3 = Region3
_G.Region3int16 = Region3int16
_G.Ray = Ray
_G.NumberRange = NumberRange
_G.NumberSequence = NumberSequence
_G.NumberSequenceKeypoint = NumberSequenceKeypoint
_G.ColorSequence = ColorSequence
_G.ColorSequenceKeypoint = ColorSequenceKeypoint
_G.PhysicalProperties = PhysicalProperties
_G.Font = Font
_G.RaycastParams = RaycastParams
_G.OverlapParams = OverlapParams
_G.PathWaypoint = PathWaypoint
_G.Axes = Axes
_G.Faces = Faces
_G.Vector3int16 = Vector3int16
_G.Vector2int16 = Vector2int16
_G.CatalogSearchParams = CatalogSearchParams
_G.DateTime = DateTime
settings = function()
    local enumKey = "Enum.QualityLevel.Automatic"
    if not _at.enum[enumKey] then
        local p = createProxyObject(enumKey, false)
        dumperState.registry[p] = enumKey
        _at.enum[enumKey] = p
    end
    local qualityProxy = _at.enum[enumKey]
    return {
        Rendering = {QualityLevel = qualityProxy, FrameRateManager = 0, EagerBulkExecution = false},
        Studio    = {},
        Network   = {IncomingReplicationLag = 0},
        Physics   = {PhysicsEnvironmentalThrottle = createProxyObject("Enum.EnviromentalPhysicsThrottle.DefaultAuto", false)},
    }
end
_G.settings = settings
getmetatable = function(x)
    if _at.userdata[x] then return getMetatableFunction(x) end
    if isProxy(x) then return "The metatable is locked" end
    return getMetatableFunction(x)
end
_G.getmetatable = getmetatable
type = function(x)
    if _at.threadLike[x] then return "thread" end
    if _at.userdata[x] then return "userdata" end
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then return "userdata" end
    return typeFunction(x)
end
_G.type = type
buffer = {
    create = function(size)
        local b = {}
        _at.buffers[b] = string.rep("\0", size or 0)
        return b
    end,
    fromstring = function(s)
        local b = {}
        _at.buffers[b] = formatValue(s)
        return b
    end,
    tostring = function(b)
        return _at.buffers[b] or ""
    end,
    len = function(b)
        return #(_at.buffers[b] or "")
    end,
    copy = function(dst, dstOffset, src, srcOffset, count)
        local srcData = _at.buffers[src] or ""
        local dstData = _at.buffers[dst] or ""
        srcOffset = (srcOffset or 0) + 1
        dstOffset = (dstOffset or 0) + 1
        local chunk = srcData:sub(srcOffset, count and srcOffset + count - 1 or -1)
        local before = dstData:sub(1, dstOffset - 1)
        local after  = dstData:sub(dstOffset + #chunk)
        _at.buffers[dst] = before .. chunk .. after
    end,
    fill = function(b, offset, value, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        count  = count or (#data - offset + 1)
        local fill = string.rep(string.char(value % 256), count)
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + count)
        _at.buffers[b] = before .. fill .. after
    end,
    writestring = function(b, offset, s, count)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        s = formatValue(s)
        if count then s = s:sub(1, count) end
        local before = data:sub(1, offset - 1)
        local after  = data:sub(offset + #s)
        _at.buffers[b] = before .. s .. after
    end,
    readstring = function(b, offset, len)
        local data = _at.buffers[b] or ""
        offset = (offset or 0) + 1
        return data:sub(offset, len and offset + len - 1 or -1)
    end,
    writeu8  = function(b, offset, v) local d=_at.buffers[b] or""; offset=(offset or 0)+1; _at.buffers[b]=d:sub(1,offset-1)..string.char(v%256)..d:sub(offset+1) end,
    readu8   = function(b, offset) local d=_at.buffers[b] or""; return string.byte(d,(offset or 0)+1) or 0 end,
    writeu16 = function(b, offset, v) offset=(offset or 0); buffer.writeu8(b,offset,v%256); buffer.writeu8(b,offset+1,math.floor(v/256)%256) end,
    readu16  = function(b, offset) return buffer.readu8(b,offset) + buffer.readu8(b,(offset or 0)+1)*256 end,
    writeu32 = function(b, offset, v) offset=(offset or 0); for i=0,3 do buffer.writeu8(b,offset+i,math.floor(v/(256^i))%256) end end,
    readu32  = function(b, offset) local v=0; for i=0,3 do v=v+buffer.readu8(b,(offset or 0)+i)*(256^i) end; return v end,
    writei8  = function(b, offset, v) buffer.writeu8(b, offset, v < 0 and v+256 or v) end,
    readi8   = function(b, offset) local v=buffer.readu8(b,offset); return v>=128 and v-256 or v end,
    writei16 = function(b, offset, v) buffer.writeu16(b, offset, v < 0 and v+65536 or v) end,
    readi16  = function(b, offset) local v=buffer.readu16(b,offset); return v>=32768 and v-65536 or v end,
    writei32 = function(b, offset, v) buffer.writeu32(b, offset, v < 0 and v+4294967296 or v) end,
    readi32  = function(b, offset) local v=buffer.readu32(b,offset); return v>=2147483648 and v-4294967296 or v end,
    writef32 = function(b, offset, v) buffer.writeu32(b, offset, math.floor(math.abs(v)*1000)%4294967296) end,
    readf32  = function(b, offset) return buffer.readu32(b,offset)/1000 end,
    writef64 = function(b, offset, v) buffer.writeu32(b, offset, 0); buffer.writeu32(b, (offset or 0)+4, math.floor(math.abs(v)*1000)%4294967296) end,
    readf64  = function(b, offset) return buffer.readu32(b,(offset or 0)+4)/1000 end,
}
_G.buffer = buffer
typeof = function(x)
    if getProxyValue(x) ~= 0 then return "number" end
    if isProxy(x) then
        if _at.typeOverride[x] then return _at.typeOverride[x] end
        local regName = dumperState.registry[x]
        if regName then
            if regName == "Enum" then return "Enums" end
            if regName:match("^Enum%.[^%.]+$") then return "Enum" end
            if regName:match("^Enum%.[^%.]+%.[^%.]+$") then return "EnumItem" end
            if regName:match("Vector3") then return "Vector3" end
            if regName:match("CFrame") then return "CFrame" end
            if regName:match("Color3") then return "Color3" end
            if regName:match("UDim") then return "UDim2" end
        end
        return "Instance"
    end
    if _at.threadLike[x] then return "thread" end
    local mt = getMetatableFunction(x)
    if mt and mt.__typeof then return mt.__typeof end
    return typeFunction(x) == "table" and "table" or typeFunction(x)
end
_G.typeof = typeof
newproxy = function(withMeta)
    local proxy = {}
    _at.userdata[proxy] = true
    if withMeta then
        setmetatable(proxy, {})
    end
    return proxy
end
_G.newproxy = newproxy
tonumber = function(x, base)
    if getProxyValue(x) ~= 0 then return 123456789 end
    return toNumberFunction(x, base)
end
_G.tonumber = tonumber
rawequal = function(a, b) return rawEqualFunction(a, b) end
_G.rawequal = rawequal
tostring = function(x)
    if isProxy(x) then
        local mt = getMetatableFunction(x)
        if mt and mt.__tostring then
            local ok, r = pcallFunction(mt.__tostring, x)
            if ok and r then return r end
        end
        local regName = dumperState.registry[x]
        return regName or "Instance"
    end
    local mt = getMetatableFunction(x)
    if mt and mt.__tostring then
        local ok, r = pcallFunction(mt.__tostring, x)
        if ok and r then return r end
    end
    return toStringFunction(x)
end
_G.tostring = tostring
dumperState.last_http_url = nil
loadstring = function(code, chunkName)
    if typeFunction(code) ~= "string" then return function() return createProxyObject("loaded", false) end end
    local url = dumperState.last_http_url or code
    dumperState.last_http_url = nil
    local libName = nil
    local lowerCode = url:lower()
    local libs = {{pattern = "rayfield", name = "Rayfield"}, {pattern = "orion", name = "OrionLib"}, {pattern = "kavo", name = "Kavo"}, {pattern = "venyx", name = "Venyx"}, {pattern = "sirius", name = "Sirius"}, {pattern = "linoria", name = "Linoria"}, {pattern = "wally", name = "Wally"}, {pattern = "dex", name = "Dex"}, {pattern = "infinite", name = "InfiniteYield"}, {pattern = "hydroxide", name = "Hydroxide"}, {pattern = "simplespy", name = "SimpleSpy"}, {pattern = "remotespy", name = "RemoteSpy"}}
    for _, lib in ipairsFunction(libs) do if lowerCode:find(lib.pattern) then libName = lib.name; break end end
    if libName then
        local proxy = createProxyObject(libName, false)
        dumperState.registry[proxy] = libName
        dumperState.names_used[libName] = true
        if url:match("^https?://") then emitOutput(string.format('local %s = loadstring(game:HttpGet("%s"))()', libName, url)) end
        return function() return proxy end
    end
    if url:match("^https?://") then
        local proxy = createProxyObject("Library", false)
        emitOutput(string.format('local loadstring = loadstring(game:HttpGet("%s"))()', url))
        return function() return proxy end
    end
    if code:match("local%s+a%s*=%s*if%s+true%s+then") then return nil, "attempt to call a nil value" end
    if typeFunction(code) == "string" then code = processString(code) end
    local func, err = loadFunction(code)
    if func then return func end
    local proxy = createProxyObject("LoadedChunk", false)
    return function() return proxy end
end
load = loadstring
_G.loadstring = loadstring
_G.load = loadstring
require = function(module)
    local modName = dumperState.registry[module] or serializeValue(module)
    local proxy = createProxyObject("RequiredModule", false)
    local varName = registerVariable(proxy, "module")
    emitOutput(string.format("local %s = require(%s)", varName, modName))
    return proxy
end
_G.require = require
print = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("print(%s)", table.concat(items, ", ")))
end
_G.print = print
warn = function(...)
    local args = {...}
    local items = {}
    for _, val in ipairsFunction(args) do table.insert(items, serializeValue(val)) end
    emitOutput(string.format("warn(%s)", table.concat(items, ", ")))
end
_G.warn = warn
-- Tag Roblox-like builtins as C closures so iscclosure() returns true for them
do
    if not _at.cclosureSet then _at.cclosureSet = setmetatable({}, {__mode="k"}) end
    local _cbuiltins = {
        print, warn, tick, time, elapsedTime, pcall, xpcall, error, assert,
        tostring, tonumber, type, typeof, rawget, rawset, rawequal, rawlen,
        setmetatable, getmetatable, ipairs, pairs, next, select, unpack,
        require, loadstring, load,
    }
    for _, fn in ipairs(_cbuiltins) do
        if typeFunction(fn) == "function" then
            _at.cclosureSet[fn] = true
        end
    end
end
_G.shared = shared
local globalBase = _G
local globalMeta = setmetatable({}, {
    __index = function(tbl, key)
        if configuration.VERBOSE then printFunction("[VERBOSE] Accessing field: " .. toStringFunction(key)) end
        local val = rawget(globalBase, key)
        if val == nil then val = rawget(_G, key) end
        if configuration.VERBOSE then
            if val ~= nil then
                if typeFunction(val) == "table" then printFunction("[VERBOSE] Found global table: " .. toStringFunction(key))
                elseif typeFunction(val) == "function" then printFunction("[VERBOSE] Found global function: " .. toStringFunction(key))
                else printFunction("[VERBOSE] Found global value: " .. toStringFunction(key) .. " = " .. toStringFunction(val)) end
            else
                printFunction("[VERBOSE] Missing field, providing dummy function: " .. toStringFunction(key))
                val = function() if configuration.VERBOSE then printFunction("[Missing Function] Called: " .. toStringFunction(key) .. " with 0 arguments") end return nil end
            end
        end
        return val
    end,
    __newindex = function(tbl, key, val) rawset(globalBase, key, val) end
})
_G._G = globalMeta
function proxyTable.reset()
    dumperState = {output = {}, indent = 0, registry = {}, reverse_registry = {}, names_used = {}, parent_map = {}, property_store = {}, call_graph = {}, variable_types = {}, string_refs = {}, proxy_id = 0, callback_depth = 0, pending_iterator = false, last_http_url = nil, last_emitted_line = nil, repetition_count = 0, current_size = 0, limit_reached = false, ls_counter = 0, captured_constants = {}}
    _at.mem = {}
    _at.tags = {}
    _at.sigs = {}
    _at.acts = {}
    _at.json = {}
    _at.enum = {}
    _at.svcCache = {}
    _at.typeOverride = {}
    _at.connState = {}
    _at.pendingHeartbeat = {}
    _at.locEntries = {}
    _at.userdata = {}
    _at.localPlayer = nil
    setmetatable(_at.userdata, {__mode = "k"})
    _at.debugIds = {}
    setmetatable(_at.debugIds, {__mode = "k"})
    _at.debugIdCtr = 0
    uiCounters = {}
    game = createProxyObject("game", true)
    workspace = createProxyObject("workspace", true)
    script = createProxyObject("script", true)
    Enum = createProxyObject("Enum", true)
    shared = createProxyObject("shared", true)
    dumperState.property_store[game] = {PlaceId = numericArg, GameId = numericArg, placeId = numericArg, gameId = numericArg}
    dumperState.property_store[script] = {Name = "DumpedScript", Parent = game, ClassName = "LocalScript"}
    _G.game = game; _G.Game = game; _G.workspace = workspace; _G.Workspace = workspace; _G.script = script; _G.Enum = Enum; _G.shared = shared
    local meta = debugLibrary.getmetatable(Enum)
    meta.__index = function(_, key)
        if key == proxyList or key == "__proxy_id" then return rawget(_, key) end
        local enumName = "Enum." .. formatValue(key)
        if not _at.enum[enumName] then
            local enumProxy = createProxyObject(enumName, false)
            dumperState.registry[enumProxy] = enumName
            _at.enum[enumName] = enumProxy
        end
        return _at.enum[enumName]
    end
    seedCoreRobloxInstances()
    if type(_G._bypassOnReset) == "function" then
        local prevOutput = dumperState.output
        local prevOutputCount = #prevOutput
        local prevIndent = dumperState.indent
        local prevLast = dumperState.last_emitted_line
        local prevRep = dumperState.repetition_count
        local prevSize = dumperState.current_size
        local prevLimit = dumperState.limit_reached
        pcall(_G._bypassOnReset)
        for i = #prevOutput, prevOutputCount + 1, -1 do
            prevOutput[i] = nil
        end
        dumperState.output = prevOutput
        dumperState.indent = prevIndent
        dumperState.last_emitted_line = prevLast
        dumperState.repetition_count = prevRep
        dumperState.current_size = prevSize
        dumperState.limit_reached = prevLimit
    end
end
function proxyTable.get_output() return getFullOutput() end
function proxyTable.save(file) return saveToFile(file) end
function proxyTable.get_call_graph() return dumperState.call_graph end
function proxyTable.get_string_refs() return dumperState.string_refs end
function proxyTable.get_stats() return {total_lines = #dumperState.output, remote_calls = #dumperState.call_graph, suspicious_strings = #dumperState.string_refs, proxies_created = dumperState.proxy_id} end
local dumper = {callId = "LUASPLOIT_", binaryOperatorNames = {["and"] = "AND", ["or"] = "OR", [">"] = "GT", ["<"] = "LT", [">="] = "GE", ["<="] = "LE", ["=="] = "EQ", ["~="] = "NEQ", [".."] = "CAT"}}
function dumper:hook(code) return self.callId .. code end
function dumper:process_expr(expr)
    if not expr then return "nil" end
    if typeFunction(expr) == "string" then return expr end
    local tag = expr.tag or expr.kind
    if tag == "number" or tag == "string" then
        local val = tag == "string" and string.format("%q", expr.text) or (expr.value or expr.text)
        if configuration.CONSTANT_COLLECTION then return string.format("%sGET(%s)", self.callId, val) end
        return val
    end
    if tag == "local" or tag == "global" then return (expr.name or expr.token).text
    elseif tag == "boolean" or tag == "bool" then return toStringFunction(expr.value)
    elseif tag == "binary" then
        local lhs = self:process_expr(expr.lhsoperand)
        local rhs = self:process_expr(expr.rhsoperand)
        local op = expr.operator.text
        local opName = self.binaryOperatorNames[op]
        if opName then return string.format("%s%s(%s, %s)", self.callId, opName, lhs, rhs) end
        return string.format("(%s %s %s)", lhs, op, rhs)
    elseif tag == "call" then
        local func = self:process_expr(expr.func)
        local args = {}
        for i, node in ipairsFunction(expr.arguments) do args[i] = self:process_expr(node.node or node) end
        return string.format("%sCALL(%s, %s)", self.callId, func, table.concat(args, ", "))
    elseif tag == "indexname" or tag == "index" then
        local exprStr = self:process_expr(expr.expression)
        local keyStr = tag == "indexname" and string.format("%q", expr.index.text) or self:process_expr(expr.index)
        return string.format("%sCHECKINDEX(%s, %s)", self.callId, exprStr, keyStr)
    end
    return "nil"
end
function dumper:process_statement(stmt)
    if not stmt then return "" end
    local tag = stmt.tag
    if tag == "local" or tag == "assign" then
        local vars, vals = {}, {}
        for _, node in ipairsFunction(stmt.variables or {}) do table.insert(vars, self:process_expr(node.node or node)) end
        for _, node in ipairsFunction(stmt.values or {}) do table.insert(vals, self:process_expr(node.node or node)) end
        return (tag == "local" and "local " or "") .. table.concat(vars, ", ") .. " = " .. table.concat(vals, ", ")
    elseif tag == "block" then
        local stmts = {}
        for _, s in ipairsFunction(stmt.statements or {}) do table.insert(stmts, self:process_statement(s)) end
        return table.concat(stmts, "; ")
    end
    return self:process_expr(stmt) or ""
end
local function _loosePasteCode(code)
    if typeFunction(code) ~= "string" then return code end
    code = code:gsub("```lua", ""):gsub("```", "")
    return code
end
local function _loadLooseChunk(code, chunkName)
    local sanitized = processString(_loosePasteCode(code))
    local lines = {}
    sanitized:gsub("([^\n]*)\n?", function(line)
        if line ~= "" or #lines == 0 or sanitized:sub(-1) == "\n" then table.insert(lines, line) end
    end)
    local skipped = {}
    for _ = 1, 400 do
        local current = table.concat(lines, "\n")
        local func, err = loadFunction(current, chunkName)
        if func then return func, nil, current, skipped end
        local lineNo = toNumberFunction(toStringFunction(err):match("%]:(%d+):") or toStringFunction(err):match(":(%d+):"))
        if not lineNo or not lines[lineNo] or skipped[lineNo] then return nil, err, current, skipped end
        skipped[lineNo] = lines[lineNo]
        lines[lineNo] = "-- " .. lines[lineNo]
    end
    return nil, "too many invalid loose-paste lines", table.concat(lines, "\n"), skipped
end
function proxyTable.dump_file(inputPath, outputPath)
    proxyTable.reset()
    local file = ioLibrary.open(inputPath, "rb")
    if not file then
    printFunction("error: cannot open input")
        return false
    end
    local code = file:read("*a")
    file:close()
    printFunction("input: normalize")
    local func, err, sanitized, skipped = _loadLooseChunk(code, "Obfuscated_Script")
    if not func then
        printFunction("error: load " .. toStringFunction(err))
        return false
    end
    if skipped then
        local skippedCount = 0
        for _ in pairsFunction(skipped) do skippedCount = skippedCount + 1 end
        if skippedCount > 0 then printFunction("input: skipped-lines=" .. toStringFunction(skippedCount)) end
    end
    local _SANDBOX_BLOCK = {
        io=true, os=true, debug=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true,
    }
    local _rawTb = debugLibrary and debugLibrary.traceback
    local _badTbWords = {
        "sandbox","hook","intercept","mock","proxy","virtual_env",
        "decompil","emulat","simulat","fake_","getupval","hookfunc",
        "replaceclos","newcclos","restorefunction","bypass","dumper",
    }
    local _tbWrapper = function(thread, msg, level)
        local ok, tb
        if _rawTb then
            if typeFunction(thread) == "thread" then
                ok, tb = pcallFunction(_rawTb, thread, msg, level)
            else
                ok, tb = pcallFunction(_rawTb, thread, msg)
            end
        end
        if not ok or typeFunction(tb) ~= "string" then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        local lines = {}
        for line in (tb .. "\n"):gmatch("([^\n]*)\n") do
            local lo = line:lower()
            local bad = false
            for _, w in next, _badTbWords do
                if lo:find(w, 1, true) then bad = true; break end
            end
            if not bad then lines[#lines + 1] = line end
        end
        local cleaned = table.concat(lines, "\n")
        cleaned = cleaned:gsub("%[([%w%+%/]+)%]", function(inner)
            if #inner + 2 < 10 then return "[RobloxGameScript]" end
            return "[" .. inner .. "]"
        end)
        if #cleaned < 20 then
            return "stack traceback:\n\t[RobloxGameScript]: in function <RobloxGameScript:1>"
        end
        return cleaned
    end
    local _SAFE_DEBUG = {
        getinfo = function(func, ...)
            if typeFunction(func) == "number" then
                return nil
            end
            return {source = "=[C]", what = "C", name = "C function", short_src = "[C]"}
        end,
        traceback  = _tbWrapper,
        getupvalue = function(fn, i) return nil end,
    }
    local _SAFE_OS = {
        clock = function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end,
        time  = osLibrary.time,
        date  = osLibrary.date,
    }
    local env = setmetatable({
        _VERSION = "Luau",
        LuraphContinue = nil,
        __LC__ = function() end,
        script = script, game = game, workspace = workspace,
        io      = nil,
        os      = _SAFE_OS,
        debug   = _SAFE_DEBUG,
        error   = _origError,
        dofile  = nil,
        loadfile = nil,
        require = nil,
        package = nil,
        socket  = nil,
        ffi     = nil,
        collectgarbage = nil,
        newproxy = newproxy,
        -- hide _G metatable from scripts
        getmetatable = function(obj)
            if obj == _G or obj == env then return nil end
            if _at.userdata[obj] then return getMetatableFunction(obj) end
            if isProxy(obj) then return "The metatable is locked" end
            return getMetatableFunction(obj)
        end,
        LUASPLOIT_CHECKINDEX = function(tbl, key)
            local val = tbl[key]
            if typeFunction(val) == "table" and not dumperState.registry[val] then
                dumperState.ls_counter = dumperState.ls_counter + 1
                dumperState.registry[val] = "v" .. dumperState.ls_counter
            end
            return val
        end,
        LUASPLOIT_GET = function(v) return v end,
        LS_CALL = function(f, ...)
            if typeFunction(f) ~= "function" then return nil end
            return f(...)
        end,
        LS_NAMECALL = function(t, method, ...)
            if typeFunction(t) ~= "table" then return nil end
            if typeFunction(t[method]) ~= "function" then return nil end
            return t[method](t, ...)
        end,
        LUASPLOIT_CALL = function(f, ...) return f(...) end,
        LUASPLOIT_NAMECALL = function(t, method, ...) return t[method](t, ...) end,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end
    }, {
        __index = function(_, k)
            if _SANDBOX_BLOCK[k] then return nil end
            -- block dumper internal globals from leaking into script env
            if k == "LuraphContinue" or k == "__FLAMEDUMPER_REQUIRE_ONLY"
            or k == "proxyTable" or k == "dumperState" or k == "_at" then
                return nil
            end
            return _G[k]
        end,
        __newindex = _G
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, env)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, env) end
        end
    end
    printFunction("vm: running")
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    local success, runErr = xpcallFunction(function() func() end, function(e) return toStringFunction(e) end)
    setHook()
    if not success and not toStringFunction(runErr):match("TIMEOUT") then
        emitComment("Runtime: " .. toStringFunction(runErr))
    end
    local saved = proxyTable.save(outputPath or configuration.OUTPUT_FILE)
    if saved then
        local stats = proxyTable.get_stats()
        printFunction(string.format("done: lines=%d remotes=%d strings=%d",
            stats.total_lines, stats.remote_calls, stats.suspicious_strings))
    else
        printFunction("error: write failed")
    end
    return saved
end
function proxyTable.dump_string(code, outputPath)
    proxyTable.reset()
    if code then code = processString(code) end
    local func, err = loadFunction(code)
    if not func then
        emitComment("Load Error: " .. (err or "unknown"))
        if outputPath then proxyTable.save(outputPath) end
        return false, err
    end
    local _DS_BLOCK = {
        io=true, os=true, dofile=true, loadfile=true,
        require=true, package=true, socket=true, ffi=true,
        collectgarbage=true, debug=true,
    }
    local _DS_OS = { clock=function() local _bc=rawget(_G,"_bypassClock"); return _bc and _bc() or osLibrary.clock() end, time=osLibrary.time, date=osLibrary.date }
    local dsEnv = setmetatable({
        _VERSION="Luau",
        io=nil, os=_DS_OS, debug=nil, dofile=nil, loadfile=nil,
        require=nil, package=nil, socket=nil, ffi=nil,
        collectgarbage=nil, newproxy=newproxy,
        pcall = function(f, ...)
            local override = rawget(_G, "_bypassPcall")
            if typeFunction(override) == "function" then
                local res = {override(pcallFunction, f, ...)}
                if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
                return unpack(res)
            end
            local res = {pcallFunction(f, ...)}
            if not res[1] and toStringFunction(res[2]):match("TIMEOUT") then errorFunction(res[2], 0) end
            return unpack(res)
        end,
    }, {
        __index = function(_, k)
            if _DS_BLOCK[k] then return nil end
            return _G[k]
        end,
        __newindex = _G,
    })
    do
        local _applied = false
        if debugLibrary and debugLibrary.getupvalue and debugLibrary.setupvalue then
            for _i = 1, 256 do
                local _n = debugLibrary.getupvalue(func, _i)
                if not _n then break end
                if _n == "_ENV" then
                    debugLibrary.setupvalue(func, _i, dsEnv)
                    _applied = true
                    break
                end
            end
        end
        if not _applied and type(setfenv) == "function" then
            local _si = debugLibrary and debugLibrary.getinfo and debugLibrary.getinfo(setfenv, "S")
            if _si and _si.what == "C" then setfenv(func, dsEnv) end
        end
    end
    local startClock = osLibrary.clock()
    setHook(function()
        if osLibrary.clock() - startClock > configuration.TIMEOUT_SECONDS then
            errorFunction("TIMEOUT", 0)
        end
    end, "", 1000)
    xpcallFunction(function() func() end, function(e)
        emitComment("Runtime: " .. toStringFunction(e))
    end)
    setHook()
    if outputPath then return proxyTable.save(outputPath) end
    return true, getFullOutput()
end
do
    local bypassPath = (arg and arg[0] and arg[0]:match("^(.+[\\/])")) or ""
    local ok, err = pcall(dofile, bypassPath .. "bypass.lua")
    if not ok then
        local ok2 = pcall(dofile, "bypass.lua")
        if not ok2 then
            printFunction("[dumper] bypass.lua not found, continuing without supplement")
        end
    end
end

_G.LuraphContinue = nil
if not rawget(_G, "__FLAMEDUMPER_REQUIRE_ONLY") then
    if arg and arg[1] then
        local success = proxyTable.dump_file(arg[1], arg[2])
        if success then end
    else
        local file = ioLibrary.open("obfuscated.lua", "rb")
        if file then
            file:close()
            local success = proxyTable.dump_file("obfuscated.lua")
            if success then
                printFunction(proxyTable.get_output())
            end
        else
            printFunction("Usage: lua dumper.lua <input> [output] [key]")
        end
    end
end
return proxyTable
, func=function: 0x752834051670")
print("[STEP 3] Probing upvalues of built-in functions for envlogger globals...")
print("[OK] Upvalues of function: 0x7528342fce80 → 9 interesting finds")
print("[OK] Upvalues of function: 0x7528342fced0 → 9 interesting finds")
print("[OK] Upvalues of function: 0x75283f992de0 → 0 interesting finds")
print("[OK] Upvalues of function: 0x7528342fc0f0 → 9 interesting finds")
print("[OK] Upvalues of function: 0x7528342fc140 → 9 interesting finds")
print("[OK] Upvalues of function: 0x7528342fcd00 → 1 interesting finds")
print("[OK] Upvalues of function: 0x7528342fc210 → 1 interesting finds")
print("[OK] Upvalues of function: 0x7528342fbe00 → 0 interesting finds")
print("[OK] Upvalues of function: 0x7528342fbe40 → 0 interesting finds")
print("[OK] Upvalues of function: 0x7528342fc1d0 → 1 interesting finds")
print("[OK] Upvalues of function: 0x75283f993390 → 0 interesting finds")
print("[STEP 4] Enumerating real_G.package.loaded modules...")
print("[OK] package.loaded → 0 modules found")
print("[STEP 5] Injecting tracer into print via debug.setupvalue...")
-- Runtime: [string "--[[ v1.0.0 https://wearedevs.net/obfuscator ..."]:1: attempt to call a nil value (local 'U')