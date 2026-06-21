#!/bin/bash
# System osimpu.com - Fedora Edition

[ -z "$PS1" ] && return

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

ICON_INFO="💡"
BAR_WIDTH=15

HOSTNAME=$(hostname)

# OS INFO (Fedora safe)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME="$PRETTY_NAME"
else
    OS_NAME=$(uname -s)
fi

KERNEL=$(uname -r)

UPTIME=$(uptime -p 2>/dev/null | sed 's/up //')
ALL_IPS=$(hostname -I 2>/dev/null)

# LOAD AVERAGE
LOAD1=$(awk '{print $1}' /proc/loadavg)
LOAD5=$(awk '{print $2}' /proc/loadavg)
LOAD15=$(awk '{print $3}' /proc/loadavg)

# MEMORY (Fedora/RHEL compatible)
MEM_TOTAL_KB=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAILABLE_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

if [ -z "$MEM_AVAILABLE_KB" ]; then
    MEM_FREE_KB=$(awk '/MemFree/ {print $2}' /proc/meminfo)
    MEM_BUFF_KB=$(awk '/Buffers/ {print $2}' /proc/meminfo)
    MEM_CACHE_KB=$(awk '/^Cached/ {print $2}' /proc/meminfo)
    MEM_AVAILABLE_KB=$((MEM_FREE_KB + MEM_BUFF_KB + MEM_CACHE_KB))
fi

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))
MEM_PERC=$((MEM_USED_KB * 100 / MEM_TOTAL_KB))

MEM_TOTAL_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_TOTAL_KB/1024/1024}")
MEM_USED_GB=$(awk "BEGIN {printf \"%.1f\", $MEM_USED_KB/1024/1024}")

# DISK
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_PERC=$(df -h / | awk 'NR==2 {gsub("%","",$5); print $5}')

# BAR FUNCTION
draw_bar() {
    local perc=$1
    local color=$GREEN

    if [ "$perc" -ge 75 ]; then color=$YELLOW; fi
    if [ "$perc" -ge 90 ]; then color=$RED; fi

    local filled=$((perc * BAR_WIDTH / 100))
    local empty=$((BAR_WIDTH - filled))

    printf "["
    printf "${color}"
    for ((i=0; i<filled; i++)); do printf "|"; done
    printf "${NC}"
    for ((i=0; i<empty; i++)); do printf "."; done
    printf "] ${perc}%%"
}

clear

echo -e "${GREEN}"
echo " ${ICON_INFO} osimpu.com | FEDORA OS Dashboard"
echo -e "${NC}========================================================"

echo -e " ${WHITE}Hostname${NC}     : ${HOSTNAME}"
echo -e " ${WHITE}OS Version${NC}   : ${OS_NAME}"
echo -e " ${WHITE}Kernel${NC}       : ${KERNEL}"
echo -e " ${WHITE}IP Address${NC}   : ${ALL_IPS}"

echo -e "${NC}--------------------------------------------------------"

echo -e " ${WHITE}Uptime${NC}       : ${UPTIME}"

echo -e "${NC}========================================================"

echo -e " ${WHITE}CPU Load${NC}     : ${LOAD1}, ${LOAD5}, ${LOAD15}"

MEM_BAR=$(draw_bar $MEM_PERC)
echo -e " ${WHITE}Memory${NC}       : ${MEM_BAR} (${MEM_USED_GB}G / ${MEM_TOTAL_GB}G)"

DISK_BAR=$(draw_bar $DISK_PERC)
echo -e " ${WHITE}Disk Usage${NC}   : ${DISK_BAR} (${DISK_USED} / ${DISK_TOTAL})"

echo -e "${NC}========================================================"

# OPTIONAL APP INFO
if [ -f /etc/idch-app-info ]; then
    PRIMARY_IP=$(hostname -I | awk '{print $1}')
    echo -e " ${GREEN}🚀 APPLICATION INFORMATION${NC}"
    while IFS= read -r line; do
        echo -e "  ${line//<your-ip>/$PRIMARY_IP}"
    done < /etc/idch-app-info
    echo -e "${NC}========================================================"
fi

echo -e " ${ICON_INFO} ${WHITE}Web${NC} : ${GREEN}https://www.osimpu.com${NC}"
echo -e "${NC}========================================================"
echo ""