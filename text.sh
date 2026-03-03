#!/bin/bash

# 1. Capture the event type sent by NUT (e.g., ONBATT, ONLINE)
EVENT=$1

# 2. Define your logic only for the "On Battery" event
if [ "$EVENT" = "ONBATT" ]; then
    
    # Notify all logged-in users via the terminal
    echo "WARNING: Power lost. Shutdown sequence initiated (45s delay)." | wall
    
    # 3. The Wait Period
    sleep 45
    
    # 4. The "Safety Check"
    # We ask NUT for the status again. If 'OL' (On Line) is found, we abort.
    CURRENT_STATUS=$(upsc tuncmatik ups.status)
    
    if [[ "$CURRENT_STATUS" == *"OL"* ]]; then
        echo "SUCCESS: Power restored within grace period. Shutdown aborted." | wall
        exit 0
    fi

    # 5. The Kill Chain
    echo "Grace period expired. Shutting down remote infrastructure..." | wall
    
    # Remote Shutdowns (Using SSH keys)
    #ssh -o ConnectTimeout=5 root@192.168.1.50 "poweroff"  # Example: Proxmox
    ssh -o ConnectTimeout=5 admin@192.168.10.103 "uptime" # Example: QNAP
    
    # 6. Final Shutdown of the Raspberry Pi itself
    echo "Remote servers signaled. Shutting down the NUT Master now." | wall
    #shutdown -h now
fi