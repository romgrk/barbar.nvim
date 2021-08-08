--
-- utils.lua
--

local vim = vim
local bufname = vim.fn.bufname
local fnamemodify = vim.fn.fnamemodify
local matchlist = vim.fn.matchlist
local strwidth = vim.api.nvim_strwidth

local function len(value)
  return #value
end

local function is_nil(value)
  return value == nil or value == vim.NIL
end

local function index(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

local function has(tbl, n)
  return index(tbl, n) ~= nil
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

return {
  len = len,
  is_nil = is_nil,
  index = index,
  has = has,
  slice = slice,
  reverse = reverse,
  collect = collect,
  basename = basename,
}
