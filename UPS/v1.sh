z#!/bin/bash

# 1. Capture the event type sent by NUT (e.g., ONBATT (OB), ONLINE)
EVENT=$1

# 2. Define your logic only for the "On Battery" event
if [ "$EVENT" = *"on battery"* ]; then
    

    echo "WARNING: Power lost. Shutdown sequence initiated (45s delay)." | wall
    sleep 45
    

    # We ask NUT for the status again. If 'OL' (On Line) is found, we abort.
    CURRENT_STATUS=$(/usr/bin/upsc tuncmatik ups.status)

    if [[ "$CURRENT_STATUS" == *"on line power"* ]]; then
        echo "SUCCESS: Power restored within grace period. Shutdown aborted." | wall
        exit 0
    fi



    # 5. The Kill Chain
    echo "Grace period expired. Shutting down remote infrastructure..." | wall
    
    ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=5 root@192.168.10.101 "/usr/sbin/poweroff" & # opti1
    ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=5 root@192.168.10.102 "/usr/sbin/poweroff" & # opti2
    ssh -i /var/lib/nut/.ssh/id_ups_manager -o ConnectTimeout=20 admin@192.168.10.103 "/sbin/poweroff" & # NAS
    wait


    # 6. Notify all endpoints are shutdown
    echo "Remote servers signaled." | wall
    echo "$(date): All remote shutdown signals processed." >> /var/log/nut/ups-script.log

    
    ### Enable if you want to shutdown the NUT master, rasp in my case

#    if [[ "$CURRENT_STATUS" == *"LB"* ]]; then
#        echo "CRITICAL: Battery low. Shutting down the Pi to prevent corruption." | wall
#        echo "$(date): CRITICAL BATTERY - Shutting down Pi." >> /var/log/nut/ups-script.log
#        shutdown -h now
#    fi 
    #shutdown -h now
fi
