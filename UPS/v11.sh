#!/bin/bash

# =========================
# UPS Shutdown Orchestrator
# =========================
#
# Triggered by NUT upsmon via NOTIFYCMD.
#
# Purpose:
# - When power is lost, wait for a grace period
# - If power does not return, shut down remote hosts
# - Leave Raspberry Pi shutdown to NUT itself
#

# --- Configuration ---
UPS_NAME="tuncmatik@localhost"
LOG_FILE="/var/log/nut/ups-script.log"
SSH_KEY="/var/lib/nut/.ssh/id_ups_manager"
GRACE_PERIOD=45

REMOTE_HOSTS=(
    "root@192.168.10.101"
    "root@192.168.10.102"
    "admin@192.168.10.103"
)

# --- Helpers ---

## Logging
## When main code works, outputs logs to the $LOG_FILE
log() {
    mkdir -p /var/log/nut
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

## When run, it uses the log() and wall to output into the logged in users' terminal
notify() {
    log "$1"
    echo "$1" | wall
}

get_ups_status() {
    /usr/bin/upsc "$UPS_NAME" ups.status 2>/dev/null
}

## Function for shutting down hosts
shutdown_remote_hosts() {
    for host in "${REMOTE_HOSTS[@]}"; do
        log "Sending shutdown command to $host"

        /usr/bin/ssh \
            -i "$SSH_KEY" \
            -o BatchMode=yes \
            -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=yes \
            "$host" "/sbin/poweroff || /usr/sbin/poweroff || poweroff" \
            >> "$LOG_FILE" 2>&1 &
    done

    wait
    log "Remote shutdown commands completed"
}

# --- Main ---
log "Script triggered. NOTIFYTYPE='${NOTIFYTYPE:-}' UPSNAME='${UPSNAME:-}' ARG1='${1:-}'"

case "${NOTIFYTYPE:-}" in
    ONBATT)
        notify "Power lost on ${UPSNAME:-unknown UPS}. Waiting ${GRACE_PERIOD}s before shutdown sequence."

        sleep "$GRACE_PERIOD"

        CURRENT_STATUS="$(get_ups_status)"
        log "UPS status after grace period: ${CURRENT_STATUS:-unknown}"

        if [[ "$CURRENT_STATUS" == *"OL"* ]]; then
            notify "Power restored on ${UPSNAME:-unknown UPS}. Shutdown aborted."
            exit 0
        fi

        notify "Grace period expired. Power is still out. Signalling remote infrastructure."
        shutdown_remote_hosts
        notify "Remote shutdown signals sent. Raspberry Pi remains under NUT shutdown control."
        ;;

    ONLINE)
        log "Utility power restored on ${UPSNAME:-unknown UPS}"
        ;;

    *)
        log "Unhandled event received. NOTIFYTYPE='${NOTIFYTYPE:-}' ARG1='${1:-}'"
        ;;
esac

exit 0