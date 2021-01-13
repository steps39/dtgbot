--[[
  Version 0.9 20210113
  Automation bot framework for telegram to control Domoticz
  dtgbot.lua does not require any customisation (see below)
  and does not require any telegram client to be installed
  all communication is via authenticated https
  Extra functions can be added by replicating list.lua,
  replacing list with the name of your new command see list.lua
  Based on test.lua from telegram-cli from
  Adapted to abstract functions into external files using
  the framework of the XMPP bot, so allowing functions to
  shared between the two bots.
]]
-- -------------------------------------------------------
-- set default loglevel which will be retrieve later from the domoticz user variable TelegramBotLoglevel
-- the first digit sets the DTGBOT loglevel - default 0
-- the seconf digit sets the DTGMENU loglevel - default 0
DtgBotLogLevel = 1
Telegram_Longpoll_TimeOut = 50 -- used to set the max wait time for both the longpoll and the HTTPS
-----------------------------------------------------------
-- Function to handle the HardErrors
--   returns the error and callstack in 2 parameter table
function ErrorHandler(x)
  return {x, debug.traceback()}
end

-- ###################################################################
-- Initialization process
-- ###################################################################
local return_status, result =
  xpcall(
  function()
    --------------------------------------------------------------------------------
    -- get the current script directory from commandline
    local str = debug.getinfo(1, "S").source:sub(2)
    -- and default to current (./) in case not retrieved
    ScriptDirectory = (str:match("(.*[/\\])") or "./")
    --  and add to the packages search path
    package.path = ScriptDirectory .. "?.lua;" .. ScriptDirectory .. "?.cfg;" .. package.path
    --------------------------------------------------------------------------------
    -- Load required files
    HTTP = require "socket.http" --lua-sockets
    SOCKET = require "socket" --lua-sockets
    HTTPS = require "ssl.https" --lua-sockets
    JSON = require "json" -- lua-sec
    MIME = require("mime") -- ???
    --------------------------------------------------------------------------------
    -- dtgbot Lua libraries
    --------------------------------------------------------------------------------
    -- Load All general Main functions
    require("dtg_main_functions")
    require("dtg_domoticz")

    -- All these values are set in /etc/profile.d/DomoticzData.sh
    TelegramBotToken = DomoticzData("TelegramBotToken")
    DomoticzIP = DomoticzData("DomoticzIP")
    DomoticzPort = DomoticzData("DomoticzPort")
    TempFileDir = DomoticzData("TempFileDir")
    BotHomePath = ScriptDirectory ---  Obsolete? -> DomoticzData("BotHomePath")
    BotLuaScriptPath = AddEndingSlash(DomoticzData("BotLuaScriptPath"))
    BotBashScriptPath = AddEndingSlash(DomoticzData("BotBashScriptPath"))
    MenuMessagesMaxShown = MenuMessagesMaxShown or 0

    -- get any persistent variable values
    Persistent = TableLoadFromFile("dtgbot_persistent") or {}
    --------------------------------------------------------------------------------
    -- Load the configuration file this file contains the list of commands
    -- used to define the external files with the command function to load.
    --------------------------------------------------------------------------------
    if (FileExists(ScriptDirectory .. "dtgbot-user.cfg")) then
      assert(loadfile(ScriptDirectory .. "dtgbot-user.cfg"))()
      Print_to_Log(0, "Using DTGBOT config file:" .. ScriptDirectory .. "dtgbot-user.cfg")
    else
      assert(loadfile(ScriptDirectory .. "dtgbot.cfg"))()
      Print_to_Log(0, "Using DTGBOT config file:" .. ScriptDirectory .. "dtgbot.cfg")
    end

    -- Array to store device list rapid access via index number
    StoredType = "None"
    StoredList = {}

    -- Table to store functions for commands plus descriptions used by help function
    Available_Commands = {}

    -- Constants derived from environment variables
    Domoticz_Url = "http://" .. DomoticzIP .. ":" .. DomoticzPort
    Telegram_Url = "https://api.telegram.org/bot" .. TelegramBotToken .. "/"
    UserScriptPath = BotBashScriptPath
  end,
  ErrorHandler
)
if not return_status then
  -- Terminate the process as the Initialisation part needs to be successfull for dtgbot to work.
  -- Try to log the hard error to logfile when function is available.
  -- Then end with an Hard Error.
  print("\n### Initialialisation process Failed:\nError-->" .. (result[1] or "") .. (result[2] or ""))
  error("Terminate DTGBOT as the initialisation failed, which frst needs to be fixed.")
