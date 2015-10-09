
local ffi = require 'ffi'
local S = require 'syscall'
local utils = require 'utils'
local nflog = require 'nflog'
local sflow = require 'sflow'

local opts = utils.getargs(unpack(args))

-- sFlow collecting 'port'
local outport = sflow.Port({
	address = opts['agent-id'],
	max_sample = tonumber(opts['max-sample']) or 160,
	max_packet = tonumber(opts['mtu']) or 1480,
	subagent = tonumber(opts['agent-id']) or 0,
	samplerate = tonumber(opts['sampling-rate']) or 2048,
})

-- output UDP socket
local dstip, dstport = opts.collector:match('([%d.]+):(%d+)')
local outsock = assert(S.socket('INET', 'DGRAM', 'UDP'))
local dstaddr = assert(S.t.sockaddr_in(dstport, dstip))
local function send(buf, sz)
	outsock:sendto(buf, sz, 0, dstaddr)
end

-- nflog handler
local logh = nflog(S.c.AF.INET6, tonumber(opts['nflog-group']))

local buf = ffi.new('uint8_t[?]', 8192)
logh:loop(function(sample)
	-- copy header+payload of each sample and add to the sflow port
	local offset = 0

	ffi.copy(buf + offset, sample.header.p, sample.header.size)
	offset = offset + sample.header.size

	ffi.copy(buf + offset, sample.payload.p, sample.payload.size)
	offset = offset + sample.payload.size

	outport:add(buf, {incl_len=offset, orig_len=offset})
	if outport:full() then
		send(outport:flush())
	end
end)

if not outport:empty() then
	send(outport:flush())
end
outsock:close()
