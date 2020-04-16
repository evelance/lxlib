# Select one of these:
# base  = Lua5.4-beta standard libraries
# basex = base + LuaFileSystem + some LHF libraries
# heavy = basex + many auto-generated modules
LXLIB=basex

# Number of states created for the test
NUM_STATES=100000

# Select one of these:
# 0   = All test steps are run per iteration on one state, NUM_STATES times.
#       Reports only total time, and has a strong caching effect.
# 1   = NUM_STATES states are constructed at the beginning and the test steps
#       are executed on all states. Needs a lot of RAM and is alot slower.
STEPWISE=0

# Lots of stuff...
CFLAGS_GENERAL = -DLUA_COMPAT_5_3 -DLUA_USE_LINUX -Wl,-E -DLXLIB=lx_$(LXLIB) -DLXNSTATES=$(NUM_STATES) -DLXSTEPWISE=$(STEPWISE) \
    # -Wshadow -Wsign-compare -Wundef -Wwrite-strings -Wredundant-decls -Wdisabled-optimization  \
    # -Wmissing-prototypes -Wnested-externs -Wstrict-prototypes -Wc++-compat -Wold-style-definition
CFLAGS_DEBUG = -ggdb -fno-omit-frame-pointer -fsanitize=address -fsanitize=null
CFLAGS_RELEASE = -O2
CFLAGS = -std=gnu99 -Wall -Wextra -pedantic $(CFLAGS_GENERAL) $(CFLAGS_RELEASE)
# CFLAGS = -std=gnu99 -fwrapv -Wall -Wextra -pedantic $(CFLAGS_GENERAL) $(CFLAGS_DEBUG)
LUA = lua-5.4.0-beta
LUA_NL = lua-5.4.0-beta-nolibs
LUA_CW = lua-5.3.x-cloudwu
LUAC = $(LUA)/src/luac
OUT = out-normal out-preload out-lx out-cw out-lua54-normal out-lua54-lx

all: $(OUT)

# Test programs
out-normal: $(LUA)/src/liblua.a main.c base64.so mathx.so Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src main.c $< -ldl -lm

out-preload: $(LUA)/src/liblua.a base64.so mathx.so main.c Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -DLX_USE_PRELOAD -Wno-implicit-fallthrough main.c base64/lbase64.o mathx/lmathx.o $< -ldl -lm

out-lx: $(LUA_NL)/src/liblua.a main.c generatedlib Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA_NL)/src -I./generatedlib -DUSELX main.c $< generatedlib/*.o -ldl -lm

out-cw: $(LUA_CW)/src/liblua.a main.c Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA_CW)/src main.c $< -ldl -lm

# Command line Lua for experimenting
out-lua54-normal: lua54.c Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -DLUA_USE_READLINE $< $(LUA)/src/liblua.a -ldl -lm -lreadline

out-lua54-lx: lua54.c generatedlib Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -I./generatedlib -DLUA_USE_READLINE -DUSELX $< generatedlib/*.o $(LUA_NL)/src/liblua.a -ldl -lm -lreadline

# Lua libraries
$(LUA)/src/liblua.a: $(LUA)/src/*.c
	cd $(LUA) && make -j4 linux

$(LUA_NL)/src/liblua.a: $(LUA_NL)/src/*.c
	cd $(LUA_NL) && make -j4 linux

$(LUA_CW)/src/liblua.a: $(LUA_CW)/src/*.c
	cd $(LUA_CW) &&make -j4 linux

# Dynamic loading
base64.so:
	cd base64 && make && cp base64.so ..

mathx.so:
	cd mathx && make && cp mathx.so ..

# Generated LX library functions for Lua
generatedlib: lx/*/*.lua lx/*/*.c lx/$(LXLIB)
	./lx/makelib.lua $(LXLIB) generatedlib
	cd generatedlib && make -j32

# Generate heavyweight library
lx/heavy: Makefile
	./generate_heavy.lua 200 500

# Cleanup
clean:
	rm -rf $(OUT) generatedlib

clean-all: clean
	cd $(LUA) && make clean
	cd $(LUA_NL) && make clean
	cd $(LUA_CW) && make clean
