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

--- Add the reverse lookup values to an existing table.
--- For example:
--- `add_reverse_lookup { A = 1 } == { [1] = 'A', A = 1 }`
---
--- Note that this *modifies* the input.
---@param o table Table to add the reverse to
---@return table o
function table.add_reverse_lookup(o)
  --- @cast o table<any,any>
  --- @type any[]
  local keys = vim.tbl_keys(o)
  for _, k in ipairs(keys) do
    local v = o[k]
    if o[v] then
      error(
        string.format(
          'The reverse lookup found an existing value for %q while processing key %q',
          tostring(v),
          tostring(k)
        )
      )
    end
    o[v] = k
  end
  return o
end

return table
