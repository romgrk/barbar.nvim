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

local animate = require'barbar.animate'
local Buffer = require'barbar.buffer'
local config = require'barbar.config'
-- local fs = require'barbar.fs' -- For debugging purposes
local groups = require'barbar.groups'
local icons = require'barbar.icons'
local JumpMode = require'barbar.jump_mode'
local Layout = require'barbar.layout'
local state = require'barbar.state'
local utils = require'barbar.utils'

--- Last value for tabline
--- @type string
local last_tabline = ''

--- Create valid `&tabline` syntax which highlights the next item in the tabline with the highlight `group` specified.
--- @param group string
--- @return string syntax
local function wrap_hl(group)
  return '%#' .. group .. '#'
end

--- @class barbar.render.animation
--- @field OPEN_DELAY integer
--- @field OPEN_DURATION integer
--- @field CLOSE_DURATION integer
--- @field SCROLL_DURATION integer
local ANIMATION = {
  OPEN_DELAY = 10,
  OPEN_DURATION = 150,
  CLOSE_DURATION = 150,
  SCROLL_DURATION = 200,
}

--- @class barbar.render.group
--- @field hl string the highlight group to use
--- @field text string the content being rendered

--- @class barbar.render.group_clump
--- @field groups barbar.render.group[]
--- @field position integer
--- @field width integer

--- @class barbar.render.scroll
--- @field current integer the place where the bufferline is currently scrolled to
--- @field target integer the place where the bufferline is scrolled/wants to scroll to.
local scroll = {current = 0, target = 0}

