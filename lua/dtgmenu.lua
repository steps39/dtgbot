-- =====================================================================================================================
-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in DTGMENU.CFG. Open the file for descript of the details.
--
-- programmer: Jos van der Zande
-- Version 0.901 20221127
-- =====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
-- these are the different formats of reply_markup. looksimple but needed a lot of testing before it worked :)
--
-- >show the custom keyboard and stay up after option selection first 3 on the first line and menu on the second
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]]}
-- >show the custom keyboard and minimises after option selection
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"one_time_keyboard":true}
-- >Remove the custom keyboard
--old	reply_markup={"hide_keyboard":true}
--new  reply_markup={"remove_keyboard":true}
--old	reply_markup={"hide_keyboard":true,"selective":false}
-- >force normal keyboard to ask for input
--	reply_markup={"force_reply":true}
--	reply_markup={"force_reply":true,"selective":false}
-- >Resize the keyboard
--	reply_markup={"keyboard":[["menu"]],"resize_keyboard":true}
--  reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"resize_keyboard":true}
--// ExportString( string )
--// returns a "Lua" portable version of the string
--------------------------------------
-- Include config
--------------------------------------
local config = ""
-- save current menu type
saveUseInlineMenu = UseInlineMenu

if (FileExists(BotHomePath .. "dtgbot-user.cfg")) then
  config = assert(loadfile(BotHomePath .. "lua/dtgmenu-user.cfg"))()
  Print_to_Log("Using DTGMENU config file:" .. BotHomePath .. "lua/dtgmenu-user.cfg")
else
  config = assert(loadfile(BotHomePath .. "lua/dtgmenu.cfg"))()
  Print_to_Log("Using DTGMENU config file:" .. BotHomePath .. "lua/dtgmenu.cfg")
end
-- override config with the last used menu type when set. This happens with reloadconfig or modules

if saveUseInlineMenu then
	UseInlineMenu=saveUseInlineMenu
end

local http = require "socket.http"
DTGil = require("dtgmenuinline")
DTGbo = require("dtgmenubottom")

-- definition used by DTGBOT
DTGMenu_Modules = {}  -- global!
menu_language = Language

-- If Domoticz Language is not used then revert to English
if dtgmenu_lang[menu_language] == nil then
  Print_to_Log("Domoticz Language is not available for dtgmenus. Using English.")
  menu_language = "en"
end

-- table to save the last commands done via dtgmenu. this is saved and loaded from a file
LastCommand = Persistent.LastCommand or {}

-------------------------------------------------------------------------------
-- Start Functions to SORT the TABLE
-- Copied from internet location: -- http://lua-users.org/wiki/SortedIteration
-- These are used to sort the items on the menu alphabetically
-------------------------------------------------------------------------------
-- declare local variables
function __genOrderedIndex(t)
  local orderedIndex = {}
  for key in pairs(t) do
    table.insert(orderedIndex, key)
  end
  table.sort(orderedIndex)
  return orderedIndex
end

function table.map_length(t)
  local c = 0
  for k, v in pairs(t) do
    c = c + 1
  end
  return c
end

function orderedNext(t, state)
  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.

  key = nil
  if state == nil then
    -- the first time, generate the index
    t.__orderedIndex = __genOrderedIndex(t)
    key = t.__orderedIndex[1]
  else
    -- fetch the next value
    for i = 1, table.map_length(t.__orderedIndex) do
      if t.__orderedIndex[i] == state then
        key = t.__orderedIndex[i + 1]
      end
    end
  end

  if key then
    return key, t[key]
  end

  -- no more value to return, cleanup
  t.__orderedIndex = nil
  return
end

function orderedPairs(t)
  -- Equivalent of the pairs() function on tables. Allows to iterate
  -- in order
  return orderedNext, t, nil
