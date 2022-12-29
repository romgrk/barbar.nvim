--
-- get-icon.lua
--

local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local command = vim.api.nvim_command
local fnamemodify = vim.fn.fnamemodify
local hlexists = vim.fn.hlexists
local notify = vim.notify

--- @type bufferline.utils.hl
local hl = require'bufferline.utils'.hl

--- @type boolean, {get_icon: fun(name: string, ext?: string, opts?: {default: nil|boolean}): string, string}
local status, web = pcall(require, 'nvim-web-devicons')

--- @class bufferline.icons.group
--- @field buffer_status bufferline.buffer.activity.name the state of the buffer whose icon is being highlighted
--- @field icon_hl string the group to highlight an icon with

--- @type bufferline.icons.group[]
local hl_groups = {}

--- Sets the highlight group used for a type of buffer's file icon
--- @param buffer_status bufferline.buffer.activity.name
--- @param icon_hl string
local function hl_buffer_icon(buffer_status, icon_hl)
  hl.set(
    icon_hl .. buffer_status,
    hl.bg_or_default({'Buffer' .. buffer_status}, 'none'),
    hl.fg_or_default({icon_hl}, 'none')
  )
end

--- @class bufferline.icons
return {
  -- It's not possible to purely delete an HL group when the colorscheme
  -- changes, therefore we need to re-define colors for all groups we have
  -- already highlighted.
  set_highlights = function()
    for _, group in ipairs(hl_groups) do
      hl_buffer_icon(group.buffer_status, group.icon_hl)
    end
 end,

  --- @param bufnr integer
  --- @param buffer_status bufferline.buffer.activity.name
  --- @return string icon, string highlight_group
  get_icon = function(bufnr, buffer_status)
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

    local basename, extension = '', ''
    local filetype = buf_get_option(bufnr, 'filetype')
    local icon_char, icon_hl = '', ''

    -- nvim-web-devicon only handles filetype icons, not other types (eg directory)
    -- thus we need to do some work here
    if filetype == 'netrw' or filetype == 'LuaTree' then
      icon_char, icon_hl = '', 'Directory'
    else
      if filetype == 'fugitive' or filetype == 'gitcommit' then
        basename, extension = 'git', 'git'
      else
        basename = fnamemodify(buf_get_name(bufnr), ':t')
        extension = fnamemodify(basename, ':e')
      end

      icon_char, icon_hl = web.get_icon(basename, extension, { default = true })
    end

    if icon_hl and hlexists(icon_hl .. buffer_status) < 1 then
      hl_buffer_icon(buffer_status, icon_hl)
      hl_groups[#hl_groups + 1] = { buffer_status = buffer_status, icon_hl = icon_hl }
    end

    return icon_char, icon_hl .. buffer_status
  end,
}