end
-- ###################################################################
-- Main process start
-- ###################################################################
local return_status, result =
  xpcall(
  function()
    Print_to_Log(0, "------------------------------------------------------")
    Print_to_Log(0, "### Starting dtgbot - Telegram api Bot message handler")
    Print_to_Log(0, "------------------------------------------------------")

    -- initialise tables
    DtgBot_Initialise()

    -- Get the updates
    local telegram_connected = false
    -- initialise to 0 to get the first new message
    local status = 999
    local response = ""
    local decoded_response
    local reloadmodules = false
    -- ===========================================================================================================
    -- closed loop to retrieve Telegram messages while service is running
    -- ===========================================================================================================
    Print_to_Log(0, "-------------------------------------------")
    Print_to_Log(0, "### Starting longpoll with Telegram servers")
    Print_to_Log(0, "-------------------------------------------")
    while FileExists(dtgbot_pid) do
      -- loop till messages is received
      while true do
        -- Update monitorfile each loop
        os.execute("echo " .. os.date("%Y-%m-%d %H:%M:%S") .. " > " .. TempFileDir .. "/dtgloop.txt")
        -----------------------------------------------------------------------------------------------------------
        --> Start LongPoll to Telegram wrapper in it's own error checking routine
        local return_status, result =
          xpcall(
          function()
            local url = Sprintf("%sgetUpdates?timeout=%s&limit=1&offset=%s", Telegram_Url, (Telegram_Longpoll_TimeOut or "30"), TelegramBotOffset)
            Print_to_Log(1, url)
            response, status = GetUrl(url)
          end,
          ErrorHandler
        )
        if not return_status then
          (Print_to_Log or print)("\n### Get Telegram Failed, we will just retry:\nError-->" .. (result[1] or ""))
          os.execute("sleep 2")
          status = 999
        else
          Print_to_Log(1, Sprintf("Longpoll ended with status:%s response:%s", status, result))
        end
        --< End LongPoll to Telegram wrapper
        -------------------------------------------------------------------------------------
        if status == 200 then
          if not telegram_connected then
            Print_to_Log(0, "### In contact with Telegram servers")
            telegram_connected = true
          end
          Print_to_Log(1, "Telegram response", response)
          -- check if there is a message or just a timeout with empty response
          decoded_response = JSON.decode(response or {result = {}})
          if decoded_response["result"][1] ~= nil and decoded_response["result"][1]["update_id"] ~= nil then
            -- contains data so exit while to continue to process
            break
          end
          io.write(".")
        else
          -- status <> 200 ==> error?
          io.write("!")
          if telegram_connected then
            Print_to_Log(0, Sprintf("\n### Lost contact with Telegram servers, received Non 200 status:%s", status))
            telegram_connected = false
          end
          -- pause a little on failure
          os.execute("sleep 2")
          response = ""
        end
        io.flush()
      end
      io.write("\n")
      -------------------------------------------------------------------------------------
      --> Get current update_id and set +1 for the next one to get.
      local tt = decoded_response["result"][1] or {}
      Print_to_Log(1, "update_id ", tt.update_id)
      -- set next msgid we want to receive
      TelegramBotOffset = tt.update_id + 1
      Print_to_Log(1, "TelegramBotOffset " .. TelegramBotOffset)
      -- reload modules in case a command failure happened so you can update the modules without a dtgbot restart
      if reloadmodules then
        Available_Commands = {}
        Load_LUA_Modules()
        reloadmodules = false
      end

      -->> Start processing message and capture any errors to avoid hardcrash
      Print_to_Log(0, Sprintf("=> Start Msg process for update_id %s", tt.update_id))
      local result_status, result, result_err = xpcall(PreProcess_Received_Message, ErrorHandler, tt)
      if not result_status then
        -- HardError encountered so reporting the information
        -- reload LUA modules so they can be updated without restarting the service
        Print_to_Log(0, Sprintf("<- !!! Msg process hard failed: \nError:%s\n%s", result[1], result[2]))
        reloadmodules = true
      else
        -- No Hard Errors, so check for second retuned param which is used for internal errors
        if (result_err or "") ~= "" then
          Print_to_Log(0, Sprintf("<- !!! Msg process failed:%s %s", result, result_err))
          reloadmodules = true
        else
          Print_to_Log(0, Sprintf("<= Msg processed: %s", result))
        end
      end
      -- save the persistent variables afer each message processed
      Save_Persistent_Vars()
      --<< End processing message
    end
    Print_to_Log(0, dtgbot_pid .. " does not exist, so exiting")
  end,
  ErrorHandler
)
if not return_status then
  (Print_to_Log or error)("\n### Main process Failed:\nError-->" .. (result[1] or "") .. (result[2] or ""))
end
