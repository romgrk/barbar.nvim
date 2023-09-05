--
-- render.lua
--

local max = math.max
local table_insert = table.insert

local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
local command = vim.api.nvim_command --- @type function
local defer_fn = vim.defer_fn
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local get_option = vim.api.nvim_get_option --- @type function
local has = vim.fn.has --- @type function
local list_extend = vim.list_extend
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

local animate = require('barbar.animate')
local buffer = require('barbar.buffer')
local config = require('barbar.config')
-- local fs = require('barbar.fs') -- For debugging purposes
local get_icon = require('barbar.icons').get_icon
local get_letter = require('barbar.jump_mode').get_letter
local index_of = require('barbar.utils.list').index_of
local layout = require('barbar.ui.layout')
local nodes = require('barbar.ui.nodes')
local notify = require('barbar.utils').notify
local state = require('barbar.state')

-- Digits for optional styling of buffer_number and buffer_index.
local SUPERSCRIPT_DIGITS = { '⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹' }
local SUBSCRIPT_DIGITS = { '₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉' }

--- Last value for tabline
--- @type string
local last_tabline = ''

--- @param num number
--- @param style barbar.config.options.icons.buffer.number
--- @return integer|string styled, integer substituted
local function style_number(num, style)
  if style == true then
    return num, 0
  end

  local digits = style == 'subscript' and SUBSCRIPT_DIGITS or SUPERSCRIPT_DIGITS
  return tostring(num):gsub('%d', function(match) return digits[match + 1] end)
end

--- Create valid `&tabline` syntax which highlights the next item in the tabline with the highlight `group` specified.
--- @param group string
--- @return string syntax
local function wrap_hl(group)
  return '%#' .. group .. '#'
end

--- @class barbar.ui.render.animation
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

--- @class barbar.ui.render.scroll
--- @field current integer the place where the bufferline is currently scrolled to
--- @field target integer the place where the bufferline is scrolled/wants to scroll to.
local scroll = { current = 0, target = 0 }

