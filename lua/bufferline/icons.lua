--
-- get-icon.lua
--

local status, web = pcall(require, 'nvim-web-devicons')

local function get_attr(group, attr)
  local rgb_val = (vim.api.nvim_get_hl_by_name(group, true) or {})[attr]
  return rgb_val and string.format('#%06x', rgb_val) or 'NONE'
end

-- List of icon HL groups
local hl_groups = {}
-- It's not possible to purely delete an HL group when the colorscheme
-- changes, therefore we need to re-define colors for all groups we have
-- already highlighted.
local function set_highlights()
  for _, hl_group in ipairs(hl_groups) do
    local icon_hl = hl_group[1]
    local buffer_status = hl_group[2]
    vim.api.nvim_set_hl(0, icon_hl .. buffer_status, {
      bg = get_attr('Buffer' .. buffer_status, 'background'),
      fg = get_attr(icon_hl, 'foreground'),
    })
  end
end


local function get_icon(buffer_name, filetype, buffer_status)
  if status == false then
    vim.notify(
      'barbar: bufferline.icons is set to v:true but \\\"nvim-dev-icons\\\" was not found.' ..
        '\nbarbar: icons have been disabled. Set `bufferline.icons` to `false` to disable this message.',
      vim.log.levels.WARN,
      {title = 'barbar.nvim'}
    )
    vim.g.bufferline.icons = false
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

  if icon_hl and vim.fn.hlexists(icon_hl .. buffer_status) < 1 then
    local hl_group = icon_hl .. buffer_status
    vim.api.nvim_set_hl(0, hl_group {
      bg = get_attr('Buffer' .. buffer_status, 'background'),
      fg = get_attr(icon_hl, 'foreground'),
    })
    table.insert(hl_groups, { icon_hl, buffer_status })
  end

  return icon_char, icon_hl .. buffer_status
end

return {
  get_icon = get_icon,
  set_highlights = set_highlights,
}
