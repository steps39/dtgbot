-- ~/tg/scripts/generic/domoticz2telegram.lua
-- Version 0.1 150725
-- Automation bot framework for telegram to control Domoticz
-- domoticz2telegram.lua does not require any customisation (see below)
-- and does not require any telegram client to be installed
-- all communication is via authenticated https
-- Extra functions can be added by replicating list.lua,
-- replacing list with the name of your new command see list.lua
-- Based on test.lua from telegram-cli from
-- Adapted to abstract functions into external files using
-- the framework of the XMPP bot, so allowing functions to
-- shared between the two bots.
-- -------------------------------------------------------

print ("-----------------------------------------")
print ("Starting Telegram api Bot message handler")
print ("-----------------------------------------")

function domoticzdata(envvar)
  -- loads get environment variable and prints in log
  localvar = os.getenv(envvar)
  if localvar ~= nil then
    print(envvar..": "..localvar)
  else
    print(envvar.." not found check /etc/profile.d/DomoticzData.sh")
  end
  return localvar
end

function checkpath(envpath)
  if string.sub(envpath,-2,-1) ~= "/" then
    envpath = envpath .. "/"
  end
  return envpath
end

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
      print(spaces ..linePrefix.."(table) ")
    else
      print(spaces .."(metatable) ")
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
    print(spaces..tostring(value))
  else
    print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
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


function form_device_name(parsed_cli)
-- joins together parameters after the command name to form the full "device name"
  command = parsed_cli[2]
  DeviceName = parsed_cli[3]
  len_parsed_cli = #parsed_cli
  if len_parsed_cli > 3 then
    for i = 4, len_parsed_cli do
      DeviceName = DeviceName..' '..parsed_cli[i]
    end
  end
  return DeviceName
end

function variable_list()
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type=command&param=getuservariables"
  jresponse = nil
  domoticz_tries = 1
  -- Domoticz seems to take a while to respond to getuservariables after start-up
  -- So just keep trying after 1 second sleep
  while (jresponse == nil) do
    print ("JSON request <"..t..">");
    jresponse, status = http.request(t)
    if (jresponse == nil) then
      socket.sleep(1)
      domoticz_tries = domoticz_tries + 1
      if domoticz_tries > 100 then
        print('Domoticz not sending back user variable list')
        break
      end
    end
  end
  print('Domoticz returned getuservariables after '..domoticz_tries..' attempts')
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

function idx_from_variable_name(DeviceName)
  local idx, k, record, decoded_response
  decoded_response = variable_list()
  result = decoded_response["result"]
  for k,record in pairs(result) do
    if type(record) == "table" then
      if string.lower(record['Name']) == string.lower(DeviceName) then
        print(record['idx'])
        idx = record['idx']
      end
    end
  end
  return idx
end

function get_variable_value(idx)
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=getuservariable&idx="..tostring(idx)
  print ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  print('Decoded '..decoded_response["result"][1]["Value"])
  return decoded_response["result"][1]["Value"]
end

function set_variable_value(idx,name,value)
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=updateuservariable&idx="..idx.."&vname="..name.."&vtype=integer&vvalue="..tostring(value)
  print ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  return
end

function device_list(DeviceType)
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type="..DeviceType.."&order=name"
  print ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

function idx_from_name(DeviceName,DeviceType)
  local idx, k, record, decoded_response
  decoded_response = device_list(DeviceType)
  result = decoded_response["result"]
  for k,record in pairs(result) do
    if type(record) == "table" then
      if string.lower(record['Name']) == string.lower(DeviceName) then
        print(record['idx'])
        idx = record['idx']
      end
    end
  end
  return idx
end

function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

--print("Checking for Domoticz running")
--while (not file_exists(domoticz_pid)) do
--end
--print("Domoticz running")
-- Load the modules that handle the commands. each module can have more than one command associated with it (see the list example)
print("Loading command modules...")
for i, m in ipairs(command_modules) do
  print("Loading module <"..m..">");
  t = assert(loadfile(BotLuaScriptPath..m..".lua"))();
  cl = t:get_commands();
  for c, r in pairs(cl) do
    print("found command <"..c..">");
    commands[c] = r;
    print(commands[c].handler);
  end
end

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

