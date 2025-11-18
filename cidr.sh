#!/usr/bin/env bash
# https://stackoverflow.com/questions/16986879/bash-script-to-list-all-ips-in-prefix

BASE_IP=${1%/*}
IP_CIDR=${1#*/}

if [ ${IP_CIDR} -lt 8 ]; then
    echo "Max range is /8."
    exit
fi

IP_MASK=$((0xFFFFFFFF << (32 - ${IP_CIDR})))

IFS=. read a b c d <<<${BASE_IP}

ip=$((($b << 16) + ($c << 8) + $d))

ipstart=$((${ip} & ${IP_MASK}))
ipend=$(((${ipstart} | ~${IP_MASK}) & 0x7FFFFFFF))

seq ${ipstart} ${ipend} | while read i; do
    echo $a.$((($i & 0xFF0000) >> 16)).$((($i & 0xFF00) >> 8)).$(($i & 0x00FF))
done