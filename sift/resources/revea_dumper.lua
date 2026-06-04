local env = getfenv(3)
local mt = getmetatable(env)
local idx = rawget(mt, "__index")
local req = rawget(idx, "require")
local fs = req("@lune/fs")

local function scan(path)
    local files = fs.readDir(path)
    for _, v in pairs(files) do
        local p = path .. "/" .. v
        if fs.isDir(p) then
            scan(p)
        elseif fs.isFile(p) then
            local content = fs.readFile(p)
            print("START_FILE:" .. p)
            for k = 1, #content, 100 do
                print("CHUNK:" .. string.sub(content, k, k + 99))
            end
            print("END_FILE:" .. p)
        end
    end
end

scan(".")