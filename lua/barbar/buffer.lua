--
-- buffer.lua
--

local rshift = bit.rshift
local table_concat = table.concat

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
local bufnr = vim.fn.bufnr --- @type function
local bufwinnr = vim.fn.bufwinnr --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local map = vim.tbl_map
local matchlist = vim.fn.matchlist --- @type function
local split = vim.split
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function

local config = require('barbar.config')
local list = require('barbar.utils.list')
local add_reverse_lookup = require('barbar.utils.table').add_reverse_lookup

local ELLIPSIS = '…'
local ELLIPSIS_LEN = strwidth(ELLIPSIS)

--- @alias barbar.buffer.activity 1|2|3|4

--- @alias barbar.buffer.activity.name 'Inactive'|'Alternate'|'Visible'|'Current'

--- A bidirectional map of activities to activity names
--- @type {[barbar.buffer.activity]: barbar.buffer.activity.name, [barbar.buffer.activity.name]: barbar.buffer.activity}
local activities = add_reverse_lookup {'Inactive', 'Alternate', 'Visible', 'Current'}

--- The character used to delimit paths (e.g. `/` or `\`).
local separator = package.config:sub(1, 1)

--- @param name string
--- @return string
local function terminalname(name)
  local result = matchlist(name, [[term://.\{-}//\d\+:\(.*\)]])
  if next(result) == nil then
    return name
  else
    return result[2]
  end
end

--- @class barbar.Buffer
local buffer = { activities = activities }

--- @param buffer_number integer
--- @return barbar.buffer.activity # whether `bufnr` is inactive, the alternate file, visible, or currently selected (in that order).
function buffer.get_activity(buffer_number)
  if get_current_buf() == buffer_number then
    return activities.Current
  elseif config.options.highlight_alternate and bufnr('#') == buffer_number then
    return activities.Alternate
  elseif config.options.highlight_visible and bufwinnr(buffer_number) ~= -1 then
    return activities.Visible
  end

  return activities.Inactive
end

--- @param activity barbar.buffer.activity.name
--- @param modified boolean
--- @param pinned boolean
--- @return barbar.config.options.icons.buffer
function buffer.get_icons(activity, modified, pinned)
  local icons_option = config.options.icons[activity:lower()]
  if pinned then
    icons_option = icons_option.pinned
  elseif modified then
    icons_option = icons_option.modified
  end

  return icons_option
end

--- @param buffer_number integer
--- @param depth integer
--- @return string name
function buffer.get_name(buffer_number, depth)
  --- @type string
  local name = buf_is_valid(buffer_number) and buf_get_name(buffer_number) or ''

  local no_name_title = config.options.no_name_title
  local hide_extensions = config.options.hide.extensions

  if name ~= '' then
    local full_name = buf_get_option(buffer_number, 'buftype') == 'terminal' and
      terminalname(name) or (hide_extensions and fnamemodify(name, ':t') or name)
    local parts = split(full_name, separator)
    name = table_concat(list.slice_from_end(parts, depth), separator)
  elseif no_name_title ~= nil and no_name_title ~= vim.NIL then
    name = no_name_title
  end

  if name == '' then
    name = '[buffer ' .. buffer_number .. ']'
  end

  return name
end

--- @param name string
--- @return string name
function buffer.format_name(name)
  local maximum_length = config.options.maximum_length
  local minimum_length = config.options.minimum_length

  local name_width = strwidth(name)
  if name_width < minimum_length then
    local remaining_length = minimum_length - name_width

    --- PERF: faster than `math.floor(difference / 2)`
    local half = rshift(remaining_length, 1)

    --- accounts for if `remaining_length` is not evenly divisible
    local other_half = remaining_length - half

    name = (' '):rep(other_half) .. name .. (' '):rep(half)
  elseif name_width > maximum_length then
    local ext_index = name:reverse():find('%.')

    if ext_index ~= nil and (ext_index < maximum_length - ELLIPSIS_LEN) then
      local extension = name:sub(-ext_index)
      name = strcharpart(name, 0, maximum_length - ELLIPSIS_LEN - #extension) .. ELLIPSIS .. extension
    else
      name = strcharpart(name, 0, maximum_length - ELLIPSIS_LEN) .. ELLIPSIS
    end
  end

  return name
end

--- @param buffer_numbers integer[]
--- @return string[]
function buffer.get_unique_names(buffer_numbers)
  local depth = 1
  local computed_names

  local update_computed_names = function()
    computed_names = map(function(buffer_number)
      local name = buffer.get_name(buffer_number, depth)
      local parts = split(name, separator)
      local computed_name = table_concat(list.slice_from_end(parts, depth), separator)
      return computed_name
    end, buffer_numbers)
  end

  repeat
    update_computed_names()
    depth = depth + 1
  until list.is_unique(computed_names) or depth > 10

  return computed_names
end

return buffer
