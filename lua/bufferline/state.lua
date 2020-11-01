--
-- m.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local fun = require'bufferline.fun'
local len = fun.operator.len
local range = fun.range
local utils = require'bufferline.utils'
local reverse = utils.reverse
local index = fun.index
local filter = vim.tbl_filter
local includes = vim.tbl_contains
local bufname = vim.fn.bufname

-- buffer_data {
--   closing = false,
-- }

local m = {
  is_picking_buffer = false,
  buffers = {},
  buffers_by_id = {},
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

  vim.fn['bufferline#animate#start'](150, current_width, 0, vim.v.t_number,
    function(new_width, m)
      close_buffer_animated_tick(buffer_number, new_width, m)
    end)
end


-- Update state

function m.update_names()
  local buffer_index_by_name = {}

  -- Compute names
  for i, buffer_n in ipairs(m.buffers) do
    local name = utils.get_buffer_name(buffer_n)

    if buffer_index_by_name[name] == nil then
      buffer_index_by_name[name] = i
      m.get_buffer_data(buffer_n).name = name
    else
      local other_i = buffer_index_by_name[name]
      local other_n = m.buffers[other_i]
      -- print(vim.inspect({ i, other_i, name, buffer_index_by_name[name] }))
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

function m.get_updated_buffers()
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

    -- Open next to the currently opened tab
    -- Find the new index where the tab will be inserted
    local new_index = index(m.last_current_buffer, m.buffers)
    if new_index ~= nil then
        new_index = new_index + 1
    else
        new_index = len(m.buffers) + 1
    end

    for i, new_buffer in ipairs(reverse(new_buffers)) do
        if index(new_buffer, m.buffers) == nil then
          -- For special buffers, we add them at the end
          if vim.fn.getbufvar(new_buffer, '&buftype') ~= '' then
            new_index = len(m.buffers) + 1
          end
          table.insert(m.buffers, new_index, new_buffer)
        end
    end
  end

  m.buffers =
    filter(function(b) return nvim.buf_is_valid(b) end, m.buffers)

  if did_change then
    m.update_names()
  end

  return m.buffers
end


-- Movement & tab manipulation

local function move_current_buffer (direction)
  m.get_updated_buffers()

  local currentnr = nvim.get_current_buf()
  local idx = index(currentnr, m.buffers)

  if idx == 1 and direction == -1 then
    return
  end
  if idx == len(m.buffers) and direction == 1 then
    return
  end

  local othernr = m.buffers[idx + direction]

  m.buffers[idx] = othernr
  m.buffers[idx + direction] = currentnr

  vim.fn['bufferline#update']()
end

local function goto_buffer (number)
  m.get_updated_buffers()

  local idx
  if number == -1 then
    idx = len(m.buffers)
  else
    idx = number
  end

  nvim.command('silent buffer ' .. m.buffers[idx])
end

local function goto_buffer_relative (direction)
  m.get_updated_buffers()

  local currentnr = vim.fn.bufnr('%')
  local idx = index(currentnr, m.buffers)

  if idx == 1 and direction == -1 then
      idx = len(m.buffers)
  elseif idx == len(m.buffers) and direction == 1 then
      idx = 1
  else
      idx = idx + direction
  end

  nvim.command('silent buffer ' .. m.buffers[idx])
end


-- Exports

m.move_current_buffer = move_current_buffer
m.goto_buffer = goto_buffer
m.goto_buffer_relative = goto_buffer_relative

return m
