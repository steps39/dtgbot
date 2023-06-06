--[[
-----------------------------------------------------------------------
--This script handles inline-keyboard responses when replies are send to dtgbot
  on messages coded like the below examples (send by any process):
    Basic example on/off switch:
    https://api.telegram.org/bot123456890:aaa...xxx/sendMessage?chat_id=123456789&text=actions for DeviceName
          &reply_markup={"inline_keyboard":[[{"text":"On","callback_data":"inlineaction DeviceName on"},
                                            {"text":"Off","callback_data":"inlineaction DeviceName off"},
                                            {"text":"remove","callback_data":"inlineaction DeviceName remove"}
                                            ] ] }
    Example of a dimmer
    https://api.telegram.org/bot123456890:aaa...xxx/sendMessage?chat_id=123456789&text=actions for DeviceName
          &reply_markup={"inline_keyboard":[[{"text":"Aan","callback_data":"inlineaction DeviceName on"},
                                            {"text":"25%","callback_data":"inlineaction DeviceName set level 25"},
                                            {"text":"50%","callback_data":"inlineaction DeviceName set level 50"},
                                            {"text":"75%","callback_data":"inlineaction DeviceName set level 75"},
                                            {"text":"Uit","callback_data":"inlineaction DeviceName off"},
                                            {"text":"exit","callback_data":"inlineaction DeviceName exit"},
                                            {"text":"remove","callback_data":"inlineaction DeviceName remove"}
                                            ] ] }
  Callback_Data format: inlineaction DomoticzDeviceName Action
  Action can be On/Off/Set level xx
  Action exit   -> remove the inline menu with closing message
  Action remove -> remove the whole message with keyboard.
  Add /silent at the end to perform the action without any response text
]]
local inlineaction = {}
local http = require "socket.http"
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

-- process the received command by DTGBOT
local function perform_action(parsed_cli, SendTo, MessageId, org_replymarkup)
  local DeviceName = ""
  local action = ""
  local status, response, replymarkup
  -- loop through the parsed commandline information
  for x, param in pairs(parsed_cli) do
    Print_to_Log(2, "command parameter " .. x .. "=" .. param)
    if x == 1 then
      -- "stuff" Used for other purposes
    elseif x == 2 then
      -- the "inlineaction" command
    elseif x == 3 then
      DeviceName = param
    elseif x == 4 then
      action = param
    else
      action = action .. " " .. param
    end
  end

  -- check for the /silent option
  local silent = false
  local saction = action .. " "
  local taction = saction:gsub("([ ]-/silent[ ]+)","")
  taction = taction:gsub("([ ])$","")
  if action ~= taction then
    silent = true
    action = taction
  end

  -- remove keyboard when exit is defined as action
  if action == "exit" then
    response = DeviceName .. " done." --
    replymarkup = "remove"
    if silent then
      response = ""
    end
    return 1, response, replymarkup
  end
  -- remove message and keyboard when remove is defined as action
  if action == "remove" then
    response = "remove"
    replymarkup = "remove"
    return 1, response, replymarkup
  end
  -- process the action
  response = ""
  replymarkup = org_replymarkup -- set markup to the same as the original
  status = 1
  Print_to_Log(1, "SendTo:" .. SendTo)
  Print_to_Log(1, "MessageId:" .. MessageId)
  Print_to_Log(1, "DeviceName:" .. DeviceName)
  Print_to_Log(1, "action:" .. action)
  if silent then
    Print_to_Log(1, "/silent active")
  end
    -- Check if DeviceName is a known domoticz device
  switchtype = "light"
  DeviceID = Domo_Idx_From_Name(DeviceName, "devices")
  if DeviceID == nil then
    -- Its not a device so check if a scene
    DeviceID = Domo_Idx_From_Name(DeviceName, "scenes")
    switchtype = "scenes"
  end
  -- process the action when either a device or a scene
  if DeviceID ~= nil then
    -- Now switch the device or scene when it exists
    response = Domo_sSwitchName(DeviceName, switchtype, switchtype, DeviceID, action)
    Print_to_Log(0, "perform action on Device " .. DeviceName .. "=>" .. action .. "  response:" .. response)
  else
    response = "" .. DeviceName .. " is unknown."
  end
  -- remove info when /silent is provided as parameter > 3
  if silent then
    response = ""
    replymarkup = ""
  end
  --
  return status, response, replymarkup
end

function inlineaction.handler(parsed_cli, SendTo, MessageId)
  return perform_action(parsed_cli, SendTo, MessageId)
end

local inlineaction_commands = {
  ["inlineaction"] = {handler = inlineaction.handler, description = "inline action - handle actions from inline-keyboard"}
}

function inlineaction.get_commands()
  return inlineaction_commands
end

return inlineaction
