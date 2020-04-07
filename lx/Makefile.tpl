CFLAGS_RELEASE = -O2
CFLAGS_DEBUG = -ggdb -fno-omit-frame-pointer -fsanitize=address -fsanitize=null
CFLAGS = -std=gnu99 -fwrapv -Wall -Wextra -pedantic $(CFLAGS_RELEASE)
# CFLAGS = -std=gnu99 -fwrapv -Wall -Wextra -pedantic $(CFLAGS_DEBUG)
LDFLAGS = -ldl -lm
LUA = ../lua-5.4.0-beta/src
OBJS = lx.o {{OBJECTS}}

all: $(OBJS)

lx.o: lx.c lx.h
	$(CC) $(CFLAGS) -I$(LUA) -c -o $@ $<
{{TARGETS}}

clean:
	rm -rf $(OBJS)
