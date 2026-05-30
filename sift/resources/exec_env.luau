local exec_env = {
    classes = {
        "Workspace", "Players", "Lighting", "ReplicatedStorage", "ServerStorage",
        "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "Chat",
        "MarketplaceService", "TeleportService", "HttpService", "TweenService"
    },
    functions = {
        "print", "warn", "error", "assert", "pcall", "xpcall", "select",
        "setmetatable", "getmetatable", "rawget", "rawset", "rawequal", "rawlen",
        "type", "typeof", "tostring", "tonumber", "pairs", "ipairs", "next",
        "require", "delay", "spawn", "wait", "tick", "time"
    },
    libs = {
        "string", "table", "math", "os", "coroutine", "bit32", "utf8", "buffer", "debug"
    }
}
return exec_env