end
-------------------------------------------------------------------------------
-- END Functions to SORT the TABLE
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Start Function to set the new devicestatus. needs changing moving to on
-- Jos: Maybe we should create a general lua library because this does more than On/Off
--      It does now also dimmer and Thermostat settings.
--      I would like to see all generic functions in a separate include file with an brief description at the top of the
--      include file. This way there is no need to search for the available standard functions in different modules.
--      I haven't included the Thermonstat update in here as this is currrently a "Lighting 2" only function.
--      We could revamp this into supporting more Type's or just create a separate Function for that.
--      The Thermostat update is currently done in the Actions section of the logic
-------------------------------------------------------------------------------

-- Create a button per room.
function MakeRoomMenus(iLevel, iSubmenu)
  iSubmenu = tostring(iSubmenu)
  Print_to_Log(1, "Creating Room Menus:", iLevel, iSubmenu)
  room_number = 0

  ------------------------------------
  -- process all Rooms
  ------------------------------------
  for rname, rnumber in pairs(Roomlist) do
    room_name = rname
    room_number = rnumber
    local rbutton = room_name:gsub(" ", "_")
    --
    -- only get all details per Room in case we are not building the Mainmenu.
    -- Else
    --Group change    if iLevel ~= "mainmenu"
    --Group change    and iSubmenu == rbutton or "[scene] ".. iSubmenu == rbutton then
    -----------------------------------------------------------
    -- retrieve all devices/scenes for this plan from Domoticz
    -----------------------------------------------------------
    Devsinplan = Domo_Device_List("command&param=getplandevices&idx=" .. room_number)
    DIPresult = Devsinplan["result"]
    if DIPresult ~= nil then
      Print_to_Log(1, "For room " .. room_name .. "/".. room_number .." got some devices and/or scenes")
      dtgmenu_submenus[rbutton] = {RoomNumber = room_number, whitelist = "", showdevstatus = "y", buttons = {}}
      -----------------------------------------------------------
      -- process all found entries in the plan record
      -----------------------------------------------------------
      buttons = {}
      for d, DIPrecord in pairs(DIPresult) do
        if type(DIPrecord) == "table" then
          local DeviceType = "devices"
          local SwitchType
          local Type
          local status = ""
          local LevelNames = ""
          local MaxDimLevel = 100
          local idx = DIPrecord.devidx
          local name = DIPrecord.Name
          local DUMMY = {"result"}
          DUMMY["result"] = {}
          Print_to_Log(1, " - Plan record:", DIPrecord.Name, DIPrecord.devidx, DIPrecord.type)
          if DIPrecord.type == 1 then
            Print_to_Log(1, "--> scene record")
            idx, DeviceName, DeviceType, Type, SwitchType, MaxDimLevel, status = Domo_Devinfo_From_Name(idx, "", "scenes")
          else
            Print_to_Log(1, "--> device record")
            idx, DeviceName, DeviceType, Type, SwitchType, MaxDimLevel, status, LevelNames = Domo_Devinfo_From_Name(idx, "", "devices")
          end
          -- Remove the name of the room from the device if it is present and any susequent Space or Hyphen or undersciore
          button = string.gsub(DeviceName, room_name .. "[%s-_]*", "")
          -- But reinstate it if less than 3 letters are left
          if #button < 3 then
            button = DeviceName
          end
          -- Remove any spaces from the device name and replace them by underscore.
          button = string.gsub(button, "%s+", "_")
          -- Add * infront of button name when Scene or Group
          if DeviceType == "scenes" then
            button = "*" .. button
          end
          -- fill the button table records with all required fields
          buttons[button] = {}
          -- Retrieve id white list
          buttons[button].whitelist = "" -- Not implemented for Dynamic menu: Whitelist number(s) for this device, blank is ALL
          if LevelNames == "" or LevelNames == nil then
            buttons[button].actions = "" -- Not implemented for Dynamic menu: Hardcoded Actions for the device
          else
            buttons[button].actions = LevelNames:gsub("|", ",")
          end
          buttons[button].prompt = false -- Not implemented for Dynamic menu: Prompt TG client for the variable text
          buttons[button].showactions = false -- Not implemented for Dynamic menu: Show Device action menu right away when its menu is selected
          buttons[button].Name = DeviceName -- Original devicename needed to be able to perform the "Set new status" commands
          buttons[button].idx = idx
          buttons[button].DeviceType = DeviceType
          buttons[button].SwitchType = SwitchType
          buttons[button].Type = Type
          buttons[button].MaxDimLevel = MaxDimLevel -- Level required to calculate the percentage for devices that do not use 100 for 100%
          buttons[button].status = status
          Print_to_Log(1, " Dynamic ->", rbutton, button, DeviceName, idx, DeviceType, Type, SwitchType, MaxDimLevel, status)
        end
      end
    end
    --Group change    end
    -- Save the Room entry with optionally all its devices/sceens
    dtgmenu_submenus[rbutton] = {RoomNumber = room_number, whitelist = "", showdevstatus = "y", buttons = buttons}
  end
