#!/bin/bash
# 1. Debug Logs
echo "SCRIPT TRIGGERED AT $(date) WITH EVENT $1" >> /tmp/nut_debug.log

# 2. Normalize the Message
MESSAGE=$(echo "$1" | tr '[:upper:]' '[:lower:]')
echo "message $MESSAGE" >> /tmp/nut_debug.log

# 3. Extract the Event Type
if [[ "$MESSAGE" == *"battery"* ]]; then
    EVENT="ONBATT"
elif [[ "$MESSAGE" == *"line"* ]]; then
    EVENT="ONLINE"
else
    echo "$(date): Unknown event: $1" >> /var/log/nut/ups-script.log
    exit 0
fi

# 4. Define Logic for "On Battery"
if [ "$EVENT" = "ONBATT" ]; then
    echo "WARNING: Power lost. Shutdown sequence initiated (45s delay)." | wall
    echo "$(date): Starting 45s wait period..." >> /var/log/nut/ups-script.log
    
    # The Wait Period
    sleep 45
    
    # 5. The "Safety Check" (Checking upsc status)
    # upsc returns 'OL' (Online) or 'OB' (On Battery)
    CURRENT_STATUS=$(/usr/bin/upsc tuncmatik ups.status)
    echo "Current status after sleep: $CURRENT_STATUS" >> /tmp/nut_debug.log

    if [[ "$CURRENT_STATUS" == *"OL"* ]]; then
        echo "SUCCESS: Power restored within grace period. Shutdown aborted." | wall
        echo "$(date): Power restored. Aborting shutdown." >> /var/log/nut/ups-script.log
        exit 0
    fi

    # 6. The Kill Chain
    echo "Grace period expired. Shutting down remote infrastructure..." | wall
    
    # Use absolute paths and capture errors
    /usr/bin/ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=5 root@192.168.10.101 "/usr/sbin/poweroff" >> /var/log/nut/ups-script.log 2>&1 &
    /usr/bin/ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=5 root@192.168.10.102 "/usr/sbin/poweroff" >> /var/log/nut/ups-script.log 2>&1 &
    /usr/bin/ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=20 admin@192.168.10.103 "/sbin/poweroff" >> /var/log/nut/ups-script.log 2>&1 &
    
    wait

    # 7. Final Notification
    echo "Remote servers signaled." | wall
    echo "$(date): All remote shutdown signals processed." >> /var/log/nut/ups-script.log
fi
