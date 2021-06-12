--
-- m.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local Layout = require'bufferline.layout'
local len = utils.len
local index = utils.index
local reverse = utils.reverse
local filter = vim.tbl_filter
local includes = vim.tbl_contains
local bufname = vim.fn.bufname
local fnamemodify = vim.fn.fnamemodify


local ANIMATION_OPEN_DURATION  = 150
local ANIMATION_OPEN_DELAY     =  50
local ANIMATION_CLOSE_DURATION = 100
local ANIMATION_SCROLL_DURATION = 200

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
    closing = false,
    dimensions = nil,
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


-- Scrolling

local scroll_animation = nil

local function set_scroll_tick(new_scroll, animation)
  m.scroll_current = new_scroll
  if animation.running == false then
    scroll_animation = nil
  end
  vim.fn['bufferline#update']()
end

local function set_scroll(target)
  m.scroll = target

  if scroll_animation ~= nil then
    vim.fn['bufferline#animate#stop'](scroll_animation)
  end

  scroll_animation = vim.fn['bufferline#animate#start'](
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
  vim.fn['bufferline#update']()
end

local function open_buffer_start_animation(layout, buffer_number)
  local buffer_data = m.get_buffer_data(buffer_number)
  buffer_data.dimensions = Layout.calculate_dimensions(
    buffer_data.name, layout.base_width, layout.padding_width)

  local target_width =
    buffer_data.dimensions[1] +
    buffer_data.dimensions[2]

  buffer_data.width = 1

  vim.fn.timer_start(ANIMATION_OPEN_DELAY, function()
    vim.fn['bufferline#animate#start'](
      ANIMATION_OPEN_DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(buffer_number, new_width, animation)
      end)
  end)
end

local function open_buffers(new_buffers)
  local initial_buffers = len(m.buffers)

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = utils.index(m.buffers, m.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = len(m.buffers) + 1
  end

  -- Insert the buffers where they go
  for i, new_buffer in ipairs(new_buffers) do
    if utils.index(m.buffers, new_buffer) == nil then
      local actual_index = new_index
      -- For special buffers, we add them at the end
      if vim.fn.getbufvar(new_buffer, '&buftype') ~= '' then
        actual_index = len(m.buffers) + 1
      else
        new_index = new_index + 1
      end
      table.insert(m.buffers, actual_index, new_buffer)
    end
  end

  -- We're done if there is no animations
  if vim.g.bufferline.animation == false then
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

-- Close & cleanup buffers

local function close_buffer(buffer_number, should_update_names)
  m.buffers = filter(function(b) return b ~= buffer_number end, m.buffers)
  m.buffers_by_id[buffer_number] = nil
  if should_update_names then
    m.update_names()
  end
  vim.fn['bufferline#update']()
end

local function close_buffer_animated_tick(buffer_number, new_width, animation)
  if new_width > 0 and m.buffers_by_id[buffer_number] ~= nil then
    local buffer_data = m.get_buffer_data(buffer_number)
    buffer_data.width = new_width
    vim.fn['bufferline#update']()
    return
  end
  vim.fn['bufferline#animate#stop'](animation)
  close_buffer(buffer_number, true)
end

local function close_buffer_animated(buffer_number)
  if vim.g.bufferline.animation == false then
    return close_buffer(buffer_number)
  end
  local buffer_data = m.get_buffer_data(buffer_number)
  local current_width =
    buffer_data.dimensions[1] +
    buffer_data.dimensions[2]

  buffer_data.closing = true
  buffer_data.width = current_width

  vim.fn['bufferline#animate#start'](
    ANIMATION_CLOSE_DURATION, current_width, 0, vim.v.t_number,
    function(new_width, m)
      close_buffer_animated_tick(buffer_number, new_width, m)
    end)
end


-- Update state

function m.update_names()
  local opts = vim.g.bufferline
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(m.buffers) do
    local name = utils.get_buffer_name(opts, buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      m.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = m.buffers[other_i]
      local new_name, new_other_name =
        utils.get_unique_name(
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
  local current_buffers = vim.fn['bufferline#filter']('&buflisted')
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

      if buffer_data.dimensions == nil then
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
      vim.fn['bufferline#update']()
  end
end

-- Movement & tab manipulation

local function move_current_buffer (steps)
  m.get_updated_buffers()

  local currentnr = nvim.get_current_buf()
  local idx = utils.index(m.buffers, currentnr)

  local newidx = math.max(1, math.min(len(m.buffers), idx + steps))
  if idx == newidx then
    return
  end

  table.remove(m.buffers, idx)
  table.insert(m.buffers, newidx, currentnr)

  vim.fn['bufferline#update']()
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

  local current = vim.fn.bufnr('%')
  local current_win = nvim.get_current_win()
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
    for i, win in ipairs(wins) do
      current = nvim.win_get_buf(win)
      is_listed = nvim.buf_get_option(current, 'buflisted')
      if is_listed then
        nvim.set_current_win(win)
        break
      end
    end
  end

  local idx = utils.index(m.buffers, current)

  if idx == nil then
    print("Couldn't find buffer " .. current .. " in the list: " .. vim.inspect(m.buffers))
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
  vim.fn['bufferline#update']()
end

local function close_buffers_left()
  local idx = index(m.buffers, nvim.get_current_buf()) - 1
  if idx == nil then
    return
  end
  for i = idx, 1, -1 do
    vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(m.buffers[i]))
  end
  vim.fn['bufferline#update']()
end

local function close_buffers_right()
  local idx = index(m.buffers, nvim.get_current_buf()) + 1
  if idx == nil then
    return
  end
  for i = idx, len(m.buffers) do
    vim.fn['bufferline#bbye#delete']('bdelete', '', bufname(m.buffers[i]))
  end
  vim.fn['bufferline#update']()
end


-- Ordering

local function is_relative_path(path)
   return fnamemodify(path, ':p') ~= path
end

local function order_by_directory()
  table.sort(m.buffers, function(a, b)
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
  vim.fn['bufferline#update']()
end

local function order_by_language()
  table.sort(m.buffers, function(a, b)
    local na = fnamemodify(bufname(a), ':e')
    local nb = fnamemodify(bufname(b), ':e')
    return na < nb
  end)
  vim.fn['bufferline#update']()
end


-- Exports

m.set_scroll = set_scroll
m.set_offset = set_offset

m.close_buffer = close_buffer
m.close_buffer_animated = close_buffer_animated
m.close_all_but_current = close_all_but_current
m.close_buffers_right = close_buffers_right
m.close_buffers_left = close_buffers_left

m.move_current_buffer = move_current_buffer
m.goto_buffer = goto_buffer
m.goto_buffer_relative = goto_buffer_relative

m.order_by_directory = order_by_directory
m.order_by_language = order_by_language

return m