--- @class barbar.render
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
  if config.options.animation == false then
    return render.close_buffer(bufnr)
  end

  local buffer_data = state.get_buffer_data(bufnr)
  local current_width = buffer_data.computed_width or 0

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
--- @param layout barbar.layout.data
--- @return nil
local function open_buffer_start_animation(layout, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = utils.index_of(Layout.buffers, bufnr)

  buffer_data.computed_width = Layout.calculate_width(
    layout.base_widths[index] or Layout.calculate_buffer_width(bufnr, #Layout.buffers + 1),
    layout.padding_width
  )

  local target_width = buffer_data.computed_width or 0

  buffer_data.width = 1

  defer_fn(function()
    animate.start(
      ANIMATION.OPEN_DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(bufnr, new_width, animation)
      end)
  end, ANIMATION.OPEN_DELAY)
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

  local should_insert_at_start = config.options.insert_at_start

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if utils.index_of(state.buffers, new_buffer) == nil then
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

      if buffer_data.computed_width == nil then
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

  if not config.options.animation then
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

--- Compute the buffer hl-groups
--- @param layout barbar.layout.data
--- @param bufnrs integer[]
--- @param refocus? boolean
--- @return barbar.render.group_clump[] pinned_groups, barbar.render.group_clump[] clumps
local function get_bufferline_group_clumps(layout, bufnrs, refocus)
  local click_enabled = has('tablineat') and config.options.clickable

  local accumulated_pinned_width = 0 --- the width of pinned buffers accumulated while iterating
  local accumulated_width = 0 --- the width of buffers accumulated while iterating
  local current_buffer_index = nil --- @type nil|integer
  local done = false --- if all of the visible buffers have been clumped
  local group_clumps = {} --- @type barbar.render.group_clump[]
  local pinned_group_clumps = {} --- @type barbar.render.group_clump[]

  --- The padding
  --- @type barbar.render.group
  local padding = {hl = '', text = (' '):rep(layout.padding_width)}

  --- The padding of a pinned buffer
  --- @type barbar.render.group
  local pinned_padding = {hl = padding.hl, text = (' '):rep(config.options.minimum_padding)}

  for i, bufnr in ipairs(bufnrs) do
    local activity = Buffer.activities[Buffer.get_activity(bufnr)]
    local buffer_data = state.get_buffer_data(bufnr)
    local modified = buf_get_option(bufnr, 'modified')
    local pinned = buffer_data.pinned

    if pinned then
      buffer_data.computed_position = accumulated_pinned_width
      buffer_data.computed_width    = Layout.calculate_width(layout.base_widths[i], config.options.minimum_padding)
    else
      buffer_data.computed_position = accumulated_width
      buffer_data.computed_width    = Layout.calculate_width(layout.base_widths[i], layout.padding_width)
    end

    local group_clump_width = buffer_data.width or buffer_data.computed_width

    if activity == 'Current' and refocus ~= false then
      current_buffer_index = i

      local start = accumulated_width
      local end_  = accumulated_width + group_clump_width

      if scroll.target > start then
        render.set_scroll(start)
      elseif scroll.target + layout.buffers_width < end_ then
        render.set_scroll(scroll.target + (end_ - (scroll.target + layout.buffers_width)))
      end
    end

    local scroll_current = min(scroll.current, layout.scroll_max)

    if pinned then
      accumulated_pinned_width = accumulated_pinned_width + group_clump_width
    else
      accumulated_width = accumulated_width + group_clump_width

      if accumulated_width < scroll_current  then
        goto continue -- HACK: there is no `continue` keyword
      elseif (refocus == false or (refocus ~= false and current_buffer_index ~= nil)) and
        accumulated_width - scroll_current > layout.buffers_width
      then
        done = true
      end
    end

    local buffer_name = buffer_data.name or '[no name]'
    local buffer_hl = wrap_hl('Buffer' .. activity .. (modified and 'Mod' or ''))

    local icons_option = Buffer.get_icons(activity, modified, pinned)

    --- Prefix this value to allow an element to be clicked
    local clickable = click_enabled and ('%' .. bufnr .. '@barbar#events#main_click_handler@') or ''

    --- The name of the buffer
    --- @type barbar.render.group
    local name = {hl = clickable .. buffer_hl, text = icons_option.filename and buffer_name or ''}

    --- The buffer index
    --- @type barbar.render.group
    local buffer_index = { hl = '', text = '' }
    if icons_option.buffer_index then
      buffer_index.hl = wrap_hl('Buffer' .. activity .. 'Index')
      buffer_index.text = i .. ' '
    end

    --- The buffer number
    --- @type barbar.render.group
    local buffer_number = { hl = '', text = '' }
    if icons_option.buffer_number then
      buffer_number.hl = wrap_hl('Buffer' .. activity .. 'Number')
      buffer_number.text = bufnr .. ' '
    end

    --- The close icon
    --- @type barbar.render.group
    local button = {hl = buffer_hl, text = ''}

    local button_icon = icons_option.button
    if button_icon and #button_icon > 0 then
      button.text = button_icon .. ' '

      if click_enabled then
        button.hl = '%' .. bufnr .. '@barbar#events#close_click_handler@' .. button.hl
      end
    end

    --- The jump letter
    --- @type barbar.render.group
    local jump_letter = { hl = '', text = '' }

    --- The devicon
    --- @type barbar.render.group
    local icon = { hl = clickable, text = '' }

    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(bufnr)

      -- Replace first character of buf name with jump letter
      if letter and not icons_option.filetype.enabled then
        name.text = strcharpart(name.text, 1)
      end

      jump_letter.hl = wrap_hl('Buffer' .. activity .. 'Target')
      if letter then
        jump_letter.text = letter
        if icons_option.filetype.enabled and #name.text > 0 then
          jump_letter.text = jump_letter.text .. ' '
        end
      elseif icons_option.filetype.enabled then
        jump_letter.text = '  '
      end
    elseif icons_option.filetype.enabled then
      local iconChar, iconHl = icons.get_icon(bufnr, activity)
      local hlName = (activity == 'Inactive' and not config.options.highlight_inactive_file_icons)
        and 'BufferInactive'
        or iconHl

      icon.hl = icons_option.filetype.custom_colors and
        wrap_hl('Buffer' .. activity .. 'Icon') or
        (hlName and wrap_hl(hlName) or buffer_hl)
      icon.text = #name.text > 0 and iconChar .. ' ' or iconChar
    end

    --- The separator
    --- @type barbar.render.group
    local left_separator = {
      hl = clickable .. wrap_hl('Buffer' .. activity .. 'Sign'),
      text = icons_option.separator.left,
    }

    local pad = pinned and pinned_padding or padding
    local group_clump = { --- @type barbar.render.group_clump
      groups = {left_separator, pad, buffer_index, buffer_number, icon, jump_letter, name},
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      position = buffer_data.position or buffer_data.computed_position,
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      width = group_clump_width,
    }

    Buffer.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(count, idx, option)
      table_insert(group_clump.groups, {
        hl = wrap_hl('Buffer' .. activity .. severity[idx]),
        text = ' ' .. option.icon .. count,
      })
    end)

    --- @type barbar.render.group
    local right_separator = { hl = left_separator.hl, text = icons_option.separator.right }

    vim.list_extend(group_clump.groups, { pad, button, right_separator })

    table_insert(pinned and pinned_group_clumps or group_clumps, group_clump)

    if done then
      break
    end

    ::continue::
  end

  return pinned_group_clumps, group_clumps
end

local HL = {
  FILL = wrap_hl('BufferTabpageFill'),
}

--- Generate the `&tabline` representing the current state of Neovim.
--- @param bufnrs integer[] the bufnrs to render
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @return nil|string syntax
local function generate_tabline(bufnrs, refocus)
  local layout = Layout.calculate()
  local pinned_group_clumps, group_clumps = get_bufferline_group_clumps(layout, bufnrs, refocus)

  -- Create actual tabline string
  local result = ''

  -- Left offset
  if state.offset.left.width > 0 then
    local hl = wrap_hl(state.offset.left.hl)
    local offset_groups = {
      { hl = hl, text = (' '):rep(state.offset.left.width) }
    }

    local content = {
      { hl = hl, text = state.offset.left.text }
    }
    local content_max_width = state.offset.left.width - 2

    offset_groups =
      groups.insert(
        offset_groups,
        1,
        groups.slice_right(content, content_max_width))

    result = result .. groups.to_string(offset_groups)
  end

  --- @type barbar.render.group[]
  local bufferline_groups = {
    {
      hl = HL.FILL,
      text = (' '):rep(layout.actual_width),
    }
  }

  for _, group_clump in ipairs(group_clumps) do
    bufferline_groups = groups.insert(bufferline_groups, group_clump.position, group_clump.groups)
  end

  do -- Crop to scroll region
    local scroll_current = min(scroll.current, layout.scroll_max)
    local buffers_end = layout.actual_width - scroll_current

    if buffers_end > layout.buffers_width then
      bufferline_groups = groups.slice_right(bufferline_groups, scroll_current + layout.buffers_width)
    end

    if scroll_current > 0 then
      bufferline_groups = groups.slice_left(bufferline_groups, layout.buffers_width)
    end
  end

  if #pinned_group_clumps > 0 then
    local pinned_groups = {
      {
        hl = HL.FILL,
        text = (' '):rep(layout.pinned_width),
      }
    }
    for _, pinned_group_clump in ipairs(pinned_group_clumps) do
      pinned_groups = groups.insert(pinned_groups, pinned_group_clump.position, pinned_group_clump.groups)
    end

    result = result .. groups.to_string(pinned_groups)
  end

  -- Render bufferline string
  result = result .. groups.to_string(bufferline_groups)

  do
    local inactive_separator = config.options.icons.inactive.separator.left
    if #group_clumps > 0 and layout.actual_width + strwidth(inactive_separator) <= layout.buffers_width then
      result = result .. groups.to_string({{ text = inactive_separator or '', hl = wrap_hl('BufferInactiveSign') }})
    end
  end

  -- prevent the expansion of the last click group
  result = result .. '%0@barbar#events#main_click_handler@'

  if layout.tabpages_width > 0 then
    result = result .. '%=%#BufferTabpages# ' .. tabpagenr() .. '/' .. tabpagenr('$') .. ' '
  end

  -- Right offset
  if state.offset.right.width > 0 then
    local hl = wrap_hl(state.offset.right.hl)
    local offset_groups = {
      { hl = hl, text = (' '):rep(state.offset.right.width) }
    }

    local content = {
      { hl = hl, text = state.offset.right.text }
    }
    local content_max_width = state.offset.right.width - 2

    offset_groups =
      groups.insert(
        offset_groups,
        1,
        groups.slice_right(content, content_max_width))

    result = result .. groups.to_string(offset_groups)
  end

  -- NOTE: For development or debugging purposes, the following code can be used:
  -- ```lua
  -- local text = groups.to_raw_string(bufferline_groups, true)
  -- if layout.actual_width + strwidth(inactive_separator) <= layout.buffers_width and #items > 0 then
  --   text = text .. groups.to_raw_string({{ text = inactive_separator or '', hl = wrap_hl('BufferInactiveSign') }}, true)
  -- end
  -- local data = vim.json.encode({ metadata = 42 })
  -- fs.write('barbar.debug.txt', text .. ':' .. data .. '\n', 'a')
  -- ```

  return result .. HL.FILL
end

--- Update `&tabline`
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @param update_names? boolean whether to refresh the names of the buffers (default: `false`)
--- @return nil
function render.update(update_names, refocus)
  if vim.g.SessionLoad then
    return
  end

  local buffers = Buffer.hide(render.get_updated_buffers(update_names))

  -- Auto hide/show if applicable
  if config.options.auto_hide then
    if #buffers + #list_tabpages() < 3 then -- 3 because the condition for auto-hiding is 1 visible buffer and 1 tabpage (2).
      if get_option'showtabline' == 2 then
        set_option('showtabline', 0)
      end
      return
    end

    if get_option'showtabline' == 0 then
      set_option('showtabline', 2)
    end
  end

  -- Store current buffer to open new ones next to this one
  local current = get_current_buf()
  if buf_get_option(current, 'buflisted') then
    if vim.b.empty_buffer then
      state.last_current_buffer = nil
    else
      state.last_current_buffer = current
    end
  end

  -- Render the tabline
  local ok, result = xpcall(
    function() render.set_tabline(generate_tabline(buffers, refocus)) end,
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
  end
end

return render
