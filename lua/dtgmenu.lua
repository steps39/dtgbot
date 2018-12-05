-- =====================================================================================================================
-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to perform actions on:
--  - all defined devices per defined ROOM in Domotics.
--  - all static actions defined in DTGMENU.CFG. Open the file for descript of the details.
--
-- programmer: Jos van der Zande
-- version: 0.1.171231
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
--// exportstring( string )
--// returns a "Lua" portable version of the string
local function exportstring( s )
  return string.format("%q", s)
end

--// The Save Function
function table.save(tbl,tblname)
  local charS,charE = "   ","\n"
  local filename = BotLuaScriptPath.."dtgmenu_"..tblname..".tbl"
  local file,err = io.open( filename, "wb" )
  if err then return err end

  -- initiate variables for save procedure
  local tables,lookup = { tbl },{ [tbl] = 1 }
  file:write( "return {"..charE )

  for idx,t in ipairs( tables ) do
     file:write( "-- Table: {"..idx.."}"..charE )
     file:write( "{"..charE )
     local thandled = {}

     for i,v in ipairs( t ) do
        thandled[i] = true
        local stype = type( v )
        -- only handle value
        if stype == "table" then
           if not lookup[v] then
              table.insert( tables, v )
              lookup[v] = #tables
           end
           file:write( charS.."{"..lookup[v].."},"..charE )
        elseif stype == "string" then
           file:write(  charS..exportstring( v )..","..charE )
        elseif stype == "number" then
           file:write(  charS..tostring( v )..","..charE )
        end
     end

     for i,v in pairs( t ) do
        -- escape handled values
        if (not thandled[i]) then

           local str = ""
           local stype = type( i )
           -- handle index
           if stype == "table" then
              if not lookup[i] then
                 table.insert( tables,i )
                 lookup[i] = #tables
              end
              str = charS.."[{"..lookup[i].."}]="
           elseif stype == "string" then
              str = charS.."["..exportstring( i ).."]="
           elseif stype == "number" then
              str = charS.."["..tostring( i ).."]="
           end

           if str ~= "" then
              stype = type( v )
              -- handle value
              if stype == "table" then
                 if not lookup[v] then
                    table.insert( tables,v )
                    lookup[v] = #tables
                 end
                 file:write( str.."{"..lookup[v].."},"..charE )
              elseif stype == "string" then
                 file:write( str..exportstring( v )..","..charE )
              elseif stype == "number" then
                 file:write( str..tostring( v )..","..charE )
              end
           end
        end
     end
     file:write( "},"..charE )
  end
  file:write( "}" )
  file:close()
end

--// The Load Function
function table.load( tblname )
  local sfile = BotLuaScriptPath.."dtgmenu_"..tblname..".tbl"
  local ftables,err = loadfile( sfile )
  if err then return _,err end
  local tables = ftables()
  for idx = 1,#tables do
     local tolinki = {}
     for i,v in pairs( tables[idx] ) do
        if type( v ) == "table" then
           tables[idx][i] = tables[v[1]]
        end
        if type( i ) == "table" and tables[i[1]] then
           table.insert( tolinki,{ i,tables[i[1]] } )
        end
     end
     -- link indices
     for _,v in ipairs( tolinki ) do
        tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
     end
  end
  return tables[1]
end
--
function printtbl( t,tab,lookup )
   local lookup = lookup or { [t] = 1 }
   local tab = tab or ""
   for i,v in pairs( t ) do
      print( tab..tostring(i), v )
      if type(i) == "table" and not lookup[i] then
         lookup[i] = 1
         print( tab.."Table: i" )
         printtbl( i,tab.."\t",lookup )
      end
      if type(v) == "table" and not lookup[v] then
         lookup[v] = 1
         print( tab.."Table: v" )
         printtbl( v,tab.."\t",lookup )
      end
   end
end
--------------------------------------
-- Include config
--------------------------------------
local config=""
if (file_exists(BotHomePath.."dtgbot-user.cfg")) then
  config = assert(loadfile(BotHomePath.."lua/dtgmenu-user.cfg"))();
  print_to_log ("Using DTGMENU config file:"..BotHomePath.."lua/dtgmenu-user.cfg")
else
  config = assert(loadfile(BotHomePath.."lua/dtgmenu.cfg"))();
  print_to_log ("Using DTGMENU config file:"..BotHomePath.."lua/dtgmenu.cfg")
