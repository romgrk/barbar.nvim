--
-- buffer.lua
--

local max = math.max
local min = math.min
local table_concat = table.concat

local bufnr = vim.fn.bufnr
local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local buf_is_valid = vim.api.nvim_buf_is_valid
local bufwinnr = vim.fn.bufwinnr
local ERROR = vim.diagnostic.severity.ERROR
local get_current_buf = vim.api.nvim_get_current_buf
local get_diagnostics = vim.diagnostic.get
local HINT = vim.diagnostic.severity.HINT
local INFO = vim.diagnostic.severity.INFO
local matchlist = vim.fn.matchlist
local split = vim.split
local strcharpart = vim.fn.strcharpart
local strwidth = vim.api.nvim_strwidth
local WARN = vim.diagnostic.severity.WARN

--- @type bufferline.options
local options = require'bufferline.options'

--- @type bufferline.utils
local utils = require'bufferline.utils'

--- @alias bufferline.buffer.activity 1|2|3|4

--- @alias bufferline.buffer.activity.name 'Inactive'|'Alternate'|'Visible'|'Current'

--- The character used to delimit paths (e.g. `/` or `\`).
local separator = package.config:sub(1,1)

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
--- @return bufferline.buffer.activity # whether `bufnr` is inactive, the alternate file, visible, or currently selected (in that order).
local function get_activity(buffer_number)
  if get_current_buf() == buffer_number then
    return 4
  elseif options.highlight_alternate() and bufnr('#') == buffer_number then
    return 2
  elseif options.highlight_visible() and bufwinnr(buffer_number) ~= -1 then
    return 3
  end

  return 1
end

--- @param buffer_number number
--- @return {[number]: number} count keyed on `vim.diagnostic.severity`
local function count_diagnostics(buffer_number)
  local count = {[ERROR] = 0, [HINT] = 0, [INFO] = 0, [WARN] = 0}

  for _, diagnostic in ipairs(get_diagnostics(buffer_number)) do
    count[diagnostic.severity] = count[diagnostic.severity] + 1
  end

  return count
end

--- @class bufferline.buffer
return {
  count_diagnostics = count_diagnostics,

  --- For each severity in `diagnostics`: if it is enabled, and there are diagnostics associated with it in the `buffer_number` provided, call `f`.
  --- @param buffer_number integer the buffer number to count diagnostics in
  --- @param diagnostics bufferline.options.diagnostics the user configuration for diagnostics
  --- @param f fun(count: integer, diagnostic: bufferline.options.diagnostics.severity, severity: integer) the function to run when diagnostics of a specific severity are enabled and present in the `buffer_number`
  for_each_counted_enabled_diagnostic = function(buffer_number, diagnostics, f)
    local count
    for i, v in ipairs(diagnostics) do
      if v.enabled then
        count = count or count_diagnostics(buffer_number)
        if count[i] > 0 then
          f(count[i], v, i)
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

    local no_name_title = options.no_name_title()
    local maximum_length = options.maximum_length()

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
  --- Does not mutate `bufnrs`.
  --- @param bufnrs integer[]
  --- @return integer[] bufnrs
  hide = function(bufnrs)
    local hide = options.hide()
    if hide.alternate or hide.current or hide.inactive or hide.visible then
      local shown = {}

      hide = {hide.inactive, hide.visible, hide.alternate, hide.current}
      for _, buffer_number in ipairs(bufnrs) do
        if not hide[get_activity(buffer_number)] then
          shown[#shown + 1] = buffer_number
        end
      end

      bufnrs = shown
    end

    return bufnrs
  end,
}
