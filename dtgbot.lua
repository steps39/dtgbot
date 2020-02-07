-- ~/tg/scripts/generic/domoticz2telegram.lua
-- Version 0.7 20200206
-- Automation bot framework for telegram to control Domoticz
-- dtgbot.lua does not require any customisation (see below)
-- and does not require any telegram client to be installed
-- all communication is via authenticated https
-- Extra functions can be added by replicating list.lua,
-- replacing list with the name of your new command see list.lua
-- Based on test.lua from telegram-cli from
-- Adapted to abstract functions into external files using
-- the framework of the XMPP bot, so allowing functions to
-- shared between the two bots.
-- -------------------------------------------------------

-- print to log with time and date
function print_to_log(loglevel, logmessage, ...)
  -- when only one parameter is provided => set the loglevel to 0 and assume the parameter is the messagetext
  if tonumber(loglevel) == nil or logmessage == nil then
    logmessage = loglevel
    loglevel=0
  end
  if loglevel <= dtgbotLogLevel then
    logcount = #{...}
    if logcount > 0 then
      for i, v in pairs({...}) do
        logmessage = logmessage ..' ('..tostring(i)..') '..tostring(v)
      end
      logmessage=tostring(logmessage):gsub(" (.+) nil","")
    end
    print(os.date("%Y-%m-%d %H:%M:%S")..' - '..tostring(logmessage))
  end
end
-- print Telegram exchange to a separate debug log
function print_to_debuglog(loglevel, logmessage, ...)
  -- when only one parameter is provided => set the loglevel to 0 and assume the parameter is the messagetext
  if tonumber(loglevel) == nil or logmessage == nil then
    logmessage = loglevel
    loglevel=0
  end
  if loglevel <= dtgbotLogLevel then
    file = io.open(os.getenv("BotLuaLog").."_Telegram_debug.log", "a")
    logcount = #{...}
    if logcount > 0 then
      for i, v in pairs({...}) do
        logmessage = logmessage ..' ('..tostring(i)..') '..tostring(v)
      end
      logmessage=tostring(logmessage):gsub(" (.+) nil","")
    end
    file:write(os.date("%M:%S")..' '..tostring(logmessage).."\r\n")
    file:close()
  end
end
---------------------------------------------------------
-- new geturl to set protocol
function geturl(url)
  local resp = {}
  local r, c, h, s = https.request{
     url = url,
     sink = ltn12.sink.table(resp),
     protocol = "tlsv1_2"
  }
  returncode=c
  response = resp[1]
  return response, returncode
end

function domoticzdata(envvar)
  -- loads get environment variable and prints in log
  localvar = os.getenv(envvar)
  if localvar ~= nil then
    print_to_log(0,envvar..": "..localvar)
  else
    print_to_log(0,envvar.." not found check /etc/profile.d/DomoticzData.sh")
  end
  return localvar
end

function checkpath(envpath)
  if string.sub(envpath,-1,-1) ~= "/" then
    envpath = envpath .. "/"
  end
  return envpath
end

-- set default loglevel which will be retrieve later from the domoticz user variable TelegramBotLoglevel
dtgbotLogLevel=0

-- loglevel 0 - Always shown
-- loglevel 1 - only shown when TelegramBotLoglevel >= 1

-- All these values are set in /etc/profile.d/DomoticzData.sh
DomoticzIP = domoticzdata("DomoticzIP")
DomoticzPort = domoticzdata("DomoticzPort")
BotHomePath = domoticzdata("BotHomePath")
TempFileDir = domoticzdata("TempFileDir")
BotLuaScriptPath = domoticzdata("BotLuaScriptPath")
BotBashScriptPath = domoticzdata("BotBashScriptPath")
TelegramBotToken = domoticzdata("TelegramBotToken")
TBOName = domoticzdata("TelegramBotOffset")
-- -------------------------------------------------------

-- Constants derived from environment variables
server_url = "http://"..DomoticzIP..":"..DomoticzPort
telegram_url = "https://api.telegram.org/bot"..TelegramBotToken.."/"
UserScriptPath = BotBashScriptPath

-- Check paths end in / and add if not present
BotHomePath=checkpath(BotHomePath)
BotLuaScriptPath=checkpath(BotLuaScriptPath)
BotBashScriptPath=checkpath(BotBashScriptPath)

support = assert(loadfile(BotHomePath.."dtg_domoticz.lua"))();
-- Should end up a library - require("dtg_domoticz.lua")

