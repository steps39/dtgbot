--[[
-- Version 0.900 20210113
  functions for the main dtgbot.au3 script
]]

-- ===========================================================================================================
-- dtgbot initialisation step to:
--  initialise room, device, scene and variable list from Domoticz
--  load the available modules
-- ===========================================================================================================
function DtgBot_Initialise()
  Variablelist = Domo_Variable_List_Names_IDXs()
  Devicelist = Domo_Device_List_Names_IDXs("devices")
  Scenelist, Sceneproperties = Domo_Device_List_Names_IDXs("scenes")
  Roomlist = Domo_Device_List_Names_IDXs("plans")

  -- Get Language from Domoticz
  Language = Domoticz_Language()

  -- get the required loglevel
  --  When defined in Domoticz use that or else use the default defined in dtgbot[_user].cf
  local dtgbotLogLevelidx = Domo_Idx_From_Variable_Name("TelegramBotLoglevel")
  if dtgbotLogLevelidx ~= nil then
    DtgBotLogLevel = tonumber(Domo_Get_Variable_Value(dtgbotLogLevelidx)) or DtgBotLogLevel
    Print_to_Log(0, "Domoticz DtgBotLogLevel set to: " .. tostring(DtgBotLogLevel))
  else
    Print_to_Log(0, "DtgBotLogLevel set to: " .. tostring(DtgBotLogLevel))
  end

  -- Load all modules
  Load_LUA_Modules()

  -- Retrieve id white list
  WLidx = Domo_Idx_From_Variable_Name(WLName)
  if WLidx == nil then
    Print_to_Log(0, WLName .. " user variable does not exist in Domoticz")
    Print_to_Log(0, "So will allow any id to use the bot!")
  else
    WLString = Domo_Get_Variable_Value(WLidx)
    Print_to_Log(0, Sprintf("WLName:%s  WLidx:%s  WLString:%s", WLName, WLidx, WLString))
    WhiteList = Domo_Get_Names_From_Variable(WLString)
  end

  -- Retrieve id Menu white list
  MenuWLidx = Domo_Idx_From_Variable_Name(MenuWLName)
  MenuWhiteList = {}
  if MenuWLidx == nil then
    Print_to_Log(1, MenuWLName .. " user variable does not exist in Domoticz")
    Print_to_Log(1, "So everybody will see all available rooms in DOmoticz!")
  else
    Print_to_Log(1, "-> Get Menu Whitelist per SendTo and/or Default(0) from Domoticz")
    MenuWhiteListin = Domo_Get_Variable_Value(MenuWLidx).."|"
    for iSendTo, iWhiteList in MenuWhiteListin:gmatch("(%d+)[:=]([^|]+)") do
      MenuWhiteList[iSendTo] = {}
      Print_to_Log(1,">",iSendTo or "nil", iWhiteList or "nil")
      for iMenu in iWhiteList:gmatch("%s*(%d+)%s*,?") do
        MenuWhiteList[iSendTo][tostring(iMenu)] = 1
        Print_to_Log(1,"   ",#MenuWhiteList[iSendTo],iSendTo or "nil", iMenu or "nil")
      end
    end
  end
end
-- ===========================================================================================================
-- Main Functions to Process Received Message
-- ===========================================================================================================
-- Step 1: Check Message content, validity and preprocess data
function PreProcess_Received_Message(tt)
  -- return the encountered error in stead of crashing the script
  --  if unexpected_condition then
  --    error()
  --  end
  -- extract the message part for regulater messages
  local msg = tt["message"]
  -- extract the message part for callback messages from inline keyboards
  if tt["callback_query"] ~= nil then
    -- checking for callback_query message from inline keyboard.
    Print_to_Log(3, "<== Received callback_query, reformating result to be able to process.")
    msg = tt["callback_query"]
    msg.chat = {}
    msg.chat.id = msg.message.chat.id
    msg.message_id = msg.message.message_id
    msg.text = msg.data
  elseif tt["channel_post"] ~= nil then
    -- extract change some fields for channel messages to use the same field names
    Print_to_Log(3, "<== Received channel message, reformating result to be able to process.")
    msg = tt["channel_post"]
    msg.from = {}
    msg.from.id = msg.chat.id
  end
  if (msg == nil) then
    return "Received message table empty"
  end
  local ReceivedText, msg_type = "command"

  --Check to see if id is whitelisted, if not record in log and exit
  if ID_WhiteList_Check(msg.from.id) then
    local grp_from = tostring(msg.chat.id)
    local msg_from = tostring(msg.from.id)
    local msg_id = tostring(msg.message_id)
    local chat_type = ""
    -- determine the chat_type
    if msg.chat.type == "channel" then
      chat_type = "channel"
    elseif msg.message ~= nil and msg.message.chat.id ~= nil then
      chat_type = "callback"
    end
    -- get the appropriate info from the different message types
    if msg.text then -- check if message is text
      -- check for received voicefiles
      ReceivedText = msg.text
    elseif msg.voice then -- check if message is voicefile
      -- check for received voicefiles
      Print_to_Log(0, "msg.voice.file_id:", msg.voice.file_id)
      responsev, statusv = GetUrl(Telegram_Url .. "getFile?file_id=" .. msg.voice.file_id)
      if statusv == 200 then
        Print_to_Log(1, "responsev:", responsev)
        decoded_responsev = JSON.decode(responsev)
        result = decoded_responsev["result"]
        filelink = result["file_path"]
        Print_to_Log(1, "filelink:", filelink)
        ReceivedText = "voice " .. filelink
        msg_type = "voice"
      end
    elseif msg.video_note then -- check if message is videofile
      Print_to_Log(0, "msg.video_note.file_id:", msg.video_note.file_id)
      responsev, statusv = GetUrl(Telegram_Url .. "getFile?file_id=" .. msg.video_note.file_id)
      if statusv == 200 then
        Print_to_Log(1, "responsev:", responsev)
        decoded_responsev = JSON.decode(responsev)
        result = decoded_responsev["result"]
        filelink = result["file_path"]
        Print_to_Log(1, "filelink:", filelink)
        ReceivedText = "video " .. filelink
        msg_type = "video"
      end
    end
    --------------------------------------------------------------------------------------------
    -- Handle the received command and capture any errors to avoid hardcrash
    --print(ReceivedText)
    local result_status, result, result_err = xpcall(HandleCommand, ErrorHandler, ReceivedText, msg_from, grp_from, msg_id, chat_type)
    --[[
     print("--onmsg------")
     print(result_status)
     print("--------")
     print(err)
     print("--------")
     print(result)
     print("--------")
     ]]
    if not result_status then
      -- Hard error process - send warning to telegram to inform sender of the failure amd return the info for logging
      Telegram_SendMessage(msg_from, Sprintf("⚡️ Command caused error. check dtgbot log ⚡️\nError:%s", result[1]), msg_id)
      Print_to_Log(0, Sprintf("<- !!! function PreProcess_Received_Message failed: \nError:%s\n%s", result[1], result[2]))
      return "", "PreProcess_Received_Message failed"
    else
      -- No hard error process
      if result_err == nil then
        Print_to_Log(0, "Succesfully handled incoming request")
      else
        if msg_type == "voice" then
          Print_to_Log(0, "!! Voice file received but voice.sh or lua not found to process it. skipping the message.")
          Telegram_SendMessage(msg_from, "⚡️ voice.sh or lua missing?? ⚡️", msg_id)
        elseif msg_type == "voice" then
          Print_to_Log(0, "!! Video file received but video_note.sh or lua not found to process it. Skipping the message.")
          Telegram_SendMessage(msg_from, "⚡️ video_note.sh or lua missing?? ⚡️", msg_id)
        else
          --print(ReceivedText)
          Print_to_Log(0, Sprintf("!! error in command: %s - %s ", result, result_err))
          Telegram_SendMessage(msg_from, "⚡️ " .. result .. " " .. result_err .. " ⚡️", msg_id)
        end
      end
      return result, result_err
    end
  else
    Print_to_Log(0, "id " .. msg_from .. " not on white list, command ignored")
    Telegram_SendMessage(msg_from, "⚡️ ID Not Recognised - Command Ignored ⚡️", msg_id)
    return "", "ID not autherized"
  end
  return ""
end
---------------------------------------------------------
-- Step 2: Handle the received command/data
-- Process the received command
function HandleCommand(cmd, SendTo, Group, MessageId, chat_type)
  chat_type = chat_type or ""
  local found = false
  local parsed_command = {}
  local text, command_dispatch, status, replymarkup
  local handled_by = "other"

  Print_to_Log(0, Sprintf("dtgbot: HandleCommand=> cmd:%s  SendTo:%s  Group:%s  chat_type:%s ", cmd, SendTo, Group, chat_type))
  --- parse the command
  --Command_Prefix is set in the dtgbot.cfg, default ""
  --    start with entry "stuff" when no prefix defined to ensure the same table position for the rest
  Command_Prefix = Command_Prefix or ""

  -- strip the beginning / from any command
  -- the / infront of a comment make the text a link you can click by Telegram, so usefull to add in send text.
  cmd = cmd:gsub("^/", "")
  -- get commandline parameters
  for w in cmd:gmatch("([^ ]+)") do
    if #parsed_command == 0 then
      if Command_Prefix ~= "" then
        -- check for a valid prefix
        if w ~= Command_Prefix then
          return 1 -- not a command so successful but nothing done
        end
      else
        table.insert(parsed_command, "stuff")
      end
    end
    table.insert(parsed_command, w)
    Print_to_Log(2, Sprintf(" - parsed_command[%s]  %s", #parsed_command, w))
  end
  -- return when no command
  if (parsed_command[2] == nil) then
    return "", "command missing"
  end
  ---------------------------------------------------------------------------
  -- Start integration for dtgmenu.lua option
  ---------------------------------------------------------------------------
  if (Persistent.UseDTGMenu == 1
      or string.lower(parsed_command[2]) == "dtgmenu"
      or string.lower(parsed_command[2]) == "menu")
    and chat_type ~= "channel" then
    Print_to_Log(0, Sprintf("-> forward to dtgmenu :%s  %s", cmd, parsed_command[2]))
    command_dispatch = Available_Commands["dtgmenu"] or {handler = {}}
    found, text, replymarkup = command_dispatch.handler(parsed_command, SendTo, cmd)
    if found then
      handled_by = "menu"
    elseif UseInlineMenu and parsed_command[2] == "menu" then
      -- remove the 2 layer inline menu commands
      for i = 2, #parsed_command-2, 1 do
        Print_to_Log(1,parsed_command[i] or "nil",parsed_command[i+2] or "nil" )
        if not parsed_command[i+2] or parsed_command[i+2] == "" then
          parsed_command[i] = ""
          break
        end
        parsed_command[i] = parsed_command[i+2]
        parsed_command[i+2] = ""
      end
    end
  end
  local savereplymarkup = replymarkup
  ---------------------------------------------------------------------------
  -- End integration for dtgmenu.lua option
  ---------------------------------------------------------------------------
  -------- process commandline ------------
  -- first check for some internal dtgbot commands
  -- command reload modules will reload all LUA modules without having to restart the Service
  if string.lower(parsed_command[2]) == "_reloadmodules" then
    Print_to_Log("-> Start _reloadmodules process.")
    text = "modules reloaded"
    found = true
    Available_Commands = {}
    -- ensure the require packages for dtgmenu are removed
    package.loaded["dtgmenubottom"] = nil
    package.loaded["dtgmenuinline"] = nil
   -- Now reload the modules
    Load_LUA_Modules()

  elseif string.lower(parsed_command[2]) == "_reloadconfig" then
    Print_to_Log("-> Start _reloadconfig process.")
--~ =========================================================
--~ commented as this is handled by the reload of the modules
--~ =========================================================
--~ 	-- save current menu type
--~ 	saveUseInlineMenu = UseInlineMenu
--~     if (FileExists(ScriptDirectory .. "dtgbot-user.cfg")) then
--~       assert(loadfile(ScriptDirectory .. "dtgbot-user.cfg"))()
--~       Print_to_Log(0, "Using DTGBOT config file:" .. ScriptDirectory .. "dtgbot-user.cfg")
--~     else
--~       assert(loadfile(ScriptDirectory .. "dtgbot.cfg"))()
--~       Print_to_Log(0, "Using DTGBOT config file:" .. ScriptDirectory .. "dtgbot.cfg")
--~     end
--~ 	-- override config with the last used menu type
--~ 	UseInlineMenu=saveUseInlineMenu
    -- reset these tables to start with a clean slate
    LastCommand = {}
    Available_Commands = {}
    -- ensure the require packages for dtgmenu are removed
    package.loaded["dtgmenubottom"] = nil
    package.loaded["dtgmenuinline"] = nil
	-- reinit dtgbot
    DtgBot_Initialise()
    found = true
    text = "Config and Modules reloaded"

  elseif string.lower(parsed_command[2]) == "_cleanall" then
    Print_to_Log("-> Start _cleanall process.")
    Telegram_CleanMessages(SendTo, MessageId, 0, "", true)
    found = true
    text = ""

  elseif string.lower(parsed_command[2]) == "_togglekeyboard" then
    Print_to_Log("-> Start _ToggleKeyboard process.")
    ----------------------------------
    -- start disabled current keyboard
    local tcommand={"","Exit_Menu","Exit_Menu",""}
    local icmdline = "Exit_Menu"
    local iMessageId = MessageId
    if UseInlineMenu then
      tcommand={"menu exit","menu","exit",""}
      icmdline = ""
      Print_to_Log(1, Sprintf("Persistent.LastInlinemessage_id=%s", Persistent.LastInlinemessage_id or "nil"))
      iMessageId = Persistent.LastInlinemessage_id or MessageId
    end
    command_dispatch = Available_Commands["dtgmenu"] or {handler = {}}
    status, text, replymarkup = command_dispatch.handler(tcommand, SendTo, icmdline)
    -- reset vars
    Persistent.UseDTGMenu=0
    Persistent.iLastcommand=""
    chat_type=""

    -- send telegram msg
    if Group ~= "" then
      Telegram_SendMessage(Group, "removed keyboard", iMessageId, replymarkup, "callback", handled_by)
    else
      Telegram_SendMessage(SendTo, "removed keyboard", iMessageId, replymarkup, "callback", handled_by)
    end
  ----------------------------------
    -- toggle setting
    UseInlineMenu = not UseInlineMenu
    ----------------------------------
    -- Reset handler
    --Available_Commands["menu"] = nil
    --Available_Commands["dtgmenu"] = nil
    --Load_LUA_Module("dtgmenu")
    if UseInlineMenu then
      Print_to_Log(1, "Set Handler to DTGil.handler")
      Available_Commands["menu"] = {handler = DTGil.handler, description = "Will start menu functionality."}
      Available_Commands["dtgmenu"] = {handler = DTGil.handler, description = "Will start menu functionality."}
      --dtgmenu_commands = {["menu"] = {handler = DTGil.handler, description = "Will start menu functionality."},
      --                 ["dtgmenu"] = {handler = DTGil.handler, description = "Will start menu functionality."}
      --}
      replymarkup = '{"remove_keyboard":true}'
    else
      Print_to_Log(1, "Set Handler to DTGbo.handler")
      Available_Commands["menu"] = {handler = DTGbo.handler, description = "Will start menu functionality."}
      Available_Commands["dtgmenu"] = {handler = DTGbo.handler, description = "Will start menu functionality."}
      --dtgmenu_commands = {["menu"] = {handler = DTGbo.handler, description = "Will start menu functionality."},
      --                 ["dtgmenu"] = {handler = DTGbo.handler, description = "Will start menu functionality."}
      --}
    end
    ----------------------------------
    -- show Keyboard
    local tcommand={"menu","menu","menu",""}
    command_dispatch = Available_Commands["dtgmenu"] or {handler = {}}
    found, text, replymarkup = command_dispatch.handler(tcommand, SendTo, "menu")

    Print_to_Log("-> end  _ToggleKeyboard process.")
    found = true

  elseif not found then
    -- check for loaded LUA modules
    Print_to_Log(Sprintf("Not found as Menu or Fixed command so try Lua or Bash options for %s", string.lower(parsed_command[2])))
    command_dispatch = Available_Commands[string.lower(parsed_command[2])]
    if command_dispatch then
      Print_to_Log(Sprintf("->run lua command %s", string.lower(parsed_command[2])))
      found, text, replymarkup = command_dispatch.handler(parsed_command, SendTo, MessageId, savereplymarkup)
      text = text or ""
      found = true
      if found and string.lower(parsed_command[2]) == "menu" then
        handled_by = "menu"
      end
    else
      -- check for BASH modules
      text = ""
      local f = io.popen("ls " .. BotBashScriptPath)
      cmda = string.lower(tostring(parsed_command[2]))
      len_parsed_command = #parsed_command
      local params = string.sub(cmd, string.len(cmda) + 1)
      for line in f:lines() do
        Print_to_Log(1, "checking line " .. line)
        if (line:match(cmda)) then
          Print_to_Log(0, Sprintf("->run bash command %s %s %s", line, SendTo, params))
          -- run bash script and collect returned text.
          local handle = io.popen(BotBashScriptPath .. line .. " " .. SendTo .. " " .. params)
          text = handle:read("*a")
          handle:close()
          -- ensure the text isn't nil
          text = text or ""
          -- only get the last 400 characters to avoid generating many messages when something is wrong
          text = text:sub(-400)
          -- remove ending CR LF
          text = text:gsub("[\n\r]$", "")
          Print_to_Log(1, "returned text=" .. text)
          -- default to "done"when no text is returned as it use to be.
          if text == "" then
            text = "done."
          end
          found = true
        end
      end
    end
    -- try dtgmenu as final resort in case we're out of sync
    if (not found) and Persistent.UseDTGMenu == 0 and chat_type ~= "channel" then
      Print_to_Log(0, Sprintf("-> forward to dtgmenu as last resort :%s", cmd))
      command_dispatch = Available_Commands["dtgmenu"] or {handler = {}}
      found, text, replymarkup = command_dispatch.handler(parsed_command, SendTo, cmd)
    end
  end
  --~ replymarkup
  if (replymarkup == nil or replymarkup == "") and savereplymarkup then
    -- restore the menu supplied replymarkup in case the shelled LUA didn't provide one
    replymarkup = savereplymarkup or ""
    Print_to_Log(1, "restored previous replymarkup:" .. replymarkup)
  elseif (replymarkup == "remove") then
    replymarkup = ""
  end
  ---------------------------------------------------------------------------------
  -- return when not found
  if not found then
    return "", "not found"
  end

  text = text or ""
  -- send the response to the sender
  if text ~= "" then
    -- send multiple message when larger than 4000 characters
    while string.len(text) > 0 do
      if Group ~= "" then
        Telegram_SendMessage(Group, string.sub(text, 1, 4000), MessageId, replymarkup, chat_type, handled_by)
      else
        Telegram_SendMessage(SendTo, string.sub(text, 1, 4000), MessageId, replymarkup, chat_type, handled_by)
      end
      text = string.sub(text, 4000, -1)
    end
  elseif replymarkup ~= savereplymarkup or chat_type == "callback" then
    -- Set msg text for normal messages to send the replymarkup
    if chat_type ~= "callback" or text == "" then
      text = "done"
    end
    if Group ~= "" then
      Telegram_SendMessage(Group, text, MessageId, replymarkup, chat_type, handled_by)
    else
      Telegram_SendMessage(SendTo, text, MessageId, replymarkup, chat_type, handled_by)
    end
  end
  return "ok"
end

-- ==== Functions section =====================================================================================
-- simulate sprintf for easy string formatting
Sprintf = function(s, ...)
  return s:format(...)
end

-- Format string variable
local function ExportString(s)
  return string.format("%q", s)
end

---------------------------------------------------------
-- loads get environment variable and prints in log
function DomoticzData(envvar)
  local var = os.getenv(envvar) or " not found check /etc/profile.d/DomoticzData.sh"
  Print_to_Log(0, envvar .. ": " .. var)
  return var
end

---------------------------------------------------------
-- print to log with time and date
function Print_to_Log(loglevel, logmessage, ...)
  -- handle calls without loglevel and assume 0: Print_to_Log(message)
  if tonumber(loglevel) == nil or logmessage == nil then
    logmessage = loglevel
    loglevel = 0
  end
  local msgprev = ""
  -- check if from dtgmenu and use dtgmenuLogLevel in stead of  DtgBotLogLevel
  -- get calling func debug.getinfo(1, "n").source
  for i = 2, 3, 1 do
    if debug.getinfo(i) == nil then
      break
    end
    --print(debug.getinfo(i).source)
    -- check the stack if the logmessage is from dtgmenu
    if debug.getinfo(i).source:find("dtgmenu") ~= nil then
      loglevel = loglevel + 10
      msgprev = " dtgmenu:"
      break
    end
  end
  loglevel = tonumber(loglevel) or 0
  logmessage = logmessage or ""

  if (loglevel <= (DtgBotLogLevel or 0)) then
    logcount = #{...}
    if logcount > 0 then
      for i, v in pairs({...}) do
        if type(v) == "table" then
          for i2, v2 in pairs({...}) do
            if type(v2) ~= "table" then
              logmessage = logmessage .. " [" .. i2 .. "] " .. (tostring(v2) or "nil")
            end
          end
        else
          logmessage = logmessage .. " (" .. i .. ") " .. (tostring(v) or "nil")
        end
      end
      --logmessage = logmessage:gsub(" (.+) nil", "")   --  Not sure why we added this ??
      logmessage = logmessage:gsub("[\r\n]", "")
    end

    local lvl2 = ""
    local lvl3 = ""
    if loglevel > 8 then
      -- Add stack info
      lvl2 = "-> * "
      if debug.getinfo(2) and debug.getinfo(2).name then
        --lvl2 = "->"..string.format("%-15s",debug.getinfo(2).name) .. ""
        lvl2 = "->"..debug.getinfo(2).name .. " "
      end
      lvl3 = "-> * "
      if debug.getinfo(3) and debug.getinfo(3).name then
        --lvl3 = "->"..string.format("%-15s",debug.getinfo(3).name) .. ""
        lvl3 = "->"..debug.getinfo(3).name .. " "
      end
    end
    -- print message to console
    print(Sprintf("%s %s: %s %s", os.date("%Y-%m-%d %H:%M:%S"), lvl3 .. lvl2, msgprev, logmessage))
  end
end

---------------------------------------------------------
-- GetUrl to set protocol and timeout
function GetUrl(url)
  local resp = {}
  HTTPS.TIMEOUT = (Telegram_Longpoll_TimeOut or 30) + 20 -- set the request timeout to 20 secs longer than the longpoll timeout.
  local r, returncode, h, s =
    HTTPS.request {
    url = url,
    sink = ltn12.sink.table(resp),
    protocol = "tlsv1_2"
  }
  returncode = returncode or 9999
  local response = ""
  -- read response table records and make them one string
  for i = 1, #resp do
    response = response .. resp[i]
  end
  return response, returncode
end

---------------------------------------------------------
-- Add / at the end of the path
function AddEndingSlash(envpath)
  if string.sub(envpath, -1, -1) ~= "/" then
    envpath = envpath .. "/"
  end
  return envpath
end

---------------------------------------------------------
-- FileExists check
function FileExists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

---------------------------------------------------------
--  Table functions
---------------------------------------------------------
--// The Save Function
function TableSaveToFile(tbl, tblname)
  local charS, charE = "   ", "\n"
  local filename = ScriptDirectory .. tblname .. ".tbl"
  local file, err = io.open(filename, "wb")
  if err then
    return err
  end

  -- initiate variables for save procedure
  local tables, lookup = {tbl}, {[tbl] = 1}
  file:write("return {" .. charE)

  for idx, t in ipairs(tables) do
    file:write("-- Table: {" .. idx .. "}" .. charE)
    file:write("{" .. charE)
    local thandled = {}

    for i, v in ipairs(t) do
      thandled[i] = true
      local stype = type(v)
      -- only handle value
      if stype == "table" then
        if not lookup[v] then
          table.insert(tables, v)
          lookup[v] = #tables
        end
        file:write(charS .. "{" .. lookup[v] .. "}," .. charE)
      elseif stype == "string" then
        file:write(charS .. ExportString(v) .. "," .. charE)
      elseif stype == "number" then
        file:write(charS .. tostring(v) .. "," .. charE)
      end
    end

    for i, v in pairs(t) do
      -- escape handled values
      if (not thandled[i]) then
        local str = ""
        local stype = type(i)
        -- handle index
        if stype == "table" then
          if not lookup[i] then
            table.insert(tables, i)
            lookup[i] = #tables
          end
          str = charS .. "[{" .. lookup[i] .. "}]="
        elseif stype == "string" then
          str = charS .. "[" .. ExportString(i) .. "]="
        elseif stype == "number" then
          str = charS .. "[" .. tostring(i) .. "]="
        end

        if str ~= "" then
          stype = type(v)
          -- handle value
          if stype == "table" then
            if not lookup[v] then
              table.insert(tables, v)
              lookup[v] = #tables
            end
            file:write(str .. "{" .. lookup[v] .. "}," .. charE)
          elseif stype == "string" then
            file:write(str .. ExportString(v) .. "," .. charE)
          elseif stype == "number" then
            file:write(str .. tostring(v) .. "," .. charE)
          end
        end
      end
    end
    file:write("}," .. charE)
  end
  file:write("}")
  file:close()
end

---------------------------------------------------------
--// The Load Function
function TableLoadFromFile(tblname)
  local filename = ScriptDirectory .. tblname .. ".tbl"
  local ftables, err = loadfile(filename)
  if err then
    return nil, err
  end
  local tables = ftables()
  for idx = 1, #tables do
    local tolinki = {}
    for i, v in pairs(tables[idx]) do
      if type(v) == "table" then
        tables[idx][i] = tables[v[1]]
      end
      if type(i) == "table" and tables[i[1]] then
        table.insert(tolinki, {i, tables[i[1]]})
      end
    end
    -- link indices
    for _, v in ipairs(tolinki) do
      tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
    end
  end
  return tables[1]
end

---------------------------------------------------------
-- ### Not Used at this moment
-- print table to log for debugging
function TablePrintToLog(t, tab, lookup)
  lookup = lookup or {[t] = 1}
  tab = tab or ""
  for i, v in pairs(t) do
    Print_to_Log(1, tab .. tostring(i), v)
    if type(i) == "table" and not lookup[i] then
      lookup[i] = 1
      Print_to_Log(1, tab .. "Table: i")
      TablePrintToLog(i, tab .. "\t", lookup)
    end
    if type(v) == "table" and not lookup[v] then
      lookup[v] = 1
      Print_to_Log(1, tab .. "Table: v")
      TablePrintToLog(v, tab .. "\t", lookup)
    end
  end
end

---------------------------------------------------------
-- ### Not Used at this moment
-- Var dump to logfile for debugging
function VarDumpToLog(value, depth, key)
  local linePrefix = ""
  local spaces = ""

  if key ~= nil then
    linePrefix = "[" .. key .. "] = "
  end

  if depth == nil then
    depth = 0
  else
    depth = depth + 1
    for i = 1, depth do
      spaces = spaces .. "  "
    end
  end

  if type(value) == "table" then
    mTable = getmetatable(value)
    if mTable == nil then
      Print_to_Log(1, spaces .. linePrefix .. "(table) ")
    else
      Print_to_Log(1, spaces .. "(metatable) ")
      value = mTable
    end
    for tableKey, tableValue in pairs(value) do
      VarDumpToLog(tableValue, depth, tableKey)
    end
  elseif type(value) == "function" or type(value) == "thread" or type(value) == "userdata" or value == nil then
    Print_to_Log(1, spaces .. tostring(value))
  else
    Print_to_Log(1, spaces .. linePrefix .. "(" .. type(value) .. ") " .. tostring(value))
  end
end

---------------------------------------------------------
-- Original XMPP function to list device properties
function List_Device_Attr(dev, mode)
  local result = ""
  local exclude_flag
  -- Don't dump these fields as they are boring. Name data and idx appear anyway to exclude them
  local exclude_fields = {"Name", "Data", "idx", "SignalLevel", "CustomImage", "Favorite", "HardwareID", "HardwareName", "HaveDimmer", "HaveGroupCmd", "HaveTimeout", "Image", "IsSubDevice", "Notifications", "PlanID", "Protected", "ShowNotifications", "StrParam1", "StrParam2", "SubType", "SwitchType", "SwitchTypeVal", "Timers", "TypeImg", "Unit", "Used", "UsedByCamera", "XOffset", "YOffset"}
  result = "<" .. dev.Name .. ">, Data: " .. dev.Data .. ", Idx: " .. dev.idx
  if mode == "full" then
    for k, v in pairs(dev) do
      exclude_flag = 0
      for i, k1 in ipairs(exclude_fields) do
        if k1 == k then
          exclude_flag = 1
          break
        end
      end
      if exclude_flag == 0 then
        result = result .. k .. "=" .. tostring(v) .. ", "
      else
        exclude_flag = 0
      end
    end
  end
  return result
end

---------------------------------------------------------
-- Load all Modules and report any errors without failing
function Load_LUA_Modules()
  if Command_Modules == nil then
    Print_to_Log(0, "!!! warning: Command_Modules is empty.")
    return
  end
  Print_to_Log(0, "Loading command modules...")
  for i, m in ipairs(Command_Modules) do
    local result_status, result = xpcall(Load_LUA_Module, ErrorHandler, m)
    if not result_status then
      Print_to_Log(0, Sprintf("!! Module %s failed to load, so won't be available until a 'reloadmodules' command:\nError:%s\n%s", m, result[1], result[2]))
    else
      Print_to_Log(0, " -module->" .. m .. "  commands:" .. result)
    end
  end
  -- check if dtgmenu.lua loaded succesfully
  if Available_Commands["dtgmenu"] ~= nil then
    -- Initialise and populate dtgmenu tables in case the menu is switched on
    Persistent.UseDTGMenu = tonumber(Persistent.UseDTGMenu) or 0
    Print_to_Log(0, Sprintf("Menu restored state %s (0=disabled;1=enabled)", Persistent.UseDTGMenu))
    MsgInfo = MsgInfo or {}
    -- initialise menu tables
    PopulateMenuTab(1, "")
  end
end

---------------------------------------------------------
-- load the individual module
function Load_LUA_Module(mName)
  local result = ""
  local t = assert(loadfile(BotLuaScriptPath .. mName .. ".lua"))()
  local cl = t:get_commands()
  for c, r in pairs(cl) do
    result = result .. c .. ","
    Available_Commands[c] = r
  end
  return result
end

---------------------------------------------------------
-- allow for variables to be saved/restored
function Save_Persistent_Vars()
  -- save all persistent variables to file
  Print_to_Log(1, Sprintf("Persistent.UseDTGMenu=%s", Persistent.UseDTGMenu))
  TableSaveToFile(Persistent or {}, "dtgbot_persistent")
end

---------------------------------------------------------
-- ### Not Used at this moment
-- Calculate the timestamp difference in seconds with current time
function TimeDiff(s)
  year = string.sub(s, 1, 4)
  month = string.sub(s, 6, 7)
  day = string.sub(s, 9, 10)
  hour = string.sub(s, 12, 13)
  minutes = string.sub(s, 15, 16)
  seconds = string.sub(s, 18, 19)
  t1 = os.time()
  t2 = os.time {year = year, month = month, day = day, hour = hour, min = minutes, sec = seconds}
  difference = os.difftime(t1, t2)
  return difference
end

---------------------------------------------------------
-- Url Encode
function Url_Encode(str)
  if (str) then
    str = string.gsub(str, "\n", "\r\n")
    str =
      string.gsub(
      str,
      "([^%w %-%_%.%~])",
      function(c)
        return string.format("%%%02X", string.byte(c))
      end
    )
    str = string.gsub(str, " ", "+")
  end
  return str
end

---------------------------------------------------------
-- Check if ID is WHiteListed so allowed to send commands
function ID_WhiteList_Check(SendTo)
  --Check if whitelist empty then let any message through
  if WhiteList == nil then
    return true
  else
    SendTo = tostring(SendTo)
    --Check id against whitelist
    for i = 1, #WhiteList do
      Print_to_Log(1, "WhiteList: " .. WhiteList[i])
      if SendTo == WhiteList[i] then
        return true
      end
    end
    -- Checked WhiteList no match
    Print_to_Log(0, "Not on WhiteList: " .. SendTo)
    return false
  end
end

-- ====  Telegram functions ================================================================
---------------------------------------------------------
-- Send Message to Telegram
function Telegram_SendMessage(SendTo, Message, MessageId, replymarkup, chat_type, handled_by)
  chat_type = chat_type or ""
  replymarkup = replymarkup or ""
  Message = Message or ""
  Print_to_Log(1, "chat_type:" .. chat_type)
  Print_to_Log(1, "replymarkup:" .. replymarkup)
  local response, status
  -- Process callback messages
  if chat_type == "callback" then
    if replymarkup == nil or replymarkup == "" then
      replymarkup = "&reply_markup="
    else
      replymarkup = "&reply_markup=" .. Url_Encode(replymarkup)
    end
    -- Delete option for message with inline keyboard
    if Message == "remove" then
      Print_to_Log(1, Telegram_Url .. "deleteMessage?chat_id=" .. SendTo .. "&message_id=" .. MessageId)
      response, status = GetUrl(Telegram_Url .. "deleteMessage?chat_id=" .. SendTo .. "&message_id=" .. MessageId)
    else
      -- rebuild new message with inlinemenu when the old message can't be updated
      Print_to_Log(1, Telegram_Url .. "editMessageText?chat_id=" .. SendTo .. "&message_id=" .. MessageId .. "&text=" .. Url_Encode(Message) .. replymarkup)
      response, status = GetUrl(Telegram_Url .. "editMessageText?chat_id=" .. SendTo .. "&message_id=" .. MessageId .. "&text=" .. Url_Encode(Message) .. replymarkup)
    end
    if status == 400 and string.find(response, "Message can't be edited") then
      Print_to_Log(3, status .. "<== ", response)
      Print_to_Log(3, "==> /sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Message .. replymarkup)
      response, status = GetUrl(Telegram_Url .. "sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Url_Encode(Message) .. replymarkup)
    end
  else
    -- Process other messages
    if chat_type == "channel" then
      -- channel messages don't support menus
      replymarkup = ""
    end
    if replymarkup == nil or replymarkup == "" then
      Print_to_Log(1, Telegram_Url .. "sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Url_Encode(Message))
      response, status = GetUrl(Telegram_Url .. "sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Url_Encode(Message))
    else
      Print_to_Log(1, Telegram_Url .. "sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Url_Encode(Message) .. "&reply_markup=" .. Url_Encode(replymarkup))
      response, status = GetUrl(Telegram_Url .. "sendMessage?chat_id=" .. SendTo .. "&reply_to_message_id=" .. MessageId .. "&text=" .. Url_Encode(Message) .. "&reply_markup=" .. Url_Encode(replymarkup))
    end
    Print_to_Log(0, Sprintf("Message sent. status=%s", status))
    Print_to_Log(1, Sprintf("response=%s", response))
    if status == 200 then
      local decoded_response = JSON.decode(response or {result = {}})
      if decoded_response.result ~= nil and decoded_response.result.message_id ~= nil then
        Telegram_CleanMessages(SendTo, decoded_response.result.message_id, MessageId, handled_by, false)
        Print_to_Log(1, Sprintf("Persistent.UseDTGMenu=%s", Persistent.UseDTGMenu))
        Print_to_Log(1, Sprintf("Persistent.iLastcommand=%s", Persistent.iLastcommand))
        if Persistent.UseDTGMenu == 1 and Persistent.iLastcommand == "menu" then
          Persistent.LastInlinemessage_id = decoded_response.result.message_id
          Print_to_Log(1, Sprintf("save Persistent.LastInlinemessage_id=%s", Persistent.LastInlinemessage_id))
          Persistent.iLastcommand = ""
        end
      end
    end
    return
  end
end
-------------------------------------------------------------------------
-- Save current message ID's and clean up previous messages when defined
function Telegram_CleanMessages(From_Id, nsmsgid, nrmsgid, handled_by, remAll)
  remAll = remAll or false
  handled_by = handled_by or ""
  MenuMessagesMaxShown = tonumber(MenuMessagesMaxShown)
  -- do not save or delete messages when MenuMessagesMaxShown = 0
  Print_to_Log(1, Sprintf("===CleanMessage handled_by:%s remAll=%s", handled_by, remAll))
  if ((MenuMessagesMaxShown or 0) == 0 and handled_by == "menu") or ((OtherMessagesMaxShown or 0) == 0 and handled_by ~= "menu") then
    if handled_by ~= "" then
      Print_to_Log(0, Sprintf("---CleanMessage handled_by:%s", handled_by))
    end
    return
  end
  MsgInfo = TableLoadFromFile("dtgbot_msginfo")
  if MsgInfo == nil then
    MsgInfo = {}
  end
  if MsgInfo[From_Id] == nil then
    MsgInfo[From_Id] = {}
  end

  -- get the message table for the current Sender ID
  Old_Messages = MsgInfo[From_Id]

  -- remove old messages
  while (#Old_Messages >= MenuMessagesMaxShown) or remAll do
    -- break when table is empty
    if #Old_Messages == 0 then
      break
    end
    -- get first table entry en remove from table.
    local cmsg = table.remove(Old_Messages, 1)
    Telegram_Remove_Message(From_Id, cmsg.smsgid)
    Telegram_Remove_Message(From_Id, cmsg.rmsgid)
  end
  -- _cleanall: also the send command to totally clean all messages
  if remAll then
    Telegram_Remove_Message(From_Id, nsmsgid)
  else
    -- add the latest message to table
    if ((nrmsgid or 0) ~= 0 and (nsmsgid or 0) ~= 0) then
      Print_to_Log(0, Sprintf("Current %s.Add messages to table for %s: %s - %s", #Old_Messages, From_Id, nrmsgid, nsmsgid))
      table.insert(Old_Messages, {smsgid = nsmsgid, rmsgid = nrmsgid})
    end
  end
  TableSaveToFile(MsgInfo, "dtgbot_msginfo")
end

function Telegram_Remove_Message(SendTo, MessageId)
  Print_to_Log(2, Sprintf("Delete MessageId:%s for SendTo:%s",MessageId,SendTo))
  if (tonumber(SendTo) or 0) == 0 or (tonumber(MessageId) or 0) == 0 then
    return
  end
  -- Remove requested MsgId
  local response, status = GetUrl(Telegram_Url .. "deleteMessage?chat_id=" .. SendTo .. "&message_id=" .. MessageId)
  -- update MsgTime when update is successful
  local decoded_response = JSON.decode(response or {result = {}})
  if status == 200 then
    Print_to_Log(0, Sprintf("Message %s deleted.", MessageId))
  else
    Print_to_Log(0, Sprintf("!!! Message %s not deleted! %s", MessageId, (decoded_response.description or response)))
  end
end
