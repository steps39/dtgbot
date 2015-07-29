local on_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function SwitchID(DeviceName, idx, DeviceType, state, SendTo)
	if string.lower(state) == "on" then
        	state = "On";
       	elseif string.lower(state) == "off" then
        	state = "Off";
        else
        	return "state must be on or off!";
        end
        t = server_url.."/json.htm?type=command&param=switch"..DeviceType.."&idx="..idx.."&switchcmd="..state;
        print ("JSON request <"..t..">");
        jresponse, status = http.request(t)
        print("raw jason", jresponse)
        response = 'Switched '..DeviceName..' '..command
	return response
end

function switch(parsed_cli)
  command = parsed_cli[2]
  DeviceName = form_device_name(parsed_cli)
  if DeviceName ~= nil then
    print('Device Name: '..DeviceName)
    -- DeviceName can either be a device / group / scene name or a number refering to list previously generated
    if tonumber(DeviceName) ~= nil then
      NewDeviceName = StoredList[tonumber(DeviceName)]
      if NewDeviceName == nil then
        response = 'No '..StoredType..' with number '..DeviceName..' was found - please execute devices or scenes command with qualifier to generate list'
        return status, response
      else
        DeviceName = NewDeviceName
      end
    end
    -- Update the list of device names and ids to be checked later
    -- Check if DeviceName is a device
    DeviceID = idx_from_name(DeviceName,'devices')
    switchtype = 'light'
    -- Its not a device so check if a scene
    if DeviceID == nil then
      DeviceID = idx_from_name(DeviceName,'scenes')
      switchtype = 'scene'
    end
    if DeviceID ~= nil then
      -- Now switch the device
      response = SwitchID(DeviceName, DeviceID, switchtype, command, SendTo)
    else   
      response = 'Device '..DeviceName..' was not found on Domoticz - please check spelling and capitalisation'
    end
  else
    response = 'No device specified'
  end
  return response
end 

function on_module.handler(parsed_cli)
	local response = ""
        response = switch(parsed_cli)
	return status, response;
end

local on_commands = {
			["on"] = {handler=on_module.handler, description="on - on devicename - switches devicename on"},
			["off"] = {handler=on_module.handler, description="off - off devicename - switches devicename off"}
		      }

function on_module.get_commands()
	return on_commands;
end

return on_module;
