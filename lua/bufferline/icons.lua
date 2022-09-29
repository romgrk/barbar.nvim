--
-- get-icon.lua
--

local table_insert = table.insert

local command = vim.api.nvim_command
local fnamemodify = vim.fn.fnamemodify
local hlexists = vim.fn.hlexists
local matchstr = vim.fn.matchstr
local notify = vim.notify

--- @type bufferline.utils.hl
local hl = require'bufferline.utils'.hl

local status, web = pcall(require, 'nvim-web-devicons')

--- @class bufferline.icons.group
--- @field buffer_status "Current"|"Inactive"|"Visible" the state of the buffer whose icon is being highlighted
--- @field icon_hl string the group to highlight an icon with

--- @type bufferline.icons.group[]
local hl_groups = {}

--- @class bufferline.icons
return {
  -- It's not possible to purely delete an HL group when the colorscheme
  -- changes, therefore we need to re-define colors for all groups we have
  -- already highlighted.
  set_highlights = function()
    for _, group in ipairs(hl_groups) do
      hl.set(
        group.icon_hl .. group.buffer_status,
        hl.bg_or_default({'Buffer' .. group.buffer_status}, 'none'),
        hl.fg_or_default({group.icon_hl}, 'none')
      )
    end
 end,

  --- @param buffer_name string
  --- @param filetype string
  --- @param buffer_status "Current"|"Inactive"|"Visible"
  --- @return string icon, string highlight_group
  get_icon = function(buffer_name, filetype, buffer_status)
    if status == false then
      notify(
        'barbar: bufferline.icons is set to v:true but "nvim-dev-icons" was not found.' ..
          '\nbarbar: icons have been disabled. Set `bufferline.icons` to `false` or ' ..
          'install "nvim-dev-icons" to disable this message.',
        vim.log.levels.WARN,
        {title = 'barbar.nvim'}
      )

      if type(vim.g.bufferline) == 'table' then
        command('let g:bufferline.icons = v:false')
      else
        vim.g.bufferline = {icons = false}
      end

      return '', ''
    end

    local basename
    local extension
    local icon_char
    local icon_hl

    -- nvim-web-devicon only handles filetype icons, not other types (eg directory)
    -- thus we need to do some work here
    if filetype == 'netrw' or filetype == 'LuaTree' then
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
      hl.set(
        icon_hl .. buffer_status,
        hl.bg_or_default({'Buffer' .. buffer_status}, 'none'),
        hl.fg_or_default({icon_hl}, 'none')
      )
      table_insert(hl_groups, { buffer_status = buffer_status, icon_hl = icon_hl })
    end

    return icon_char, icon_hl .. buffer_status
  end,
}
