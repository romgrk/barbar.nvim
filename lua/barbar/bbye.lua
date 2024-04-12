-- Bbye (rewritten in Lua)
--
-- source: https://github.com/moll/vim-bbye/blob/master/plugin/bbye.vim
-- license:
--
-- Copyright (C) 2013 Andri Möll
--
-- This program is free software: you can redistribute it and/or modify it under
-- the terms of the GNU Affero General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or any later version.
--
-- Additional permission under the GNU Affero GPL version 3 section 7:
-- If you modify this Program, or any covered work, by linking or
-- combining it with other code, such other code is not for that reason
-- alone subject to any of the requirements of the GNU Affero GPL version 3.
--
-- In summary:
-- - You can use this program for no cost.
-- - You can use this program for both personal and commercial reasons.
-- - You do not have to share your own program's code which uses this program.
-- - You have to share modifications (e.g bug-fixes) you've made to this program.
--
-- For the full copy of the GNU Affero General Public License see:
-- http://www.gnu.org/licenses.

local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_set_option = vim.api.nvim_buf_set_option --- @type function
local buflisted = vim.fn.buflisted --- @type function
local bufnr = vim.fn.bufnr --- @type function
local command = vim.api.nvim_command --- @type function
local create_augroup = vim.api.nvim_create_augroup --- @type function
local create_autocmd = vim.api.nvim_create_autocmd --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local get_current_win = vim.api.nvim_get_current_win --- @type function
local get_option = vim.api.nvim_get_option --- @type function
local list_wins = vim.api.nvim_list_wins --- @type function
local notify = vim.notify
local set_current_buf = vim.api.nvim_set_current_buf --- @type function
local set_current_win = vim.api.nvim_set_current_win --- @type function
local win_get_buf = vim.api.nvim_win_get_buf --- @type function
local win_is_valid = vim.api.nvim_win_is_valid --- @type function

local state = require('barbar.state')
local markdown_inline_code = require('barbar.utils').markdown_inline_code

-------------------
-- Section: helpers
-------------------

local cmd = vim.api.nvim_cmd and
  --- @param action string
  --- @param buffer_number integer
  --- @param force? boolean
  --- @param mods? {[string]: any}
  function(action, buffer_number, force, mods)
    vim.cmd[action] {bang = force, count = buffer_number, mods = mods}
  end or
  --- @param action string
  --- @param buffer_number integer
  --- @param force? boolean
  --- @param mods? string
  function(action, buffer_number, force, mods)
    command((mods or '') .. " " .. action .. (force and '!' or '') .. " " .. buffer_number)
  end

local enew = vim.api.nvim_cmd and
  --- The `:enew` command
  --- @param force boolean
  function(force) vim.cmd.enew {bang = force} end or
  --- The `:enew` command
  --- @param force boolean
  function(force) command("enew" .. (force and '!' or '')) end

--- Use `vim.notify` to print an error `msg`
--- @param msg string
--- @return nil
local function err(msg)
  notify(msg, vim.log.levels.ERROR, {title = 'bbye'})
  vim.v.errmsg = msg
end

local empty_buffer = nil --- @type nil|integer

--- Create a new buffer.
--- @param force boolean if `true`, forcefully create the new buffer
--- @return nil
local function new(force)
  enew(force)

  empty_buffer = get_current_buf()
  vim.b.empty_buffer = true

  -- Regular buftype warns people if they have unsaved text there.
  -- Wouldn't want to lose someone's data:
  buf_set_option(0, 'buftype', '')
  buf_set_option(0, 'swapfile', false)

  -- If empty and out of sight, delete it right away:
  buf_set_option(0, 'bufhidden', 'wipe')

  create_autocmd('BufWipeout', {
    buffer = 0,
    callback = function() state.close_buffer(empty_buffer) end,
    group = create_augroup('bbye_empty_buffer', {})
  })
end

------------------
-- Section: module
------------------

--- @class barbar.Bbye
local bbye = {}