print_to_log ("-----------------------------------------")
print_to_log ("Starting Telegram api Bot message handler")
print_to_log ("-----------------------------------------")

-- Array to store device list rapid access via index number
StoredType = "None"
StoredList = {}

-- Table to store functions for commands plus descriptions used by help function
commands = {};

-- Load necessary Lua libraries
http = require "socket.http";
socket = require "socket";
https = require "ssl.https";
JSON = require "JSON";
mime = require("mime")

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- Load the configuration file this file contains the list of commands
-- used to define the external files with the command function to load.
local config=""
if (file_exists(BotHomePath.."dtgbot-user.cfg")) then
  config = assert(loadfile(BotHomePath.."dtgbot-user.cfg"))();
  print_to_log ("Using DTGBOT config file:"..BotHomePath.."dtgbot-user.cfg")
else
  config = assert(loadfile(BotHomePath.."dtgbot.cfg"))();
  print_to_log ("Using DTGBOT config file:"..BotHomePath.."dtgbot.cfg")
end
--Not quite sure what this is here for
started = 1

function ok_cb(extra, success, result)
end

function vardump(value, depth, key)
  local linePrefix = ""
  local spaces = ""

  if key ~= nil then
    linePrefix = "["..key.."] = "
  end

  if depth == nil then
    depth = 0
  else
    depth = depth + 1
    for i=1, depth do spaces = spaces .. "  " end
  end

  if type(value) == 'table' then
    mTable = getmetatable(value)
    if mTable == nil then
      print_to_log(1,spaces ..linePrefix.."(table) ")
    else
      print_to_log(1,spaces .."(metatable) ")
      value = mTable
    end
    for tableKey, tableValue in pairs(value) do
      vardump(tableValue, depth, tableKey)
    end
  elseif type(value)	== 'function' or
  type(value)	== 'thread' or
  type(value)	== 'userdata' or
  value		== nil
  then
    print_to_log(1,spaces..tostring(value))
  else
    print_to_log(1,spaces..linePrefix.."("..type(value)..") "..tostring(value))
  end
end

-- Original XMPP function to list device properties
function list_device_attr(dev, mode)
  local result = "";
  local exclude_flag;
  -- Don't dump these fields as they are boring. Name data and idx appear anyway to exclude them
  local exclude_fields = {"Name", "Data", "idx", "SignalLevel", "CustomImage", "Favorite", "HardwareID", "HardwareName", "HaveDimmer", "HaveGroupCmd", "HaveTimeout", "Image", "IsSubDevice", "Notifications", "PlanID", "Protected", "ShowNotifications", "StrParam1", "StrParam2", "SubType", "SwitchType", "SwitchTypeVal", "Timers", "TypeImg", "Unit", "Used", "UsedByCamera", "XOffset", "YOffset"};
  result = "<"..dev.Name..">, Data: "..dev.Data..", Idx: ".. dev.idx;
  if mode == "full" then
    for k,v in pairs(dev) do
      exclude_flag = 0;
      for i, k1 in ipairs(exclude_fields) do
        if k1 == k then
          exclude_flag = 1;
          break;
        end
      end
      if exclude_flag == 0 then
        result = result..k.."="..tostring(v)..", ";
      else
        exclude_flag = 0;
      end
    end
  end
  return result;
end

-- initialise room, device, scene and variable list from Domoticz
function dtgbot_initialise()
  Variablelist = variable_list_names_idxs()
  Devicelist = device_list_names_idxs("devices")
  Scenelist, Sceneproperties = device_list_names_idxs("scenes")
  Roomlist = device_list_names_idxs("plans")

-- Get language from Domoticz
	language = domoticz_language()

-- get the required loglevel
  dtgbotLogLevelidx = idx_from_variable_name("TelegramBotLoglevel")
  if dtgbotLogLevelidx ~= nil then
    dtgbotLogLevel = tonumber(get_variable_value(dtgbotLogLevelidx))
    if dtgbotLogLevel == nil then
      dtgbotLogLevel=0
    end
  end

  print_to_log(0,' dtgbotLogLevel set to: '..tostring(dtgbotLogLevel))

  print_to_log(0,"Loading command modules...")
  for i, m in ipairs(command_modules) do
    print_to_log(0,"Loading module <"..m..">");
    t = assert(loadfile(BotLuaScriptPath..m..".lua"))();
    cl = t:get_commands();
    for c, r in pairs(cl) do
      print_to_log(0,"found command <"..c..">");
      commands[c] = r;
      print_to_log(2,commands[c].handler);
    end
  end

  -- Initialise and populate dtgmenu tables in case the menu is switched on
  Menuidx = idx_from_variable_name("TelegramBotMenu")
  if Menuidx ~= nil then
    Menuval = get_variable_value(Menuidx)
    if Menuval == "On" then
      -- initialise
      -- define the menu table and initialize the table first time
      PopulateMenuTab(1,"")
    end
  end

  return
