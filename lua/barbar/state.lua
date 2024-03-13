--
-- m.lua
--

local table_insert = table.insert
local table_remove = table.remove

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local bufname = vim.fn.bufname --- @type function
local command = vim.api.nvim_command --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local get_diagnostics = vim.diagnostic.get --- @type fun(bufnr: integer): {severity: integer}[]
local json_decode = vim.json.decode --- @type function
local json_encode = vim.json.encode --- @type function
local list_bufs = vim.api.nvim_list_bufs --- @type function
local list_slice = vim.list_slice
local severity = vim.diagnostic.severity
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local tbl_map = vim.tbl_map

local buffer = require('barbar.buffer')
local config = require('barbar.config')
local fs = require('barbar.fs')
local utils = require('barbar.utils')

local CACHE_PATH = vim.fn.stdpath('cache') .. '/barbar.json'
local ERROR = severity.ERROR
local HINT = severity.HINT
local INFO = severity.INFO
local WARN = severity.WARN

--------------------------------
-- Section: Application state --
--------------------------------

--- @class barbar.state.data
--- @field closing boolean whether the buffer is being closed
--- @field computed_position? integer the real position of the buffer
--- @field computed_width? integer the width of the buffer plus invisible characters
--- @field diagnostics? {[DiagnosticSeverity]: integer}
--- @field gitsigns? {[barbar.config.options.icons.buffer.git.statuses]: integer} the real position of the buffer
--- @field moving? boolean whether the buffer is currently being repositioned
--- @field name? string the name of the buffer
--- @field pinned boolean whether the buffer is pinned
--- @field position? integer the absolute position of the buffer
--- @field width? integer the width of the buffer minus invisible characters

--- @class barbar.state.offset.side
--- @field align align the alignment of the group
--- @field hl string the highlight group to use
--- @field text string the text to fill the offset with
--- @field width integer the size of the offset

--- @class barbar.state.offset
--- @field left barbar.state.offset.side
--- @field right barbar.state.offset.side

