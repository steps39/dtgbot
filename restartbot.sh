#!/bin/bash
# Script to restart the dtgbot service and clean any task still running. also used by monit incase of a hang
# Author: Jos van der Zande
# Date  : 25 Feb 2017

chk=`sudo ps x | grep "restartbot.sh" | grep -cv grep`
if  [ $chk -gt 2 ] ; then
	echo "`date +"%x %X"` restartbot.sh started but is already running so stopping this one. ($chk)" >> /var/tmp/dtgrestart.log
	exit
fi
# update dtgloop file to avoid the dtgloop check to kick in too early (Monit)
echo "$(date +%x) $(date +%X) restartbot.sh started  ($chk)" >> /var/tmp/dtgloop.txt
echo "$(date +%x) $(date +%X) Restarting" >> /var/tmp/dtgrestart.log
# Stop the Service
sudo service dtgbot stop >> /var/tmp/dtgrestart.log
# allow any command being process to finish
sleep 2
# kill all remaining processes
sudo pkill -SIGKILL -e -f dtgbot/dtgbot.lua >> /var/tmp/dtgrestart.log
sleep 1
# Start service again
sudo service dtgbot start >> /var/tmp/dtgrestart.log
echo "$(date +%x) $(date +%X) Restart done" >> /var/tmp/dtgrestart.log
