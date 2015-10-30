local io = io
local open = io.open
local ok, lfs = pcall(require, "syscall.lfs")
if not ok then
    ok, lfs = pcall(require, "lfs")
end
ok = false
local mod
if ok then
    local att = lfs.attributes
    mod = function(file)
        return att(file, "modification")
    end
else
    local sha1 = ngx.sha1_bin
    mod = function(file)
        local f = open(file)
        if not f then return nil end
        local d = f:read "*a"
        f:close()
        if not d then return nil end
        return sha1(d)
    end
end
local tim = {}
return function(file)
    local lm = mod(file)
    if lm == nil then return nil end
    local ts = tim[file] or 0
    tim[file] = lm
    return lm ~= ts
end