--- @class barbar.State
--- @field buffers integer[] the open buffers, in visual order.
--- @field data_by_bufnr {[integer]: barbar.state.data} the buffer data indexed on buffer number
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field offset barbar.state.offset
--- @field recently_closed string[] the list of recently closed paths
local state = {
  buffers = {},
  data_by_bufnr = {},
  is_picking_buffer = false,
  offset = {
    left = {align = 'right', hl = 'BufferOffset', text = '', width = 0},
    right = {align = 'left', hl = 'BufferOffset', text = '', width = 0},
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
      if not tbl_contains(exclude_name, fs.basename(name, hide_extensions)) then
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

--- For each severity in `diagnostics`: if it is enabled, and there are diagnostics associated with it in the `buffer_number` provided, call `f`.
--- @param bufnr integer the buffer number to count diagnostics in
--- @param diagnostics barbar.config.options.icons.buffer.diagnostics the user configuration for diagnostics
--- @param f fun(count: integer, severity_idx: integer, option: barbar.config.options.icons.diagnostics.severity) the function to run when diagnostics of a specific severity are enabled and present in the `buffer_number`
--- @return nil
function state.for_each_counted_enabled_diagnostic(bufnr, diagnostics, f)
  local count = state.get_buffer_data(bufnr).diagnostics
  if count == nil then
    return
  end

  for i in ipairs(severity) do
    local option = diagnostics[i]
    if option.enabled and count[i] > 0 then
      f(count[i], i, option)
    end
  end
end

--- For each status in `git`: if it is enabled, and there is a git status associated with the buffer (`buffer_number`), call `f`.
--- @param bufnr integer the buffer number to get git status
--- @param git barbar.config.options.icons.buffer.git the user configuration for git status
--- @param f fun(count: integer, git_status: string, option: barbar.config.options.icons.buffer.git.status) the function to run when a specific git status is enabled and present in the `buffer_number`
--- @return nil
function state.for_each_counted_enabled_git_status(bufnr, git, f)
  -- NOTE: can be extended to check for other git implementations by using e.g. `or buffer_data.gitgutter`
  local count = state.get_buffer_data(bufnr).gitsigns
  if count == nil then
    return
  end

  for _, git_status in ipairs(config.git_statuses) do
    local git_status_option = git[git_status]
    if git_status_option.enabled and count[git_status] > 0 then
      f(count[git_status], git_status, git_status_option)
    end
  end
end

--- Update the `vim.diagnostics` count for the `bufnr`
--- @param bufnr integer
function state.update_diagnostics(bufnr)
  local count = { [ERROR] = 0, [HINT] = 0, [INFO] = 0, [WARN] = 0 }

  for _, diagnostic in ipairs(get_diagnostics(bufnr)) do
    count[diagnostic.severity] = count[diagnostic.severity] + 1
  end

  state.get_buffer_data(bufnr).diagnostics = count
end

--- Update the `gitsigns.nvim` count for the `bufnr`
--- @param bufnr integer
function state.update_gitsigns(bufnr)
  local count = { added = 0, changed = 0, deleted = 0 }

  local ok, gitsigns_status_dict = pcall(vim.api.nvim_buf_get_var, bufnr, 'gitsigns_status_dict')
  if ok and gitsigns_status_dict ~= nil then
    if gitsigns_status_dict.added ~= nil then
      count.added = gitsigns_status_dict.added
    end

    if gitsigns_status_dict.changed ~= nil then
      count.changed = gitsigns_status_dict.changed
    end

    if gitsigns_status_dict.removed ~= nil then
      count.deleted = gitsigns_status_dict.removed
    end
  end

  state.get_buffer_data(bufnr).gitsigns = count
end

--- Update the names of all buffers in the bufferline.
--- @return nil
function state.update_names()
  local buffer_index_by_name = {}
  local hide_extensions = config.options.hide.extensions

  -- Compute names
  for i, buffer_n in ipairs(state.buffers) do
    local name = buffer.get_name(buffer_n, hide_extensions)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      state.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = state.buffers[other_i]
      local new_name, new_other_name =
        buffer.get_unique_name(
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

  require('barbar.api').set_offset(width, text, hl)
end

--- Restore the buffers
--- @param buffer_data string[]|{name: string, pinned: boolean}[]
--- @return nil
function state.restore_buffers(buffer_data)
  local buf_delete = vim.api.nvim_buf_delete --- @type function
  local buf_get_lines = vim.api.nvim_buf_get_lines --- @type function
  local buf_line_count = vim.api.nvim_buf_line_count --- @type function
  local bufnr = vim.fn.bufnr --- @type function

  -- Close all empty buffers. Loading a session may call :tabnew several times
  -- and create useless empty buffers.
  for _, buffer_number in ipairs(list_bufs()) do
    if buf_get_name(buffer_number) == ''
      and buf_get_option(buffer_number, 'buftype') == ''
      and buf_line_count(buffer_number) == 1
      and buf_get_lines(buffer_number, 0, 1, true)[1] == ''
    then
      buf_delete(buffer_number, {})
    end
  end

  local any_pins = false
  state.buffers = {}

  for _, data in ipairs(buffer_data) do
    local buffer_number = bufnr(data.name or data)

    table_insert(state.buffers, buffer_number)
    if data.pinned then
      any_pins = true
      state.get_buffer_data(buffer_number).pinned = data.pinned
    end
  end

  if any_pins then
    state.sort_pins_to_left()
  end
end

-- Save/load state

--- Save recently_closed list
--- @return nil
function state.save_recently_closed()
  local err_msg = fs.write(CACHE_PATH, json_encode({ recently_closed = state.recently_closed }))
  if err_msg then
    utils.notify(err_msg, vim.log.levels.WARN)
  end
end

--- Save recently_closed list
--- @return nil
function state.load_recently_closed()
  local err_msg, content = fs.read(CACHE_PATH)
  if err_msg then
    utils.notify(err_msg, vim.log.levels.WARN)
  end

  local ok, result = pcall(json_decode, content, {luanil = {array = true, object = true}})
  if ok and result.recently_closed ~= nil then
    state.recently_closed = result.recently_closed
  end
end

-- Exports
return state
