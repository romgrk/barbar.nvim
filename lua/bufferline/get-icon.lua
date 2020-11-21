--
-- get-icon.lua
--

local nvim = require'bufferline.nvim'
local status, web = pcall(require, 'nvim-web-devicons')

local function get_attr(group, attr)
  local rgb_val = (nvim.get_hl_by_name(group, true) or {})[attr]

  return rgb_val and string.format('#%06x', rgb_val) or 'NONE'
end

local function get_icon(buffer_name, filetype, buffer_status)
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

  local iconChar, iconHl = web.get_icon(basename, extension, { default = true })

  if iconHl and vim.fn.hlexists(iconHl..buffer_status) < 1 then
    nvim.command(
      'hi! ' .. iconHl .. buffer_status ..
      ' guifg=' .. get_attr(iconHl, 'foreground') ..
      ' guibg=' .. get_attr('Buffer'..buffer_status, 'background')
    )
  end

  return iconChar, iconHl..buffer_status
end

return get_icon
