--
-- state.lua
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

-- buffer_data {
--   closing = false,
-- }

local state = {
  is_picking_buffer = false,
  buffers = {},
  buffers_by_id = {},
}

local function new_buffer_data()
  return {
    name = nil,
    width = nil,
    closing = false,
    dimensions = nil,
  }
end


local function get_buffer_data(id)
  local data = state.buffers_by_id[id]

  if data ~= nil then
    return data
  end

  state.buffers_by_id[id] = new_buffer_data()

  return state.buffers_by_id[id]
end


local function close_buffer(buffer_number)
  state.buffers = filter(function(b) return b ~= buffer_number end, state.buffers)
  state.buffers_by_id[buffer_number] = nil
  vim.fn['bufferline#update']()
end

local function close_buffer_animated_tick(buffer_number, new_width, animation)
  if new_width > 0 and state.buffers_by_id[buffer_number] ~= nil then
    local buffer_data = get_buffer_data(buffer_number)
    buffer_data.width = new_width
    vim.fn['bufferline#update']()
    return
  end
  vim.fn['bufferline#animate#stop'](animation)
  close_buffer(buffer_number)
end

local function close_buffer_animated(buffer_number)
  if vim.g.bufferline.animation == false then
    return close_buffer(buffer_number)
  end
  local buffer_data = get_buffer_data(buffer_number)
  local current_width =
    buffer_data.dimensions[1] +
    buffer_data.dimensions[2]

  buffer_data.closing = true
  buffer_data.width = current_width

  vim.fn['bufferline#animate#start'](150, current_width, 0, vim.v.t_number,
    function(new_width, state)
      close_buffer_animated_tick(buffer_number, new_width, state)
    end)
end


function get_updated_buffers()
  local current_buffers = vim.fn['bufferline#filter']('&buflisted')
  local new_buffers =
    filter(
      function(b) return not includes(state.buffers, b) end,
      current_buffers)

  -- Remove closed or update closing buffers
  local closed_buffers =
    filter(function(b) return not includes(current_buffers, b) end, state.buffers)

  for i, buffer_number in ipairs(closed_buffers) do
    local buffer_data = get_buffer_data(buffer_number)
    if not buffer_data.closing then
      if buffer_data.dimensions == nil then
        close_buffer(buffer_number)
      else
        close_buffer_animated(buffer_number)
      end
    end
  end

  -- Add new buffers
  if len(new_buffers) > 0 then

    -- Open next to the currently opened tab
    local last_buffer = state.last_current_buffer
    -- Hack: some file openers (vim-clap) switch very fast to buffers
    --       that aren't considered the current buffer when opening a
    --       file. This gets use the file we want.
    if state.last_current_time ~= nil then
      local modified_since = vim.fn.reltimefloat(vim.fn.reltime(state.last_current_time))
      local was_modified_recently = modified_since < 1
      if was_modified_recently then
        last_buffer = state.previous_current_buffer
      end
    end

    local new_index = index(last_buffer, state.buffers)
    -- print(new_index, 'newIndex before')
    if new_index ~= nil then
        new_index = new_index + 1
    else
        new_index = len(state.buffers) + 1
    end
    -- print(new_index, 'newIndex after')
    for i, new_buffer in ipairs(reverse(new_buffers)) do
        if index(new_buffer, state.buffers) == nil then
          if vim.fn.getbufvar(new_buffer, '&buftype') ~= '' then
            new_index = len(state.buffers) + 1
          end
          -- print(new_index, 'newIndex')
          table.insert(state.buffers, new_index, new_buffer)
        end
    end
  end

  state.buffers =
    filter(function(b) return nvim.buf_is_valid(b) end, state.buffers)

  return state.buffers
end


-- Movement & tab manipulation

local function move_current_buffer (direction)
  get_updated_buffers()

  local currentnr = nvim.get_current_buf()
  local idx = index(currentnr, state.buffers)

  if idx == 1 and direction == -1 then
    return
  end
  if idx == len(state.buffers) and direction == 1 then
    return
  end

  local othernr = state.buffers[idx + direction]

  state.buffers[idx] = othernr
  state.buffers[idx + direction] = currentnr

  vim.fn['bufferline#update']()
end

local function goto_buffer (number)
  get_updated_buffers()

  local idx
  if number == -1 then
    idx = len(state.buffers)
  else
    idx = number
  end

  nvim.command('silent buffer ' .. state.buffers[idx])
end

local function goto_buffer_relative (direction)
  get_updated_buffers()

  local currentnr = vim.fn.bufnr('%')
  local idx = index(currentnr, state.buffers)

  if idx == 1 and direction == -1 then
      idx = len(state.buffers)
  elseif idx == len(state.buffers) and direction == 1 then
      idx = 1
  else
      idx = idx + direction
  end

  nvim.command('silent buffer ' .. state.buffers[idx])
end


-- Exports

state.get_buffer_data = get_buffer_data
state.get_updated_buffers = get_updated_buffers

state.move_current_buffer = move_current_buffer
state.goto_buffer = goto_buffer
state.goto_buffer_relative = goto_buffer_relative

return state
