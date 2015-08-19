local temperature_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function get_temperature(DeviceName)
  idx = idx_from_name(DeviceName,'devices')
  if idx == nil then
    return DeviceName, -999, -999, 0
  end
-- Determine temperature
  t = server_url.."/json.htm?type=devices&rid=" .. idx
  print ("JSON request <"..t..">");
  jresponse, status = http.request(t)
  decoded_response = JSON:decode(jresponse)
  result = decoded_response["result"]
  record = result[1]
  Temperature = record["Temp"]
  if record["Type"] == "Temp + Humidity" then
    Humidity = record["Humidity"]
  else
    Humidity = -999
  end
  LastUpdate = record["LastUpdate"]
  DeviceName = record["Name"]
  return DeviceName, Temperature, Humidity, LastUpdate;
end

function temperature(DeviceName)
  local response = ""
  DeviceName, Temperature, Humidity, LastUpdate = get_temperature(DeviceName)
  if Temperature == -999 then
    print(DeviceName..' does not exist')
    return 1, DeviceName..' does not exist'
  end
  if Humidity ~= -999 then
    print(DeviceName .. ' temperature is ' .. Temperature .. '°C and relative humidity is ' .. Humidity .. '%')
    response = DeviceName.. ' ' .. Temperature .. '°C & ' .. Humidity .. '%'
  else
    print(DeviceName .. ' temperature is ' .. Temperature .. '°C')
    response = DeviceName.. ' ' .. Temperature .. '°C'
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
    -- Get list of all user variables
    idx = idx_from_variable_name('DevicesWithTemperatures')
    if idx == 0 then
      print('User Variable DevicesWithTemperatures not set in Domoticz')
      return 1, 'User Variable DevicesWithTemperatures not set in Domoticz'
    end
    -- Get user variable DevicesWithTemperature
    DevicesWithTemperatures = get_variable_value(idx)
    print(DevicesWithTemperatures)
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
