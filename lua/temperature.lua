local temperature_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function get_temperature(DeviceName)
  idx = Domo_Idx_From_Name(DeviceName,'devices')
  if idx == nil then
    return DeviceName, -999, -999, -999, 0
  end
  Temperature = -999
  Humidity = -999
  Pressure = -999
  -- Determine temperature
  if (DomoticzRevision or 0) > 15325 then
    t = Domoticz_Url.."/json.htm?type=command&param=getdevices&rid=" .. idx
  else
    t = Domoticz_Url.."/json.htm?type=devices&rid=" .. idx
  end

  print ("JSON request <"..t..">");
  jresponse, status = HTTP.request(t)
  decoded_response = JSON.decode(jresponse)
  result = decoded_response["result"]
  record = result[1]
  DeviceType = record["Type"]
  if DeviceType == "Temp" then
    Temperature = record["Temp"]
  else
    if DeviceType == "Humidity" then
      Humidity = record["Humidity"]
    else
      if DeviceType == "Temp + Humidity" then
        Temperature = record["Temp"]
        Humidity = record["Humidity"]
      else
        if DeviceType == "Temp + Humidity + Baro" then
          Temperature = record["Temp"]
          Humidity = record["Humidity"]
          Pressure = record["Barometer"]
        end
      end
    end
  end
  LastUpdate = record["LastUpdate"]
  DeviceName = record["Name"]
  return DeviceName, Temperature, Humidity, Pressure, LastUpdate;
end

function temperature(DeviceName)
  local response = ""
  DeviceName, Temperature, Humidity, Pressure, LastUpdate = get_temperature(DeviceName)
  if Temperature == -999 and Humidity == -999 and Pressure == -999 then
    print(DeviceName..' does not exist')
    return 1, DeviceName..' does not exist'
  else
    if Temperature == -999 and Pressure == -999 then
      print(DeviceName .. ' relative humidity is ' .. Humidity .. '%')
      response = DeviceName.. ' ' .. Humidity .. '%'
    else
      if Pressure ~= -999 then
        print(DeviceName .. ' temperature is ' .. Temperature .. '°C, relative humidity is ' .. Humidity .. '% and pressure is '.. Pressure..'hPa')
        response = DeviceName.. ' ' .. Temperature .. '°C & ' .. Humidity .. '% & '.. Pressure .. 'hPa'
      else
        if Humidity ~= -999 then
          print(DeviceName .. ' temperature is ' .. Temperature .. '°C and relative humidity is ' .. Humidity .. '%')
          response = DeviceName.. ' ' .. Temperature .. '°C & ' .. Humidity .. '%'
        else
          print(DeviceName .. ' temperature is ' .. Temperature .. '°C')
          response = DeviceName.. ' ' .. Temperature .. '°C'
        end
      end
    end
  end
  return status, response;
end

function temperature_module.handler(parsed_cli)
  local t, response, status, decoded_response
  response = ''
  if string.lower(parsed_cli[2]) == 'temperature' then
    DeviceName = Form_Device_name(parsed_cli)
    if DeviceName == nil then
      print('No Temperature Device Name given')
      return 1,'No Temperature Device Name given'
    end
    status, response = temperature(DeviceName)

  elseif string.lower(parsed_cli[2]) == 'tempall' then
    -- get all devices with temp info
    Deviceslist = Domo_Device_List("devices&used=true&filter=temp")
    result = Deviceslist["result"]
    status=""
    for k,record in pairs(result) do
      if type(record) == "table" then
        -- as default simply use the status field
        -- use the dtgbot_type_status to retrieve the status from the "other devices" field as defined in the table.
        if dtgbot_type_status[record.Type] ~= nil then
          if dtgbot_type_status[record.Type].Status ~= nil then
            status = ''
            CurrentStatus = dtgbot_type_status[record.Type].Status
            for i=1, #CurrentStatus do
              if status ~= '' then
                status = status .. ' - '
              end
              cindex, csuffix = next(CurrentStatus[i])
              status = status .. tostring(record[cindex])..tostring(csuffix)
            end
          end
        else
          status = tostring(record.Status)
        end
        Print_to_Log(1," !!!! found temp device",record.Name,record.Type,status)
      end
      response = response .. record.Name .. ":" .. status .. '\n'
    end
  else
    -- Get list of all user variables
    idx = Domo_Idx_From_Variable_Name('DevicesWithTemperatures')
    if idx == 0 then
      print('User Variable DevicesWithTemperatures not set in Domoticz')
      return 1, 'User Variable DevicesWithTemperatures not set in Domoticz'
    end
    -- Get user variable DevicesWithTemperature
    DevicesWithTemperatures = Domo_Get_Variable_Value(idx)
    print(DevicesWithTemperatures)
    -- Retrieve the names
    DeviceNames = Domo_Get_Names_From_Variable(DevicesWithTemperatures)
    -- Loop round each of the devices with temperature
    if DeviceNames ~= nil then
      response = ''
      for i,DeviceName in ipairs(DeviceNames) do
        status, r = temperature(DeviceName)
        response = response .. r .. '\n'
      end
    else
      response = 'No device names found in '..DevicesWithTemperatures
    end
  end
  return status, response
end

local temperature_commands = {
  ["tempall"] = {handler=temperature_module.handler, description="tempall - show all devices with a temperature value."},
  ["temperature"] = {handler=temperature_module.handler, description="temperature - temperature devicename - returns temperature level of devicename and when last updated"},
  ["temperatures"] = {handler=temperature_module.handler, description="temperatures - temperatures - returns temperature level of DevicesWithTemperatures and when last updated"}
}

function temperature_module.get_commands()
  return temperature_commands;
end

return temperature_module;
