--
-- m.lua
--

local table_insert = table.insert

local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local buf_get_var = vim.api.nvim_buf_get_var
local buf_is_valid = vim.api.nvim_buf_is_valid
local buf_set_var = vim.api.nvim_buf_set_var
local command = vim.api.nvim_command
local get_current_buf = vim.api.nvim_get_current_buf
local list_bufs = vim.api.nvim_list_bufs
local list_wins = vim.api.nvim_list_wins
local set_current_buf = vim.api.nvim_set_current_buf
local set_current_win = vim.api.nvim_set_current_win
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local win_get_buf = vim.api.nvim_win_get_buf

local Buffer = require'bufferline.buffer'
local utils = require'bufferline.utils'

local PIN = 'bufferline_pin'

--------------------------------
-- Section: Application state --
--------------------------------

--- @class bufferline.State.Data
--- @field closing boolean whether the buffer is being closed
--- @field name nil|string the name of the buffer
--- @field position nil|integer the absolute position of the buffer
--- @field real_width nil|integer the width of the buffer + invisible characters
--- @field width nil|integer the width of the buffer - invisible characters

--- @class bufferline.State
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field buffers table<integer> the open buffers, in visual order.
--- @field buffers_by_id table<integer, bufferline.State.Data> the buffer data
local State = {
  is_picking_buffer = false,
  buffers = {},
  buffers_by_id = {},
}

function State.get_buffer_data(id)
  local data = State.buffers_by_id[id]

  if data ~= nil then
    return data
  end

  State.buffers_by_id[id] = {
    closing = false,
    name = nil,
    position = nil,
    real_width = nil,
    width = nil,
  }

  return State.buffers_by_id[id]
end

-- Pinned buffers

--- @param bufnr integer
--- @return boolean pinned `true` if `bufnr` is pinned
function State.is_pinned(bufnr)
  local ok, val = pcall(buf_get_var, bufnr, PIN)
  return ok and val
end

--- Toggle the `bufnr`'s "pin" state.
--- @param bufnr integer
function State.toggle_pin(bufnr)
  buf_set_var(bufnr, PIN, not State.is_pinned(bufnr))
end

-- Open buffers

--- @return integer current_buffer
local function set_current_win_listed_buffer()
  local current = get_current_buf()
  local is_listed = buf_get_option(current, 'buflisted')

  -- Check previous window first
  if not is_listed then
    command('wincmd p')
    current = get_current_buf()
    is_listed = buf_get_option(current, 'buflisted')
  end
  -- Check all windows now
  if not is_listed then
    local wins = list_wins()
    for _, win in ipairs(wins) do
      current = win_get_buf(win)
      is_listed = buf_get_option(current, 'buflisted')
      if is_listed then
        set_current_win(win)
        break
      end
    end
  end

  return current
end

function State.open_buffer_in_listed_window(buffer_number)
  set_current_win_listed_buffer()
  set_current_buf(buffer_number)
end

-- Close & cleanup buffers

function State.close_buffer(buffer_number, should_update_names)
  State.buffers = tbl_filter(function(b) return b ~= buffer_number end, State.buffers)
  State.buffers_by_id[buffer_number] = nil
  if should_update_names then
    State.update_names()
  end
end


-- Update state

local function get_buffer_list()
  local opts = vim.g.bufferline
  local buffers = list_bufs()
  local result = {}

  --- @type nil|table
  local exclude_ft   = opts.exclude_ft
  local exclude_name = opts.exclude_name

  for _, buffer in ipairs(buffers) do

    if not buf_get_option(buffer, 'buflisted') then
      goto continue
    end

    if not utils.is_nil(exclude_ft) then
      local ft = buf_get_option(buffer, 'filetype')
      if utils.has(exclude_ft, ft) then
        goto continue
      end
    end

    if not utils.is_nil(exclude_name) then
      local fullname = buf_get_name(buffer)
      local name = utils.basename(fullname)
      if utils.has(exclude_name, name) then
        goto continue
      end
    end

    table_insert(result, buffer)

    ::continue::
  end

  return result
end

function State.update_names()
  local opts = vim.g.bufferline
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(State.buffers) do
    local name = Buffer.get_name(opts, buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      State.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = State.buffers[other_i]
      local new_name, new_other_name =
        Buffer.get_unique_name(
          buf_get_name(buffer_n),
          buf_get_name(State.buffers[other_i]))

      State.get_buffer_data(buffer_n).name = new_name
      State.get_buffer_data(other_n).name = new_other_name
      buffer_index_by_name[new_name] = i
      buffer_index_by_name[new_other_name] = other_i
      buffer_index_by_name[name] = nil
    end

  end
end

function State.get_updated_buffers(update_names)
  local current_buffers = get_buffer_list()
  local new_buffers =
    tbl_filter(
      function(b) return not vim.tbl_contains(State.buffers, b) end,
      current_buffers)

  -- To know if we need to update names
  local did_change = false

  -- Remove closed or update closing buffers
  local closed_buffers =
    tbl_filter(function(b) return not tbl_contains(current_buffers, b) end, State.buffers)

  for _, buffer_number in ipairs(closed_buffers) do
    local buffer_data = State.get_buffer_data(buffer_number)
    if not buffer_data.closing then
      did_change = true

      if buffer_data.real_width == nil then
        State.close_buffer(buffer_number)
      else
        State.close_buffer_animated(buffer_number)
      end
    end
  end

  -- Add new buffers
  if #new_buffers > 0 then
    did_change = true

    open_buffers(new_buffers)
  end

  State.buffers =
    tbl_filter(function(b) return buf_is_valid(b) end, State.buffers)

  if did_change or update_names then
    State.update_names()
  end

  return State.buffers
end

-- Read state

-- Return the bufnr of the buffer to the right of `buffer_number`
-- @param buffer_number int
-- @return int|nil
function State.find_next_buffer(buffer_number)
  local index = utils.index_of(State.buffers, buffer_number)
  if index == nil then return nil end
  if index + 1 > #State.buffers then
    index = index - 1
    if index <= 0 then
      return nil
    end
  else
    index = index + 1
  end
  return State.buffers[index]
end

-- Movement & tab manipulation

function State.goto_buffer (number)
  State.get_updated_buffers()

  number = tonumber(number)

  local idx
  if number == -1 then
    idx = #State.buffers
  elseif number > #State.buffers then
    return
  else
    idx = number
  end

  set_current_buf(State.buffers[idx])
end

function State.goto_buffer_relative(steps)
  State.get_updated_buffers()

  local current = set_current_win_listed_buffer()

  local idx = utils.index_of(State.buffers, current)

  if idx == nil then
    print('Couldn\'t find buffer ' .. current .. ' in the list: ' .. vim.inspect(State.buffers))
    return
  else
    idx = (idx + steps - 1) % #State.buffers + 1
  end

  set_current_buf(State.buffers[idx])
end


-- Exports
return State
