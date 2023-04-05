--
-- m.lua
--

local table_insert = table.insert
local table_remove = table.remove

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local bufadd = vim.fn.bufadd --- @type function
local bufname = vim.fn.bufname --- @type function
local command = vim.api.nvim_command --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local json_encode = vim.json.encode --- @type function
local json_decode = vim.json.decode --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local list_bufs = vim.api.nvim_list_bufs --- @type function
local list_slice = vim.list_slice
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local tbl_map = vim.tbl_map

local Buffer = require'barbar.buffer'
local config = require'barbar.config'
local utils = require'barbar.utils'

local CACHE_PATH = vim.fn.stdpath('cache') .. '/barbar.json'

--------------------------------
-- Section: Application state --
--------------------------------

--- @class barbar.state.data
--- @field closing boolean whether the buffer is being closed
--- @field name? string the name of the buffer
--- @field position? integer the absolute position of the buffer
--- @field computed_position? integer the real position of the buffer
--- @field computed_width? integer the width of the buffer plus invisible characters
--- @field pinned boolean whether the buffer is pinned
--- @field width? integer the width of the buffer minus invisible characters

--- @class barbar.state.offset.side
--- @field hl? string the highlight group to use
--- @field text string the text to fill the offset with
--- @field width integer the size of the offset

--- @class barbar.state.offset
--- @field left barbar.state.offset.side
--- @field right barbar.state.offset.side

--- @class barbar.state
--- @field buffers integer[] the open buffers, in visual order.
--- @field data_by_bufnr {[integer]: barbar.state.data} the buffer data indexed on buffer number
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field loading_session boolean `true` if a `SessionLoadPost` event is being processed
--- @field offset barbar.state.offset
--- @field recently_closed string[] the list of recently closed paths
local state = {
  buffers = {},
  data_by_bufnr = {},
  is_picking_buffer = false,
  loading_session = false,
  offset = {
    left = {text = '', width = 0},
    right = {text = '', width = 0},
  },
  recently_closed = {},
}

--- Get the state of the `id`
--- @param bufnr integer the `bufnr`
--- @return barbar.state.data
function state.get_buffer_data(bufnr)
  if bufnr == 0 then
    bufnr = get_current_buf()
  end

  local data = state.data_by_bufnr[bufnr]
  if data == nil then
    data = {closing = false, pinned = false}
    state.data_by_bufnr[bufnr] = data
  end

  return data
end

--- Get the list of buffers
--- @return integer[] bufnrs
function state.get_buffer_list()
  local result = {}

  local exclude_ft = config.options.exclude_ft
  local exclude_name = config.options.exclude_name
  local hide_extensions = config.options.hide.extensions

  for _, bufnr in ipairs(list_bufs()) do
    if buf_get_option(bufnr, 'buflisted') and
      not tbl_contains(exclude_ft, buf_get_option(bufnr, 'filetype'))
    then
      local name = buf_get_name(bufnr)
      if not tbl_contains(exclude_name, utils.basename(name, hide_extensions)) then
        table_insert(result, bufnr)
      end
    end
  end

  return result
end

-- Pinned buffers

--- PERF: only call this method if you don't already `state.get_buffer_data`
--- @param bufnr integer
--- @return boolean pinned `true` if `bufnr` is pinned
function state.is_pinned(bufnr)
  return state.get_buffer_data(bufnr).pinned
end

--- Sort the pinned tabs to the left of the bufferline.
--- @return nil
function state.sort_pins_to_left()
  local pinned = 0

  local i = #state.buffers
  while i >= 1 + pinned do
    if state.is_pinned(state.buffers[i]) then
      table_insert(state.buffers, 1, table_remove(state.buffers, i))
      pinned = pinned + 1
    else
      i = i - 1
    end
  end
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

--- Store a recently closed buffer
--- @param filepath string | nil
--- @return nil
function state.push_recently_closed(filepath)
  if filepath ~= nil and filepath ~= '' then
    table_insert(state.recently_closed, 1, fnamemodify(filepath, ':p'))
    state.recently_closed = list_slice(state.recently_closed, 1, 20)
  end
end

--- Restore a recently closed buffer
--- @return nil
function state.pop_recently_closed()
  local open_filepaths =
    tbl_map(function(bufnr) return fnamemodify(bufname(bufnr), ':p') end, state.buffers)

  while #state.recently_closed > 0 do
    local filepath = state.recently_closed[1]
    state.recently_closed = list_slice(state.recently_closed, 2, 20)

    if not tbl_contains(open_filepaths, filepath) then
      command(string.format('edit %s', filepath))
      break
    end
  end
end

-- Read/write state

--- Update the names of all buffers in the bufferline.
--- @return nil
function state.update_names()
  local buffer_index_by_name = {}
  local hide_extensions = config.options.hide.extensions

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
  utils.deprecate(
    utils.markdown_inline_code'bufferline.state.set_offset',
    utils.markdown_inline_code'barbar.api.set_offset'
  )

  require'barbar.api'.set_offset(width, text, hl)
end

--- Restore the buffers
--- @param buffer_data string[]|{name: string, pinned: boolean}[]
--- @return nil
function state.restore_buffers(buffer_data)
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

-- Save/load state

--- Save recently_closed list
--- @return nil
function state.save_recently_closed()
  local file, open_err = io.open(CACHE_PATH, 'w')
  if open_err ~= nil then
    return utils.notify(open_err, vim.log.levels.ERROR)
  elseif file == nil then
    return utils.notify('Could not open ' .. CACHE_PATH, vim.log.levels.ERROR)
  end
  do
    local _, write_err = file:write(json_encode({
      recently_closed = state.recently_closed,
    }))
    if write_err ~= nil then
      return utils.notify(write_err, vim.log.levels.ERROR)
    end
  end
  local success, close_err = file:close()
  if close_err ~= nil then
    return utils.notify(close_err, vim.log.levels.ERROR)
  elseif success == false then
    return utils.notify('Could not close ' .. CACHE_PATH, vim.log.levels.ERROR)
  end
end

--- Save recently_closed list
--- @return nil
function state.load_recently_closed()
  local file, open_err = io.open(CACHE_PATH, 'r')

  -- Ignore if the file doesn't exist or isn't readable
  if open_err ~= nil then
    return
  elseif file == nil then
    return
  end

  local content, read_err = file:read('*a')
  if read_err ~= nil then
    return utils.notify(read_err, vim.log.levels.ERROR)
  end

  local success, close_err = file:close()
  if close_err ~= nil then
    return
  elseif success == false then
    return
  end

  local ok, result = pcall(json_decode, content, {luanil = {array = true, object = true}})
  if ok and result.recently_closed ~= nil then
    state.recently_closed = result.recently_closed
  end
end

-- Exports
return state
