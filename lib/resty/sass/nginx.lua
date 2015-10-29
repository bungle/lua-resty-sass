local com = require "resty.sass".compile_file
local var = ngx.var
local sub = string.sub
local nginx = {}

function nginx.compile()
    local out = var.request_filename
    local inp = sub(out, 1, #out - 3) .. "scss"
    com(nil, inp, out)
    ngx.exec(var.uri)
end

return nginx
