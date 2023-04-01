--
-- m.lua
--

local table_insert = table.insert
local table_remove = table.remove

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
local bufadd = vim.fn.bufadd --- @type function
local bufname = vim.fn.bufname --- @type function
local command = vim.api.nvim_command --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local json_encode = vim.json.encode --- @type function
local json_decode = vim.json.decode --- @type function
local deepcopy = vim.deepcopy
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local list_bufs = vim.api.nvim_list_bufs --- @type function
local list_extend = vim.list_extend
local list_slice = vim.list_slice
local severity = vim.diagnostic.severity --- @type {[integer]: string, [string]: integer}
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local tbl_map = vim.tbl_map

local Buffer = require'barbar.buffer'
local config = require'barbar.config'
local utils = require'barbar.utils'

local CACHE_PATH = vim.fn.stdpath('cache') .. '/barbar.json'

--- Set `higher` to have higher priority than `lower` when resolving the `icons` option.
--- @param higher? barbar.config.options.icons.buffer
--- @param lower barbar.config.options.icons.buffer
--- @return table barbar.options.icons.buffer corresponding to the `tbl` parameter
local function icons_option_prioritize(higher, lower)
  if higher and lower then -- set the sub-table fallbacks
    do
      local lower_diagnostics = utils.tbl_remove_key(lower, 'diagnostics')
      if lower_diagnostics then
        if higher.diagnostics == nil then
          higher.diagnostics = {}
        end

        for i in ipairs(severity) do
          higher.diagnostics[i] = utils.setfallbacktable(higher.diagnostics[i], lower_diagnostics[i])
        end
      end
    end

    do
      local lower_filetype = utils.tbl_remove_key(lower, 'filetype')
      if lower_filetype then
        higher.filetype = utils.setfallbacktable(higher.filetype, lower_filetype)
      end
    end

    do
      local lower_separator = utils.tbl_remove_key(lower, 'separator')
      if lower_separator then
        higher.separator = utils.setfallbacktable(higher.separator, lower_separator)
      end
    end
  end

  return utils.setfallbacktable(higher, lower)
end

--------------------------------
-- Section: Application state --
--------------------------------

--- @class barbar.state.data
--- @field closing boolean whether the buffer is being closed
--- @field name? string the name of the buffer
--- @field position? integer the absolute position of the buffer
--- @field computed_position? integer the position of the buffer
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
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field loading_session boolean `true` if a `SessionLoadPost` event is being processed
--- @field buffers integer[] the open buffers, in visual order.
--- @field data_by_bufnr {[integer]: barbar.state.data} the buffer data indexed on buffer number
--- @field offset barbar.state.offset
--- @field recently_closed string[] the list of recently closed paths
local state = {
  buffers = {},
  data_by_bufnr = {},
  is_picking_buffer = false,
  loading_session = false,
  offset = {
    left = { text = '', width = 0 },
    right = { text = '', width = 0 },
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

--- @param bufnr integer
--- @return boolean pinned `true` if `bufnr` is pinned
function state.is_pinned(bufnr)
  return state.get_buffer_data(bufnr).pinned
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
      table_insert(unpinned, table_remove(state.buffers, i))
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

--- The `icons` for a particular activity.
--- @param activity barbar.buffer.activity.name
--- @see barbar.options.icons
--- @return barbar.config.options.icons.buffer
function state.icons(bufnr, activity)
  local activity_lower = activity:lower()
  local icons = deepcopy(config.options.icons)

  --- @type barbar.config.options.icons.state
  local activity_icons = utils.tbl_remove_key(icons, activity_lower) or {}

  --- @type barbar.config.options.icons.buffer
  local buffer_icons = icons_option_prioritize(activity_icons, icons)

  if not buf_is_valid(bufnr) then
    return buffer_icons
  end

  --- Prioritize the `modified` or `pinned` states
  --- @param option string
  local function icons_option_prioritize_state(option)
    buffer_icons = icons_option_prioritize(
      utils.tbl_remove_key(activity_icons, option),
      icons_option_prioritize(
        utils.tbl_remove_key(icons, option),
        buffer_icons
      )
    )
  end

  if buf_get_option(bufnr, 'modified') then
    icons_option_prioritize_state'modified'
  end

  if state.get_buffer_data(bufnr).pinned then
    icons_option_prioritize_state'pinned'
  end

  return buffer_icons
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
