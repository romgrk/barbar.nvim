--
-- buffer.lua
--

local concat = table.concat
local substring = string.sub

local list_slice = vim.list_slice

local utils = require'bufferline.utils'

local function terminalname(name)
  local result = vim.fn.matchlist(name, [===[term://.\{-}//\d\+:\(.*\)]===])
  if next(result) == nil then
    return name
  else
    return result[2]
  end
end

-- returns 0: none, 1: active, 2: current
local function get_activity(number)
  if vim.api.nvim_get_current_buf() == number then
    return 2
  end
  if vim.fn.bufwinnr(number) ~= -1 then
    return 1
  end
  return 0
end

local function get_name(opts, number)
  local name = vim.api.nvim_buf_get_name(number)

  if name == '' then
    if opts.no_name_title ~= nil and
       opts.no_name_title ~= vim.NIL
    then
      name = opts.no_name_title
    else
      name = '[buffer ' .. number .. ']'
    end
  else
    local buftype = vim.bo[number].buftype
    if buftype == 'terminal' then
      name = terminalname(name)
    else
      name = utils.basename(name)
    end
  end

  local ellipsis = '…'
  local max_len = opts.maximum_length
  if #name > max_len then
    local ext_index = string.find(string.reverse(name), '%.')

    if ext_index ~= nil and (ext_index < max_len - #ellipsis) then
      local extension = substring(name, -ext_index)
      name = substring(name, 1, max_len - #ellipsis - #extension) .. ellipsis .. extension
    else
      name = substring(name, 1, max_len - #ellipsis) .. ellipsis
    end

    -- safety to prevent recursion in any future edge case
    name = substring(name, 1, max_len)
  end

  return name
end

local separator = package.config:sub(1,1)
local function get_unique_name(first, second)
  local first_parts  = vim.split(first,  separator)
  local second_parts = vim.split(second, separator)

  local length = 1
  local first_result  = concat(list_slice(first_parts, -length),  separator)
  local second_result = concat(list_slice(second_parts, -length), separator)

  while first_result == second_result and
        length < math.max(#first_parts, #second_parts)
  do
    length = length + 1
    first_result  = concat(list_slice(first_parts,  -math.min(#first_parts, length)),  separator)
    second_result = concat(list_slice(second_parts, -math.min(#second_parts, length)), separator)
  end

  return first_result, second_result
end

return {
  get_activity = get_activity,
  get_name = get_name,
  get_unique_name = get_unique_name,
}
