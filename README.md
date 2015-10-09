# nfsflow_v2
self-contained NFLOG -> sFlow connector

It's a userspace tool to collect packets sent to NFLOG target from an iptables rule like this:

    sudo iptables -A INPUT -p udp -j NFLOG --nflog-group=30

and send (part-of) them as sFlow packets.

Currently recognizes the following options:

		--help				this help text
		--agent-id=<ipaddr>		        (required)
		--max-sample=<max samplesize> 	(default 160 bytes)
		--mtu=<max_packetsize>		    (default 1480 bytes)
		--sampling-rate=<declared-rate> (default 2048)
		--collector=<ip:port>		    (required)
		--nflog-group=<group>		    (required)


It depends on the `libnetfilter-log` library and headers, avaliable as `libnetfilter-log-dev` on Ubuntu.
