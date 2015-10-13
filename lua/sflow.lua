
local bit = require 'bit'
local ffi = require 'ffi'
local S = require 'syscall'
local utils = require 'utils'

ffi.cdef [[

	typedef struct {
		n32_t version;
		n32_t xx01;
		uint32_t ag_address;	// IPv4 addr
		n32_t sub_agnt_id;
		n32_t seq;
		n32_t uptime;
		n32_t numsamples;
	} sf_header;

	typedef struct {
		n32_t type;
		n32_t length;
		n32_t seq;
		n32_t src_class_idx;
		n32_t samplerate;
		n32_t poolsize;
		n32_t dropped;
		n32_t intf_in;
		n32_t intf_out;
		n32_t flow_record;
	} sf_sample;

	typedef struct {
		n32_t type;
		n32_t length;
		n32_t protocol;
		n32_t framelength;
		n32_t payload_removed;
		n32_t payload_size;
	} sf_pkt_header;

	typedef struct {
		n32_t type;
		n32_t length;
		n32_t incoming_vlan;
		n32_t incoming_priority;
		n32_t outgoing_vlan;
		n32_t outgoing_priority;
	} sf_ext_switch;


	typedef struct {
		int size;
		int used;
		int max_sample;
		sf_header proto_header;
		sf_sample proto_sample;
		sf_pkt_header proto_pkth;
		uint8_t buf[?];
	} sf_port;
]]


local Port = {}
Port.__index = Port

local htonl = bit.bswap
local localtime = 1			-- TODO: get time sporadically

function Port:__new(opts)
	local max_sample = opts.max_sample or 160
	local max_packet = opts.max_packet or 1500

	local port = ffi.new('sf_port', max_packet, {
		size = max_packet,
		used = 0,
		max_sample = max_sample,
		proto_header = {
			version = {htonl(5)},
			xx01 = {htonl(1)}, 		-- ??
			ag_address = S.t.in_addr(opts.address).s_addr,
			sub_agnt_id = {htonl(opts.subagent)},
			seq = {htonl(1)},				-- pick from somewhere?
			uptime = {htonl(localtime)},
			numsamples = {0},
		},
		proto_sample = {
			type = {htonl(1)},
			length = {htonl(ffi.sizeof('sf_sample') - 8)},
			seq = {0},
			src_class_idx = {0},		-- ??
			samplerate = {htonl(opts.samplerate)},
			dopped = {0},
			intf_in = {opts.intf_in or 0},
			intf_out = {opts.intf_out or 0},
			flow_record = {htonl(1)},
		},
		proto_pkth = {
			type = {htonl(1)},
			length = {htonl(ffi.sizeof('sf_pkt_header') - 8)},
			protocol = {htonl(1)},
			framelength = {0},
			payload_removed = {0},
			payload_size = {0},
		},
	})
	return port
end

function Port:start_packet()
	ffi.copy(self.buf, self.proto_header, ffi.sizeof(self.proto_header))
	self.used = ffi.sizeof('sf_header')
end

function Port:add(p, r)
	local samplesize = math.min(r.incl_len, self.max_sample)
	if self:full(samplesize) then
		self:flush()
		self.proto_sample.dropped.h = self.proto_sample.dropped.h + 1
	end
	if self:empty() then
		self:start_packet()
	end
	local headerptr = ffi.cast('sf_header*', self.buf)
	headerptr.numsamples.h = headerptr.numsamples.h + 1

	local sampleptr = ffi.cast('sf_sample*', self.buf+self.used)
	self.proto_sample.seq.h = self.proto_sample.seq.h + 1
	ffi.copy(sampleptr, self.proto_sample, ffi.sizeof(self.proto_sample))
	self.used = self.used + ffi.sizeof(self.proto_sample)
	sampleptr.length.h = sampleptr.length.h + ffi.sizeof('sf_pkt_header') + samplesize

	local pkthptr = ffi.cast('sf_pkt_header*', self.buf+self.used)
	ffi.copy(pkthptr, self.proto_pkth, ffi.sizeof(self.proto_pkth))
	self.used = self.used + ffi.sizeof(self.proto_pkth)
	pkthptr.length.h = pkthptr.length.h + samplesize
	pkthptr.framelength.h = r.orig_len
	pkthptr.payload_removed.h = r.orig_len - samplesize
	pkthptr.payload_size.h = samplesize

	ffi.copy(self.buf + self.used, p, samplesize)
	self.used = self.used + samplesize
end

function Port:full(sz)
	sz = sz or self.max_sample
	return self.used >= self.size
		- ffi.sizeof('sf_sample')
		- ffi.sizeof('sf_pkt_header')
		- ffi.sizeof('uint32_t')
		- sz
end

function Port:empty()
	return self.used == 0
end

function Port:flush()
	local markptr = ffi.cast('uint32_t*', self.buf+self.used)
	markptr[0] = htonl(0x0011)
	self.used = self.used + ffi.sizeof('uint32_t')
	local size = self.used
	self.used = 0
	return self.buf, size
end

ffi.metatype('sf_port', Port)

return {
	Port = ffi.typeof('sf_port'),
}
