#!/bin/bash
#
# src: unknown
###
# Clear out any and all existing rules
# Copied and pasted from time enternal
# It's uber-overkill, but hey, what good script isn't?
###

# Hardcode to have as few dependencies as possible
#iptables_cmd="$(which iptables)"
iptables_cmd="/sbin/iptables"
for a in $(cat /proc/net/ip_tables_names); do
${iptables_cmd} -F -t $a
${iptables_cmd} -X -t $a

if [ $a == nat ]; then
   ${iptables_cmd} -t nat -P PREROUTING ACCEPT
   ${iptables_cmd} -t nat -P POSTROUTING ACCEPT
   ${iptables_cmd} -t nat -P OUTPUT ACCEPT
elif [ $a == mangle ]; then
   ${iptables_cmd} -t mangle -P PREROUTING ACCEPT
   ${iptables_cmd} -t mangle -P INPUT ACCEPT
   ${iptables_cmd} -t mangle -P FORWARD ACCEPT
   ${iptables_cmd} -t mangle -P OUTPUT ACCEPT
   ${iptables_cmd} -t mangle -P POSTROUTING ACCEPT
elif [ $a == filter ]; then
   ${iptables_cmd} -t filter -P INPUT ACCEPT
   ${iptables_cmd} -t filter -P FORWARD ACCEPT
   ${iptables_cmd} -t filter -P OUTPUT ACCEPT
fi
done


#ip6tables_cmd="$(which ip6tables)"
ip6tables_cmd="/sbin/ip6tables"
# ip6tables version
for a in $(cat /proc/net/ip6_tables_names); do
${ip6tables_cmd} -F -t $a
${ip6tables_cmd} -X -t $a

if [ $a == nat ]; then
   ${ip6tables_cmd} -t nat -P PREROUTING ACCEPT
   ${ip6tables_cmd} -t nat -P POSTROUTING ACCEPT
   ${ip6tables_cmd} -t nat -P OUTPUT ACCEPT
elif [ $a == mangle ]; then
   ${ip6tables_cmd} -t mangle -P PREROUTING ACCEPT
   ${ip6tables_cmd} -t mangle -P INPUT ACCEPT
   ${ip6tables_cmd} -t mangle -P FORWARD ACCEPT
   ${ip6tables_cmd} -t mangle -P OUTPUT ACCEPT
   ${ip6tables_cmd} -t mangle -P POSTROUTING ACCEPT
elif [ $a == filter ]; then
   ${ip6tables_cmd} -t filter -P INPUT ACCEPT
   ${ip6tables_cmd} -t filter -P FORWARD ACCEPT
   ${ip6tables_cmd} -t filter -P OUTPUT ACCEPT
fi
done
