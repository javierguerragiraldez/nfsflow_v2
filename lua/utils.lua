local bit = require 'bit'
local ffi = require 'ffi'
local utils = {}

-- ljsyscall needs a slightly better 'assert()'
function newassert(cond, err, ...)
	if cond then return cond, err, ... end
	error (tostring(err or "assertion failed!"), 2)
end

-- install new assert, keep the old one as _assert
assert, _assert = newassert, assert

-- returns commandline args as a Lua table
function utils.getargs(...)
	local out = {}
	for i = 1, select('#', ...) do
		local arg = select(i, ...)
		local k, v = arg:match('^-+([^=]+)=?(.*)$')
		if k and v then
			out[k] = v
		end
	end
	return out
end

-- debugger's best friend
function utils.hexdump(buf, n)
	buf = ffi.cast('uint8_t*', buf)
	for i = 0, n-1 do
		if i%16 == 0 then
			io.write('\n', bit.tohex(i,-4), ':')
		end
		io.write(' ', bit.tohex(buf[i], -2))
	end
	io.write('\n')
end

return utils
