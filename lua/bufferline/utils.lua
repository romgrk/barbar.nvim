--
-- utils.lua
--

local function index_of(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

return {
  basename = function (path)
     return vim.fn.fnamemodify(path, ':t')
  end,

  has = function (tbl, n)
    return index_of(tbl, n) ~= nil
  end,

  index_of = index_of,

  is_nil = function (value)
    return value == nil or value == vim.NIL
  end,

  reverse = function (tbl)
    local reversed = {}
    while #reversed < #tbl do
      reversed[#reversed + 1] = tbl[#tbl - #reversed]
    end
    return reversed
  end,
}
