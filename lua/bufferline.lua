local command = vim.api.nvim_command
local create_user_command = vim.api.nvim_create_user_command
local get_current_buf = vim.api.nvim_get_current_buf

--- @type bufferline.api
local api = require'bufferline.api'

--- @type bbye
local bbye = require'bufferline.bbye'

--- @type bufferline.highlight
local highlight = require'bufferline.highlight'

--- @type bufferline.JumpMode
local JumpMode = require'bufferline.jump_mode'

--- @type bufferline.options
local options = require'bufferline.options'

--- @type bufferline.render
local render = require'bufferline.render'

--- @type bufferline.state
local state = require'bufferline.state'

-------------------------------
-- Section: `bufferline` module
-------------------------------

--- @class bufferline
local bufferline = {}

--- Setup this plugin.
--- @param user_config? table
function bufferline.setup(user_config)
  -- Show the tabline
  vim.opt.showtabline = 2

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
    function(tbl) api.goto_buffer(tonumber(tbl.args) or 1) end,
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

  create_user_command(
    'BufferMoveStart',
    function() api.move_current_buffer_to(1) end,
    {desc = 'Move current buffer to the front'}
  )

  create_user_command('BufferPick', api.pick_buffer, {desc = 'Pick a buffer'})

  create_user_command('BufferPickDelete', api.pick_buffer_delete, {desc = 'Pick buffers to delete'})

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
      bbye.bdelete(tbl.bang, tbl.args, tbl.smods or tbl.mods, focus_buffer)
    end,
    {bang = true, complete = 'buffer', desc = 'Close the current buffer.', nargs = '?'}
  )

  create_user_command(
    'BufferDelete',
    function(tbl) bbye.bdelete(tbl.bang, tbl.args, tbl.smods or tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Synonym for `:BufferClose`', nargs = '?'}
  )

  create_user_command(
    'BufferWipeout',
    function(tbl) bbye.bwipeout(tbl.bang, tbl.args, tbl.smods or tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Wipe out the buffer', nargs = '?'}
  )

  create_user_command(
    'BufferCloseAllButCurrent',
    api.close_all_but_current,
    {desc = 'Close every buffer except the current one'}
  )

  create_user_command(
    'BufferCloseAllButVisible',
    api.close_all_but_visible,
    {desc = 'Close every buffer except those in visible windows'}
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
  vim.g.bufferline = user_config or vim.empty_dict()

  highlight.setup()
  JumpMode.set_letters(options.letters())
  render.enable()
end

return bufferline