end
--
-----------------------------------------------
--- END population the table
-----------------------------------------------

-----------------------------------------------
--- Start Misc Function to support the process
-----------------------------------------------
-- get translation
function DTGMenu_translate_desc(Language, input, default)
  Language = Language or "en"
  input = input or "?"
  local response = default or input
  if (dtgmenu_lang[Language] == nil) then
    Print_to_Log(0, "  - Language not defined in config", Language)
  elseif (dtgmenu_lang[Language].text[input] == nil) then
    Print_to_Log(0, "  - Language keyword not defined in config:", Language, input)
  else
    response = dtgmenu_lang[Language].text[input]
  end
  return response
end

-- function to return a numeric value for a device status.
function status2number(switchstatus)
  -- translater the switchstatus to a number from 0-100
  switchstatus = tostring(switchstatus)
  Print_to_Log(2, "--> status2number Input switchstatus", switchstatus)
  if switchstatus == "Off" or switchstatus == "Open" then
    switchstatus = 0
  elseif switchstatus == "On" or switchstatus == "Closed" then
    switchstatus = 100
  else
    -- retrieve number from: "Set Level: 49 %"
    switchstatus = switchstatus:gsub("Set Level: ", "")
    switchstatus = switchstatus:gsub(" ", "")
    switchstatus = switchstatus:gsub("%%", "")
  end
  Print_to_Log(2, "--< status2number Returned switchstatus", switchstatus)
  return switchstatus
end
-- SCAN through provided delimited string for the second parameter
function ChkInTable(itab, idev)
  local cnt = 0
  if itab ~= nil then
    for dev in string.gmatch(itab, "[^|,]+") do
      cnt = cnt + 1
      if dev == idev then
        Print_to_Log(2, "-< ChkInTable found: " .. idev, cnt, itab)
        return true, cnt
      end
    end
  end
  Print_to_Log(2, "-< ChkInTable not found: " .. idev, cnt, itab)
  return false, 0
end

-- SCAN through provided delimited string for the second parameter
function getSelectorStatusLabel(itab, ival)
  Print_to_Log(2, " getSelectorStatusLabel: ", ival, itab)
  local cnt = 0
  --
  if itab ~= nil then
    -- convert 0;10;20;30  etc  to 1;2;3;5  etc
    if ival > 9 then
      ival = (ival / 10)
    end
    -- get the label and return
    for lbl in string.gmatch(itab, "[^|,]+") do
      if cnt == ival then
        Print_to_Log(1, "-< getSelectorStatusLabel found: " .. lbl, cnt, itab)
        return lbl
      end
      cnt = cnt + 1
    end
  end
  Print_to_Log(1, "-< getSelectorStatusLabel not found: " .. ival, cnt, itab)
  return ""
end

