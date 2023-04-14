--
-- render.lua
--

local max = math.max
local min = math.min
local table_insert = table.insert
local table_remove = table.remove

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

local animate = require'barbar.animate'
local Buffer = require'barbar.buffer'
local config = require'barbar.config'
-- local fs = require'barbar.fs' -- For debugging purposes
local Nodes = require'barbar.ui.nodes'
local icons = require'barbar.icons'
local JumpMode = require'barbar.jump_mode'
local Layout = require'barbar.ui.layout'
local state = require'barbar.state'
local utils = require'barbar.utils'

--- @class barbar.ui.render
local render = {}


-- Animation durations & delays
local BUFFER_OP_DURATION = 150

local OPEN_DELAY      = 10 -- Let autocmds & other plugins run, avoids jank
local OPEN_DURATION   = BUFFER_OP_DURATION
local MOVE_DURATION   = BUFFER_OP_DURATION
local CLOSE_DURATION  = BUFFER_OP_DURATION
local PIN_DURATION    = BUFFER_OP_DURATION
local SCROLL_DURATION = 200


--- Last value for tabline
--- @type string
local last_tabline = ''

--- @class barbar.ui.render.scroll
--- @field current integer the place where the bufferline is currently scrolled to
--- @field target integer the place where the bufferline is scrolled/wants to scroll to.
local scroll = { current = 0, target = 0 }

