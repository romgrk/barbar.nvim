local command = vim.api.nvim_command
local create_augroup = vim.api.nvim_create_augroup
local create_autocmd = vim.api.nvim_create_autocmd
local create_user_command = vim.api.nvim_create_user_command
local buf_get_option = vim.api.nvim_buf_get_option
local defer_fn = vim.defer_fn
local notify = vim.notify
local tbl_extend = vim.tbl_extend

local highlight = require 'bufferline.highlight'

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

--- Create and reset autocommand groups associated with this plugin.
--- @return integer bufferline, integer bufferline_update
local function create_augroups()
  return create_augroup('bufferline', {}), create_augroup('bufferline_update', {})
end

-------------------------------
-- Section: `bufferline` module
-------------------------------

--- @class bufferline
local bufferline = {}

--- Disable the bufferline.
function bufferline.disable()
  create_augroups()
  vim.opt.tabline = ''
end

--- Enable the bufferline.
function bufferline.enable()
  local augroup_bufferline, augroup_bufferline_update = create_augroups()

  create_autocmd({'BufNewFile', 'BufReadPost'}, {
    callback = function(tbl) require'bufferline.jump_mode'.assign_next_letter(tbl.buf) end,
    group = augroup_bufferline,
  })

  create_autocmd('BufDelete', {
    callback = function(tbl)
      require'bufferline.jump_mode'.unassign_letter_for(tbl.buf)
      bufferline.update_async()
    end,
    group = augroup_bufferline,
  })

  create_autocmd('ColorScheme', {callback = highlight.setup, group = augroup_bufferline})

  create_autocmd('BufModifiedSet', {
    callback = function()
      local is_modified = buf_get_option(0, 'modified')
      if is_modified ~= vim.b.checked then
        vim.b.checked = is_modified
        bufferline.update()
      end
    end,
    group = augroup_bufferline,
  })

  create_autocmd('User', {
    callback = function() require'bufferline.state'.on_pre_save() end,
    group = augroup_bufferline,
    pattern = 'SessionSavePre',
  })

  create_autocmd('BufNew', {
    callback = function() bufferline.update(true) end,
    group = augroup_bufferline_update,
  })

  create_autocmd(
    {'BufEnter', 'BufWinEnter', 'BufWinLeave', 'BufWipeout', 'BufWritePost', 'SessionLoadPost', 'VimResized', 'WinEnter', 'WinLeave'},
    {
      callback = function() bufferline.update() end,
      group = augroup_bufferline_update,
    }
  )

  create_autocmd('OptionSet', {
    callback = function() bufferline.update() end,
    group = augroup_bufferline_update,
    pattern = 'buflisted',
  })

  create_autocmd('WinClosed', {
    callback = function() bufferline.update_async() end,
    group = augroup_bufferline_update,
  })

  create_autocmd('TermOpen', {
    callback = function() bufferline.update_async(true, 500) end,
    group = augroup_bufferline_update,
  })

  bufferline.update()
end

