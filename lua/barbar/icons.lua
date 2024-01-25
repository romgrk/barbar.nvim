--
-- get-icon.lua
--

local table_insert = table.insert

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local hlexists = vim.fn.hlexists --- @type function

local hl = require('barbar.utils.highlight')
local utils = require('barbar.utils')

--- @type boolean, {get_icon: fun(name: string, ext?: string, opts?: {default: nil|boolean}): string, string}
local ok, web = pcall(require, 'nvim-web-devicons')

--- Sets the highlight group used for a type of buffer's file icon
--- @param buffer_status barbar.buffer.activity.name
--- @param icon_hl string
--- @return nil
local function hl_buffer_icon(buffer_status, icon_hl)
  local buffer_status_hl = {'Buffer' .. buffer_status}
  hl.set(
    icon_hl .. buffer_status,
    hl.bg_or_default(buffer_status_hl, 'none'),
    hl.fg_or_default({icon_hl}, 'none'),
    hl.sp_or_default(buffer_status_hl, 'none'),
    hl.definition(buffer_status_hl)
  )
end

--- @class barbar.icons.group
--- @field buffer_status barbar.buffer.activity.name the state of the buffer whose icon is being highlighted
--- @field icon_hl string the group to highlight an icon with

--- @type barbar.icons.group[]
local hl_groups = {}

--- @class barbar.Icons
local icons = {}

icons.get_icon = ok and
  --- @param bufnr integer
  --- @param buffer_activity barbar.buffer.activity.name
  --- @return string icon, string highlight_group
  function(bufnr, buffer_activity)
    local basename, extension = '', ''
    local filetype = buf_get_option(bufnr, 'filetype')
    local icon_char, icon_hl = '', 'Buffer'

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

      local char, group = web.get_icon(basename, extension, { default = true })

      if char ~= nil then icon_char = char end
      if group ~= nil then icon_hl = group end
    end

    if icon_hl and hlexists(icon_hl .. buffer_activity) < 1 then
      hl_buffer_icon(buffer_activity, icon_hl)
      table_insert(hl_groups, {buffer_status = buffer_activity, icon_hl = icon_hl})
    end

    return icon_char, icon_hl .. buffer_activity
  end or
  function(_, buffer_activity)
    local invalid_option = utils.markdown_inline_code'icons.filetype.enabled'
    utils.notify_once(
      'barbar.nvim: ' .. invalid_option .. ' is set to ' .. utils.markdown_inline_code'true' ..
        ' but ' .. utils.markdown_inline_code'nvim-web-devicons' .. ' was not found.' ..
        '\nbarbar.nvim: icons have been disabled. Set ' .. invalid_option .. ' to ' ..
        utils.markdown_inline_code'false' .. ' or ' .. 'install ' ..
        utils.markdown_inline_code'nvim-web-devicons' .. 'as a non-optional plugin to prevent this message.',
      vim.log.levels.WARN
    )

    return '', 'Buffer' .. buffer_activity .. 'Icon'
  end

--- Re-highlight all of the groups which have been set before. Checks for updated highlight groups.
--- @return nil
icons.set_highlights = vim.schedule_wrap(function()
  for _, group in ipairs(hl_groups) do
    hl_buffer_icon(group.buffer_status, group.icon_hl)
  end
end)

return icons
