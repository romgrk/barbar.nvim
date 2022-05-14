--
-- utils.lua
--

local function len(value)
  return #value
end

local function is_nil(value)
  return value == nil or value == vim.NIL
end

local function index_of(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

local function has(tbl, n)
  return index_of(tbl, n) ~= nil
end

local function reverse(tbl)
  local reversed = {}
  while #reversed < #tbl do
    reversed[#reversed + 1] = tbl[#tbl - #reversed]
  end
  return reversed
end

local function basename(path)
   return vim.fn.fnamemodify(path, ':t')
end

return {
  len = len,
  is_nil = is_nil,
  index_of = index_of,
  has = has,
  reverse = reverse,
  basename = basename,
}