--- Setup this plugin.
--- @param options nil|table
function bufferline.setup(options)
  -- Show the tabline
  vim.opt.showtabline = 2

  -- Create all necessary commands
  create_user_command('BarbarEnable', bufferline.enable, {desc = 'Enable barbar.nvim'})
  create_user_command('BarbarDisable', bufferline.disable, {desc = 'Disable barbar.nvim'})

  create_user_command(
    'BufferNext',
    function(tbl) require'bufferline.state'.goto_buffer_relative(math.max(tbl.count, 1)) end,
    {count = true, desc = 'Go to the next buffer'}
  )

  create_user_command(
    'BufferPrevious',
    function(tbl) require'bufferline.state'.goto_buffer_relative(-math.max(tbl.count, 1)) end,
    {count = true, desc = 'Go to the previous buffer'}
  )

  create_user_command(
    'BufferGoto',
    function(tbl) require'bufferline.state'.goto_buffer(tbl.args) end,
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
    function(tbl) require'bufferline.state'.move_current_buffer(math.max(tbl.count, 1)) end,
    {count = true, desc = 'Move the current buffer to the right'}
  )

  create_user_command(
    'BufferMovePrevious',
    function(tbl) require'bufferline.state'.move_current_buffer(-math.max(tbl.count, 1)) end,
    {count = true, desc = 'Move the current buffer to the left'}
  )

  create_user_command('BufferPick', function() require'bufferline.jump_mode'.activate() end, {desc = 'Pick a buffer'})

  create_user_command('BufferPin', function() require'bufferline.state'.toggle_pin() end, {desc = 'Un/pin a buffer'})

  create_user_command(
    'BufferOrderByBufferNumber',
    function() require'bufferline.state'.order_by_buffer_number() end,
    {desc = 'Order the bufferline by buffer number'}
  )

  create_user_command(
    'BufferOrderByDirectory',
    function() require'bufferline.state'.order_by_directory() end,
    {desc = 'Order the bufferline by directory'}
  )

  create_user_command(
    'BufferOrderByLanguage',
    function() require'bufferline.state'.order_by_language() end,
    {desc = 'Order the bufferline by language'}
  )

  create_user_command(
    'BufferOrderByWindowNumber',
    function() require'bufferline.state'.order_by_window_number() end,
    {desc = 'Order the bufferline by window number'}
  )

  create_user_command(
    'BufferClose',
    function(tbl) require'bufferline.bbye'.delete('bdelete', tbl.bang, tbl.args, tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Close the current buffer.', nargs = '?'}
  )

  create_user_command(
    'BufferDelete',
    function(tbl) require'bufferline.bbye'.delete('bdelete', tbl.bang, tbl.args, tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Synonym for `:BufferClose`', nargs = '?'}
  )

  create_user_command(
    'BufferWipeout',
    function(tbl) require'bufferline.bbye'.delete('bwipeout', tbl.bang, tbl.args, tbl.mods) end,
    {bang = true, complete = 'buffer', desc = 'Wipe out the buffer', nargs = '?'}
  )

  create_user_command(
    'BufferCloseAllButCurrent',
    function() require'bufferline.state'.close_all_but_current() end,
    {desc = 'Close every buffer except the current one'}
  )

  create_user_command(
    'BufferCloseAllButPinned',
    function() require'bufferline.state'.close_all_but_pinned() end,
    {desc = 'Close every buffer except pinned buffers'}
  )

  create_user_command(
    'BufferCloseAllButCurrentOrPinned',
    function() require'bufferline.state'.close_all_but_current_or_pinned() end,
    {desc = 'Close every buffer except pinned buffers or the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersLeft',
    function() require'bufferline.state'.close_buffers_left() end,
    {desc = 'Close all buffers to the left of the current buffer'}
  )

  create_user_command(
    'BufferCloseBuffersRight',
    function() require'bufferline.state'.close_buffers_right() end,
    {desc = 'Close all buffers to the right of the current buffer'}
  )

  -- Set the options and watchers for when they are edited
  vim.g.bufferline = options and tbl_extend('keep', options, DEFAULT_OPTIONS) or DEFAULT_OPTIONS

  vim.cmd [[
    " Must be global -_-
    function! BufferlineCloseClickHandler(minwid, clicks, btn, modifiers) abort
      call luaeval("require'bufferline.bbye'.delete('bdelete', false, _A)", a:minwid)
    endfunction

    " Must be global -_-
    function! BufferlineMainClickHandler(minwid, clicks, btn, modifiers) abort
      call luaeval("require'bufferline'.main_click_handler(_A[1], nil, _A[2])", [a:minwid, a:btn])
    endfunction

    " Must be global -_-
    function! BufferlineOnOptionChanged(dict, key, changes) abort
      call luaeval("require'bufferline'.on_option_changed(nil, _A)", a:key)
    endfunction

    call dictwatcheradd(g:bufferline, '*', 'BufferlineOnOptionChanged')
  ]]

  highlight.setup()
  bufferline.enable()
end

----------------------------
-- Section: Bufferline state
----------------------------

-- Last value for tabline
local last_tabline = ''

-- Debugging
-- let g:events = []

--------------------------
-- Section: Main functions
--------------------------

--- Render the bufferline.
--- @param update_names boolean if `true`, update the names of the buffers in the bufferline.
--- @return nil|string tabline a valid `&tabline`
function bufferline.render(update_names)
  local result = require'bufferline.render'.render_safe(update_names)

  if result[1] then
    return result[2]
  end

  local err = result[2]

  bufferline.disable()
  notify(
    "Barbar detected an error while running. Barbar disabled itself :/" ..
      "Include this in your report: " ..
      tostring(err),
    vim.log.levels.ERROR,
    {title = 'barbar.nvim'}
  )
end

--- @param update_names boolean|nil if `true`, update the names of the buffers in the bufferline. Default: false
function bufferline.update(update_names)
  if vim.g.SessionLoad then
    return
  end

  local new_value = bufferline.render(update_names or false)

  if new_value == last_tabline then
    return
  end

  vim.opt.tabline = new_value
  last_tabline = new_value
end

--- Update the bufferline using `vim.defer_fn`.
--- @param update_names boolean|nil if `true`, update the names of the buffers in the bufferline. Default: false
--- @param delay integer|nil the number of milliseconds to defer updating the bufferline.
function bufferline.update_async(update_names, delay)
  defer_fn(function() bufferline.update(update_names or false) end, delay or 1)
end

--------------------------
-- Section: Event handlers
--------------------------

--- What to do when clicking.
--- @param btn string
--- @param minwid integer
function bufferline.main_click_handler(minwid, _, btn, _)
  if minwid == 0 then
    return
  end

  -- NOTE: in Vimscript this was not `==`, it was a regex compare `=~`
  if btn == 'm' then
    require'bufferline.bbye'.delete('bdelete', false, minwid)
  else
    require'bufferline.state'.open_buffer_in_listed_window(minwid)
  end
end

--- What to do when `vim.g.bufferline` is changed.
--- @param key string what option was changed.
function bufferline.on_option_changed(_, key, _)
  vim.g.bufferline = tbl_extend('keep', vim.g.bufferline or {}, DEFAULT_OPTIONS)
  if key == 'letters' then
    require'bufferline.jump_mode'.initialize_indexes()
  end
end

return bufferline
