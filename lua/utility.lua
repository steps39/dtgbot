local utility_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

--- the handler for the list commands. a module can have more than one handler. in this case the same handler handles two commands
function utility_module.handler(parsed_cli)
  local response = "", status;

  command = parsed_cli[2]
  if string.lower(command) == 'refresh' then
    dtgbot_initialise()
    return status, 'Global device, scene and room variables updated from Domoticz and modules code reloaded';
  else
    return status, 'Wrong command'
  end
end

local utility_commands = {
  ["refresh"] = {handler=utility_module.handler, description="refresh - reloads global variables and modules code"}
}

function utility_module.get_commands()
  return utility_commands;
end

return utility_module;
