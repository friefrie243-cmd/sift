local mt = {
    __lt = function(a, b)
        print("lt called", a, b)
        return true
    end
}
local t = setmetatable({}, mt)
print(0 < t)
