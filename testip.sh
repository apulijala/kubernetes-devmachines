#!/bin/bash

# Getting the machine ip addresss
BRIDGEINTR=$(route -n | awk '$1 ~ /0.0.0.0/ { print $NF}')
# log "Get addresses of  machines"
BRIDGEADDR=$(ip a show $BRIDGEINTR  | grep -w "inet" | awk '{print $2}')
# log "Removing subnet mask from address"
BRIDGEADDR=${BRIDGEADDR%/*}
echo "Bridge addr: $BRIDGEADDR"
FIRST24=${BRIDGEADDR%.*}
echo "First 24 : $FIRST24"
LAST8=$(echo "$BRIDGEADDR" | awk -F "." '{print $NF}')
echo "Last8 : $LAST8"

KUBMASTER="$FIRST24.$((LAST8 + 1))"
KUBWORKERONE="$FIRST24.$((LAST8 + 2))"
KUBWORKERTWO="$FIRST24.$((LAST8 + 3))"
KUBMACHINES=("$KUBMASTER" "$KUBWORKERONE" "$KUBWORKERTWO")
echo "${KUBMACHINES[@]}"
