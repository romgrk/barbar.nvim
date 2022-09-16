local command = vim.api.nvim_command
local create_user_command = vim.api.nvim_create_user_command
local get_current_buf = require'bufferline.utils'.get_current_buf
local tbl_extend = vim.tbl_extend
local validate = vim.validate

--- @type bufferline.api
local api = require'bufferline.api'

--- @type bbye
local bbye = require'bufferline.bbye'

--- @type bufferline.highlight
local highlight = require'bufferline.highlight'

--- @type bufferline.JumpMode
local JumpMode = require'bufferline.jump_mode'

--- @type bufferline.render
local render = require'bufferline.render'

--- @type bufferline.state
local state = require'bufferline.state'

--- @class bufferline.Options the available options for this plugin, and their defaults.
--- @field exclude_ft string[]
--- @field exclude_name string[]
local DEFAULT_OPTIONS = {
  animation = true,
  auto_hide = false,
  clickable = true,
  closable = true,
  exclude_ft = {},
  exclude_name = {},
  icon_close_tab = '',
  icon_close_tab_modified = '●',
  icon_pinned = '',
  icon_separator_active =   '▎',
  icon_separator_inactive = '▎',
  icons = true,
  icon_custom_colors = false,
  insert_at_start = false,
  insert_at_end = false,
  letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
  maximum_padding = 4,
  maximum_length = 30,
  no_name_title = nil,
  semantic_letters = true,
  tabpages = true,
  use_winbar = false,
  winbar_disabled_filetypes = {},
}

-------------------------------
-- Section: `bufferline` module
-------------------------------

--- @class bufferline
local bufferline = {}

--- Setup this plugin.
--- @param options? bufferline.Options
function bufferline.setup(options)
  -- Create all necessary commands
  create_user_command('BarbarEnable', render.enable, {desc = 'Enable barbar.nvim'})
  create_user_command('BarbarDisable', render.disable, {desc = 'Disable barbar.nvim'})

  create_user_command(
    'BufferNext',
    function(tbl) api.goto_buffer_relative(math.max(1, tbl.count)) end,
    {count = true, desc = 'Go to the next buffer'}
  )

  create_user_command(
    'BufferPrevious',
    function(tbl) api.goto_buffer_relative(-math.max(1, tbl.count)) end,
    {count = true, desc = 'Go to the previous buffer'}
  )

  create_user_command(
    'BufferGoto',
    function(tbl)
      local index = tbl.args
      validate {index = {index, 'number'}}
      api.goto_buffer(index)
    end,
    {desc = 'Go to the buffer at the specified index', nargs = 1}
  )

  create_user_command('BufferFirst', 'BufferGoto 1', {desc = 'Go to the first buffer'})
  create_user_command('BufferLast', 'BufferGoto -1', {desc = 'Go to the last buffer'})

  create_user_command(
    'BufferMove',
    function(tbl) command('BufferMovePrevious ' .. tbl.count) end,
    {count = true, desc = 'Synonym for `:BufferMovePrevious`'}
  )

  create_user_command(
    'BufferMoveNext',
    function(tbl) api.move_current_buffer(math.max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the right'}
  )

  create_user_command(
    'BufferMovePrevious',
    function(tbl) api.move_current_buffer(-math.max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the left'}
  )

  create_user_command('BufferPick', api.pick_buffer, {desc = 'Pick a buffer'})

  create_user_command('BufferPin', function() api.toggle_pin() end, {desc = 'Un/pin a buffer'})

  create_user_command(
    'BufferOrderByBufferNumber',
    api.order_by_buffer_number,
    {desc = 'Order the bufferline by buffer number'}
  )

  create_user_command(
    'BufferOrderByDirectory',
    api.order_by_directory,
    {desc = 'Order the bufferline by directory'}
  )

  create_user_command('BufferOrderByLanguage', api.order_by_language, {desc = 'Order the bufferline by language'})

  create_user_command(
    'BufferOrderByWindowNumber',
    api.order_by_window_number,
    {desc = 'Order the bufferline by window number'}
  )

  create_user_command(
    'BufferClose',
    function(tbl)
      local focus_buffer = state.find_next_buffer(get_current_buf())
      bbye.bdelete(tbl.bang, tbl.args, tbl.mods, focus_buffer)
    end,
    {bang = true, complete = 'buffer', desc = 'Close the current buffer.', nargs = '?'}
  )

  create_user_command(
    'BufferDelete',
    function(tbl) bbye.bdelete(tbl.bang, tbl.args, tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Synonym for `:BufferClose`', nargs = '?'}
  )

  create_user_command(
    'BufferWipeout',
    function(tbl) bbye.bwipeout(tbl.bang, tbl.args, tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Wipe out the buffer', nargs = '?'}
  )

  create_user_command(
    'BufferCloseAllButCurrent',
    api.close_all_but_current,
    {desc = 'Close every buffer except the current one'}
  )

  create_user_command(
    'BufferCloseAllButPinned',
    api.close_all_but_pinned,
    {desc = 'Close every buffer except pinned buffers'}
  )

  create_user_command(
    'BufferCloseAllButCurrentOrPinned',
    api.close_all_but_current_or_pinned,
    {desc = 'Close every buffer except pinned buffers or the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersLeft',
    api.close_buffers_left,
    {desc = 'Close all buffers to the left of the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersRight',
    api.close_buffers_right,
    {desc = 'Close all buffers to the right of the current buffer'}
  )

  create_user_command(
    'BufferScrollLeft',
    function(tbl) render.scroll(-math.max(1, tbl.count)) end,
    {count = true, desc = 'Scroll the bufferline left'}
  )

  create_user_command(
    'BufferScrollRight',
    function(tbl) render.scroll(math.max(1, tbl.count)) end,
    {count = true, desc = 'Scroll the bufferline right'}
  )

  -- Set the options and watchers for when they are edited
  vim.g.bufferline = options and tbl_extend('keep', options, DEFAULT_OPTIONS) or DEFAULT_OPTIONS

  -- winbar mode is set up in an autocmd on WinEnter
  -- so that ignored filetypes are respected
  if not vim.g.bufferline.use_winbar then
    -- Show the tabline
    vim.opt.showtabline = 2
  end

  highlight.setup()
  JumpMode.set_letters(vim.g.bufferline.letters)
  render.enable()
end

return bufferline
