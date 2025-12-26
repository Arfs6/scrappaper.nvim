local api = vim.api
local describe = require('plenary.busted').describe
local it = require('plenary.busted').it
local before_each = require('plenary.busted').before_each
local after_each = require('plenary.busted').after_each
local assert = require('luassert')
local stub = require('luassert.stub')
local spy = require('luassert.spy')

describe('scrappaper', function()
	local scrappaper = require 'scrappaper'

	-- Reset all the attributes that might affect each description
	before_each(function()
		if scrappaper.buf_id then api.nvim_buf_delete(scrappaper.buf_id, {}) end
		scrappaper.saved_scrap_papers = nil
		scrappaper.index = nil
		assert.falsy(scrappaper.buf_id)
	end)

	-- Tests for scrapaper.* variables defined outside functions
	describe('buf_name', function()
		it('verify_value', function()
			assert.equal(scrappaper.buf_name, 'Scrap Paper')
		end)
	end)
	describe('storage_path', function()
		it('verify_value', function()
			local path_sep = require('plenary.path').path.sep
			assert.equal(scrappaper.storage_path,
				vim.fn.stdpath('data') .. path_sep .. 'scrappaper_storage.json')
		end)
	end)
	describe('max_saved_scrap_papers', function()
		it('verify_value', function()
			assert.equal(scrappaper.max_saved_scrap_papers, 16)
		end)
	end)

	-- tests for scrapaper.* functions
	describe('swap', function()
		it('works', function()
			local initial_buf_id = api.nvim_get_current_buf()
			assert.falsy(scrappaper.buf_id)
			scrappaper.swap()
			assert.equal(initial_buf_id, scrappaper.prev_buf_id)
			assert.equal(scrappaper.buf_id, api.nvim_get_current_buf())
			scrappaper.swap()
			assert.equal(initial_buf_id, api.nvim_get_current_buf())
		end)
	end)

	-- stub the io.open function so that test doesn't affect installed plugin data
	-- return an empty temporary file by default
	local open_stub
	before_each(function()
		open_stub = stub(io, 'open', function(filename, _)
			return nil, filename .. ': No such file or directory'
		end)
	end)
	-- Revert the stub after each test:
	after_each(function()
		open_stub:revert()
	end)

	describe('load', function()
		it('storage_file_does_not_exist', function()
			scrappaper.load()
			assert.same(scrappaper.saved_scrap_papers, {})
			assert.stub(io.open).was_called_with(scrappaper.storage_path)
			assert.stub(io.open).was_called(1)
		end)

		it('storage_file_has_json', function()
			-- test with non empty storage.
			local test_saved_scrap_papers = { { 'Line 1', 'Line 2' }, { 'Second scrap paper' } }
			local load_open_stub = stub(io, 'open', function()
				local temp_file = io.tmpfile()
				temp_file:write(vim.fn.json_encode(test_saved_scrap_papers))
				temp_file:seek('set')
				return temp_file
			end)
			scrappaper.load()
			assert.same(scrappaper.saved_scrap_papers, test_saved_scrap_papers)
			assert.stub(io.open).was_called_with(scrappaper.storage_path)
			assert.stub(io.open).was_called(1)
			load_open_stub:revert()
		end)
	end)

	describe('save', function()
		it('not_in_scrappaper', function()
			scrappaper.save()
			assert.falsy(scrappaper.saved_scrap_papers)
			assert.stub(io.open).was_called(0)
		end)

		before_each(function()
			-- Subsequent tests should expect current buffer as a scrap paper.
			scrappaper.swap()
		end)

		it('empty', function()
			-- Do nothing if the scrap paper is empty.
			scrappaper.save()
			assert.stub(io.open).was_called(0)
		end)

		it('works_with_text', function()
			-- Create a new io.open stub that returns an empty file.
			local temp_file = io.tmpfile()
			temp_file:write('[]')
			local empty_open_stub = stub(io, 'open', function(filename, mode)
				if mode ~= 'w' then
					return nil, filename .. ': No such file or directory'
				end
				temp_file:seek('set')
				return temp_file
			end)
			local lines = { 'Line 1', 'Line2' }
			api.nvim_buf_set_lines(0, 0, -1, true, lines)
			scrappaper.save()
			temp_file:seek('set')
			local saved_scrap_papers = vim.fn.json_decode(temp_file:read('*a'))
			assert.same(lines, saved_scrap_papers[1])
			assert.equal(table.maxn(saved_scrap_papers), 1)
			assert.stub(io.open).was_called(2)
			assert.stub(io.open).was_called_with(scrappaper.storage_path, 'w')
			empty_open_stub:revert()
		end)

		it('already_saved', function()
			-- stub io.open to return content of the current buffer.
			local lines = { 'Line 1', 'Line 2' }
			api.nvim_buf_set_lines(0, 0, -1, true, lines)
			local temp_file = io.tmpfile()
			temp_file:write(vim.fn.json_encode({ lines }))
			local save_open_stub = stub(io, 'open', function()
				temp_file:seek('set')
				return temp_file
			end)
			api.nvim_buf_set_lines(0, 0, -1, true, lines)
			scrappaper.save()
			assert.stub(io.open).was_called(1)
			save_open_stub:revert()
		end)

		it('more_than_max_saved_scrapapers', function()
			-- Make sure the saved item is truncated to scrappaper.max_saved_scrapapers.
			local saved_scrap_papers = {}
			for idx = 16, 1, -1 do
				table.insert(saved_scrap_papers, { 'Scrap paper no: ' .. idx })
			end
			local temp_file = io.tmpfile()
			temp_file:write(vim.fn.json_encode(saved_scrap_papers))
			local save_open_stub = stub(io, 'open', function()
				temp_file:seek('set')
				return temp_file
			end)
			local new_scrap_paper = { 'Scrap paper no: 17' }
			api.nvim_buf_set_lines(0, 0, -1, true, new_scrap_paper)
			scrappaper.save()
			table.insert(saved_scrap_papers, 1, new_scrap_paper)
			table.remove(saved_scrap_papers)
			assert.same(saved_scrap_papers, scrappaper.saved_scrap_papers)
			save_open_stub:revert()
		end)
	end)

	describe('prev', function()
		it('not_in_scrapaper', function()
			-- Do nothing if not in scrap paper
			scrappaper.prev()
			assert.falsy(scrappaper.index)
			assert.stub(io.open).was_called(0)
		end)

		-- all tests after here should expect to be in a scrap paper.
		before_each(function()
			scrappaper.swap()
		end)

		it('storage_empty', function()
			local initial = { 'initial' }
			api.nvim_buf_set_lines(0, 0, -1, true, initial)
			scrappaper.prev()
			assert.falsy(scrappaper.index)
			assert.same(initial, api.nvim_buf_get_lines(0, 0, -1, true))
		end)

		it('load_only_once', function()
			-- m.load shouldn't be called if saved scrap papers have been loaded already
			local load_spy = spy.on(scrappaper, 'load')
			scrappaper.saved_scrap_papers = {}
			scrappaper.prev()
			assert.spy(scrappaper.load).was_called(0)
			load_spy:revert()
		end)

		it('storage_has_one_scrap_paper', function()
			local initial = { 'initial' }
			api.nvim_buf_set_lines(0, 0, -1, true, initial)
			local saved_scrap_paper = { 'Only one scrap paper', 'Can have more than one lines' }
			local prev_open_stub = stub(io, 'open', function()
				local temp_file = io.tmpfile()
				temp_file:write(vim.fn.json_encode({ saved_scrap_paper }))
				temp_file:seek('set')
				return temp_file
			end)
			scrappaper.prev()
			local lines = api.nvim_buf_get_lines(0, 0, -1, true)
			assert.are_not.same(initial, lines)
			assert.same({ saved_scrap_paper }, scrappaper.saved_scrap_papers)
			assert.equal(scrappaper.index, 1)

			-- Make sure index still stays at one even after calling prev multiple times
			scrappaper.prev()
			assert.equal(scrappaper.index, 1)
			assert.same(saved_scrap_paper, api.nvim_buf_get_lines(0, 0, -1, true))
			prev_open_stub:revert()
		end)

		it('many_scrap_papers_stored', function()
			local load_stub = stub(scrappaper, 'load', function()
				scrappaper.saved_scrap_papers = {}
				for idx = 1, scrappaper.max_saved_scrap_papers, 1 do
					scrappaper.saved_scrap_papers[idx] = { 'Scrap Paper No: ' .. idx }
				end
			end)
			-- Check that prev starts from till the highest possible number
			for idx = 1, scrappaper.max_saved_scrap_papers, 1 do
				scrappaper.prev()
				assert.equal(scrappaper.index, idx)
				assert.same(scrappaper.saved_scrap_papers[idx], api.nvim_buf_get_lines(0, 0, -1, true))
			end
			-- test that prev cycles back when it reaches the end
			assert.equal(scrappaper.index, scrappaper.max_saved_scrap_papers)
			scrappaper.prev()
			assert.equal(scrappaper.index, 1)
			-- What if the saved scrap papers list isn't full?
			scrappaper.saved_scrap_papers[scrappaper.max_saved_scrap_papers] = nil
			scrappaper.index = 15
			scrappaper.prev()
			assert.equal(scrappaper.index, 1)
			load_stub:revert()
		end)
	end)

	describe('next', function()
		it('not_in_scrapaper', function()
			-- Do nothing if not in scrap paper
			scrappaper.next()
			assert.falsy(scrappaper.index)
			assert.stub(io.open).was_called(0)
		end)

		-- all tests after here should expect to be in a scrap paper.
		before_each(function()
			scrappaper.swap()
		end)

		it('storage_empty', function()
			local initial = { 'initial' }
			api.nvim_buf_set_lines(0, 0, -1, true, initial)
			scrappaper.next()
			assert.falsy(scrappaper.index)
			assert.same(initial, api.nvim_buf_get_lines(0, 0, -1, true))
		end)

		it('load_only_once', function()
			-- m.load shouldn't be called if saved scrap papers have been loaded already
			local load_spy = spy.on(scrappaper, 'load')
			scrappaper.saved_scrap_papers = {}
			scrappaper.next()
			assert.spy(scrappaper.load).was_called(0)
			load_spy:revert()
		end)

		it('storage_has_one_scrap_paper', function()
			local initial = { 'initial' }
			api.nvim_buf_set_lines(0, 0, -1, true, initial)
			local saved_scrap_paper = { 'Only one scrap paper', 'Can have more than one lines' }
			local next_open_stub = stub(io, 'open', function()
				local temp_file = io.tmpfile()
				temp_file:write(vim.fn.json_encode({ saved_scrap_paper }))
				temp_file:seek('set')
				return temp_file
			end)
			scrappaper.next()
			local lines = api.nvim_buf_get_lines(0, 0, -1, true)
			assert.are_not.same(initial, lines)
			assert.same({ saved_scrap_paper }, scrappaper.saved_scrap_papers)
			assert.equal(scrappaper.index, 1)

			-- Make sure index still stays at one even after calling next multiple times
			scrappaper.next()
			assert.equal(scrappaper.index, 1)
			assert.same(saved_scrap_paper, api.nvim_buf_get_lines(0, 0, -1, true))
			next_open_stub:revert()
		end)

		it('many_scrap_papers_stored', function()
			local load_stub = stub(scrappaper, 'load', function()
				scrappaper.saved_scrap_papers = {}
				for idx = 1, scrappaper.max_saved_scrap_papers, 1 do
					scrappaper.saved_scrap_papers[idx] = { 'Scrap Paper No: ' .. idx }
				end
			end)
			-- Check that next starts from the highest possible number down to 1
			for idx = scrappaper.max_saved_scrap_papers, 1, -1 do
				scrappaper.next()
				assert.equal(scrappaper.index, idx)
				assert.same(scrappaper.saved_scrap_papers[idx], api.nvim_buf_get_lines(0, 0, -1, true))
			end
			-- test that next cycles back when it reaches the end
			assert.equal(scrappaper.index, 1)
			scrappaper.next()
			assert.equal(scrappaper.index, scrappaper.max_saved_scrap_papers)
			-- What if the saved scrap papers list isn't full?
			scrappaper.saved_scrap_papers[scrappaper.max_saved_scrap_papers] = nil
			scrappaper.index = 1
			scrappaper.next()
			assert.equal(scrappaper.index, scrappaper.max_saved_scrap_papers - 1)
			load_stub:revert()
		end)
	end)
end)
