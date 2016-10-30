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

if ! command -v "${iptables_cmd}" 1>/dev/null; then
    echo "[ipv4] Could not find ${iptables_cmd}. Skipping." >&2
else
    while read -r tablename; do
        ${iptables_cmd} -F -t "${tablename}"
        ${iptables_cmd} -X -t "${tablename}"

        if [ "${tablename}" == "nat" ]; then
            ${iptables_cmd} -t nat -P PREROUTING ACCEPT
            ${iptables_cmd} -t nat -P POSTROUTING ACCEPT
            ${iptables_cmd} -t nat -P OUTPUT ACCEPT
        elif [ "${tablename}" == "mangle" ]; then
            ${iptables_cmd} -t mangle -P PREROUTING ACCEPT
            ${iptables_cmd} -t mangle -P INPUT ACCEPT
            ${iptables_cmd} -t mangle -P FORWARD ACCEPT
            ${iptables_cmd} -t mangle -P OUTPUT ACCEPT
            ${iptables_cmd} -t mangle -P POSTROUTING ACCEPT
        elif [ "${tablename}" == "filter" ]; then
            ${iptables_cmd} -t filter -P INPUT ACCEPT
            ${iptables_cmd} -t filter -P FORWARD ACCEPT
            ${iptables_cmd} -t filter -P OUTPUT ACCEPT
        fi
    done </proc/net/ip_tables_names
fi


# ip6tables version
#ip6tables_cmd="$(which ip6tables)"
ip6tables_cmd="/sbin/ip6tables"
if ! command -v "${ip6tables_cmd}" 1>/dev/null; then
    echo "[ipv6] Could not find ${ip6tables_cmd}. Skipping." >&2
else
    while read -r tablename; do
        ${ip6tables_cmd} -F -t "${tablename}"
        ${ip6tables_cmd} -X -t "${tablename}"

        if [ "${tablename}" == "nat" ]; then
            ${ip6tables_cmd} -t nat -P PREROUTING ACCEPT
            ${ip6tables_cmd} -t nat -P POSTROUTING ACCEPT
            ${ip6tables_cmd} -t nat -P OUTPUT ACCEPT
        elif [ "${tablename}" == "mangle" ]; then
            ${ip6tables_cmd} -t mangle -P PREROUTING ACCEPT
            ${ip6tables_cmd} -t mangle -P INPUT ACCEPT
            ${ip6tables_cmd} -t mangle -P FORWARD ACCEPT
            ${ip6tables_cmd} -t mangle -P OUTPUT ACCEPT
            ${ip6tables_cmd} -t mangle -P POSTROUTING ACCEPT
        elif [ "${tablename}" == "filter" ]; then
            ${ip6tables_cmd} -t filter -P INPUT ACCEPT
            ${ip6tables_cmd} -t filter -P FORWARD ACCEPT
            ${ip6tables_cmd} -t filter -P OUTPUT ACCEPT
        fi
    done </proc/net/ip_tables_names
fi
