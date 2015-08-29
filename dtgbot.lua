-- ~/tg/scripts/generic/domoticz2telegram.lua
-- Version 0.2 150826
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
  if string.sub(envpath,-2,-1) ~= "/" then
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

-- Load the configuration file this file contains the list of commands
-- used to define the external files with the command function to load.
local config = assert(loadfile(BotHomePath.."dtgbot.cfg"))();

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
  if Variablelist == nil then
    print_to_log(0,'No Variables defined in Domoticz - exiting')
    os.exit()
  end
  Devicelist = device_list_names_idxs("devices")
  if Devicelist == nil then
    print_to_log(0,'No Devices defined in Domoticz - exiting')
    os.exit()
  end
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

function HandleCommand(cmd, SendTo, Group, MessageId)
  print_to_log(0,"Handle command function started with " .. cmd .. " and " .. SendTo)
  --- parse the command
  if command_prefix == "" then
    -- Command prefix is not needed, as can be enforced by Telegram api directly
    parsed_command = {"Stuff"}  -- to make compatible with Hangbot with password
  else
    parsed_command = {}
  end
  -- strip the beginning / from any command
  --cmd = cmd:gsub("/","") - takes out all slashes
--  if cmd:sub(1,1) == "/" then -- should just take out one
--    cmd = cmd:sub(2)
--  end
  local found=0

  ---------------------------------------------------------------------------
  -- Change for menu.lua option
  -- When LastCommand starts with menu then assume the rest is for menu.lua
  ---------------------------------------------------------------------------
  if Menuval == "On" then
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
--~ change to allow for replymarkup.
    local savereplymarkup = replymarkup
--~ 	print("debug1." ,replymarkup)
    if command_dispatch then
--?      status, text = command_dispatch.handler(parsed_command);
--~      change to allow for replymarkup.
      status, text, replymarkup = command_dispatch.handler(parsed_command,SendTo);
      found=1
    else
      text = ""
      local f = io.popen("ls " .. BotBashScriptPath)
--?      cmda = string.lower(parsed_command[2])
--~ change to avoid nil error
      cmda = string.lower(tostring(parsed_command[2]))
      len_parsed_command = #parsed_command
      stuff = ""
      for i = 3, len_parsed_command do
        stuff = stuff..parsed_command[i]
      end
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
--~ 	print("debug2." ,replymarkup)
    if found==0 then
--?      text = "command <"..parsed_command[2].."> not found";
--~ change to avoid nil error
      text = "command <"..tostring(parsed_command[2]).."> not found";
    end
  else
    text ='No command found'
  end
  if text ~= "" then
    while string.len(text)>0 do
--~         added replymarkup to allow for custom keyboard
      if Group ~= "" then
        send_msg(Group,string.sub(text,1,4000),MessageId,replymarkup)
      else
        send_msg(SendTo,string.sub(text,1,4000),MessageId,replymarkup)
      end
      text = string.sub(text,4000,-1)
    end
  elseif replymarkup ~= "" then
--~     added replymarkup to allow for custom keyboard reset also in case there is no text to send.
--~     This could happen after running a bash file.
    if Group ~= "" then
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
    response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
  else
    print_to_log(1,telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message)..'&reply_markup='..url_encode(replymarkup))
    response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message)..'&reply_markup='..url_encode(replymarkup))
  end
--  response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&text=hjk')
  print_to_log(0,'Message sent',status)
  return
end

--?function send_msg(SendTo, Message,MessageId)
--?  print_to_log(0,telegram_url..'sendMessage?timeout=60&chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
--?  response, status = --?https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
--  response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&text=hjk')
--?  print_to_log(0,status)
--?  return
--?end



--Commands.Smiliesoverview = "Smiliesoverview - sends a range of smilies"

--function Smiliesoverview(SendTo)
--  smilies = {"smiley 😀", "crying smiley 😢", "sleeping smiley 😴", "beer 🍺", "double beer 🍻",
--    "wine 🍷", "double red excam ‼️", "yellow sign exclamation mark ⚠️ ", "camera 📷", "light(on) 💡",
--    "open sun 🔆", "battery 🔋", "plug 🔌", "film 🎬", "music 🎶", "moon 🌙", "sun ☀️", "sun behind some clouds ⛅️",
--    "clouds ☁️", "lightning ⚡️", "umbrella ☔️", "snowflake ❄️"}
--  for i,smiley in ipairs(smilies) do
--    send_msg(SendTo,smiley,ok_cb,false)
--  end
--  return
--end

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

  if msg.text then   -- check if message is text
    --  ReceivedText = string.lower(msg.text)
    ReceivedText = msg.text

--    if msg.to.type == "chat" then -- check if the command was given in a group chat
--      msg_from = msg.to.print_name -- if yes, take the group name as a destination for the reply
--    else
--      msg_from = msg.from.print_name -- if no, take the users name as destination for the reply
--    end
--    msg_from = msg.from.id
--  Changed from from.id to chat.id to allow group chats to work as expected.
    grp_from = msg.chat.id
    msg_from = msg.from.id
    msg_id =msg.message_id
--Check to see if id is whitelisted, if not record in log and exit
    if id_check(msg_from) then
      if HandleCommand(ReceivedText, tostring(msg_from), tostring(grp_from),msg_id) == 1 then
        print_to_log(0,"Succesfully handled incoming request")
      else
        print_to_log(0,"Invalid command received")
        print_to_log(0,msg_from)
        send_msg(msg_from,'⚡️ INVALID COMMAND ⚡️',msg_id)
        --      os.execute("sleep 5")
        --      Help(tostring (msg_from))
      end
    else
      print_to_log(0,'id '..msg_from..' not on white list, command ignored')
      send_msg(msg_from,'⚡️ ID Not Recognised - Command Ignored ⚡️',msg_id)
    end
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
--while TelegramBotOffset do
while file_exists(dtgbot_pid) do
  response, status = https.request(telegram_url..'getUpdates?timeout=60&offset='..TelegramBotOffset)
  if status == 200 then
    if response ~= nil then
      io.write('.')
      print_to_log(1,response)
      decoded_response = JSON:decode(response)
      result_table = decoded_response['result']
      tc = #result_table
      for i = 1, tc do
        print_to_log(1,'Message: '..i)
        tt = table.remove(result_table,1)
        msg = tt['message']
        print_to_log(1,'update_id ',tt.update_id)
        print_to_log(1,msg.text)
        TelegramBotOffset = tt.update_id + 1
        print_to_log(1,'TelegramBotOffset '..TelegramBotOffset)
        set_variable_value(TBOidx,TBOName,0,TelegramBotOffset)
        -- Offset updated before processing in case of crash allows clean restart
        on_msg_receive(msg)
      end
    else
      print_to_log(2,'Updates retrieved',status)
    end
  end
end
print_to_log(0,dtgbot_pid..' does not exist, so exiting')
