#!/bin/bash
# Change the rid values below to match the sensors on your devices page in Domoticz

# Settings
SendMsgTo=$1
TmpFileName=$TempFileDir'SystemStatus.txt'

#Send sensor values with telegram
#$TelegramScript msg $SendMsgTo "Please wait, gathering data..."
#curl 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage?chat_id='$SendMsgTo'&text=Please%20wait%20gathering%20data'
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=Please wait, gathering data...' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'

##############################################################################
ResultString="-CPU temperature: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=1' 2>/dev/null | jq -r .result[]."Temp"`
ResultString+="°C\n"

ResultString+="-CPU Usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=386' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

ResultString+="-Memory Usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=385' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

ResultString+="-SD usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=388' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

Updates=`sudo aptitude search '~U' | wc -l`
if [[ $Updates -ge 1 ]] ; then
    ResultString+="-Apt-get updates available: "
   ResultString+=$Updates
   ResultString+="\n"
fi
InstalledVersion=`curl "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=command&param=checkforupdate&forced=true" 2>/dev/null | jq -r ."ActVersion"`
UpdateVersion=`curl "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=command&param=checkforupdate&forced=true" 2>/dev/null | jq -r ."Revision"`
if [[ $InstalledVersion -lt $UpdateVersion ]] ; then
   ResultString+="-Domoticz update available! (version "
   ResultString+=$UpdateVersion
   ResultString+=") "
   ResultString+="\n"
fi
##############################################################################
#InstalledFW=`curl "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=hardware&filter=idx=1" 2>/dev/null | jq -r .result[].Mode2 | grep -v "^0"`
InstalledFW=` curl "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=hardware&filter=idx=1" 2>/dev/null | jq -r '.result[] | select(.Name=="RFXCOM")| .Mode2'`
echo $InstalledFW
if [ "$InstalledFW" -ge 0 -a "$InstalledFW" -le 99 ]; then
   grepvar="8" #Type1 firmware
   LatestFW=`curl -s "http://blog.rfxcom.com/?feed=rss2" | grep -m 1 "firmware version" | sed "s/.*[^0-9]\([0-9][0-9]\)[^0-9].*/\1/"`
fi
if [ "$InstalledFW" -ge 100 -a "$InstalledFW" -le 199 ]; then
   grepvar="1" #Type2 firmware
   LatestFW=`curl -s "http://blog.rfxcom.com/?feed=rss2" | grep -m 1 "firmware version" | sed "s/.*[^0-9]\([0-9][0-9][0-9]\)[^0-9].*[^0-9][0-9][0-9][0-9][^0-9].*/\1/"`
fi
if [ "$InstalledFW" -ge 200 -a "$InstalledFW" -le 299 ]; then
   grepvar="2" #EXT firmware
   LatestFW=`curl -s "http://blog.rfxcom.com/?feed=rss2" | grep -m 1 "firmware version" | sed "s/.*[^0-9][0-9][0-9][0-9][^0-9].*[^0-9]\([0-9][0-9][0-9]\)[^0-9].*/\1/"`
fi

if [[ $InstalledFW -lt $LatestFW ]] ; then
    ResultString+="-RFXtrx update available! (version "
   ResultString+=$LatestFW
   ResultString+=") "
   ResultString+="\n"
fi
##############################################################################
echo -e $ResultString > $TmpFileName
ResultString=`cat $TmpFileName`
#$TelegramScript send_text $SendMsgTo $TmpFileName
#curl 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage?chat_id='$SendMsgTo'&text='"$ResultString"
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text='"$ResultString" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
