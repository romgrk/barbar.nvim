--
-- get-icon.lua
--

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local command = vim.api.nvim_command --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local hlexists = vim.fn.hlexists --- @type function

local utils = require'bufferline.utils'
local hl = utils.hl

--- @type boolean, {get_icon: fun(name: string, ext?: string, opts?: {default: nil|boolean}): string, string}
local ok, web = pcall(require, 'nvim-web-devicons')

--- Sets the highlight group used for a type of buffer's file icon
--- @param buffer_status bufferline.buffer.activity.name
--- @param icon_hl string
--- @return nil
local function hl_buffer_icon(buffer_status, icon_hl)
  hl.set(
    icon_hl .. buffer_status,
    hl.bg_or_default({'Buffer' .. buffer_status}, 'none'),
    hl.fg_or_default({icon_hl}, 'none')
  )
end

--- @class bufferline.icons.group
--- @field buffer_status bufferline.buffer.activity.name the state of the buffer whose icon is being highlighted
--- @field icon_hl string the group to highlight an icon with

--- @type bufferline.icons.group[]
local hl_groups = {}

--- @class bufferline.icons
local icons = {
  --- Re-highlight all of the groups which have been set before. Checks for updated highlight groups.
  --- @return nil
  set_highlights = function()
    for _, group in ipairs(hl_groups) do
      hl_buffer_icon(group.buffer_status, group.icon_hl)
    end
  end,

  --- @param bufnr integer
  --- @param buffer_status bufferline.buffer.activity.name
  --- @return string icon, string highlight_group
  get_icon = function(bufnr, buffer_status)
    if ok == false then
      utils.notify(
        'barbar: bufferline.icons is set to v:true but "nvim-dev-icons" was not found.' ..
          '\nbarbar: icons have been disabled. Set `bufferline.icons` to `false` or ' ..
          'install "nvim-dev-icons" to disable this message.',
        vim.log.levels.WARN
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

return icons