end

dtgbot_initialise()

function timedifference(s)
  year = string.sub(s, 1, 4)
  month = string.sub(s, 6, 7)
  day = string.sub(s, 9, 10)
  hour = string.sub(s, 12, 13)
  minutes = string.sub(s, 15, 16)
  seconds = string.sub(s, 18, 19)
  t1 = os.time()
  t2 = os.time{year=year, month=month, day=day, hour=hour, min=minutes, sec=seconds}
  difference = os.difftime (t1, t2)
  return difference
end

function HandleCommand(cmd, SendTo, Group, MessageId, channelmsg)
  if channelmsg then
    print_to_log(0,"Handle command function started with " .. cmd .. " and " .. SendTo .. "  Group:"..Group.."   channelmsg:true" )
  else
    print_to_log(0,"Handle command function started with " .. cmd .. " and " .. SendTo .. "  Group:"..Group.."   channelmsg:False")
  end
  --- parse the command
  if command_prefix == "" then
    -- Command prefix is not needed, as can be enforced by Telegram api directly
    parsed_command = {"Stuff"}  -- to make compatible with Hangbot with password
  else
    parsed_command = {}
  end
  -- strip the beginning / from any command
--~   print(cmd)
--~   cmd = cmd:gsub("/.*","%1")
--~   print(cmd)
  local found=0

  ---------------------------------------------------------------------------
  -- Change for menu.lua option
  -- When LastCommand starts with menu then assume the rest is for menu.lua
  ---------------------------------------------------------------------------
  if Menuval == "On" and not channelmsg then
    print_to_log(0,"dtgbot: Start DTGMENU ...", cmd)
    local menu_cli = {}
    table.insert(menu_cli, "")  -- make it compatible
    table.insert(menu_cli, cmd)
    -- send whole cmd line instead of first word
    command_dispatch = commands["dtgmenu"];
    status, text, replymarkup, cmd = command_dispatch.handler(menu_cli,SendTo);
    if status ~= 0 then
      -- stop the process when status is not 0
      if text ~= "" then
        while string.len(text)>0 do
          if Group ~= "" then
            send_msg(Group,string.sub(text,1,4000),MessageId,replymarkup)
          else
            send_msg(SendTo,string.sub(text,1,4000),MessageId,replymarkup)
          end
          text = string.sub(text,4000,-1)
        end
      end
      print_to_log(0,"dtgbot: dtgmenu ended and text send ...return:"..status)
      -- no need to process anything further
      return 1
    end
    print_to_log(0,"dtgbot:continue regular processing. cmd =>",cmd)
  end
  ---------------------------------------------------------------------------
  -- End change for menu.lua option
  ---------------------------------------------------------------------------

  --~	added "-_"to allowed characters a command/word
  for w in string.gmatch(cmd, "([%w-_]+)") do
    table.insert(parsed_command, w)
  end
  if command_prefix ~= "" then
    if parsed_command[1] ~= command_prefix then -- command prefix has not been found so ignore message
      return 1 -- not a command so successful but nothing done
    end
  end

  if(parsed_command[2]~=nil) then
    command_dispatch = commands[string.lower(parsed_command[2])];
    local savereplymarkup = replymarkup
    if command_dispatch then
      status, text, replymarkup = command_dispatch.handler(parsed_command,SendTo);
      found=1
    else
      text = ""
      local f = io.popen("ls " .. BotBashScriptPath)
      cmda = string.lower(tostring(parsed_command[2]))
      len_parsed_command = #parsed_command
      stuff = string.sub(cmd, string.len(cmda)+1)
      for line in f:lines() do
        print_to_log(0,"checking line ".. line)
        if(line:match(cmda)) then
          print_to_log(0,line)
          os.execute(BotBashScriptPath  .. line .. ' ' .. SendTo .. ' ' .. stuff)
          found=1
        end
      end
    end
