--
-- get-icon.lua
--

local table_insert = table.insert

local command = vim.api.nvim_command
local fnamemodify = vim.fn.fnamemodify
local hlexists = vim.fn.hlexists
local matchstr = vim.fn.matchstr
local notify = vim.notify

local hl = require'bufferline.utils'.hl

local status, web = pcall(require, 'nvim-web-devicons')

-- List of icon HL groups
local hl_groups = {}
-- It's not possible to purely delete an HL group when the colorscheme
-- changes, therefore we need to re-define colors for all groups we have
-- already highlighted.
local function set_highlights()
  for _, hl_group in ipairs(hl_groups) do
    local icon_hl = hl_group[1]
    local buffer_status = hl_group[2]
    local set_default_hl = hl.get_default_setter()
    set_default_hl(
      icon_hl .. buffer_status,
      hl.bg_or_default({'Buffer' .. buffer_status}, 'none', nil),
      hl.fg_or_default({icon_hl}, 'none', nil)
    )
  end
end


local function get_icon(buffer_name, filetype, buffer_status)
  if status == false then
    notify(
      'barbar: bufferline.icons is set to v:true but \\\"nvim-dev-icons\\\" was not found.' ..
        '\nbarbar: icons have been disabled. Set `bufferline.icons` to `false` to disable this message.',
      vim.log.levels.WARN,
      {title = 'barbar.nvim'}
    )
    command('let g:bufferline.icons = v:false')
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
      basename = fnamemodify(buffer_name, ':t')
      extension = matchstr(basename, [[\v\.@<=\w+$]], '', '')
    end

    icon_char, icon_hl = web.get_icon(basename, extension, { default = true })
  end

  if icon_hl and hlexists(icon_hl .. buffer_status) < 1 then
    local hl_group = icon_hl .. buffer_status
    local set_default_hl = hl.get_default_setter()
    set_default_hl(
      hl_group,
      hl.bg_or_default({'Buffer' .. buffer_status}, 'none', nil),
      hl.fg_or_default({icon_hl}, 'none', nil)
    )
    table_insert(hl_groups, { icon_hl, buffer_status })
  end

  return icon_char, icon_hl .. buffer_status
end

return {
  get_icon = get_icon,
  set_highlights = set_highlights,
}
