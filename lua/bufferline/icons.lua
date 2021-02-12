--
-- get-icon.lua
--

local nvim = require'bufferline.nvim'
local status, web = pcall(require, 'nvim-web-devicons')

local function get_attr(group, attr)
  local rgb_val = (nvim.get_hl_by_name(group, true) or {})[attr]
  return rgb_val and string.format('#%06x', rgb_val) or 'NONE'
end

-- List of icon HL groups
local hl_groups = {}
-- It's not possible to purely delete an HL group when the colorscheme
-- changes, therefore we need to re-define colors for all groups we have
-- already highlighted.
local function set_highlights()
  for i, hl_group in ipairs(hl_groups) do
    local icon_hl = hl_group[1]
    local buffer_status = hl_group[2]
    nvim.command(
      'hi! ' .. icon_hl .. buffer_status ..
      ' guifg=' .. get_attr(icon_hl, 'foreground') ..
      ' guibg=' .. get_attr('Buffer'..buffer_status, 'background')
    )
  end
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
  local icon_char
  local icon_hl

  -- nvim-web-devicon only handles filetype icons, not other types (eg directory)
  -- thus we need to do some work here
  if
    filetype == 'netrw' or
    filetype == 'LuaTree'
  then
    icon_char = ''
    icon_hl = 'Directory'
  else
    if filetype == 'fugitive' or filetype == 'gitcommit' then
      basename = 'git'
      extension = 'git'
    else
      basename = vim.fn.fnamemodify(buffer_name, ':t')
      extension = vim.fn.matchstr(basename, [[\v\.@<=\w+$]], '', '')
    end

    icon_char, icon_hl = web.get_icon(basename, extension, { default = true })
  end

  if icon_hl and vim.fn.hlexists(icon_hl..buffer_status) < 1 then
    local hl_group = icon_hl .. buffer_status
    nvim.command(
      'hi! ' .. hl_group ..
      ' guifg=' .. get_attr(icon_hl, 'foreground') ..
      ' guibg=' .. get_attr('Buffer'..buffer_status, 'background')
    )
    table.insert(hl_groups, { icon_hl, buffer_status })
  end

  return icon_char, icon_hl..buffer_status
end

return {
  get_icon = get_icon,
  set_highlights = set_highlights,
}
