--
-- m.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local Buffer = require'bufferline.buffer'
local Layout = require'bufferline.layout'
local animate = require'bufferline.animate'
local len = utils.len
local is_nil = utils.is_nil
local index_of = utils.index_of
local reverse = utils.reverse
local filter = vim.tbl_filter
local includes = vim.tbl_contains
local bufname = vim.fn.bufname
local bufwinnr = vim.fn.bufwinnr
local fnamemodify = vim.fn.fnamemodify


local PIN = 'bufferline_pin'

local ANIMATION_OPEN_DURATION   = 150
local ANIMATION_OPEN_DELAY      = 50
local ANIMATION_CLOSE_DURATION  = 150
local ANIMATION_SCROLL_DURATION = 200
local ANIMATION_MOVE_DURATION   = 150

--------------------------------
-- Section: Application state --
--------------------------------

local m = {
  is_picking_buffer = false,
  scroll = 0,
  scroll_current = 0,
  buffers = {},
  buffers_by_id = {},
  offset = 0,
  offset_text = '',
}

function m.new_buffer_data()
  return {
    name = nil,
    width = nil,
    position = nil,
    closing = false,
    real_width = nil,
  }
end

function m.get_buffer_data(id)
  local data = m.buffers_by_id[id]

  if data ~= nil then
    return data
  end

  m.buffers_by_id[id] = m.new_buffer_data()

  return m.buffers_by_id[id]
end

function m.update()
  vim.fn['bufferline#update']()
end


-- Pinned buffers

local function is_pinned(bufnr)
  local ok, val = pcall(vim.api.nvim_buf_get_var, bufnr, PIN)
  return ok and val
end

local function sort_pins_to_left()
  local pinned = {}
  local unpinned = {}
  for _, bufnr in ipairs(m.buffers) do
    if is_pinned(bufnr) then
      table.insert(pinned, bufnr)
    else
      table.insert(unpinned, bufnr)
    end
  end
  m.buffers = vim.list_extend(pinned, unpinned)
end

