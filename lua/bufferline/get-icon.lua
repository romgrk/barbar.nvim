--
-- get-icon.lua
--

local status, web = pcall(require, 'nvim-web-devicons')

local function get_icon(buffer_name, filetype)
  local basename
  local extension

  if filetype == 'fugitive' or filetype == 'gitcommit' then
    basename = 'git'
    extension = 'git'
  else
    basename = vim.fn.fnamemodify(buffer_name, ':t')
    extension = vim.fn.matchstr(basename, [[\v\.@<=\w+$]], '', '')
  end

  return web.get_icon(basename, extension, { default = true })
end

return get_icon
