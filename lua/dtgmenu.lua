-- =====================================================================================================================
-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in DTGMENU.CFG. Open the file for descript of the details.
--
-- programmer: Jos van der Zande
-- version: 0.1.150824
-- =====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
-- these are the different formats of reply_markup. looksimple but needed a lot of testing before it worked :)
--
-- >show the custom keyboard and stay up after option selection first 3 on the first line and menu on the second
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]]}
-- >show the custom keyboard and minimises after option selection
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"one_time_keyboard":true}
-- >Remove the custom keyboard
--	reply_markup={"hide_keyboard":true}
--	reply_markup={"hide_keyboard":true,"selective":false}
-- >force normal keyboard to ask for input
--	reply_markup={"force_reply":true}
--	reply_markup={"force_reply":true,"selective":false}
-- >Resize the keyboard
--	reply_markup={"keyboard":[["menu"]],"resize_keyboard":true}
--  reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"resize_keyboard":true}

--------------------------------------
-- Include config
--------------------------------------
local config = assert(loadfile(BotHomePath.."lua/dtgmenu.cfg"))();
local http = require "socket.http";

-- definition used by DTGBOT
local dtgmenu_module = {};
local menu_language = language

-- If Domoticz language is not used then revert to English
if dtgmenu_lang[menu_language] == nil then
  print_to_log(0, "Domoticz language is not available for dtgmenus")
  menu_language = "en"
end

-------------------------------------------------------------------------------
-- Start Functions to SORT the TABLE
-- Copied from internet location: -- http://lua-users.org/wiki/SortedIteration
-- These are used to sort the items on the menu alphabetically
-------------------------------------------------------------------------------
function __genOrderedIndex( t )
  local orderedIndex = {}
  for key in pairs(t) do
    table.insert( orderedIndex, key )
  end
  table.sort( orderedIndex )
  return orderedIndex
end

function table.map_length(t)
  local c = 0
  for k,v in pairs(t) do
    c = c+1
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
    t.__orderedIndex = __genOrderedIndex( t )
    key = t.__orderedIndex[1]
  else
    -- fetch the next value
    for i = 1,table.map_length(t.__orderedIndex) do
      if t.__orderedIndex[i] == state then
        key = t.__orderedIndex[i+1]
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

  ------------------------------------------------------------------------------
  -- start the build of the 3 levels of the keyboard menu
  ------------------------------------------------------------------------------
  print_to_log(1,"  -> makereplymenu  Level:",Level,"submenu",submenu,"devicename",devicename)
  local t=0
  local l1menu=""
  local l2menu=""
  local l3menu=""
