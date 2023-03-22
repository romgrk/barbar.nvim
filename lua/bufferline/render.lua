-- !::exe [luafile %]
--
-- render.lua
--

local max = math.max
local min = math.min
local table_insert = table.insert

local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
local command = vim.api.nvim_command --- @type function
local defer_fn = vim.defer_fn
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local get_option = vim.api.nvim_get_option --- @type function
local has = vim.fn.has --- @type function
local list_tabpages = vim.api.nvim_list_tabpages --- @type function
local list_wins = vim.api.nvim_list_wins --- @type function
local set_current_win = vim.api.nvim_set_current_win --- @type function
local set_option = vim.api.nvim_set_option --- @type function
local severity = vim.diagnostic.severity
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function
local tabpagenr = vim.fn.tabpagenr --- @type function
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local win_get_buf = vim.api.nvim_win_get_buf --- @type function

local animate = require'bufferline.animate'
local Buffer = require'bufferline.buffer'
local icons = require'bufferline.icons'
local JumpMode = require'bufferline.jump_mode'
local Layout = require'bufferline.layout'
local options = require'bufferline.options'
local state = require'bufferline.state'
local utils = require'bufferline.utils'

--- Last value for tabline
--- @type string
local last_tabline = ''

--- Concatenates some `groups` into a valid string.
--- @param groups bufferline.render.group[]
--- @return string
local function groups_to_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    -- NOTE: We have to escape the text in case it contains '%', which is a special character to the
    --       tabline.
    --       To escape '%', we make it '%%'. It just so happens that '%' is also a special character
    --       in Lua, so we have write '%%' to mean '%'.
    result = result .. group.hl .. group.text:gsub('%%', '%%%%')
  end

  return result
end

--- Insert `others` into `groups` at the `position`.
--- @param groups bufferline.render.group[]
--- @param position integer
--- @param others bufferline.render.group[]
--- @return bufferline.render.group[] with_insertions
local function groups_insert(groups, position, others)
  local current_position = 0

  local new_groups = {}

  local i = 1
  while i <= #groups do
    local group = groups[i]
    local group_width = strwidth(group.text)

    -- While we haven't found the position...
    if current_position + group_width <= position then
      table_insert(new_groups, group)
      i = i + 1
      current_position = current_position + group_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current group if it `position` is inside it
      if available_width > 0 then
        table_insert(new_groups, {
          text = strcharpart(group.text, 0, available_width),
          hl = group.hl,
        })
      end

      -- Add new other groups
      local others_width = 0
      for _, other in ipairs(others) do
        local other_width = strwidth(other.text)
        others_width = others_width + other_width
        table_insert(new_groups, other)
      end

      local end_position = position + others_width

      -- Then, resume adding previous groups
      -- table.insert(new_groups, 'then')
      while i <= #groups do
        local previous_group = groups[i]
        local previous_group_width = strwidth(previous_group.text)
        local previous_group_start_position = current_position
        local previous_group_end_position   = current_position + previous_group_width

        if previous_group_end_position <= end_position and previous_group_width ~= 0 then
          -- continue
        elseif previous_group_start_position >= end_position then
          -- table.insert(new_groups, 'direct')
          table_insert(new_groups, previous_group)
        else
          local remaining_width = previous_group_end_position - end_position
          local start = previous_group_width - remaining_width
          local end_  = previous_group_width
          local new_group = { hl = previous_group.hl, text = strcharpart(previous_group.text, start, end_) }
          -- table.insert(new_groups, { group_start_position, group_end_position, end_position })
          table_insert(new_groups, new_group)
        end

        i = i + 1
        current_position = current_position + previous_group_width
      end

      break
    end
  end

  return new_groups
end

--- Create valid `&tabline` syntax which highlights the next item in the tabline with the highlight `group` specified.
--- @param group string
--- @return string syntax
local function hl_tabline(group)
  return '%#' .. group .. '#'
end

