-- !::exe [luafile %]
--
-- render.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local web = require'nvim-web-devicons'
local utils = require'bufferline.utils'
local len = utils.len
local state = require'bufferline.state'
local Buffer = require'bufferline.buffer'
local JumpMode = require'bufferline.jump_mode'

local HL_BY_ACTIVITY = {
  [0] = 'Inactive',
  [1] = 'Visible',
  [2] = 'Current',
}

local function hl(name)
   return '%#' .. name .. '#'
end

function get_icon(buffer_name, filetype)
  local basename
  local extension

  if filetype == 'fugitive' or filetype == 'gitcommit' then
    basename = 'git'
    extension = 'git'
  else
    basename = vim.fn.fnamemodify(buffer_name, ':t')
    extension = vim.fn.matchstr(basename, [[\v\.@<=\w+$]], '', '')
  end

  return web.get_icon(basename, extension, { default = true })
end


local function calculate_used_width(buffer_numbers, base_width)
  local sum = 0

  -- local sum += bufferline#tabpages#width()

  for i, buffer_number in ipairs(buffer_numbers) do
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

local function calculate_layout(buffer_numbers)
  local opts = vim.g.bufferline

  -- separator + icon + space-after-icon + space-after-name
  local base_width =
    1
    + (opts.icons and 2 or 0)
    + (opts.closable and 2 or 0)

  local available_width = vim.o.columns

  local used_width = calculate_used_width(buffer_numbers, base_width)
  -- local used_width = 100

  local buffers_length               = len(buffer_numbers)
  local remaining_width              = available_width - used_width
  local remaining_width_per_buffer   = math.floor(remaining_width / buffers_length)
  local remaining_padding_per_buffer = math.floor(remaining_width_per_buffer / 2)
  local padding_width                = math.min(remaining_padding_per_buffer, opts.maximum_padding) - 1
  local actual_width                 = used_width + padding_width * buffers_length

  return { available_width, base_width, padding_width, actual_width }
end

local function render()
  local buffer_numbers = state.get_updated_buffers()
  local current = vim.fn.bufnr('%')

  -- Store current buffer to open new ones next to this one
  if nvim.buf_get_option(current, 'buflisted') then
    state.last_current_buffer = current
  end

  local opts = vim.g.bufferline
  local icons = vim.g.icons

  local click_enabled = vim.fn.has('tablineat') and opts.clickable
  local has_icons = opts.icons
  local has_close = opts.closable

  local layout = calculate_layout(buffer_numbers)
  local available_width = layout[1]
  local base_width      = layout[2]
  local padding_width   = layout[3]
  local actual_width    = layout[4]

  local result = ''

  for i, buffer_number in ipairs(buffer_numbers) do

    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    buffer_data.dimensions = {
      len(buffer_name),
      base_width + 2 * padding_width,
    }

    local activity = Buffer.get_activity(buffer_number)
    local is_visible = activity == 1
    local is_current = activity == 2
    -- local is_inactive = activity == 0
    local is_modified = nvim.buf_get_option(buffer_number, 'modified')
    local is_closing = buffer_data.closing

    local status = HL_BY_ACTIVITY[activity]
    local mod = is_modified and 'Mod' or ''

    local separatorPrefix = hl('Buffer' .. status .. 'Sign')
    local separator = status == 'Inactive' and
      icons.bufferline_separator_inactive or
      icons.bufferline_separator_active

    local namePrefix = hl('Buffer' .. status .. mod)
    local name =
      (not has_icons and state.is_picking_buffer) and
        slice(buffer_name, 1) or
        buffer_name

    local iconPrefix = ''
    local icon = ''
    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(buffer_number)
      iconPrefix = hl('Buffer' .. status .. 'Target')
      icon =
        (letter ~= nil and letter or ' ') ..
        (has_icons and ' ' or '')
    elseif has_icons then
      local iconChar, iconHl = get_icon(buffer_name, vim.fn.getbufvar(buffer_number, '&filetype'))
      iconPrefix = status == 'Inactive' and hl('BufferInactive') or hl(iconHl)
      icon = iconChar .. ' '
    end

    local closePrefix = ''
    local close = ''
    if has_close then
      local icon =
        (not is_modified and
          icons.bufferline_close_tab or
          icons.bufferline_close_tab_modified)

      closePrefix = namePrefix
      close = icon .. ' '

      if click_enabled then
        closePrefix = 
            '%' .. buffer_number .. '@BufferlineCloseClickHandler@' .. closePrefix
      end
    end

    local clickable = ''
    if click_enabled then
      clickable = '%' .. buffer_number .. '@BufferlineMainClickHandler@'
    end

    local padding = string.rep(' ', padding_width)

    local item = ''
    if not is_closing then
      item =
        clickable ..
        separatorPrefix .. separator ..
        padding ..
        iconPrefix .. icon ..
        namePrefix .. name ..
        padding ..
        ' ' ..
        closePrefix .. close ..
        ''
    else
      local width = buffer_data.width
      local text = 
        separator ..
        padding ..
        icon ..
        name ..
        padding ..
        ' ' ..
        close
      text = vim.fn.strcharpart(text, 0, width)
      item = namePrefix ..  text
    end

    result = result .. item
  end

  if actual_width < available_width then
    local separatorPrefix = hl('BufferInactiveSign')
    local separator = icons.bufferline_separator_inactive
    result = result .. separatorPrefix .. separator
  end

  result = result .. hl('TabLineFill')

  return result
end

-- print()
-- print(render(vim.g['bufferline#'].buffers))

local exports = {
  render = render,
  calculate_layout = calculate_layout,
}

return exports
