#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <unistd.h>
#include <math.h>
#include <inttypes.h>
#include <sys/time.h>

#ifdef USELX
    #include "lx.h"
    extern lx_module LXLIB;
    /* Add __index methamethod to _G */
    #define luaL_openlibs(L) { lua_pushglobaltable(L); lx_set_lookup_metatable(L, &LXLIB); lua_pop(L, 1); }
#endif

#define LUA_USE_APICHECK
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

#if LUA_VERSION_NUM == 504
    #define RESUME(L) \
        int nres = 0; \
        switch (lua_resume(L, NULL, 0, &nres)) { \
            case LUA_OK:      break; \
            case LUA_YIELD:   printf("lua_resume: yielded!\n");                       break; \
            default:          printf("lua_resume: error: %s\n", lua_tostring(L, -1)); break; \
        }
#endif
#if  LUA_VERSION_NUM == 503
    #define RESUME(L) \
        switch (lua_resume(L, NULL, 0)) { \
            case LUA_OK:      break; \
            case LUA_YIELD:   printf("lua_resume: yielded!\n");                       break; \
            default:          printf("lua_resume: error: %s\n", lua_tostring(L, -1)); break; \
        }
#endif

//*
#define MEASURE(msg,stmt) { \
    printf("%-18s...", msg); fflush(stdout); \
    struct timeval tv; \
    gettimeofday(&tv, NULL); \
    uint64_t us1 = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec; \
    stmt; \
    gettimeofday(&tv, NULL); \
    uint64_t us2 = tv.tv_sec * (uint64_t)1000000 + tv.tv_usec; \
    printf("\b\b\b- %7.4fs\n", ((double)us2 - us1) / 1000000); \
}
//*/

#if LXSTEPWISE == 1
    #define STEPWISE_OR_TOTAL(code) { \
        lua_State** states = (lua_State**)malloc(sizeof(void*) * nstates); \
        code; \
        free(states); \
    }
    #define MEASURE_STATES(msg, code) { \
        MEASURE(msg, { \
            for (size_t istate = 0; istate < nstates; ++istate) { \
                lua_State* L = states[istate]; \
                code; \
            } \
        }); \
    }
    #define STEPWISE_ONLY(code) code;
#else
    #define STEPWISE_OR_TOTAL(code) { \
        MEASURE("All at once", { \
            lua_State** states = (lua_State**)malloc(sizeof(void*) * 1); \
            size_t istate = 0; \
            lua_State* L = states[istate]; \
            for (size_t round = 0; round < nstates; ++round) { \
                code; \
            } \
            free(states); \
        }); \
    }
    #define MEASURE_STATES(msg, code) code;
    #define STEPWISE_ONLY(code)
#endif

#ifdef LX_USE_PRELOAD
    extern int luaopen_base64(lua_State *L);
    extern int luaopen_mathx(lua_State *L);
    #define USE_PRELOAD(code) { code; }
#else
    #define USE_PRELOAD(code) { ; }
#endif

// #define MEASURE(msg, code) code;

// Buffer with compiled script.lua
static char* buf = NULL;
static size_t buflen = 0;

static int buf_writer(lua_State* L, const void* p, size_t size, void* u) {
    (void)L; (void)u;
    buf = realloc(buf, buflen + size);
    memcpy(buf + buflen, p, size);
    buflen += size;
    return 0;
}

int main(void)
{
    // Load script, compile it and dump bytecode into buf
    lua_State* L1 = luaL_newstate();
    luaL_loadfilex(L1, "script.lua", "t");
    lua_dump(L1, buf_writer, NULL, 1);
    lua_close(L1);
    // Create states and load libraries
    const size_t nstates = LXNSTATES;
    //*
    // Repeat for all states and measure time taken
    STEPWISE_OR_TOTAL({
        MEASURE_STATES("Create states", {
            states[istate] = luaL_newstate();
            L = states[istate];
        });
        MEASURE_STATES("Load libraries", {
            luaL_openlibs(L);
        });
        MEASURE_STATES("Load bytecode", {
            if (luaL_loadbufferx(L, buf, buflen, "script.lua (bytecode buffer)", "b")) {
                printf("luaL_loadbufferx: %s\n", lua_tostring(L, -1));
                return 1;
            }
        });
        USE_PRELOAD({
            MEASURE_STATES("preload", {
                // base64
                lua_getglobal(L, "package");
                    lua_getfield(L, -1, "preload");
                        lua_pushcfunction(L, luaopen_base64);
                            lua_setfield(L, -2, "base64");
                        lua_pop(L, 2);
                // mathx
                lua_getglobal(L, "package");
                    lua_getfield(L, -1, "preload");
                        lua_pushcfunction(L, luaopen_mathx);
                            lua_setfield(L, -2, "mathx");
                        lua_pop(L, 2);
            });
        })
        MEASURE_STATES("Execution", {
            RESUME(L);
        });
        STEPWISE_ONLY({
            printf("memory usage per state: %dKB\n", lua_gc(states[0], LUA_GCCOUNT, 0));
        });
        MEASURE_STATES("full gc cycle", {
            lua_gc(L, LUA_GCCOLLECT, 0);
        });
        MEASURE_STATES("Cleanup", {
            lua_close(L);
        });
    });
    free(buf);
}

