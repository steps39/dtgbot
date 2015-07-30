#!/bin/bash
# Change the rid values below to match the sensors on your devices page in Domoticz

SendMsgTo=$1
TmpFileName=$TempFileDir'WeatherFile.txt'
# array of temperature / humidity sensor indexes
declare -a arr=("79" "802" "747" "433")

## now loop through the above array
for index in "${arr[@]}"
do
   ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid='$index 2>/dev/null | jq -r .result[].Name`
   ResultString+=" "
   ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid='$index 2>/dev/null | jq -r .result[].Temp`
   ResultString+="°C "
   ResultString+=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid='$index 2>/dev/null | jq -r .result[].Humidity`
   ResultString+=$"%\n"
done
#echo $ResultString
#Outside prediction
ResultString+="%, prediction "
ForeCast=`curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=26' 2>/dev/null | jq -r .result[].Forecast`
echo $ForeCast
case "$ForeCast" in
2) ResultString+="⛅️" #Partly Cloudy
	;;
3) ResultString+="☁️" #Cloudy
	;;
*) echo `curl 'http://'$DomoticzIP':'$DomoticzPort'/json.htm?type=devices&rid=14' 2>/dev/null | jq -r .result[].ForecastStr`
	;;
esac

#Send
#echo -e $ResultString | ./utility/awkenc -l  |  sed 's/\\\\/\\/g' > $TmpFileName
#echo -e $ResultString | $BotBashScriptPath'utility/awkenc' -l  > $TmpFileName
echo -e $ResultString > $TmpFileName
ResultString=`cat $TmpFileName`
#curl 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage?chat_id='$SendMsgTo'&text='"$ResultString" 
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text='"$ResultString" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