local function toggle_pin(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_set_var(bufnr, PIN, not is_pinned(bufnr))
  sort_pins_to_left()
  m.update()
end

-- Scrolling

local scroll_animation = nil

local function set_scroll_tick(new_scroll, animation)
  m.scroll_current = new_scroll
  if animation.running == false then
    scroll_animation = nil
  end
  m.update()
end

local function set_scroll(target)
  m.scroll = target

  if scroll_animation ~= nil then
    animate.stop(scroll_animation)
  end

  scroll_animation = animate.start(
    ANIMATION_SCROLL_DURATION, m.scroll_current, target, vim.v.t_number,
    set_scroll_tick)
end


-- Open buffers

local function open_buffer_animated_tick(buffer_number, new_width, animation)
  local buffer_data = m.get_buffer_data(buffer_number)
  if animation.running then
    buffer_data.width = new_width
  else
    buffer_data.width = nil
  end
  m.update()
end

local function open_buffer_start_animation(layout, buffer_number)
  local buffer_data = m.get_buffer_data(buffer_number)
  buffer_data.real_width = Layout.calculate_width(
    buffer_data.name, layout.base_width, layout.padding_width)

  local target_width = buffer_data.real_width

  buffer_data.width = 1

  vim.fn.timer_start(ANIMATION_OPEN_DELAY, function()
    animate.start(
      ANIMATION_OPEN_DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(buffer_number, new_width, animation)
      end)
  end)
end

local function open_buffers(new_buffers)
  local opts = vim.g.bufferline
  local initial_buffers = len(m.buffers)

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = index_of(m.buffers, m.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = len(m.buffers) + 1
  end

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do

    if index_of(m.buffers, new_buffer) == nil then
      local actual_index = new_index

      local should_insert_at_start = opts.insert_at_start
      local should_insert_at_end =
        opts.insert_at_end or
        -- We add special buffers at the end
        vim.fn.getbufvar(new_buffer, '&buftype') ~= ''

      if should_insert_at_start then
        actual_index = 1
        new_index = new_index + 1
      elseif should_insert_at_end then
        actual_index = len(m.buffers) + 1
      else
        new_index = new_index + 1
      end

      table.insert(m.buffers, actual_index, new_buffer)
    end
  end

  sort_pins_to_left()

  -- We're done if there is no animations
  if opts.animation == false then
    return
  end

  -- Case: opening a lot of buffers from a session
  -- We avoid animating here as well as it's a bit
  -- too much work otherwise.
  if initial_buffers <= 1 and len(new_buffers) > 1 or
     initial_buffers == 0 and len(new_buffers) == 1
  then
    return
  end

  -- Update names because they affect the layout
  m.update_names()

  local layout = Layout.calculate(m)

  for i, buffer_number in ipairs(new_buffers) do
    open_buffer_start_animation(layout, buffer_number)
  end
end

local function set_current_win_listed_buffer()
  local current = vim.fn.bufnr('%')
  local is_listed = nvim.buf_get_option(current, 'buflisted')

  -- Check previous window first
  if not is_listed then
    nvim.command('wincmd p')
    current = vim.fn.bufnr('%')
    is_listed = nvim.buf_get_option(current, 'buflisted')
  end
  -- Check all windows now
  if not is_listed then
    local wins = nvim.list_wins()
    for _, win in ipairs(wins) do
      current = nvim.win_get_buf(win)
      is_listed = nvim.buf_get_option(current, 'buflisted')
      if is_listed then
        nvim.set_current_win(win)
        break
      end
    end
  end

  return current
end

local function open_buffer_in_listed_window(buffer_number)
  set_current_win_listed_buffer()

  nvim.command('buffer ' .. buffer_number)
end

-- Close & cleanup buffers

local function close_buffer(buffer_number, should_update_names)
  m.buffers = filter(function(b) return b ~= buffer_number end, m.buffers)
  m.buffers_by_id[buffer_number] = nil
  if should_update_names then
    m.update_names()
  end
  m.update()
end

local function close_buffer_animated_tick(buffer_number, new_width, animation)
  if new_width > 0 and m.buffers_by_id[buffer_number] ~= nil then
    local buffer_data = m.get_buffer_data(buffer_number)
    buffer_data.width = new_width
    m.update()
    return
  end
  animate.stop(animation)
  close_buffer(buffer_number, true)
end

local function close_buffer_animated(buffer_number)
  if vim.g.bufferline.animation == false then
    return close_buffer(buffer_number)
  end
  local buffer_data = m.get_buffer_data(buffer_number)
  local current_width = buffer_data.real_width

  buffer_data.closing = true
  buffer_data.width = current_width

  animate.start(
    ANIMATION_CLOSE_DURATION, current_width, 0, vim.v.t_number,
    function(new_width, m)
      close_buffer_animated_tick(buffer_number, new_width, m)
    end)
end


-- Update state

local function get_buffer_list()
  local opts = vim.g.bufferline
  local buffers = nvim.list_bufs()
  local result = {}

  local exclude_ft   = opts.exclude_ft
  local exclude_name = opts.exclude_name

  for i, buffer in ipairs(buffers) do

    if not nvim.buf_get_option(buffer, 'buflisted') then
      goto continue
    end

    if not is_nil(exclude_ft) then
      local ft = nvim.buf_get_option(buffer, 'filetype')
      if utils.has(exclude_ft, ft) then
        goto continue
      end
    end

    if not is_nil(exclude_name) then
      local fullname = nvim.buf_get_name(buffer)
      local name = utils.basename(fullname)
      if utils.has(exclude_name, name) then
        goto continue
      end
    end

    table.insert(result, buffer)

    ::continue::
  end

  return result
end

function m.update_names()
  local opts = vim.g.bufferline
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(m.buffers) do
    local name = Buffer.get_name(opts, buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      m.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = m.buffers[other_i]
      local new_name, new_other_name =
        Buffer.get_unique_name(
          bufname(buffer_n),
          bufname(m.buffers[other_i]))

      m.get_buffer_data(buffer_n).name = new_name
      m.get_buffer_data(other_n).name = new_other_name
      buffer_index_by_name[new_name] = i
      buffer_index_by_name[new_other_name] = other_i
      buffer_index_by_name[name] = nil
    end

  end
end

function m.get_updated_buffers(update_names)
  local current_buffers = get_buffer_list()
  local new_buffers =
    filter(
      function(b) return not includes(m.buffers, b) end,
      current_buffers)

  -- To know if we need to update names
  local did_change = false

  -- Remove closed or update closing buffers
  local closed_buffers =
    filter(function(b) return not includes(current_buffers, b) end, m.buffers)

  for i, buffer_number in ipairs(closed_buffers) do
    local buffer_data = m.get_buffer_data(buffer_number)
    if not buffer_data.closing then
      did_change = true

      if buffer_data.real_width == nil then
        close_buffer(buffer_number)
      else
        close_buffer_animated(buffer_number)
      end
    end
  end

  -- Add new buffers
  if len(new_buffers) > 0 then
    did_change = true

    open_buffers(new_buffers)
  end

  m.buffers =
    filter(function(b) return nvim.buf_is_valid(b) end, m.buffers)

  if did_change or update_names then
    m.update_names()
  end

  return m.buffers
end

local function set_offset(offset, offset_text)
  local offset_number = tonumber(offset)
  if offset_number then
      m.offset = offset_number
      m.offset_text = offset_text or ''
      m.update()
  end
end


-- Movement & tab manipulation

local move_animation = nil
local move_animation_data = nil

local function move_buffer_animated_tick(ratio, current_animation)
  local data = move_animation_data

  for i, current_number in ipairs(m.buffers) do
    local current_data = m.get_buffer_data(current_number)

    if current_animation.running == true then
      current_data.position = animate.lerp(
        ratio,
        data.previous_positions[current_number],
        data.next_positions[current_number]
      )
    else
      current_data.position = nil
      current_data.moving = false
    end
  end

  m.update()

  if current_animation.running == false then
    move_animation = nil
    move_animation_data = nil
  end
end

local function move_buffer_animated(from_idx, to_idx)
  local buffer_number = m.buffers[from_idx]

  local layout

  layout = Layout.calculate(m)
  local previous_positions = Layout.calculate_buffers_position_by_buffer_number(m, layout)

  table.remove(m.buffers, from_idx)
  table.insert(m.buffers, to_idx, buffer_number)

  sort_pins_to_left()

  local current_index = index_of(m.buffers, buffer_number)

  local start_index = math.min(from_idx, current_index)
  local end_index   = math.max(from_idx, current_index)

  if start_index == end_index then return end

  if move_animation ~= nil then
    animate.stop(move_animation)
  end

  layout = Layout.calculate(m)
  local next_positions = Layout.calculate_buffers_position_by_buffer_number(m, layout)

  for i, _ in ipairs(m.buffers) do
    local current_number = m.buffers[i]
    local current_data = m.get_buffer_data(current_number)

    local previous_position = previous_positions[current_number]
    local next_position     = next_positions[current_number]

    if next_position ~= previous_position then
      current_data.position = previous_positions[current_number]
      current_data.moving = true
    end
  end

  move_animation_data = {
    previous_positions = previous_positions,
    next_positions = next_positions,
  }
  move_animation =
    animate.start(ANIMATION_MOVE_DURATION, 0, 1, vim.v.t_float,
      function(ratio, current_animation) move_buffer_animated_tick(ratio, current_animation) end)

  m.update()
end

local function move_buffer_direct(from_idx, to_idx)
  local buffer_number = m.buffers[from_idx]
  table.remove(m.buffers, from_idx)
  table.insert(m.buffers, to_idx, buffer_number)
  sort_pins_to_left()

  m.update()
end

local function move_buffer(from_idx, to_idx)
  to_idx = math.max(1, math.min(len(m.buffers), to_idx))
  if to_idx == from_idx then
    return
  end

  if vim.g.bufferline.animation == false then
    move_buffer_direct(from_idx, to_idx)
  else
    move_buffer_animated(from_idx, to_idx)
  end
end

local function move_current_buffer_to(number)
  number = tonumber(number)
  m.get_updated_buffers()
  if number == -1 then
    number = len(m.buffers)
  end

  local currentnr = nvim.get_current_buf()
  local idx = index_of(m.buffers, currentnr)
  move_buffer(idx, number)
end

local function move_current_buffer (steps)
  m.get_updated_buffers()

  local currentnr = nvim.get_current_buf()
  local idx = index_of(m.buffers, currentnr)

  move_buffer(idx, idx + steps)
end

local function goto_buffer (number)
  m.get_updated_buffers()

  number = tonumber(number)

  local idx
  if number == -1 then
    idx = len(m.buffers)
  elseif number > len(m.buffers) then
    return
  else
    idx = number
  end

  nvim.command('buffer ' .. m.buffers[idx])
end

local function goto_buffer_relative(steps)
  m.get_updated_buffers()

  local current = set_current_win_listed_buffer()

  local idx = index_of(m.buffers, current)

  if idx == nil then
    print('Couldn\'t find buffer ' .. current .. ' in the list: ' .. vim.inspect(m.buffers))
    return
  else
    idx = (idx + steps - 1) % len(m.buffers) + 1
  end

  nvim.command('buffer ' .. m.buffers[idx])
end


-- Close commands

local function close_all_but_current()
  local current = nvim.get_current_buf()
  local buffers = m.buffers
  for i, number in ipairs(buffers) do
    if number ~= current then
      vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(number))
    end
  end
  m.update()
end

local function close_all_but_pinned()
  local buffers = m.buffers
  for i, number in ipairs(buffers) do
    if not is_pinned(number) then
      vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(number))
    end
  end
  m.update()
end

local function close_buffers_left()
  local idx = index_of(m.buffers, nvim.get_current_buf()) - 1
  if idx == nil then
    return
  end
  for i = idx, 1, -1 do
    vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(m.buffers[i]))
  end
  m.update()
