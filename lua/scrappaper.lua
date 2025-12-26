--[[
--`ScrapPaper` plugin.
--This file contains the code for the plugin.
--The swap function swaps between the current buffer and a scrap paper buffer.
--The save function saves the content of the current buffer.
--It does that by converting the content of the buffer to json using `vim.fn.json_encode` and storing the result in a file.
--The path to the file is saved in `m.storage_path`
--the prev and next functions move to the most recent and least recent saved scrap papers respectively.
--the load function reads the stored scrap papers, converts it to a lua table and stores it.
--]]

local api = vim.api

local m = {}

-- Set the buffer name.
m.buf_name = 'Scrap Paper'
-- Set the path to stored scrap papers.
local path_sep = '/'
-- Path separator in windows is \.
if vim.env['OS'] == 'Windows_NT' then
	path_sep = '\\'
end
m.storage_path = vim.fn.stdpath('data') .. path_sep .. 'scrappaper_storage.json'
m.max_saved_scrap_papers = 16

local empty_storage_msg = 'Storage is empty'

-- [[
--create_buffer - Creates a scrap paper buffer and sets its name.
-- Also creates auto commands for `BufLeave` and `BufDelete` to manage variables.
-- ]]
local create_buffer = function()
	m.buf_id = api.nvim_create_buf(false, true) -- create a not listed scratch buffer.
	if m.buf_id == 0 then
		print('Error: scrappaper.nvim - unable to create new scratch buffer.')
		m.buf_id = nil
	end
	api.nvim_buf_set_name(m.buf_id, m.buf_name)

	-- Create an auto command that deletes the `m.buf_id` variable when deleting the buffer.
	api.nvim_create_autocmd('BufUnload', {
		buffer = m.buf_id,
		callback = function()
			m.buf_id = nil
		end
	})
end

-- [[
--swap - swaps the content of the current buffer with a scrap paper or the other way round.
-- When the function is called outside a scrap paper, it saves the name of the previous buffer, then replaces the current buffer with a scrap paper buffer.
-- When the function is called while in a scrap paper, it tries to return to the previous buffer.
-- ]]
m.swap = function()
	if api.nvim_get_current_buf() == m.buf_id then
		-- Current buffer is a scrap paper.
		if m.prev_buf_id and api.nvim_buf_is_valid(m.prev_buf_id) then
			-- We have a valid saved `prev_buf_id`.
			-- Switched to `prev_buf_id`.
			api.nvim_win_set_buf(0, m.prev_buf_id)
		else
			print('scrappaper.nvim: Unable to switch to previous buffer.')
		end
		return
	end

	-- Current buffer isn't a scrap paper buffer.
	-- Save current buffer id and switch to scrap paper buffer.
	m.prev_buf_id = api.nvim_get_current_buf()
	if m.buf_id then
		vim.api.nvim_set_current_buf(m.buf_id)
		return
	end

	create_buffer()
	if m.buf_id == nil then
		-- Fail to create a buffer.
		return
	end
	api.nvim_win_set_buf(0, m.buf_id)
end

--[[
--load - loades saved scrap papers from storage and keeps it in `m.saved_scrap_papers`.
--If cannot load saved scrap papers, use empty list.
--Inform user of error.
--]]
m.load = function()
	local saved_scrap_papers_json = '[]'
	local storage_file, err = io.open(m.storage_path)
	if storage_file then
		saved_scrap_papers_json = storage_file:read('*a')
		storage_file:close()
	else
		print('scrappaper.nvim: error while loading saved scrap papers, using empty storage...', err)
	end
	m.saved_scrap_papers = vim.fn.json_decode(saved_scrap_papers_json)
end

