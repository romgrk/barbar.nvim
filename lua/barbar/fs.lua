--
-- fs.lua
--


local fs = {}

--- @param filepath string
--- @param content string
--- @param mode string
--- @return string | nil err
function fs.write(filepath, content, mode)
  mode = mode or 'w'
  local file, open_err = io.open(filepath, mode)
  if open_err ~= nil then
    return open_err
  elseif file == nil then
    return 'Error while opening file'
  end
  local _, write_err = file:write(content)
  if write_err ~= nil then
    return write_err
  end

  local success, close_err = file:close()
  if close_err ~= nil then
    return close_err
  elseif success == false then
    return 'Error while closing file'
  end
  return nil
end

return fs
