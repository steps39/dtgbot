#!/bin/bash
# Script to restart the dtgbot service and clean any task still running. also used by monit incase of a hang
# Author: Jos van der Zande
# Date  : 25 Feb 2017

echo "$(date +%x) $(date +%X)  Stopping"  >> /var/tmp/dtgnewloop.txt
sudo service dtgbotnew stop
# allow any comman being process to finish
sleep 5
# kill all remaining processes
sudo pkill -f dtgbotnew/dtgbot.lua
echo "$(date +%x) $(date +%X)  Stopped"  >> /var/tmp/dtgnewloop.txt
