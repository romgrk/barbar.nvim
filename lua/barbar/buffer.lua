--
-- buffer.lua
--

local max = math.max
local min = math.min
local table_concat = table.concat
local table_insert = table.insert

local bufnr = vim.fn.bufnr --- @type function
local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_is_valid = vim.api.nvim_buf_is_valid --- @type function
local bufwinnr = vim.fn.bufwinnr --- @type function
local ERROR = vim.diagnostic.severity.ERROR --- @type integer
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local get_diagnostics = vim.diagnostic.get --- @type fun(bufnr: integer): {severity: integer}[]
local HINT = vim.diagnostic.severity.HINT --- @type integer
local INFO = vim.diagnostic.severity.INFO --- @type integer
local matchlist = vim.fn.matchlist --- @type function
local split = vim.split
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function
local WARN = vim.diagnostic.severity.WARN --- @type integer

local config = require'barbar.config'
local utils = require'barbar.utils'

--- @alias barbar.buffer.activity 1|2|3|4

--- @alias barbar.buffer.activity.name 'Inactive'|'Alternate'|'Visible'|'Current'

--- A bidirectional map of activities to activity names
--- @type {[barbar.buffer.activity]: barbar.buffer.activity.name, [barbar.buffer.activity.name]: barbar.buffer.activity}
local activities = vim.tbl_add_reverse_lookup {'Inactive', 'Alternate', 'Visible', 'Current'}

--- The character used to delimit paths (e.g. `/` or `\`).
local separator = package.config:sub(1, 1)

--- @param name string
--- @return string
local function terminalname(name)
  local result = matchlist(name, [===[term://.\{-}//\d\+:\(.*\)]===])
  if next(result) == nil then
    return name
  else
    return result[2]
  end
end

--- @param buffer_number integer
--- @return barbar.buffer.activity # whether `bufnr` is inactive, the alternate file, visible, or currently selected (in that order).
local function get_activity(buffer_number)
  if get_current_buf() == buffer_number then
    return activities.Current
  elseif config.options.highlight_alternate and bufnr('#') == buffer_number then
    return activities.Alternate
  elseif config.options.highlight_visible and bufwinnr(buffer_number) ~= -1 then
    return activities.Visible
  end

  return activities.Inactive
end

--- @param buffer_number integer
--- @return integer[] # indexed on `vim.diagnostic.severity`
local function count_diagnostics(buffer_number)
  local count = {[ERROR] = 0, [HINT] = 0, [INFO] = 0, [WARN] = 0}

  for _, diagnostic in ipairs(get_diagnostics(buffer_number)) do
    count[diagnostic.severity] = count[diagnostic.severity] + 1
  end

  return count
end

--- @class barbar.buffer
local buffer = {
  activities = activities,

  count_diagnostics = count_diagnostics,

  --- For each severity in `diagnostics`: if it is enabled, and there are diagnostics associated with it in the `buffer_number` provided, call `f`.
  --- @param buffer_number integer the buffer number to count diagnostics in
  --- @param diagnostics barbar.config.options.icons.diagnostics the user configuration for diagnostics
  --- @param f fun(count: integer, diagnostic: barbar.config.options.icons.diagnostics.severity, severity: integer) the function to run when diagnostics of a specific severity are enabled and present in the `buffer_number`
  --- @return nil
  for_each_counted_enabled_diagnostic = function(buffer_number, diagnostics, f)
    local count
    for severity, severity_config in ipairs(diagnostics) do
      if severity_config.enabled then
        if count == nil then
          count = count_diagnostics(buffer_number)
        end

        if count[severity] > 0 then
          f(count[severity], severity_config, severity)
        end
      end
    end
  end,

  get_activity = get_activity,

  --- @param buffer_number integer
  --- @param hide_extensions boolean? if `true`, exclude the extension of the file
  --- @return string name
  get_name = function(buffer_number, hide_extensions)
    --- @type string
    local name = buf_is_valid(buffer_number) and buf_get_name(buffer_number) or ''

    local no_name_title = config.options.no_name_title
    local maximum_length = config.options.maximum_length

    if name ~= '' then
      name = buf_get_option(buffer_number, 'buftype') == 'terminal' and terminalname(name) or utils.basename(name, hide_extensions)
    elseif no_name_title ~= nil and no_name_title ~= vim.NIL then
      name = no_name_title
    end

    if name == '' then
      name = '[buffer ' .. buffer_number .. ']'
    end

    local ellipsis = '…'
    if strwidth(name) > maximum_length then
      local ext_index = name:reverse():find('%.')

      if ext_index ~= nil and (ext_index < maximum_length - #ellipsis) then
        local extension = name:sub(-ext_index)
        name = strcharpart(name, 0, maximum_length - #ellipsis - #extension) .. ellipsis .. extension
      else
        name = strcharpart(name, 0, maximum_length - #ellipsis) .. ellipsis
      end

      -- safety to prevent recursion in any future edge case
      name = name:sub(1, maximum_length)
    end

    return name
  end,

  --- @param first string
  --- @param second string
  --- @return string, string
  get_unique_name = function(first, second)
    local first_parts  = split(first,  separator)
    local second_parts = split(second, separator)

    local length = 1
    local first_result  = table_concat(utils.list_slice_from_end(first_parts, length),  separator)
    local second_result = table_concat(utils.list_slice_from_end(second_parts, length), separator)

    while first_result == second_result and
          length < max(#first_parts, #second_parts)
    do
      length = length + 1
      first_result  = table_concat(utils.list_slice_from_end(first_parts,  min(#first_parts, length)),  separator)
      second_result = table_concat(utils.list_slice_from_end(second_parts, min(#second_parts, length)), separator)
    end

    return first_result, second_result
  end,

  --- Filter buffer numbers which are not to be shown during the render process.
  --- Does **not** mutate `bufnrs`.
  --- @param bufnrs integer[]
  --- @return integer[] bufnrs the shown buffers
  hide = function(bufnrs)
    local hide = config.options.hide
    if hide.alternate or hide.current or hide.inactive or hide.visible then
      local shown = {}

      for _, buffer_number in ipairs(bufnrs) do
        local activity = activities[get_activity(buffer_number)]
        if not hide[activity:lower()] then
          table_insert(shown, buffer_number)
        end
      end

      bufnrs = shown
    end

    return bufnrs
  end,
}

return buffer
