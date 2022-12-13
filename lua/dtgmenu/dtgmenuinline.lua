local dtgmenuinline =  {}
-- =====================================================================================================================
-- =====================================================================================================================
-- DTGBOTMENU functions for inline-Keyboard style
-- programmer: Jos van der Zande
-- =====================================================================================================================

------------------------------------------------------------------------------
--- START Build the reply_markup functions.
--  this function will build the requested menu layout and calls the function to retrieve the devices/scenes  details.
-------------------------------------------------------------------------------
function dtgmenuinline.makereplymenu(SendTo, Level, submenu, devicename)
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
  Print_to_Log(1,"  -> makereplymenu  Level:",Level,"submenu",submenu,"devicename",devicename)
  local t=0
  local l1menu=""
  local l2menu=""
  local l3menu=""
-- ==== Build Submenu - showing the Devices from the selected room of static config
--                      This will also add the device status when showdevstatus=true for the option.
  Print_to_Log(1,'     submenu: '..submenu)
  if Level == "submenu" or Level == "devicemenu" then
    if dtgmenu_submenus[submenu] ~= nil
    and dtgmenu_submenus[submenu].buttons ~= nil then
      t=0
      -- loop through all defined "buttons in the Config
      local DevMwitdh=DevMenuwidth or 3
      if dtgmenu_submenus[submenu].Menuwidth ~= nil then
        if tonumber(dtgmenu_submenus[submenu].Menuwidth) >= 2 then
          DevMwitdh=tonumber(dtgmenu_submenus[submenu].Menuwidth)
        end
      end
      for i,get in orderedPairs(dtgmenu_submenus[submenu].buttons) do
        -- process all found devices in dtgmenu_submenus buttons table
        if i ~= "" then
          local switchstatus = ""
          Print_to_Log(2,"   - Submenu item:",i,dtgmenu_submenus[submenu].showdevstatus,get.DeviceType,get.idx,get.status)
          local didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel
          if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then
            -- add the device status to the button when requested
            if dtgmenu_submenus[submenu].showdevstatus == "y" then
              didx,dDeviceName,dDeviceType,dType,dSwitchType,dMaxDimLevel,switchstatus,LevelNames,LevelInt = Domo_Devinfo_From_Name(get.idx,get.Name,get.DeviceType)
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
            t,newbutton = dtgmenuinline.buildmenuitem(string.sub(i,1,(ButtonTextwidth or 20)-string.len(switchstatus))..switchstatus,"menu",submenu .. " " .. i, DevMwitdh,t)
            l2menu=l2menu .. newbutton
            -- show the actions menu immediately for this devices since that is requested in the config
            -- this can avoid having the press 2 button before getting to the actions menu
            if get.showactions and devicename == "" then
              Print_to_Log(2,"    - Changing to Device action level due to showactions:",i)
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
            -- set reply markup to the override when provide
            l3menu = get.actions
            Print_to_Log(1," ---< ",Type,SwitchType," using replymarkup:",l3menu)
            -- else use the default reply menu for the SwitchType
            if l3menu == nil or l3menu == "" then
              l3menu = dtgmenu_lang[menu_language].devices_options[SwitchType]
              if l3menu == nil then
                -- use the type in case of devices like a Thermostat
                l3menu = dtgmenu_lang[menu_language].devices_options[Type]
                if l3menu == nil then
                  Print_to_Log(1,"  !!! No default dtgmenu_lang[menu_language].devices_options for SwitchType:",SwitchType,Type)
                  l3menu = dtgmenu_lang[menu_language].devices_options["On/Off"]
                end
              end
            end
            Print_to_Log(1,"   -< ".. tostring(SwitchType).." using replymarkup:",l3menu)
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
    replymarkup = replymarkup .. dtgmenuinline.buildmenu(l3menu,ActMenuwidth,"menu " .. submenu .. " ".. devicename) .. ","
    Print_to_Log(3, ">> inline L3:", l3menu, "replymarkup:", replymarkup)
  end
  ------------------------------
  -- Add level 2 next if needed
  ------------------------------
  if l2menu ~= "" then
    replymarkup = replymarkup .. l2menu .. ","
    Print_to_Log(3, ">> inline L2:", l2menu, "replymarkup:", replymarkup)
  end
  -------------------------------
  -- Add level 1 -- the main menu
  --------------------------------
  t=0
  SubMenuwidth = SubMenuwidth or 3
  if (FullMenu or l2menu == "") then
    --~   Sort & Loop through the compiled options returned by PopulateMenuTab
    for i,get in orderedPairs(dtgmenu_submenus) do
      -- ==== Build mainmenu - level 1 which is the bottom part of the menu, showing the Rooms and static definitins
      -- Avoid adding start and menu as these are handled separately.
      if i ~= "menu" and i ~= "start" then
        if get.whitelist == "" or ChkInTable(get.whitelist,SendTo) then

          -- test if anything is specifically defined for this user in Telegram-RoomsShowninMenu`
          Print_to_Log(3, ">> inline MenuWhiteList check ", MenuWhiteList[SendTo] or " SendTo not defined", MenuWhiteList[0] or " Default not defined")
          --
          AllowButton=true
          if get.RoomNumber then
            if MenuWhiteList[SendTo] then
              if MenuWhiteList[SendTo][get.RoomNumber] then
                Print_to_Log(1, SendTo.." in MenuWhiteList Check room:"..(get.RoomNumber).." is Whitelisted. -> add room button" )
              else
                Print_to_Log(1, SendTo.." in MenuWhiteList Check room:"..(get.RoomNumber).." not Whitelisted! -> skip room button" )
                AllowButton=false
              end
            elseif MenuWhiteList['0'] then
              if MenuWhiteList['0'] and MenuWhiteList['0'][get.RoomNumber] then
                Print_to_Log(1, "0 in MenuWhiteList Check room:"..(get.RoomNumber).." is Whitelisted. -> add room button" )
              else
                Print_to_Log(1, "0 in MenuWhiteList Check room:"..(get.RoomNumber).." not Whitelisted! -> skip room button" )
                AllowButton=false
              end
            else
              Print_to_Log(1, SendTo.." No 0/SendTo in list -> add to menu: ")
            end
          else
            Print_to_Log(1, " No Roomnumber -> add to menu: ")
          end
          -- only add button when needed/allowed
          if AllowButton then
            t,newbutton = dtgmenuinline.buildmenuitem(i,"menu",i, SubMenuwidth,t)
            Print_to_Log(3, " -> t:", t, "newbutton:", newbutton)
            if newbutton then
              l1menu=l1menu .. newbutton
            end
          end
        end
      end
    end
  end
  -- add Menu & Exit
  t,newbutton = dtgmenuinline.buildmenuitem("Menu","menu","menu",SubMenuwidth,t)
  l1menu=l1menu .. newbutton
  t,newbutton = dtgmenuinline.buildmenuitem("Exit","menu","exit",SubMenuwidth,t)
  l1menu=l1menu .. newbutton
  l1menu=l1menu .. ']'
  replymarkup = replymarkup .. l1menu .. ']'
  --(not working with inline keyboards (yet?). add the resize menu option when desired. this sizes the keyboard menu to the size required for the options
--~   replymarkup = replymarkup..',"resize_keyboard":true'
--~   replymarkup = replymarkup..',"hide_keyboard":true,"selective":false'
  replymarkup = replymarkup .. '}'
  Print_to_Log(3, ">> inline L1:", l1menu, "replymarkup:", replymarkup)
  Print_to_Log(0,"  -< replymarkup:"..replymarkup)
-- save menus
  return replymarkup, devicename
end
-- convert the provided menu options into a proper format for the replymenu
function dtgmenuinline.buildmenu(menuitems,width,prefix)
  local replymenu=""
  local t=0
  Print_to_Log(2,"      process buildmenu:",menuitems," w:",width)
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
  Print_to_Log(2,"    -< buildmenu:",replymenu)
  return replymenu
end
-- convert the provided menu options into a proper format for the replymenu
function dtgmenuinline.buildmenuitem(menuitem,prefix,Callback,width,t)
  local replymenu=""
  Print_to_Log(2,"       process buildmenuitem:",menuitem,prefix,Callback," w:"..(width or "nil")," t:"..(t or "nil"))
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
  t=t+1
  Print_to_Log(2,"    -< buildmenuitem:","t:"..t,replymenu)
  return t,replymenu
end
-----------------------------------------------
--- END Build the reply_markup functions.
-----------------------------------------------
--
-----------------------------------------------
--- START the main process handler
-----------------------------------------------
function dtgmenuinline.handler(menu_cli,SendTo)

  -- rebuilt the total commandline after dtgmenu
  local commandline = ""  -- need to rebuild the commndline for feeding back
  local commandlinex = ""  -- need to rebuild the commndline for feeding back
  local parsed_command = {} -- rebuild table without the dtgmenu command in case we need to hand it back as other command
  local menucmd = false
  for nbr,param in pairs(menu_cli) do
    Print_to_Log(2,"nbr:",nbr," param:",param)
    -- check if
    if nbr==2 and param:lower()=="menu" then
      menucmd=true
    end
    if nbr > 2 then
      commandline = commandline .. param .. " "
    end
    -- build commandline without menu to feedback when it is an LUA/BASH command defined in the Menu
    if nbr < 2 or nbr > 3 then
      table.insert(parsed_command, param)
      commandlinex = commandlinex .. param .. " "
    end
  end
  commandline = tostring(commandline)
  commandline = string.sub(commandline,1,string.len(commandline)-1)
  local lcommandline = string.lower(commandline)
  --
  Print_to_Log(0,"==> dtgmenuinline Handle -->" .. commandline)
  Print_to_Log(1," => SendTo:",SendTo)

  -- return when not a menu item and hand it back to be processed as regular command
  if not menucmd then
    status=0
    Print_to_Log(0,"==<1 found regular lua command. -> hand back to dtgbot to run",commandlinex,parsed_command[2])
    return false, "", ""
  end

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
  Print_to_Log(1," => commandline  :",commandline)
  Print_to_Log(1," => commandlinex :",commandlinex)
  Print_to_Log(1," => param1       :",param1)
  Print_to_Log(1," => param2       :",param2)
  Print_to_Log(1," => param3       :",param3)
  Print_to_Log(1," => param4       :",param4)
  Print_to_Log(1,' => cmdisaction :',cmdisaction)
  Print_to_Log(1,' => cmdisbutton :',cmdisbutton)
  Print_to_Log(1,' => cmdissubmenu:',cmdissubmenu)

  -------------------------------------------------
  -- Process "start" or "menu" commands
  -------------------------------------------------
  -- Build main menu and return
  if param1:lower() == "dtgmenu" or param1:lower() == "menu" or param1:lower() == "start"
  or (cmdisbutton and (param2:lower() == "dtgmenu" or param2:lower() == "menu")) then
    response=dtgmenu_lang[menu_language].text["main"]
    replymarkup = dtgmenuinline.makereplymenu(SendTo, "mainmenu")
    status=1
    Persistent.UseDTGMenu = 1
    Persistent[SendTo].iLastcommand = "menu"
    Print_to_Log(0,"==< Show main menu")
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
    Print_to_Log(0,"==< Exit main inline menu")
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
    Print_to_Log(1,' => submenu :',submenu)
    Print_to_Log(1,' => devicename :',devicename)
    Print_to_Log(1,' => dtgmenu_submenus[submenu] :',dtgmenu_submenus[submenu])
    Print_to_Log(1,' => dtgmenu_submenus[submenu].buttons[devicename] :',dtgmenu_submenus[submenu].buttons[devicename])
    realdevicename = dtgmenu_submenus[submenu].buttons[devicename].Name
    Type       = dtgmenu_submenus[submenu].buttons[devicename].Type
    idx        = dtgmenu_submenus[submenu].buttons[devicename].idx
    DeviceType = dtgmenu_submenus[submenu].buttons[devicename].DeviceType
    SwitchType = dtgmenu_submenus[submenu].buttons[devicename].SwitchType
    MaxDimLevel = dtgmenu_submenus[submenu].buttons[devicename].MaxDimLevel
    Print_to_Log(1,' => realdevicename :',realdevicename)
    Print_to_Log(1,' => idx:',idx)
    Print_to_Log(1,' => Type :',Type)
    Print_to_Log(1,' => DeviceType :',DeviceType)
    Print_to_Log(1,' => SwitchType :',SwitchType)
    Print_to_Log(1,' => MaxDimLevel :',MaxDimLevel)
    if DeviceType ~= "command" then
      dummy,dummy,dummy,dummy,dummy,dummy,dstatus,LevelNames,LevelInt = Domo_Devinfo_From_Name(idx,realdevicename,DeviceType)
      Print_to_Log(1,' => dstatus    :',dstatus)
      Print_to_Log(1,' => LevelNames :',LevelNames)
      Print_to_Log(1,' => LevelInt   :',LevelInt)
    end
  end

  local jresponse
  local decoded_response
  local replymarkup = ""

  -------------------------------------------------
  -- process Type="command" (none devices/scenes
  -------------------------------------------------
  if Type == "command" then
    if cmdisaction or (cmdisbutton and ChkEmpty(dtgmenu_submenus[submenu].buttons[devicename].actions)) then
      status=0
      replymarkup, rdevicename = dtgmenuinline.makereplymenu(SendTo,"submenu",submenu)
      Print_to_Log(0,"==<1 found regular lua command. -> hand back to dtgbot to run",commandlinex,parsed_command[2])
      Persistent[SendTo]["iLastcommand"] = parsed_command[2]
      return false, "", replymarkup
    end
  end
  -------------------------------------------------
  -- process submenu button pressed
  -------------------------------------------------
  -- ==== Show Submenu when no device is specified================
  if cmdissubmenu then
    Print_to_Log(1,' - Showing Submenu as no device name specified. submenu: '..submenu)
    local rdevicename
    -- when showactions is defined for a device, the devicename will be returned
    replymarkup, rdevicename = dtgmenuinline.makereplymenu(SendTo,"submenu",submenu)
    -- not an menu command received
    if rdevicename ~= "" then
      Print_to_Log(1," -- Changed to devicelevel due to showactions defined for device "..rdevicename )
      response=dtgmenu_lang[menu_language].text["SelectOptionwo"] .. " " .. rdevicename
    else
      response= submenu .. ":" .. dtgmenu_lang[menu_language].text["Select"]
    end
    status=1
    Print_to_Log(0,"==< show options in submenu.")
    return status, response, replymarkup, commandline;
  end

  -------------------------------------------------------
  -- process device button pressed on one of the submenus
  -------------------------------------------------------
  status=1
  if cmdisbutton then
    -- create reply menu and update table with device details
    replymarkup = dtgmenuinline.makereplymenu(SendTo,"devicemenu",submenu,devicename)
    local switchstatus=""
    local found=0
    if DeviceType == "scenes" then
      if Type == "Group" then
        response = dtgmenu_lang[menu_language].text["SelectGroup"]
        Print_to_Log(0,"==< Show group options menu plus other devices in submenu.")
      else
        response = dtgmenu_lang[menu_language].text["SelectScene"]
        Print_to_Log(0,"==< Show scene options menu plus other devices in submenu.")
      end
    elseif dtgbot_type_status[Type] ~= nil and dtgbot_type_status[Type].DisplayActions == false then
      -- when temp device is selected them just return with resetting keyboard and ask to select device.
      status=1
      response=dtgmenu_lang[menu_language].text["SelectOption"]..dstatus
      Print_to_Log(1,"==< Don't do anything as a temp device was selected.")
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
      Print_to_Log(0,"==< Show device options menu plus other devices in submenu.")
    else
      response = dtgmenu_lang[menu_language].text["Select"]
      Print_to_Log(0,"==< Show options menu plus other devices in submenu.")
    end

    return status, response, replymarkup, commandline;
  end

  -------------------------------------------------
  -- process action button pressed
  -------------------------------------------------
  -- Specials
  -------------------------------------------------
  Print_to_Log(1,"   -> Start Action:"..action)

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
    Print_to_Log(1,"JSON request <"..t..">");
    jresponse, status = http.request(t)
    Print_to_Log(1,"JSON feedback: ", jresponse)
    response="Set "..realdevicename.." to "..action

  elseif SwitchType=="Selector" then
    local sfound,Selector_Option = ChkInTable(LevelNames,action)
    if sfound then
      Selector_Option=(Selector_Option)*10
      Print_to_Log(2,"    -> Selector Switch level found ", Selector_Option,LevelNames,action)
      response=Domo_sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level "..Selector_Option)
    else
      response= "Selector Option not found:"..action
    end
  -------------------------------------------------
  -- regular On/Off/Set Level
  -------------------------------------------------
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["Off"]),string.lower(action)) then
    response= Domo_sSwitchName(realdevicename,DeviceType,SwitchType,idx,'Off')
  elseif ChkInTable(string.lower(dtgmenu_lang[menu_language].switch_options["On"]),string.lower(action)) then
    response= Domo_sSwitchName(realdevicename,DeviceType,SwitchType,idx,'On')
  elseif string.find(action, "%d") then  -- assume a percentage is specified.
    -- calculate the proper level to set the dimmer
    action = action:gsub("%%","") -- remove % sign
    rellev = tonumber(action)*MaxDimLevel/100  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response= Domo_sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  elseif action == "+" or action == "-" then
    -- calculate the proper leve lto set the dimmer
    dstatus=status2number(dstatus)
    Print_to_Log(2," + or - command: dstatus:",tonumber(dstatus),"action..10:",action.."10")
    action = tonumber(dstatus) + tonumber(action.."10")
    if action > 100 then action = 100 end
    if action < 0 then action = 0 end
    rellev = MaxDimLevel/100*tonumber(action)  -- calculate the relative level
    rellev = tonumber(string.format("%.0f", rellev)) -- remove decimals
    action = tostring(rellev)
    response=Domo_sSwitchName(realdevicename,DeviceType,SwitchType,idx,"Set Level " .. action)
  -------------------------------------------------
  -- Unknown Action
  -------------------------------------------------
  else
    response = dtgmenu_lang[menu_language].text["UnknownChoice"] .. action
  end
  status=1

  replymarkup = dtgmenuinline.makereplymenu(SendTo,"devicemenu",submenu,devicename)
  Print_to_Log(0,"==< "..response)
  return status, response, replymarkup, commandline;
end
-----------------------------------------------
--- END the main process handler
-----------------------------------------------
return dtgmenuinline