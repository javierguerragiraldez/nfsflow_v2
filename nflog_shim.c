#include <stdint.h>
#include <stdio.h>

typedef uint8_t u_int8_t;
typedef uint16_t u_int16_t;
typedef uint32_t u_int32_t;

#include <libnetfilter_log/libnetfilter_log.h>

typedef struct {
	char *p;
	int size;
} buf;

typedef struct {
	buf header, payload;
} logsample;

typedef struct {
	int n;
	logsample sample[];
} samplearray;



int cb(struct nflog_g_handle *gh,
			  struct nfgenmsg *nfmsg,
			  struct nflog_data *nfa, void *data) {
	if (!data) return 0;

	samplearray *out = (samplearray *)data;
	logsample *sample = &out->sample[out->n];

	sample->header.p = nflog_get_msg_packet_hwhdr(nfa);
	sample->header.size = nflog_get_msg_packet_hwhdrlen(nfa);
	sample->payload.size = nflog_get_payload(nfa, &sample->payload.p);
	++out->n;

	return 0;
}
