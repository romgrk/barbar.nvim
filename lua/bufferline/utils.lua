--
-- utils.lua
--

local vim = vim
local bufname = vim.fn.bufname
local fnamemodify = vim.fn.fnamemodify
local matchlist = vim.fn.matchlist
local split = vim.split
local join = table.concat
local strwidth = vim.api.nvim_strwidth
local nvim_buf_get_option = vim.api.nvim_buf_get_option

local function len(value)
  return #value
end

local function index(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

local function slice(tbl, first, last)
  if type(tbl) == 'string' then
    return string.sub(tbl, first, last)
  end

  if first < 0 then
    first = #tbl + 1 + first
  end

  if last ~= nil and last < 0 then
    last = #tbl + 1 + last
  end

  local sliced = {}

  for i = first or 1, last or #tbl do
    sliced[#sliced+1] = tbl[i]
  end

  return sliced
end

local function reverse(tbl)
  local result = {}
  for i = #tbl, 1, -1 do
    table.insert(result, tbl[i])
  end
  return result
end

local function collect(iterator)
  local result = {}
  for it, v in iterator do
    table.insert(result, v)
  end
  return result
end

local function basename(path)
   return fnamemodify(path, ':t')
end

local function terminalname(name)
  local result = matchlist(name, [===[term://.\\{-}//\\d\\+:\\(.*\\)]===])
  if next(result) == nil then
    return name
  else
    return result[2]
  end
end

local function get_buffer_name(opts, number)
  local name = bufname(number)

  if name == '' then
    name = opts.no_name_title or ('[buffer ' .. number .. ']')
  else
    local buftype = nvim_buf_get_option(number, 'buftype')
    if buftype == 'terminal' then
      name = terminalname(name)
    else
      name = basename(name)
    end
  end

  if len(name) > opts.maximum_length then
    name = '…' .. slice(name, -opts.maximum_length, -1)
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

-- print(vim.inspect(get_buffer_names(vim.g['bufferline#'].buffers)))

return {
  len = len,
  index = index,
  slice = slice,
  reverse = reverse,
  collect = collect,
  get_buffer_name = get_buffer_name,
  get_unique_name = get_unique_name,
}