-- ==== Build Submenu - showing the Devices from the selected room of static config
--                      This will also add the device status when showdevstatus=true for the option.
  print_to_log(1,'     submenu: '..submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil
    and dtgmenu_submenus[submenu].buttons ~= nil then
      t=0
      -- loop through all defined "buttons in the Config
      local DevMwitdh=DevMenuwidth
      if dtgmenu_submenus[submenu].Menuwidth ~= nil then
        if tonumber(dtgmenu_submenus[submenu].Menuwidth) >= 2 then
          DevMwitdh=tonumber(dtgmenu_submenus[submenu].Menuwidth)
        end
      end
      for i,get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
        -- process all found devices in dtgmenu_submenus buttons table
        if i ~= "" then
          local switchstatus = ""
          print_to_log(2,"   - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          local didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            -- add the device status to the button when requested
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel,switchstatus,LevelNames,LevelInt = devinfo_from_name(get.idx,get.Name,get.DeviceType)
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
                if dSwitchType == "Selector" then
                  switchstatus = " "..getSelectorStatusLabel(get.actions,LevelInt)
                else
                  switchstatus = tostring(switchstatus)
                  switchstatus = switchstatus:gsub("Set Level: ", "")
                  switchstatus = switchstatus:gsub(" ", "")
                  switchstatus = " " .. switchstatus
                end
              end
            end
            -- add to the total menu string for later processing
            t,newbutton = buildmenuitem(string.sub(i,1,ButtonTextwidth-string.len(switchstatus))..switchstatus,"menu",submenu .. " " .. i, DevMwitdh,t)
            l2menu=l2menu .. newbutton
            -- show the actions menu immediately for this devices since that is requested in the config
            -- this can avoid having the press 2 button before getting to the actions menu
            if get.showactions and devicename == "" then
              print_to_log(2,"    - Changing to Device action level due to showactions:",i)
              Level = "devicemenu"
              devicename = i
            end
          end
        end
        -- ==== Build DeviceActionmenu
        -- do not build the actions menu when NoDevMenu == true. EG temp devices have no actions
        if dtgmenu_submenus[submenu].NoDevMenu ~= true
        and Level == "devicemenu" and i == devicename then
          -- do not build the actions menu when DisplayActions == false on Device level. EG temp devices have no actions
          SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
          Type = dtgmenu_submenus[submenu].buttons[devicename].Type
          if (dtgbot_type_status[Type] == nil or dtgbot_type_status[Type].DisplayActions ~= false) then
            if (dtgbot_type_status[Type] ~= nil ) then
            end
            -- set reply markup to the override when provide
            l3menu = get.actions
            print_to_log(1," ---< ",Type,SwitchType," using replymarkup:",l3menu)
            -- else use the default reply menu for the SwitchType
            if l3menu == nil or l3menu == "" then
              l3menu = dtgmenu_lang[menu_language].devices_options[SwitchType]
              if l3menu == nil then
                -- use the type in case of devices like a Thermostat
                l3menu = dtgmenu_lang[menu_language].devices_options[Type]
                if l3menu == nil then
                  print_to_log(1,"  !!! No default dtgmenu_lang[menu_language].devices_options for SwitchType:",SwitchType,Type)
                  l3menu = dtgmenu_lang[menu_language].devices_options["On/Off"]
                end
              end
            end
            print_to_log(1,"   -< ".. tostring(SwitchType).." using replymarkup:",l3menu)
          end
        end
      end
      l2menu=l2menu .. ']'
    end
  end
  -------------------------------------------------------------------
  -- Start building the proper layout for the 3 levels of menu items
  -------------------------------------------------------------------
  ------------------------------
  -- start build total replymarkup
  local replymarkup = '{"inline_keyboard":['
  ------------------------------
  -- Add level 3 first if needed
  ------------------------------
  if l3menu ~= "" then
    replymarkup = replymarkup .. buildmenu(l3menu,ActMenuwidth,"menu " .. submenu .. " ".. devicename) .. ","
  end
  ------------------------------
  -- Add level 2 next if needed
  ------------------------------
  if l2menu ~= "" then
    replymarkup = replymarkup .. l2menu .. ","
  end
  -------------------------------
  -- Add level 1 -- the main menu
  --------------------------------
  t=0
  if (FullMenu or l2menu == "") then
    --~   Sort & Loop through the compiled options returned by PopulateMenuTab
    for i,get in orderedPairs(dtgmenu_submenus) do
      -- ==== Build mainmenu - level 1 which is the bottom part of the menu, showing the Rooms and static definitins
      -- Avoid adding start and menu as these are handled separately.
      if i ~= "menu" and i ~= "start" then
        if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
          -- buildmenuitem(menuitem,prefix,Callback,width,t)
          t,newbutton = buildmenuitem(i,"menu",i, SubMenuwidth,t)
          l1menu=l1menu .. newbutton
        end
      end
    end
  end
  -- add Menu & Exit
  t,newbutton = buildmenuitem("Menu","menu","menu",SubMenuwidth,t)
  l1menu=l1menu .. newbutton
  t,newbutton = buildmenuitem("Exit","menu","exit",SubMenuwidth,t)
  l1menu=l1menu .. newbutton
  l1menu=l1menu .. ']'
  replymarkup = replymarkup .. l1menu .. '],"resize_keyboard":true'
  --(not working with inline keyboards (yet?). add the resize menu option when desired. this sizes the keyboard menu to the size required for the options
  --replymarkup = replymarkup .. ',"resize_keyboard":true}'
  replymarkup = replymarkup .. '}'
  print_to_log(0,"  -< replymarkup:"..replymarkup)
-- save menus
  return replymarkup, devicename
end
-- convert the provided menu options into a proper format for the replymenu
function buildmenu(menuitems,width,prefix)
  local replymenu=""
  local t=0
  print_to_log(2,"      process buildmenu:",menuitems," w:",width)
  for dev in string.gmatch(menuitems, "[^|,]+") do
    if t == width then
      replymenu = replymenu .. '],'
      t = 0
    end
    if t == 0 then
        replymenu = replymenu .. '[{"text":"' .. dev .. '","callback_data":"' .. prefix .. " " .. dev .. '"}'
    else
        replymenu = replymenu .. ',{"text":"' .. dev .. '","callback_data":"' .. prefix .. " " .. dev .. '"}'
    end
    t = t + 1
  end
  if replymenu ~= "" then
    replymenu = replymenu .. ']'
  end
  print_to_log(2,"    -< buildmenu:",replymenu)
  return replymenu
end
-- convert the provided menu options into a proper format for the replymenu
function buildmenuitem(menuitem,prefix,Callback,width,t)
  local replymenu=""
  print_to_log(2,"       process buildmenuitem:",menuitem,prefix,Callback," w:",width," t:",t)
  if t == width then
    replymenu = replymenu .. '],'
    t = 0
  end
  if t == 0 then
      replymenu = replymenu .. '['
  else
      replymenu = replymenu .. ','
  end
  replymenu = replymenu .. '{"text":"' .. menuitem .. '","callback_data":"' .. prefix .. " " .. Callback .. '"}'
  print_to_log(2,"    -< buildmenuitem:",replymenu)
  t=t+1
  return t,replymenu
end
-----------------------------------------------
--- END Build the reply_markup functions.
-----------------------------------------------

-----------------------------------------------
--- START population the table which runs at each menu update -> makereplymenu
-----------------------------------------------
--
-- this function will rebuild the dtgmenu_submenus table each time it is called.
-- It will first read through the static menu items defined in DTGMENU.CRG in table static_dtgmenu_submenus
-- It will then call the MakeRoomMenus() function to add the dynamic options from Domoticz Room configuration
function PopulateMenuTab(iLevel,iSubmenu)
  buttonnbr = 0
  print_to_log(1,"####  Start populating menuarray")
  -- reset menu table and rebuild
  dtgmenu_submenus = {}

  print_to_log(1,"   Submenu table including buttons defined in menu.cfg:",iLevel,iSubmenu)
  for submenu,get in pairs(static_dtgmenu_submenus) do
    print_to_log(1,"=>",submenu, get.whitelist, get.showdevstatus,get.Menuwidth)
    if static_dtgmenu_submenus[submenu].buttons ~= nil then
      buttons = {}
--Group change      if iLevel ~= "mainmenu" and iSubmenu == submenu then
        for button,dev in pairs(static_dtgmenu_submenus[submenu].buttons) do
          -- Get device/scene details
          idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(9999,button,"anything")
          -- fill the button table records with all required fields
          -- Remove any spaces from the device name and replace them by underscore.
          button = string.gsub(button,"%s+", "_")
          -- Add * infront of button name when Scene or Group
          if DeviceType == "scenes" then
            button = "*"..button
          end
          buttons[button]={}
          buttons[button].whitelist = dev.whitelist       -- specific for the static config: Whitelist number(s) for this device, blank is ALL
          buttons[button].actions=dev.actions             -- specific for the static config: Hardcoded Actions for the device
          buttons[button].showactions=dev.showactions     -- specific for the static config: Show Device action menu right away when its menu is selected
          buttons[button].Name=DeviceName
          buttons[button].idx=idx
          buttons[button].DeviceType=DeviceType
          buttons[button].SwitchType=SwitchType
          buttons[button].Type=Type
          buttons[button].MaxDimLevel=MaxDimLevel     -- Level required to calculate the percentage for devices that do not use 100 for 100%
          buttons[button].status=status
          print_to_log(1," static ->",submenu,button,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
        end
      end
      -- Save the subment entry with optionally all its devices/sceens
      dtgmenu_submenus[submenu] = {whitelist=get.whitelist,showdevstatus=get.showdevstatus,Menuwidth=get.Menuwidth,buttons=buttons}
--Group change     end
  end
  -- Add the room/plan menu's after the statis is populated
  MakeRoomMenus(iLevel,iSubmenu)
  print_to_log(1,"####  End populating menuarray")
  return
end
--
-- Create a button per room.
function MakeRoomMenus(iLevel,iSubmenu)
  iSubmenu = tostring(iSubmenu)
  print_to_log(1,"Creating Room Menus:",iLevel,iSubmenu)
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
      Devsinplan = device_list("command&param=getplandevices&idx="..room_number)
      DIPresult = Devsinplan["result"]
      if DIPresult ~= nil then
        print_to_log(1,'For room '..room_name..' got some devices and/or scenes')
        dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons={}}
        -----------------------------------------------------------
        -- process all found entries in the plan record
        -----------------------------------------------------------
        buttons = {}
        for d,DIPrecord in pairs(DIPresult) do
          if type(DIPrecord) == "table" then
            local DeviceType="devices"
            local SwitchType
            local Type
            local status=""
            local LevelNames=""
            local MaxDimLevel=100
            local idx=DIPrecord.devidx
            local name=DIPrecord.Name
            local DUMMY={"result"}
            DUMMY["result"]={}
            print_to_log(1," - Plan record:",DIPrecord.Name,DIPrecord.devidx,DIPrecord.type)
            if DIPrecord.type == 1 then
              print_to_log(1,"--> scene record")
              idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(idx,"","scenes")
            else
              print_to_log(1,"--> device record")
              idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status,LevelNames = devinfo_from_name(idx,"","devices")
            end
            -- Remove the name of the room from the device if it is present and any susequent Space or Hyphen or undersciore
            button = string.gsub(DeviceName,room_name.."[%s-_]*","")
            -- But reinstate it if less than 3 letters are left
            if #button < 3 then
              button = DeviceName
            end
            -- Remove any spaces from the device name and replace them by underscore.
            button = string.gsub(button,"%s+", "_")
            -- Add * infront of button name when Scene or Group
            if DeviceType == "scenes" then
              button = "*"..button
            end
            -- fill the button table records with all required fields
            buttons[button]={}
            buttons[button].whitelist=""               -- Not implemented for Dynamic menu: Whitelist number(s) for this device, blank is ALL
            if LevelNames == "" or LevelNames == nil then
              buttons[button].actions=""                 -- Not implemented for Dynamic menu: Hardcoded Actions for the device
            else
              buttons[button].actions=LevelNames:gsub("|",",")
            end
            buttons[button].showactions=false          -- Not implemented for Dynamic menu: Show Device action menu right away when its menu is selected
            buttons[button].Name=DeviceName            -- Original devicename needed to be able to perform the "Set new status" commands
            buttons[button].idx=idx
            buttons[button].DeviceType=DeviceType
            buttons[button].SwitchType=SwitchType
            buttons[button].Type=Type
            buttons[button].MaxDimLevel=MaxDimLevel     -- Level required to calculate the percentage for devices that do not use 100 for 100%
            buttons[button].status=status
            print_to_log(1," Dynamic ->",rbutton,button,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
          end
        end
      end
--Group change    end
    -- Save the Room entry with optionally all its devices/sceens
    dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons=buttons}
  end
end
--
-----------------------------------------------
--- END population the table
-----------------------------------------------

-----------------------------------------------
--- Start Misc Function to support the process
-----------------------------------------------
-- function to return a numeric value for a device status.
function status2number(switchstatus)
  -- translater the switchstatus to a number from 0-100
  switchstatus = tostring(switchstatus)
  print_to_log(2,"--> status2number Input switchstatus",switchstatus)
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
  print_to_log(2,"--< status2number Returned switchstatus",switchstatus)
  return switchstatus
end
-- SCAN through provided delimited string for the second parameter
function ChkInTable(itab,idev)
--~   print_to_log(2, " ChkInTable: ",idev,itab)
  local cnt=0
  if itab ~= nil then
    for dev in string.gmatch(itab, "[^|,]+") do
      cnt=cnt+1
      if dev == idev then
				print_to_log(2, "-< ChkInTable found: "..idev,cnt,itab)
        return true,cnt
      end
    end
  end
  print_to_log(2, "-< ChkInTable not found: "..idev,cnt,itab)
  return false,0
end
-- SCAN through provided delimited string for the second parameter
function getSelectorStatusLabel(itab,ival)
--~   print_to_log(2, " getSelectorStatusLabel: ",ival,itab)
  local cnt=0
  --
  if itab ~= nil then
    -- convert 0;10;20;30  etc  to 1;2;3;5  etc
    ival=(ival/10)+1
    -- get the label and return
    for lbl in string.gmatch(itab, "[^|,]+") do
      cnt=cnt+1
      if cnt == ival then
				print_to_log(2, "-< getSelectorStatusLabel found: "..lbl,cnt,itab)
        return lbl
      end
    end
  end
  print_to_log(2, "-< getSelectorStatusLabel not found: "..ival,cnt,itab)
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

-----------------------------------------------
--- START the main process handler
-----------------------------------------------
function dtgmenu_module.handler(menu_cli,SendTo)
  -- initialise the user table in case it runs the firsttime
  -- rebuilt the total commandline after dtgmenu
  local commandline = ""  -- need to rebuild the commndline for feedng back
  local commandlinex = ""  -- need to rebuild the commndline for feedng back
  local parsed_command = {} -- rebuild table without the dtgmenu command in case we need to hand it back as other command
  for nbr,param in pairs(menu_cli) do
    print_to_log(2,"  param:",param)
    if nbr > 2 then
      commandline = commandline .. param .. " "
    end
    if nbr < 2 or nbr > 3 then
      table.insert(parsed_command, param)
      commandlinex = commandlinex .. param .. " "
    end
  end
  commandline = tostring(commandline)
  commandline = string.sub(commandline,1,string.len(commandline)-1)
  local lcommandline = string.lower(commandline)
  --
  print_to_log(0,"==> dtgmenu.lua process:" .. commandline)
  print_to_log(1," => SendTo:",SendTo)
  --
  local param1 = ""
  local param2 = ""
  local param3 = ""
  local param4 = ""
  local cmdisaction  = false
  local cmdisbutton  = false
  local cmdissubmenu = false
  -- get all parameters
  if menu_cli[3] ~= nil then
    param1  = tostring(menu_cli[3])
    cmdissubmenu = true
    cmdisbutton = false
    cmdisaction = false
  end
  if param1 == "" then
    param1 = "menu"
  end
  local lparam1 = string.lower(param1)
  --
  if menu_cli[4] ~= nil then
    param2  = tostring(menu_cli[4])
    cmdissubmenu = false
    cmdisbutton = true
    cmdisaction = false
  end
  if menu_cli[5] ~= nil then
    param3  = tostring(menu_cli[5])
    cmdissubmenu = false
    cmdisbutton = false
    cmdisaction = true
  end
  --
  if menu_cli[6] ~= nil then
    param4  = tostring(menu_cli[6])
  end
  print_to_log(1," => commandline  :",commandline)
  print_to_log(1," => commandlinex :",commandlinex)
  print_to_log(1," => param1       :",param1)
  print_to_log(1," => param2       :",param2)
  print_to_log(1," => param3       :",param3)
  print_to_log(1," => param4       :",param4)
  print_to_log(1,' => cmdisaction :',cmdisaction)
  print_to_log(1,' => cmdisbutton :',cmdisbutton)
  print_to_log(1,' => cmdissubmenu:',cmdissubmenu)

  -------------------------------------------------
  -- Process "start" or "menu" commands
  -------------------------------------------------
  -- Build main menu and return
  if param1 == "menu" or param1 == "start" then
    response=dtgmenu_lang[menu_language].text["main"]
    replymarkup = makereplymenu(SendTo, "mainmenu")
    status=1
    print_to_log(0,"==< Show main menu")
    return status, response, replymarkup, commandline
  end
  -------------------------------------------------
  -- Process "exit" command
  -------------------------------------------------
  -- Exit menu
  if param1 == "exit" then
    -- Clear menu end set exxit messge
    response=dtgmenu_lang[menu_language].text["exit"]
    replymarkup = ""
    status=1
    print_to_log(0,"==< Exit main menu")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- continue set local variables
  -------------------------------------------------
  local submenu    = param1
  local devicename = param2
  local action     = param3
  local status     = 0
  local response = ""
  local DeviceType = "devices"
  local SwitchType = ""
  local idx        = ""
  local Type       = ""
  local dstatus    = ""
  local MaxDimLevel= 0
  local LevelNames = ""
  local LevelInt=0
  if cmdissubmenu then
    submenu    = param1
  end

  local dummy
  ----------------------------------------------------------------------
  -- Set needed variables when the command is a known action menu button
  ----------------------------------------------------------------------
  if cmdisbutton or cmdisaction then
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    print_to_log(1,' => devicename :',devicename)
    print_to_log(1,' => realdevicename :',realdevicename)
    print_to_log(1,' => idx:',idx)
    print_to_log(1,' => Type :',Type)
    print_to_log(1,' => DeviceType :',DeviceType)
    print_to_log(1,' => SwitchType :',SwitchType)
    print_to_log(1,' => MaxDimLevel :',MaxDimLevel)
    if DeviceType ~= "command" then
      dummy,dummy,dummy,dummy,dummy,dummy,dstatus,LevelNames,LevelInt = devinfo_from_name(idx,realdevicename,DeviceType)
      print_to_log(1,' => dstatus    :',dstatus)
      print_to_log(1,' => LevelNames :',LevelNames)
      print_to_log(1,' => LevelInt   :',LevelInt)
    end
  end

  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- process Type="command" (none devices/scenes
  -------------------------------------------------
  if Type == "command" then
    if cmdisaction
    or (cmdisbutton
    and ChkEmpty(dtgmenu_submenus[submenu].buttons[devicename].actions)) then
      status=0
      replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
      print_to_log(0,"==<1 found regular lua command. -> hand back to dtgbot to run",commandlinex,parsed_command[2])
      return status, "", replymarkup, parsed_command
    end
  end
  -------------------------------------------------
  -- process submenu button pressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    print_to_log(1,' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      print_to_log(1," -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=dtgmenu_lang[menu_language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. dtgmenu_lang[menu_language].text["Select"]
    end
    status=1
    print_to_log(0,"==< show options in submenu.")
    return status, response, replymarkup, commandline;
  end

  -------------------------------------------------------
  -- process device button pressed on one of the submenus
  -------------------------------------------------------
  status=1
  if cmdisbutton then
    -- create reply menu and update table with device details
    replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename)
    local switchstatus=""
    local found=0
    if DeviceType == "scenes" then
      if Type == "Group" then
        response = dtgmenu_lang[menu_language].text["SelectGroup"]
        print_to_log(0,"==< Show group options menu plus other devices in submenu.")
      else
        response = dtgmenu_lang[menu_language].text["SelectScene"]
        print_to_log(0,"==< Show scene options menu plus other devices in submenu.")
      end
    elseif dtgbot_type_status[Type] ~= nil and dtgbot_type_status[Type].DisplayActions == false then
      -- when temp device is selected them just return with resetting keyboard and ask to select device.
      status=1
      response=dtgmenu_lang[menu_language].text["SelectOption"]..dstatus
      print_to_log(1,"==< Don't do anything as a temp device was selected.")
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
          switchstatus = getSelectorStatusLabel(LevelNames,LevelInt)
        end
        response = dtgmenu_lang[menu_language].text["SelectOptionwo"].. devicename .. "(" .. switchstatus .. ")"
      else
        switchstatus = dstatus
        response = dtgmenu_lang[menu_language].text["SelectOptionwo"].. devicename .. " " ..dtgmenu_lang[menu_language].text["SelectOption"] .. " " .. switchstatus
      end
      print_to_log(0,"==< Show device options menu plus other devices in submenu.")
    else
      response = dtgmenu_lang[menu_language].text["Select"]
      print_to_log(0,"==< Show options menu plus other devices in submenu.")
    end

    return status, response, replymarkup, commandline;
  end

  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  -- Specials
  -------------------------------------------------
  print_to_log(1,"   -> Start Action:"..action)
  if Type == "Thermostat" then
    -- Set Temp + or - .5 degrees
    if action == "+" or action == "-" then
      dstatus = dstatus:gsub("°C", "")
      dstatus = dstatus:gsub("°F", "")
      dstatus = dstatus:gsub(" ", "")
      action = tonumber(dstatus) + tonumber(action.."0.5")
    end
    -- set thermostate temperature
    local t,jresponse
    t = server_url.."/json.htm?type=command&param=udevice&idx="..idx.."&nvalue=0&svalue="..action
    print_to_log(1,"JSON request <"..t..">");
    jresponse, status = http.request(t)
    print_to_log(1,"JSON feedback: ", jresponse)
    response="Set "..realdevicename.." to "..action
  elseif SwitchType=="Selector" then
    local sfound,Selector_Option = ChkInTable(LevelNames,action)
    if sfound then
      Selector_Option=(Selector_Option-1)*10
      print_to_log(2,"    -> Selector Switch level found ", Selector_Option,LevelNames,action)
      response=sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level "..Selector_Option)
    else
      response= "Selector Option not found:"..action
    end
  -------------------------------------------------
  -- regular On/Off/Set Level
  -------------------------------------------------
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["Off"]),string.lower(action)) then
    response= sSwitchName(realdevicename,DeviceType,SwitchType,idx,'Off')
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["On"]),string.lower(action)) then
    response= sSwitchName(realdevicename,DeviceType,SwitchType,idx,'On')
  elseif string.find(action, "%d") then  -- assume a percentage is specified.
    -- calculate the proper level to set the dimmer
    action = action:gsub("%%","") -- remove % sign
    rellev = tonumber(action)*MaxDimLevel/100  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response= sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  elseif action == "+" or action == "-" then
    -- calculate the proper leve lto set the dimmer
    dstatus=status2number(dstatus)
    print_to_log(2," + or - command: dstatus:",tonumber(dstatus),"action..10:",action.."10")
    action = tonumber(dstatus) + tonumber(action.."10")
    if action > 100 then action = 100 end
    if action < 0 then action = 0 end
    rellev = MaxDimLevel/100*tonumber(action)  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response=sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  -------------------------------------------------
  -- Unknown Action
  -------------------------------------------------
  else
    response = dtgmenu_lang[menu_language].text["UnknownChoice"] .. action
  end
  status=1

  replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename)
  print_to_log(0,"==< "..response)
  return status, response, replymarkup, commandline;
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------

local dtgmenu_commands = {
  ["menu"] = {handler=dtgmenu_module.handler, description="Menu (will start the DTGMenu function."},
}

function dtgmenu_module.get_commands()
  return dtgmenu_commands;
end

-- define the menu table and initialize the table first time
buttonnbr = 0
Menuidx=0
Menuval="Off"
dtgmenu_submenus = {}
PopulateMenuTab(1,"")

return dtgmenu_module;
