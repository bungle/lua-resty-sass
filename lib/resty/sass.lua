local lib          = require "resty.sass.library"
local options      = require "resty.sass.options"
local file         = require "resty.sass.file"
local data         = require "resty.sass.data"
local ffi          = require "ffi"
local ffi_str      = ffi.string
local open         = io.open
local setmetatable = setmetatable

local sass = {
    version = ffi_str(lib.libsass_version())
}
sass.__index = sass

function sass.new()
    return setmetatable({
        options = options.new()
    }, sass)
end

function sass:compile_file(input_path, output_path)
    local file = file.new(input_path)
    local context = file.context
    local options = self.options
    if output_path then
        options.output_path = output_path
    end
    options.input_path = input_path
    file.options = options
    file:compile()
    if context.error_status ~= 0 then
        return nil, context.error_message
    end
    local output = context.output_string
    if output then
        if output_path then
            local of, err = open(output_path, "w")
            if not of then
                return of, err
            end
            local ok, err = of:write(output)
            if not ok then
                of:close()
                return ok, err
            end
            of:close()
        end
        local output_path = options.source_map_file
        if output_path then
            if context.error_status ~= 0 then
                return nil, context.error_message
            end
            local map = context.source_map_string
            local of, err = open(output_path, "w")
            if not of then
                return of, err
            end
            local ok, err = of:write(map)
            if not ok then
                of:close()
                return ok, err
            end
            of:close()
            return output, map
        else
            return output
        end
    else
        return nil, "Unknown internal error."
    end
end

function sass:compile_data(input_string, output_path)
    local data = data.new(input_string)
    local context = data.context
    local options = self.options
    data.options = options
    data:compile()
    if context.error_status ~= 0 then
        return nil, context.error_message
    end
    local output = context.output_string
    if output then
        if output_path then
            local of, err = open(output_path, "w")
            if not of then
                return of, err
            end
            local ok, err = of:write(output)
            if not ok then
                of:close()
                return ok, err
            end
            of:close()
        end
        return output
    else
        return nil, "Unknown internal error."
    end
end

sass.sass2scss = setmetatable({ version = ffi_str(lib.sass2scss_version()) }, { __call = function(_, sass, options)
    options = options or 0
    return ffi_str(lib.sass2scss(sass, options))
end })

return sass