#!/bin/bash
##### start script for dtgbot  ##################
## Define some system wide env variables
export DomoticzIP="127.0.0.1"
export DomoticzPort="8080"
export TempFileDir="/tmp/"
export BotHomePath="/home/pi/dtgbot/"
export BotBashScriptPath=$BotHomePath"bash/"
export BotLuaScriptPath=$BotHomePath"lua/"
export BotLuaLog=$TempFileDir"dtb.log"
export TelegramChatId='012343553'
export TelegramBotToken="000000000:keykeykeykeykeykeykeykey"
export TelegramBotOffset="TelegramBotOffset"
export EmailTo="joe.blogs@amailsystem.com"
/usr/bin/lua $BotHomePath"dtgbot.lua" >$BotLuaLog 2>>$BotLuaLog.errors
