--
-- buffer.lua
--

local max = math.max
local min = math.min
local table_concat = table.concat

local buf_get_name = vim.api.nvim_buf_get_name
local buf_is_valid = vim.api.nvim_buf_is_valid
local buf_get_option = vim.api.nvim_buf_get_option
local bufwinnr = vim.fn.bufwinnr
local get_current_buf = vim.api.nvim_get_current_buf
local matchlist = vim.fn.matchlist
local split = vim.split

--- @type bufferline.utils
local utils = require'bufferline.utils'

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

--- @class bufferline.buffer
return {
  --- returns 0: none, 1: active, 2: current
  --- @param bufnr integer
  --- @return 1|2|3 # whether `bufnr` is inactive, visible, and currently selected (in that order).
  get_activity = function(bufnr)
    if get_current_buf() == bufnr then
      return 3
    elseif not vim.g.bufferline.use_winbar and bufwinnr(bufnr) ~= -1 then
      return 2
    end

    return 1
  end,

  ---
  --- @param bufnr integer
  get_name = function(bufnr)
    --- @type nil|string
    local name = buf_is_valid(bufnr) and buf_get_name(bufnr) or nil

    local no_name_title = vim.g.bufferline.no_name_title
    local maximum_length = vim.g.bufferline.maximum_length

    if name then
      name = buf_get_option(bufnr, 'buftype') == 'terminal' and terminalname(name) or utils.basename(name)
    elseif no_name_title ~= nil and no_name_title ~= vim.NIL then
      name = no_name_title
    end

    if name == '' or not name then
      name = '[buffer ' .. bufnr .. ']'
    end

    local ellipsis = '…'
    local max_len = maximum_length
    if #name > max_len then
      local ext_index = name:reverse():find('%.')

      if ext_index ~= nil and (ext_index < max_len - #ellipsis) then
        local extension = name:sub(-ext_index)
        name = name:sub(1, max_len - #ellipsis - #extension) .. ellipsis .. extension
      else
        name = name:sub(1, max_len - #ellipsis) .. ellipsis
      end

      -- safety to prevent recursion in any future edge case
      name = name:sub(1, max_len)
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
}
