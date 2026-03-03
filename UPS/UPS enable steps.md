UPS enable steps

You’re right—the internal "NUT way" of handling timers involves a daemon called upssched, which uses a complex system of "pipes" and "flags" that feels very 1990s.

Since you prefer a script-based approach, you can use the NOTIFYCMD method. This is much more modern, easier to debug, and works perfectly with your existing Python or Bash skills.

Option 1: The Script-Based Way (Recommended)
In this setup, upsmon acts as the trigger, and your script handles the logic (the 45-second wait and the remote shutdowns).

1. Create your "Master Shutdown" Script
Create a file (e.g., /usr/local/bin/ups-manager.sh) and make it executable.

Bash
#!/bin/bash
# This script is triggered by NUT

EVENT=$1

if [ "$EVENT" = "ONBATT" ]; then
    echo "Power lost! Waiting 45 seconds before killing servers..." | wall
    sleep 45
    
    # Re-check status: If power came back during the 45s, abort!
    STATUS=$(upsc tuncmatik ups.status)
    if [[ "$STATUS" == *"OL"* ]]; then
        echo "Power restored. Shutdown aborted." | wall
        exit 0
    fi

    echo "45 seconds passed. Shutting down remote servers..." | wall
    
    # Add your remote shutdown commands here
    # Example: ssh root@proxmox "shutdown -h now"
    # Example: ssh admin@qnap "/sbin/poweroff"
    
    # Finally, shut down this Pi
    shutdown -h now
fi


2. Link NUT to your Script
Edit /etc/nut/upsmon.conf:

Tell NUT where the script is:
NOTIFYCMD /usr/local/bin/ups-manager.sh

Tell NUT when to run it:
Find the NOTIFYFLAG section and add:
NOTIFYFLAG ONBATT EXEC

The EXEC flag is what tells NUT to actually run your script when the "On Battery" event occurs.

3. create the log file
4. make sure the .sh has correct permissions

5. ssh keyscans so it won't ask known host

ssh-keyscan -H 192.168.10.101 >> /var/lib/nut/.ssh/known_hosts
ssh-keyscan -H 192.168.10.102 >> /var/lib/nut/.ssh/known_hosts
ssh-keyscan -H 192.168.10.103 >> /var/lib/nut/.ssh/known_hosts
chown nut:nut /var/lib/nut/.ssh/known_hosts
chmod 644 /var/lib/nut/.ssh/known_hosts