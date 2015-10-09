
local bit = require 'bit'
local ffi = require 'ffi'
local C = ffi.C
local S = require 'syscall'
local utils = require 'utils'

local nflog_lib = ffi.load('netfilter_log')
ffi.cdef [[
	static const int NFULNL_COPY_NONE = 0x00;
	static const int NFULNL_COPY_META = 0x01;
	static const int NFULNL_COPY_PACKET = 0x02;

	typedef struct nflog_handle {
		struct nfnl_handle *nfnlh;
		struct nfnl_subsys_handle *nfnlssh;
		struct nflog_g_handle *gh_list;
	} nflog_handle;

	typedef int nflog_callback(struct nflog_g_handle *gh, struct nfgenmsg *nfmsg,
			struct nflog_data *nfd, void *data);

	typedef struct nflog_g_handle {
		struct nflog_g_handle *next;
		struct nflog_handle *h;
		uint16_t id;

		nflog_callback *cb;
		void *data;
	} nflog_g_handle;

	struct nfgenmsg {
		uint8_t  nfgen_family;		/* AF_xxx */
		uint8_t  version;		/* nfnetlink version */
		uint16_t    res_id;		/* resource id */
	};
	struct nfnlhdr {
		struct nlmsghdr nlh;
		struct nfgenmsg nfmsg;
	};

	typedef struct nflog_data {
		struct nfattr **nfa;
	} nflog_data;

	extern int nflog_errno;
	extern int errno;

	extern struct nflog_handle *nflog_open(void);
	extern int nflog_close(struct nflog_handle *h);
	extern int nflog_fd(struct nflog_handle *h);

	extern int nflog_bind_pf(struct nflog_handle *h, uint16_t pf);
	extern int nflog_unbind_pf(struct nflog_handle *h, uint16_t pf);

	extern struct nflog_g_handle *nflog_bind_group(struct nflog_handle *h, uint16_t num);
	extern int nflog_set_mode(struct nflog_g_handle *gh, uint8_t mode, unsigned int len);

	extern int nflog_callback_register(struct nflog_g_handle *gh,
				    nflog_callback *cb, void *data);
	extern int nflog_handle_packet(struct nflog_handle *h, char *buf, int len);

	extern uint16_t nflog_get_msg_packet_hwhdrlen(struct nflog_data *nfad);
	extern char *nflog_get_msg_packet_hwhdr(struct nflog_data *nfad);
	extern int nflog_get_payload(struct nflog_data *nfad, char **data);


	typedef struct {
		char *p;
		int size;
	} buf;

	typedef struct {
		buf header, payload;
	} logsample;

	typedef struct {
		int n;
		logsample sample[?];
	} samplearray;

	nflog_callback cb;
]]

local nflog = {}
nflog.__index = nflog

local samplearray = ffi.new('samplearray', 1024)
samplearray.n = 0

local function chk(cond, r, l)
	r = r or 0
	if cond then return cond end
	error (("r:%d errno:%d nflog_errno:%d"):format(
		tonumber(r), tonumber(ffi.C.errno), tonumber(nflog_lib.nflog_errno)),
		l or 2)
end

local function chkerr(r, err)
	chk (tonumber(r) >= 0, r, 3)
	return r
end

function nflog:__new(family, group)
	local handle = nflog_lib.nflog_open()
	assert (handle ~= nil)

	chkerr(nflog_lib.nflog_unbind_pf(handle, S.c.AF.INET))
	chkerr(nflog_lib.nflog_unbind_pf(handle, S.c.AF.INET6))

	chkerr(nflog_lib.nflog_bind_pf(handle, family))

	local g_handle = nflog_lib.nflog_bind_group(handle, group)
	chk (g_handle ~= nil)
	chkerr(nflog_lib.nflog_set_mode(g_handle, ffi.C.NFULNL_COPY_PACKET, 0xFFFF))


	nflog_lib.nflog_callback_register(g_handle, C.cb, samplearray)
	print ('trying callback')
	C.cb(nil, nil, nil, nil)
	print ('go on..')

	return handle
end

function nflog:__gc()
	chkerr(nflog_lib.nflog_close(self))
end

function nflog:getfd()
	return chkerr(nflog_lib.nflog_fd(self))
end


function nflog:loop(cb)
	local fd = self:getfd()
	local size = 16384
	local buf = ffi.new('uint8_t[?]', size)
	while true do

		local sz, err = S.recv(fd, buf, size)
		if not sz then error(tostring(err)) end
-- 		print ('packet size', sz, buf)

		nflog_lib.nflog_handle_packet(self, buf, sz)

		for i = 0, samplearray.n do
			cb(samplearray.sample[i])
-- 			local s = samplearray.sample[i]
-- 			print ('header:', s.header.size, s.header.p)
-- 			utils.hexdump(s.header.p, s.header.size)
-- 			print ('payload:', s.payload.size, s.payload.p)
-- 			utils.hexdump(s.payload.p, s.payload.size)
		end
		samplearray.n = 0

-- 		local offs = 0
-- 		while offs < sz do
-- 			local hdr = ffi.cast('struct nfnlhdr*', buf+offs)
-- 			print ('type', hdr.nlh.nlmsg_type, 'length', hdr.nlh.nlmsg_len)
-- 			print (("flags %X, seq:%d, pid:%d"):format(
-- 				hdr.nlh.nlmsg_flags, hdr.nlh.nlmsg_seq, hdr.nlh.nlmsg_pid))
--
-- -- 			do
-- -- 				local hda = get_hda(buf+offs+ffi.sizeof('struct nfnlhdr'))
-- -- 				local buf = nflog_lib.nflog_get_msg_packet_hwhdr(hda)
-- -- 				local sz  = nflog_lib.nflog_get_msg_packet_hwhdrlen(hda)
-- -- 				print ('header length:', sz)
-- -- 				utils.hexdump(buf, sz)
-- --
-- -- 				local buf = ffi.new('uint8_t[?]', 2^16)
-- -- 				local bufp = ffi.new('uint8_t*[1]')
-- -- 				bufp[0] = buf
-- -- 				local sz = nflog_lib.nflog_get_payload(hda, bufp)
-- -- 				print ('payload length:', sz)
-- -- 				utils.hexdump(buf, sz)
-- -- 			end
--
-- 			if tonumber(hdr.nlh.nlmsg_type) == 1024 then
-- 				local r = cb(
-- 					buf + offs + ffi.sizeof('struct nlmsghdr'),
-- 					hdr.nlh.nlmsg_len - ffi.sizeof('struct nlmsghdr'))
-- 				if r == false then break end
-- 			end
-- 			offs = offs + hdr.nlh.nlmsg_len
-- 		end
-- 		utils.hexdump(buf, sz)
	end
end

return ffi.metatype ('nflog_handle', nflog)
