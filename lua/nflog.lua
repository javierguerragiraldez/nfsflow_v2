
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

local function chkerr(r, err)
	assert(r >= 0, err)
	return r
end

function nflog:__new(family, group)
	local handle = nflog_lib.nflog_open()
	assert (handle ~= nil)

	chkerr(nflog_lib.nflog_unbind_pf(handle, S.c.AF.INET))
	chkerr(nflog_lib.nflog_unbind_pf(handle, S.c.AF.INET6))

	chkerr(nflog_lib.nflog_bind_pf(handle, family))

	local g_handle = assert(nflog_lib.nflog_bind_group(handle, group))
	chkerr(nflog_lib.nflog_set_mode(g_handle, ffi.C.NFULNL_COPY_PACKET, 0xFFFF))

	nflog_lib.nflog_callback_register(g_handle, C.cb, samplearray)

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

		local sz, err = assert(S.recv(fd, buf, size))

		nflog_lib.nflog_handle_packet(self, buf, sz)

		for i = 0, samplearray.n do
			cb(samplearray.sample[i])
		end
		samplearray.n = 0
	end
end

return ffi.metatype ('nflog_handle', nflog)
