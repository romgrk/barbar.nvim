--
-- layout.lua
--

local floor = math.floor
local max = math.max
local min = math.min
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

--- The length of a slash (`#'/'`)
local SLASH_LEN = #'/'

--- The length of one space (`#' '`)
local SPACE_LEN = #' '

--- @class barbar.layout.data
--- @field actual_width integer the `used_width` plus the `padding_width` allocated to each buffer
--- @field base_widths integer[] the minimum amount of space taken up by each buffer
--- @field buffers_width integer the amount of space available to be taken up by buffers
--- @field padding_width integer the amount of padding used on each side of each buffer
--- @field tabpages_width integer the amount of space taken up by the tabpage indicator
--- @field scroll_max integer the maximum position which can be scrolled to
--- @field used_width integer the sum of the `base_widths`

--- @class barbar.Layout
--- @field buffers integer[] different from `state.buffers` in that the `hide` option is respected. Only updated when calling `calculate_buffers_width`.
local Layout = { buffers = {} }

--- Calculate the current layout of the bufferline.
--- @return barbar.layout.data
function Layout.calculate()
  local available_width = get_option'columns'
  available_width = available_width - state.offset.left.width - state.offset.right.width

  local used_width, base_widths = Layout.calculate_buffers_width()
  local tabpages_width = Layout.calculate_tabpages_width()

  local buffers_width = available_width - tabpages_width
  local remaining_width = max(0, buffers_width - used_width)
  local remaining_width_per_buffer = floor(remaining_width / #base_widths)
  local remaining_padding_per_buffer = floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding_width = max(config.options.minimum_padding, min(remaining_padding_per_buffer, config.options.maximum_padding))
  local actual_width = used_width + (#base_widths * padding_width * SIDES_OF_BUFFER)

  return {
    actual_width = actual_width,
    base_widths = base_widths,
    buffers_width = buffers_width,
    padding_width = padding_width,
    scroll_max = max(0, actual_width - buffers_width),
    tabpages_width = tabpages_width,
    used_width = used_width,
  }
end

--- @param bufnr integer the buffer to calculate the width of
--- @param index integer the buffer's numerical index
--- @return integer width
function Layout.calculate_buffer_width(bufnr, index)
  local buffer_activity = Buffer.activities[Buffer.get_activity(bufnr)]
  local buffer_data = state.get_buffer_data(bufnr)
  local buffer_name = buffer_data.name or '[no name]'

  local icons_option = state.icons(bufnr, buffer_activity)

  local width = strwidth(icons_option.separator.left)

  local filename_enabled = icons_option.filename
  if filename_enabled then
    width = width + strwidth(buffer_name)
  end

  if icons_option.buffer_index then
    width = width + #tostring(index) + SPACE_LEN
  end

  if icons_option.buffer_number then
    width = width + #tostring(bufnr) + SPACE_LEN
  end

  if icons_option.filetype.enabled then
    local file_icon = icons.get_icon(bufnr, buffer_activity)
    width = width + strwidth(file_icon)

    if filename_enabled then
      width = width + SPACE_LEN
    end
  end

  Buffer.for_each_counted_enabled_diagnostic(bufnr, icons_option.diagnostics, function(count, _, option)
    width = width + SPACE_LEN + strwidth(option.icon) + #tostring(count)
  end)

  local button = icons_option.button
  if button then
    width = width + strwidth(button) + SPACE_LEN
  end

  return width + strwidth(icons_option.separator.right)
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

--- The number of characters needed to represent the tabpages.
--- @return integer width
function Layout.calculate_tabpages_width()
  if not config.options.tabpages then
    return 0
  end

  local total_tabpages = tabpagenr('$')
  return total_tabpages > 1 and
    SPACE_LEN + #tostring(tabpagenr()) + SLASH_LEN + #tostring(total_tabpages) + SPACE_LEN or
    0
end

--- Determines what the width of a buffer would be with its padding
--- @param base_width integer
--- @param padding_width integer
--- @return integer width
function Layout.calculate_width(base_width, padding_width)
  return base_width + (padding_width * SIDES_OF_BUFFER)
end

return Layout
