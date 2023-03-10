--
-- m.lua
--

local table_remove = table.remove

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local bufadd = vim.fn.bufadd --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local list_bufs = vim.api.nvim_list_bufs --- @type function
local list_extend = vim.list_extend
local tbl_filter = vim.tbl_filter

local Buffer = require'bufferline.buffer' --- @type bufferline.buffer
local options = require'bufferline.options' --- @type bufferline.options
local utils = require'bufferline.utils' --- @type bufferline.utils

--------------------------------
-- Section: Application state --
--------------------------------

--- @class bufferline.state.data
--- @field closing boolean whether the buffer is being closed
--- @field name? string the name of the buffer
--- @field position? integer the absolute position of the buffer
--- @field real_width? integer the width of the buffer + invisible characters
--- @field pinned boolean whether the buffer is pinned
--- @field width? integer the width of the buffer - invisible characters

--- @class bufferline.state
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field loading_session boolean `true` if a `SessionLoadPost` event is being processed
--- @field buffers integer[] the open buffers, in visual order.
--- @field data_by_bufnr {[integer]: bufferline.state.data} the buffer data indexed on buffer number
--- @field pins {[integer]: boolean} whether a buffer is pinned
local state = {
  is_picking_buffer = false,
  loading_session = false,
  buffers = {},
  data_by_bufnr = {},

  --- The offset of the tabline (from the left).
  --- @class bufferline.render.offset
  --- @field hl? string the highlight group to use
  --- @field text string the text to fill the offset with
  --- @field width integer the size of the offset
  offset = {text = '', width = 0}
}

--- Get the state of the `id`
--- @param bufnr integer the `bufnr`
--- @return bufferline.state.data
function state.get_buffer_data(bufnr)
  if bufnr == 0 then
    bufnr = get_current_buf()
  end

  local data = state.data_by_bufnr[bufnr]
  if data ~= nil then
    return data
  end

  state.data_by_bufnr[bufnr] = {
    closing = false,
    name = nil,
    position = nil,
    real_width = nil,
    width = nil,
  }

  return state.data_by_bufnr[bufnr]
end

--- Get the list of buffers
--- @return integer[] bufnrs
function state.get_buffer_list()
  local result = {}

  local exclude_ft = options.exclude_ft()
  local exclude_name = options.exclude_name()
  local hide_extensions = options.hide().extensions

  for _, bufnr in ipairs(list_bufs()) do
    if buf_get_option(bufnr, 'buflisted') and
      not utils.has(exclude_ft, buf_get_option(bufnr, 'filetype'))
    then
      local name = buf_get_name(bufnr)
      if not utils.has(exclude_name, utils.basename(name, hide_extensions)) then
        table.insert(result, bufnr)
      end
    end
  end

  return result
end

-- Pinned buffers

--- @param bufnr integer
--- @return boolean pinned `true` if `bufnr` is pinned
function state.is_pinned(bufnr)
  local data = state.get_buffer_data(bufnr)
  return data and data.pinned
end

--- Sort the pinned tabs to the left of the bufferline.
--- @return nil
function state.sort_pins_to_left()
  local unpinned = {}

  local i = 1
  while i <= #state.buffers do
    if state.is_pinned(state.buffers[i]) then
      i = i + 1
    else
      unpinned[#unpinned + 1] = table_remove(state.buffers, i)
    end
  end

  state.buffers = list_extend(state.buffers, unpinned)
end

--- Toggle the `bufnr`'s "pin" state.
--- WARN: does not redraw the bufferline. See `Render.toggle_pin`.
--- @param bufnr integer
--- @return nil
function state.toggle_pin(bufnr)
  local data = state.get_buffer_data(bufnr)
  data.pinned = not data.pinned

  state.sort_pins_to_left()
end

-- Open/close buffers

--- Stop tracking the `bufnr` with barbar.
--- WARN: does NOT close the buffer in Neovim (see `:h nvim_buf_delete`)
--- @param bufnr integer
--- @param do_name_update? boolean refreshes all buffer names iff `true`
--- @return nil
function state.close_buffer(bufnr, do_name_update)
  state.buffers = tbl_filter(function(b) return b ~= bufnr end, state.buffers)
  state.data_by_bufnr[bufnr] = nil

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
  if index == nil then
    return
  end

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
--- @return nil
function state.update_names()
  local buffer_index_by_name = {}
  local hide_extensions = options.hide().extensions

  -- Compute names
  for i, buffer_n in ipairs(state.buffers) do
    local name = Buffer.get_name(buffer_n, hide_extensions)

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

--- @deprecated use `api.set_offset` instead
--- @param width integer
--- @param text? string
--- @param hl? string
--- @return nil
function state.set_offset(width, text, hl)
  if vim.deprecate then
    vim.deprecate('`bufferline.state.set_offset`', '`bufferline.api.set_offset`', '2.0.0', 'barbar.nvim')
  else
    vim.notify_once(
      "`bufferline.state.set_offset` is deprecated, use `bufferline.api.set_offset` instead",
      vim.log.levels.WARN,
      {title = 'barbar.nvim'}
    )
  end

  require'bufferline.api'.set_offset(width, text, hl)
end

--- Restore the buffers
--- @param buffer_data string[]|{name: string, pinned: boolean}[]
--- @return nil
function state.restore_buffers(buffer_data)
  --- PERF: since this function is only run once (`nvim -S`) I avoided importing the called functions at top-level
  local table_insert = table.insert
  local buf_delete = vim.api.nvim_buf_delete
  local buf_get_lines = vim.api.nvim_buf_get_lines
  local buf_line_count = vim.api.nvim_buf_line_count

  -- Close all empty buffers. Loading a session may call :tabnew several times
  -- and create useless empty buffers.
  for _, bufnr in ipairs(list_bufs()) do
    if buf_get_name(bufnr) == ''
      and buf_get_option(bufnr, 'buftype') == ''
      and buf_line_count(bufnr) == 1
      and buf_get_lines(bufnr, 0, 1, true)[1] == ''
    then
      buf_delete(bufnr, {})
    end
  end

  state.buffers = {}
  for _, data in ipairs(buffer_data) do
    local bufnr = bufadd(data.name or data)

    table_insert(state.buffers, bufnr)
    if data.pinned then
      state.toggle_pin(bufnr)
    end
  end
end

-- Exports
return state
