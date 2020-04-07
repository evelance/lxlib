/*
** Lua extension library general header
*/
#ifndef __LX_H
#define __LX_H
#include <stddef.h>
#include <stdlib.h>
#include "lua.h"

/* Record types */
typedef enum lx_type {
    LX_RECORD_EMPTY,   /* Empty slots in gperf table; like nil */
    LX_RECORD_SUBMOD,  /* Submodule */
    LX_RECORD_FUNC,    /* lua_CFunction */
    LX_RECORD_CSTR,    /* Zero-terminated string */
    LX_RECORD_LSTR,    /* Length-terminated string */
    LX_RECORD_NUMBER,  /* lua_Number */
    LX_RECORD_INTEGER, /* lua_Integer */
    
    /* many more could be added like bytecode, callbacks, dynamic loading of other libraries, ... */
    
} lx_type;

/* gperf table lookup function */
typedef const struct lx_record* (* lx_lookup)(register const char* str, register size_t len);

/* Exposed module entry point: provides access to module-local functions */
typedef struct lx_module {
    lx_lookup     lookup; /* Looks up symbols in this module (auto-generated function) */
    lua_CFunction open;   /* Called when the module is actually accessed by Lua. */
                          /* Parameter 1: Metatable of the module table */
                          /* Parameter 2: Module table itself */
} lx_module;

/* Length string */
typedef struct lx_lstr {
    const size_t len;
    const char* str;
} lx_lstr;

/* Record object */
typedef struct lx_record {
    const char* name; // Key in gperf table
    lx_type type;
    union {
        void*          ptr;
        lx_module*     mod;
        lua_CFunction  func;
        const char*    cstr;
        const lx_lstr* lstr;
        lua_Number     num;
        lua_Integer    intg;
    } value;
} lx_record;

/*
** Set the metatable for the table at the top of the stack.
** The __index metamethod calls the lookup function of the module m and
** returns or handles the values found.
** [-0, +0, e]
*/
LUA_API void lx_set_lookup_metatable(lua_State* L, lx_module* m);

#endif