local ok, lfs = pcall(require, "syscall.lfs")
if not ok then
    ok, lfs = pcall(require, "lfs")
end
assert(ok, "Either syscall or lfs is required.")
local att = lfs.attributes
local tim = {}
return function(file)
    local lm = att(file, "modification")
    if lm == nil then return nil end
    local ts = tim[file] or 0
    tim[file] = lm
    return lm > ts
end
