local help_module = {};
local http = require "socket.http";
--JSON = assert(loadfile "JSON.lua")() -- one-time load of the routines

--- the handler for the list commands. a module can have more than one handler. in this case the same handler handles two commands
function help_module.handler(parsed_cli)
	local response = "", status;

  command = parsed_cli[3]
  if (command ~= "" and command ~= nil) then
    command_dispatch = commands[string.lower(command)];
    if command_dispatch then
      response = command_dispatch.description;
    else
      response = command..' was not found - check spelling and capitalisation - Help for list of commands'
    end
    return status, response
  end
  local DotPos = 0
  HelpText='⚠️ Start Menu: /menu ⚠️ \n\n'
  HelpText=HelpText..'⚠️ Available Lua commands ⚠️ \n'
  for i,help in pairs(commands) do
    print_to_log(help.description)
   --send_msg(SendTo,help,ok_cb,false)
    HelpText = HelpText.."/"..string.gmatch(help.description, "%S+")[[1]]..', '
  end
  HelpText = string.sub(HelpText,1,-3)..'\nHelp Command - gives usage information, i.e. Help On \n\n'
--  send_msg(SendTo,HelpText,ok_cb,false)
  local Functions = io.popen("ls " .. UserScriptPath)
  HelpText = HelpText..'⚠️ Available Shell commands ⚠️ \n'
  for line in Functions:lines() do
    print_to_log(line)
    DotPos=string.find(line, "%.")
    HelpText = HelpText .. "-" .. "/"..string.sub(line,0,DotPos-1).."\n"
  end
	return status, HelpText;
end

local help_commands = {
			["help"] = {handler=help_module.handler, description="help - list all help information"},
			["start"] = {handler=help_module.handler, description="start - list all help information"}
        }

function help_module.get_commands()
	return help_commands;
end

return help_module;
