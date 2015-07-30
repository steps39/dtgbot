#!/bin/sh
SendMsgTo=$1
#################################################################
SnapFile=$TempFileDir"snapshot.jpg"
#$TelegramScript msg $SendTo Er is zojuist aangebeld!
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=Er is zojuist aangebeld!' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
if ping -c 1 $IP > /dev/null ; then  # if IPCAM is online then:
(su - pi -c "wget "$DomoticzIP":"$DomoticzPort"/camsnapshot.jpg?idx=1 && sudo mv camsnapshot.jpg?idx=1 "$SnapFile)&
#$TelegramScript msg $SendTo Kijk wie er aangebeld heeft:
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=Kijk wie er aangebeld heeft:' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
#sleep 1
#$TelegramScript send_photo $SendTo $SnapFile
curl -s -X POST "https://api.telegram.org/bot"$TelegramBotToken"/sendPhoto" -F chat_id=$SendMsgTo -F photo="@$SnapFile"
/bin/rm $SnapFile
else
#$TelegramScript msg $SendTo IP-cam niet beschikbaar.
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=IP-cam niet beschikbaar.' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
fi

