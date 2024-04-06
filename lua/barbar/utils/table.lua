--- @class barbar.utils.Table
local table = {}

--- Remove `tbl[key]` from `tbl` and return it
--- @param tbl table
--- @param key string
--- @return any
function table.remove_key(tbl, key)
  local value = rawget(tbl, key)
  rawset(tbl, key, nil)
  return value
end

--- Set a `value` in a `tbl` multiple `keys` deep.
--
--- ```lua
--- assert(vim.deep_equal(
---  {a = {b = {c = 'd'}}},
---  tbl_set({}, {'a', 'b', 'c'}, 'd')
--- ))
--- ```
---
--- WARN: this mutates `tbl`!
---
--- @generic T
--- @param tbl table
--- @param keys table<number|string|table>
--- @param value T
--- @return nil
function table.set(tbl, keys, value)
  local current = tbl
  for i = 1, #keys - 1 do
    local key = keys[i]

    if current[key] == nil then
      current[key] = {}
    end

    current = current[key]
  end

  current[keys[#keys]] = value
end

return table
