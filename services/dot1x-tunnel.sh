#!/bin/sh

set -eu

case "${1:-}" in
start)
	LOCAL=${LOCAL:-$(ip route get 1.1.1.1 | sed -ne 's/.* src \([^ ]*\).*/\1/ p')}
	REMOTE=${REMOTE:-$(ip route get 1.1.1.1 | sed -ne 's/.* via \([^ ]*\).*/\1/ p')}

	ip l2tp del tunnel tunnel_id 1 || true
	sleep 1 # racey :(

	ip l2tp add tunnel local $LOCAL remote $REMOTE tunnel_id 1 peer_tunnel_id 1 encap udp udp_sport 1701 udp_dport 1701
	ip l2tp add session name dot1x tunnel_id 1 session_id 0xffffffff peer_session_id 0xffffffff

	ip addr add 172.23.5.1/24 dev dot1x

	ip link set dot1x up
	;;
stop)
	ip l2tp del tunnel tunnel_id 1 || true
	;;
*)	echo 'start or stop?' >&2
	exit 1
	;;
esac

exit 0
