-- =====================================================================================================================
-- Menu script which enables the option in TG BOT to use a reply keyboard to do the commands in stead of typing them.
-- The menu configuration is done in dtgbot.cfg.
-- programmer: Jos van der Zande
-- version: 0.1.150816
-- =====================================================================================================================
-- these are the different formats of reply_markup. look simple but needed a lot of testing before it worked :)

--show the custom keyboard and stay up after option selection first 3 on the first line and menu on the second
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]]}

--show the custom keyboard and minimises after option selection
--	reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"one_time_keyboard":true}

--Remove the custom keyboard
--	reply_markup={"hide_keyboard":true}
--	reply_markup={"hide_keyboard":true,"selective":false}

--force normal keyboard to ask for input
--	reply_markup={"force_reply":true}
--	reply_markup={"force_reply":true,"selective":false}

--Resize the keyboard
--	reply_markup={"keyboard":[["menu"]],"resize_keyboard":true}
--  reply_markup={"keyboard":[["opt 1","opt 2","opt 3"],["menu"]],"resize_keyboard":true}

local config = assert(loadfile(BotHomePath.."lua/dtgmenu.cfg"))();
local dtgmenu_module = {};

local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

--------------------------------------
-- Start Functions to SORT the TABLE
--------------------------------------
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
    --print("orderedNext: state = "..tostring(state) )
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
--------------------------------------
-- END Functions to SORT the TABLE
--------------------------------------


-----------------------------------------------
-- Start Functions to set and retrieve status.
-----------------------------------------------
function SwitchName(DeviceName, DeviceType, SwitchType,idx,state)
  local status
--~ 	print("=== Start SwitchName ==> ")
--~ 	idx, Type = idx_from_name(DeviceName,DeviceType)
--~ 	print(Type)
  if idx == nil then
       response = 'Device '..DeviceName..'  not found.'
  else
    local subgroup = "light"
    if DeviceType == "scenes" then
      subgroup = "scene"
    end
    if string.lower(state) == "on" then
          state = "On";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
        elseif string.lower(state) == "off" then
          state = "Off";
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd="..state;
    elseif string.lower(string.sub(state,1,9)) == "set level" then
      t = server_url.."/json.htm?type=command&param=switch"..subgroup.."&idx="..idx.."&switchcmd=Set%20Level&level="..string.sub(state,11)
        else
          return "state must be on, off or Set Level!";
        end
--~         print ("JSON request <"..t..">");
        jresponse, status = http.request(t)
--~         print("JSON feedback: ", jresponse)
        response = dtgmenu_lang[language].text["Switched"] .. ' ' ..DeviceName..' => '..state
  end
  print_to_log("   -< SwitchName:",DeviceName,idx, status,response)
  return response, status
end

-----------------------------------------------
--- START Build the reply_markup functions.
-----------------------------------------------
function makereplymenu(SendTo, Level, submenu, devicename,SwitchType)
  -- mainmenu
  -- submenu
  -- devicemenu
--~ 	print('=== Start makereplymenu ==========================================================')

-- Update Menu to the rreequired level
  print("Start makereplymenu:",SendTo, Level, submenu, devicename,SwitchTyp)
  PopulateMenuTab(Level,submenu)
--
  if submenu == nil then
    submenu = ""
  end
  if devicename == nil then
    devicename = ""
  end
  if SwitchType == nil then
    SwitchType = ""
  end
  print_to_log("  -> makereplymenu  Level:",Level,"submenu",submenu,"devicename",devicename,"SwitchType",SwitchType)
  local t=1
  local l1menu=""
  local l2menu=""
  local l3menu=""
--~   using orderedPairs to sort the entries.
  for i,get in orderedPairs(dtgmenu_submenus) do
--~ 		print(i, get.submenu, get.menuoptions)
    -- ==== Build mainmenu
    if i ~= "menu" and i ~= "start" then
      if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
        l1menu=l1menu .. i .. "|"
      end
    end
  end
