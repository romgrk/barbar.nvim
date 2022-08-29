local buf_call = vim.api.nvim_buf_call
local buf_get_option = vim.api.nvim_buf_get_option
local command = vim.api.nvim_command
local create_user_command = vim.api.nvim_create_user_command
local exec_autocmds = vim.api.nvim_exec_autocmds
local get_current_buf = vim.api.nvim_get_current_buf
local tbl_extend = vim.tbl_extend
local validate = vim.validate

local bbye = require'bufferline.bbye'
local highlight = require'bufferline.highlight'
local JumpMode = require'bufferline.jump_mode'
local render = require'bufferline.render'
local state = require'bufferline.state'

--- The default options for this plugin.
local DEFAULT_OPTIONS = {
  animation = true,
  auto_hide = false,
  clickable = true,
  closable = true,
  exclude_ft = nil,
  exclude_name = nil,
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
}

--------------------------
-- Section: Helpers
--------------------------

-------------------------------
-- Section: `bufferline` module
-------------------------------

--- @class bufferline
local bufferline = {}

--- Setup this plugin.
--- @param options nil|table
function bufferline.setup(options)
  -- Show the tabline
  vim.opt.showtabline = 2

  -- Create all necessary commands
  create_user_command('BarbarEnable', render.enable, {desc = 'Enable barbar.nvim'})
  create_user_command('BarbarDisable', render.disable, {desc = 'Disable barbar.nvim'})

  create_user_command(
    'BufferNext',
    function(tbl) render.goto_buffer_relative(math.max(1, tbl.count)) end,
    {count = true, desc = 'Go to the next buffer'}
  )

  create_user_command(
    'BufferPrevious',
    function(tbl) render.goto_buffer_relative(-math.max(1, tbl.count)) end,
    {count = true, desc = 'Go to the previous buffer'}
  )

  create_user_command(
    'BufferGoto',
    function(tbl)
      local index = tbl.args
      validate {index = {index, 'number'}}
      render.goto_buffer(tonumber(index))
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
    function(tbl) render.move_current_buffer(math.max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the right'}
  )

  create_user_command(
    'BufferMovePrevious',
    function(tbl) render.move_current_buffer(-math.max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the left'}
  )

  create_user_command('BufferPick', render.activate_jump_mode, {desc = 'Pick a buffer'})

  create_user_command('BufferPin', function() render.toggle_pin() end, {desc = 'Un/pin a buffer'})

  create_user_command(
    'BufferOrderByBufferNumber',
    render.order_by_buffer_number,
    {desc = 'Order the bufferline by buffer number'}
  )

  create_user_command(
    'BufferOrderByDirectory',
    render.order_by_directory,
    {desc = 'Order the bufferline by directory'}
  )

  create_user_command('BufferOrderByLanguage', render.order_by_language, {desc = 'Order the bufferline by language'})

  create_user_command(
    'BufferOrderByWindowNumber',
    render.order_by_window_number,
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
    render.close_all_but_current,
    {desc = 'Close every buffer except the current one'}
  )

  create_user_command(
    'BufferCloseAllButPinned',
    render.close_all_but_pinned,
    {desc = 'Close every buffer except pinned buffers'}
  )

  create_user_command(
    'BufferCloseAllButCurrentOrPinned',
    render.close_all_but_current_or_pinned,
    {desc = 'Close every buffer except pinned buffers or the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersLeft',
    render.close_buffers_left,
    {desc = 'Close all buffers to the left of the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersRight',
    render.close_buffers_right,
    {desc = 'Close all buffers to the right of the current buffer'}
  )

  create_user_command(
    'BufferScrollLeft',
    function(tbl) render.set_scroll(math.max(0, render.scroll - math.max(1, tbl.count))) end,
    {count = true, desc = 'Scroll the bufferline left'}
  )

  create_user_command(
    'BufferScrollRight',
    function(tbl) render.set_scroll(render.scroll + math.max(1, tbl.count)) end,
    {count = true, desc = 'Scroll the bufferline right'}
  )

  -- Set the options and watchers for when they are edited
  vim.g.bufferline = options and tbl_extend('keep', options, DEFAULT_OPTIONS) or DEFAULT_OPTIONS

  highlight.setup()
  render.enable()
end

----------------------------
-- Section: Bufferline state
----------------------------

--- Last value for tabline
--- @type nil|string
local last_tabline

-- Debugging
-- let g:events = []

--- Clears the tabline. Does not stop the tabline from being redrawn via autocmd.
--- @param tabline nil|string
function bufferline.set_tabline(tabline)
  last_tabline = tabline
  vim.opt.tabline = last_tabline
end

--------------------------
-- Section: Main functions
--------------------------

--------------------------
-- Section: Event handlers
--------------------------

--- What to do when clicking a buffer close button.
--- @param buffer integer
function bufferline.close_click_handler(buffer)
  if buf_get_option(buffer, 'modified') then
    buf_call(buffer, function() command('w') end)
    exec_autocmds('BufModifiedSet', {buffer = buffer})
  else
    bbye.bdelete(false, buffer)
  end
end

--- What to do when clicking a buffer label.
--- @param minwid integer the buffer nummber
--- @param btn string
function bufferline.main_click_handler(minwid, _, btn, _)
  if minwid == 0 then
    return
  end

  -- NOTE: in Vimscript this was not `==`, it was a regex compare `=~`
  if btn == 'm' then
    bbye.bdelete(false, minwid)
  else
    render.open_buffer_in_listed_window(minwid)
  end
end

--- What to do when `vim.g.bufferline` is changed.
--- @param key string what option was changed.
function bufferline.on_option_changed(_, key, _)
  vim.g.bufferline = tbl_extend('keep', vim.g.bufferline or {}, DEFAULT_OPTIONS)
  if key == 'letters' then
    JumpMode.set_letters(vim.g.bufferline.letters)
  end
end

return bufferline
