-- !::exe [luafile %]
--
-- render.lua
--

local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local utils = require'bufferline.utils'
local icons = require'bufferline.icons'
local state = require'bufferline.state'
local Buffer = require'bufferline.buffer'
local Layout = require'bufferline.layout'
local JumpMode = require'bufferline.jump_mode'
local get_icon = icons.get_icon
local len = utils.len
local slice = utils.slice
local strwidth = nvim.strwidth
local reverse = utils.reverse
local has = vim.fn.has
local bufnr = vim.fn.bufnr
local strcharpart = vim.fn.strcharpart
local getbufvar = vim.fn.getbufvar
local tabpagenr = vim.fn.tabpagenr


local HL_BY_ACTIVITY = {
  [0] = 'Inactive',
  [1] = 'Visible',
  [2] = 'Current',
}

local function hl(name)
   return '%#' .. name .. '#'
end

-- A "group" is an array with the format { HL_GROUP, TEXT_CONTENT }

local function groups_to_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    local hl   = group[1]
    local text = group[2]
    result = result .. hl .. text
  end

  return result
end

local function groups_to_raw_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    local text = group[2]
    result = result .. text
  end

  return result
end

local function groups_insert(groups, position, others)
  local current_position = 0

  local new_groups = {}

  local i = 1
  while i <= len(groups) do
    local group = groups[i]
    local group_width = strwidth(group[2])

    -- While we haven't found the position...
    if current_position + group_width <= position then
      table.insert(new_groups, group)
      i = i + 1
      current_position = current_position + group_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current group if it `position` is inside it
      if available_width > 0 then
        local new_group = { group[1], slice(group[2], 1, available_width) }
        table.insert(new_groups, new_group)
      end

      -- Add new other groups
      local others_width = 0
      for j, other in ipairs(others) do
        local other_width = strwidth(other[2])
        others_width = others_width + other_width
        table.insert(new_groups, other)
      end

      local end_position = position + others_width

      -- Then, resume adding previous groups
      -- table.insert(new_groups, 'then')
      while i <= len(groups) do
        local group = groups[i]
        local group_width = strwidth(group[2])
        local group_start_position = current_position
        local group_end_position   = current_position + group_width

        if group_end_position <= end_position and group_width ~= 0 then
          -- continue
        elseif group_start_position >= end_position then
          -- table.insert(new_groups, 'direct')
          table.insert(new_groups, group)
        else
          local remaining_width = group_end_position - end_position
          local start = group_width + 1 - remaining_width
          local end_  = group_width
          local new_group = { group[1], slice(group[2], start, end_) }
          -- table.insert(new_groups, { group_start_position, group_end_position, end_position })
          table.insert(new_groups, new_group)
        end

        i = i + 1
        current_position = current_position + group_width
      end

      break
    end
  end

  return new_groups
end

