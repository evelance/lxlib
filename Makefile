# Select one of these:
# base  = Lua5.4-beta standard libraries
# basex = base + LuaFileSystem + some LHF libraries
# heavy = basex + many auto-generated modules
LXLIB=base

CFLAGS_GENERAL = -Wshadow -Wsign-compare -Wundef -Wwrite-strings -Wredundant-decls -Wdisabled-optimization  \
                 -Wmissing-prototypes -Wnested-externs -Wstrict-prototypes -Wc++-compat -Wold-style-definition
CFLAGS_DEBUG = -ggdb -fno-omit-frame-pointer -fsanitize=address -fsanitize=null
CFLAGS_RELEASE = -O2
CFLAGS = -std=gnu99 -fwrapv -Wall -Wextra -pedantic $(CFLAGS_RELEASE) -DLXLIB=lx_$(LXLIB)
# CFLAGS = -std=gnu99 -fwrapv -Wall -Wextra -pedantic $(CFLAGS_DEBUG)
LUA = lua-5.4.0-beta
LUA_NL = lua-5.4.0-beta-nolibs
LUAC = $(LUA)/src/luac
OUT = script.lbc out-normal out-lx out-lua54-normal out-lua54-lx

all: $(OUT)

run: $(OUT)
	./out-lx
	./out-normal

# Test programs
out-normal: main.c
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src $< $(LUA)/src/liblua.a -ldl -lm

out-lx: main.c generatedlib Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -I./generatedlib -DUSELX $< generatedlib/*.o $(LUA_NL)/src/liblua.a -ldl -lm

# Command line Lua for experimenting
out-lua54-normal: lua54.c
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -DLUA_USE_LINUX -DLUA_USE_READLINE $< $(LUA)/src/liblua.a -ldl -lm -lreadline

out-lua54-lx: lua54.c generatedlib Makefile
	$(CC) $(CFLAGS) -o $@ -I$(LUA)/src -I./generatedlib -DLUA_USE_LINUX -DLUA_USE_READLINE -DUSELX $< generatedlib/*.o $(LUA_NL)/src/liblua.a -ldl -lm -lreadline

# Generated LX library functions for Lua
generatedlib: lx/*/*.lua lx/*/*.c lx/$(LXLIB) Makefile
	./lx/makelib.lua $(LXLIB) generatedlib
	cd generatedlib && make -j32

# Precompiled Lua byte code
script.lbc: script.lua Makefile
	$(LUAC) -o $@ $<

# Generate heavyweight library
lx/heavy: Makefile
	./generate_heavy.lua 200 500

# Cleanup
clean:
	rm -rf $(OUT) generatedlib

clean-all: clean
	cd $(LUA) && make clean
	cd $(LUA_NL) && make clean
