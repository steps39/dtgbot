-- A set of support functions currently aimed at dtgbot,
-- but probably more general

-- joins together parameters after the command name to form the full "device name"
function form_device_name(parsed_cli)
  command = parsed_cli[2]
  DeviceName = parsed_cli[3]
  len_parsed_cli = #parsed_cli
  if len_parsed_cli > 3 then
    for i = 4, len_parsed_cli do
      DeviceName = DeviceName..' '..parsed_cli[i]
    end
  end
  return DeviceName
end

-- returns list of all user variables - called early by dtgbot
-- in case Domoticz is not running will retry
-- allowing Domoticz time to start
function variable_list()
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type=command&param=getuservariables"
  jresponse = nil
  domoticz_tries = 1
  -- Domoticz seems to take a while to respond to getuservariables after start-up
  -- So just keep trying after 1 second sleep
  while (jresponse == nil) do
    print_to_log(1,"JSON request <"..t..">");
    jresponse, status = http.request(t)
    if (jresponse == nil) then
      socket.sleep(1)
      domoticz_tries = domoticz_tries + 1
      if domoticz_tries > 100 then
        print_to_log(0,'Domoticz not sending back user variable list')
        break
      end
    end
  end
  print_to_log(0,'Domoticz returned getuservariables after '..domoticz_tries..' attempts')
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

-- returns idx of a user variable from name
function variable_list_names_idxs()
  local idx, k, record, decoded_response
  decoded_response = variable_list()
  result = decoded_response["result"]
  variables = {}
  for i = 1, #result do
    record = result[i]
    if type(record) == "table" then
      variables[record['Name']] = record['idx']
    end
  end
  return variables
end


-- returns device name from idx and idx from device name if stored in device table
-- wrapper for device table
function idx_from_variable_name(DeviceName)
  return Variablelist[DeviceName]
end

-- returns the value of the variable from the idx
function get_variable_value(idx)
  local t, jresponse, decoded_response
  if idx == nill then
    return ""
  end
  t = server_url.."/json.htm?type=command&param=getuservariable&idx="..tostring(idx)
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  print_to_log(0,'Decoded '..decoded_response["result"][1]["Value"])
  return decoded_response["result"][1]["Value"]
end

-- sets the value of the variable based on idx requires name and devicetype 
function set_variable_value(idx,name,devicetype,value)
  -- store the value of a user variable
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=updateuservariable&idx="..idx.."&vname="..name.."&vtype="..devicetype.."&vvalue="..tostring(value)
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  return
end

function create_variable(name,type,value)
  -- creates user variable
  local t, jresponse, decoded_response
  t = server_url.."/json.htm?type=command&param=saveuservariable&vname="..name.."&vtype="..type.."&vvalue="..tostring(value)
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  return
end

-- returns multiple names from string separated by |
function get_names_from_variable(DividedString)
  Names = {}
  for Name in string.gmatch(DividedString, "[^|]+") do
    Names[#Names + 1] = Name
    print_to_log(1,'Name :'..Name)
  end
  if Names == {} then
    Names = nil
  end
  return Names
end

-- returns a device table of Domoticz items based on type i.e. devices or scenes
function device_list(DeviceType)
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type="..DeviceType.."&order=name&used=true"
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

-- returns a list of Domoticz items based on type i.e. devices or scenes
function device_list_names_idxs(DeviceType)
  local idx, k, record, decoded_response
  decoded_response = device_list(DeviceType)
  result = decoded_response['result']
  if result ~= nil then
    devices = {}
    devicesproperties = {}
    for i = 1, #result do
      record = result[i]
      if type(record) == "table" then
        if DeviceType == "plans" then
          devices[record['Name']] = record['idx']
        else
          devices[string.lower(record['Name'])] = record['idx']
          devices[record['idx']] = record['Name']
          if DeviceType == 'scenes' then
            devicesproperties[record['idx']] = {Type=record['Type'], SwitchType = record['Type']}
          end
        end
      end
    end
    return devices, devicesproperties
  else
    print_to_log(0,'device_list_names_idxs',DeviceType,'No items returned from Domoticz')
    return nil, nil
  end
end

--returns a devcie idx based on its name
function idx_from_name(DeviceName,DeviceType)
  if DeviceType == "devices" then
    return Devicelist[string.lower(DeviceName)]
  elseif DeviceType == "scenes" then
    return Scenelist[string.lower(DeviceName)]
  else
    return Roomlist[DeviceName]
  end
end

-- returns the status of a device based on idx
function retrieve_status(idx,DeviceType)
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type="..DeviceType.."&rid="..tostring(idx)
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  return decoded_response
end

-- support function to scan through the Devices and Scenes idx tables and retrieve the required information for it
function devinfo_from_name(idx,DeviceName,DeviceScene)
  local k, record, Type,DeviceType,SwitchType
  local found = 0
  local rDeviceName=""
  local status=""
  local MaxDimLevel=100
  local ridx=0
  if DeviceScene~="scenes" then
    -- Check for Devices
    -- Have the device name
    if DeviceName ~= "" then
      idx = idx_from_name(DeviceName,'devices')
    end
    print_to_log(2,"==> start devinfo_from_name", idx,DeviceName)
    if idx ~= nil then
      record = retrieve_status(idx,"devices")['result'][1]
      print_to_log(2,'device ',DeviceName,record.Name,idx,record.idx)
      if type(record) == "table" then
        ridx = record.idx
        rDeviceName = record.Name
        DeviceType="devices"
        Type=record.Type
        -- as default simply use the status field
        -- use the dtgbot_type_status to retrieve the status from the "other devices" field as defined in the table.
        if dtgbot_type_status[Type] ~= nil then
          if dtgbot_type_status[Type].Status ~= nil then
            status = ''
            CurrentStatus = dtgbot_type_status[Type].Status
            for i=1, #CurrentStatus do
              if status ~= '' then
                status = status .. ' - '
              end
              cindex, csuffix = next(CurrentStatus[i])
              status = status .. tostring(record[cindex])..tostring(csuffix)
            end
          end
        else
          SwitchType=record.SwitchType
          MaxDimLevel=record.MaxDimLevel
          status = tostring(record.Status)
        end
        found = 1
        print_to_log(2," !!!! found device",record.Name,rDeviceName,record.idx,ridx)
      end
    end
    print_to_log(2," !!!! found device",rDeviceName,ridx)
  end
-- Check for Scenes
  if found == 0 then
    if DeviceName ~= "" then
      idx = idx_from_name(DeviceName,'scenes')
    else
      DeviceName = idx_from_name(idx,'scenes')
    end
    if idx ~= nil then
      DeviceName = Scenelist[idx]
      DeviceType="scenes"
      ridx = idx
      rDeviceName = DeviceName
      SwitchType = Sceneproperties[tostring(idx)]['SwitchType']
      Type = Sceneproperties[tostring(idx)]['Type']
      found = 1
    end
  end
-- Check for Scenes
  if found == 0 then
    ridx = 9999
    DeviceType="command"
    Type="command"
    SwitchType="command"
  end
  print_to_log(2," --< devinfo_from_name:",found,ridx,rDeviceName,DeviceType,Type,SwitchType,status)
  return ridx,rDeviceName,DeviceType,Type,SwitchType,MaxDimLevel,status
end

-- returns true if file exists
function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end

--returns 2 character language string set in Domoticz
function domoticz_language()
  local t, jresponse, status, decoded_response
  t = server_url.."/json.htm?type=command&param=getlanguage"
  jresponse = nil
  print_to_log(1,"JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  local language = decoded_response['language']
  if language ~= nil then
    return language
  else
    return 'en'
  end
end