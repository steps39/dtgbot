#!/bin/sh
SendMsgTo=$1
ActVersionFile=$TempFileDir"Actversion.txt"
RevisionFile=$TempFileDir"Revision.txt"
UpdateFile=$TempFileDir"Update.txt"
if [ -f $RevisionFile ];
then
   LatelyChecked=`cat $RevisionFile | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
   echo "File $FILE exists"
else
   LatelyChecked=1000
   echo "File $FILE does not exists"
fi
ActVersion=`curl -s -i -H "Accept: application/json" "$DomoticzIP:$DomoticzPort/json.htm?type=command&param=checkforupdate&forced=true" |grep "ActVersion" `
Revision=`curl -s -i -H "Accept: application/json" "http://127.0.0.1:8080/json.htm?type=command&param=checkforupdate&forced=true" |grep "Revision" `
echo $LatelyChecked
echo $ActVersion > $ActVersionFile
echo $Revision > $RevisionFile
InstalledVersion=`cat $ActVersionFile | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
UpdateVersion=`cat $RevisionFile | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
if [ $InstalledVersion -le $UpdateVersion ] && [ $UpdateVersion -eq $LatelyChecked ] ; then
echo "No Update Available"
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=No Update Available' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
exit  # Exit script
fi
if [ $InstalledVersion -le $UpdateVersion ] && [ $UpdateVersion -ge $LatelyChecked ] ; then
echo 'Domoticz Update Available! \n'$InstalledVersion'= Current Version\n'$UpdateVersion'= Latest Version\n sourceforge.net/p/domoticz/code/commit_browser' > $UpdateFile
stuff=`cat $UpdateFile`
echo $stuff
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text='"$stuff" 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
else
curl --data 'chat_id='$SendMsgTo --data-urlencode 'text=No Update Available' 'https://api.telegram.org/bot'$TelegramBotToken'/sendMessage'
fi
