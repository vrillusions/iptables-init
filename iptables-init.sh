#!/bin/bash
# Set iptables rules
#
# Environment Variables:
#   VERBOSE - if 'true' will print out some extra information. Without this it
#     will not output anything unless an error occurs
#   DEBUG - if 'true' will print each line as it runs
#
# Syntax notes:
#   In an attempt to not have really long lines I split lines up when setting a
#   new module (the '-m' option). Trying to be consistent even if the line
#   isn't too long.
#
# While the overhead is small keep in mind that iptables rules are evaluated
# from the top down and the first one the matches is the action that is taken.
# If a certain port is really popular you may want to consider moving it further
# up
#

set -e
set -u

if [[ $EUID -ne 0 ]]; then
    printf "%s" "Must be run as root" >&2
    exit 1
fi

readonly VERBOSE="${VERBOSE:-false}"
readonly DEBUG="${DEBUG:-false}"

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi

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


iptables_cmd=$(which iptables) || eval "echo 'Could not find iptables'; exit 1"


verbose "Setting iptables rules"
verbose "Clearing current rules"
# Start from scratch
${iptables_cmd} -F
${iptables_cmd} -Z
${iptables_cmd} -X


# LIMIT chain, used as endpoint of limited connections
verbose "Creating LIMIT chain"
${iptables_cmd} -N LIMIT
${iptables_cmd} -A LIMIT -m limit --limit 3/min -j LOG --log-prefix "[LIMIT BLOCK] "
${iptables_cmd} -A LIMIT -j REJECT --reject-with icmp-port-unreachable


verbose "Creating main iptables rules"
# Allow existing connections
# For OpenVZ servers:
#   - need to modprobe xt_tcpudp, ip_conntrack, and xt_state
#   - uncomment the state line and comment out the conntrack line if it doesn't
#     work.
#${iptables_cmd} -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${iptables_cmd} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


# allow local interface
${iptables_cmd} -A INPUT -i lo -j ACCEPT


# ok icmp codes
${iptables_cmd} -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type source-quench -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
${iptables_cmd} -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
# can lower this if you're paranoid but 1 ping a second is fine.  If someone is
# trying to ping flood they're going to attempt thousands a second. Can also
# comment out if you don't want to respond to pings but that's not recommended
# for servers
${iptables_cmd} -A INPUT -p icmp --icmp-type echo-request -j ACCEPT \
    -m limit --limit 60/minute


# limit how fast incoming ssh connections can happen
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 \
    -m state --state NEW \
    -m recent --set --name SSHLIMIT --rsource
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 \
    -m state --state NEW \
    -m recent --update --seconds 30 --hitcount 6 --name SSHLIMIT --rsource -j LIMIT
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT


# some ports to allow
# ssh is handled above but if you don't want limiter
#${iptables_cmd} -A INPUT -p tcp --dport 22 -j ACCEPT
${iptables_cmd} -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
# example of just 443
#${iptables_cmd} -A INPUT -p tcp --dport 80 -j ACCEPT
# example to allow full access from a single ip
#${iptables_cmd} -A INPUT -s 192.231.162.123/32 -j ACCEPT


# log unhandled packets
# Once you have things setup probably want to comment this out so you're not filling logs
${iptables_cmd} -A INPUT -m limit --limit 15/min -j LOG --log-prefix "[UNHANDLED INPUT PKT] "


# by default allow outgoing traffic, no incoming
${iptables_cmd} -P INPUT DROP
${iptables_cmd} -P FORWARD DROP
${iptables_cmd} -P OUTPUT ACCEPT

verbose "iptables setup has completed. Can view stats by running 'iptables -nvL' as root"

exit 0
