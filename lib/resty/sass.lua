local ffi        = require "ffi"
local ffi_cdef   = ffi.cdef
local ffi_load   = ffi.load
local ffi_str    = ffi.string
local assert     = assert
local concat     = table.concat
local type       = type

ffi_cdef[[
typedef struct sass_options {
  int output_style;
  int source_comments;
  const char* include_paths;
  const char* image_path;
  int precision;
};
typedef struct sass_context {
  const char* input_path;
  const char* output_path;
  const char* source_string;
  char* output_string;
  char* source_map_string;
  const char* source_map_file;
  bool omit_source_map_url;
  struct sass_options options;
  int error_status;
  char* error_message;
  struct Sass_C_Function_Descriptor* c_functions;
  char** included_files;
  int num_included_files;
};
typedef struct sass_file_context {
  const char* input_path;
  const char* output_path;
  char* output_string;
  char* source_map_string;
  const char* source_map_file;
  bool omit_source_map_url;
  struct sass_options options;
  int error_status;
  char* error_message;
  struct Sass_C_Function_Descriptor* c_functions;
  char** included_files;
  int num_included_files;
};
struct sass_context*        sass_new_context        (void);
struct sass_file_context*   sass_new_file_context   (void);
void   sass_free_context        (struct sass_context* ctx);
void   sass_free_file_context   (struct sass_file_context* ctx);
int    sass_compile             (struct sass_context* ctx);
int    sass_compile_file        (struct sass_file_context* ctx);
]]

local libsass = ffi_load("libsass")

local styles = {
    nested     = 0,
    expanded   = 1,
    compact    = 2,
    compressed = 3
}

local comments = {
    none = 0,
    default = 1,
    map = 2
}

local function options(opts, ctx)
    local style = styles[opts.style]
    if style then ctx.options.output_style = style end
    local comments = comments[opts.comments]
    if comments then ctx.options.source_comments = comments end
    local includes = opts.includes
    local t = type(includes)
    if t == "table" then
        ctx.options.include_paths = concat(includes, ";")
    elseif t == "string" then
        ctx.options.include_paths = includes
    end
    local images = opts.images
    local t = type(images)
    if t == "table" then
        ctx.options.image_paths = concat(images, ";")
    elseif t == "string" then
        ctx.options.image_paths = images
    end
    local precision = opts.precision
    local t = type(precision)
    if t == "number" then ctx.options.precision = precision end
end

local sass = {}

function sass.compile(opts)
    local t, ctx = type(opts)
    assert(t == "table" or t == "string", "sass.compile takes a single argument of type string or table.")
    if t == "table" then
        assert(type(opts.src) == "string", "sass.compile called with table argument needs to have at least src key of type string.")
        ctx = libsass.sass_new_context()
        ctx.source_string = opts.src
        options(opts, ctx)
    else
        ctx = libsass.sass_new_context()
        ctx.source_string = opts
    end
    if libsass.sass_compile(ctx) ~= 0 then
        if ctx.error_status ~= 0 then
            local err = ffi_str(ctx.error_message)
            libsass.sass_free_context(ctx)
            return nil, err
        else
            libsass.sass_free_context(ctx)
            return nil, nil
        end
    else
        if ctx.error_status ~= 0 then
            local err = ffi_str(ctx.error_message)
            libsass.sass_free_context(ctx)
            return nil, err
        else
            local css = ffi_str(ctx.output_string)
            libsass.sass_free_context(ctx)
            return css, nil
        end
    end
end

function sass.compile_file(opts)
    local t, dst, ctx = type(opts), false
    assert(t == "table" or t == "string", "sass.compile_file takes a single argument of type string or table.")
    if t == "table" then
        assert(type(opts.src) == "string", "sass.compile_file called with table argument needs to have at least src key of type string.")
        ctx = libsass.sass_new_file_context()
        ctx.input_path = opts.src
        options(opts, ctx)
        dst = opts.dst
        if dst then
            ctx.output_path = dst
            if ctx.options.source_comments == comments.map then
                ctx.source_map_file = dst .. '.map'
            end
        end
    else
        ctx = libsass.sass_new_file_context()
        ctx.input_path = opts
    end
    if libsass.sass_compile_file(ctx) ~= 0 then
        if ctx.error_status ~= 0 then
            local err = ffi_str(ctx.error_message)
            libsass.sass_free_file_context(ctx)
            return nil, err
        else
            libsass.sass_free_file_context(ctx)
            return nil, nil
        end
    else
        if ctx.error_status ~= 0 then
            local err = ffi_str(ctx.error_message)
            libsass.sass_free_file_context(ctx)
            return nil, err
        else
            local css, map = ffi_str(ctx.output_string), nil
            if dst and ctx.options.source_comments == comments.map then
                map = ffi_str(ctx.source_map_string)
            end
            libsass.sass_free_file_context(ctx)
            return css, map
        end
    end
end

return sass