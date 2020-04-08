#!/usr/bin/lua5.3
if arg[1] == "-h" or #arg < 2 then print [[
Lua extension library - library builder

Generates a custom Lua extension library made out of
hierarchical modules.
It checks dependencies, copies necessary files from the
module repository and generates glue code and a Makefile.

Usage: makelib.lua <root module> <output dir>
    
    <root module>
        Name of the module that will be the root of the library.
    
    <output dir>
        All resulting files will be written into this directory.
        WARNING: Everything in it will be deleted during execution.
]] return 1 end

local here = string.sub(arg[0], 1, #arg[0] - #"/makelib.lua") --beautiful
assert(loadfile(here.."/util.lua", "t"))()
local rootm  = arg[1]
local outdir = normalpath(arg[2])

-- Clean output dir
rm(outdir)
mkdir(outdir)

-- Add lx files
cp({here, "lx.c"}, outdir)
cp({here, "lx.h"}, outdir)

-- Add modules, start with root module
function build_module_tree(in_dir, out_dir, name, module_files)
    -- Load module description file and create compound output file
    local out_c = out_dir.."/"..name..".c"
    local mod = LX.read_module(in_dir, name)
    newfile(out_c, LX.generate_compound_c(mod, readfile({in_dir, LX.user_file})))
    -- Register newly created file
    table.insert(module_files, name)
    -- Create child modules
    for sym_name, sym in pairs(mod.symbols) do
        if sym.type == "Submodule" then
            build_module_tree(normalpath{in_dir, sym.value}, out_dir, mod.name.."_"..sym_name, module_files)
        end
    end
end

local module_files = {}
build_module_tree(normalpath{here, rootm}, outdir, rootm, module_files)

-- Generate Makefile
local make_objects, make_targets = {}, {}
for _, file in ipairs(module_files) do
    table.insert(make_objects, file..".o")
    table.insert(make_targets, "")
    table.insert(make_targets, file..".o: "..file..".c lx.h")
    table.insert(make_targets, "\t$(CC) $(CFLAGS) -Wno-unused-parameter -Wno-implicit-fallthrough -I$(LUA) -I. -DLUA_USE_POSIX -c -o $@ $<")
end
newfile({outdir, "Makefile"},
    readfile({here, "Makefile.tpl"})
    :gsub("{{OBJECTS}}", table.concat(make_objects, " "))
    :gsub("{{TARGETS}}", table.concat(make_targets, "\r\n"))
, nil) -- don't print gsub's 2nd result

return 0