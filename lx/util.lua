-- Path normalization
function normalpath(t_or_s)
    if type(t_or_s) == "table" then
        -- Build path from string array
        return normalpath(table.concat(t_or_s, "/"))
    else
        -- Strip trailing slash
        local last = string.sub(t_or_s, -1)
        if last == "/" or last == "\\" then
            return string.sub(t_or_s, 1, -2)
        else
            return t_or_s
        end
    end
end

-- Write file
function newfile(path, ...)
    local f = assert(io.open(normalpath(path), "wb"))
    assert(f:write(table.concat({...})))
    f:close()
end

-- Read entire file
function readfile(path)
    local f = assert(io.open(normalpath(path), "rb"))
    local content = f:read("a")
    f:close()
    return content
end

-- Make directory
function mkdir(path)
    assert(os.execute("mkdir "..normalpath(path)))
end

-- Remove file or directory
function rm(path)
    assert(os.execute("rm -rf "..normalpath(path)))
end

-- Copy file or directory
function cp(path_from, path_to)
    assert(os.execute("cp -r "..normalpath(path_from).." "..normalpath(path_to)))
end

-- Append data to an existing file
function append(path, data)
    local f = assert(io.open(normalpath(path), "ab"))
    assert(f:write(data))
    f:close()
end

-- Call gperf
-- name is appended to the temp file for better debugging in the console
function gperf(name, text)
    local tnin = os.tmpname().."_gperf_"..name..".txt"
    newfile(tnin, text)
    local gp = io.popen("gperf "..tnin, "r")
    local res = gp:read("a")
    gp:close()
    os.remove(tnin)
    return res
end

-- Definitions
LX = {
    module_file = "module.lua", -- Meta informations about the module
    user_file = "module.c",     -- Actual module implementation
    sym_file = "sym.c",         -- Lookup file that maps strings to C functions/Lua values
    module_c = "mod.c",         -- Includes dependency headers, user code and lookup table into one file
    module_o = "mod.o",         -- Resulting object file for this module
    symbol_types = {
        "Submodule",
        "CFunction",
        "CString",
        "LString",
        "Number",
        "Integer",
    },
    record_init = { -- @ will be replaced by symbol value
        Submodule  = "LX_RECORD_SUBMOD,{.mod=&lx_@},",
        CFunction = "LX_RECORD_FUNC,{.func=@},",
        CString   = "LX_RECORD_CSTR,{.cstr=@},",
        LString   = "LX_RECORD_CSTR,{.lstr=@},",
        Number    = "LX_RECORD_NUMBER,{.num=@},",
        Integer   = "LX_RECORD_INTEGER,{.intg=@},",
    }
}

-- Load and check module description file
-- Returns table with ["symbol name"] = { type = one of LX.symbol_types, value = "symbol value" }
function LX.read_module(path, name)
    local env = {}
    local legal_sym = {}
    for k, v in ipairs(LX.symbol_types) do
        env[v] = v
        legal_sym[v] = true
    end
    local e = "Error loading module '"..name.."': "
    assert(loadfile(path.."/"..LX.module_file, "t", env))()
    assert(env.symbols,                  e.."The module must have a symbols table (set 'symbols' variable")
    assert(type(env.symbols) == "table", e.."The symbols table must be a table")
    local sym = {}
    assert(#env.symbols > 0, e.."The module must have at least one symbol")
    for i = 1, #env.symbols do
        assert(type(env.symbols[i]) == "table", e.."The symbols table must contain only table entries"..
                                                   "in the form {type, name, value}")
        local sym_type, sym_name, sym_val = table.unpack(env.symbols[i])
        assert(legal_sym[sym_type],        e.."Symbol type (1st column) ('"..sym_type.."') is unknown")
        assert(type(sym_name) == "string", e.."Symbol name (2nd column) must be a string")
        assert(type(sym_val) == "string",  e.."Symbol value (3rd column) must be a string")
        assert(not sym[sym_name],          e.."Symbol name '"..sym_name.."' already defined")
        sym[sym_name] = { type = sym_type, value = sym_val }
    end
    return { name = name, symbols = sym }
end

-- C module file with includes, user code, lookup table and entry point
function LX.generate_compound_c(mod, user_code)
    local ls = {
        "#include <string.h>", -- for gperf
        '#include "lx.h"',
        "",
        user_code,
        "",
        "/* submodules */",
        "",
        "/* static symbol lookup table */",
        LX.generate_lookup_table(mod),
        "",
        "/* entry point for this module */",
        "lx_module lx_"..mod.name.." = {",
        "   .lookup = lx_get_record,",
        "   .open   = lx_open,",
        "};",
        "",
        "",
    }
    local has_submodules = false
    for sym_name, sym in pairs(mod.symbols) do
        if sym.type == "Submodule" then
            has_submodules = true
            table.insert(ls, 7, "extern lx_module lx_"..mod.name.."_"..sym_name..";")
        end
    end
    if not has_submodules then
        table.insert(ls, 7, "/* (none) */")
    end
    return table.concat(ls, "\r\n")
end

-- Make gperf input file, call gperf and re-treat output so that all functions are static
-- Parameter name: module name
function LX.generate_lookup_table(mod)
    -- Collect lines
    local ls = {
        "/* File was auto-generated */",
        "%language=ANSI-C",
        "%compare-lengths",
        "%readonly-tables",
        "%define hash-function-name   lx_get_hash",   -- static function
        "%define lookup-function-name lx_get_record", -- static function
        "%struct-type",
        "struct lx_record",
        "%define initializer-suffix ,LX_RECORD_EMPTY,{.ptr=NULL}",
        "%%"
    }
    local longest = 0 -- for same indentation level (purely cosmetic)
    for sym_name, _ in pairs(mod.symbols) do
        if #sym_name > longest then
            longest = #sym_name
        end
    end
    -- Keywords of the lookup table
    for sym_name, sym in pairs(mod.symbols) do
        local val = sym.value
        if sym.type == "Submodule" then
            val = mod.name.."_"..sym_name
        end
        local valstr = string.gsub(LX.record_init[sym.type], "@", val)
        table.insert(ls, sym_name..","..string.rep(" ", (longest - #sym_name) + 1)..valstr)
    end
    table.insert(ls, "%%")
    -- Output post-processing
    return
        gperf(mod.name, table.concat(ls, "\n")) -- gperf only likes \n
        :gsub("^.*#define TOTAL_KEYWORDS", "#define TOTAL_KEYWORDS")                  -- remove cruft at the beginnig
        :gsub("\n#line[^\n]*\n", "\n")                                                -- remove cruft that confuses gcc
        :gsub("\nconst struct lx_record %*\n", "\nstatic const struct lx_record *\n") -- make lookup function static
end

--[[ Regex to convert module C array to symbols table
^[\s]*{[\s]*([^,]+),[\s]*([^ }]+)[\s]*},
    { CFunction, $1,         "$2" },
--]]

--EOF