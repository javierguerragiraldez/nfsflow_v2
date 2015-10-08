CC=gcc
CFLAGS = -Wall -D__USE_GNU

LIBS+= libs/libluajit.a
LDFLAGS+= -Wl,-E

luafiles := $(shell ls lua/*.lua)
LUAOBJS := $(addsuffix .o, $(luafiles))

debug:clean $(LUAOBJS)
	$(CC) $(CFLAGS) -g main.c $(LUAOBJS) $(LIBS) -lm -ldl -o nfsf $(LDFLAGS)
stable:clean $(LUAOBJS) nfsf.o
	$(CC) $(CFLAGS) main.c $(LUAOBJS) $(LIBS) -lm -ldl -o nfsf $(LDFLAGS)
clean:
	rm -vfr *~ nfsf

%.lua.h: %.lua
	luajit -b $< $@

%.lua.o: %.lua
	luajit -b $< $@