local function slice_groups_right(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for i, group in ipairs(groups) do
    local hl   = group[1]
    local text = group[2]
    local text_width = strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      local new_group = {hl, strcharpart(text, 0, diff)}
      table.insert(new_groups, new_group)
      break
    end

    table.insert(new_groups, group)
  end

  return new_groups
end

local function slice_groups_left(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for i, group in ipairs(reverse(groups)) do
    local hl   = group[1]
    local text = group[2]
    local text_width = strwidth(text)

    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      local new_group = {hl, strcharpart(text, start, length)}
      table.insert(new_groups, 1, new_group)
      break
    end

    table.insert(new_groups, 1, group)
  end

  return new_groups
end

-- Rendering

local function render(update_names)
  local opts = vim.g.bufferline
  local buffer_numbers = state.get_updated_buffers(update_names)

  if opts.auto_hide then
    if len(buffer_numbers) <= 1 then
      if vim.o.showtabline == 2 then
        vim.o.showtabline = 0
      end
      return
    end
    if vim.o.showtabline == 0 then
      vim.o.showtabline = 2
    end
  end

  local current = bufnr('%')

  -- Store current buffer to open new ones next to this one
  if nvim.buf_get_option(current, 'buflisted') then
    local ok, is_empty = pcall(api.nvim_buf_get_var, current, 'empty_buffer')
    if ok and is_empty then
      state.last_current_buffer = nil
    else
      state.last_current_buffer = current
    end
  end

  local click_enabled = has('tablineat') and opts.clickable
  local has_close = opts.closable
  local has_icons = (opts.icons == true) or (opts.icons == 'both')
  local has_icon_custom_colors = opts.icon_custom_colors
  local has_buffer_number = (opts.icons == 'buffer_numbers')
  local has_numbers = (opts.icons == 'numbers') or (opts.icons == 'both')

  local layout = Layout.calculate(state)

  local items = {}

  local current_buffer_index = nil
  local current_position = 0
  for i, buffer_number in ipairs(buffer_numbers) do

    local buffer_data = state.get_buffer_data(buffer_number)
    local buffer_name = buffer_data.name or '[no name]'

    buffer_data.real_width    = Layout.calculate_width(buffer_name, layout.base_width, layout.padding_width)
    buffer_data.real_position = current_position

    local activity = Buffer.get_activity(buffer_number)
    local is_inactive = activity == 0
    local is_visible = activity == 1
    local is_current = activity == 2
    local is_modified = nvim.buf_get_option(buffer_number, 'modified')
    local is_closing = buffer_data.closing
    local is_pinned = state.is_pinned(buffer_number)

    local status = HL_BY_ACTIVITY[activity]
    local mod = is_modified and 'Mod' or ''

    local separatorPrefix = hl('Buffer' .. status .. 'Sign')
    local separator = is_inactive and
      opts.icon_separator_inactive or
      opts.icon_separator_active

    local namePrefix = hl('Buffer' .. status .. mod)
    local name = buffer_name

    -- The buffer name
    local bufferIndexPrefix = ''
    local bufferIndex = ''

    -- The jump letter
    local jumpLetterPrefix = ''
    local jumpLetter = ''

    -- The devicon
    local iconPrefix = ''
    local icon = ''

    if has_buffer_number or has_numbers then
      local number_text =
        has_buffer_number and
          tostring(buffer_number) or
          tostring(i)

      bufferIndexPrefix = hl('Buffer' .. status .. 'Index')
      bufferIndex = number_text .. ' '
    end

    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(buffer_number)

      -- Replace first character of buf name with jump letter
      if letter and not has_icons then
        name = slice(name, 2)
      end

      jumpLetterPrefix = hl('Buffer' .. status .. 'Target')
      jumpLetter = (letter or '') ..
        (has_icons and (' ' .. (letter and '' or ' ')) or '')
    else

      if has_icons then
        local iconChar, iconHl = get_icon(buffer_name, getbufvar(buffer_number, '&filetype'), status)
        local hlName = is_inactive and 'BufferInactive' or iconHl
        iconPrefix = has_icon_custom_colors and hl('Buffer' .. status .. 'Icon') or hlName and hl(hlName) or namePrefix
        icon = iconChar .. ' '
      end
    end

    local closePrefix = ''
    local close = ''
    if has_close or is_pinned then
      local closeIcon =
        is_pinned and
          opts.icon_pinned or
        (not is_modified and
          opts.icon_close_tab or
          opts.icon_close_tab_modified)

      closePrefix = namePrefix
      close = closeIcon .. ' '

      if click_enabled then
        closePrefix =
            '%' .. buffer_number .. '@BufferlineCloseClickHandler@' .. closePrefix
      end
    end

    local clickable = ''
    if click_enabled then
      clickable = '%' .. buffer_number .. '@BufferlineMainClickHandler@'
    end

    local padding = string.rep(' ', layout.padding_width)

    local item = {
      is_current = is_current,
      width = buffer_data.width
        -- <padding> <base_widths[i]> <padding>
        or layout.base_widths[i] + (2 * layout.padding_width),
      position = buffer_data.position or buffer_data.real_position,
      groups = {
        {clickable,          ''},
        {separatorPrefix,    separator},
        {'',                 padding},
        {bufferIndexPrefix,  bufferIndex},
        {iconPrefix,         icon},
        {jumpLetterPrefix,   jumpLetter},
        {namePrefix,         name},
        {'',                 padding},
        {'',                 ' '},
        {closePrefix,        close},
      }
    }

    if is_current then
      current_buffer_index = i
      current_buffer_position = buffer_data.real_position

      local start = current_position
      local end_  = current_position + item.width

      if state.scroll > start then
        state.set_scroll(start)
      elseif state.scroll + layout.buffers_width < end_ then
        state.set_scroll(state.scroll + (end_ - (state.scroll + layout.buffers_width)))
      end
    end

    table.insert(items, item)
    current_position = current_position + item.width
  end

  -- Create actual tabline string
  local result = ''

  -- Add offset filler & text (for filetree/sidebar plugins)
  if state.offset and state.offset > 0 then
    local offset_available_width = state.offset - 2
    local groups = {
      {hl('BufferOffset'), ' '},
      {'',                 state.offset_text},
    }
    result = result .. groups_to_string(slice_groups_right(groups, offset_available_width))
    result = result .. string.rep(' ', offset_available_width - len(state.offset_text))
    result = result .. ' '
  end

  -- Add bufferline
  local bufferline_groups = {
    { hl('BufferTabpageFill'), string.rep(' ', layout.actual_width) }
  }

  for i, item in ipairs(items) do
    if i ~= current_buffer_index then
      bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
    end
  end
  if current_buffer_index ~= nil then
    local item = items[current_buffer_index]
    bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
  end

  -- Crop to scroll region
  local max_scroll = math.max(layout.actual_width - layout.buffers_width, 0)
  local scroll = math.min(state.scroll_current, max_scroll)
  local buffers_end = layout.actual_width - scroll

  if buffers_end > layout.buffers_width then
    bufferline_groups = slice_groups_right(bufferline_groups, scroll + layout.buffers_width)
  end
  if scroll > 0 then
    bufferline_groups = slice_groups_left(bufferline_groups, layout.buffers_width)
  end

  -- Render bufferline string
  result = result .. groups_to_string(bufferline_groups)

  -- To prevent the expansion of the last click group
  result = result .. '%0@BufferlineMainClickHandler@' .. hl('BufferTabpageFill')

  if layout.actual_width + strwidth(opts.icon_separator_inactive) <= layout.buffers_width and len(items) > 0 then
    result = result .. opts.icon_separator_inactive
  end

  local current_tabpage = tabpagenr()
  local total_tabpages  = tabpagenr('$')
  if layout.tabpages_width > 0 then
    result = result .. '%=%#BufferTabpages# ' .. tostring(current_tabpage) .. '/' .. tostring(total_tabpages) .. ' '
  end

  result = result .. hl('BufferTabpageFill')

  return result
end

local function render_safe(update_names)
  local ok, result = xpcall(render, debug.traceback, update_names)
  return {ok, tostring(result)}
end

-- print(render(state.buffers))

local exports = {
  render = render,
  render_safe = render_safe,
}

return exports
