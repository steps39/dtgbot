#!/bin/bash
# Script to restart the dtgbot service and clean any task still running. also used by monit incase of a hang
# Author: Jos van der Zande
# Date  : 25 Feb 2017

chk=`sudo ps x | grep "restartbot.sh" | grep -cv grep`
if  [ $chk -gt 2 ] ; then
	echo "`date +"%x %X"` restartbot.sh started but is already running so stopping this one. ($chk)" >> /var/tmp/dtgloop.txt
	exit
fi
echo "$(date +%x) $(date +%X) restartbot.sh started  ($chk)" >> /var/tmp/dtgloop.txt
# update dtgloop file to avoid the dtgloop check to kick in too early
echo "$(date +%x) $(date +%X)  Restarting" >> /var/tmp/dtgloop.txt
# Stop the Service
sudo service dtgbot stop >> /var/tmp/dtgloop.txt
# allow any command being process to finish
sleep 10
# kill all remaining processes
sudo pkill -f dtgbot/dtgbot.lua >> /var/tmp/dtgloop.txt
sleep 2
# Start service again
sudo service dtgbot start >> /var/tmp/dtgloop.txt
echo "$(date +%x) $(date +%X)  Restart done" >> /var/tmp/dtgloop.txt