end

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
-- declare local variables
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
  print_to_log(1,"Start makereplymenu:",SendTo, Level, submenu, devicename)

  ------------------------------------------------------------------------------
  -- First build the dtgmenu_submenus table with the required level information
  ------------------------------------------------------------------------------
--~ moved to refresh:   PopulateMenuTab(Level,submenu)

  ------------------------------------------------------------------------------
  -- start the build of the 3 levels of the keyboard menu
  ------------------------------------------------------------------------------
  print_to_log(1,"  -> makereplymenu  Level:",Level,"submenu",submenu,"devicename",devicename)
  local t=1
  local l1menu=""
  local l2menu=""
  local l3menu=""
--~   Sort & Loop through the compiled options returned by PopulateMenuTab
  for i,get in orderedPairs(dtgmenu_submenus) do
    -- ==== Build mainmenu - level 1 which is the bottom part of the menu, showing the Rooms and static definitins
    -- Avoid adding start and menu as these are handled separately.
    if i ~= "menu" and i ~= "start" then
      if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
        l1menu=l1menu .. i .. "|"
      end
    end
  end
-- ==== Build Submenu - showing the Devices from the selected room of static config
--                      This will also add the device status when showdevstatus=true for the option.
  print_to_log(1,'submenu: '..submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil
    and dtgmenu_submenus[submenu].buttons ~= nil then
      -- loop through all devined "buttons in the Config
      for i,get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
        print_to_log(1," Submenu item:",i,get.submenu)
        -- process all found devices in  dtgmenu_submenus buttons table
        if i ~= "" then
          local switchstatus = ""
          print_to_log(1,"   - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          local didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            -- add the device status to the button when requested
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel,switchstatus,LevelNames,LevelInt = devinfo_from_name(get.idx,get.Name,get.DeviceType)
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
                if dSwitchType == "Selector" then
                  switchstatus = " - "..getSelectorStatusLabel(get.actions,LevelInt)
                else
                  switchstatus = tostring(switchstatus)
                  switchstatus = switchstatus:gsub("Set Level: ", "")
                  switchstatus = " - " .. switchstatus
--~ 							print_to_log(0,switchstatus)
                end
              end
            end
            -- add to the total menu string for later processing
            l2menu=l2menu .. i .. switchstatus .. "|"
            -- show the actions menu immediately for this devices since that is requested in the config
            -- this can avoid having the press 2 button before getting to the actions menu
            if get.showactions and devicename == "" then
              print_to_log(1,"  - Changing to Device action level due to showactions:",i)
              Level = "devicemenu"
              devicename = i
            end
          end
        end
        print_to_log(1,l2menu)
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
                  l3menu = "Aan,Uit"
                end
              end
            end
            print_to_log(1,"   -< ".. tostring(SwitchType).." using replymarkup:",l3menu)
          end
        end
      end
    end
  end
  -------------------------------------------------------------------
  -- Start building the proper layout for the 3 levels of menu items
  -------------------------------------------------------------------
  -- Always add "menu" as last option to level1 menu
  l1menu=l1menu .. "menu"
  ------------------------------
  -- start build total replymarkup
  local replymarkup = '{"keyboard":['
  ------------------------------
  -- Add level 3 first if needed
  ------------------------------
  if l3menu ~= "" then
    replymarkup = replymarkup .. buildmenu(l3menu,ActMenuwidth,"") .. ","
    l1menu = "menu"
  end
  ------------------------------
  -- Add level 2 next if needed
  ------------------------------
  if l2menu ~= "" then
    local mwitdh=DevMenuwidth
    if dtgmenu_submenus[submenu].Menuwidth ~= nil then
      if tonumber(dtgmenu_submenus[submenu].Menuwidth) >= 2 then
        mwitdh=tonumber(dtgmenu_submenus[submenu].Menuwidth)
      end
    end
    replymarkup = replymarkup .. buildmenu(l2menu,mwitdh,"") .. ","
    l1menu = "menu"
  end
  -------------------------------
  -- Add level 1 -- the main menu
  --------------------------------
  replymarkup = replymarkup .. buildmenu(l1menu,SubMenuwidth,"") .. ']'
  -- add the resize menu option when desired. this sizes the keyboard menu to the size required for the options
  if AlwaysResizeMenu then
--~     replymarkup = replymarkup .. ',"resize_keyboard":true'
    replymarkup = replymarkup .. ',"selective":true,"resize_keyboard":true'
  end
  -- Close the total statement
  replymarkup = replymarkup .. '}'

  -- save the full replymarkup and only send it again when it changed to minimize traffic to the TG client
  if LastCommand[SendTo]["replymarkup"] == replymarkup then
    print_to_log(0,"  -< replymarkup: No update needed")
    replymarkup=""
  else
    print_to_log(0,"  -< replymarkup:"..replymarkup)
    LastCommand[SendTo]["replymarkup"] = replymarkup
  end
-- save menus
  LastCommand[SendTo]["l1menu"] = l1menu  -- rooms or submenu items
  LastCommand[SendTo]["l2menu"] = l2menu  -- Devices scenes or commands
  LastCommand[SendTo]["l3menu"] = l3menu  -- actions
  table.save(LastCommand,"LastCommand")
  return replymarkup, devicename
end
-- convert the provided menu options into a proper format for the replymenu
function buildmenu(menuitems,width,extrachar)
  local replymenu=""
  local t=0
  print_to_log(1," process buildmenu:",menuitems," w:",width)
  for dev in string.gmatch(menuitems, "[^|,]+") do
    if t == width then
      replymenu = replymenu .. '],'
      t = 0
    end
    if t == 0 then
      replymenu = replymenu .. '["' .. extrachar .. '' .. dev .. '"'
    else
      replymenu = replymenu .. ',"' .. extrachar .. '' .. dev .. '"'
    end
    t = t + 1
  end
  if replymenu ~= "" then
    replymenu = replymenu .. ']'
  end
  print_to_log(1,"    -< buildmenu:",replymenu)
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
function PopulateMenuTab(iLevel,iSubmenu)
  print_to_log(1,"####  Start populating menuarray")
  -- reset menu table and rebuild
  dtgmenu_submenus = {}

  print_to_log(1,"Submenu table including buttons defined in menu.cfg:",iLevel,iSubmenu)
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
          buttons[button].prompt=dev.prompt               -- specific for the static config: Prompt TG cleint for the variable text
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
            buttons[button].prompt=false               -- Not implemented for Dynamic menu: Prompt TG cleint for the variable text
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
  print_to_log(2, " getSelectorStatusLabel: ",ival,itab)
  local cnt=0
  --
  if itab ~= nil then
    -- convert 0;10;20;30  etc  to 1;2;3;5  etc
    if ival > 9 then
      ival=(ival/10)
    end
    -- get the label and return
    for lbl in string.gmatch(itab, "[^|,]+") do
      if cnt == ival then
        print_to_log(0, "-< getSelectorStatusLabel found: "..lbl,cnt,itab)
        return lbl
      end
      cnt=cnt+1
    end
  end
  print_to_log(0, "-< getSelectorStatusLabel not found: "..ival,cnt,itab)
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
  if LastCommand[SendTo] == nil then
    LastCommand[SendTo] = {}
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["replymarkup"] = ""
    LastCommand[SendTo]["prompt"] = false
  end
  --~	split the commandline into parameters
  local dtgmenu_cli={}
  for w in string.gmatch(menu_cli[2], "([%w-_?%%++><&-**]+)") do
    table.insert(dtgmenu_cli, w)
  end
  --
  print_to_log(0,"==> menu.lua process:" ..  menu_cli[2])
  print_to_log(1," => SendTo:",SendTo)
  local commandline = menu_cli[2]
  local command = tostring(dtgmenu_cli[1])
  local lcommand = string.lower(command)
  local lcommandline = string.lower(commandline)
  local param1 = ""
  -- Retrieve the first parameter after the command in case provided.
  if menu_cli[3] ~= nil then
    param1  = tostring(menu_cli[3])    -- the command came in through the standard DTGBOT process
  elseif dtgmenu_cli[2] ~= nil then
    param1  = tostring(dtgmenu_cli[2]) -- the command came in via the DTGMENU exit routine
  end
  print_to_log(1," => commandline  :",commandline)
  print_to_log(1," => command      :",command)
  print_to_log(1," => param1       :",param1)
  print_to_log(1,' => Lastmenu submenu  :',LastCommand[SendTo]["l1menu"])
  print_to_log(1,' => Lastmenu devs/cmds:',LastCommand[SendTo]["l2menu"])
  print_to_log(1,' => Lastmenu actions  :',LastCommand[SendTo]["l3menu"])
  print_to_log(1,' => Lastcmd prompt :',LastCommand[SendTo]["prompt"])
  print_to_log(1,' => Lastcmd submenu:',LastCommand[SendTo]["submenu"])
  print_to_log(1,' => Lastcmd device :',LastCommand[SendTo]["device"])

  -------------------------------------------------
  -- set local variables
  -------------------------------------------------
  local lparam1 = string.lower(param1)
  local cmdisaction  = ChkInTable(LastCommand[SendTo]["l3menu"],commandline)
  local cmdisbutton  = ChkInTable(LastCommand[SendTo]["l2menu"],commandline)
  local cmdissubmenu = ChkInTable(LastCommand[SendTo]["l1menu"],commandline)
  -- When the command is not a button or submenu and the last Action options contained a "?" and the current command is numeric we assume this is a manual set percentage
  if not (cmdisaction or cmdisbutton or cmdisbutton) and ChkInTable(LastCommand[SendTo]["l3menu"],"?") and string.find(command, "%d") then
    cmdisaction = true
  end
  -- Check just the command Command if all False
  -------------------------------------------------
  -- Process "dtgmenu  (On/Off)" command
  -------------------------------------------------
  -- Set DTGMENU On/Off
  if lcommand == "dtgmenu" then
    Menuidx = idx_from_variable_name("TelegramBotMenu")
    if Menuidx == nil then
      Menuval = "Off"
    else
      Menuval = get_variable_value(Menuidx)
    end
    response="DTGMENU is currently "..Menuval
    if Menuval == "On" and (lparam1 == "off" or lparam1 == "") then
      print_to_log(0, " Set DTGMENU Off")
      response="DTGMENU is now disabled. send DTGMENU to start the menus again."
      replymarkup='{"hide_keyboard":true}'
      set_variable_value(Menuidx,"TelegramBotMenu",2,"Off")
      LastCommand[SendTo]["replymarkup"]=""
      Menuval = "Off"
    elseif Menuval == "Off" and (lparam1 == "on" or lparam1 == "") then
      print_to_log(0, " Set DTGMENU On")
      if Menuidx == nil then
        create_variable("TelegramBotMenu",2,"On")
      else
        set_variable_value(Menuidx,"TelegramBotMenu",2,"On")
      end
      -- initialise the tables when switched on
      dtgbot_initialise()
      -- initialise user table
      LastCommand[SendTo] = {}
      LastCommand[SendTo]["submenu"] = ""
      LastCommand[SendTo]["device"] = ""
      LastCommand[SendTo]["l1menu"] = ""
      LastCommand[SendTo]["l2menu"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      LastCommand[SendTo]["replymarkup"] = ""
      LastCommand[SendTo]["prompt"] = false
      -- buld main menu
      replymarkup = makereplymenu(SendTo, "mainmenu")
      response="DTGMENU is now enabled. send DTGMENU again to stop the menus."
    elseif Menuval == "On" then
      -- reset menu to main menu in case dtgmenu command is send
      response=dtgmenu_lang[menu_language].text["main"]
      replymarkup = makereplymenu(SendTo, "mainmenu")
    end
      status=1
    print_to_log(0,"==< Show main menu")
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline
  end
  -------------------------------------------------
  -- Process "start" or "menu" commands
  -------------------------------------------------
  -- Build main menu and return
  if cmdisaction == false and(lcommand == "menu" or lcommand == "start") then
    -- ensure the menu is always rebuild for Menu or Start
    LastCommand[SendTo]["replymarkup"]=""
    response=dtgmenu_lang[menu_language].text["main"]
    replymarkup = makereplymenu(SendTo, "mainmenu")
    status=1
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    print_to_log(0,"==< Show main menu")
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- process prompt input for "command" Type
  -------------------------------------------------
  -- When returning from a "prompt"action" then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
  if LastCommand[SendTo]["prompt"] then
    -- make small keyboard
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 0
    response = ""
    -- add previous command ot the current command
    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log(0,"==<1a prompt and found regular lua command and param was given. -> hand back to dtgbot to run",commandline)
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline
  end

  -----------------------------------------------------
  -- process when command is not known in the last menu
  -----------------------------------------------------
  -- hand back to DTGBOT reset keyboard to just MENU
  if cmdisaction == false
  and cmdisbutton == false
  and cmdissubmenu == false then
    -- make small keyboard
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 0 -- this triggers dtgbot to reset the parsed_command[2}=response and parsed_command[3}=command
    response = ""
--    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log(0,"==<1b found regular lua command and param was given. -> hand back to dtgbot to run",commandline )
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- continue set local variables
  -------------------------------------------------
  local submenu    = ""
  local devicename = ""
  local action     = ""
  local status     = 0
  local response = ""
  local DeviceType = "devices"
  local SwitchType = ""
  local idx        = ""
  local Type       = ""
  local dstatus     = ""
  local MaxDimLevel= 0
  if cmdissubmenu then
    submenu    = commandline
  end

  ----------------------------------------------------------------------
  -- Set needed variable when the command is a known device menu button
  ----------------------------------------------------------------------
  if cmdisbutton then
    submenu    = LastCommand[SendTo]["submenu"]
    devicename = command  -- use command as that should only contain the values of the first param
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel= dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    dstatus    = dtgmenu_submenus[submenu].buttons[devicename].status
    print_to_log(1,' => devicename :',devicename)
    print_to_log(1,' => realdevicename :',realdevicename)
    print_to_log(1,' => idx:',idx)
    print_to_log(1,' => Type :',Type)
    print_to_log(1,' => DeviceType :',DeviceType)
    print_to_log(1,' => SwitchType :',SwitchType)
    print_to_log(1,' => MaxDimLevel:',MaxDimLevel)
    if DeviceType ~= "command" then
      dummy,dummy,dummy,dummy,dummy,dummy,dstatus,LevelNames,LevelInt = devinfo_from_name(idx,realdevicename,DeviceType)
      print_to_log(1,' => dstatus    :',dstatus)
      print_to_log(1,' => LevelNames :',LevelNames)
      print_to_log(1,' => LevelInt   :',LevelInt)
    end
  end
  ----------------------------------------------------------------------
  -- Set needed variables when the command is a known action menu button
  ----------------------------------------------------------------------
  if cmdisaction then
    submenu    = LastCommand[SendTo]["submenu"]
    devicename = LastCommand[SendTo]["device"]
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    action     = lcommand  -- use lcommand as that should only contain the values of the first param
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    if DeviceType ~= "command" then
      dummy,dummy,dummy,dummy,dummy,dummy,dstatus,LevelNames,LevelInt = devinfo_from_name(idx,realdevicename,DeviceType)
      print_to_log(1,' => dstatus    :',dstatus)
      print_to_log(1,' => LevelNames :',LevelNames)
      print_to_log(1,' => LevelInt   :',LevelInt)
    end
    print_to_log(1,' => devicename :',devicename)
    print_to_log(1,' => realdevicename :',realdevicename)
    print_to_log(1,' => idx:',idx)
    print_to_log(1,' => Type :',Type)
    print_to_log(1,' => DeviceType :',DeviceType)
    print_to_log(1,' => SwitchType :',SwitchType)
    print_to_log(1,' => MaxDimLevel:',MaxDimLevel)
    print_to_log(1,' => LevelNames :',LevelNames)
  end
  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- process Type="command" (none devices/scenes
  -------------------------------------------------
  if Type == "command" then
    --  when Button is pressed and Type "command" and no actions defined for the command then check for prompt and hand back without updating the keyboard
    if cmdisbutton
    and ChkEmpty(dtgmenu_submenus[submenu].buttons[command].actions) then
      -- prompt for parameter when requested in the config
      if dtgmenu_submenus[LastCommand[SendTo]["submenu"]].buttons[commandline].prompt then
        LastCommand[SendTo]["device"] = commandline
        LastCommand[SendTo]["prompt"] = true
        replymarkup='{"force_reply":true}'
        LastCommand[SendTo]["replymarkup"] = replymarkup
        status = 1
        response=dtgmenu_lang[menu_language].text["Specifyvalue"]
        print_to_log(0,"==<1 found regular lua command that need Param ")

        -- no prompt defined so simply return to dtgbot with status 0 so it will be performed and reset the keyboard to just MENU
      else
        replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
        status = 0
        LastCommand[SendTo]["submenu"] = ""
        LastCommand[SendTo]["device"] = ""
        LastCommand[SendTo]["l1menu"] = ""
        LastCommand[SendTo]["l2menu"] = ""
        LastCommand[SendTo]["l3menu"] = ""
        print_to_log(0,"==<1 found regular lua command. -> hand back to dtgbot to run")
      end
      table.save(LastCommand,"LastCommand")
      return status, response, replymarkup, commandline
    end

    --  when Action is pressed and Type "command"  then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
    if devicename ~= ""
    and cmdisaction then
      --  if command is one of the actions of a command DeviceType hand it now back to DTGBOT
      replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
      response = ""
      -- add previous command ot the current command
      commandline = LastCommand[SendTo]["device"] .. " " .. commandline
      LastCommand[SendTo]["submenu"] = ""
      LastCommand[SendTo]["device"] = ""
      LastCommand[SendTo]["l1menu"] = ""
      LastCommand[SendTo]["l2menu"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      print_to_log(0,"==<2 found regular lua command. -> hand back to dtgbot to run:"..LastCommand[SendTo]["device"].. " " .. commandline )
      table.save(LastCommand,"LastCommand")
      return status, response, replymarkup, commandline
    end
  end

  -------------------------------------------------
  -- process submenu button pressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    LastCommand[SendTo]["submenu"]=submenu
    print_to_log(1,' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      LastCommand[SendTo]["device"] = rdevicename
      print_to_log(1," -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=dtgmenu_lang[menu_language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. dtgmenu_lang[menu_language].text["Select"]
    end
    status=1
    print_to_log(0,"==< show options in submenu.")
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------------
  -- process device button pressed on one of the submenus
  -------------------------------------------------------
  status=1
  if cmdisbutton then
    -- create reply menu and update table with device details
    replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename)
    -- Save the current device
    LastCommand[SendTo]["device"] = devicename
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
--~     elseif Type == "Temp" or Type == "Temp + Humidity" or Type == "Wind" or Type == "Rain" then
    elseif dtgbot_type_status[Type] ~= nil and dtgbot_type_status[Type].DisplayActions == false then
      -- when temp device is selected them just return with resetting keyboard and ask to select device.
      status=1
      response=dtgmenu_lang[menu_language].text["Select"]
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
        response = dtgmenu_lang[menu_language].text["SelectOptionwo"]
      else
        switchstatus = dstatus
        response = dtgmenu_lang[menu_language].text["SelectOption"] .. " " .. switchstatus
      end
      print_to_log(0,"==< Show device options menu plus other devices in submenu.")
    else
      response = dtgmenu_lang[menu_language].text["Select"]
      print_to_log(0,"==< Show options menu plus other devices in submenu.")
    end
    table.save(LastCommand,"LastCommand")
    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  -- Specials
  -------------------------------------------------
  if Type == "Thermostat" then
    -- prompt for themperature
    if commandline == "?" then
      replymarkup='{"force_reply":true}'
      LastCommand[SendTo]["replymarkup"] = replymarkup
      response=dtgmenu_lang[menu_language].text["Specifyvalue"]
      print_to_log(0,"==< "..response)
      status=1
      return status, response, replymarkup, commandline;
    else
      if commandline == "+" or commandline == "-" then
        dstatus = dstatus:gsub("°C", "")
        dstatus = dstatus:gsub("°F", "")
        dstatus = dstatus:gsub(" ", "")
        commandline = tonumber(dstatus) + tonumber(commandline.."0.5")
      end
      -- set thermostate temperature
      local t,jresponse
      t = server_url.."/json.htm?type=command&param=udevice&idx="..idx.."&nvalue=0&svalue="..commandline
      print_to_log(1,"JSON request <"..t..">");
      jresponse, status = http.request(t)
      print_to_log(1,"JSON feedback: ", jresponse)
      response="Set "..realdevicename.." to "..commandline.."°C"
    end
  elseif SwitchType=="Selector" then
    local sfound,Selector_Option = ChkInTable(string.lower(LevelNames),string.lower(action))
    if sfound then
      Selector_Option=(Selector_Option)*10
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
    -- calculate the proper level to set the dimmer
    dstatus=status2number(dstatus)
    print_to_log(2," + or - command: dstatus:",tonumber(dstatus),"action..10:",action.."10")
    action = tonumber(dstatus) + tonumber(action.."10")
    if action > 100 then action = 100 end
    if action < 0 then action = 0 end
    rellev = MaxDimLevel/100*tonumber(action)  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response= sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  elseif commandline == "?" then
    replymarkup='{"force_reply":true}'
    LastCommand[SendTo]["replymarkup"] = replymarkup
    response=dtgmenu_lang[menu_language].text["Specifyvalue"]
    print_to_log(0,"==<"..response)
    status=1
    return status, response, replymarkup, commandline;
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
  ["dtgmenu"] = {handler=dtgmenu_module.handler, description="DTGMENU (will toggle On/Off) to start/stop the menu functionality."},
}

function dtgmenu_module.get_commands()
  return dtgmenu_commands;
end

-- define the menu table and initialize the table first time
Menuidx=0
Menuval="Off"
dtgmenu_submenus = {}
--~ PopulateMenuTab(1,"")  -- now done in refresh

return dtgmenu_module;
