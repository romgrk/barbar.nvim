--
-- m.lua
--

local table_insert = table.insert
local table_remove = table.remove

local defer_fn = vim.defer_fn
local vim_bufnr = vim.fn.bufnr --- @type function
local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_loaded = vim.api.nvim_buf_is_loaded --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
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

local fs = require('barbar.fs')
local buffer = require('barbar.buffer')
local config = require('barbar.config')
local animate = require('barbar.animate')
local utils = require('barbar.utils')
local list = require('barbar.utils.list')
local layout = require('barbar.ui.layout')
local ANIMATION = require('barbar.constants').ANIMATION

local CACHE_PATH = vim.fn.stdpath('cache') .. '/barbar.json'
local ERROR = severity.ERROR
local HINT = severity.HINT
local INFO = severity.INFO
local WARN = severity.WARN

--------------------------------
-- Section: Application state --
--------------------------------

--- @class barbar.state.buffer.data
--- @field closing boolean whether the buffer is being closed
--- @field will_close boolean whether the buffer will be closed
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
--- @field buffers_visible integer[] same as above, but with the `config.hide` options applied
--- @field data_by_bufnr {[integer]: barbar.state.buffer.data} the buffer data indexed on buffer number
--- @field is_picking_buffer boolean whether the user is currently in jump-mode
--- @field last_current_buffer? integer the previously-open buffer before rendering starts
--- @field offset barbar.state.offset
--- @field recently_closed string[] the list of recently closed paths
--- @field update_callback function the render.update callback
local state = {
  buffers = {},
  buffers_visible = {},
  data_by_bufnr = {},
  is_picking_buffer = false,
  offset = {
    left = { align = 'right', hl = 'BufferOffset', text = '', width = 0 },
    right = { align = 'left', hl = 'BufferOffset', text = '', width = 0 },
  },
  recently_closed = {},
  update_callback = function() end,
}

--- Get the state of the `id`
--- @param bufnr integer the `bufnr`
--- @return barbar.state.buffer.data
function state.get_buffer_data(bufnr)
  if bufnr == 0 then
    bufnr = get_current_buf()
  end

  local data = state.data_by_bufnr[bufnr]
  if data == nil then
    data = { closing = false, will_close = false, pinned = false }
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

--- Mark buffer as soon-to-be closed
--- @param bufnr integer
function state.will_close(bufnr)
  local buffer_data = state.data_by_bufnr[bufnr]
  if buffer_data then
    buffer_data.will_close = true
  end
end

--- Stop tracking the `bufnr` with barbar.
--- WARN: does NOT close the buffer in Neovim (see `:h nvim_buf_delete`)
--- @param bufnr integer
--- @param do_name_update? boolean refreshes all buffer names iff `true`
function state.close_buffer(bufnr, do_name_update)
  state.buffers = tbl_filter(function(b) return b ~= bufnr end, state.buffers)
  state.data_by_bufnr[bufnr] = nil

  if do_name_update then
    state.update_names()
  end

  state.update_callback()
end

--- Same as `close_buffer`, but animated.
--- @param bufnr integer
function state.close_buffer_animated(bufnr)
  if config.options.animation == false then
    return state.close_buffer(bufnr)
  end

  local buffer_data = state.get_buffer_data(bufnr)
  local current_width = buffer_data.computed_width or 0

  buffer_data.closing = true
  buffer_data.width = current_width

  animate.start(
    ANIMATION.CLOSE_DURATION, current_width, 0, vim.v.t_number,
    function(new_width, animation)
      if new_width > 0 and state.data_by_bufnr[bufnr] ~= nil then
        buffer_data.width = new_width
        return state.update_callback()
      end
      animate.stop(animation)
      state.close_buffer(bufnr, true)
    end)
end

