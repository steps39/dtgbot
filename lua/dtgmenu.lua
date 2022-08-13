-- =====================================================================================================================
-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in DTGMENU.CFG. Open the file for descript of the details.
--
-- programmer: Jos van der Zande
-- Version 0.901 20220912
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
if (FileExists(BotHomePath .. "dtgbot-user.cfg")) then
  config = assert(loadfile(BotHomePath .. "lua/dtgmenu-user.cfg"))()
  Print_to_Log("Using DTGMENU config file:" .. BotHomePath .. "lua/dtgmenu-user.cfg")
else
  config = assert(loadfile(BotHomePath .. "lua/dtgmenu.cfg"))()
  Print_to_Log("Using DTGMENU config file:" .. BotHomePath .. "lua/dtgmenu.cfg")
end

local http = require "socket.http"

-- definition used by DTGBOT
local dtgmenu_module = {}
local menu_language = Language

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

-------------------------------------------------------------------------------
--- START Build the reply_markup functions.
--  this function will build the requested menu layout and calls the function to retrieve the devices/scenes  details.
-------------------------------------------------------------------------------
function makereplymenu(SendTo, Level, submenu, devicename)
  -- These are the possible menu level's ..
  -- mainmenu   -> will show all first level static and dynamic (rooms) options
  -- submenu    -> will show the second level menu for the select option on the main menu
  -- devicemenu -> will show the same menu as the previous but now add the possible action at the top of the menu
  --
  if submenu == nil then
    submenu = ""
  end
  if devicename == nil then
    devicename = ""
  end
  Print_to_Log(1, "Start makereplymenu:", SendTo, Level, submenu, devicename)

  ------------------------------------------------------------------------------
  -- First build the dtgmenu_submenus table with the required level information
  ------------------------------------------------------------------------------
  --~ moved to refresh:   PopulateMenuTab(Level,submenu)

  ------------------------------------------------------------------------------
  -- start the build of the 3 levels of the keyboard menu
  ------------------------------------------------------------------------------
  Print_to_Log(1, "  -> makereplymenu  Level:", Level, "submenu", submenu, "devicename", devicename)
  local t = 1
  local l1menu = ""
  local l2menu = ""
  local l3menu = ""
  --~   Sort & Loop through the compiled options returned by PopulateMenuTab
  for i, get in orderedPairs(dtgmenu_submenus) do
    -- ==== Build mainmenu - level 1 which is the bottom part of the menu, showing the Rooms and static definitions
    -- Avoid adding start and menu as these are handled separately.
    if i ~= "menu" and i ~= "start" then
      if get.whitelist == "" or ChkInTable(get.whitelist, SendTo) then
        -- test if anything is specifically defined for this user in Telegram-RoomsShowninMenu`
        Print_to_Log(3, " MenuWhiteList check ", MenuWhiteList[SendTo] or " SendTo not defined", MenuWhiteList[0] or " Default not defined")
        --
        if get.RoomNumber then
          -- Check WHitelist for the Sender's id
          if MenuWhiteList[SendTo] then
            Print_to_Log(1, SendTo.." in MenuWhiteList Check room:"..(get.RoomNumber).."|", MenuWhiteList[SendTo][get.RoomNumber] or " -> not there" )
            if MenuWhiteList[SendTo][get.RoomNumber] then
              l1menu = l1menu .. i .. "|"
            end
            -- esle check for the standard/default menus to be shown
          elseif MenuWhiteList['0'] then
            Print_to_Log(1, "0 in MenuWhiteList Check room:"..(get.RoomNumber).."|", MenuWhiteList['0'][get.RoomNumber] or " -> not there" )
            if MenuWhiteList['0'] and MenuWhiteList['0'][get.RoomNumber] then
              l1menu = l1menu .. i .. "|"
            end
          else
            Print_to_Log(1, SendTo.." No 0/SendTo in list -> add to menu: ")
            l1menu = l1menu .. i .. "|"
          end
        else
          Print_to_Log(1, SendTo.." No Roomnumber -> add to menu: ")
          l1menu = l1menu .. i .. "|"
        end
      end
    end
  end
  -- ==== Build Submenu - showing the Devices from the selected room of static config
  --                      This will also add the device status when showdevstatus=true for the option.
  Print_to_Log(1, "submenu: " .. submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil and dtgmenu_submenus[submenu].buttons ~= nil then
      -- loop through all devined "buttons in the Config
      for i, get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
        Print_to_Log(1, " Submenu item:", i, get.submenu)
        -- process all found devices in  dtgmenu_submenus buttons table
        if i ~= "" then
          local switchstatus = ""
          Print_to_Log(1, "   - Submenu item:", i, dtgmenu_submenus[submenu].showdevstatus, get.DeviceType, get.idx, get.status)
          local didx, dDeviceName, dDeviceType, dType, dSwitchType, dMaxDimLevel
          if get.whitelist == "" or ChkInTable(get.whitelist, SendTo) then
            -- add the device status to the button when requested
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              didx, dDeviceName, dDeviceType, dType, dSwitchType, dMaxDimLevel, switchstatus, LevelNames, LevelInt = Domo_Devinfo_From_Name(get.idx, get.Name, get.DeviceType)
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
                if dSwitchType == "Selector" then
                  switchstatus = " - " .. getSelectorStatusLabel(get.actions, LevelInt)
                else
                  --~ 							Print_to_Log(0,switchstatus)
                  switchstatus = tostring(switchstatus)
                  switchstatus = switchstatus:gsub("Set Level: ", "")
                  switchstatus = " - " .. switchstatus
                end
              end
            end
            -- add to the total menu string for later processing
            l2menu = l2menu .. i .. switchstatus .. "|"
            -- show the actions menu immediately for this devices since that is requested in the config
            -- this can avoid having the press 2 button before getting to the actions menu
            if get.showactions and devicename == "" then
              Print_to_Log(1, "  - Changing to Device action level due to showactions:", i)
              Level = "devicemenu"
              devicename = i
            end
          end
        end
        Print_to_Log(1, l2menu)
        -- ==== Build DeviceActionmenu
        -- do not build the actions menu when NoDevMenu == true. EG temp devices have no actions
        if dtgmenu_submenus[submenu].NoDevMenu ~= true and Level == "devicemenu" and i == devicename then
          -- do not build the actions menu when DisplayActions == false on Device level. EG temp devices have no actions
          SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
          Type = dtgmenu_submenus[submenu].buttons[devicename].Type
          if (dtgbot_type_status[Type] == nil or dtgbot_type_status[Type].DisplayActions ~= false) then
            if (dtgbot_type_status[Type] ~= nil) then
            end
            -- set reply markup to the override when provide
            l3menu = get.actions
            Print_to_Log(1, " ---< ", Type, SwitchType, " using replymarkup:", l3menu)
            -- else use the default reply menu for the SwitchType
            if l3menu == nil or l3menu == "" then
              l3menu = dtgmenu_lang[menu_language].devices_options[SwitchType]
              if l3menu == nil then
                -- use the type in case of devices like a Thermostat
                l3menu = dtgmenu_lang[menu_language].devices_options[Type]
                if l3menu == nil then
                  Print_to_Log(1, "  !!! No default dtgmenu_lang[menu_language].devices_options for SwitchType:", SwitchType, Type)
                  l3menu = "Aan,Uit"
                end
              end
            end
            Print_to_Log(1, "   -< " .. tostring(SwitchType) .. " using replymarkup:", l3menu)
          end
        end
      end
    end
  end
  -------------------------------------------------------------------
  -- Start building the proper layout for the 3 levels of menu items
  -------------------------------------------------------------------
  -- Always add "menu" as last option to level1 menu
  l1menu = l1menu .. "Exit_Menu"
  ------------------------------
  -- start build total replymarkup
  local replymarkup = '{"keyboard":['
  ------------------------------
  -- Add level 3 first if needed
  ------------------------------
  if l3menu ~= "" then
    replymarkup = replymarkup .. buildmenu(l3menu, ActMenuwidth, "") .. ","
    l1menu = "back"
  end
  ------------------------------
  -- Add level 2 next if needed
  ------------------------------
  if l2menu ~= "" then
    local mwitdh = DevMenuwidth
    if dtgmenu_submenus[submenu].Menuwidth ~= nil then
      if tonumber(dtgmenu_submenus[submenu].Menuwidth) >= 2 then
        mwitdh = tonumber(dtgmenu_submenus[submenu].Menuwidth)
      end
    end
    replymarkup = replymarkup .. buildmenu(l2menu, mwitdh, "") .. ","
    l1menu = "back"
  end
  -------------------------------
  -- Add level 1 -- the main menu
  --------------------------------
  replymarkup = replymarkup .. buildmenu(l1menu, SubMenuwidth, "") .. "]"
  -- add the resize menu option when desired. this sizes the keyboard menu to the size required for the options
  if AlwaysResizeMenu then
    --~     replymarkup = replymarkup .. ',"resize_keyboard":true'
    replymarkup = replymarkup .. ',"selective":true,"resize_keyboard":true'
  end
  -- Close the total statement
  replymarkup = replymarkup .. "}"

  -- save the full replymarkup and only send it again when it changed to minimize traffic to the TG client
  if LastCommand[SendTo]["replymarkup"] == replymarkup then
    Print_to_Log(1, "  -< replymarkup: No update needed")
    replymarkup = ""
  else
    Print_to_Log(1, "  -< replymarkup:" .. replymarkup)
    LastCommand[SendTo]["replymarkup"] = replymarkup
  end
  -- save menus
  LastCommand[SendTo]["l1menu"] = l1menu -- rooms or submenu items
  LastCommand[SendTo]["l2menu"] = l2menu -- Devices scenes or commands
  LastCommand[SendTo]["l3menu"] = l3menu -- actions
  Persistent.LastCommand = Lastcommand
  return replymarkup, devicename
end
-- convert the provided menu options into a proper format for the replymenu
function buildmenu(menuitems, width, extrachar)
  local replymenu = ""
  local t = 0
  Print_to_Log(1, " process buildmenu:", menuitems, " w:", width)
  for dev in string.gmatch(menuitems, "[^|,]+") do
    if t == width then
      replymenu = replymenu .. "],"
      t = 0
    end
    if t == 0 then
      replymenu = replymenu .. '["' .. extrachar .. "" .. dev .. '"'
    else
      replymenu = replymenu .. ',"' .. extrachar .. "" .. dev .. '"'
    end
    t = t + 1
  end
  if replymenu ~= "" then
    replymenu = replymenu .. "]"
  end
  Print_to_Log(1, "    -< buildmenu:", replymenu)
  return replymenu
end
-----------------------------------------------
--- END Build the reply_markup functions.
-----------------------------------------------
-- decoding
-----------------------------------------------
--- START population the table which runs at each menu update -> makereplymenu
-----------------------------------------------
--
-- this function will rebuild the dtgmenu_submenus table each time it is called.
-- It will first read through the static menu items defined in DTGMENU.CRG in table static_dtgmenu_submenus
-- It will then call the MakeRoomMenus() function to add the dynamic options from Domoticz Room configuration
function PopulateMenuTab(iLevel, iSubmenu)
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

--print(" wrong" .. causeerror)
-----------------------------------------------
--- START the main process handler
-----------------------------------------------
function dtgmenu_module.handler(menu_cli, SendTo, commandline)
  --print(" wrong" .. causeerror)

  -- initialise the user table in case it runs the firsttime
  if LastCommand[SendTo] == nil then
    LastCommand[SendTo] = {}
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["replymarkup"] = ""
    LastCommand[SendTo]["prompt"] = 0
  end
  --
  Print_to_Log(-11, "Handle -> " .. menu_cli[2])
  Print_to_Log(1, " => SendTo:", SendTo)
  local command = tostring(menu_cli[2])
  local lcommand = string.lower(command)
  commandline = commandline or ""
  local lcommandline = string.lower(commandline)
  local param1 = ""
  -- Retrieve the first parameter after the command in case provided.
  if menu_cli[3] ~= nil then
    param1 = tostring(menu_cli[3]) -- the command came in through the standard DTGBOT process
  elseif menu_cli[2] ~= nil then
    param1 = tostring(menu_cli[2]) -- the command came in via the DTGMENU exit routine
  end
  Print_to_Log(1, " => commandline  :", commandline)
  Print_to_Log(1, " => command      :", command)
  Print_to_Log(1, " => param1       :", param1)
  Print_to_Log(1, " => Lastmenu submenu  :", LastCommand[SendTo]["l1menu"])
  Print_to_Log(1, " => Lastmenu devs/cmds:", LastCommand[SendTo]["l2menu"])
  Print_to_Log(1, " => Lastmenu actions  :", LastCommand[SendTo]["l3menu"])
  Print_to_Log(1, " => Lastcmd prompt :", LastCommand[SendTo]["prompt"])
  Print_to_Log(1, " => Lastcmd submenu:", LastCommand[SendTo]["submenu"])
  Print_to_Log(1, " => Lastcmd device :", LastCommand[SendTo]["device"])

  -------------------------------------------------
  -- set local variables
  -------------------------------------------------
  local lparam1 = string.lower(param1)
  local cmdisaction = ChkInTable(LastCommand[SendTo]["l3menu"], commandline)
  local cmdisbutton = ChkInTable(LastCommand[SendTo]["l2menu"], commandline)
  local cmdissubmenu = ChkInTable(LastCommand[SendTo]["l1menu"], commandline)
  -- When the command is not a button or submenu and the last Action options contained a "?" and the current command is numeric we assume this is a manual set percentage
  if not (cmdisaction or cmdisbutton or cmdisbutton) and ChkInTable(LastCommand[SendTo]["l3menu"], "?") and string.find(command, "%d") then
    cmdisaction = true
  end
  -------------------------------------------------
  -- Process "start" or "menu" commands
  -------------------------------------------------
  -- Build main menu and return
  if cmdisaction == false and (lcommand == "menu" or lcommand == "showmenu" or lcommand == "start") then
    Persistent.UseDTGMenu = 1
    Print_to_Log(1, Sprintf("Persistent.UseDTGMenu=%s", Persistent.UseDTGMenu))
    -- ensure the menu is always rebuild for Menu or Start
    LastCommand[SendTo]["replymarkup"] = ""
    local response = DTGMenu_translate_desc("main", menu_language, "Select the submenu.")
    replymarkup = makereplymenu(SendTo, "mainmenu")
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    Print_to_Log(1, "-< Show main menu")
    Persistent.Lastcommand = LastCommand
    Save_Persistent_Vars()
    return true, response, replymarkup
  end
  -- Hide main menu and return
  if cmdisaction == false and (lcommand == "exit_menu") then
    -- ensure the menu is always rebuild for Menu or Start
    local response = DTGMenu_translate_desc("main", menu_language, "type /menu to show it again.")
    LastCommand[SendTo]["replymarkup"] = ""
    replymarkup = '{"remove_keyboard":true}'
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    Print_to_Log(0, "-< hide main menu")
    Persistent.LastCommand = Lastcommand
    Persistent.UseDTGMenu = 0
    Print_to_Log(1, Sprintf("Persistent.UseDTGMenu=%s", Persistent.UseDTGMenu))
    -- clean all messages but last when option MenuMessagesCleanOnExit is set true
    if MenuMessagesCleanOnExit then
      Telegram_CleanMessages(SendTo, 0, 0,"menu", true)
    end
    return true, response, replymarkup
  end
  -------------------------------------------------
  -- process prompt input for "command" Type
  -------------------------------------------------
  -- When returning from a "prompt"action" then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
  if LastCommand[SendTo]["prompt"] == 1 then
    -- make small keyboard
    replymarkup = '{"keyboard":[["showmenu"]],"resize_keyboard":true}'
    response = ""
    -- add previous command to the current command
    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = 0
    Print_to_Log(11, "-< prompt and found regular lua command and param was given. -> hand back to dtgbot to run", menu_cli[2])
    Persistent.Lastcommand = LastCommand
    return true, response, replymarkup
  end

  -----------------------------------------------------
  -- process when command is not known in the last menu
  -----------------------------------------------------
  -- hand back to DTGBOT reset keyboard to just MENU
  if cmdisaction == false and cmdisbutton == false and cmdissubmenu == false then
    -- make small keyboard
    replymarkup = '{"keyboard":[["showmenu"]],"resize_keyboard":true}'
    response = ""
    --    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = 0
    Print_to_Log(-11, "-< Unknown as menu option so hand back to dtgbot to handle")
    Persistent.Lastcommand = LastCommand
    return false, response, replymarkup
  end

  -------------------------------------------------
  -- continue set local variables
  -------------------------------------------------
  local submenu = ""
  local devicename = ""
  local action = ""
  local status = 0
  local response = ""
  local DeviceType = "devices"
  local SwitchType = ""
  local idx = ""
  local Type = ""
  local dstatus = ""
  local MaxDimLevel = 0
  if cmdissubmenu then
    submenu = commandline
  end

  ----------------------------------------------------------------------
  -- Set needed variable when the command is a known device menu button
  ----------------------------------------------------------------------
  if cmdisbutton then
    submenu = LastCommand[SendTo]["submenu"]
    devicename = command -- use command as that should only contain the values of the first param
    if dtgmenu_submenus[submenu] == nil then
      Print_to_Log(1, "Error not found  => submenu :", submenu)
    elseif dtgmenu_submenus[submenu].buttons[devicename] == nil then
      Print_to_Log(1, "Error not found  => devicename :", devicename)
    else
      realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name or "?"
      Type = dtgmenu_submenus[submenu].buttons[devicename].Type or "?"
      idx = dtgmenu_submenus[submenu].buttons[devicename].idx or "?"
      DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType or "?"
      SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType or "?"
      MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel or "?"
      dstatus = dtgmenu_submenus[submenu].buttons[devicename].status or "?"
      Print_to_Log(1, " => devicename :", devicename)
      Print_to_Log(1, " => realdevicename :", realdevicename)
      Print_to_Log(1, " => idx:", idx)
      Print_to_Log(1, " => Type :", Type)
      Print_to_Log(1, " => DeviceType :", DeviceType)
      Print_to_Log(1, " => SwitchType :", SwitchType)
      Print_to_Log(1, " => MaxDimLevel:", MaxDimLevel)
    end
    if DeviceType ~= "command" then
      dummy, dummy, dummy, dummy, dummy, dummy, dstatus, LevelNames, LevelInt = Domo_Devinfo_From_Name(idx, realdevicename, DeviceType)
      Print_to_Log(1, " => dstatus    :", dstatus)
      Print_to_Log(1, " => LevelNames :", LevelNames)
      Print_to_Log(1, " => LevelInt   :", LevelInt)
    end
  end
  ----------------------------------------------------------------------
  -- Set needed variables when the command is a known action menu button
  ----------------------------------------------------------------------
  if cmdisaction then
    submenu = LastCommand[SendTo]["submenu"]
    devicename = LastCommand[SendTo]["device"]
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    action = lcommand -- use lcommand as that should only contain the values of the first param
    Type = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    if DeviceType ~= "command" then
      dummy, dummy, dummy, dummy, dummy, dummy, dstatus, LevelNames, LevelInt = Domo_Devinfo_From_Name(idx, realdevicename, DeviceType)
      Print_to_Log(1, " => dstatus    :", dstatus)
      Print_to_Log(1, " => LevelNames :", LevelNames)
      Print_to_Log(1, " => LevelInt   :", LevelInt)
    end
    Print_to_Log(1, " => devicename :", devicename)
    Print_to_Log(1, " => realdevicename :", realdevicename)
    Print_to_Log(1, " => idx:", idx)
    Print_to_Log(1, " => Type :", Type)
    Print_to_Log(1, " => DeviceType :", DeviceType)
    Print_to_Log(1, " => SwitchType :", SwitchType)
    Print_to_Log(1, " => MaxDimLevel:", MaxDimLevel)
    Print_to_Log(1, " => LevelNames :", LevelNames)
  end
  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- process Type="command" (none devices/scenes
  -------------------------------------------------
  if Type == "command" then
    --  when Button is pressed and Type "command" and no actions defined for the command then check for prompt and hand back without updating the keyboard
    if cmdisbutton and ChkEmpty(dtgmenu_submenus[submenu].buttons[command].actions) then
      -- prompt for parameter when requested in the config
      if dtgmenu_submenus[LastCommand[SendTo]["submenu"]].buttons[commandline].prompt then
        -- no prompt defined so simply return to dtgbot with status 0 so it will be performed and reset the keyboard to just MENU
        LastCommand[SendTo]["device"] = commandline
        LastCommand[SendTo]["prompt"] = 1
        replymarkup = '{"force_reply":true}'
        LastCommand[SendTo]["replymarkup"] = replymarkup
        status = true
        response = DTGMenu_translate_desc(Language, "Specifyvalue")
        Print_to_Log(1, "-<1 found regular lua command that need Param ")
      else
        replymarkup = '{"keyboard":[["menu"]],"resize_keyboard":true}'
        status = false
        LastCommand[SendTo]["submenu"] = ""
        LastCommand[SendTo]["device"] = ""
        LastCommand[SendTo]["l1menu"] = ""
        LastCommand[SendTo]["l2menu"] = ""
        LastCommand[SendTo]["l3menu"] = ""
        Print_to_Log(1, "-<1 found regular lua command. -> hand back to dtgbot to run")
      end
      Persistent.Lastcommand = LastCommand
      return status, response, replymarkup
    end

    --  when Action is pressed and Type "command"  then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
    if devicename ~= "" and cmdisaction then
      --  if command is one of the actions of a command DeviceType hand it now back to DTGBOT
      replymarkup = '{"keyboard":[["menu"]],"resize_keyboard":true}'
      response = ""
      -- add previous command ot the current command
      commandline = LastCommand[SendTo]["device"] .. " " .. commandline
      LastCommand[SendTo]["submenu"] = ""
      LastCommand[SendTo]["device"] = ""
      LastCommand[SendTo]["l1menu"] = ""
      LastCommand[SendTo]["l2menu"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      Print_to_Log(1, "-<2 found regular lua command. -> hand back to dtgbot to run:" .. LastCommand[SendTo]["device"] .. " " .. commandline)
      Persistent.Lastcommand = LastCommand
      return false, response, replymarkup
    end
  end

  -------------------------------------------------
  -- process submenu button pressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    LastCommand[SendTo]["submenu"] = submenu
    Print_to_Log(1, " - Showing Submenu as no device name specified. submenu: " .. submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo, "submenu", submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      LastCommand[SendTo]["device"] = rdevicename
      Print_to_Log(1, " -- Changed to devicelevel due to showactions defined for device " .. rdevicename)
      response = DTGMenu_translate_desc(Language, "SelectOptionwo") .. " " .. rdevicename
    else
      response = submenu .. ":" .. DTGMenu_translate_desc("Select", Language, "Select option.")
    end
    Print_to_Log(1, "-< show options in submenu.")
    Persistent.Lastcommand = LastCommand
    return true, response, replymarkup
  end

  -------------------------------------------------------
  -- process device button pressed on one of the submenus
  -------------------------------------------------------
  if cmdisbutton then
    -- create reply menu and update table with device details
    replymarkup = makereplymenu(SendTo, "devicemenu", submenu, devicename)
    -- Save the current device
    LastCommand[SendTo]["device"] = devicename
    local switchstatus = ""
    local found = 0
    if DeviceType == "scenes" then
      --~     elseif Type == "Temp" or Type == "Temp + Humidity" or Type == "Wind" or Type == "Rain" then
      if Type == "Group" then
        response = DTGMenu_translate_desc(Language, "SelectGroup")
        Print_to_Log(1, "-< Show group options menu plus other devices in submenu.")
      else
        response = DTGMenu_translate_desc(Language, "SelectScene")
        Print_to_Log(1, "-< Show scene options menu plus other devices in submenu.")
      end
    elseif dtgbot_type_status[Type] ~= nil and dtgbot_type_status[Type].DisplayActions == false then
      -- when temp device is selected them just return with resetting keyboard and ask to select device.
      response = DTGMenu_translate_desc("Select", Language, "Select option.")
      Print_to_Log(1, "-< Don't do anything as a temp device was selected.")
    elseif DeviceType == "devices" then
      -- Only show current status in the text when not shown on the action options
      if dtgmenu_submenus[submenu].showdevstatus == "y" then
        switchstatus = dstatus
        if ChkEmpty(switchstatus) then
          switchstatus = ""
        else
          switchstatus = tostring(switchstatus)
          switchstatus = switchstatus:gsub("Set Level: ", "")
        end
        -- Get the correct Label for a Selector switch which belongs to the level.
        if SwitchType == "Selector" then
          switchstatus = getSelectorStatusLabel(LevelNames, LevelInt)
        end
        response = DTGMenu_translate_desc(Language, "SelectOptionwo")
      else
        switchstatus = dstatus
        response = DTGMenu_translate_desc(Language, "SelectOption") .. " " .. switchstatus
      end
      Print_to_Log(1, "-< Show device options menu plus other devices in submenu.")
    else
      response = DTGMenu_translate_desc("Select", Language, "Select option.")
      Print_to_Log(1, "-< Show options menu plus other devices in submenu.")
    end
    Persistent.Lastcommand = LastCommand
    return true, response, replymarkup
  end

  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  -- Specials
  -------------------------------------------------
  if Type == "Thermostat" then
    -- prompt for themperature
    if commandline == "?" then
      replymarkup = '{"force_reply":true}'
      LastCommand[SendTo]["replymarkup"] = replymarkup
      response = DTGMenu_translate_desc(Language, "Specifyvalue")
      Print_to_Log(1, "-< " .. response)
      return true, response, replymarkup
    else
      if commandline == "+" or commandline == "-" then
        dstatus = dstatus:gsub("°C", "")
        dstatus = dstatus:gsub("°F", "")
        dstatus = dstatus:gsub(" ", "")
        commandline = tonumber(dstatus) + tonumber(commandline .. "0.5")
      end
      -- set thermostate temperature
      local t, jresponse
      t = Domoticz_Url .. "/json.htm?type=command&param=udevice&idx=" .. idx .. "&nvalue=0&svalue=" .. commandline
      Print_to_Log(1, "JSON request <" .. t .. ">")
      jresponse, status = HTTP.request(t)
      Print_to_Log(1, "JSON feedback: ", jresponse)
      response = "Set " .. realdevicename .. " to " .. commandline .. "°C"
    end
  elseif SwitchType == "Selector" then
    -------------------------------------------------
    -- regular On/Off/Set Level
    -------------------------------------------------
    local sfound, Selector_Option = ChkInTable(string.lower(LevelNames), string.lower(action))
    if sfound then
      if LevelNames:sub(1, 1) ~= "|" then
        Selector_Option = Selector_Option - 1
      end
      Selector_Option = (Selector_Option) * 10
      Print_to_Log(2, "    -> Selector Switch level found ", Selector_Option, LevelNames, action)
      response = Domo_sSwitchName(realdevicename, DeviceType, SwitchType, idx, "Set Level " .. Selector_Option)
    else
      response = "Selector Option not found:" .. action
    end
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["Off"]), string.lower(action)) then
    response = Domo_sSwitchName(realdevicename, DeviceType, SwitchType, idx, "Off")
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["On"]), string.lower(action)) then
    response = Domo_sSwitchName(realdevicename, DeviceType, SwitchType, idx, "On")
  elseif string.find(action, "%d") then -- assume a percentage is specified.
    -- calculate the proper level to set the dimmer
    action = action:gsub("%%", "") -- remove % sign
    rellev = tonumber(action) * MaxDimLevel / 100 -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response = Domo_sSwitchName(realdevicename, DeviceType, SwitchType, idx, "Set Level " .. action)
  elseif action == "+" or action == "-" then
    -- calculate the proper level to set the dimmer
    dstatus = status2number(dstatus)
    Print_to_Log(2, " + or - command: dstatus:", tonumber(dstatus), "action..10:", action .. "10")
    action = tonumber(dstatus) + tonumber(action .. "10")
    if action > 100 then
      action = 100
    end
    if action < 0 then
      action = 0
    end
    rellev = MaxDimLevel / 100 * tonumber(action) -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response = Domo_sSwitchName(realdevicename, DeviceType, SwitchType, idx, "Set Level " .. action)
  elseif commandline == "?" then
    -------------------------------------------------
    -- Unknown Action
    -------------------------------------------------
    replymarkup = '{"force_reply":true}'
    LastCommand[SendTo]["replymarkup"] = replymarkup
    response = DTGMenu_translate_desc(Language, "Specifyvalue")
    Print_to_Log(1, "-<" .. response)
    return true, response, replymarkup
  else
    response = DTGMenu_translate_desc(Language, "UnknownChoice") .. action
  end
  replymarkup = makereplymenu(SendTo, "devicemenu", submenu, devicename)
  Print_to_Log(1, "-< " .. response)
  return true, response, replymarkup
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------

local dtgmenu_commands = {
  ["menu"] = {
    handler = dtgmenu_module.handler,
    description = "Will start menu functionality."
  },
  ["dtgmenu"] = {
    handler = dtgmenu_module.handler,
    description = "Will start menu functionality."
  }
}

function dtgmenu_module.get_commands()
  return dtgmenu_commands
end

-- define the menu table and initialize the table first time
Menuidx = 0
dtgmenu_submenus = {}
--~ PopulateMenuTab(1,"")  -- now done in refresh

return dtgmenu_module
