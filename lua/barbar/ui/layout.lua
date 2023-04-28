--
-- layout.lua
--

local floor = math.floor
local max = math.max
local min = math.min
local table_insert = table.insert

local buf_get_option = vim.api.nvim_buf_get_option --- @type function
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

--- @class barbar.ui.layout.data
--- @field total_width integer the total width of the tabline, equals to &columns
--- @field left barbar.ui.layout.data.side left offset data
--- @field right barbar.ui.layout.data.side right offset data
--- @field buffers barbar.ui.layout.data.buffers buffer data
--- @field tabpages barbar.ui.layout.data.tabpages tabpage data

--- @class barbar.ui.layout.data.side
--- @field width integer the amount of space allocated

--- @class barbar.ui.layout.data.buffers
--- @field width integer the amount of space allocated to the buffers
--- @field pinned_width integer the amount of space used by pinned buffers
--- @field unpinned_width integer the amount of space used by pinned buffers
--- @field unpinned_allocated_width integer the amount of space allocated to unpinned buffers
--- @field used_width integer the amount of space used by buffers
--- @field padding integer the amount of padding used on each side of each buffer
--- @field base_widths integer[] the minimum amount of space taken up by each buffer
--- @field scroll_max integer the maximum position which can be scrolled to

--- @class barbar.ui.layout.data.tabpages
--- @field width integer the amount of space allocated to the tabpage indicator


--- @class barbar.ui.layout
--- @field buffers integer[] different from `state.buffers` in that the `hide` option is respected. Only updated when calling `calculate_buffers_width`.
local Layout = { buffers = {} }

--- Calculate the current layout of the bufferline.
--- @return barbar.ui.layout.data
function Layout.calculate()

  local total_width = get_option('columns')

  local left_width  = state.offset.left.width
  local right_width = state.offset.right.width
  local tabpages_width = Layout.calculate_tabpages_width()
  local buffers_width = total_width - state.offset.left.width - state.offset.right.width - tabpages_width

  local pinned_count, pinned_sum, unpinned_sum, widths = Layout.calculate_buffers_width()
  local pinned_width = pinned_sum + (pinned_count * config.options.minimum_padding * SIDES_OF_BUFFER)

  local unpinned_allocated_width = buffers_width - pinned_width
  local unpinned_count = #widths - pinned_count

  local remaining_width = max(0, unpinned_allocated_width - unpinned_sum)
  local remaining_width_per_buffer = floor(remaining_width / unpinned_count)
  local remaining_padding_per_buffer = floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding = max(config.options.minimum_padding, min(remaining_padding_per_buffer, config.options.maximum_padding))

  local unpinned_width = unpinned_sum + (unpinned_count * padding * SIDES_OF_BUFFER)

  local buffers_used_width = pinned_width + unpinned_width

  local result = {
    total_width = total_width,

    left = {
      width = left_width,
    },

    buffers = {
      width = buffers_width,
      pinned_width = pinned_width,
      unpinned_width = unpinned_width,
      unpinned_allocated_width = unpinned_allocated_width,
      used_width = buffers_used_width,
      padding = padding,
      base_widths = widths,
      scroll_max = max(0, unpinned_width - unpinned_allocated_width),
    },

    tabpages = {
      width = tabpages_width,
    },

    right = {
      width = right_width,
    },
  }

  return result
end

--- @param bufnr integer the buffer to calculate the width of
--- @param index integer the buffer's numerical index
--- @return integer width
function Layout.calculate_buffer_width(bufnr, index)
  local buffer_data = state.get_buffer_data(bufnr)
  if buffer_data.closing then
    return buffer_data.width or buffer_data.computed_width or 0
  end

  local buffer_activity = Buffer.activities[Buffer.get_activity(bufnr)]
  local buffer_name = buffer_data.name or '[no name]'

  local icons_option = Buffer.get_icons(buffer_activity, buf_get_option(bufnr, 'modified'), buffer_data.pinned)

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

  Buffer.for_each_enabled_git_status(bufnr, icons_option.gitsigns, function(count, _, option)
    width = width + SPACE_LEN + strwidth(option.icon) + #tostring(count)
  end)

  local button = icons_option.button
  if button and #button > 0 then
    width = width + strwidth(button) + SPACE_LEN
  end

  return width + strwidth(icons_option.separator.right)
end

--- @return {[integer]: integer} position_by_bufnr
function Layout.calculate_buffers_position_by_buffer_number()
  local layout = Layout.calculate()
  local positions = {}

  local pinned_position = 0
  local unpinned_position = layout.buffers.pinned_width

  for i, buffer_number in ipairs(Layout.buffers) do
    if state.is_pinned(buffer_number) then
      positions[buffer_number] = pinned_position
      pinned_position = pinned_position + Layout.calculate_width(
        layout.buffers.base_widths[i],
        config.options.minimum_padding
      )
    else
      positions[buffer_number] = unpinned_position
      unpinned_position = unpinned_position + Layout.calculate_width(
        layout.buffers.base_widths[i],
        layout.buffers.padding
      )
    end
  end

  return positions
end

--- Calculate the width of the buffers
--- @return integer pinned_count, integer pinned_sum, integer unpinned_sum, integer[] widths
function Layout.calculate_buffers_width()
  Layout.buffers = Buffer.hide(state.buffers)

  local pinned_count = 0
  local pinned_sum = 0
  local unpinned_sum = 0
  local widths = {}

  for i, bufnr in ipairs(Layout.buffers) do
    local width = Layout.calculate_buffer_width(bufnr, i)
    if state.is_pinned(bufnr) then
      pinned_count = pinned_count + 1
      pinned_sum = pinned_sum + width
    else
      unpinned_sum = unpinned_sum + width
    end

    table_insert(widths, width)
  end

  return pinned_count, pinned_sum, unpinned_sum, widths
end

--- The number of characters needed to represent the tabpages.
--- @return integer width
function Layout.calculate_tabpages_width()
  if not config.options.tabpages then
    return 0
  end

  local total_tabpages = tabpagenr('$')
  if total_tabpages == 1 then
    return 0
  end

  return SPACE_LEN + #tostring(tabpagenr()) + SLASH_LEN + #tostring(total_tabpages) + SPACE_LEN
end

--- Determines what the width of a buffer would be with its padding
--- @param base_width integer
--- @param padding_width integer
--- @return integer width
function Layout.calculate_width(base_width, padding_width)
  return base_width + (padding_width * SIDES_OF_BUFFER)
end

return Layout