-----------------------------------------------
-- this function will rebuild the dtgmenu_submenus table each time it is called.
-- It will first read through the static menu items defined in DTGMENU.CRG in table static_dtgmenu_submenus
-- It will then call the MakeRoomMenus() function to add the dynamic options from Domoticz Room configuration
function PopulateMenuTab(iLevel, iSubmenu)
  buttonnbr = 0
  Print_to_Log(1, Sprintf("####  Start populating Menu Array.  ilevel:%s  iSubmenu:$s", iLevel, iSubmenu))
  -- reset menu table and rebuild
  dtgmenu_submenus = {}

  Print_to_Log(1, "Submenu table including buttons defined in menu.cfg:", iLevel, iSubmenu)
  for submenu, get in pairs(static_dtgmenu_submenus) do
    Print_to_Log(1, "=>", submenu, get.whitelist, get.showdevstatus, get.Menuwidth)
    if static_dtgmenu_submenus[submenu].buttons ~= nil then
      buttons = {}
      --Group change      if iLevel ~= "mainmenu" and iSubmenu == submenu then
      for button, dev in pairs(static_dtgmenu_submenus[submenu].buttons) do
        -- Get device/scene details
        idx, DeviceName, DeviceType, Type, SwitchType, MaxDimLevel, status = Domo_Devinfo_From_Name(9999, button, "anything")
        -- fill the button table records with all required fields
        -- Remove any spaces from the device name and replace them by underscore.
        button = string.gsub(button, "%s+", "_")
        -- Add * infront of button name when Scene or Group
        if DeviceType == "scenes" then
          button = "*" .. button
        end
        buttons[button] = {}
        buttons[button].whitelist = dev.whitelist -- specific for the static config: Whitelist number(s) for this device, blank is ALL
        buttons[button].actions = dev.actions -- specific for the static config: Hardcoded Actions for the device
        buttons[button].prompt = dev.prompt -- specific for the static config: Prompt TG cleint for the variable text
        buttons[button].showactions = dev.showactions -- specific for the static config: Show Device action menu right away when its menu is selected
        buttons[button].Name = DeviceName
        buttons[button].idx = idx
        buttons[button].DeviceType = DeviceType
        buttons[button].SwitchType = SwitchType
        buttons[button].Type = Type
        buttons[button].MaxDimLevel = MaxDimLevel -- Level required to calculate the percentage for devices that do not use 100 for 100%
        buttons[button].status = status
        Print_to_Log(1, " static ->", submenu, button, DeviceName, idx, DeviceType, Type, SwitchType, MaxDimLevel, status)
      end
    end
    -- Save the submenu entry with optionally all its devices/sceens
    dtgmenu_submenus[submenu] = {
      whitelist = get.whitelist,
      RoomNumber = get.RoomNumber,
      showdevstatus = get.showdevstatus,
      Menuwidth = get.Menuwidth,
      buttons = buttons
    }
    --Group change     end
  end
  -- Add the room/plan menu's after the static is populated
  MakeRoomMenus(iLevel, iSubmenu)
  Print_to_Log(1, "####  End populating Menu Array")
  return
end

--
-- Simple check function whether the input field is nil or empty ("")
function ChkEmpty(itxt)
  if itxt == nil or itxt == "" then
    return true
  end
  return false
end
-----------------------------------------------
--- END Misc Function to support the process
-----------------------------------------------

function DTGMenu_Modules.get_commands()
  return dtgmenu_commands
end

-- define the menu table and initialize the table first time
Menuidx = 0
dtgmenu_submenus = {}

-- Set the appropriate handler to use for the keyboard
if UseInlineMenu then
  Print_to_Log(1, "Set Handler to DTGil.handler")
  dtgmenu_commands = {["menu"] = {handler = DTGil.handler, description = "Will start menu functionality."},
                   ["dtgmenu"] = {handler = DTGil.handler, description = "Will start menu functionality."}
  }
else
  Print_to_Log(1, "Set Handler to DTGbo.handler")
  dtgmenu_commands = {["menu"] = {handler = DTGbo.handler, description = "Will start menu functionality."},
                   ["dtgmenu"] = {handler = DTGbo.handler, description = "Will start menu functionality."}
  }
end

return DTGMenu_Modules
