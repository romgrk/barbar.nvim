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

-------------------
-- Section: helpers
-------------------

--- Use `vim.notify` to print an error `msg`
--- @param msg string
local function err(msg)
  vim.notify(msg, vim.log.levels.ERROR, {title = 'bbye'})
  vim.v.errmsg = msg
end

--- Convert a buffer name into a buffer number.
--- @param buffer string
--- @return number buffer_number
local function str2bufnr(buffer)
  if not buffer or #buffer < 1 then
    return vim.fn.bufnr("%")
  elseif vim.regex([[^\d\+$]]):match_str(buffer)  then
    return vim.fn.bufnr(tostring(buffer))
  end

  return vim.fn.bufnr(buffer)
end

local empty_buffer = nil

--- Create a new buffer.
--- @param force boolean if `true`, forcefully create the new buffer
local function new(force)
  vim.api.nvim_command("enew" .. (force and '!' or ''))

  empty_buffer = vim.api.nvim_get_current_buf()
  vim.b.empty_buffer = true

  -- Regular buftype warns people if they have unsaved text there.
  -- Wouldn't want to lose someone's data:
  vim.opt_local.buftype = ''
  vim.opt_local.swapfile = false

  -- If empty and out of sight, delete it right away:
  vim.opt_local.bufhidden = 'wipe'

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = 0,
    callback = function() require'bufferline.state'.close_buffer(empty_buffer) end,
    group = vim.api.nvim_create_augroup('bbye_empty_buffer', {})
  })
end

------------------
-- Section: module
------------------

--- @class bbye
local bbye = {}

--- Delete a buffer
--- @param action nil|string the command to use to delete the buffer (default: `'bdelete'`)
--- @param force boolean if true, forcefully delete the buffer
--- @param buffer nil|number|string the name or number of the buffer (default: current buffer)
--- @param mods string the modifiers to the command (e.g. `'verbose'`)
function bbye.delete(action, force, buffer, mods)
  action = action or 'bdelete'
  mods = mods or ''

  local buffer_number = type(buffer) == 'string' and str2bufnr(buffer) or buffer
  if buffer_number < 0 then
    err("E516: No buffers were deleted. No match for " .. buffer)
    return
  end

  local is_modified = vim.bo[buffer_number].modified
  local has_confirm = vim.o.confirm or (string.match(mods, 'conf') ~= nil)

  if is_modified and not (force or has_confirm) then
    err("E89: No write since last change for buffer " .. buffer_number .. " (add ! to override)")
    return
  end

  local current_window = vim.api.nvim_get_current_win()

  -- If the buffer is set to delete and it contains changes, we can't switch
  -- away from it. Hide it before eventual deleting:
  if is_modified and force then
    vim.bo[buffer_number].bufhidden = 'hide'
  end

  -- For cases where adding buffers causes new windows to appear or hiding some
  -- causes windows to disappear and thereby decrement, loop backwards.
  local window_ids = vim.api.nvim_list_wins()
  local window_ids_reversed = {}
  while #window_ids_reversed < #window_ids do
    window_ids_reversed[#window_ids_reversed + 1] = window_ids[#window_ids - #window_ids_reversed]
  end

  for _, window_number in ipairs(window_ids_reversed) do
    -- For invalid window numbers, winbufnr returns -1.
    if vim.api.nvim_win_get_buf(window_number) == buffer_number then
      vim.api.nvim_set_current_win(window_number)

      -- Bprevious also wraps around the buffer list, if necessary:
      local no_errors = pcall(function()
        local previous_buffer = vim.fn.bufnr '#'
        if previous_buffer > 0 and vim.fn.buflisted(previous_buffer) == 1 then
          vim.api.nvim_set_current_buf(previous_buffer)
        else
          vim.api.nvim_command 'bprevious'
        end
      end)

      if not (no_errors or string.match(vim.v.errmsg, 'E85')) then
        err(vim.v.errmsg)
        return
      end

      -- If found a new buffer for this window, mission accomplished:
      if vim.api.nvim_get_current_buf() == buffer_number then
        new(force)
      end
    end
  end

  if vim.api.nvim_win_is_valid(current_window) then
    vim.api.nvim_set_current_win(current_window)
  end

  -- If it hasn't been already deleted by &bufhidden, end its pains now.
  -- Unless it previously was an unnamed buffer and :enew returned it again.
  --
  -- Using buflisted() over bufexists() because bufhidden=delete causes the
  -- buffer to still _exist_ even though it won't be :bdelete-able.
  if vim.fn.buflisted(buffer_number) == 1 and buffer_number ~= vim.api.nvim_get_current_buf() then
    local no_errors = pcall(function()
      vim.api.nvim_command(mods .. " " .. action .. (force and '!' or '') .. " " .. buffer_number)
    end)

    if not no_errors then
      if string.match(vim.v.errmsg, 'E516') then
        vim.api.nvim_set_current_buf(buffer_number)
      else
        err(vim.v.errmsg)
        return
      end
    end
  end

  vim.api.nvim_exec_autocmds('BufWinEnter', {})
end

return bbye
