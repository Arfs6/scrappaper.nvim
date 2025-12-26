--[[
--plugin file for `scrappaper.nvim` plugin.
--It creates the `ScrapPaper` command if the module hasn't been loaded yet.
--]]

if vim.g.loaded_scrappaper then return end
vim.g.loaded_scrappaper = 1

--[[
--Creates a new user command with name `ScrapPaper`.
--If a user command with name `ScrapPaper` already exist, overwride it.
--The command toggles the Scrap Paper window.
--]]
local commands = { 'swap', 'save', 'prev', 'next' }
vim.api.nvim_create_user_command(
	'ScrapPaper',
	function(command_args)
		for _, command in pairs(commands) do
			if command == command_args.args then
				require('scrappaper')[command]()
				return
			end
		end
		vim.notify(
			'Error: scrappaper.nvim - Unknown scrappaper command: ' .. command_args.args,
			vim.log.levels.ERROR,
			{}
		)
	end,
	{
		nargs = 1,
		complete = function(ArgLead, CmdLine, CursorPos)
			return { 'swap', 'save', 'next', 'prev' }
		end
	}
)
