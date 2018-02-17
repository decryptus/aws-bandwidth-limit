#!/bin/bash

# title       :dw-aws-bandwith-limit.sh
# description :This script permit to limit outgoing bandwidth on AWS service
# author      :Adrien DELLE CAVE (decryptus)
# date        :2018-02-17
# version     :0.1

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

DW_AWS_BL_CURL_BIN="${DW_AWS_BL_CURL_BIN:-curl}"
DW_AWS_BL_CUT_BIN="${DW_AWS_BL_CUT_BIN:-cut}"
DW_AWS_BL_GREP_BIN="${DW_AWS_BL_GREP_BIN:-grep}"
DW_AWS_BL_IPT_BIN="${DW_AWS_BL_IPT_BIN:-sudo iptables}"
DW_AWS_BL_JQ_BIN="${DW_AWS_BL_JQ_BIN:-jq}"
DW_AWS_BL_SORT_BIN="${DW_AWS_BL_SORT_BIN:-sort}"
DW_AWS_BL_TC_BIN="${DW_AWS_BL_TC_BIN:-sudo tc}"
DW_AWS_BL_XARGS_BIN="${DW_AWS_BL_XARGS_BIN:-xargs}"

DW_AWS_BL_IPS_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"
DW_AWS_BL_REGION="${DW_AWS_BL_REGION:-eu-west-3}"
DW_AWS_BL_SERVICE="${DW_AWS_BL_SERVICE:-S3}"

DW_AWS_BL_IPT_COMMENT="DW: ${DW_AWS_BL_SERVICE} Bandwidth Limit"
DW_AWS_BL_IFACE="${DW_AWS_BL_IFACE:-eth0}"
DW_AWS_BL_CLASS_ID="5"
DW_AWS_BL_BITRATE="${DW_AWS_BL_BITRATE:-200mbit}"

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

for DW_AWS_BL_IP in `${DW_AWS_BL_CURL_BIN} -s "${DW_AWS_BL_IPS_URL}"|\
  ${DW_AWS_BL_JQ_BIN} -r ".prefixes[]|\
      select(.region==\"${DW_AWS_BL_REGION}\")|\
      select(.service==\"${DW_AWS_BL_SERVICE}\") | .ip_prefix"`
do
  ${DW_AWS_BL_IPT_BIN} -A OUTPUT -t mangle -d "${DW_AWS_BL_IP}" -j MARK --set-mark 5 -m comment --comment "${DW_AWS_BL_IPT_COMMENT}"
done