--- Select from `groups` while fitting within the provided `width`, discarding all indices larger than the last index that fits.
--- @param groups bufferline.render.group[]
--- @param width integer
--- @return bufferline.render.group[]
local function slice_groups_right(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(groups) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      local new_group = {hl = group.hl, text = strcharpart(group.text, 0, diff)}
      table_insert(new_groups, new_group)
      break
    end

    table_insert(new_groups, group)
  end

  return new_groups
end

--- Select from `groups` in reverse while fitting within the provided `width`, discarding all indices less than the last index that fits.
--- @param groups bufferline.render.group[]
--- @param width integer
--- @return bufferline.render.group[]
local function slice_groups_left(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(utils.list_reverse(groups)) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      local new_group = {hl = group.hl, text = strcharpart(group.text, start, length)}
      table_insert(new_groups, 1, new_group)
      break
    end

    table_insert(new_groups, 1, group)
  end

  return new_groups
end

--- @class bufferline.render.animation
--- @field CLOSE_DURATION integer
--- @field OPEN {DURATION: integer, DELAY: integer}
--- @field SCROLL_DURATION integer
local ANIMATION = {
  CLOSE_DURATION = 150,
  OPEN = {DELAY = 50, DURATION = 150},
  SCROLL_DURATION = 200,
}

--- @class bufferline.render.group
--- @field hl string the highlight group to use
--- @field text string the content being rendered

--- @class bufferline.render.scroll
--- @field current integer the place where the bufferline is currently scrolled to
--- @field target integer the place where the bufferline is scrolled/wants to scroll to.
local scroll = {current = 0, target = 0}

--- @class bufferline.render
local render = {}

--- An incremental animation for `close_buffer_animated`.
--- @param bufnr integer
--- @param new_width integer
--- @return nil
local function close_buffer_animated_tick(bufnr, new_width, animation)
  if new_width > 0 and state.data_by_bufnr[bufnr] ~= nil then
    local buffer_data = state.get_buffer_data(bufnr)
    buffer_data.width = new_width
    return render.update()
  end
  animate.stop(animation)
  render.close_buffer(bufnr, true)
end

--- Stop tracking the `bufnr` with barbar, and update the bufferline.
--- WARN: does NOT close the buffer in Neovim (see `:h nvim_buf_delete`)
--- @param bufnr integer
--- @param do_name_update? boolean refreshes all buffer names iff `true`
--- @return nil
function render.close_buffer(bufnr, do_name_update)
  state.close_buffer(bufnr, do_name_update)
  render.update()
end

--- Same as `close_buffer`, but animated.
--- @param bufnr integer
--- @return nil
function render.close_buffer_animated(bufnr)
  if options.animation() == false then
    return render.close_buffer(bufnr)
  end

  local buffer_data = state.get_buffer_data(bufnr)
  local current_width = buffer_data.real_width or 0

  buffer_data.closing = true
  buffer_data.width = current_width

  animate.start(
    ANIMATION.CLOSE_DURATION, current_width, 0, vim.v.t_number,
    function(new_width, m)
      close_buffer_animated_tick(bufnr, new_width, m)
    end)
end

--- The incremental animation for `open_buffer_start_animation`.
--- @param bufnr integer
--- @param new_width integer
--- @param animation unknown
--- @return nil
local function open_buffer_animated_tick(bufnr, new_width, animation)
  local buffer_data = state.get_buffer_data(bufnr)
  buffer_data.width = animation.running and new_width or nil

  render.update()
end

--- Opens a buffer with animation.
--- @param bufnr integer
--- @param layout bufferline.layout.data
--- @return nil
local function open_buffer_start_animation(layout, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = utils.index_of(Layout.buffers, bufnr)

  buffer_data.real_width = Layout.calculate_width(
    layout.base_widths[index] or Layout.calculate_buffer_width(bufnr, #Layout.buffers + 1),
    layout.padding_width
  )

  local target_width = buffer_data.real_width or 0

  buffer_data.width = 1

  defer_fn(function()
    animate.start(
      ANIMATION.OPEN.DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(bufnr, new_width, animation)
      end)
  end, ANIMATION.OPEN.DELAY)
end

--- Open the `new_buffers` in the bufferline.
--- @return nil
local function open_buffers(new_buffers)
  local initial_buffers = #state.buffers

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = utils.index_of(state.buffers, state.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = #state.buffers + 1
  end

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if utils.index_of(state.buffers, new_buffer) == nil then
      local actual_index = new_index

      local should_insert_at_start = options.insert_at_start()
      local should_insert_at_end = options.insert_at_end() or
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
  if options.animation() == false then
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

  local layout = Layout.calculate()

  for _, buffer_number in ipairs(new_buffers) do
    open_buffer_start_animation(layout, buffer_number)
  end
end

--- Refresh the buffer list.
--- @return integer[] state.buffers
function render.get_updated_buffers(update_names)
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

      if buffer_data.real_width == nil then
        render.close_buffer(buffer_number)
      else
        render.close_buffer_animated(buffer_number)
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

--- @deprecated use `state.restore_buffers` instead
render.restore_buffers = state.restore_buffers

--- Open the window which contained the buffer which was clicked on.
--- @return integer current_bufnr
function render.set_current_win_listed_buffer()
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

--- Scroll the bufferline relative to its current position.
--- @param n integer the amount to scroll by. Use negative numbers to scroll left, and positive to scroll right.
--- @return nil
function render.scroll(n)
  render.set_scroll(max(0, scroll.target + n))
end

local scroll_animation = nil

--- An incremental animation for `set_scroll`.
--- @return nil
local function set_scroll_tick(new_scroll, animation)
  scroll.current = new_scroll
  if animation.running == false then
    scroll_animation = nil
  end
  render.update(nil, false)
end

--- Scrolls the bufferline to the `target`.
--- @param target integer where to scroll to
--- @return nil
function render.set_scroll(target)
  scroll.target = target

  if not options.animation() then
    scroll.current = target
    return render.update(nil, false)
  end

  if scroll_animation ~= nil then
    animate.stop(scroll_animation)
  end

  scroll_animation = animate.start(
    ANIMATION.SCROLL_DURATION, scroll.current, target, vim.v.t_number,
    set_scroll_tick)
end

--- Sets and redraws `'tabline'` if `s` does not match the cached value.
--- @param s? string
--- @return nil
function render.set_tabline(s)
  s = s or ''
  if last_tabline ~= s then
    last_tabline = s
    set_option('tabline', s)
    command('redrawtabline')
  end
end

--- Generate the `&tabline` representing the current state of Neovim.
--- @param bufnrs integer[] the bufnrs to render
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @return nil|string syntax
local function generate_tabline(bufnrs, refocus)
  if options.auto_hide() then
    if #bufnrs + #list_tabpages() < 3 then -- 3 because the condition for auto-hiding is 1 visible buffer and 1 tabpage (2).
      if get_option'showtabline' == 2 then
        set_option('showtabline', 0)
      end
      return
    end

    if get_option'showtabline' == 0 then
      set_option('showtabline', 2)
    end
  end

  local current = get_current_buf()

  -- Store current buffer to open new ones next to this one
  if buf_get_option(current, 'buflisted') then
    if vim.b.empty_buffer then
      state.last_current_buffer = nil
    else
      state.last_current_buffer = current
    end
  end

  local click_enabled = has('tablineat') and options.clickable()

  local layout = Layout.calculate()

  local items = {}

  local current_buffer_index = nil
  local current_buffer_position = 0

  local inactive_separator = options.icons().inactive.separator.left

  for i, bufnr in ipairs(bufnrs) do
    local activity = Buffer.activities[Buffer.get_activity(bufnr)]

    local buffer_data = state.get_buffer_data(bufnr)
    local buffer_hl = hl_tabline('Buffer' .. activity .. (
      buf_get_option(bufnr, 'modified') and 'Mod' or ''
    ))
    local buffer_name = buffer_data.name or '[no name]'

    buffer_data.real_width    = Layout.calculate_width(layout.base_widths[i], layout.padding_width)
    buffer_data.real_position = current_buffer_position

    local icons_option = state.icons(bufnr, activity)

    --- Prefix this value to allow an element to be clicked
    local clickable = click_enabled and ('%' .. bufnr .. '@BufferlineMainClickHandler@') or ''

    --- The name of the buffer
    --- @type bufferline.render.group
    local name = {hl = clickable .. buffer_hl, text = buffer_name}

    --- The buffer index
    --- @type bufferline.render.group
    local buffer_index = {hl = '', text = ''}
    if icons_option.buffer_index then
      buffer_index.hl = hl_tabline('Buffer' .. activity .. 'Index')
      buffer_index.text = tostring(i) .. ' '
    end

    --- The buffer number
    --- @type bufferline.render.group
    local buffer_number = {hl = '', text = ''}
    if icons_option.buffer_number then
      buffer_number.hl = hl_tabline('Buffer' .. activity .. 'Number')
      buffer_number.text = tostring(bufnr) .. ' '
    end

    local button = icons_option.button or ''

    --- The close icon
    --- @type bufferline.render.group
    local close = {hl = buffer_hl, text = button .. ' '}
    if click_enabled and #button > 0 then
      close.hl = '%' .. bufnr .. '@BufferlineCloseClickHandler@' .. close.hl
    end

    --- The jump letter
    --- @type bufferline.render.group
    local jump_letter = {hl = '', text = ''}

    --- The devicon
    --- @type bufferline.render.group
    local icon = {hl = clickable, text = ''}

    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(bufnr)

      -- Replace first character of buf name with jump letter
      if letter and not icons_option.filetype.enabled then
        name.text = strcharpart(name.text, 1)
      end

      jump_letter.hl = hl_tabline('Buffer' .. activity .. 'Target')
      jump_letter.text = (letter or '') ..
        (icons_option.filetype.enabled and (' ' .. (letter and '' or ' ')) or '')
    elseif icons_option.filetype.enabled then
      local iconChar, iconHl = icons.get_icon(bufnr, activity)
      local hlName = (activity == 'Inactive' and not options.highlight_inactive_file_icons())
        and 'BufferInactive'
        or iconHl

      icon.hl = icons_option.filetype.custom_color and
        hl_tabline('Buffer' .. activity .. 'Icon') or
        (hlName and hl_tabline(hlName) or buffer_hl)
      icon.text = iconChar .. ' '
    end

    --- The padding
    --- @type bufferline.render.group
    local padding = {hl = '', text = (' '):rep(layout.padding_width)}

    --- The separator
    --- @type bufferline.render.group
    local left_separator = {
      hl = clickable .. hl_tabline('Buffer' .. activity .. 'Sign'),
      text = icons_option.separator.left,
    }

    local item = {
      groups = {left_separator, padding, buffer_index, buffer_number, icon, jump_letter, name},
      position = buffer_data.position or buffer_data.real_position,
      width = buffer_data.width
        -- <padding> <base_widths[i]> <padding>
        or layout.base_widths[i] + (2 * layout.padding_width),
    }

    Buffer.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(c, d, s)
      table_insert(item.groups, {
        hl = hl_tabline('Buffer' .. activity .. severity[s]),
        text = ' ' .. d.icon .. c,
      })
    end)

    --- @type bufferline.render.group
    local right_separator = {hl = left_separator.hl, text = icons_option.separator.right}

    vim.list_extend(item.groups, {padding, close, right_separator})

    if activity == 'Current' and refocus ~= false then
      current_buffer_index = i
      current_buffer_position = buffer_data.real_position

      local start = current_buffer_position
      local end_  = current_buffer_position + item.width

      if scroll.target > start then
        render.set_scroll(start)
      elseif scroll.target + layout.buffers_width < end_ then
        render.set_scroll(scroll.target + (end_ - (scroll.target + layout.buffers_width)))
      end
    end

    table_insert(items, item)
    current_buffer_position = current_buffer_position + item.width
  end

  -- Create actual tabline string
  local result = ''

  -- Add offset filler & text (for filetree/sidebar plugins)
  if state.offset.width > 0 then
    --- @type bufferline.render.group
    local offset = {hl = hl_tabline(state.offset.hl or 'BufferOffset'), text = ' ' .. state.offset.text}
    local offset_available_width = state.offset.width - 2

    result = result ..
      groups_to_string(slice_groups_right({offset}, offset_available_width)) ..
      (' '):rep(offset_available_width - #state.offset.text + 1)
  end

  --- The highlight of the buffer tabpage fill
  local hl_buffer_tabpage_fill = hl_tabline('BufferTabpageFill')

  --- Add bufferline
  --- @type bufferline.render.group[]
  local bufferline_groups = {{
    hl = hl_buffer_tabpage_fill,
    text = (' '):rep(layout.actual_width),
  }}

  for i, item in ipairs(items) do
    if i ~= current_buffer_index then
      bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
    end
  end

  if current_buffer_index ~= nil then
    local item = items[current_buffer_index]
    bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
  end

  -- Crop to scroll region
  local max_scroll = max(layout.actual_width - layout.buffers_width, 0)
  local scroll_current = min(scroll.current, max_scroll)
  local buffers_end = layout.actual_width - scroll_current

  if buffers_end > layout.buffers_width then
    bufferline_groups = slice_groups_right(bufferline_groups, scroll_current + layout.buffers_width)
  end

  if scroll_current > 0 then
    bufferline_groups = slice_groups_left(bufferline_groups, layout.buffers_width)
  end

  result = result ..
    groups_to_string(bufferline_groups) .. -- Render bufferline string
    '%0@BufferlineMainClickHandler@' .. -- prevent the expansion of the last click group
    hl_buffer_tabpage_fill

  if layout.actual_width + strwidth(inactive_separator) <= layout.buffers_width and #items > 0 then
    result = result .. inactive_separator
  end

  if layout.tabpages_width > 0 then
    result = result .. '%=%#BufferTabpages# ' .. tabpagenr() .. '/' .. tabpagenr('$') .. ' '
  end

  return result .. hl_buffer_tabpage_fill
end

--- Update `&tabline`
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @param update_names? boolean whether to refresh the names of the buffers (default: `false`)
--- @return nil
function render.update(update_names, refocus)
  if vim.g.SessionLoad then
    return
  end

  local ok, result = xpcall(
    function()
      return generate_tabline(Buffer.hide(render.get_updated_buffers(update_names)), refocus)
    end,
    debug.traceback
  )

  if not ok then
    command('BarbarDisable')
    utils.notify(
      "Barbar detected an error while running. Barbar disabled itself :/ " ..
        "Include this in your report: " ..
        tostring(result),
      vim.log.levels.ERROR
    )
  else
    render.set_tabline(result)
  end
end

return render
