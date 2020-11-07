--
-- get-icon.lua
--

local nvim = require'bufferline.nvim'
local status, web = pcall(require, 'nvim-web-devicons')

local function get_icon(buffer_name, filetype)
  if status == false then
    nvim.command('echohl WarningMsg')
    nvim.command('echom "barbar: bufferline.icons is set to v:true but \\\"nvim-dev-icons\\\" was not found."')
    nvim.command('echom "barbar: icons have been disabled. Set bufferline.icons to v:false to disable this message."')
    nvim.command('echohl None')
    nvim.command('let g:bufferline.icons = v:false')
    return ' '
  end

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
