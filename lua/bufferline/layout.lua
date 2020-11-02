-- !::exe [luafile %]
--
-- layout.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local len = utils.len

local function calculate_used_width(state, base_width)
  local sum = 0

  -- local sum += bufferline#tabpages#width()

  for i, buffer_number in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    if buffer_data.closing then
      sum = sum + buffer_data.dimensions[1]
    else
      sum = sum + base_width + len(buffer_name)
    end
  end

  return sum
end

local function calculate(state)
  local opts = vim.g.bufferline

  -- separator + icon + space-after-icon + space-after-name
  local base_width =
    1
    + (opts.icons and 2 or 0)
    + (opts.closable and 2 or 0)

  local available_width = vim.o.columns

  local used_width = calculate_used_width(state, base_width)
  -- local used_width = 100

  local buffers_length               = len(state.buffers)
  local remaining_width              = available_width - used_width
  local remaining_width_per_buffer   = math.floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = math.floor(remaining_width_per_buffer / 2)
  local padding_width                = math.min(remaining_padding_per_buffer, opts.maximum_padding) - 1
  local actual_width                 = used_width + padding_width * buffers_length

  return {
    available_width = available_width,
    base_width = base_width,
    padding_width = padding_width,
    actual_width = actual_width,
  }
end

local function calculate_dimensions(buffer_name, base_width, padding_width)
  return { len(buffer_name), base_width + padding_width * 2 }
end

local exports = {
  calculate = calculate,
  calculate_used_width = calculate_used_width,
  calculate_dimensions = calculate_dimensions,
}

return exports
