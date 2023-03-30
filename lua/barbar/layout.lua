--
-- layout.lua
--

local floor = math.floor
local max = math.max
local min = math.min
local rshift = bit.rshift
local table_insert = table.insert

local get_option = vim.api.nvim_get_option --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function
local tabpagenr = vim.fn.tabpagenr --- @type function

local Buffer = require'barbar.buffer'
local config = require'barbar.config'
local icons = require'barbar.icons'
local state = require'barbar.state'

--- The number of sides of each buffer in the tabline.
local SIDES_OF_BUFFER = 2

--- @class barbar.layout.data
--- @field actual_width integer
--- @field available_width integer
--- @field base_widths integer[]
--- @field buffers_width integer
--- @field padding_width integer
--- @field tabpages_width integer
--- @field used_width integer

--- @class barbar.Layout
--- @field buffers integer[] different from `state.buffers` in that the `hide` option is respected. Only updated when calling `calculate_buffers_width`.
local Layout = {buffers = {}}

--- The number of characters needed to represent the tabpages.
--- @return integer width
function Layout.calculate_tabpages_width()
  local current = tabpagenr()
  local total   = tabpagenr('$')
  if not config.options.tabpages or total == 1 then
    return 0
  end
  return 1 + tostring(current):len() + 1 + tostring(total):len() + 1
end

--- @param bufnr integer the buffer to calculate the width of
--- @param index integer the buffer's numerical index
--- @return integer width
function Layout.calculate_buffer_width(bufnr, index)
  local buffer_data = state.get_buffer_data(bufnr)
  local buffer_name = buffer_data.name or '[no name]'
  local width

  if buffer_data.closing then
    width = buffer_data.real_width
  else
    local icons_option = state.icons(bufnr, Buffer.activities[Buffer.get_activity(bufnr)])

    width = strwidth(icons_option.separator.left) + strwidth(buffer_name) -- separator + name

    if icons_option.buffer_index then
      width = width + #tostring(index) + 1 -- buffer-index + space after buffer-index
    elseif icons_option.buffer_number then
      width = width + #tostring(bufnr) + 1 -- buffer-number + space after buffer-index
    end

    if icons_option.filetype.enabled then
      --- @diagnostic disable-next-line:param-type-mismatch
      local file_icon = icons.get_icon(bufnr, '')
      width = width + strwidth(file_icon) + 1 -- icon + space after icon
    end

    Buffer.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(c, d, _)
      width = width + 1 + strwidth(d.icon) + #tostring(c) -- space before icon + icon + diagnostic count
    end)

    -- close-or-pin-or-save-icon + the space after + right separator
    width = width + strwidth(icons_option.button or '') + 1 + strwidth(icons_option.separator.right)
  end

  return width or 0
end

--- Calculate the width of the buffers
--- @return integer sum, integer[] widths
function Layout.calculate_buffers_width()
  Layout.buffers = Buffer.hide(state.buffers)

  local sum = 0
  local widths = {}

  for i, bufnr in ipairs(Layout.buffers) do
    local width = Layout.calculate_buffer_width(bufnr, i)
    sum = sum + width
    table_insert(widths, width)
  end

  return sum, widths
end

--- Calculate the current layout of the bufferline.
--- @return barbar.layout.data
function Layout.calculate()
  local available_width = get_option'columns'
  available_width = available_width - state.offset.left.width - state.offset.right.width

  local used_width, base_widths = Layout.calculate_buffers_width()
  local tabpages_width = Layout.calculate_tabpages_width()

  local buffers_width = available_width - tabpages_width

  local remaining_width = max(buffers_width - used_width, 0)
  local remaining_width_per_buffer = floor(remaining_width / #base_widths)
  -- PERF: faster than `floor(remaining_width_per_buffer / SIDES_OF_BUFFER)`.
  --       if `SIDES_OF_BUFFER` changes, this will have to go back to `floor`.
  local remaining_padding_per_buffer = rshift(remaining_width_per_buffer, 1)
  local padding_width = max(config.options.minimum_padding, min(remaining_padding_per_buffer, config.options.maximum_padding))
  local actual_width = used_width + (#base_widths * padding_width * SIDES_OF_BUFFER)

  return {
    actual_width = actual_width,
    available_width = available_width,
    base_widths = base_widths,
    buffers_width = buffers_width,
    padding_width = padding_width,
    tabpages_width = tabpages_width,
    used_width = used_width,
  }
end

--- @return {[integer]: integer} position_by_bufnr
function Layout.calculate_buffers_position_by_buffer_number()
  local current_position = 0
  local layout = Layout.calculate()
  local positions = {}

  for i, buffer_number in ipairs(Layout.buffers) do
    positions[buffer_number] = current_position
    local width = layout.base_widths[i] + (2 * layout.padding_width)
    current_position = current_position + width
  end

  return positions
end

--- @param base_width integer
--- @param padding_width integer
--- @return integer width
function Layout.calculate_width(base_width, padding_width)
  return base_width + (padding_width * SIDES_OF_BUFFER)
end

return Layout
