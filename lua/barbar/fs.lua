--
-- fs.lua
--

local fnamemodify = vim.fn.fnamemodify --- @type function
local vim_fs = vim.fs or {}

local list = require('barbar.utils.list') --- @type barbar.utils.List

--- @class barbar.Fs
local fs = {}

--- @param path string
--- @return string absolute_path
function fs.absolute(path)
  return fnamemodify(path, ':p')
end

--- Get
--- @param path string
--- @param hide_extension? boolean if `true`, exclude the extension of the file in the basename
--- @return string basename
function fs.basename(path, hide_extension)
  return fnamemodify(path, hide_extension and ':t:r' or ':t')
end

--- @param path string
--- @return boolean is_relative `true` if `path` is relative to the CWD
function fs.is_relative_path(path)
  return fs.relative(path) == path
end

if vim_fs.joinpath then
  fs.join = vim_fs.joinpath
else
  local table_concat = table.concat
  --- @param ... string the parts to join into a path
  --- @return string path the joined, normalized path
  function fs.join(...)
    local joined = table_concat({...}, '/')
    local normalized = fs.normalize(joined)
    return normalized
  end
end

--- implementation of certain functions can be simplified based on Neovim version
if vim_fs.normalize then
  local normalize = vim_fs.normalize

  --- create a standard format for the path.
  ---
  --- # Remarks
  ---
  --- - we wrap around `normalize` despite forwarding all args so we can control the input
  --- - env variables are not expanded, which differs from the default behavior of `vim.fs.normalize`
  ---   - we do this to prevent pervasive mismatch between behavior in different Nvim versions.
  ---
  --- @param path string
  --- @return string normalized_path
  function fs.normalize(path)
    return normalize(path, { expand_env = false })
  end
else
  --- the OS' path separator (e.g. `/` on unix, `\` on windows)
  local os_path_separator = package.config:sub(1, 1)


  --- a custom implementation of path normalization.
  ---
  --- # Remarks
  ---
  --- - less in-depth than `vim.fs.normalize` (available from Nvim 0.8+); meant to bridge the gap in versions.
  --- - `vim.loop.fs_realpath` was considered, but it fails if a path does not exist on-disk
  ---
  --- @param path string
  --- @return string normalized_path
  function fs.normalize(path)
    local normalized, _ = path:gsub(os_path_separator, '/') -- replace backslashes on Windows with forward slashes
    return normalized
  end
end

--- @param filepath string
--- @param mode? openmode
--- @return string|nil error_message, any content
function fs.read(filepath, mode)
  local file, open_err = io.open(filepath, mode or 'r')

  -- Ignore if the file doesn't exist or isn't readable
  if open_err ~= nil then
    return
  elseif file == nil then
    return
  end

  local content, read_err = file:read('*a')
  if read_err ~= nil then
    return read_err
  end

  do
    local success, close_err = file:close()
    if close_err ~= nil then
      return close_err
    elseif success == false then
      return 'Error while closing ' .. filepath
    end
  end

  return nil, content
end

--- @param path string
--- @return string relative_path
function fs.relative(path)
  return fnamemodify(path, ':~:.')
end

--- # Example
---
--- ```lua
--- fs.split '~/foo/bar/baz.lua' --> {'~', 'foo', 'bar', 'baz.lua'}
--- ```
---
--- @param path string a (normalized) filepath to split
--- @return string[] parts the sections of the filepath between separators
function fs.split(path)
  return vim.split(path, '/', { plain = true, trimempty = true })
end

--- # Example
---
--- ```lua
--- fs.slice_parts_from_end('~/foo/bar/baz', 2) --> 'bar/baz'
--- ```
---
--- @param path string a (normalized) filepath from which to select a given number of ending parts
--- @param desired_parts integer the number of parts which the final path should have
--- @return string sliced_path the filepath with only the given number of desired parts left at the end
function fs.slice_parts_from_end(path, desired_parts)
  local parts = fs.split(path)
  parts = list.slice_from_end(parts, desired_parts)

  local desired_path = fs.join(unpack(parts))
  return desired_path
end

--- @param filepath string
--- @param content string
--- @param mode? openmode
--- @return string|nil error_message
function fs.write(filepath, content, mode)
  local file, open_err = io.open(filepath, mode or 'w')

  if open_err ~= nil then
    return open_err
  elseif file == nil then
    return 'Error while opening ' .. filepath
  end

  do
    local _, write_err = file:write(content)
    if write_err ~= nil then
      return write_err
    end
  end

  local success, close_err = file:close()
  if close_err ~= nil then
    return close_err
  elseif success == false then
    return 'Error while closing ' .. filepath
  end
end

return fs
