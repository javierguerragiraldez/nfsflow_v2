CC=gcc
CFLAGS="-Wall"

debug:clean
	$(CC) $(CFLAGS) -g -o nfsf main.c
stable:clean
	$(CC) $(CFLAGS) -o nfsf main.c
clean:
	rm -vfr *~ nfsf