--- @class barbar.ui.Render
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
--- @param data barbar.ui.layout.data
--- @return nil
local function open_buffer_start_animation(data, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = index_of(layout.buffers, bufnr)

  buffer_data.computed_width = layout.calculate_width(
    data.buffers.base_widths[index] or layout.calculate_buffer_width(bufnr, #layout.buffers + 1),
    data.buffers.padding
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
  local new_index = index_of(state.buffers, state.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = #state.buffers + 1
  end

  local should_insert_at_start = config.options.insert_at_start

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if index_of(state.buffers, new_buffer) == nil then
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

  local data = layout.calculate()

  for _, buffer_number in ipairs(new_buffers) do
    open_buffer_start_animation(data, buffer_number)
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
  if s == nil then
    s = ''
  end

  if last_tabline ~= s then
    last_tabline = s
    set_option('tabline', s)
    command('redrawtabline')
  end
end

--- Compute the buffer hl-groups
--- @param data barbar.ui.layout.data
--- @param bufnrs integer[]
--- @param refocus? boolean
--- @return barbar.ui.container[] pinned, barbar.ui.container[] unpinned, nil|{idx: integer, pinned: boolean} current_buffer
local function get_bufferline_containers(data, bufnrs, refocus)
  local click_enabled = has('tablineat') and config.options.clickable

  local accumulated_pinned_width = 0 --- the width of pinned buffers accumulated while iterating
  local accumulated_unpinned_width = 0 --- the width of buffers accumulated while iterating
  local current_buffer = nil --- @type nil|{idx: integer, pinned: boolean}
  local done = false --- if all of the visible buffers have been clumped
  local containers = {} --- @type barbar.ui.container[]
  local pinned_containers = {} --- @type barbar.ui.container[]

  local pinned_pad_text   = (' '):rep(config.options.minimum_padding)
  local unpinned_pad_text = (' '):rep(data.buffers.padding)

  for i, bufnr in ipairs(bufnrs) do
    local activity = buffer.get_activity(bufnr)
    local activity_name = buffer.activities[activity]
    local buffer_data = state.get_buffer_data(bufnr)
    local modified = buf_get_option(bufnr, 'modified')
    local pinned = buffer_data.pinned

    if pinned then
      buffer_data.computed_position = accumulated_pinned_width
      buffer_data.computed_width    = layout.calculate_width(data.buffers.base_widths[i], config.options.minimum_padding)
    else
      buffer_data.computed_position = accumulated_unpinned_width + data.buffers.pinned_width
      buffer_data.computed_width    = layout.calculate_width(data.buffers.base_widths[i], data.buffers.padding)
    end

    local container_width = buffer_data.width or buffer_data.computed_width

    if activity == buffer.activities.Current and refocus ~= false then
      current_buffer = {idx = #(pinned and pinned_containers or containers) + 1, pinned = pinned}

      local start = accumulated_unpinned_width
      local end_  = accumulated_unpinned_width + container_width

      if scroll.target > start then
        render.set_scroll(start)
      elseif scroll.target + data.buffers.unpinned_allocated_width < end_ then
        render.set_scroll(scroll.target + (end_ - (scroll.target + data.buffers.unpinned_allocated_width)))
      end
    end

    if pinned then
      accumulated_pinned_width = accumulated_pinned_width + container_width
    else
      accumulated_unpinned_width = accumulated_unpinned_width + container_width

      if accumulated_unpinned_width < scroll.current  then
        goto continue -- HACK: there is no `continue` keyword
      elseif (refocus == false or (refocus ~= false and current_buffer ~= nil)) and
        accumulated_unpinned_width - scroll.current > data.buffers.unpinned_allocated_width
      then
        done = true
      end
    end

    local buffer_name = buffer_data.name or '[no name]'
    local buffer_hl = wrap_hl('Buffer' .. activity_name .. (modified and 'Mod' or ''))

    local icons_option = buffer.get_icons(activity_name, modified, pinned)

    --- Prefix this value to allow an element to be clicked
    local clickable = click_enabled and ('%' .. bufnr .. '@barbar#events#main_click_handler@') or ''

    --- The name of the buffer
    --- @type barbar.ui.node
    local name = {hl = clickable .. buffer_hl, text = icons_option.filename and buffer_name or ''}

    --- The buffer index
    --- @type barbar.ui.node
    local buffer_index = { hl = '', text = '' }
    if icons_option.buffer_index then
      buffer_index.hl = wrap_hl('Buffer' .. activity_name .. 'Index')
      buffer_index.text = style_number(i, icons_option.buffer_index) .. ' '
    end

    --- The buffer number
    --- @type barbar.ui.node
    local buffer_number = { hl = '', text = '' }
    if icons_option.buffer_number then
      buffer_number.hl = wrap_hl('Buffer' .. activity_name .. 'Number')
      buffer_number.text = style_number(bufnr, icons_option.buffer_number) .. ' '
    end

    --- The close icon
    --- @type barbar.ui.container
    local button = {hl = buffer_hl, text = ''}

    local button_icon = icons_option.button
    if button_icon and #button_icon > 0 then
      button.text = button_icon .. ' '

      if click_enabled then
        button.hl = '%' .. bufnr .. '@barbar#events#close_click_handler@' .. button.hl
      end
    end

    --- The jump letter
    --- @type barbar.ui.node
    local jump_letter = { hl = '', text = '' }

    --- The devicon
    --- @type barbar.ui.node
    local icon = { hl = clickable, text = '' }

    if state.is_picking_buffer then
      local letter = get_letter(bufnr)

      -- Replace first character of buf name with jump letter
      if letter and not icons_option.filetype.enabled then
        name.text = strcharpart(name.text, 1)
      end

      jump_letter.hl = wrap_hl('Buffer' .. activity_name .. 'Target')
      if letter then
        jump_letter.text = letter
        if icons_option.filetype.enabled and #name.text > 0 then
          jump_letter.text = jump_letter.text .. ' '
        end
      elseif icons_option.filetype.enabled then
        jump_letter.text = '  '
      end
    elseif icons_option.filetype.enabled then
      local iconChar, iconHl = get_icon(bufnr, activity_name)
      local hlName = (activity_name == 'Inactive' and not config.options.highlight_inactive_file_icons)
        and 'BufferInactive'
        or iconHl

      icon.hl = icons_option.filetype.custom_colors and
        wrap_hl('Buffer' .. activity_name .. 'Icon') or
        (hlName and wrap_hl(hlName) or buffer_hl)
      icon.text = #name.text > 0 and iconChar .. ' ' or iconChar
    end

    --- @type barbar.ui.node
    local left_separator = {
      hl = clickable .. wrap_hl('Buffer' .. activity_name .. 'Sign'),
      text = icons_option.separator.left,
    }

    --- @type barbar.ui.node
    local padding = { hl = buffer_hl, text = pinned and pinned_pad_text or unpinned_pad_text }

    local container = { --- @type barbar.ui.container
      nodes = { left_separator, padding, buffer_index, buffer_number, icon, jump_letter, name },
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      position = buffer_data.position or buffer_data.computed_position,
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      width = container_width,
    }

    state.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(count, idx, option)
      table_insert(container.nodes, {
        hl = wrap_hl('Buffer' .. activity_name .. severity[idx]),
        text = ' ' .. option.icon .. count,
      })
    end)

    state.for_each_counted_enabled_git_status(bufnr, icons_option.gitsigns, function(count, idx, option)
      table_insert(container.nodes, {
        hl = wrap_hl('Buffer' .. activity_name .. idx:upper()),
        text = ' ' .. option.icon .. count,
      })
    end)

    --- @type barbar.ui.node
    local right_separator = {
      hl = clickable .. wrap_hl('Buffer' .. activity_name .. 'SignRight'),
      text = icons_option.separator.right,
    }

    list_extend(container.nodes, { padding, button, right_separator })
    table_insert(pinned and pinned_containers or containers, container)

    if done then
      break
    end

    ::continue::
  end

  return pinned_containers, containers, current_buffer
end

local HL = {
  FILL = wrap_hl('BufferTabpageFill'),
  TABPAGES = wrap_hl('BufferTabpages'),
  TABPAGES_SEP = wrap_hl('BufferTabpagesSep'),
  SIGN_INACTIVE = wrap_hl('BufferInactiveSign'),
  SCROLL_ARROW = wrap_hl('BufferScrollArrow'),
}

--- Generate the `&tabline` representing the current state of Neovim.
--- @param bufnrs integer[] the bufnrs to render
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @return nil|string syntax
local function generate_tabline(bufnrs, refocus)
  local data = layout.calculate()
  if refocus ~= false and scroll.current > data.buffers.scroll_max then
    render.set_scroll(data.buffers.scroll_max)
  end

  local pinned, unpinned, current_buffer = get_bufferline_containers(data, bufnrs, refocus)

  -- Create actual tabline string
  local result = ''

  -- Left offset
  if state.offset.left.width > 0 then
    local hl = wrap_hl(state.offset.left.hl)
    local offset_nodes = { { hl = hl, text = (' '):rep(state.offset.left.width) } }

    local content = { { hl = hl, text = state.offset.left.text } }
    local content_max_width = state.offset.left.width - 2

    offset_nodes = nodes.insert_many(offset_nodes, 1, nodes.slice_right(content, content_max_width))
    result = result .. nodes.to_string(offset_nodes)
  end

  -- Buffer tabs
  do
    --- @type barbar.ui.container
    local content = { { hl = HL.FILL, text = (' '):rep(data.buffers.width) } }

    do
      local current_container = nil
      local current_not_unpinned = current_buffer == nil or current_buffer.pinned == true

      for i, container in ipairs(unpinned) do
        -- We insert the current buffer after the others so it's always on top
        --- @diagnostic disable-next-line:need-check-nil
        if current_not_unpinned or (current_buffer.pinned == false and current_buffer.idx ~= i) then
          content = nodes.insert_many(content, container.position - scroll.current, container.nodes)
        else
          current_container = container
        end
      end

      if current_container ~= nil then
        content = nodes.insert_many(content, current_container.position - scroll.current, current_container.nodes)
      end
    end

    if config.options.icons.separator_at_end then
      local inactive_separator = config.options.icons.inactive.separator.left
      if inactive_separator ~= nil and #unpinned > 0 and
        data.buffers.unpinned_width + strwidth(inactive_separator) <= data.buffers.unpinned_allocated_width
      then
        content = nodes.insert(content, data.buffers.used_width, { text = inactive_separator, hl = HL.SIGN_INACTIVE })
      end
    end

    if #pinned > 0 then
      local current_container = nil
      local current_not_pinned = current_buffer == nil or current_buffer.pinned == false

      for i, container in ipairs(pinned) do
        -- We insert the current buffer after the others so it's always on top
        --- @diagnostic disable-next-line:need-check-nil
        if current_not_pinned or (current_buffer.pinned == true and current_buffer.idx ~= i) then
          content = nodes.insert_many(content, container.position, container.nodes)
        else
          current_container = container
        end
      end

      if current_container ~= nil then
        content = nodes.insert_many(content, current_container.position, current_container.nodes)
      end
    end

    local filler = { { hl = HL.FILL, text = (' '):rep(data.buffers.width) } }
    content = nodes.insert_many(filler, 0, content)
    content = nodes.slice_right(content, data.buffers.width)

    local has_left_scroll = scroll.current > 0
    if has_left_scroll then
      content = nodes.insert(content, data.buffers.pinned_width, {
        hl = HL.SCROLL_ARROW,
        text = config.options.icons.scroll.left,
      })
    end

    local has_right_scroll = data.buffers.used_width - scroll.current > data.buffers.width
    if has_right_scroll then
      content = nodes.insert(content, data.buffers.width - 1, {
        hl = HL.SCROLL_ARROW,
        text = config.options.icons.scroll.right,
      })
    end

    -- Render bufferline string
    result = result .. nodes.to_string(content)

    -- Prevent the expansion of the last click group
    if config.options.clickable then
      result = result .. '%0@barbar#events#main_click_handler@'
    end
  end

  -- Tabpages
  if data.tabpages.width > 0 then
    result = result .. nodes.to_string({
      {hl = HL.TABPAGES, text = ' ' .. tabpagenr()},
      {hl = HL.TABPAGES_SEP, text = '/'},
      {hl = HL.TABPAGES, text = tabpagenr('$') .. ' '},
    })
  end

  -- Right offset
  if state.offset.right.width > 0 then
    local hl = wrap_hl(state.offset.right.hl)
    local offset_nodes = { { hl = hl, text = (' '):rep(state.offset.right.width) } }

    local content = { { hl = hl, text = state.offset.right.text } }
    local content_max_width = state.offset.right.width - 2

    offset_nodes = nodes.insert_many(offset_nodes, 1, nodes.slice_right(content, content_max_width))

    result = result .. nodes.to_string(offset_nodes)
  end

  -- NOTE: For development or debugging purposes, the following code can be used:
  -- ```lua
  -- local text = Nodes.to_raw_string(bufferline_nodes, true)
  -- if layout.buffers.unpinned_width + strwidth(inactive_separator) <= layout.buffers.unpinned_allocated_width and #items > 0 then
  --   text = text .. Nodes.to_raw_string({{ text = inactive_separator or '', hl = wrap_hl('BufferInactiveSign') }}, true)
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

  local buffers = layout.hide(render.get_updated_buffers(update_names))

  -- Auto hide/show if applicable
  if config.options.auto_hide > -1 then
    if #buffers <= config.options.auto_hide and #list_tabpages() < 2 then
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
    notify(
      "Barbar detected an error while running. Barbar disabled itself :/ " ..
        "Include this in your report: " ..
        tostring(result),
      vim.log.levels.ERROR
    )
  end
end

return render
