local list_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

--- the handler for the list commands. a module can have more than one handler. in this case the same handler handles two commands
function list_module.handler(parsed_cli)
	local response = "", jresponse, decoded_response, status;

	local match_type, mode;
	local i;

	if parsed_cli[2] == "dump" then
		mode = "full";
	else
		mode = "brief";
	end
	if parsed_cli[3] then
		match_type = string.lower(parsed_cli[3]);
	else
		match_type = "";
	end

	jresponse, status = http.request(server_url.."/json.htm?type=devices")
	decoded_response = JSON:decode(jresponse)
	for k,record in pairs(decoded_response) do
		print_to_log(k, type(record))
		if type(record) == "table" then
			for k1, v1 in pairs(record) do
				if string.find(string.lower(v1.Type), match_type) then
					response = response..list_device_attr(v1, mode).."\n";
				end
--				print_to_log(k1, v1)
			end
		else
			print_to_log(record)
		end
	end
  print_to_log(response)
	return status, response;
end

local list_commands = {
			["list"] = {handler=list_module.handler, description="List devices, either all or specific type"},
			["dump"] = {handler=list_module.handler, description="List all information about devices, either all or specific type"}
		      }

function list_module.get_commands()
	return list_commands;
end

return list_module;
