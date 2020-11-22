-- !::exe [luafile %]
--
-- layout.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local len = utils.len

local function calculate_tabpages_width(state)
  local current = vim.fn.tabpagenr()
  local total   = vim.fn.tabpagenr('$')
  if not vim.g.bufferline.tabpages or total == 1 then
    return 0
  end
  return 1 + #tostring(current) + 1 + #tostring(total) + 1
end

local function calculate_buffers_width(state, base_width)
  local sum = 0

  local widths = {}

  for i, buffer_number in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    local width
    if buffer_data.closing then
      width = buffer_data.dimensions[1] + buffer_data.dimensions[2]
    else
      width = base_width + len(buffer_name)
    end
    sum = sum + width
    table.insert(widths, width)
  end

  return sum, widths
end

local function calculate(state)
  local opts = vim.g.bufferline

  -- separator + icon + space-after-icon + space-after-name
  local base_width =
      1 -- sign
    + (opts.icons and 2 or 0)
        -- name
    + 1 -- space after name
    + (opts.closable and 2 or 0)

  local available_width = vim.o.columns

  local used_width, base_widths = calculate_buffers_width(state, base_width)
  local tabpages_width = calculate_tabpages_width(state)

  local buffers_width = available_width - tabpages_width

  local buffers_length               = len(state.buffers)
  local remaining_width              = math.max(buffers_width - used_width, 0)
  local remaining_width_per_buffer   = math.floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = math.floor(remaining_width_per_buffer / 2)
  local padding_width                = math.min(remaining_padding_per_buffer, opts.maximum_padding)
  local actual_width                 = used_width + padding_width * buffers_length


  return {
    available_width = available_width,
    buffers_width = buffers_width,
    tabpages_width = tabpages_width,
    used_width = used_width,
    base_width = base_width,
    padding_width = padding_width,
    actual_width = actual_width,
    base_widths = base_widths,
  }
end

local function calculate_dimensions(buffer_name, base_width, padding_width)
  return { len(buffer_name), base_width + padding_width * 2 }
end

local exports = {
  calculate = calculate,
  calculate_buffers_width = calculate_buffers_width,
  calculate_dimensions = calculate_dimensions,
}

return exports
