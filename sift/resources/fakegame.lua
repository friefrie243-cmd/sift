local _tbl
_tbl = function(...)
    return setmetatable({}, {
        __index = function() return _tbl end,
        __call = function() return _tbl end
    })
end

local roblox_env = {
    game = {},
    workspace = {},
    script = {},
    Instance = { new = function() return _tbl() end },
    Enum = {},
    Vector3 = {},
    CFrame = {},
    Color3 = {},
    UDim2 = {},
    task = { wait = function() return 1 end, spawn = function() end }
}

return roblox_env, _tbl
