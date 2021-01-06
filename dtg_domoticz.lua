--[[
  Version 0.9 20210106
  A set of support functions currently aimed at dtgbot,
  but probably more general
]]
function Form_Device_name(parsed_cli)
  -- joins together parameters after the command name to form the full "device name"
  Print_to_Log(0, parsed_cli[2])
  DeviceName = parsed_cli[3]
  Print_to_Log(0, parsed_cli[3])
  local len_parsed_cli = #parsed_cli
  if len_parsed_cli > 3 then
    for i = 4, len_parsed_cli do
      DeviceName = DeviceName .. " " .. parsed_cli[i]
      Print_to_Log(0, parsed_cli[i])
    end
  end
  Print_to_Log(0, DeviceName)
  return DeviceName
end

function Form_Device_names(parsed_cli)
  -- joins together parameters after the command name to form the full "device name"
  --command = parsed_cli[2]
  DeviceNames = {}
  DeviceNames[1] = ""
  local j = 1
  local len_parsed_cli = #parsed_cli
  local bit
  for i = 3, len_parsed_cli do
    bit = parsed_cli[i]
    if not (string.match(bit, ",")) then
      bit = string.gsub(bit, " ", "")
      if (DeviceNames[j] == "") then
        DeviceNames[j] = bit
      else
        DeviceNames[j] = DeviceNames[j] .. " " .. bit
      end
    else
      -- Needed to deal with , ,word, word,word etc..
      bit = string.gsub(bit, ",", " , ")
      for w in string.gmatch(bit, "([^ ]+)") do
        w = string.gsub(w, " ", "")
        if (w == ",") then
          j = j + 1
          DeviceNames[j] = ""
        else
          if (DeviceNames[j] == "") then
            DeviceNames[j] = w
          else
            DeviceNames[j] = DeviceNames[j] .. " " .. w
          end
        end
      end
    end
  end
  return DeviceNames
end

-- returns list of all user variables - called early by dtgbot
-- in case Domoticz is not running will retry
-- allowing Domoticz time to start
function Domo_Variable_List()
  local t, jresponse, status, decoded_response
  t = Domoticz_Url .. "/json.htm?type=command&param=getuservariables"
  jresponse = nil
  local domoticz_tries = 1
  -- Domoticz seems to take a while to respond to getuservariables after start-up
  -- So just keep trying after 1 second sleep
  while (jresponse == nil) do
    Print_to_Log(1, "JSON request <" .. t .. ">")
    jresponse, status = HTTP.request(t)
    if (jresponse == nil) then
      SOCKET.sleep(1)
      domoticz_tries = domoticz_tries + 1
      if domoticz_tries > 20 then
        Print_to_Log(0, "Domoticz not sending back user variable list")
        break
      end
    end
  end
  Print_to_Log(0, "Domoticz returned getuservariables after " .. domoticz_tries .. " attempts")
  if jresponse ~= nil then
    decoded_response = JSON.decode(jresponse)
  else
    decoded_response = {}
    decoded_response["result"] = "{}"
  end
  return decoded_response
end

-- returns idx of a user variable from name
function Domo_Variable_List_Names_IDXs()
  local record, decoded_response, result
  decoded_response = Domo_Variable_List()
  result = decoded_response["result"]
  local variables = {}
  for i = 1, #result do
    record = result[i]
    if type(record) == "table" then
      variables[record["Name"]] = record["idx"]
    end
  end
  return variables
end

function Domo_Idx_From_Variable_Name(DeviceName)
  return Variablelist[DeviceName]
end

-- returns the value of the variable from the idx
function Domo_Get_Variable_Value(idx)
  local t, decoded_response
  if idx == nil then
    return ""
  end
  t = Domoticz_Url .. "/json.htm?type=command&param=getuservariable&idx=" .. tostring(idx)
  Print_to_Log(1, "JSON request <" .. t .. ">")
  local jresponse, status = HTTP.request(t)
  decoded_response = JSON.decode(jresponse)
  Print_to_Log(1, Sprintf("Idx:%s  Value:%s ", idx, decoded_response["result"][1]["Value"]))
  return decoded_response["result"][1]["Value"]
end

