#!/bin/bash
# Change the rid values below to match the sensors on your devices page in Domoticz

# Settings
SendMsgTo=$1

#Send start of gathering msg to telegram
Result=`curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=Please wait, gathering data...' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage' 2>/dev/null`

##############################################################################
ResultString="-CPU temperature: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=15' 2>/dev/null | jq -r .result[]."Temp"`
ResultString+="°C\n"

ResultString+="-CPU Usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=16' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

ResultString+="-Memory Usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=12' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

ResultString+="-SD usage: "
ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=13' 2>/dev/null | jq -r .result[]."Data"`
ResultString+="\n"

Updates=`sudo aptitude search '~U' | wc -l`
if [[ $Updates -ge 1 ]] ; then
    ResultString+="-Apt-get updates available: "
   ResultString+=$Updates
   ResultString+="\n"
fi
CheckforUpdate=`curl -s -i -H "Accept: application/json" "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=command&param=checkforupdate&forced=true"`
InstalledVersion=`curl -s -i -H "Accept: application/json" "http://$DomoticzIP:$DomoticzPort/json.htm?type=command&param=getversion"`
#echo "CheckforUpdate:$CheckforUpdate\n"
HaveUpdate=`echo -ne "$CheckforUpdate"|grep "\"HaveUpdate\" :" `
Version=`echo -ne "$InstalledVersion"|grep "\"version\" :" `
Revision=`echo -ne "$InstalledVersion"|grep "\"Revision\" :" `
HaveUpdate=`echo $HaveUpdate | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
Version=`echo $Version | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
Revision=`echo $Revision | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`

#echo "HaveUpdate:$HaveUpdate\n"
#echo "Version:$Version\n"
#echo "Revision:$Revision\n"

if [[ "$HaveUpdate" -eq "true" ]] ; then
   ResultString+="-Domoticz update available! current version $Version build $Revision\n"
fi
##############################################################################
InstalledFW=`curl "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=hardware&filter=idx=1" 2>/dev/null | jq -r '.result[] | select(.Name=="RFXCOM")| .version'`
InstalledFW=`echo $InstalledFW | sed "s/.*\/\([0-9]*\)[^0-9]*/\1/"`
LatestFW=`curl -s "http://blog.rfxcom.com/?feed=rss2" | grep -m 1 "firmware version" | sed "s/.*version \(.*\)<\/t.*/\1/"`

if [[ $InstalledFW -lt $LatestFW ]] ; then
   ResultString+="-RFXtrx update available: $LatestFW"
   ResultString+=" installed: $InstalledFW"
   ResultString+="\n"
fi
##############################################################################
echo -ne "$ResultString"