--~ replymarkup
    if replymarkup == nil or replymarkup == "" then
      -- restore the menu supplied replymarkup in case the shelled LUA didn't provide one
      replymarkup = savereplymarkup
    end
    if found==0 then
      text = "command <"..tostring(parsed_command[2]).."> not found";
    end
  else
    text ='No command found'
  end
  if text ~= "" then
    while string.len(text)>0 do
      if channelmsg then
        send_msg(Group,string.sub(text,1,4000),MessageId)  -- channel messages on support inline menus
      elseif Group ~= "" then
        send_msg(Group,string.sub(text,1,4000),MessageId,replymarkup)
      else
        send_msg(SendTo,string.sub(text,1,4000),MessageId,replymarkup)
      end
      text = string.sub(text,4000,-1)
    end
  elseif replymarkup ~= "" then
    if channelmsg then
      send_msg(Group,"done",MessageId)
    elseif Group ~= "" then
      send_msg(Group,"done",MessageId,replymarkup)
    else
      send_msg(SendTo,"done",MessageId,replymarkup)
    end
  end
  return found
end

function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
      function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

--~ added replymarkup to allow for custom keyboard
function send_msg(SendTo, Message, MessageId, replymarkup)
  if replymarkup == nil or replymarkup == "" then
    print_to_log(1,telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
    response, status = geturl(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
  else
    print_to_log(1,telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message)..'&reply_markup='..url_encode(replymarkup))
    response, status = geturl(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message)..'&reply_markup='..url_encode(replymarkup))
  end
  print_to_log(0,'Message sent',status)
  return
end

function id_check(SendTo)
  --Check if whitelist empty then let any message through
  if WhiteList == nil then
    return true
  else
    SendTo = tostring(SendTo)
    --Check id against whitelist
    for i = 1, #WhiteList do
      print_to_log(0,'WhiteList: '..WhiteList[i])
      if SendTo == WhiteList[i] then
        return true
      end
    end
    -- Checked WhiteList no match
    print_to_log(0,'Not on WhiteList: '..SendTo)
    return false
  end
end

function on_msg_receive (msg)
  if started == 0 then
    return
  end
  if msg.out then
    return
  end

--Check to see if id is whitelisted, if not record in log and exit
  if id_check(msg.from.id) then
    grp_from = msg.chat.id
    msg_from = msg.from.id
    msg_id = msg.message_id
    channelmsg = false
    if msg.chat.type == "channel" then
      channelmsg = true
    end
    if msg.text then   -- check if message is text
      ReceivedText = msg.text
      if HandleCommand(ReceivedText, tostring(msg_from), tostring(grp_from), msg_id, channelmsg) == 1 then
        print_to_log(0,"Succesfully handled incoming request")
      else
        print_to_log(0,"Invalid command received")
        print_to_log(0,msg_from)
        send_msg(msg_from,'⚡️ INVALID COMMAND ⚡️',msg_id)
        --      os.execute("sleep 5")
        --      Help(tostring (msg_from))
      end
    -- check for received voicefiles
    elseif msg.voice then   -- check if message is voicefile
      print_to_log(0,"msg.voice.file_id:",msg.voice.file_id)
      responsev, statusv = geturl(telegram_url..'getFile?file_id='..msg.voice.file_id)
      if statusv == 200 then
        print_to_log(1,"responsev:",responsev)
        decoded_responsev = JSON:decode(responsev)
        result = decoded_responsev["result"]
        filelink = result["file_path"]
        print_to_log(1,"filelink:",filelink)
        ReceivedText="voice "..filelink
        if HandleCommand(ReceivedText, tostring(msg_from), tostring(grp_from), msg_id, channelmsg) == 1 then
          print_to_log(0,"Succesfully handled incoming voice request")
        else
          print_to_log(0,"Voice file received but voice.sh or lua not found to process it. skipping the message.")
          print_to_log(0,msg_from)
          send_msg(msg_from,'⚡️ INVALID COMMAND ⚡️',msg_id)
        end
      end
    elseif msg.video_note then   -- check if message is videofile
      print_to_log(0,"msg.video_note.file_id:",msg.video_note.file_id)
      responsev, statusv = geturl(telegram_url..'getFile?file_id='..msg.video_note.file_id)
      if statusv == 200 then
        print_to_log(1,"responsev:",responsev)
        decoded_responsev = JSON:decode(responsev)
        result = decoded_responsev["result"]
        filelink = result["file_path"]
        print_to_log(1,"filelink:",filelink)
        ReceivedText="video "..filelink
        if HandleCommand(ReceivedText, tostring(msg_from), tostring(grp_from), msg_id, channelmsg) == 1 then
          print_to_log(0,"Succesfully handled incoming video request")
        else
          print_to_log(0,"Video file received but video_note.sh or lua not found to process it. Skipping the message.")
          print_to_log(0,msg_from)
          send_msg(msg_from,'⚡️ INVALID COMMAND ⚡️',msg_id)
        end
      end
    end
  else
    print_to_log(0,'id '..msg_from..' not on white list, command ignored')
    send_msg(msg_from,'⚡️ ID Not Recognised - Command Ignored ⚡️',msg_id)
  end