function Domo_Set_Variable_Value(idx, name, Type, value)
  -- store the value of a user variable
  local t, jresponse, decoded_response
  t = Domoticz_Url .. "/json.htm?type=command&param=updateuservariable&idx=" .. idx .. "&vname=" .. name .. "&vtype=" .. Type .. "&vvalue=" .. tostring(value)
  Print_to_Log(1, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  return
end

-- ### Not Used currently
function Domo_Create_Variable(name, Type, value)
  -- creates user variable
  local t, jresponse, decoded_response
  t = Domoticz_Url .. "/json.htm?type=command&param=saveuservariable&vname=" .. name .. "&vtype=" .. Type .. "&vvalue=" .. tostring(value)
  Print_to_Log(1, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  return
end

function Domo_Get_Names_From_Variable(DividedString)
  local Names = {}
  for Name in string.gmatch(DividedString, "[^|]+") do
    Names[#Names + 1] = Name
    Print_to_Log(1, "Name :" .. Name)
  end
  if Names == {} then
    Names = nil
  end
  return Names
end

-- returns a device table of Domoticz items based on type i.e. devices or scenes
function Domo_Device_List(DeviceType)
  local t, jresponse, status, decoded_response
  t = Domoticz_Url .. "/json.htm?type=" .. DeviceType .. "&order=name&used=true"
  Print_to_Log(1, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  if jresponse ~= nil then
    decoded_response = JSON.decode(jresponse)
  else
    decoded_response = {}
    decoded_response["result"] = "{}"
  end
  return decoded_response
end

-- returns a list of Domoticz items based on type i.e. devices or scenes
function Domo_Device_List_Names_IDXs(DeviceType)
  --returns a device idx based on its name
  local record, decoded_response
  decoded_response = Domo_Device_List(DeviceType)
  local result = decoded_response["result"]
  local devices = {}
  local devicesproperties = {}
  if result ~= nil then
    for i = 1, #result do
      record = result[i]
      if type(record) == "table" then
        if DeviceType == "plans" then
          devices[record["Name"]] = record["idx"]
        else
          devices[string.lower(record["Name"])] = record["idx"]
          devices[record["idx"]] = record["Name"]
          if DeviceType == "scenes" then
            devicesproperties[record["idx"]] = {Type = record["Type"], SwitchType = record["Type"]}
          end
        end
      end
    end
  else
    Print_to_Log(0, " !!!! Domo_Device_List_Names_IDXs(): nothing found for ", DeviceType)
  end
  return devices, devicesproperties
end

function Domo_Idx_From_Name(DeviceName, DeviceType)
  --returns a device idx based on its name
  if DeviceType == "devices" then
    return Devicelist[string.lower(DeviceName)]
  elseif DeviceType == "scenes" then
    return Scenelist[string.lower(DeviceName)]
  else
    return Roomlist[DeviceName]
  end
end

function Domo_Retrieve_Status(idx, DeviceType)
  local t, jresponse, status, decoded_response
  t = Domoticz_Url .. "/json.htm?type=" .. DeviceType .. "&rid=" .. tostring(idx)
  Print_to_Log(2, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  if jresponse ~= nil then
    decoded_response = JSON.decode(jresponse)
  else
    decoded_response = {}
    decoded_response["result"] = ""
  end
  return decoded_response
end

-- support function to scan through the Devices and Scenes idx tables and retrieve the required information for it
function Domo_Devinfo_From_Name(idx, DeviceName, DeviceScene)
  local k, record, Type, DeviceType, SwitchType
  local found = 0
  local rDeviceName = ""
  local status = ""
  local LevelNames = ""
  local LevelInt = 0
  local MaxDimLevel = 100
  local ridx = 0
  local tvar
  if DeviceScene ~= "scenes" then
    -- Check for Devices
    -- Have the device name
    if DeviceName ~= "" then
      idx = Domo_Idx_From_Name(DeviceName, "devices")
    end
    Print_to_Log(2, "==> start Domo_Devinfo_From_Name", idx, DeviceName)
    if idx ~= nil then
      tvar = Domo_Retrieve_Status(idx, "devices")["result"]
      if tvar == nil then
        found = 9
      else
        record = tvar[1]
        if record ~= nil and record.Name ~= nil and record.idx ~= nil then
          Print_to_Log(2, "device ", DeviceName, record.Name, idx, record.idx)
        end
        if type(record) == "table" then
          ridx = record.idx
          rDeviceName = record.Name
          DeviceType = "devices"
          Type = record.Type
          LevelInt = record.LevelInt
          if LevelInt == nil then
            LevelInt = 0
          end
          LevelNames = record.LevelNames
          if LevelNames == nil then
            LevelNames = ""
          end
          -- as default simply use the status field
          -- use the dtgbot_type_status to retrieve the status from the "other devices" field as defined in the table.
          Print_to_Log(2, "Type ", Type)
          if dtgbot_type_status[Type] ~= nil then
            Print_to_Log(2, "dtgbot_type_status[Type] ", dtgbot_type_status[Type])
            if dtgbot_type_status[Type].Status ~= nil then
              status = ""
              CurrentStatus = dtgbot_type_status[Type].Status
              Print_to_Log(2, "CurrentStatus ", CurrentStatus)
              for i = 1, #CurrentStatus do
                if status ~= "" then
                  status = status .. " - "
                end
                cindex, csuffix = next(CurrentStatus[i])
                status = status .. tostring(record[cindex]) .. tostring(csuffix)
                Print_to_Log(2, "status ", status)
              end
            end
          else
            SwitchType = record.SwitchType
            -- Check for encoded selector LevelNames
            if SwitchType == "Selector" then
              if string.find(LevelNames, "[|,]+") then
                Print_to_Log(2, "--  < 4.9700 selector switch levelnames: ", LevelNames)
              else
                LevelNames = MIME.unb64(LevelNames)
                Print_to_Log(2, "--  >= 4.9700  decoded selector switch levelnames: ", LevelNames)
              end
            end
            MaxDimLevel = record.MaxDimLevel
            status = tostring(record.Status)
          end
          found = 1
        --~         Print_to_Log(2," !!!! found device",record.Name,rDeviceName,record.idx,ridx)
        end
      end
    end
  --~     Print_to_Log(2," !!!! found device",rDeviceName,ridx)
  end
  -- Check for Scenes
  if found == 0 then
    if DeviceName ~= "" then
      idx = Domo_Idx_From_Name(DeviceName, "scenes")
    else
      DeviceName = Domo_Idx_From_Name(idx, "scenes")
    end
    if idx ~= nil then
      DeviceName = Scenelist[idx]
      DeviceType = "scenes"
      ridx = idx
      rDeviceName = DeviceName
      SwitchType = Sceneproperties[tostring(idx)]["SwitchType"]
      Type = Sceneproperties[tostring(idx)]["Type"]
      found = 1
    end
  end
  -- Check for Scenes
  if found == 0 or found == 9 then
    ridx = 9999
    DeviceType = "command"
    Type = "command"
    SwitchType = "command"
  end
  Print_to_Log(2, " --< Domo_Devinfo_From_Name:", found, ridx, rDeviceName, DeviceType, Type, SwitchType, status, LevelNames, LevelInt)
  return ridx, rDeviceName, DeviceType, Type, SwitchType, MaxDimLevel, status, LevelNames, LevelInt
end

-- Switch functions
function Domo_SwitchID(DeviceName, idx, DeviceType, state, SendTo)
  if string.lower(state) == "on" then
    state = "On"
  elseif string.lower(state) == "off" then
    state = "Off"
  else
    return "state must be on or off!"
  end
  t = Domoticz_Url .. "/json.htm?type=command&param=switch" .. DeviceType .. "&idx=" .. idx .. "&switchcmd=" .. state
  Print_to_Log(1, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  Print_to_Log(1, "raw jason", jresponse)
  response = "Switched " .. DeviceName .. " " .. state
  return response
end

function Domo_sSwitchName(DeviceName, DeviceType, SwitchType, idx, state)
  local status
  if idx == nil then
    response = "Device " .. DeviceName .. "  not found."
  else
    local subgroup = "light"
    if DeviceType == "scenes" then
      subgroup = "scene"
    end
    if string.lower(state) == "on" then
      state = "On"
      t = Domoticz_Url .. "/json.htm?type=command&param=switch" .. subgroup .. "&idx=" .. idx .. "&switchcmd=" .. state
    elseif string.lower(state) == "off" then
      state = "Off"
      t = Domoticz_Url .. "/json.htm?type=command&param=switch" .. subgroup .. "&idx=" .. idx .. "&switchcmd=" .. state
    elseif string.lower(string.sub(state, 1, 9)) == "set level" then
      t = Domoticz_Url .. "/json.htm?type=command&param=switch" .. subgroup .. "&idx=" .. idx .. "&switchcmd=Set%20Level&level=" .. string.sub(state, 11)
    else
      return "state must be on, off or set level!"
    end
    Print_to_Log(3, "JSON request <" .. t .. ">")
    jresponse, status = HTTP.request(t)
    Print_to_Log(3, "JSON feedback: ", jresponse)
    response = DTGMenu_translate_desc(Language, "Switched") .. " " .. (DeviceName or "?") .. " => " .. (state or "?")
  end
  Print_to_Log(0, "   -< Domo_sSwitchName:", DeviceName, idx, status, response)
  return response, status
end

-- other functions
function FileExists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function Domoticz_Language()
  local t, jresponse, status, decoded_response
  t = Domoticz_Url .. "/json.htm?type=command&param=getlanguage"
  jresponse = nil
  Print_to_Log(1, "JSON request <" .. t .. ">")
  jresponse, status = HTTP.request(t)
  if jresponse ~= nil then
    decoded_response = JSON.decode(jresponse)
  else
    decoded_response = {}
    decoded_response["result"] = "{}"
  end
  local Language = decoded_response["Language"]
  if Language ~= nil then
    return Language
  else
    return "en"
  end
end
