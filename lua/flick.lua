local flick_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

function flick_module.handler(parsed_cli)
	local response = "", jresponse, decoded_response, status;

	local i, idx, state, t;
	for i, t in ipairs(parsed_cli) do
		print(i, t)
	end


	if parsed_cli[3] then
		idx = tonumber(parsed_cli[3]);
    print('In flick idx: '..idx)
		if parsed_cli[4] then
			state = parsed_cli[4];
		else
			state = "On";
		end
		if string.lower(state) == "on" then
			state = "On";
		elseif string.lower(state) == "off" then
			state = "Off";
		else
			return status, "state must be on or off!";
		end
	else
		return status, "Device idx must be given!"
	end

	print("in flick_handler!");
	t = server_url.."/json.htm?type=command&param=switchlight&idx="..idx.."&switchcmd="..state.."&level=0";
	print ("JSON request <"..t..">");
	jresponse, status = http.request(t)
	print("raw jason", jresponse)
	decoded_response = JSON:decode(jresponse)
	for k,record in pairs(decoded_response) do
		print(k, type(record))
		if type(record) == "table" then
			for k1, v1 in pairs(record) do
				if string.find(string.lower(v1.Type), match_type) then
					response = response..list_device_attr(v1, mode).."\n";
				end
				print(k1, v1)
			end
		else
			print(record)
		end
	end
	return status, response;
end

local flick_commands = {
			["flick"] = {handler=flick_module.handler, description="flick a switch by idx"}
		      }

function flick_module.get_commands()
	return flick_commands;
end

return flick_module;
