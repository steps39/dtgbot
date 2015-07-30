#!/bin/sh
SendMsgTo=$1
IP=$2                                  # IP address Camera
##########################################################
SnapFile=$TempFileDir"snapshot.jpg"
$TelegramScript msg $SendTo  Er is nieuwe post bezorgd!
if ping -c 1 $IP > /dev/null ; then # if IPCAM is online then:
#$TelegramScript msg SendTo Kijk wie er post heeft bezorgd:
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text="Kijk wie er post heeft bezorgd:"' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
(su - pi -c "wget http://"$DomoticzIP":"$DomoticzPort"/camsnapshot.jpg?idx=1 && sudo mv camsnapshot.jpg?idx=1 "$SnapFile)&
#sleep 1
#$TelegramScript send_photo $SendTo $SnapFile
curl -s -X POST "https://api.telegram.org/bot"$TelegramBotToken"/sendPhoto" -F chat_id=$SendMsgTo -F photo="@$SnapFile"
/bin/rm $SnapFile
else
#$TelegramScript msg $SendTo IP-cam niet beschikbaar.
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=IP-cam niet beschikbaar.' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
fi
