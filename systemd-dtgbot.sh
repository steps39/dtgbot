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
export EmailTo="joe.blogs@amailsystem.com"
# Force use of Lua 5.2 or else lua socks will fail with ltn12 error
/usr/bin/lua5.2 $BotHomePath"dtgbot.lua" >$BotLuaLog 2>>$BotLuaLog.errors