end

local function close_buffers_right()
  local idx = index_of(m.buffers, nvim.get_current_buf()) + 1
  if idx == nil then
    return
  end
  for i = idx, len(m.buffers) do
    vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(m.buffers[i]))
  end
  m.update()
end


-- Ordering

local function with_pin_order(order_func)
  return function(a, b)
    local a_pinned = is_pinned(a)
    local b_pinned = is_pinned(b)
    if a_pinned and not b_pinned then
      return true
    elseif b_pinned and not a_pinned then
      return false
    else
      return order_func(a, b)
    end
  end
end

local function is_relative_path(path)
   return fnamemodify(path, ':p') ~= path
end

local function order_by_buffer_number()
  table.sort(m.buffers, function(a, b)
    return a < b
  end)
  m.update()
end

local function order_by_directory()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = bufname(a)
      local nb = bufname(b)
      local ra = is_relative_path(na)
      local rb = is_relative_path(nb)
      if ra and not rb then
        return true
      end
      if not ra and rb then
        return false
      end
      return na < nb
    end)
  )
  m.update()
end

local function order_by_language()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = fnamemodify(bufname(a), ':e')
      local nb = fnamemodify(bufname(b), ':e')
      return na < nb
    end)
  )
  m.update()
end

local function order_by_window_number()
  table.sort(
    m.buffers,
    with_pin_order(function(a, b)
      local na = bufwinnr(bufname(a))
      local nb = bufwinnr(bufname(b))
      return na < nb
    end)
  )
  m.update()
