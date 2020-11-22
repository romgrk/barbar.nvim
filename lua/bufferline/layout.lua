-- !::exe [luafile %]
--
-- layout.lua
--

local vim = vim
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local len = utils.len

local SIDES_OF_BUFFER = 2

local function calculate_tabpages_width()
  local current = vim.fn.tabpagenr()
  local total   = vim.fn.tabpagenr('$')
  if not vim.g.bufferline.tabpages or total == 1 then
    return 0
  end
  return 1 + len(tostring(current)) + 1 + len(tostring(total)) + 1
end

local function calculate_buffers_width(state, base_width)
  local Buffer = require'bufferline.buffer'
  local opts = vim.g.bufferline
  local sum = 0
  local widths = {}

  for i, buffer_number in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    local width
    if buffer_data.closing then
      width = buffer_data.dimensions[1] + buffer_data.dimensions[2]
    else
      width = base_width
        + len(Buffer.get_activity(buffer_number) > 0 -- separator
            and opts.icon_separator_active
            or opts.icon_separator_inactive)
        + len(buffer_name) -- name

      if opts.icons == 'both' or opts.icons == 'numbers' then
        width = width
          + len(tostring(i)) -- buffer-index
          + 1 -- space-after-buffer-index
      end

      if opts.closable then
        width = width
          + len(not nvim.buf_get_option(buffer_number, 'modified') -- close-icon
              and opts.icon_close_tab
              or opts.icon_close_tab_modified)
          + 1 -- space-after-close-icon
      end
    end
    sum = sum + width
    table.insert(widths, width)
  end

  return sum, widths
end

local function calculate(state)
  local opts = vim.g.bufferline

  local has_icons = (opts.icons == true) or (opts.icons == 'both')
  local has_numbers = (opts.icons == 'numbers') or (opts.icons == 'both')

  -- separator [+ space-before-icon] [+ icon + space-after-icon] + name + space-after-name
  local base_width =
    (has_numbers and 0 or 1) -- space-before-icon
    + (has_icons and (1 + 1) or 0) -- icon + space-after-icon
        -- name
    + 1 -- space-after-name

  local available_width = vim.o.columns

  local used_width, base_widths = calculate_buffers_width(state, base_width)
  local tabpages_width = calculate_tabpages_width()

  local buffers_width = available_width - tabpages_width

  local buffers_length               = len(state.buffers)
  local remaining_width              = math.max(buffers_width - used_width, 0)
  local remaining_width_per_buffer   = math.floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = math.floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding_width                = math.min(remaining_padding_per_buffer, opts.maximum_padding)
  local actual_width                 = used_width + (padding_width * buffers_length * SIDES_OF_BUFFER)

  return {
    actual_width = actual_width,
    available_width = available_width,
    base_width = base_width,
    base_widths = base_widths,
    buffers_width = buffers_width,
    padding_width = padding_width,
    tabpages_width = tabpages_width,
    used_width = used_width,
  }
end

local function calculate_dimensions(buffer_name, base_width, padding_width)
  return { len(buffer_name), base_width + padding_width * SIDES_OF_BUFFER }
end

local exports = {
  calculate = calculate,
  calculate_buffers_width = calculate_buffers_width,
  calculate_dimensions = calculate_dimensions,
}

return exports
