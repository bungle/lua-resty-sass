local lib          = require "resty.sass.library"
local ffi          = require "ffi"
local ffi_str      = ffi.string
local setmetatable = setmetatable
local rawget       = rawget

local context = {}

function context:__index(n)
    if n == "error_status" then
        return lib.sass_context_get_error_status(self.context)
    elseif n == "error_message" then
        local s = lib.sass_context_get_error_message(self.context)
        return s ~= nil and ffi_str(s) or nil
    elseif n == "output_string" then
        local s = lib.sass_context_get_output_string(self.context)
        return s ~= nil and ffi_str(s) or nil
    elseif n == "source_map_string" then
        local s = lib.sass_context_get_source_map_string(self.context)
        return s ~= nil and ffi_str(s) or nil
    else
        return rawget(context, n)
    end
end

function context.new(ctx)
    return setmetatable({
        context = ctx
    }, context)
end

return context