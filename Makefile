CC=gcc
CFLAGS = -Wall -D__USE_GNU

LIBS+= luajit/src/libluajit.a -lnetfilter_log -lm -ldl
LDFLAGS+= -Wl,-E

luafiles := $(shell find lua ljsyscall -name '*.lua')
LUAOBJS := $(addsuffix .o, $(luafiles))

OBJS = nflog_shim.o

debug:clean luajit $(OBJS) $(LUAOBJS)
	$(CC) $(CFLAGS) -g main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nfsf $(LDFLAGS)
stable:clean luajit $(OBJS) $(LUAOBJS) nfsf.o
	$(CC) $(CFLAGS) main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nfsf $(LDFLAGS)
clean:
	rm -vfr *~ nfsf

.PHONY: luajit
luajit:
	cd luajit && $(MAKE)

.SUFFIXES:

%.lua.o: %.lua
	LUA_PATH='./luajit/src/?.lua' luajit/src/luajit -bgn $(subst /,_,$(patsubst lua/%,%,$(patsubst ljsyscall/%,%,$(basename $<)))) $< $@
