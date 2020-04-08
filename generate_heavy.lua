#!/usr/bin/lua5.3
local num_mod, num_fpm = ...
num_mod, num_fpm = math.tointeger(num_mod), math.tointeger(num_fpm)
if arg[1] == "-h" or not num_mod or not num_fpm then print [[
Generate random modules in lx/heavy

Parameter 1: Number of modules
Parameter 2: Number of functions per module]] return 1 end
local here = string.sub(arg[0], 1, #arg[0] - #"/generate_heavy.lua")
assert(loadfile(here.."/lx/util.lua", "t"))()

-- Clean output dir
local outdir = normalpath{here, "lx", "heavy"}
rm(outdir)
cp({here, "lx", "basex"}, outdir)
local basex_lua = readfile{here, "lx", "basex", "module.lua"}
local subm = {}

-- Generate modules
for m = 1, num_mod do
    local mname = "module"..m
    local mdir = normalpath {outdir, mname}
    mkdir(mdir)
    -- Generate module.lua
    local sym = {"symbols = {"}
    for f = 1, num_fpm do
        local fname = "m"..m.."func"..f
        table.insert(sym, '    { CFunction, "'..fname..'", "'..fname..'" },')
    end
    table.insert(sym, "}")
    newfile({mdir, "module.lua"}, table.concat(sym, "\r\n"))
    -- Generate module.c
    local c = {
        '#include <math.h>',
        '#include "lua.h"',
        '#include "lauxlib.h"',
    }
    for f = 1, num_fpm do
        local fname = "m"..m.."func"..f
        table.insert(c, "")
        table.insert(c, "static int "..fname.." (lua_State *L) {")
        table.insert(c, '    lua_pushliteral(L, "Module '..mname..' function '..fname..' says hello:");')
        table.insert(c, "    for (int i = 0; i < "..f.."; ++i) {")
        table.insert(c, '        lua_pushliteral(L, " '..fname..'!");')
        table.insert(c, "        lua_pushnumber(L, sin("..m..".0 * "..f..".0 * i));")
        table.insert(c, "        lua_concat(L, 3);")
        table.insert(c, "    }")
        table.insert(c, "    return 1;")
        table.insert(c, "}")
    end
    table.insert(c, "static const lua_CFunction lx_open = NULL;")
    newfile({mdir, "module.c"}, table.concat(c, "\r\n"))
    table.insert(subm, '    { Submodule, "'..mname..'", "'..mname..'" },')
end

-- Add submodules to base module
newfile({here, "lx", "heavy", "module.lua"}, basex_lua:gsub("}[\r\n ]*$", "")..table.concat(subm, "\r\n").."\r\n}")

-- .LUA Framework successfully generated
return 0