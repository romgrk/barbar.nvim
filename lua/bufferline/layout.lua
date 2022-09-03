--
-- layout.lua
--

local floor = math.floor
local max = math.max
local min = math.min
local table_insert = table.insert

local buf_get_option = vim.api.nvim_buf_get_option
local strwidth = vim.api.nvim_strwidth
local tabpagenr = vim.fn.tabpagenr

--- @type bufferline.buffer
local Buffer = require'bufferline.buffer'

--- @type bufferline.state
local state = require'bufferline.state'

--- The number of sides of each buffer in the tabline.
local SIDES_OF_BUFFER = 2

--- @class bufferline.layout.data
--- @field actual_width integer
--- @field available_width integer
--- @field base_width integer
--- @field base_widths integer
--- @field buffers_width integer
--- @field padding_width integer
--- @field tabpages_width integer
--- @field used_width integer

--- @class bufferline.Layout
local Layout = {}

function Layout.calculate_tabpages_width()
  local current = tabpagenr()
  local total   = tabpagenr('$')
  if not vim.g.bufferline.tabpages or total == 1 then
    return 0
  end
  return 1 + strwidth(tostring(current)) + 1 + strwidth(tostring(total)) + 1
end

--- @param base_width integer
function Layout.calculate_buffers_width(base_width)
  local opts = vim.g.bufferline
  local has_numbers = opts.icons == 'both' or opts.icons == 'numbers'

  local sum = 0
  local widths = {}

  for i, buffer_number in ipairs(state.buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    local width
    if buffer_data.closing then
      width = buffer_data.real_width
    else
      width = base_width
        + strwidth(Buffer.get_activity(buffer_number) > 1 -- separator
            and opts.icon_separator_active
            or opts.icon_separator_inactive)
        + strwidth(buffer_name) -- name

      if has_numbers then
        width = width
          + #tostring(i) -- buffer-index
          + 1 -- space-after-buffer-index
      end

      local is_pinned = state.is_pinned(buffer_number)

      if opts.closable or is_pinned then
        local is_modified = buf_get_option(buffer_number, 'modified')
        local icon = is_pinned and opts.icon_pinned or
          (not is_modified -- close-icon
            and opts.icon_close_tab
             or opts.icon_close_tab_modified)

        width = width
          + strwidth(icon)
          + 1 -- space-after-close-icon
      end
    end
    sum = sum + width
    table_insert(widths, width)
  end

  return sum, widths
end

--- Calculate the current layout of the bufferline.
--- @return bufferline.layout.data
function Layout.calculate()
  local opts = vim.g.bufferline

  local has_icons = (opts.icons == true) or (opts.icons == 'both') or (opts.icons == 'buffer_number_with_icon')

  -- [icon + space-after-icon] + space-after-name
  local base_width =
    (has_icons and (1 + 1) or 0) -- icon + space-after-icon
    + 1 -- space-after-name

  local available_width = vim.o.columns
  available_width = available_width - state.offset.width

  local used_width, base_widths = Layout.calculate_buffers_width(base_width)
  local tabpages_width = Layout.calculate_tabpages_width()

  local buffers_width = available_width - tabpages_width

  local buffers_length               = #state.buffers
  local remaining_width              = max(buffers_width - used_width, 0)
  local remaining_width_per_buffer   = floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = floor(remaining_width_per_buffer / SIDES_OF_BUFFER)
  local padding_width                = min(remaining_padding_per_buffer, opts.maximum_padding)
  local actual_width                 = used_width + (buffers_length * padding_width * SIDES_OF_BUFFER)

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

--- @return {[integer]: integer} position_by_bufnr
function Layout.calculate_buffers_position_by_buffer_number()
  local current_position = 0
  local layout = Layout.calculate()
  local positions = {}

  for i, buffer_number in ipairs(state.buffers) do
    positions[buffer_number] = current_position
    local width = layout.base_widths[i] + (2 * layout.padding_width)
    current_position = current_position + width
  end

  return positions
end

--- @param buffer_name string
--- @param base_width integer
--- @param padding_width integer
--- @return integer width
function Layout.calculate_width(buffer_name, base_width, padding_width)
  return strwidth(buffer_name) + base_width + padding_width * SIDES_OF_BUFFER
end

return Layout
