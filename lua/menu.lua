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

local menu_module = {};

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
        response = menu_lang[language].text["Switched"] .. ' ' ..DeviceName..' => '..state
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
  for i,get in orderedPairs(menu_submenus) do
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
    if menu_submenus[submenu] ~= nil
    and menu_submenus[submenu].buttons ~= nil then
      for i,get in orderedPairs(menu_submenus[submenu].buttons) do
--~ 			print(" #debug1 - Submenu item:",i,get.submenu)
        -- Do not show the selected Device as Keyboard button as you just pressed it
        -- Exception is when the option menu_submenus[submenu].NoDevMenu is defined as that is just for status display
--~ 				print(" #debug2 - Submenu item:",i,menu_submenus[submenu].showdevstatus,get.DeviceType,get.idx)
        if i ~= devicename or menu_submenus[submenu].NoDevMenu then
          local switchstatus = ""
          print_to_log("   - Submenu item:",i,menu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            if menu_submenus[submenu].showdevstatus == "y" then
              switchstatus = get.status
              if ChkEmpty(switchstatus) then
                switchstatus = ""
              else
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
        if menu_submenus[submenu].NoDevMenu ~= true
        and Level == "devicemenu" and i == devicename then
          -- set reply markup to the override when provide
          l3menu = get.actions
          print_to_log(" ---< ",SwitchType," using replymarkup:",l3menu)
          -- else use the default reply menu for the SwitchType
          if l3menu == nil or l3menu == "" then
            l3menu = menu_lang[language].devices_options[SwitchType]
            if l3menu == nil then
              print_to_log("  !!! No default menu_lang[language].devices_options for SwitchType:",SwitchType)
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
  LastCommand[SendTo]["l3menu"] = l3menu
  ------------------------------
  -- Add level 2 first if needed
  if l2menu ~= "" then
    local mwitdh=DevMenuwidth
    if menu_submenus[submenu].Menuwidth ~= nil then
      if tonumber(menu_submenus[submenu].Menuwidth) >= 2 then
        mwitdh=tonumber(menu_submenus[submenu].Menuwidth)
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
-- SCAN through the menu_submenus table to get the info for the given name and determine whther it is an known device
function isdevice(name,SendTo)
  local bidx=""
  local btype=""
  local bsubmenu=""
  local isbutton=false
  local ismenu=false
  for submenu,get in pairs(menu_submenus) do
    -- Find the menu but only when it is whitelisted
    if submenu == name and (get.whitelist == "" or ChkInTable(get.whitelist,SendTo)) then
      ismenu=true
    end
    if menu_submenus[submenu].buttons ~= nil then
      for button,dev in pairs(menu_submenus[submenu].buttons) do
        -- Find the button in menu but only when it is whitelisted
        if button == name and (dev.whitelist == "" or ChkInTable(dev.whitelist,SendTo)) then
          btype = dev.Type
          bsubmenu=submenu
          isbutton=true
          bidx = dev.idx
        end
      end
    end
  end
--~ 	print(" --< isdevice:" .. name,ismenu,isbutton,bidx,btype,bsubmenu)
  return ismenu,isbutton,bidx,btype,bsubmenu
end
--
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
function menu_module.handler(menu_cli, SendTo)
  local response = "", jresponse, decoded_response, status, action;
  local DeviceType = "devices"
  local SwitchType = ""
  local idx = ""
  local replymarkup = ""
  --
  print_to_log("==> menu.lua    Start" )
  -- populate the room info each cycle to allow for updates in Domotics
  PopulateMenuTab()
  MakeRoomMenus()
  print_to_log(" => SendTo:",SendTo,"menu_cli[2]:",menu_cli[2],"[3]:",menu_cli[3], "[4]:",menu_cli[4])
  print_to_log(' => LastCommand[SendTo]["menu"]:',LastCommand[SendTo]["menu"],'["submenu"]:',LastCommand[SendTo]["submenu"])
  print_to_log(' => LastCommand[SendTo]["button"]:',LastCommand[SendTo]["button"],'["l3menu"]:',LastCommand[SendTo]["l3menu"])
  local match_type, mode;
  --
  -- check if received command is a submenu:
  local submenu = ""				-- level 1
  local devicename = ""			-- level 2
  local action = ""				-- level 3
  local command = menu_cli[2]
  local lcommand = string.lower(command)
  local commandline = menu_cli[3]
  local param = menu_cli[4]
  if commandline == nil then
    commandline = ""
  end

-- Command lexing -------------------------------------------

  LastCommand[SendTo]["menu"] = "menu"
  -- set to "start when no command was given
  if command == nil then
    command = "start"
  end
  local lcommand = string.lower(command)
  -- When command is equeal to any of the defined commands in dtgbot, we start from scratch
  if commands[command] ~= nil then
    -- command found in the overall table
--~ 		print("- is an existing dtgbot command.")
    if commands[lcommand].handler == menu_module.handler then
      response = "Hi"
      if lcommand == "menu" then
        response=menu_lang[language].text["main"]
      end
      if lcommand == "start" then
        response=menu_lang[language].text["start"]
      end
      replymarkup = makereplymenu(SendTo, "mainmenu")
      status=1
      LastCommand[SendTo]["menu"] = "menu"
      LastCommand[SendTo]["submenu"] = ""
      LastCommand[SendTo]["button"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      print_to_log("==< Show main menu")
      return status, response, replymarkup
    end
  end
  --
  -- When we return from a prompt action then use the last buttonname as that is the command needing the extra input
  -- else look for the given command
  local ismenu,isbutton,bidx,btype,bsubmenu
  if LastCommand[SendTo]["prompt"] then
    print_to_log(" - Returned from prompt..looking up:",LastCommand[SendTo]["button"])
    ismenu,isbutton,bidx,btype,bsubmenu=isdevice(LastCommand[SendTo]["button"],SendTo)
  else
    print_to_log(" - looking up:",command)
    ismenu,isbutton,bidx,btype,bsubmenu=isdevice(command,SendTo)
  end
  print_to_log(" -->isdevice:",ismenu,isbutton,bidx,btype,bsubmenu)
  -- When returning from prompt then hand back to DTGBOT with previous command + param
  if LastCommand[SendTo]["prompt"] then
--~ 		replymarkup = makereplymenu(SendTo,"submenu",bsubmenu)
    replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    status = 9999
    response = LastCommand[SendTo]["button"]
    LastCommand[SendTo]["button"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    LastCommand[SendTo]["prompt"] = false
    print_to_log("==<1 found regular lua command and param was given. -> hand back to dtgbot to run")
    return status, response, replymarkup
  elseif isbutton
  and btype == "command"
  and ChkEmpty(menu_submenus[bsubmenu].buttons[command].actions) then
  --  filter the DeviceType "command" that can be ran by dtgbot and simply hand it back without updating the keyboard
    if menu_submenus[LastCommand[SendTo]["submenu"]].buttons[commandline].prompt then
      LastCommand[SendTo]["button"] = commandline
      LastCommand[SendTo]["prompt"] = true
      replymarkup='{"force_reply":true}'
      LastCommand[SendTo]["replymarkup"] = replymarkup
      status = 1
      response="param needed"
      print_to_log("==<1 found regular lua command that need Param ")
    else
--~ 			replymarkup = makereplymenu(SendTo,"submenu",bsubmenu)
      replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
      status = 0
      LastCommand[SendTo]["button"] = ""
      LastCommand[SendTo]["l3menu"] = ""
      print_to_log("==<1 found regular lua command. -> hand back to dtgbot to run")
    end
    return status, response, replymarkup
  elseif LastCommand[SendTo]["button"] ~= ""
  and menu_submenus[LastCommand[SendTo]["submenu"]].buttons[LastCommand[SendTo]["button"]].DeviceType == "command"
  and ChkInTable(tostring(menu_submenus[LastCommand[SendTo]["submenu"]].buttons[LastCommand[SendTo]["button"]].actions),command) then
  --  if command is one of the actions of a command DeviceType hand it now back to DTGBOT
    status = 9999
    response = LastCommand[SendTo]["button"]
    print_to_log("==<2 found regular lua command. -> hand back to dtgbot to run:"..LastCommand[SendTo]["button"].. " " .. command )
--~ 		replymarkup='{"keyboard":[["menu"]],"resize_keyboard":true}'
    return status, response, replymarkup
  elseif menu_submenus[commandline] ~= nil and param == nil then
  -- when there is just one parameter and it matches a Submenu  we assume a submenu was provided
    print_to_log("- found submenu:", command)
    submenu = lcommand
    devicename = ""
    action = ""
  elseif isbutton then
    print_to_log("- found device:", command)
    submenu = bsubmenu
    devicename = command
    action = ""
  -- check both command and commandline as command is stripped from characters line % so would not recognize percentages
  elseif ChkInTable(LastCommand[SendTo]["l3menu"],command)
    or ChkInTable(LastCommand[SendTo]["l3menu"],commandline) then
    submenu = LastCommand[SendTo]["submenu"]
    devicename = LastCommand[SendTo]["button"]
    action = command
    print_to_log("- Command is action..")
  else
    -- We do not know this command so handing it back to dtgbot
    LastCommand[SendTo]["menu"] = "menu"
    LastCommand[SendTo]["submenu"] = ""
    LastCommand[SendTo]["button"] = ""
    LastCommand[SendTo]["l3menu"] = ""
    replymarkup, status = makereplymenu(SendTo,"mainmenu")
    response = ""
    status = 0
    print_to_log("==< Unknown command for Menu. -> Show Main menu and hand back to dtgbot to handle the command")
    return status, response, replymarkup
  end
  -- retrieve the information from the table for the device.
  if devicename ~= "" then
    idx = menu_submenus[submenu].buttons[devicename].idx
    if idx == nil then
      idx = 0
    end
    DeviceType = menu_submenus[submenu].buttons[devicename].DeviceType
    if DeviceType == nil then
      DeviceType = ""
    end
    SwitchType = menu_submenus[submenu].buttons[devicename].SwitchType
    if SwitchType == nil then
      SwitchType = ""
    end

  end
  print_to_log(" => --Command lexing done ------------------")
  print_to_log(" => submenu:"..submenu, "devicename:"..devicename, "action:"..action)
  print_to_log(" => idx:".. idx, "DeviceType:"..DeviceType, "SwitchType:"..SwitchType,"btype:"..btype)
  -- ==== start the logic =========================================

  LastCommand[SendTo]["submenu"] = submenu
  LastCommand[SendTo]["button"] = devicename
  -- ==== Show Submenu when no device is specified================
  if devicename == "" then
    print_to_log(' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      LastCommand[SendTo]["button"] = rdevicename
      print_to_log(" -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=menu_lang[language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. menu_lang[language].text["Select"]
    end
    print_to_log("==< show options in submenu.")
    return status, response, replymarkup;
  end
  -- ==== Show devicemenu when no action is specified================
  if action == "" then
    -- show initial menu with only devices when shown first time
    local switchstatus=""
    local found=0
    print (SwitchType)
    if DeviceType == "scenes" then
      if SwitchType == "Group" then
        response = menu_lang[language].text["SelectGroup"]
      else
        response = menu_lang[language].text["SelectScene"]
      end
    elseif DeviceType == "devices" then
      -- Only show current status in the text when not shown on the action options
      if menu_submenus[submenu].showdevstatus == "y" then
        response = menu_lang[language].text["SelectOptionwo"]
      else
        switchstatus = menu_submenus[submenu].button[devicename].status
        response = menu_lang[language].text["SelectOption"] .. " " .. switchstatus
      end
    else
      response = menu_lang[language].text["Select"]
    end
    replymarkup = makereplymenu(SendTo,"devicemenu",submenu,devicename,SwitchType)
    print_to_log("==< Show device options menu plus other devices in submenu.")
    return status, response, replymarkup;
  end

  action = string.lower(action)
--~ 	print(action)
--~ 	print(string.lower(menu_lang[language].switch_options["Off"]))
  if ChkInTable(string.lower(menu_lang[language].switch_options["Off"]),action) then
    response= SwitchName(devicename,DeviceType,SwitchType,idx,'Off')
    status=1
  elseif ChkInTable(string.lower(menu_lang[language].switch_options["On"]),action) then
    response= SwitchName(devicename,DeviceType,SwitchType,idx,'On')
    status=1
  elseif string.find(action, "%d") then
    response = "Set level " .. action
    response= SwitchName(devicename,DeviceType,SwitchType,idx,"Set Level " .. action)
    status=1
  else
    response = menu_lang[language].text["UnknownChoice"] .. action
    status=1
  end

  print_to_log("==<"..response)
  return status, response, replymarkup;
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------

local menu_commands = {
  ["start"] = {handler=menu_module.handler, description="Mainmenu"},
  ["menu"] = {handler=menu_module.handler, description="Mainmenu"}
  }

function menu_module.get_commands()
  return menu_commands;
end

-----------------------------------------------
--- START population the table which runs only at BOT startup time
-----------------------------------------------
-- support func to scan through the provided Devices and Scenes tables to check for these types
-- else we assume it is a "command" that DTGBOT understand
function devinfo_from_name(DeviceName,Devlist,Scenelist)
  local idx, k, record, Type,DeviceType,SwitchType
  idx=0
  -- Check for Devices
  result = Devlist["result"]
  for k,record in pairs(result) do
--~ 		print(k,record['Name'],DeviceName)
    if type(record) == "table" then
      if string.lower(record['Name']) == string.lower(DeviceName) then
        idx = record.idx
        DeviceType="devices"
        Type=record.Type
        if Type == "Temp" then
          SwitchType="temp"
        elseif Type == "Temp + Humidity" then
          SwitchType="temp"
        else
          SwitchType=record.SwitchType
        end
      end
    end
  end
  -- Check for Scenes
  if idx==0 then
    result = Scenelist["result"]
    for k,record in pairs(result) do
      if type(record) == "table" then
        if string.lower(record['Name']) == string.lower(DeviceName) then
        idx = record.idx
        DeviceType="scenes"
        Type=record.Type
        SwitchType="Scene"
        end
      end
    end
  end
  -- Check for Scenes
  if idx==0 then
    idx = 9999
    DeviceType="command"
    Type="command"
    SwitchType="command"
  end
--~ 	print("devinfo_from_name:",idx,DeviceType,Type,SwitchType)
  return idx,DeviceType,Type,SwitchType
end
--
function PopulateMenuTab(opt)
  print_to_log("####  Start populating menuarray")
  -- get IDX device table
  Deviceslist = device_list("devices&used=true")
  -- get IDX scenes table
  Sceneslist = device_list("scenes")
  print_to_log("Submenu table including buttons defined in dtgbot.cfg:")
  for submenu,get in pairs(menu_submenus) do
    print_to_log("=>",submenu, get.whitelist, get.showdevstatus,get.Menuwidth)
    if menu_submenus[submenu].buttons ~= nil then
      for button,dev in pairs(menu_submenus[submenu].buttons) do
        idx,DeviceType,Type,SwitchType = devinfo_from_name(button,Deviceslist,Sceneslist)
        menu_submenus[submenu].buttons[button].idx = idx
        menu_submenus[submenu].buttons[button].DeviceType = DeviceType
        menu_submenus[submenu].buttons[button].Type = Type
        menu_submenus[submenu].buttons[button].SwitchType = SwitchType
        print_to_log("  ->",submenu,button, dev.idx,dev.DeviceType,dev.Type,dev.SwitchType)
      end
    end
    -- added all defined switchtypes to this menu dynamiccally
    if menu_submenus[submenu].selectswitchtype ~= nil then
      for inSwitchType in string.gmatch(menu_submenus[submenu].selectswitchtype, "[^|,]+") do
        if ChkInTable("Group,Scene",inSwitchType) then
-- 					print( "Search scenes for "..inSwitchType)
          result = Sceneslist["result"]
        else
-- 					print( "Search devices for "..inSwitchType)
          result = Deviceslist["result"]
        end
        for k,record in pairs(result) do
-- 			 		print(k,record['Name'],DeviceName)
          if type(record) == "table" then
            local rbutton = ""
            local sType = record.SwitchType
            local DeviceType
            local SwitchType
            local status
--~ 					print(record.Name)
            if record.Type == "Temp" then
              sType="temp"
              DeviceType="devices"
              status = tostring(record.Temp)
            elseif record.Type == "Temp + Humidity" then
              sType="temp"
              DeviceType="devices"
              status = tostring(record.Temp) .. "-" .. tostring(record.Humidity).."%"
            elseif record.Type == "Scene" or record.Type == "Group" then
              sType=record.Type
              DeviceType="scenes"
              SwitchType=record.Type
            elseif record.SwitchType ~= nil then
              sType=record.SwitchType
              DeviceType="devices"
              SwitchType=record.SwitchType
              status = tostring(record.Status)
            else
              sType="unknown"
              DeviceType="devices"
              status = tostring(v1.Status)
            end
            if string.lower(sType) == string.lower(inSwitchType) then
              menu_submenus[rbutton].buttons[record.Name] = {whitelist = "",Name=room_name,idx=record.idx,DeviceType=DeviceType,SwitchType=SwitchType,Type=sType,status=status}
              print_to_log("  ->",submenu,record.Name, record.idx,DeviceType,Type,SwitchType,status)
            end
          end
        end
      end
    end
  end
  print_to_log("####  End populating menuarray")
  return
end
--
-- Create a button per room.
function MakeRoomMenus()
  print_to_log("Creating Room Menus")
  room_number = 0
  -- retrieve all plan's from Domoticz
  Roomlist = device_list("plans")
  planresult = Roomlist["result"]
  -- get IDX device table
  Deviceslist = device_list("devices&used=true")
  -- get IDX scenes table
  Sceneslist = device_list("scenes")
  -- process plan records
  for p,precord in pairs(planresult) do
    room_name = precord.Name
    room_number = precord.idx
    local rbutton = string.lower(room_name:gsub(" ", "_"))
    -- retrieve all devices for this plan from Domoticz
    Devsinplan = device_list("command&param=getplandevices&idx="..room_number)
    DIPresult = Devsinplan["result"]
    if DIPresult ~= nil then
      print_to_log('For room '..room_name..' got some devices and/or scenes')
      menu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons={}}
        -- process all found entries in the plan record
        buttons = {}
        for d,DIPrecord in pairs(DIPresult) do
        if type(DIPrecord) == "table" then
          local DeviceType="devices"
          local SwitchType
          local Type
          local status="?"
          local idx=DIPrecord.devidx
          local name=DIPrecord.Name
          print(" - Plan record:",DIPrecord.Name,DIPrecord.devidx,DIPrecord.type)
          if DIPrecord.type == 1 then
--~ 						print("--> scene record")
            result = Sceneslist["result"]
          else
--~ 						print("--> device record")
            result = Deviceslist["result"]
          end
          for k,record in pairs(result) do
  -- 			 		print(k,record['Name'],DeviceName)
            if type(record) == "table" and record.idx == DIPrecord.devidx then
              local sType = record.SwitchType
              local DeviceType
              local SwitchType
              local status
  --~ 					print(record.Name)
              if record.Type == "Temp" then
                sType="temp"
                DeviceType="devices"
                status = tostring(record.Temp)
              elseif record.Type == "Temp + Humidity" then
                sType="temp"
                DeviceType="devices"
                status = tostring(record.Temp) .. "-" .. tostring(record.Humidity).."%"
              elseif record.Type == "Scene" or record.Type == "Group" then
                sType=record.Type
                DeviceType="scenes"
                SwitchType=record.Type
              elseif record.SwitchType ~= nil then
                sType=record.SwitchType
                DeviceType="devices"
                SwitchType=record.SwitchType
                status = tostring(record.Status)
              else
                sType="unknown"
                DeviceType="devices"
                status = tostring(v1.Status)
              end
              -- Remove the name of the room from the device if it is present
              record_name = string.gsub(record.Name,room_name,"")
              -- But reinstate it if lees than 3 letters are left
              if #record_name < 3 then
                record_name = record.Name
              end
              -- Remove any spaces from the device name
              record_name = string.gsub(record_name,"%s+", "")
              buttons[record_name] = {whitelist = "",Name=record.Name,idx=record.idx,DeviceType=DeviceType,SwitchType=SwitchType,Type=sType,status=status}
              print_to_log("  ->",rbutton,record.Name, record.idx,DeviceType,Type,SwitchType,status)
            end
          end
          menu_submenus[rbutton] = {whitelist="",showdevstatus="y",buttons=buttons}
        end
      end
    end
  end
end
-- populate the status definitions only at startup
--~ MakeRoomMenus()
--~ PopulateMenuTab()

return menu_module;
