#!/bin/bash

# --- Configuration ---
UPS_NAME="tuncmatik"
LOG_FILE="/var/log/nut/ups-script.log"
SSH_KEY="/var/lib/nut/.ssh/id_ups_manager"
GRACE_PERIOD=45
REMOTE_HOSTS=(
    "root@192.168.10.101"
    "root@192.168.10.102"
    "admin@192.168.10.103"
)

# --- Helpers ---
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

notify() {
    log "$1"
    echo "$1" | wall
}

# --- Main Logic ---
# NUT passes the event type via $NOTIFYTYPE (e.g., ONBATT, ONLINE)
case "$NOTIFYTYPE" in
    ONBATT)
        notify "WARNING: Power lost on $UPSNAME. Shutdown sequence starts in ${GRACE_PERIOD}s."
        
        sleep "$GRACE_PERIOD"

        # Check if power returned during the sleep
        CURRENT_STATUS=$(/usr/bin/upsc "$UPS_NAME" ups.status 2>/dev/null)
        if [[ "$CURRENT_STATUS" == *"OL"* ]]; then
            notify "SUCCESS: Power restored to $UPSNAME. Shutdown aborted."
            exit 0
        fi

        notify "Grace period expired. Signalling remote infrastructure..."
        
        for host in "${REMOTE_HOSTS[@]}"; do
            /usr/bin/ssh -i "$SSH_KEY" -o ConnectTimeout=5 "$host" "poweroff" >> "$LOG_FILE" 2>&1 &
        done
        
        wait
        notify "All remote shutdown signals dispatched."
        ;;

    ONLINE)
        log "System is back on utility power ($UPSNAME)."
        ;;

    *)
        log "Received unhandled NUT event: $NOTIFYTYPE"
        ;;
esac
