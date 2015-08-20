local temperature_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function get_temperature(DeviceName)
  idx = idx_from_name(DeviceName,'devices')
  if idx == nil then
    return DeviceName, -999, -999, -999, 0
  end
  Temperature = -999
  Humidity = -999
  Pressure = -999
-- Determine temperature
  t = server_url.."/json.htm?type=devices&rid=" .. idx
  print ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
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
  local t, jresponse, status, decoded_response
  if string.lower(parsed_cli[2]) == 'temperature' then
    DeviceName = form_device_name(parsed_cli)
    if DeviceName == nil then
      print('No Temperature Device Name given')
      return 1,'No Temperature Device Name given'
    end
    status, response = temperature(DeviceName)
  else
    idx = idx_from_variable_name('DevicesWithTemperatures')
    -- Get list of all user variables
--    t = server_url.."/json.htm?type=command&param=getuservariables"
--    print ("JSON request <"..t..">");  
--    jresponse, status = http.request(t)
--    decoded_response = JSON:decode(jresponse)
--    result = decoded_response["result"]
--    idx = 0
--    for k,record in pairs(result) do
--      if type(record) == "table" then
--        if record['Name'] == 'DevicesWithTemperatures' then
--          print(record['idx'])
--          idx = record['idx']
--        end
--      end
--    end
    if idx == 0 then
      print('User Variable DevicesWithTemperatures not set in Domoticz')
      return 1, 'User Variable DevicesWithTemperatures not set in Domoticz'
    end
    -- Get user variable DevicesWithTemperature
    DevicesWithTemperatures = get_variable_value(idx)
--    t = server_url.."/json.htm?type=command&param=getuservariable&idx="..idx
--    print ("JSON request <"..t..">");  
--    jresponse, status = http.request(t)
--    decoded_response = JSON:decode(jresponse)
--    result = decoded_response["result"]
--    record = result[1]
--    DevicesWithTemperatures = record["Value"]
--    DeviceNames = {}
    print(DevicesWithTemperatures)
--    for DeviceName in string.gmatch(DevicesWithTemperatures, "[^|]+") do
--      DeviceNames[#DeviceNames + 1] = DeviceName
--    end
    -- Retrieve the names
    DeviceNames = get_names_from_variable(DevicesWithTemperatures)
    -- Loop round each of the devices with temperature
    response = ''
    for i,DeviceName in ipairs(DeviceNames) do
      status, r = temperature(DeviceName)
      response = response .. r .. '\n'
    end
  end
  return status, response
end

local temperature_commands = {
  ["temperature"] = {handler=temperature_module.handler, description="temperature - temperature devicename - returns temperature level of devicename and when last updated"},
  ["temperatures"] = {handler=temperature_module.handler, description="temperatures - temperatures - returns temperature level of DevicesWithTemperatures and when last updated"}
}

function temperature_module.get_commands()
  return temperature_commands;
end

return temperature_module;