end

-- vim-session integration

local function on_pre_save()
  -- We're allowed to use relative paths for buffers iff there are no tabpages
  -- or windows with a local directory (:tcd and :lcd)
  local use_relative_file_paths = true
  for tabnr,tabpage in ipairs(vim.api.nvim_list_tabpages()) do
    if not use_relative_file_paths or vim.fn.haslocaldir(-1, tabnr) == 1 then
      use_relative_file_paths = false
      break
    end
    for _,win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
      if vim.fn.haslocaldir(win, tabnr) == 1 then
        use_relative_file_paths = false
        break
      end
    end
  end

  local bufnames = {}
  for _,bufnr in ipairs(m.buffers) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if use_relative_file_paths then
      name = vim.fn.fnamemodify(name, ':~:.')
    end
    -- escape quotes
    name = string.gsub(name, '"', '\\"')
    table.insert(bufnames, string.format('"%s"', name))
  end
  local bufarr = string.format('{%s}', table.concat(bufnames, ','))
  local commands = vim.g.session_save_commands
  table.insert(commands, '" barbar.nvim')
  table.insert(commands,
    string.format([[lua require'bufferline.state'.restore_buffers(%s)]], bufarr))
  vim.g.session_save_commands = commands
end

local function restore_buffers(bufnames)
  -- Close all empty buffers. Loading a session may call :tabnew several times
  -- and create useless empty buffers.
  for _,bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.bufname(bufnr) == ''
      and vim.api.nvim_buf_get_option(bufnr, 'buftype') == ''
      and vim.api.nvim_buf_line_count(bufnr) == 1
      and vim.api.nvim_buf_get_lines(bufnr, 0, 1, true)[1] == '' then
        vim.api.nvim_buf_delete(bufnr, {})
    end
  end

  m.buffers = {}
  for _,name in ipairs(bufnames) do
    local bufnr = vim.fn.bufadd(name)
    table.insert(m.buffers, bufnr)
  end
  m.update()
end

-- Exports

m.set_scroll = set_scroll
m.set_offset = set_offset

m.open_buffer_in_listed_window = open_buffer_in_listed_window

m.close_buffer = close_buffer
m.close_buffer_animated = close_buffer_animated
m.close_all_but_current = close_all_but_current
m.close_all_but_pinned = close_all_but_pinned
m.close_buffers_right = close_buffers_right
m.close_buffers_left = close_buffers_left

m.is_pinned = is_pinned
m.move_current_buffer_to = move_current_buffer_to
m.move_current_buffer = move_current_buffer
m.goto_buffer = goto_buffer
m.goto_buffer_relative = goto_buffer_relative

m.toggle_pin = toggle_pin
m.order_by_buffer_number = order_by_buffer_number
m.order_by_directory = order_by_directory
m.order_by_language = order_by_language
m.order_by_window_number = order_by_window_number

m.on_pre_save = on_pre_save
m.restore_buffers = restore_buffers

return m