function HandleCommand(cmd, SendTo, MessageId)
  print("Handle command function started with " .. cmd .. " and " .. SendTo)
  --- parse the command
  if command_prefix == "" then
    -- Command prefix is not needed, as can be enforced by Telegram api directly
    parsed_command = {"Stuff"}  -- to make compatible with Hangbot with password
  else
    parsed_command = {}
  end
  for w in string.gmatch(cmd, "(%w+)") do
    table.insert(parsed_command, w)
  end
  if command_prefix ~= "" then
    if parsed_command[1] ~= command_prefix then -- command prefex has not been found so ignore message
      return 1 -- not a command so successful but nothing done
    end
  end
  local found=0
  command_dispatch = commands[string.lower(parsed_command[2])];
  if command_dispatch then
    status, text = command_dispatch.handler(parsed_command);
    found=1
  else
    text = ""
    local f = io.popen("ls " .. BotBashScriptPath)
    cmda = string.lower(parsed_command[2])
    len_parsed_command = #parsed_command
    stuff = ""
    for i = 3, len_parsed_command do
      stuff = stuff..parsed_command[i]
    end
    for line in f:lines() do
      print("checking line ".. line)
      if(line:match(cmda)) then
        print(line)
        os.execute(BotBashScriptPath  .. line .. ' ' .. SendTo .. ' ' .. stuff)
        found=1
      end
    end
  end
  if found==0 then
    text = "command <"..parsed_command[2].."> not found";
  end
  if text ~= "" then
--    if string.len(text)>4000 then
    while string.len(text)>0 do
      send_msg(SendTo,string.sub(text,1,4000),MessageId)
      text = string.sub(text,4000,-1)
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

function send_msg(SendTo, Message,MessageId)
  print(telegram_url..'sendMessage?timeout=60&chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
  response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&reply_to_message_id='..MessageId..'&text='..url_encode(Message))
--  response, status = https.request(telegram_url..'sendMessage?chat_id='..SendTo..'&text=hjk')
  print(status)
  return
end


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
    print('No on WhiteList: '..#WhiteList)
    for i = 1, #WhiteList do
      print('WhiteList: '..WhiteList[i])
      if SendTo == WhiteList[i] then
        return true
      end
    end
    -- Checked WhiteList no match
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
    msg_from = msg.chat.id
    msg_id =msg.message_id
--Check to see if id is whitelisted, if not record in log and exit
    if id_check(msg_from) then
      if HandleCommand(ReceivedText, tostring(msg_from),msg_id) == 1 then
        print "Succesfully handled incoming request"
      else
        print "Invalid command received"
        print(msg_from)
        send_msg(msg_from,'⚡️ INVALID COMMAND ⚡️',msg_id)
        --      os.execute("sleep 5")
        --      Help(tostring (msg_from))
      end
    else
      print('id '..msg_from..' not on white list, command ignored')
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

function get_names_from_variable(DividedString)
  Names = {}
  for Name in string.gmatch(DividedString, "[^|]+") do
    Names[#Names + 1] = Name
    print('Name :'..Name)
  end
  return Names
end

-- Retrieve id white list
WLidx = idx_from_variable_name(WLName)
if WLidx == nil then
  print(WLName..' user variable does not exist in Domoticz')
  print('So will allow any id to use the bot')
else
  print('WLidx '..WLidx)
  WLString = get_variable_value(WLidx)
  print('WLString: '..WLString)
  WhiteList = get_names_from_variable(WLString)
end

-- Get the updates
print('Getting '..TBOName..' the previous Telegram bot message offset from Domoticz')
TBOidx = idx_from_variable_name(TBOName)
if TBOidx == nil then
  print(TBOName..' user variable does not exist in Domoticz')
  os.exit()
else
  print('TBOidx '..TBOidx)
end
TelegramBotOffset=get_variable_value(TBOidx)
print('TBO '..TelegramBotOffset)
print(telegram_url)
--while TelegramBotOffset do
while file_exists(dtgbot_pid) do
  response, status = https.request(telegram_url..'getUpdates?timeout=60&offset='..TelegramBotOffset)
  if status == 200 then
    if response ~= nil then
      io.write('.')
      print(response)
      decoded_response = JSON:decode(response)
      result_table = decoded_response['result']
      tc = #result_table
      for i = 1, tc do
        print('Message: '..i)
        tt = table.remove(result_table,1)
        msg = tt['message']
        print('update_id ',tt.update_id)
        print(msg.text)
        TelegramBotOffset = tt.update_id + 1
        on_msg_receive(msg)
        print('TelegramBotOffset '..TelegramBotOffset)
        set_variable_value(TBOidx,TBOName,TelegramBotOffset)
      end
    else
      print(status)
    end
  end
end
print(dtgbot_pid..' does not exist, so exiting')
