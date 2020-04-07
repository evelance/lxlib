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

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

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

// #define MEASURE(msg,stmt) stmt;

int main(void)
{
    // Load bytecode into buffer
    FILE* f = fopen("script.lbc", "rb");
    if (! f) {
        perror("fopen");
        return 1;
    }
    fseek(f, 0, SEEK_END);
    size_t len = ftell(f);
    rewind(f);
    char* buf = (char*)malloc(len + 1);
    fread(buf, 1, len, f);
    buf[len] = 0;
    fclose(f);
    // Create states and load libraries
    const size_t nstates = 100000;
    lua_State** states = (lua_State**)malloc(sizeof(void*) * nstates);
    // Repeat for all states and measure time taken
    #define MEASURE_STATES(msg, code) { \
        MEASURE(msg, { \
            for (size_t i = 0; i < nstates; ++i) { \
                lua_State* L = states[i]; \
                code; \
            } \
        }); \
    }
    MEASURE_STATES("Create states", {
        (void)L;
        states[i] = luaL_newstate();
    });
    MEASURE_STATES("Load libraries", {
        luaL_openlibs(L);
    });
    MEASURE_STATES("Load bytecode", {
        if (luaL_loadbufferx(L, buf, len, "script.lua (bytecode buffer)", "b")) {
            printf("luaL_loadbufferx: %s\n", lua_tostring(L, -1));
            return 1;
        }
    });
    MEASURE_STATES("Execution", {
        int nresults = 0;
        switch (lua_resume(L, NULL, 0, &nresults))
        {
            case LUA_YIELD:   printf("lua_resume: yielded!\n");                                   break;
            case LUA_OK:      break; // printf("lua_resume: finished.\n");                                  break;
            case LUA_ERRRUN:  printf("lua_resume: runtime error: %s\n", lua_tostring(L, -1));     break;
            case LUA_ERRMEM:  printf("lua_resume: memory allocation error.\n");                   break;
            case LUA_ERRERR:  printf("lua_resume: error while running the message handler.\n");   break;
            default:          printf("lua_resume: unknown\n");                                    break;
        }
        // printf("We're back with %d arguments\n", nresults);
        // for (int r = 1; r <= nresults; ++r) {
            // size_t slen = 0;
            // const char* s = luaL_tolstring(L, r, &slen);
            // printf("Argument %d: %s, %.*s\n", r, lua_typename(L, lua_type(L, r)), (int)slen, s);
        // }
    });
    printf("memory usage per state: %dKB\n", lua_gc(states[0], LUA_GCCOUNT));
    // sleep(10);
    MEASURE_STATES("full gc cycle", {
        lua_gc(L, LUA_GCCOLLECT);
    });
    MEASURE_STATES("Cleanup", {
        lua_close(L);
    });
    /*
    MEASURE_STATES("All at once", {
        states[i] = luaL_newstate();
        L = states[i];
        OPENLIBS;
        if (luaL_loadbufferx(L, buf, len, "script.lua (bytecode buffer)", "b")) {
            printf("luaL_loadbufferx: %s\n", lua_tostring(L, -1));
            return 1;
        }
        int nresults = 0;
        switch (lua_resume(L, NULL, 0, &nresults))
        {
            case LUA_YIELD:   printf("lua_resume: yielded!\n");                                   break;
            case LUA_OK:      break; // printf("lua_resume: finished.\n");                                  break;
            case LUA_ERRRUN:  printf("lua_resume: runtime error: %s\n", lua_tostring(L, -1));     break;
            case LUA_ERRMEM:  printf("lua_resume: memory allocation error.\n");                   break;
            case LUA_ERRERR:  printf("lua_resume: error while running the message handler.\n");   break;
            default:          printf("lua_resume: unknown\n");                                    break;
        }
        lua_close(L);
    });
    */
    free(states);
    free(buf);
}

