#!/bin/sh
SendMsgTo=$1
ActVersionFile=$TempFileDir"Actversion.txt"
RevisionFile=$TempFileDir"Revision.txt"
UpdateFile=$TempFileDir"Update.txt"
if [ -f $RevisionFile ];
then
   LatelyChecked=`cat $RevisionFile | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
   #echo "File $FILE exists"
else
   LatelyChecked=1000
   #echo "File $FILE does not exists"
fi
CheckforUpdate=`curl -s -i -H "Accept: application/json" "$DomoticzIP:$DomoticzPort/json.htm?type=command&param=getversion"`
#echo "CheckforUpdate:$CheckforUpdate\n"
HaveUpdate=`echo -ne "$CheckforUpdate"|grep "\"HaveUpdate\" :" `
Version=`echo -ne "$CheckforUpdate"|grep "\"version\" :" `
Revision=`echo -ne "$CheckforUpdate"|grep "\"Revision\" :" `
#echo "-------------------------------\n HaveUpdate:$HaveUpdate\n"
#echo "-------------------------------\n Version:$Version\n"
#echo "-------------------------------\n Revision: $Revision\n"
HaveUpdate=`echo $HaveUpdate | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
Version=`echo $Version | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
Revision=`echo $Revision | awk -F: '{print $2, $3}' | sed 's/\"//g' | sed 's/,//'`
echo -ne "Installed Version: $Version\n"
echo -ne "Revision: $Revision\n"
echo -ne "HaveUpdate: $HaveUpdate\n"
exit
