#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

int main (int argc, char **argv) {

  lua_State *L = lua_open();  /* create state */
  if (L == NULL) {
    perror("cannot create state: not enough memory");
    return EXIT_FAILURE;
  }
  luaL_openlibs(L);  /* open libraries */

  luaL_loadstring(L, "print (debug.traceback(tostring(...), 2))");	// error handler
  luaL_loadstring(L, "args = {...}; require 'main'");			// main loader
  int i;
  for (i = 0; i < argc; ++i) {
    lua_pushstring(L, argv[i]);
  }
  int r = lua_pcall(L, argc, LUA_MULTRET, 1);

  lua_close(L);
  return r;
}