--- Delete a buffer
--- @param action string the command to use to delete the buffer (e.g. `'bdelete'`)
--- @param force boolean if true, forcefully delete the buffer
--- @param buffer? integer|string the name of the buffer.
--- @param mods? string|{[string]: any} the modifiers to the command (e.g. `'verbose'`)
--- @return nil
function bbye.delete(action, force, buffer, mods)
  local buffer_number = type(buffer) == 'string' and bufnr(buffer) or tonumber(buffer) or get_current_buf()
  if buffer_number < 0 then
    return err("E516: No buffers were deleted. No match for " .. buffer)
  end

  local has_confirm --- @type boolean

  -- try arguments first
  if type(mods) == 'table' then
    has_confirm = mods.confirm
  elseif mods then
    has_confirm = mods:match('conf') ~= nil
  end

  -- get the option if no arguments were passed in
  if has_confirm == nil then
    has_confirm = get_option('confirm')
  end

  local is_modified = buf_get_option(buffer_number, 'modified')
  if is_modified and not (force or has_confirm) then
    return err("E89: No write since last change for buffer " .. buffer_number .. " (add ! to override)")
  end

  local current_window = get_current_win()

  -- If the buffer is set to delete and it contains changes, we can't switch
  -- away from it. Hide it before eventual deleting:
  if is_modified and force then
    buf_set_option(buffer_number, 'bufhidden', 'hide')
  end

  -- For cases where adding buffers causes new windows to appear or hiding some
  -- causes windows to disappear and thereby decrement, loop backwards.
  local wins = list_wins()
  for i = #wins, 1, -1 do
    local window_number = wins[i]
    if win_get_buf(window_number) == buffer_number then
      set_current_win(window_number)

      -- Bprevious also wraps around the buffer list, if necessary:
      local ok = pcall(function()
        local focus_buffer = state.get_focus_on_close(buffer_number)
        if focus_buffer then
          set_current_buf(focus_buffer)
        else
          command 'bprevious'
        end
      end)

      if not (ok or vim.v.errmsg:match('E85')) then
        return err(vim.v.errmsg)
      end

      -- If the buffer is still the same, we couldn't find a new buffer,
      -- and we need to create a new empty buffer.
      if get_current_buf() == buffer_number then
        new(force)
      end
    end
  end

  if win_is_valid(current_window) then
    set_current_win(current_window)
  end

  -- If it hasn't been already deleted by &bufhidden, end its pains now.
  -- Unless it previously was an unnamed buffer and :enew returned it again.
  --
  -- Using buflisted() over bufexists() because bufhidden=delete causes the
  -- buffer to still _exist_ even though it won't be :bdelete-able.
  if buflisted(buffer_number) == 1 and buffer_number ~= get_current_buf() then
    local ok, msg = pcall(cmd, action, buffer_number, force, mods)
    if not ok then
      if msg then
        if msg:match('E516') then
          set_current_buf(buffer_number)
        else
          return err(msg)
        end
      else
          return err('Could not delete buffer ' .. buffer_number .. ' with ' .. markdown_inline_code(action))
      end
    end
  end

  state.will_close(buffer_number)
end

--- 'bdelete' a buffer
--- @param force boolean if true, forcefully delete the buffer
--- @param buffer? integer|string the name of the buffer.
--- @param mods? string|{[string]: any} the modifiers to the command (e.g. `'verbose'`)
--- @return nil
function bbye.bdelete(force, buffer, mods)
  bbye.delete('bdelete', force, buffer, mods)
end

--- 'bwipeout' a buffer
--- @param force boolean if true, forcefully delete the buffer
--- @param buffer? integer|string the name of the buffer.
--- @param mods? string|{[string]: any} the modifiers to the command (e.g. `'verbose'`)
--- @return nil
function bbye.bwipeout(force, buffer, mods)
  bbye.delete('bwipeout', force, buffer, mods)
end

return bbye
