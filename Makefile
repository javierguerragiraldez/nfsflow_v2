CC=gcc
CFLAGS = -Wall -D__USE_GNU

LIBS+= libs/libluajit.a -lnetfilter_log -lm -ldl
LDFLAGS+= -Wl,-E

luafiles := $(shell ls lua/*.lua)
LUAOBJS := $(addsuffix .o, $(luafiles))

OBJS = nflog_shim.o

debug:clean $(OBJS) $(LUAOBJS)
	$(CC) $(CFLAGS) -g main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nfsf $(LDFLAGS)
stable:clean $(OBJS) $(LUAOBJS) nfsf.o
	$(CC) $(CFLAGS) main.c $(OBJS) $(LUAOBJS) $(LIBS) -o nfsf $(LDFLAGS)
clean:
	rm -vfr *~ nfsf

%.lua.h: %.lua
	luajit -bg $< $@

%.lua.o: %.lua
	luajit -bg $< $@