--[[
--save - Saves content of current buffer if it hasn't been saved already.
--The scrap paper is saved at the beginning of the saved scrap paper list.
--This means that the saved scrap paper starts from most recently saved (latest) to the least recently saved (earliest) scrap paper.
--Saving the same buffer twice doesn't do anything.
--It saves the content by converting the content of the file to a json string and storing it in a file.
--The storage contains a list of all previously saved scrap papers up to `max_saved_scrap_papers`.
--]]
m.save = function()
	-- Do nothing if not in a scrap paper
	if api.nvim_get_current_buf() ~= m.buf_id then return end

		local lines = api.nvim_buf_get_lines(0, 0, -1, true)

	-- Don't save an empty buffer.
	if vim.deep_equal(lines, {''}) then
		-- Empty scrap baper, don't save.
		print('scrappaper.nvim: Emptyscrap paper, not saving.')
		return
	end

		-- Load stored scrap papers
		    m.load()
	if vim.deep_equal(m.saved_scrap_papers[1], lines) then
		-- Scrap paper already saved.
		print('scrappaper.nvim: Already saved!')
		return
	end
	table.insert(m.saved_scrap_papers, 1, lines)
	local saved_scrap_papers_count = table.maxn(m.saved_scrap_papers)
	if saved_scrap_papers_count > m.max_saved_scrap_papers then
		for _ = m.max_saved_scrap_papers + 1, saved_scrap_papers_count, 1 do
			table.remove(m.saved_scrap_papers)
		end
	end

	-- Convert all saved scrap paper to a json string and write to storage.
	local saved_scrap_papers_json = vim.fn.json_encode(m.saved_scrap_papers)
	local storage_file, err = io.open(m.storage_path, 'w')
	if not storage_file then
		print('Error: scrappaper.nvim - Unable to write to storage -', err)
		return
	end
	storage_file:write(saved_scrap_papers_json)
	storage_file:close()
	m.index = nil -- position of scrap papers has changed.
end

--[[
--prev - Replaces the content of the current scrap buffer with the previous scrap paper in the saved scrap paper list.
--starts from most recently saved scrap paper (latest) to the least recently saved scrap paper (earliest).
--]]
m.prev = function()
	-- Do nothing if current buffer isn't a scrap paper buffer.
	if api.nvim_get_current_buf() ~= m.buf_id then return end

	-- load scrap papers if it hasn't been loaded.
	if not m.saved_scrap_papers then m.load() end

	-- get index of scrap paper to read.
	-- also update `m.index` to the index of the scrap paper that will be set.
	local length = table.maxn(m.saved_scrap_papers)
	if length == 0 then
		-- Storage empty, do nothing.
		print('scrappaper.nvim:', empty_storage_msg)
		return
	elseif length == 1 then
		-- storage is empty or has only one scrap paper.
		m.index = 1
	elseif not m.index then
		-- `m.index` has not been set, set it as the most recently saved scrap paper.
		m.index = 1
	elseif m.index == length then
		-- current scrap paper is the least recently saved scrap paper,
		-- cycle to most recently saved scrap paper.
		m.index = 1
	else
		-- It is possible to move to an earlier saved scrap paper.
		m.index = m.index + 1
	end

	-- get scrap paper to set
	local scrap_paper = m.saved_scrap_papers[m.index]

	-- Set scrap paper.
	api.nvim_buf_set_lines(0, 0, -1, true, scrap_paper)
end

--[[
--next - replaces the content of the current buffer with the next saved scrap paper.
--This moves from least recently saved scrap paper (earliest)
--to most recently saved scrap paper (latest).
--]]
m.next = function()
	-- Do nothing if not in a scrap paper buffer.
	if api.nvim_get_current_buf() ~= m.buf_id then return end

	-- load saved scrap papers if it hasn't been loaded yet.
	if not m.saved_scrap_papers then m.load() end

	-- Set `m.index` to the scrap paper that will be displayed.
	local length = table.maxn(m.saved_scrap_papers)
	if length == 0 then
		-- Do nothing.
		print('scrappaper.nvim:', empty_storage_msg)
		return
	elseif length == 1 then
		-- only one item in storage.
		m.index = 1
	elseif not m.index then
		-- index hasn't been set yet,
		-- set it to the least recently saved scrap paper (earliest)
		m.index = length
	elseif m.index == 1 then
		-- Reached end of current cycle, cycle back.
		m.index = length
	else
		-- it's possible to move towards the most recently set scrap paper (latest)
		m.index = m.index - 1
	end

	-- Set scrap paper to display
	local scrap_paper = m.saved_scrap_papers[m.index]

	-- Replace content of scrap paper buffer with `scrap_paper`.
	api.nvim_buf_set_lines(0, 0, -1, true, scrap_paper)
end

return m