--  mark_read(msg_from)
end

--function on_our_id (id)
--  our_id = id
--end

function on_secret_chat_created (peer)
  --vardump (peer)
end

function on_user_update (user)
  --vardump (user)
end

function on_chat_update (user)
  --vardump (user)
end

function on_get_difference_end ()
end

function on_binlog_replay_end ()
  started = 1
end

-- get the require loglevel
dtgbotLogLevelidx = idx_from_variable_name("TelegramBotLoglevel")
if dtgbotLogLevelidx ~= nil then
  dtgbotLogLevel = tonumber(get_variable_value(dtgbotLogLevelidx))
  if dtgbotLogLevel == nil then
    dtgbotLogLevel=0
  end
end
print_to_log(0,' dtgbotLogLevel set to: '..tostring(dtgbotLogLevel))

-- Retrieve id white list
WLidx = idx_from_variable_name(WLName)
if WLidx == nil then
  print_to_log(0,WLName..' user variable does not exist in Domoticz')
  print_to_log(0,'So will allow any id to use the bot')
else
  print_to_log(0,'WLidx '..WLidx)
  WLString = get_variable_value(WLidx)
  print_to_log(0,'WLString: '..WLString)
  WhiteList = get_names_from_variable(WLString)
end

-- Get the updates
print_to_log(0,'Getting '..TBOName..' the previous Telegram bot message offset from Domoticz')
TBOidx = idx_from_variable_name(TBOName)
if TBOidx == nil then
  print_to_log(0,TBOName..' user variable does not exist in Domoticz so can not continue')
  os.exit()
else
  print_to_log(1,'TBOidx '..TBOidx)
end
TelegramBotOffset=get_variable_value(TBOidx)
print_to_log(1,'TBO '..TelegramBotOffset)
print_to_log(1,telegram_url)
telegram_connected = false
--Update monitorfile before loop
os.execute("echo " .. os.date("%Y-%m-%d %H:%M:%S") .. " >> " .. TempFileDir .. "/dtgloop.txt")
while file_exists(dtgbot_pid) do
  response, status = geturl(telegram_url..'getUpdates?timeout=60&limit=1&offset='..TelegramBotOffset)
  if status == 200 then
    if not telegram_connected then
      print_to_log(0,'')
      print_to_log(0,'### In contact with Telegram servers')
      telegram_connected = true
    end
    if response ~= nil then
      io.write('.')
      print_to_log(1,"")
      print_to_log(1,response)
      decoded_response = JSON:decode(response)
      result_table = decoded_response['result']
      tc = #result_table
      for i = 1, tc do
        print_to_log(1,'Message: '..i)
        tt = table.remove(result_table,1)
        print_to_log(1,'update_id ',tt.update_id)
        TelegramBotOffset = tt.update_id + 1
        print_to_log(1,'TelegramBotOffset '..TelegramBotOffset)
        set_variable_value(TBOidx,TBOName,0,TelegramBotOffset)
        -- get message from Json result
        msg = tt['message']
        -- checking for channel message
        if tt['channel_post'] ~= nil then
          print_to_log(3,'<== received channel message, reformating result to be able to process.')
          msg = tt['channel_post']
          msg.from = {}
          msg.from.id = msg.chat.id
        end
        -- processing message
        -- Offset updated before processing in case of crash allows clean restart
        if (msg ~= nil and (msg.text ~= nil or msg.voice ~= nil or msg.video_note ~= nil)) then
            print_to_log(1,msg.text)
            on_msg_receive(msg)
        end
      end
    else
      io.write('X')
      print_to_log(2,'')
      print_to_log(2,'Updates retrieved',status)
    end
  else
    io.write('?')
    if telegram_connected then
      print_to_log(0,'')
      print_to_log(0,'### Lost contact with Telegram servers, received Non 200 status - returned - ',status)
      telegram_connected = false
    end
    -- sleep a little to slow donw the loop
    os.execute("sleep 5")
  end
  --Update monitorfile each loop
  os.execute("echo " .. os.date("%Y-%m-%d %H:%M:%S") .. " >> " .. TempFileDir .. "/dtgloop.txt")
end
print_to_log(0,dtgbot_pid..' does not exist, so exiting')