--- @type nil|barbar.animate.state
local current_animation = nil


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

  current_animation = animate.stop(current_animation)
  current_animation = animate.start(
    CLOSE_DURATION, current_width, 0, vim.v.t_number,
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
--- @param layout barbar.ui.layout.data
--- @return nil
local function open_buffer_start_animation(layout, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = utils.index_of(Layout.buffers, bufnr)

  buffer_data.computed_width = Layout.calculate_width(
    layout.buffers.base_widths[index] or Layout.calculate_buffer_width(bufnr, #Layout.buffers + 1),
    layout.buffers.padding
  )

  local target_width = buffer_data.computed_width or 0

  buffer_data.width = 1

  defer_fn(function()
    current_animation = animate.stop(current_animation)
    current_animation = animate.start(
      OPEN_DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(bufnr, new_width, animation)
      end)
  end, OPEN_DELAY)
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

--- Move a buffer (with animation, if configured).
--- @param from_idx integer the buffer's original index.
--- @param to_idx integer the buffer's new index.
--- @return nil
function render.move_buffer(from_idx, to_idx)
  to_idx = max(1, min(#state.buffers, to_idx))
  if to_idx == from_idx then
    return
  end

  local animation = config.options.animation
  local buffer_number = state.buffers[from_idx]

  local previous_positions
  if animation == true then
    previous_positions = Layout.calculate_buffers_position_by_buffer_number()
  end

  table_remove(state.buffers, from_idx)
  table_insert(state.buffers, to_idx, buffer_number)
  state.sort_pins_to_left()

  if animation == false then
    return render.update()
  end

  local current_index = utils.index_of(Layout.buffers, buffer_number)
  local start_index = min(from_idx, current_index)
  local end_index   = max(from_idx, current_index)

  if start_index == end_index then
    return
  end

  local next_positions = Layout.calculate_buffers_position_by_buffer_number()

  for _, layout_bufnr  in ipairs(Layout.buffers) do
    local current_data = state.get_buffer_data(layout_bufnr)

    local previous_position = previous_positions[layout_bufnr]
    local next_position     = next_positions[layout_bufnr]

    if next_position ~= previous_position then
      current_data.position = previous_positions[layout_bufnr]
    end
  end

  local move_animation_data = {
    previous_positions = previous_positions,
    next_positions = next_positions,
  }

  current_animation = animate.stop(current_animation)
  current_animation = animate.start(MOVE_DURATION, 0, 1, vim.v.t_float,
    function(ratio, current_state)
      for _, current_number in ipairs(Layout.buffers) do
        local current_data = state.get_buffer_data(current_number)

        if current_state.running == true then
          current_data.position = animate.lerp(
            ratio,
            (move_animation_data.previous_positions or {})[current_number],
            (move_animation_data.next_positions or {})[current_number]
          )
        else
          current_data.position = nil
        end
      end

      render.update()

      if current_state.running == false then
        move_animation_data.next_positions = nil
        move_animation_data.previous_positions = nil
      end
    end)
end


--- Toggle the `bufnr`'s "pin" state, visually.
--- @param buffer_number integer
--- @return nil
function render.toggle_pin(buffer_number)
  local previous_data_by_bufnr = vim.deepcopy(state.data_by_bufnr)

  state.toggle_pin(buffer_number)

  if config.options.animation == false then
    return render.update()
  end

  current_animation = animate.stop(current_animation)
  current_animation = animate.start(PIN_DURATION, 0, 1, vim.v.t_float,
    function (ratio, current_state)
      for _, current_number in ipairs(Layout.buffers) do
        local previous_data = state.get_buffer_data(current_number, previous_data_by_bufnr)
        local current_data  = state.get_buffer_data(current_number)

        local previous_width    = previous_data.width    or previous_data.computed_width
        local previous_padding  = previous_data.padding  or previous_data.computed_padding
        local previous_position = previous_data.position or previous_data.computed_position

        local next_width    = current_data.computed_width
        local next_padding  = current_data.computed_padding
        local next_position = current_data.computed_position

        if current_state.running == true then
          if previous_width and next_width then
            current_data.width = math.floor(animate.lerp(ratio, previous_width, next_width, vim.v.t_float))
          end
          if previous_padding and next_padding then
            current_data.padding = math.floor(animate.lerp(ratio, previous_padding, next_padding, vim.v.t_float))
          end
          if previous_position and next_position then
            current_data.position = math.ceil(animate.lerp(ratio, previous_position, next_position, vim.v.t_float))
          end
        else
          current_data.width = nil
          current_data.padding = nil
          current_data.position = nil
        end
      end

      render.update()
    end)
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
    SCROLL_DURATION, scroll.current, target, vim.v.t_number,
    set_scroll_tick)
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

--- Create valid `&tabline` syntax which highlights the next item in the tabline with the highlight `group` specified.
--- @param group string
--- @return string syntax
local function wrap_hl(group)
  return '%#' .. group .. '#'
end

--- Compute the buffer hl-groups
--- @param layout barbar.ui.layout.data
--- @param bufnrs integer[]
--- @param refocus? boolean
--- @return barbar.ui.container[] pinned_groups, barbar.ui.container[] clumps
local function get_bufferline_containers(layout, bufnrs, refocus)
  local click_enabled = has('tablineat') and config.options.clickable

  local accumulated_pinned_width = 0 --- the width of pinned buffers accumulated while iterating
  local accumulated_unpinned_width = 0 --- the width of buffers accumulated while iterating
  local current_buffer_index = nil --- @type nil|integer
  local done = false --- if all of the visible buffers have been clumped
  local containers = {} --- @type barbar.ui.container[]
  local pinned_containers = {} --- @type barbar.ui.container[]

  local pinned_pad_text   = (' '):rep(config.options.minimum_padding)
  local unpinned_pad_text = (' '):rep(layout.buffers.padding)

  for i, bufnr in ipairs(bufnrs) do
    local activity = Buffer.get_activity(bufnr)
    local activity_name = Buffer.activities[activity]
    local buffer_data = state.get_buffer_data(bufnr)
    local modified = buf_get_option(bufnr, 'modified')
    local pinned = buffer_data.pinned

    if pinned then
      buffer_data.computed_position = accumulated_pinned_width
      buffer_data.computed_padding  = config.options.minimum_padding
      buffer_data.computed_width    = Layout.calculate_width(layout.buffers.base_widths[i], buffer_data.computed_padding)
    else
      buffer_data.computed_position = accumulated_unpinned_width + layout.buffers.pinned_width
      buffer_data.computed_padding  = layout.buffers.padding
      buffer_data.computed_width    = Layout.calculate_width(layout.buffers.base_widths[i], buffer_data.computed_padding)
    end

    local container_width = buffer_data.width or buffer_data.computed_width

    if activity == Buffer.activities.Current and refocus ~= false then
      current_buffer_index = i

      local start = accumulated_unpinned_width
      local end_  = accumulated_unpinned_width + container_width

      if scroll.target > start then
        render.set_scroll(start)
      elseif scroll.target + layout.buffers.unpinned_allocated_width < end_ then
        render.set_scroll(scroll.target + (end_ - (scroll.target + layout.buffers.unpinned_allocated_width)))
      end
    end

    local scroll_current = min(scroll.current, layout.buffers.scroll_max)

    if pinned then
      accumulated_pinned_width = accumulated_pinned_width + container_width
    else
      accumulated_unpinned_width = accumulated_unpinned_width + container_width

      if accumulated_unpinned_width < scroll_current  then
        goto continue -- HACK: there is no `continue` keyword
      elseif (refocus == false or (refocus ~= false and current_buffer_index ~= nil)) and
        accumulated_unpinned_width - scroll_current > layout.buffers.unpinned_allocated_width
      then
        done = true
      end
    end

    local buffer_name = buffer_data.name or '[no name]'
    local buffer_hl = wrap_hl('Buffer' .. activity_name .. (modified and 'Mod' or ''))

    local icons_option = Buffer.get_icons(activity_name, modified, pinned)

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
      buffer_index.text = i .. ' '
    end

    --- The buffer number
    --- @type barbar.ui.node
    local buffer_number = { hl = '', text = '' }
    if icons_option.buffer_number then
      buffer_number.hl = wrap_hl('Buffer' .. activity_name .. 'Number')
      buffer_number.text = bufnr .. ' '
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
      local letter = JumpMode.get_letter(bufnr)

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
      local iconChar, iconHl = icons.get_icon(bufnr, activity_name)
      local hlName = (activity_name == 'Inactive' and not config.options.highlight_inactive_file_icons)
        and 'BufferInactive'
        or iconHl

      icon.hl = icons_option.filetype.custom_colors and
        wrap_hl('Buffer' .. activity_name .. 'Icon') or
        (hlName and wrap_hl(hlName) or buffer_hl)
      icon.text = #name.text > 0 and iconChar .. ' ' or iconChar
    end

    local hl_sign = wrap_hl('Buffer' .. activity_name .. 'Sign')

    --- @type barbar.ui.node
    local left_separator = { hl = clickable .. hl_sign, text = icons_option.separator.left }

    --- @type barbar.ui.node
    local padding = { hl = buffer_hl, text =
      buffer_data.padding and (' '):rep(buffer_data.padding) or
                   pinned and pinned_pad_text or
                              unpinned_pad_text }

    local container = { --- @type barbar.ui.container
      activity = activity,
      nodes = { left_separator, padding, buffer_index, buffer_number, icon, jump_letter, name },
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      position = buffer_data.position or buffer_data.computed_position,
      --- @diagnostic disable-next-line:assign-type-mismatch it is assigned just earlier
      width = container_width,
    }

    Buffer.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(count, idx, option)
      table_insert(container.nodes, {
        hl = wrap_hl('Buffer' .. activity_name .. severity[idx]),
        text = ' ' .. option.icon .. count,
      })
    end)

    --- @type barbar.ui.node
    local right_separator = { hl = left_separator.hl, text = icons_option.separator.right }

    list_extend(container.nodes, { padding, button, right_separator })
    if container_width then
      container.nodes = Nodes.slice_right(container.nodes, container_width)
    end

    table_insert(pinned and pinned_containers or containers, container)

    if done then
      break
    end

    ::continue::
  end

  return pinned_containers, containers
end

local HL = {
  FILL = wrap_hl('BufferTabpageFill'),
  TABPAGES = wrap_hl('BufferTabpages'),
  SIGN_INACTIVE = wrap_hl('BufferInactiveSign'),
  SCROLL_ARROW = wrap_hl('BufferScrollArrow'),
}

--- Generate the `&tabline` representing the current state of Neovim.
--- @param bufnrs integer[] the bufnrs to render
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @return nil|string syntax
local function generate_tabline(bufnrs, refocus)
  local layout = Layout.calculate()
  local pinned_containers, unpinned_containers = get_bufferline_containers(layout, bufnrs, refocus)

  -- Create actual tabline string
  local result = ''

  -- Left offset
  if state.offset.left.width > 0 then
    local hl = wrap_hl(state.offset.left.hl)
    local offset_nodes = { { hl = hl, text = (' '):rep(state.offset.left.width) } }

    local content = { { hl = hl, text = state.offset.left.text } }
    local content_max_width = state.offset.left.width - 2

    offset_nodes =
      Nodes.insert_many(
        offset_nodes,
        1,
        Nodes.slice_right(content, content_max_width))

    result = result .. Nodes.to_string(offset_nodes)
  end

  -- Buffer tabs
  do
    --- @type barbar.ui.container
    local content = { { hl = HL.FILL, text = (' '):rep(layout.buffers.width) } }

    local current_container = nil
    local max_used_position = 0

    if #pinned_containers > 0 then
      for _, container in ipairs(pinned_containers) do
        if container.activity ~= Buffer.activities.Current then
          content = Nodes.insert_many(content, container.position, container.nodes)
        else
          current_container = container
        end
      end
    end

    do
      for _, container in ipairs(unpinned_containers) do
        -- We insert the current buffer after the others so it's always on top
        if container.activity ~= Buffer.activities.Current then
          content = Nodes.insert_many(
            content,
            container.position - scroll.current,
            container.nodes)
          max_used_position = max(max_used_position, container.position + container.width)
        else
          current_container = container
        end
      end
    end

    if current_container ~= nil then
      local container = current_container
      content = Nodes.insert_many(content, container.position, container.nodes)
      max_used_position = max(max_used_position, container.position + container.width)
    end

    do
      local inactive_separator = config.options.icons.inactive.separator.left
      local max_actual_position = max_used_position - scroll.current
      local total_containers = #pinned_containers + #unpinned_containers
      if
        inactive_separator ~= nil and
        total_containers > 0 and
        max_actual_position + strwidth(inactive_separator) <= layout.buffers.width
      then
        content = Nodes.insert(
          content,
          max_actual_position,
          { text = inactive_separator, hl = HL.SIGN_INACTIVE })
      end
    end

    local filler = { { hl = HL.FILL, text = (' '):rep(layout.buffers.width) } }
    content = Nodes.insert_many(filler, 0, content)
    content = Nodes.slice_right(content, layout.buffers.width)

    local has_left_scroll = scroll.current > 0
    if has_left_scroll then
      content = Nodes.insert(content, layout.buffers.pinned_width,
        { hl = HL.SCROLL_ARROW, text = config.options.icons.scroll.left })
    end

    local has_right_scroll = layout.buffers.used_width - scroll.current > layout.buffers.width
    if has_right_scroll then
      content = Nodes.insert(content, layout.buffers.width - 1,
        { hl = HL.SCROLL_ARROW, text = config.options.icons.scroll.right })
    end

    -- Render bufferline string
    result = result .. Nodes.to_string(content)

    -- Prevent the expansion of the last click node
    if config.options.clickable then
      result = result .. '%0@barbar#events#main_click_handler@'
    end
  end

  -- Tabpages
  do
    if layout.tabpages.width > 0 then
      result = result .. Nodes.to_string({
        { hl = HL.TABPAGES, text = ' ' .. tabpagenr() .. '/' .. tabpagenr('$') .. ' ', },
      })
    end
  end

  -- Right offset
  if state.offset.right.width > 0 then
    local hl = wrap_hl(state.offset.right.hl)
    local offset_nodes = { { hl = hl, text = (' '):rep(state.offset.right.width) } }

    local content = { { hl = hl, text = state.offset.right.text } }
    local content_max_width = state.offset.right.width - 2

    offset_nodes =
      Nodes.insert_many(
        offset_nodes,
        1,
        Nodes.slice_right(content, content_max_width))

    result = result .. Nodes.to_string(offset_nodes)
  end

  -- NOTE: For development or debugging purposes, the following code can be used:
  -- local containers = { unpack(pinned_containers), unpack(unpinned_containers) }
  -- local data = vim.json.encode(containers)
  -- fs.write('barbar.debug.txt', result .. ':' .. data .. '\n', 'a')

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
