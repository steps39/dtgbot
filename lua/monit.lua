local monit_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

--- the handler for the list commands. a module can have more than one handler. in this case the same handler handles two commands
function monit_module.handler(parsed_cli)
	local response = "", jresponse, decoded_response, status, action;
	local replymarkup = ""
	local match_type, mode;
	local i;
	if parsed_cli[3] == nil then
		action = ""
	else
		action = string.lower(parsed_cli[3])
	end
	print("action:"..action)
	if action == "on" then
		status=1
		os.execute("sudo monit monitor all&&sleep 3")
		os.execute("sudo monit reload&&sleep 2")
		os.execute("sudo service monit restart&&sleep 5")
--~ 		replymarkup = '{"keyboard":[["Monit Off"],["Monit Ok"]],"one_time_keyboard":true}'
--~ 		replymarkup = ''
	elseif action == "off"  then
		os.execute("sudo monit unmonitor all&&sleep 5")
		response = "Monit monitoring stopped"
--~ 		replymarkup = '{"keyboard":[["Monit On"],["Monit Ok"]],"one_time_keyboard":true}'
		status=1
	elseif action == "ok"  then
		response = "ok"
--~ 		replymarkup = default_replymarkup
		status=1
	else
		local handle = io.popen("sudo monit summary")
		response = string.gsub(handle:read("*a"), "\n", "\n")
		handle:close()
		print("msg:"..response)
		print("KB:"..replymarkup)
		status=0
	end

	print(response)
	return status, response, replymarkup;
end

local monit_commands = {
			["monit"] = {handler=monit_module.handler, description="Manage Monit: monit (on/off)"}
		      }

function monit_module.get_commands()
	return monit_commands;
end

return monit_module;
