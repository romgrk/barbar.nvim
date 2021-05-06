-- !::exe [luafile %]
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

local function get_buffer_name(number)
  local name = bufname(number)
  if name == '' then
    local opts = vim.g.bufferline
    return opts.no_name_title or ('[buffer ' .. number .. ']')
  end
  local buftype = nvim_buf_get_option(number, 'buftype')
  if buftype == 'terminal' then
    return terminalname(name)
  else
    return basename(name)
  end
end                                                              

function get_unique_name (first, second)
  local first_parts  = split(first, '/')
  local second_parts = split(second, '/')

  local length = 1
  local first_result  = join(slice(first_parts, -length), '/')
  local second_result = join(slice(second_parts, -length), '/')

  while first_result == second_result and
        length < math.max(len(first_parts), len(second_parts))
  do
    length = length + 1
    first_result  = join(slice(first_parts,  -math.min(len(first_parts), length)), '/')
    second_result = join(slice(second_parts, -math.min(len(second_parts), length)), '/')
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
