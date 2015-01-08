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
# up.
#
# Licensed under a dual permissive license of Unlicense and MIT. See LICENSE.txt
#

# -- Exit on errors (-e) and Exit if try to use an unset variable (-u) --
set -e
set -u

# -- Only root can set iptables rules --
if [[ $EUID -ne 0 ]]; then
    printf "%s" "Must be run as root" >&2
    exit 1
fi

# -- Setup our env variables (need this or will exit if not set) --
readonly VERBOSE="${VERBOSE:-false}"
readonly DEBUG="${DEBUG:-false}"

if [[ "${DEBUG}" == "true" ]]; then
    set -x
fi


# == Helper functions ==

# -- print line to screen with timestamp --
# Usage: log "What to log"
log () {
    # Uncomment this line to log messages to syslog
    #logger -s -t "${script_name}" -- "$*"
    printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
}

# -- only print line if verbose is true --
# Usage: verbose "What to log if VERBOSE is true"
verbose () {
    if [[ "${VERBOSE}" == "true" ]]; then
        log "$*"
    fi
}


# -- setup iptables_cmd variable --
# Use this to change command that is run for entire script
iptables_cmd=$(which iptables) || eval "echo 'Could not find iptables'; exit 1"


verbose "Setting iptables rules"
verbose "Clearing current rules"
${iptables_cmd} -F
${iptables_cmd} -Z
${iptables_cmd} -X


# -- create LIMIT chain for throttled connections --
verbose "Creating LIMIT chain"
${iptables_cmd} -N LIMIT
${iptables_cmd} -A LIMIT -m limit --limit 3/min -j LOG --log-prefix "[LIMIT BLOCK] "
${iptables_cmd} -A LIMIT -j REJECT --reject-with icmp-port-unreachable


# -- start setting specific iptables rules --
verbose "Creating main iptables rules"

# -- allow established connections --
# ## IMPORTANT: For OpenVZ servers ##
#   - need to modprobe xt_tcpudp, ip_conntrack, and xt_state. To do this add
#     those three names to /etc/modules and restart.
#   - uncomment the state line and comment out the conntrack line if it doesn't
#     work.
#${iptables_cmd} -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
${iptables_cmd} -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT


# -- allow all traffic on local interface --
${iptables_cmd} -A INPUT -i lo -j ACCEPT


# -- ICMP types that should always be allowed --
# Messages about a host not being reachable
${iptables_cmd} -A INPUT -p icmp --icmp-type destination-unreachable -j ACCEPT
# Messages to slow down how fast your sending data
${iptables_cmd} -A INPUT -p icmp --icmp-type source-quench -j ACCEPT
# Time-to-live is exceeded
${iptables_cmd} -A INPUT -p icmp --icmp-type time-exceeded -j ACCEPT
# Something about the packet that the server sent is wrong
${iptables_cmd} -A INPUT -p icmp --icmp-type parameter-problem -j ACCEPT
# The ping command defaults to one ping a second. Use 10 per second or else if
# just two people are pinging a server it won't respond or be really
# intermittent.  Ping flood attacks are thousands a second so this is still
# a lot better than nothing.  Deleting this line will block pings but that isn't
# recommended on servers.
${iptables_cmd} -A INPUT -p icmp --icmp-type echo-request -j ACCEPT \
    -m limit --limit 10/second


# -- limit how fast incoming ssh connections can happen --
# This sets it to 8 times (value for hitcount) every 60 seconds (value for
# seconds). Feel free to adjust those.  This is per source ip meaning if some
# botnet is flooding ssh server you should still be able to ssh from your
# location.
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 \
    -m state --state NEW \
    -m recent --set --name SSHLIMIT --rsource
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 \
    -m state --state NEW \
    -m recent --update --seconds 60 --hitcount 8 --name SSHLIMIT --rsource -j LIMIT
${iptables_cmd} -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT


# -- allow aditional ports --
# ssh is handled above but if you don't want limiter then comment or remove
# above and uncomment this line
#${iptables_cmd} -A INPUT -p tcp --dport 22 -j ACCEPT
${iptables_cmd} -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
# example of just 80
#${iptables_cmd} -A INPUT -p tcp --dport 80 -j ACCEPT
# example to allow full access from a single ip
#${iptables_cmd} -A INPUT -s 192.231.162.123/32 -j ACCEPT


# -- log unhandled packets (run `dmesg` to see log entries) --
# Will be logged to kernel, viewable by running `dmesg`. Once you have things
# setup probably want to comment this out so you're not filling logs
${iptables_cmd} -A INPUT -m limit --limit 15/min -j LOG --log-prefix "[UNHANDLED INPUT PKT] "


# -- set preferences for any traffic that does match above rules --
# allow unhandled outgoing traffic but silently drop unhandled incoming traffic
${iptables_cmd} -P INPUT DROP
${iptables_cmd} -P FORWARD DROP
${iptables_cmd} -P OUTPUT ACCEPT

verbose "iptables setup has completed. Can view stats by running 'iptables -nvL' as root"

exit 0
