#!/bin/bash
# Set iptables rules
#
# Environment Variables:
#   VERBOSE - if 'true' will print out some extra information. Without this it
#     will not output anything unless an error occurs
#   DEBUG - if 'true' will print each line as it runs
#

set -e
set -u

if [[ $EUID -ne 0 ]]; then
    echo "Must be run as root"
    exit 1
fi

readonly VERBOSE=${VERBOSE:-false}
readonly DEBUG=${DEBUG:-false}

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi

# setup IPv6 as well?
setup_ipv6=false


# Logging Functions
# Usage: log "What to log"
log () {
    printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
}
# Usage: verbose "What to log if VERBOSE is true"
verbose () {
    if [[ "${VERBOSE}" == "true" ]]; then
        log "$*"
    fi
}


if [ "${setup_ipv6}" == "true" ]; then
    ip6tables_cmd=$(which ip6tables) || eval "echo 'Please install ip6tables'; exit 1"
fi
iptables_cmd=$(which iptables) || eval "echo 'Could not find iptables'; exit 1"


verbose "Setting iptables rules"
# Start from scratch
${iptables_cmd} -F
${iptables_cmd} -Z
${iptables_cmd} -X

# LIMIT chain, used as endpoint of limited connections
${iptables_cmd} -N LIMIT
${iptables_cmd} -A LIMIT -m limit --limit 3/min -j LOG --log-prefix "[LIMIT BLOCK] "
${iptables_cmd} -A LIMIT -j REJECT --reject-with icmp-port-unreachable

# Allow existing connections
# For OpenVZ servers:
#   - need to modprobe xt_tcpudp, ip_conntrack, and xt_state
#   - uncomment the state line and comment out the conntrack line if it doesn't
#     work.
#${iptables_cmd} -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${iptables_cmd} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# allow local interface
${iptables_cmd} -A INPUT -i lo -j ACCEPT

# limit how fast incoming ssh connections can happen
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW -m recent --set --name DEFAULT --rsource
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW -m recent --update --seconds 30 --hitcount 6 --name DEFAULT --rsource -j LIMIT
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# some ports to allow
# ssh is handled above
#${iptables_cmd} -A INPUT -p tcp --dport 22 -j ACCEPT
${iptables_cmd} -A INPUT -p tcp --dport 80 -j ACCEPT
# example to allow full access from a single ip
#${iptables_cmd} -A INPUT -s 192.231.162.0/24 -j ACCEPT

# ok icmp codes
${iptables_cmd} -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type source-quench -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
# can lower this if you're paranoid but 1 ping a second is fine.  If someone is trying
# to ping flood they're going to do several a second
${iptables_cmd} -A INPUT -p icmp --icmp-type echo-request -j ACCEPT -m limit --limit 60/minute

# log unhandled packets
# Once you have things setup probably want to comment this out so you're not filling logs
${iptables_cmd} -A INPUT -m limit --limit 15/min -j LOG --log-prefix "[UNHANDLED INPUT PKT] "


# by default allow outgoing traffic, no incoming
${iptables_cmd} -P INPUT DROP
${iptables_cmd} -P FORWARD DROP
${iptables_cmd} -P OUTPUT ACCEPT

verbose "iptables setup has completed. Can view stats by running 'iptables -nvL' as root"

if [[ "${setup_ipv6}" == "true" ]]; then
    verbose "Setting IPv6 rules"
    # Only commenting on differences
    ${ip6tables_cmd} -F
    ${ip6tables_cmd} -Z
    ${ip6tables_cmd} -X

    # again, choose either conntrack or state, don't need both
    #${ip6tables_cmd} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ${ip6tables_cmd} -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ${ip6tables_cmd} -A INPUT -i lo -j ACCEPT
    # allow link-local communications
    ${ip6tables_cmd} -A INPUT -s fe80::/10 -j ACCEPT
    # for stateless autoconfiguration (restrict NDP messages to hop limit of 255)
    # commented out on openvz containers
    #${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type neighbor-solicitation -m hl --hl-eq 255 -j ACCEPT
    #${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type neighbor-advertisement -m hl --hl-eq 255 -j ACCEPT
    #${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type router-solicitation -m hl --hl-eq 255 -j ACCEPT
    #${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type router-advertisement -m hl --hl-eq 255 -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p tcp --dport 22 -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p tcp --dport 80 -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type time-exceeded -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type parameter-problem -j ACCEPT
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type echo-request -j ACCEPT -m limit --limit 60/minute
    # need this for ip6tables but not iptables
    ${ip6tables_cmd} -A INPUT -p icmpv6 --icmpv6-type echo-reply -j ACCEPT

    ${ip6tables_cmd} -P INPUT DROP
    ${ip6tables_cmd} -P FORWARD DROP
    ${ip6tables_cmd} -P OUTPUT ACCEPT

    verbose "ip6tables setup has completed. Can view stats by running 'ip6tables -nvL' as root"
fi

exit 0
