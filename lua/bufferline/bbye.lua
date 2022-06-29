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

local string_match = string.match

local buflisted = vim.fn.buflisted
local bufnr = vim.fn.bufnr
local command = vim.api.nvim_command
local create_augroup = vim.api.nvim_create_augroup
local create_autocmd = vim.api.nvim_create_autocmd
local exec_autocmds = vim.api.nvim_exec_autocmds
local get_current_buf = vim.api.nvim_get_current_buf
local get_current_win = vim.api.nvim_get_current_win
local list_wins = vim.api.nvim_list_wins
local notify = vim.notify
local set_current_buf = vim.api.nvim_set_current_buf
local set_current_win = vim.api.nvim_set_current_win
local win_get_buf = vim.api.nvim_win_get_buf
local win_is_valid = vim.api.nvim_win_is_valid
local buf_get_option = vim.api.nvim_buf_get_option
local buf_set_option = vim.api.nvim_buf_set_option

local reverse = require'bufferline.utils'.reverse

-------------------
-- Section: helpers
-------------------

--- Use `vim.notify` to print an error `msg`
--- @param msg string
local function err(msg)
  notify(msg, vim.log.levels.ERROR, {title = 'bbye'})
  vim.v.errmsg = msg
end

local empty_buffer = nil

--- Create a new buffer.
--- @param force boolean if `true`, forcefully create the new buffer
local function new(force)
  command("enew" .. (force and '!' or ''))

  empty_buffer = get_current_buf()
  vim.b.empty_buffer = true

  -- Regular buftype warns people if they have unsaved text there.
  -- Wouldn't want to lose someone's data:
  vim.opt_local.buftype = ''
  vim.opt_local.swapfile = false

  -- If empty and out of sight, delete it right away:
  vim.opt_local.bufhidden = 'wipe'

  create_autocmd('BufWipeout', {
    buffer = 0,
    callback = function() require'bufferline.state'.close_buffer(empty_buffer) end,
    group = create_augroup('bbye_empty_buffer', {})
  })
end

------------------
-- Section: module
------------------

--- @class bbye
local bbye = {}

--- Delete a buffer
--- @param action string the command to use to delete the buffer (e.g. `'bdelete'`)
--- @param force boolean if true, forcefully delete the buffer
--- @param buffer nil|number|string the name of the buffer.
--- @param mods string the modifiers to the command (e.g. `'verbose'`)
function bbye.delete(action, force, buffer, mods)
  local buffer_number = type(buffer) == 'string' and bufnr(buffer) or buffer or get_current_buf()
  mods = mods or ''

  if buffer_number < 0 then
    err("E516: No buffers were deleted. No match for " .. buffer)
    return
  end

  local is_modified = buf_get_option(buffer_number, 'modified')
  local has_confirm = vim.o.confirm or (string_match(mods, 'conf') ~= nil)

  if is_modified and not (force or has_confirm) then
    err("E89: No write since last change for buffer " .. buffer_number .. " (add ! to override)")
    return
  end

  local current_window = get_current_win()

  -- If the buffer is set to delete and it contains changes, we can't switch
  -- away from it. Hide it before eventual deleting:
  if is_modified and force then
    buf_set_option(buffer_number, 'bufhidden', 'hide')
  end

  -- For cases where adding buffers causes new windows to appear or hiding some
  -- causes windows to disappear and thereby decrement, loop backwards.
  local window_ids = list_wins()
  local window_ids_reversed = reverse(window_ids)

  for _, window_number in ipairs(window_ids_reversed) do
    if win_get_buf(window_number) == buffer_number then
      set_current_win(window_number)

      -- Bprevious also wraps around the buffer list, if necessary:
      local no_errors = pcall(function()
        local previous_buffer = bufnr('#')
        if previous_buffer > 0 and buflisted(previous_buffer) == 1 then
          set_current_buf(previous_buffer)
        else
          command 'bprevious'
        end
      end)

      if not (no_errors or string_match(vim.v.errmsg, 'E85')) then
        err(vim.v.errmsg)
        return
      end

      -- If found a new buffer for this window, mission accomplished:
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
    local no_errors = pcall(function()
      command(mods .. " " .. action .. (force and '!' or '') .. " " .. buffer_number)
    end)

    if not no_errors then
      if string_match(vim.v.errmsg, 'E516') then
        set_current_buf(buffer_number)
      else
        err(vim.v.errmsg)
        return
      end
    end
  end

  exec_autocmds('BufWinEnter', {})
end

return bbye
