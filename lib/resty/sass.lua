local ffi        = require "ffi"
local C          = ffi.C
local ffi_gc     = ffi.gc
local ffi_copy   = ffi.copy
local ffi_cdef   = ffi.cdef
local ffi_load   = ffi.load
local ffi_str    = ffi.string
local ffi_sizeof = ffi.sizeof
local assert     = assert
local concat     = table.concat
local type       = type

ffi_cdef[[
typedef struct Sass_Function (*Sass_Function_Entry);
typedef struct Sass_Function* (*Sass_Function_List);
struct sass_options {
  int output_style;
  bool source_comments;
  const char* source_map_file;
  bool omit_source_map_url;
  bool source_map_embed;
  bool source_map_contents;
  const char* source_map_root;
  bool is_indented_syntax_src;
  const char* include_paths;
  const char* plugin_paths;
  const char* indent;
  const char* linefeed;
  int precision;
};
struct sass_context {
  const char* input_path;
  const char* output_path;
  const char* source_string;
  char* output_string;
  char* source_map_string;
  struct sass_options options;
  int error_status;
  char* error_message;
  Sass_Function_List c_functions;
  char** included_files;
  int num_included_files;
};
struct sass_file_context {
  const char* input_path;
  const char* output_path;
  char* output_string;
  char* source_map_string;
  struct sass_options options;
  int error_status;
  char* error_message;
  Sass_Function_List c_functions;
  char** included_files;
  int num_included_files;
};
struct sass_folder_context {
  const char* search_path;
  const char* output_path;
  struct sass_options options;
  int error_status;
  char* error_message;
  Sass_Function_List c_functions;
  char** included_files;
  int num_included_files;
};
struct sass_context* sass_new_context (void);
struct sass_file_context* sass_new_file_context (void);
struct sass_folder_context* sass_new_folder_context (void);
void sass_free_context (struct sass_context* ctx);
void sass_free_file_context (struct sass_file_context* ctx);
void sass_free_folder_context(struct sass_folder_context* ctx);
int sass_compile (struct sass_context* ctx);
int sass_compile_file (struct sass_file_context* ctx);
int sass_compile_folder (struct sass_folder_context* ctx);
const char* libsass_version (void);
char* sass2scss (const char* sass, const int options);
const char* sass2scss_version (void);
void* malloc(size_t size);
]]

local libsass = ffi_load("sass")
local char_s  = ffi_sizeof("char")

local styles   = {
    nested     = 0,
    expanded   = 1,
    compact    = 2,
    compressed = 3
}

local function options(opts, ctx)
    local style = styles[opts.style]
    if style then ctx.options.output_style = style end
    if type(opts.comments) == "boolean" then
        ctx.options.source_comments = opts.comments == true
    end
    local includes = opts.includes
    local t = type(includes)
    if t == "table" then
        ctx.options.include_paths = concat(includes, ",")
    elseif t == "string" then
        ctx.options.include_paths = includes
    end
    local images = opts.images
    local t = type(images)
    if t == "table" then
        ctx.options.image_paths = concat(images, ",")
    elseif t == "string" then
        ctx.options.image_paths = images
    end
    local precision = opts.precision
    local t = type(precision)
    if t == "number" then ctx.options.precision = precision end
end

local sass = { version = ffi_str(libsass.libsass_version()) }

function sass.compile(opts)
    local t, ctx, src = type(opts), ffi_gc(libsass.sass_new_context(), sass_free_context)
    assert(t == "table" or t == "string", "sass.compile takes a single argument of type string or table.")
    if t == "table" then
        assert(type(opts.src) == "string", "sass.compile called with table argument needs to have at least src key of type string.")
        src = C.malloc((#opts.src + 1) * char_s)
        ffi_copy(src, opts.src, #opts.src)
        options(opts, ctx)
    else
        src = C.malloc((#opts + 1) * char_s)
        ffi_copy(src, opts, #opts)
    end
    ctx.source_string = src
    if libsass.sass_compile(ctx) ~= 0 then
        if ctx.error_status ~= 0 then
            return nil, ffi_str(ctx.error_message)
        end
        return nil, nil
    else
        if ctx.error_status ~= 0 then
            return nil, ffi_str(ctx.error_message)
        end
        return css, ffi_str(ctx.output_string)
    end
end

function sass.compile_file(opts)
    local t, ctx = type(opts), ffi_gc(libsass.sass_new_file_context(), libsass.sass_free_file_context)
    assert(t == "table" or t == "string", "sass.compile_file takes a single argument of type string or table.")
    if t == "table" then
        assert(type(opts.src) == "string", "sass.compile_file called with table argument needs to have at least src key of type string.")
        ctx.input_path = opts.src
        options(opts, ctx)
        if opts.dst then
            ctx.output_path = dst
            if ctx.options.source_comments == true then
                ctx.source_map_file = dst .. '.map'
            end
        end
    else
        ctx.input_path = opts
    end
    if libsass.sass_compile_file(ctx) ~= 0 then
        if ctx.error_status ~= 0 then
            return nil, ffi_str(ctx.error_message)
        end
        return nil, nil
    else
        if ctx.error_status ~= 0 then
            return nil, ffi_str(ctx.error_message)
        else
            local css, map = ffi_str(ctx.output_string), nil
            if dst and ctx.options.source_comments == true then
                map = ffi_str(ctx.source_map_string)
            end
            return css, map
        end
    end
end

sass.sass2scss = setmetatable({ version = ffi_str(libsass.sass2scss_version()) }, { __call = function(_, sass, options)
    options = options or 0
    assert(type(sass) == "string", "sass.sass2scss first argument should be of type string.")
    assert(type(options) == "number", "sass.sass2scss optional second argument should be of type number.")
    return ffi_str(libsass.sass2scss(sass, options))
end })

return sass