--- Opens a buffer with animation.
--- @param bufnr integer
--- @param data barbar.ui.layout.data
--- @return nil
local function open_buffer_start_animation(data, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = list.index_of(state.buffers_visible, bufnr)

  buffer_data.computed_width = layout.calculate_width(
    data.buffers.base_widths[index] or
      layout.calculate_buffer_width(state, bufnr, #state.buffers_visible + 1),
    data.buffers.padding
  )

  local target_width = buffer_data.computed_width or 0

  buffer_data.width = 1

  defer_fn(function()
    animate.start(
      ANIMATION.OPEN_DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        buffer_data.width = animation.running and new_width or nil
        state.update_callback()
      end)
  end, ANIMATION.OPEN_DELAY)
end

--- Open the `new_buffers` in the bufferline.
--- @return nil
local function open_buffers(new_buffers)
  local initial_buffers = #state.buffers

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = list.index_of(state.buffers, state.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = #state.buffers + 1
  end

  local should_insert_at_start = config.options.insert_at_start

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if list.index_of(state.buffers, new_buffer) == nil then
      local actual_index = new_index

      local should_insert_at_end = config.options.insert_at_end or
        -- We add special buffers at the end
        buf_get_option(new_buffer, 'buftype') ~= ''

      if should_insert_at_start then
        actual_index = 1
        new_index = new_index + 1
      elseif should_insert_at_end then
        actual_index = #state.buffers + 1
      else
        new_index = new_index + 1
      end

      table_insert(state.buffers, actual_index, new_buffer)
    end
  end

  state.sort_pins_to_left()

  -- We're done if there is no animations
  if config.options.animation == false then
    return
  end

  -- Case: opening a lot of buffers from a session
  -- We avoid animating here as well as it's a bit
  -- too much work otherwise.
  if initial_buffers <= 1 and #new_buffers > 1 or
     initial_buffers == 0 and #new_buffers == 1
  then
    return
  end

  -- Update names because they affect the layout
  state.update_names()

  local data = layout.calculate(state)

  for _, buffer_number in ipairs(new_buffers) do
    open_buffer_start_animation(data, buffer_number)
  end
end

--- Refresh the buffer list.
--- @return integer[] state.buffers
function state.get_updated_buffers(update_names)
  local current_buffers = state.get_buffer_list()
  local new_buffers =
    tbl_filter(function(b) return not tbl_contains(state.buffers, b) end, current_buffers)

  -- To know if we need to update names
  local did_change = false

  -- Remove closed or update closing buffers
  local closed_buffers =
    tbl_filter(function(b) return not tbl_contains(current_buffers, b) end, state.buffers)

  for _, buffer_number in ipairs(closed_buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    if not buffer_data.closing then
      did_change = true

      if buffer_data.computed_width == nil then
        state.close_buffer(buffer_number)
      else
        state.close_buffer_animated(buffer_number)
      end
    end
  end

  -- Add new buffers
  if #new_buffers > 0 then
    did_change = true

    open_buffers(new_buffers)
  end

  state.buffers =
    tbl_filter(function(b) return buf_is_valid(b) end, state.buffers)

  if did_change or update_names then
    state.update_names()
  end

  return state.buffers
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

  -- Find all names
  for i, buffer_n in ipairs(state.buffers) do
    local name = buffer.get_name(buffer_n, 1)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = {}
    end

    table.insert(buffer_index_by_name[name], i)
  end

  for name, indexes in pairs(buffer_index_by_name) do
    if #indexes == 1 then
      state.get_buffer_data(state.buffers[indexes[1]]).name = name
    else
      local buffer_numbers = tbl_map(function(i) return state.buffers[i] end, indexes)
      local unique_names = buffer.get_unique_names(buffer_numbers)
      for i, buffer_number in ipairs(buffer_numbers) do
        state.get_buffer_data(buffer_number).name = unique_names[i]
      end
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

--- @class barbar.state.buffer.exported
--- @field name string the name of the buffer
--- @field pinned boolean whether the buffer is pinned

--- Exports buffers to a format which is acceptable by `restore_buffers`
--- @return barbar.state.buffer.exported[]
--- @see barbar.State.restore_buffers
function state.export_buffers()
    local buffers = {} --- @type barbar.state.buffer.exported[]

    for _, bufnr in ipairs(state.buffers) do
      table_insert(buffers, {
        name = fs.relative(buf_get_name(bufnr)),
        pinned = state.is_pinned(bufnr) or nil,
      })
    end

    return buffers
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

--- Get the bufnr that will be focused when the buffer with `closing_number` closes.
--- @param closing_number integer
--- @return nil|integer bufnr of the buffer to focus
function state.get_focus_on_close(closing_number)
  local focus_on_close = config.options.focus_on_close

  if focus_on_close == 'previous' then
    local previous = vim_bufnr('#')
    if buf_is_loaded(previous) then
      return previous
    end
  end

  -- Edge case: no buflisted buffers in state
  if #state.buffers == 0 then
    local open_bufnrs = list_bufs()

    local start, end_, step
    if focus_on_close == 'left' then
      start, end_, step = 1, #open_bufnrs, 1
    else
      start, end_, step = #open_bufnrs, 1, -1
    end

    for i = start, end_, step do
      local nr = open_bufnrs[i]
      if buf_get_option(nr, 'buflisted') then
        return nr -- there was a listed buffer open, focus it.
      end
    end

    return nil -- there are no listed, focusable buffers open
  end

  local closing_index = list.index_of(state.buffers, closing_number)
  if closing_index == nil then
    return nil
  end

  if focus_on_close == 'previous' then
    focus_on_close = 'right'
  end

  -- Next, try to get the buffer to focus by "looking" left or right of the current buffer
  do
    local step = focus_on_close == 'right' and 1 or -1
    local end_ = focus_on_close == 'right' and #state.buffers or 0


    for i = closing_index + step, end_, step do
      local buffer_number = state.buffers[i]
      local buffer_data = state.data_by_bufnr[buffer_number]
      if buffer_data and not buffer_data.closing and not buffer_data.will_close then
        return buffer_number
      end
    end
  end

  -- If it failed, try looking the other direction
  do
    local step = focus_on_close == 'left' and 1 or -1
    local end_ = focus_on_close == 'left' and #state.buffers or 0

    for i = closing_index + step, end_, step do
      local buffer_number = state.buffers[i]
      local buffer_data = state.data_by_bufnr[buffer_number]
      if buffer_data and not buffer_data.closing and not buffer_data.will_close then
        return buffer_number
      end
    end
  end

  return nil
end


-- Exports
return state
