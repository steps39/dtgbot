#!/bin/bash
#
# Ewald 20190728
#
# this script allows to read all the user variables set in Domoticz (In Domoticz => Setup => More Options => User Variables)
# and to change them, syntax: varia VariableName Value
#
# if you would like to display with index in front, use the below line
# ( but display without the index allows for easier copy and paste to set a variable )
# mapfile -t varia  < <(curl --silent 'http://domoticz.local:8080/json.htm?type=command&param=getuservariables' | jq -r -c '.result[]| {Name,idx,Value}' | perl -ne '/Name\":\"(\S+?)\".*idx\":\"(\d+).*Value\":\"(\S+?)\"/ && print "\[$2\] $1: $3\n"')

SendMsgTo=$1

if [ -z "$2" ]; then
	mapfile -t varia  < <(curl --silent 'http://domoticz.local:8080/json.htm?type=command&param=getuservariables' | jq -r -c '.result[]| {Name, Value}' | perl -ne '/Name\":\"(\S+?)\".*Value\":\"(\S+?)\"/ && print "$1 $2\n"')

	for v in "${varia[@]}"
		do
		    if [[ $v != Telegram* ]]; then		# leave out the dtgbot variables that start with Telegram
		# another option to display only the variables ending in Alert is:  [[ $v == *Alert ]]
   			curl --silent --data 'chat_id='$SendMsgTo --data-urlencode 'text='"$v" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
		    fi
		done
	else
		if [[ "$#" -ne 3 ]]; then
                        curl --silent --data 'chat_id='$SendMsgTo --data-urlencode 'text='"Sorry, i need TWO arguments, VariableName and Value" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
                        exit 0
		fi
		VAR=$2; VAL=$3
		if [[ $VAR == Telegram* ]]; then
			curl --silent --data 'chat_id='$SendMsgTo --data-urlencode 'text='"Sorry, no changing Telegram variables" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
			exit 0
		fi
		CHECK=$(curl --silent "http://"$DomoticzIP":"$DomoticzPort"/json.htm?type=command&param=updateuservariable&vname="$2"&vtype=0&vvalue="$3 | jq -r '.status')
		if [[ $CHECK == "OK" ]]; then
			curl --silent --data 'chat_id='$SendMsgTo --data-urlencode 'text='"$VAR = $VAL" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
		else
			curl --silent --data 'chat_id='$SendMsgTo --data-urlencode 'text='"Oops, that didn't work" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
		fi
	fi