-- ==== Build Submenu
--~ print('submenu: '..submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil
    and dtgmenu_submenus[submenu].buttons ~= nil then
      for i,get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
--~ 			print(" #debug1 - Submenu item:",i,get.submenu)
        -- Do not show the selected Device as Keyboard button as you just pressed it
        -- Exception is when the option dtgmenu_submenus[submenu].NoDevMenu is defined as that is just for status display
--~ 				print(" #debug2 - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx)
--~ 				if dtgmenu_submenus[submenu].NoDevMenu then
--~ 				if i ~= devicename or dtgmenu_submenus[submenu].NoDevMenu then
        if i ~= "" or dtgmenu_submenus[submenu].NoDevMenu then
          local switchstatus = ""
          print_to_log("   - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              switchstatus = get.status
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
                switchstatus = tostring(switchstatus)
                switchstatus = switchstatus:gsub("Set Level: ", "")
                switchstatus = " - " .. switchstatus
--~ 							print(switchstatus)
              end
            end
            l2menu=l2menu .. i .. switchstatus .. "|"
            -- show the actions menu immediately for this devices since that is requested in the config
            if get.showactions then
              print_to_log("  - Changing to Device action level due to showactions:",i)
              Level = "devicemenu"
              devicename = i
            end
          end
        end
--~ 				print(l2menu)
        -- ==== Build DeviceActionmenu
        if dtgmenu_submenus[submenu].NoDevMenu ~= true
        and Level == "devicemenu" and i == devicename then
          -- set reply markup to the override when provide
          l3menu = get.actions
          print_to_log(" ---< ",SwitchType," using replymarkup:",l3menu)
          -- else use the default reply menu for the SwitchType
          if l3menu == nil or l3menu == "" then
            l3menu = dtgmenu_lang[language].devices_options[SwitchType]
            if l3menu == nil then
              print_to_log("  !!! No default dtgmenu_lang[language].devices_options for SwitchType:",SwitchType)
              l3menu = "Aan,Uit"
            end
          end
          print_to_log("   -< " .. SwitchType .. " using replymarkup:",l3menu)
        end
      end
    end
  end
  -- Add main as last option
  l1menu=l1menu .. "menu"

  ------------------------------
  -- build total replymarkup
  local replymarkup = '{"keyboard":['
  ------------------------------
  -- Add level 3 first if needed
  if l3menu ~= "" then
    replymarkup = replymarkup .. buildmenu(l3menu,ActMenuwidth,"") .. ","
    l1menu = "menu"
  end
  -- save the level3 menu actions to be able to search them later whne the message is send by TG
  ------------------------------
  -- Add level 2 first if needed
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
  ------------------------------
  -- Add level 1
  replymarkup = replymarkup .. buildmenu(l1menu,SubMenuwidth,"") .. ']'
  -- add the resize menu option when desired
  if AlwaysResizeMenu then
    replymarkup = replymarkup .. ',"resize_keyboard":true'
  end
  -- Cloe the total statement
  replymarkup = replymarkup .. '}'

  -- save the full replymarkup and only send it again when it changed to minimize traffic to the TG client
  if LastCommand[SendTo]["replymarkup"] == replymarkup then
    print_to_log("  -< replymarkup: No update needed")
  else
    print_to_log("  -< replymarkup:"..replymarkup)
    LastCommand[SendTo]["replymarkup"] = replymarkup
  end
-- save menus
  LastCommand[SendTo]["l1menu"] = l1menu  -- rooms or submenu items
  LastCommand[SendTo]["l2menu"] = l2menu  -- Devices scenes or commands
  LastCommand[SendTo]["l3menu"] = l3menu  -- actions
--~ 	print_to_log('=== End makereplymenu ==========================================================')
  return replymarkup, devicename
end
--
function buildmenu(menuitems,width,extrachar)
  local replymenu=""
  local t=0
--~ 	print(" process buildmenu:",menuitems," w:",width)
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
--~ 		print(replymenu)
  end
  if replymenu ~= "" then
    replymenu = replymenu .. ']'
  end
  print_to_log("    -< buildmenu:",replymenu)
  return replymenu
end
-----------------------------------------------
--- END Build the reply_markup functions.
-----------------------------------------------

-----------------------------------------------
--- Start Misc Function to support the process
-----------------------------------------------
-- SCAN through provided delimited string for the second parameter
function ChkInTable(itab,idev)
--~ 	print( " ChkInTable: ", itab)
  if itab ~= nil then
    for dev in string.gmatch(itab, "[^|,]+") do
      if dev == idev then
--~ 				print( "- ChkInTable found: ".. dev)
        return true
      end
    end
  end
--~ 	print( "- ChkInTable not found: "..idev)
  return false
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
    print("init LastCommand[SendTo]")
    LastCommand[SendTo] = {}
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["replymarkup"] = ""
    LastCommand[SendTo]["prompt"] = false
  end
  --~	added "-_"to allowed characters a command/word
  local dtgmenu_cli={}
  for w in string.gmatch(menu_cli[2], "([%w-_]+)") do
    table.insert(dtgmenu_cli, w)
  end
  --
  print_to_log("==> menu.lua Start" )
  print_to_log(" => SendTo:",SendTo)
  local commandline = menu_cli[2]
  local command = tostring(dtgmenu_cli[1])
  local lcommand = string.lower(command)
  local lcommandline = string.lower(commandline)
  local param1
  if menu_cli[3] ~= nil then
    param1  = menu_cli[3]              -- the command came in through the standard process
  else
    param1  = tostring(dtgmenu_cli[2]) -- the command came in via the DTGMENU exit routine
  end
  print_to_log(" => commandline  :",commandline)
  print_to_log(" => command      :",command)
  print_to_log(" => param1       :",param1)
--~ 	print_to_log(" => full commandline  :",menu_cli[2])
--~ 	print_to_log(" => menu_cli[3]       :",tostring(menu_cli[3]))
--~ 	print_to_log(" => dtgmenu_cli[1]    :",dtgmenu_cli[1])
--~ 	print_to_log(" => dtgmenu_cli[2]    :",dtgmenu_cli[2])
  print_to_log(' => Lastmenu submenu  :',LastCommand[SendTo]["l1menu"])
  print_to_log(' => Lastmenu devs/cmds:',LastCommand[SendTo]["l2menu"])
  print_to_log(' => Lastmenu actions  :',LastCommand[SendTo]["l3menu"])
  print_to_log(' => Lastcmd prompt :',LastCommand[SendTo]["prompt"])
  print_to_log(' => Lastcmd submenu:',LastCommand[SendTo]["submenu"])
  print_to_log(' => Lastcmd device :',LastCommand[SendTo]["device"])

  -------------------------------------------------
  -- set local variables
  -------------------------------------------------
  local lparam1 = string.lower(param1)
  local cmdisaction  = ChkInTable(LastCommand[SendTo]["l3menu"],commandline)
  local cmdisbutton  = ChkInTable(LastCommand[SendTo]["l2menu"],commandline)
  local cmdissubmenu = ChkInTable(LastCommand[SendTo]["l1menu"],commandline)
  print_to_log(' => cmdisaction :',cmdisaction)
  print_to_log(' => cmdisbutton :',cmdisbutton)
  print_to_log(' => cmdissubmenu:',cmdissubmenu)

  -------------------------------------------------
  -- Process start or menu commands
  -------------------------------------------------
  -- Set DTGMENU On/Off
  if lcommand == "dtgmenu" then
    Menuidx = idx_from_variable_name("DTGMENU")
    if Menuidx == nil then
      Menuval = "Off"
    else
      Menuval = get_variable_value(Menuidx)
    end
    response="DTGMENU is currently "..Menuval
    if Menuval == "On" and lparam1 == "off" then
      print( " Set DTGMENU Off")
      response="DTGMENU is now disabled. send DTGMENU On to start the menus again."
      replymarkup='{"hide_keyboard":true}'
      set_variable_value(Menuidx,"DTGMENU",2,"Off")
    elseif Menuval == "Off" and lparam1 == "on" then
      print( " Set DTGMENU On")
      response="DTGMENU is now enabled. send DTGMENU Off to stop the menus."
      response=dtgmenu_lang[language].text["main"]
      replymarkup = makereplymenu(SendTo, "mainmenu")
      if Menuidx == nil then
        create_variable("DTGMENU",2,"On")
      else
        set_variable_value(Menuidx,"DTGMENU",2,"On")
      end
    end
    status=1
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    print_to_log("==< Show main menu")
    return status, response, replymarkup, commandline
  end

  -- Build main menu and return
  if cmdisaction == false and(lcommand == "menu" or lcommand == "start") then
    response=dtgmenu_lang[language].text["main"]
    replymarkup = makereplymenu(SendTo, "mainmenu")
    status=1
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    print_to_log("==< Show main menu")
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- process prompt for "command" Type
  -------------------------------------------------
  -- When returning from prompt then hand back to DTGBOT with previous command + param and reset keyboard to just MENU
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
    print_to_log("==<1 promt and found regular lua command and param was given. -> hand back to dtgbot to run",commandline)
    return status, response, replymarkup, commandline
  end

  -------------------------------------------------
  -- process when command is not known in the last menu
  -------------------------------------------------
  -- hand back to DTGBOT reset keyboard to just MENU
  if cmdisaction == false
  and cmdisbutton == false
  and cmdissubmenu == false then
    -- make small keyboard
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 0 -- this triggers dtgbot to reset the parsed_command[2}=response and parsed_command[3}=command
    response = ""
    commandline = LastCommand[SendTo]["device"] .. " " .. commandline
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["device"] = ""
    LastCommand[SendTo]["l1menu"] = ""
    LastCommand[SendTo]["l2menu"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log("==<1 found regular lua command and param was given. -> hand back to dtgbot to run",commandline )
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
  local MaxDimLevel= 0
  if cmdissubmenu then
    submenu    = commandline
  end
  if cmdisbutton then
    submenu    = LastCommand[SendTo]["submenu"]
    devicename = command  -- use command as that should only contain the values of the first param
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    print_to_log(' => devicename :',devicename)
    print_to_log(' => realdevicename :',realdevicename)
    print_to_log(' => idx:',idx)
    print_to_log(' => Type :',Type)
    print_to_log(' => DeviceType :',DeviceType)
    print_to_log(' => SwitchType :',SwitchType)
    print_to_log(' => MaxDimLevel :',MaxDimLevel)
  end
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
    print_to_log(' => devicename :',devicename)
    print_to_log(' => realdevicename :',realdevicename)
    print_to_log(' => idx:',idx)
    print_to_log(' => Type :',Type)
    print_to_log(' => DeviceType :',DeviceType)
    print_to_log(' => SwitchType :',SwitchType)
    print_to_log(' => MaxDimLevel :',MaxDimLevel)
  end
  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- populate the room info each cycle to allow for updates in Domotics
  --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  --!!! change this to only populated with menu or start command for speed
--~ 	PopulateMenuTab()
--~ 	MakeRoomMenus()
  --!!! change this to only populated with menu or start command for speed
  --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  -------------------------------------------------

  -------------------------------------------------
  -- process Type="command"
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
        response="param needed"
        print_to_log("==<1 found regular lua command that need Param ")

      -- no prompt defined so simply return to dtgbot with status 0 so it will be performed and reset the keyboard to just MENU
      else
        replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
        status = 0
        LastCommand[SendTo]["submenu"] = ""
        LastCommand[SendTo]["device"] = ""
        LastCommand[SendTo]["l1menu"] = ""
        LastCommand[SendTo]["l2menu"] = ""
        LastCommand[SendTo]["l3menu"] = ""
        print_to_log("==<1 found regular lua command. -> hand back to dtgbot to run")
      end
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
      print_to_log("==<2 found regular lua command. -> hand back to dtgbot to run:"..LastCommand[SendTo]["device"].. " " .. commandline )
  --~ 		replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
      return status, response, replymarkup, commandline
    end
  end

  -------------------------------------------------
  -- process submenu buttonpressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    LastCommand[SendTo]["submenu"]=submenu
    print_to_log(' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      LastCommand[SendTo]["device"] = rdevicename
      print_to_log(" -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=dtgmenu_lang[language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. dtgmenu_lang[language].text["Select"]
    end
    status=1
    print_to_log("==< show options in submenu.")
    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------
  -- process device button pressed
  -------------------------------------------------
  status=1
  if cmdisbutton then
    replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename,SwitchType)
    -- show initial menu with only devices when shown first time
    LastCommand[SendTo]["device"] = devicename
    local switchstatus=""
    local found=0
    if DeviceType == "scenes" then
      if Type == "Group" then
        response = dtgmenu_lang[language].text["SelectGroup"]
        print_to_log("==< Show group options menu plus other devices in submenu.")
      else
        response = dtgmenu_lang[language].text["SelectScene"]
        print_to_log("==< Show scene options menu plus other devices in submenu.")
      end
    elseif Type == "Temp" or Type == "Temp + Humidity" then
        -- when temp device is selected them just return with sending anything.
      LastCommand[SendTo]["device"] = ""
      response = ""
      status=1
      replymarkup=""
      print_to_log("==< Don't do anything as a temp device was selected.")
    elseif DeviceType == "devices" then
      -- Only show current status in the text when not shown on the action options
      if dtgmenu_submenus[submenu].showdevstatus == "y" then
        response = dtgmenu_lang[language].text["SelectOptionwo"]
      else
        switchstatus = dtgmenu_submenus[submenu].button[devicename].status
        response = dtgmenu_lang[language].text["SelectOption"] .. " " .. switchstatus
      end
      print_to_log("==< Show device options menu plus other devices in submenu.")
    else
      response = dtgmenu_lang[language].text["Select"]
      print_to_log("==< Show options menu plus other devices in submenu.")
    end

    return status, response, replymarkup, commandline;
  end


  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  if ChkInTable(string.lower(dtgmenu_lang[language].switch_options["Off"]),action) then
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,'Off')
  elseif ChkInTable(string.lower(dtgmenu_lang[language].switch_options["On"]),action) then
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,'On')
  elseif string.find(action, "%d") then
    action = tostring(MaxDimLevel/100*tonumber(action))
    response = "Set level " .. action
    response= SwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  else
    response = dtgmenu_lang[language].text["UnknownChoice"] .. action
  end
  status=1

  replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename,SwitchType)
  print_to_log("==<"..response)
  return status, response, replymarkup, commandline;
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------

local dtgmenu_commands = {
  ["dtgmenu"] = {handler=dtgmenu_module.handler, description="DTGMENU (On/Off) to start or stop the menu functionality."},
  }

function dtgmenu_module.get_commands()
  return dtgmenu_commands;
end

-----------------------------------------------
--- START population the table which runs only at BOT startup time
-----------------------------------------------
-- support func to scan through the provided Devices and Scenes tables to check for these types
-- else we assume it is a "command" that DTGBOT understand
function devinfo_from_name(idx,DeviceName,Devlist,Scenelist)
  local k, record, Type,DeviceType,SwitchType
  local found = 0
  local rDeviceName=""
  local status=""
  local MaxDimLevel=100
  local ridx=0
  -- Check for Devices
--~ 	print("==> start devinfo_from_name", idx,DeviceName)
  result = Devlist["result"]
  for k,record in pairs(result) do
--~ 		print(k,DeviceName,record.Name,idx,record.idx)
    if type(record) == "table" then
      if string.lower(record.Name) == string.lower(DeviceName) or idx == record.idx then
        ridx = record.idx
        rDeviceName = record.Name
        DeviceType="devices"
        Type=record.Type
        if Type == "Temp" then
          SwitchType="temp"
          status = tostring(record.Temp)
        elseif Type == "Temp + Humidity" then
          SwitchType="temp"
          status = tostring(record.Temp) .. "-" .. tostring(record.Humidity).."%"
        else
          SwitchType=record.SwitchType
          MaxDimLevel=record.MaxDimLevel
          status = tostring(record.Status)
        end
        found = 1
--~         print(" !!!! found device",record.Name,rDeviceName,record.idx,ridx)
        break
      end
    end
  end
--~   print(" !!!! found device",rDeviceName,ridx)
  -- Check for Scenes
  if found == 0 then
    result = Scenelist["result"]
    for k,record in pairs(result) do
--~ 		print(k,record['Name'],DeviceName)
      if type(record) == "table" then
        if string.lower(record.Name) == string.lower(DeviceName) or idx == record.idx then
          ridx = record.idx
          rDeviceName = record.Name
          DeviceType="scenes"
          Type=record.Type
          SwitchType=record.Type
          found = 1
--~           print(" !!!! found scene",record.Name,rDeviceName,record.idx,ridx)
          break
        end
      end
    end
  end
  -- Check for Scenes
  if found == 0 then
    ridx = 9999
    DeviceType="command"
    Type="command"
    SwitchType="command"
  end
--~  	print(" --< devinfo_from_name:",found,ridx,rDeviceName,DeviceType,Type,SwitchType,status)
  return ridx,rDeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status
end
--
function PopulateMenuTab(iLevel,iSubmenu)
  print_to_log("####  Start populating menuarray")

  dtgmenu_submenus = {}

  if iLevel ~= "mainmenu" then
    -- get IDX device table
    Deviceslist = device_list("devices&used=true")
    -- get IDX scenes table
    Sceneslist = device_list("scenes")
  end
  --
  print_to_log("Submenu table including buttons defined in menu.cfg:",iLevel,iSubmenu)
  for submenu,get in pairs(static_dtgmenu_submenus) do
--~ 		print_to_log("=>",submenu, get.whitelist, get.showdevstatus,get.Menuwidth)
    if static_dtgmenu_submenus[submenu].buttons ~= nil then
      buttons = {}
      if iLevel ~= "mainmenu" and iSubmenu == string.lower(submenu) then
        for button,dev in pairs(static_dtgmenu_submenus[submenu].buttons) do
            idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(9999,button,Deviceslist,Sceneslist)
            buttons[button] = {whitelist = dev.whitelist,actions=dev.actions,prompt=dev.prompt,showactions=dev.showactions,Name=DeviceName,idx=idx,DeviceType=DeviceType,SwitchType=SwitchType,Type=Type,MaxDimLevel=MaxDimLevel,status=status}
            print_to_log(" static ->",submenu,button,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
        end
      end
      dtgmenu_submenus[submenu] = {whitelist=get.whitelist,buttons=buttons}
    end
  end
  -- Add the room/plan menu's after the statis is populated
  MakeRoomMenus(iLevel,iSubmenu,Deviceslist,Sceneslist)
  print_to_log("####  End populating menuarray")
  return
end
--
-- Create a button per room.
function MakeRoomMenus(iLevel,iSubmenu,Deviceslist,Sceneslist)
  iSubmenu = tostring(iSubmenu)
  print_to_log("Creating Room Menus:",iLevel,iSubmenu)
  room_number = 0
  -- retrieve all plan's from Domoticz
  Roomlist = device_list("plans")
  planresult = Roomlist["result"]
  -- get IDX device table
  if Deviceslist == nil then
    Deviceslist = device_list("devices&used=true")
  end
  -- get IDX scenes table
  if Sceneslist == nil then
    Sceneslist = device_list("scenes")
  end
  -- process plan records
  for p,precord in pairs(planresult) do
    room_name = precord.Name
    room_number = precord.idx
    local rbutton = string.lower(room_name:gsub(" ", "_"))

    if iLevel ~= "mainmenu"
    and iSubmenu == string.lower(rbutton) or "[scene] ".. iSubmenu == string.lower(rbutton) then
      -- retrieve all devices for this plan from Domoticz
      Devsinplan = device_list("command&param=getplandevices&idx="..room_number)
      DIPresult = Devsinplan["result"]
      if DIPresult ~= nil then
        print_to_log('For room '..room_name..' got some devices and/or scenes')
        dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons={}}
        -- process all found entries in the plan record
        buttons = {}
        for d,DIPrecord in pairs(DIPresult) do
          if type(DIPrecord) == "table" then
            local DeviceType="devices"
            local SwitchType
            local Type
            local status=""
            local MaxDimLevel=100
            local idx=DIPrecord.devidx
            local name=DIPrecord.Name
    --~ 					print_to_log(" - Plan record:",DIPrecord.Name,DIPrecord.devidx,DIPrecord.type)
            if DIPrecord.type == 1 then
    --~ 						print("--> scene record")
              idx,DeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(idx,"",Deviceslist,Sceneslist)
            else
    --~ 						print("--> device record")
              idx,DeviceName, DeviceType,Type,SwitchType,MaxDimLevel,status = devinfo_from_name(idx,"",Deviceslist,Sceneslist)
            end
            -- Remove the name of the room from the device if it is present
            record_name = string.gsub(DeviceName,room_name,"")
            -- But reinstate it if lees than 3 letters are left
            if #record_name < 3 then
              record_name = DeviceName
            end
            -- Remove any spaces from the device name
            record_name = string.gsub(record_name,"%s+", "")
            buttons[record_name] = {whitelist = "",Name=DeviceName,idx=idx,DeviceType=DeviceType,SwitchType=SwitchType,Type=Type,MaxDimLevel=MaxDimLevel,status=status}
            print_to_log(" dynam ->",rbutton,DeviceName, idx,DeviceType,Type,SwitchType,MaxDimLevel,status)
          end
        end
      end
    end
    dtgmenu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons=buttons}
  end
end

--~ MakeRoomMenus()
--~ PopulateMenuTab()

return dtgmenu_module;
