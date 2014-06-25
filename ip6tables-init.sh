#!/bin/bash
# Set ip6tables rules
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


ip6tables_cmd=$(which ip6tables) || eval "echo 'Please install ip6tables'; exit 1"


verbose "Setting ip6tables rules"
verbose "Clearing current rules"
${ip6tables_cmd} -F
${ip6tables_cmd} -Z
${ip6tables_cmd} -X

# again, choose either conntrack or state, don't need both
#${ip6tables_cmd} -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${ip6tables_cmd} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
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

verbose "Setting defaults"
${ip6tables_cmd} -P INPUT DROP
${ip6tables_cmd} -P FORWARD DROP
${ip6tables_cmd} -P OUTPUT ACCEPT

verbose "ip6tables setup has completed. Can view stats by running 'ip6tables -nvL' as root"

exit 0
