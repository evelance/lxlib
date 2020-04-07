#include <assert.h>
#include "lx.h"
#include "lauxlib.h"

/* __index metamethod C closure for all module tables */
static int lx__index(lua_State *L) {
    const int idx_module_table = 1,                /* table with missing key that triggered the __index metamethod */
              idx_key = 2,                         /* requested key for __index metamethod */
              idx_metatable = lua_upvalueindex(1); /* metatable of the module table */
    lx_module* module = (lx_module*)lua_touserdata(L, idx_metatable);
    size_t len = 0;
    const char* key = luaL_checklstring(L, idx_key, &len);
    /* Get record from gperf table */
    const lx_record* record = module->lookup(key, len);
    if (! record) {
        lua_pushnil(L);
            return 1;
    }
    /* Different record types get handled differently */
    switch (record->type) {
        case LX_RECORD_SUBMOD: {
            lua_createtable(L, 0, 0); /* submodule table */
                lx_set_lookup_metatable(L, record->value.mod); /* add lookup function to submodule table */
                goto set_and_return;
        }
        case LX_RECORD_FUNC: {
            lua_pushcfunction(L, record->value.func);
                goto set_and_return;
        }
        case LX_RECORD_CSTR: {
            lua_pushstring(L, record->value.cstr);
                goto set_and_return;
        }
        case LX_RECORD_LSTR: {
            lua_pushlstring(L, record->value.lstr->str, record->value.lstr->len);
                goto set_and_return;
        }
        case LX_RECORD_NUMBER: {
            lua_pushnumber(L, record->value.num);
                goto set_and_return;
        }
        case LX_RECORD_INTEGER: {
            lua_pushinteger(L, record->value.intg);
                goto set_and_return;
        }
        default: {
            return luaL_error(L, "got lx_record of unknown type %d", record->type);
        }
    }
    set_and_return:
        lua_pushvalue(L, idx_key); /* k = requested key in module table */
            lua_pushvalue(L, -2);  /* v = value found by lookup function */
                lua_rawset(L, idx_module_table); /* add entry to module table so that next time Lua can find it */
        return 1;
}

void lx_set_lookup_metatable(lua_State* L, lx_module* m) {
    luaL_checktype(L, -1, LUA_TTABLE); /* requires the module table on top of the stack */
    luaL_checkstack(L, 5, "cannot setup lx module metatable");
    lua_createtable(L, 0, 1); /* metatable for the module table */
        lua_pushvalue(L, -1);
            lua_pushliteral(L, "__index"); /* __index is invoked when non-existing key is requested */
                lua_pushlightuserdata(L, m);
                    lua_pushcclosure(L, lx__index, 1); /* metamethod with m as upvalue */
                    lua_rawset(L, -3); /* set __index metamethod */
            lua_setmetatable(L, -3); /* set metatabe */
    if (m->open) {
        lua_pushcfunction(L, m->open); /* lx_open callback */
            lua_pushvalue(L, -2);     /* Argument 1: module metatable */
                lua_pushvalue(L, -4); /* Argument 2: module table */
                    lua_call(L, 2, 0);
    }
        lua_pop(L, 1); /* remove module table and metatable */
    return; /* stack is same as before */
}

