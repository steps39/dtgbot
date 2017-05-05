#!/bin/bash
# Script to restart the dtgbot service and clean any task still running. also used by monit incase of a hang
# Author: Jos van der Zande
# Date  : 25 Feb 2017

echo "$(date +%x) $(date +%X)  Stopping"  >> /var/tmp/dtgloop.txt
sudo service dtgbot stop
# allow any comman being process to finish
sleep 5
# kill all remaining processes
sudo pkill -f dtgbot/dtgbot.lua
echo "$(date +%x) $(date +%X)  Stopped"  >> /var/tmp/dtgloop.txt
