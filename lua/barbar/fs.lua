--
-- fs.lua
--


local fs = {}

--- @param filepath string
--- @param content string
--- @param mode string
--- @return boolean
function fs.write(filepath, content, mode)
  mode = mode or 'w'
  local file, open_err = io.open(filepath, mode)
  if open_err ~= nil then
    return false
  elseif file == nil then
    return false
  end
  file:write(content)
  local success, close_err = file:close()
  if close_err ~= nil then
    return false
  elseif success == false then
    return false
  end
  return true
end

return fs
