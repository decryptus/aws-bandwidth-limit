#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

DW_AWS_BL_CUBL_BIN="curl"
DW_AWS_BL_CUT_BIN="cut"
DW_AWS_BL_GREP_BIN="grep"
DW_AWS_BL_IPT_BIN="iptables"
DW_AWS_BL_JQ_BIN="jq"
DW_AWS_BL_SORT_BIN="sort"
DW_AWS_BL_TC_BIN="tc"
DW_AWS_BL_XARGS_BIN="xargs"

DW_AWS_BL_IPS_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"
DW_AWS_BL_REGION="eu-west-3"
DW_AWS_BL_SERVICE="S3"

DW_AWS_BL_IPT_COMMENT="DW: ${DW_AWS_BL_SERVICE} Bandwidth Limit"
DW_AWS_BL_IFACE="eth0"
DW_AWS_BL_CLASS_ID="5"
DW_AWS_BL_BITRATE="200mbit"

${DW_AWS_BL_TC_BIN} qdisc del dev ${DW_AWS_BL_IFACE} root
${DW_AWS_BL_TC_BIN} qdisc replace dev ${DW_AWS_BL_IFACE} root handle 1: htb
${DW_AWS_BL_TC_BIN} class replace dev ${DW_AWS_BL_IFACE} parent 1: classid 1:${DW_AWS_BL_CLASS_ID} htb rate ${DW_AWS_BL_BITRATE} prio 0
${DW_AWS_BL_TC_BIN} filter replace dev ${DW_AWS_BL_IFACE} parent 1: prio 0 protocol ip handle ${DW_AWS_BL_CLASS_ID} fw flowid 1:${DW_AWS_BL_CLASS_ID}
${DW_AWS_BL_TC_BIN} qdisc replace dev ${DW_AWS_BL_IFACE} parent 1:${DW_AWS_BL_CLASS_ID} sfq

${DW_AWS_BL_IPT_BIN} -t mangle -L OUTPUT --line-numbers|\
  ${DW_AWS_BL_GREP_BIN} "${DW_AWS_BL_IPT_COMMENT}"|\
  ${DW_AWS_BL_CUT_BIN} -d' ' -f1|\
  ${DW_AWS_BL_SORT_BIN} -r|\
  ${DW_AWS_BL_XARGS_BIN} --no-run-if-empty -n 1 ${DW_AWS_BL_IPT_BIN} -t mangle -D OUTPUT

for DW_AWS_BL_IP in `${DW_AWS_BL_CUBL_BIN} -s "${DW_AWS_BL_IPS_URL}"|\
  ${DW_AWS_BL_JQ_BIN} -r ".prefixes[] | select(.region==\"${DW_AWS_BL_REGION}\") | select(.service==\"${DW_AWS_BL_SERVICE}\") | .ip_prefix"`
do
  ${DW_AWS_BL_IPT_BIN} -A OUTPUT -t mangle -p tcp -d "${DW_AWS_BL_IP}" --dport 443 -j MARK --set-mark 5 -m comment --comment "${DW_AWS_BL_IPT_COMMENT}"
done
