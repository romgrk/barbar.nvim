local table_insert = table.insert

local list_slice = vim.list_slice

--- @class barbar.utils.List
local list = {}

--- Return the index of element `n` in `list.
--- @generic T
--- @param tbl T[]
--- @param t T
--- @return nil|integer index
function list.index_of(tbl, t)
  for i, value in ipairs(tbl) do
    if value == t then
      return i
    end
  end
  return nil
end

--- reverse the order of elements in some `list`.
--- perf: don't do `ipairs(list_reverse(list))`, just do `for i = #list, 1, -1` instead.
--- @generic t
--- @param tbl t[]
function list.reverse(tbl)
  local reversed = {}
  for i = #tbl, 1, -1 do
    table_insert(reversed, tbl[i])
  end
  return reversed
end

--- Run `vim.list_slice` on some `list`, `index`ed from the end of the list.
--- @generic T
--- @param tbl T[]
--- @param index_from_end number
--- @return T[] sliced
function list.slice_from_end(tbl, index_from_end)
  return list_slice(tbl, #tbl - index_from_end + 1)
end

--- Check if values are unique
--- @generic T
--- @param tbl T[]
--- @return boolean
function list.is_unique(tbl)
  local value_set = {}
  for _, value in ipairs(tbl) do
    if value_set[value] ~= nil then
      return false
    end
    value_set[value] = true
  end
  return true
end


return list
