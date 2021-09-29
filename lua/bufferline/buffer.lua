--
-- buffer.lua
--


local vim = vim
local utils = require'bufferline.utils'
local split = vim.split
local join = table.concat
local len = utils.len
local slice = utils.slice
local basename = utils.basename
local bufname = vim.fn.bufname
local bufwinnr = vim.fn.bufwinnr
local matchlist = vim.fn.matchlist
local nvim_buf_get_option = vim.api.nvim_buf_get_option
local nvim_get_current_buf = vim.api.nvim_get_current_buf


local function terminalname(name)
  local result = matchlist(name, [===[term://.\{-}//\d\+:\(.*\)]===])
  if next(result) == nil then
    return name
  else
    return result[2]
  end
end


-- returns 0: none, 1: active, 2: current
local function get_activity(number)
  if nvim_get_current_buf() == number then
    return 2
  end
  if bufwinnr(number) ~= -1 then
    return 1
  end
  return 0
end

local function get_name(opts, number)
  local name = bufname(number)

  if name == '' then
    if opts.no_name_title ~= nil and
       opts.no_name_title ~= vim.NIL
    then
      name = opts.no_name_title
    else
      name = '[buffer ' .. number .. ']'
    end
  else
    local buftype = nvim_buf_get_option(number, 'buftype')
    if buftype == 'terminal' then
      name = terminalname(name)
    else
      name = basename(name)
    end
  end

  local ellipsis = '…'
  local max_len = opts.maximum_length
  if #name > max_len then
    local ext_index = string.find(string.reverse(name), '%.')

    if ext_index ~= nil and (ext_index < max_len - #ellipsis) then
      local extension = string.sub(name, -ext_index)
      name = string.sub(name, 1, max_len - #ellipsis - #extension) .. ellipsis .. extension
    else
      name = string.sub(name, 1, max_len - #ellipsis) .. ellipsis
    end

    -- safety to prevent recursion in any future edge case
    name = string.sub(name, 1, max_len)
  end

  return name
end

local separator = package.config:sub(1,1)
local function get_unique_name (first, second)
  local first_parts  = split(first,  separator)
  local second_parts = split(second, separator)

  local length = 1
  local first_result  = join(slice(first_parts, -length),  separator)
  local second_result = join(slice(second_parts, -length), separator)

  while first_result == second_result and
        length < math.max(len(first_parts), len(second_parts))
  do
    length = length + 1
    first_result  = join(slice(first_parts,  -math.min(len(first_parts), length)),  separator)
    second_result = join(slice(second_parts, -math.min(len(second_parts), length)), separator)
  end

  return first_result, second_result
end

return {
  get_activity = get_activity,
  get_name = get_name,
  get_unique_name = get_unique_name,
}
