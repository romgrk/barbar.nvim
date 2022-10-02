--
-- m.lua
--

local table_insert = table.insert
local table_remove = table.remove

local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local buf_get_var = vim.api.nvim_buf_get_var
local buf_set_var = vim.api.nvim_buf_set_var
local list_bufs = vim.api.nvim_list_bufs
local list_extend = vim.list_extend
local tbl_filter = vim.tbl_filter

--- @type bufferline.buffer
local Buffer = require'bufferline.buffer'

--- @type bufferline.options
local options = require'bufferline.options'

--- @type bufferline.utils
local utils = require'bufferline.utils'

local PIN = 'bufferline_pin'

--------------------------------
-- Section: Application state --
--------------------------------

--- @class bufferline.state.data
--- @field closing boolean whether the buffer is being closed
--- @field name? string the name of the buffer
--- @field position? integer the absolute position of the buffer
--- @field real_width? integer the width of the buffer + invisible characters
--- @field width? integer the width of the buffer - invisible characters

--- @class bufferline.state
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field buffers integer[] the open buffers, in visual order.
--- @field buffers_by_id {[integer]: bufferline.state.data} the buffer data
local state = {
  is_picking_buffer = false,
  buffers = {},
  buffers_by_id = {},

  --- The offset of the tabline (from the left).
  --- @class bufferline.render.offset
  --- @field hl nil|string the highlight group to use
  --- @field text nil|string the text to fill the offset with
  --- @field width integer the size of the offset
  offset = {width = 0}
}

--- Get the state of the `id`
--- @param id integer the `bufnr`
--- @return bufferline.state.data
function state.get_buffer_data(id)
  local data = state.buffers_by_id[id]

  if data ~= nil then
    return data
  end

  state.buffers_by_id[id] = {
    closing = false,
    name = nil,
    position = nil,
    real_width = nil,
    width = nil,
  }

  return state.buffers_by_id[id]
end

--- Get the list of buffers
function state.get_buffer_list()
  local buffers = list_bufs()
  local result = {}

  local exclude_ft   = options.exclude_ft()
  local exclude_name = options.exclude_name()

  for _, buffer in ipairs(buffers) do
    if not buf_get_option(buffer, 'buflisted') then
      goto continue
    end

    local ft = buf_get_option(buffer, 'filetype')
    if utils.has(exclude_ft, ft) then
      goto continue
    end

    local fullname = buf_get_name(buffer)
    local name = utils.basename(fullname)
    if utils.has(exclude_name, name) then
      goto continue
    end

    table_insert(result, buffer)

    ::continue::
  end

  return result
end

-- Pinned buffers

--- @param bufnr integer
--- @return boolean pinned `true` if `bufnr` is pinned
function state.is_pinned(bufnr)
  local ok, val = pcall(buf_get_var, bufnr, PIN)
  return ok and val
end

--- Sort the pinned tabs to the left of the bufferline.
function state.sort_pins_to_left()
  local unpinned = {}

  local i = 1
  while i <= #state.buffers do
    if state.is_pinned(state.buffers[i]) then
      i = i + 1
    else
      table_insert(unpinned, table_remove(state.buffers, i))
    end
  end

  state.buffers = list_extend(state.buffers, unpinned)
end

--- Toggle the `bufnr`'s "pin" state.
--- WARN: does not redraw the bufferline. See `Render.toggle_pin`.
--- @param bufnr integer
function state.toggle_pin(bufnr)
  buf_set_var(bufnr, PIN, not state.is_pinned(bufnr))
  state.sort_pins_to_left()
end

-- Open/close buffers

--- Stop tracking the `bufnr` with barbar.
--- WARN: does NOT close the buffer in Neovim (see `:h nvim_buf_delete`)
--- @param bufnr integer
--- @param do_name_update? boolean refreshes all buffer names iff `true`
function state.close_buffer(bufnr, do_name_update)
  state.buffers = tbl_filter(function(b) return b ~= bufnr end, state.buffers)
  state.buffers_by_id[bufnr] = nil

  if do_name_update then
    state.update_names()
  end
end

-- Read/write state

-- Return the bufnr of the buffer to the right of `buffer_number`
-- @param buffer_number int
-- @return int|nil
function state.find_next_buffer(buffer_number)
  local index = utils.index_of(state.buffers, buffer_number)
  if index == nil then return nil end
  if index + 1 > #state.buffers then
    index = index - 1
    if index <= 0 then
      return nil
    end
  else
    index = index + 1
  end
  return state.buffers[index]
end

--- Update the names of all buffers in the bufferline.
function state.update_names()
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(state.buffers) do
    local name = Buffer.get_name(buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      state.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = state.buffers[other_i]
      local new_name, new_other_name =
        Buffer.get_unique_name(
          buf_get_name(buffer_n),
          buf_get_name(state.buffers[other_i]))

      state.get_buffer_data(buffer_n).name = new_name
      state.get_buffer_data(other_n).name = new_other_name
      buffer_index_by_name[new_name] = i
      buffer_index_by_name[new_other_name] = other_i
      buffer_index_by_name[name] = nil
    end

  end
end

--- @deprecated exists for backwards compatability
--- @param width integer
--- @param text nil|string
--- @param hl nil|string
function state.set_offset(width, text, hl)
  vim.notify(
    "`require'bufferline.state'.set_offset` is deprecated, use `require'bufferline.api'.set_offset` instead",
    vim.log.levels.WARN,
    {title = 'barbar.nvim'}
  )
  require'bufferline.api'.set_offset(width, text, hl)
end

-- Exports
return state
