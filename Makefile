CC=gcc
CFLAGS = -Wall -D__USE_GNU

LIBS+= luajit/src/libluajit.a -lnetfilter_log -lm -ldl
LDFLAGS+= -Wl,-E

luafiles := $(shell find lua ljsyscall -name '*.lua')
LUAOBJS := $(addsuffix .o, $(basename $(luafiles)))

OBJS = nflog_shim.o

debug:clean luajit $(OBJS) $(LUAOBJS)
	$(CC) $(CFLAGS) -g main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nflogsflowd $(LDFLAGS)
stable:clean luajit $(OBJS) $(LUAOBJS) nfsf.o
	$(CC) $(CFLAGS) main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nflogsflowd $(LDFLAGS)
clean:
	rm -vfr *~ nflogsflowd

.PHONY: luajit
luajit:
	cd luajit && $(MAKE)

%.o: %.lua
	LUA_PATH='./luajit/src/?.lua' luajit/src/luajit -bgn $(subst /,_,$(patsubst lua/%,%,$(patsubst ljsyscall/%,%,$(basename $<)))) $< $@
