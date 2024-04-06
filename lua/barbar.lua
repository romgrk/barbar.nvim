local max = math.max
local table_insert = table.insert

local bufnr = vim.fn.bufnr --- @type function
local command = vim.api.nvim_command --- @type function
local create_user_command = vim.api.nvim_create_user_command --- @type function
local set_option = vim.api.nvim_set_option --- @type function

local api = require('barbar.api')
local bbye = require('barbar.bbye')
local events = require('barbar.events')
local markdown_inline_code = require('barbar.utils').markdown_inline_code
local notify = require('barbar.utils').notify
local scroll = require('barbar.ui.render').scroll
local state = require('barbar.state')

-------------------------------
-- Section: `barbar` module
-------------------------------

--- @class Barbar
local barbar = {}

--- Setup this plugin.
--- @param options? table
--- @return nil
function barbar.setup(options)
  -- Create all necessary commands
  create_user_command('BarbarEnable', events.enable, {desc = 'Enable barbar.nvim'})
  create_user_command('BarbarDisable', events.disable, {desc = 'Disable barbar.nvim'})

  create_user_command(
    'BufferNext',
    function(tbl) api.goto_buffer_relative(max(1, tbl.count)) end,
    {count = true, desc = 'Go to the next buffer'}
  )

  create_user_command(
    'BufferPrevious',
    function(tbl) api.goto_buffer_relative(-max(1, tbl.count)) end,
    {count = true, desc = 'Go to the previous buffer'}
  )

  create_user_command(
    'BufferGoto',
    function(tbl)
      local index = tonumber(tbl.args)
      if not index then
        return notify(
          'Invalid argument to ' .. markdown_inline_code':BufferGoto',
          vim.log.levels.ERROR
        )
      end

      api.goto_buffer(index)
    end,
    {
      complete = function()
        local buffers = state.buffers
        local buffer_indices = {}

        for i in ipairs(buffers) do
          table_insert(buffer_indices, tostring(i))
        end

        for i = -#buffers, -1 do
          table.insert(buffer_indices, tostring(i))
        end

        return buffer_indices
      end,
      desc = 'Go to the buffer at the specified index',
      nargs = 1,
    }
  )

  create_user_command('BufferFirst', 'BufferGoto 1', {desc = 'Go to the first buffer'})
  create_user_command('BufferLast', 'BufferGoto -1', {desc = 'Go to the last buffer'})

  create_user_command(
    'BufferMove',
    vim.api.nvim_cmd and
      function(tbl) vim.cmd.BufferMovePrevious {count = tbl.count} end or
      function(tbl) command('BufferMovePrevious ' .. tbl.count) end,
    {count = true, desc = 'Synonym for ' .. markdown_inline_code':BufferMovePrevious'}
  )

  create_user_command(
    'BufferMoveNext',
    function(tbl) api.move_current_buffer(max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the right'}
  )

  create_user_command(
    'BufferMovePrevious',
    function(tbl) api.move_current_buffer(-max(1, tbl.count)) end,
    {count = true, desc = 'Move the current buffer to the left'}
  )

  create_user_command(
    'BufferMoveStart',
    function() api.move_current_buffer_to(1) end,
    {desc = 'Move current buffer to the front'}
  )

  create_user_command('BufferPick', api.pick_buffer, {desc = 'Pick a buffer'})

  create_user_command(
    'BufferPickDelete',
    function(cmd)
      local count = cmd.count
      if count < 1 then
        count = math.huge
      end

      api.pick_buffer_delete(count, cmd.bang)
    end,
    {bang = true, count = true, desc = 'Pick buffers to delete'}
  )

  create_user_command(
    'BufferPin',
    function(tbl) api.toggle_pin(tbl.fargs[1] and bufnr(tbl.fargs[1])) end,
    {complete = 'buffer', desc = 'Un/pin a buffer', nargs = '?'}
  )

  create_user_command(
    'BufferOrderByBufferNumber',
    api.order_by_buffer_number,
    {desc = 'Order the bufferline by buffer number'}
  )

  create_user_command(
    'BufferOrderByName',
    api.order_by_name,
    {desc = 'Order the bufferline by name'}
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

  for cmd, desc in pairs {
    Close = 'Close the current buffer',
    Delete = 'Synonym for `:BufferClose`',
  } do
    create_user_command(
      'Buffer' .. cmd,
      function(tbl) bbye.bdelete(tbl.bang, tbl.args, tbl.smods or tbl.mods) end,
      {bang = true, complete = 'buffer', desc = desc, nargs = '?'}
    )
  end

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
    function(tbl) scroll(-max(1, tbl.count)) end,
    {count = true, desc = 'Scroll the bufferline left'}
  )

  create_user_command(
    'BufferScrollRight',
    function(tbl) scroll(max(1, tbl.count)) end,
    {count = true, desc = 'Scroll the bufferline right'}
  )

  create_user_command(
    'BufferRestore',
    api.restore_buffer,
    {desc = 'Restore the last recently closed buffer'}
  )

  -- Setup barbar
  events.on_option_changed(options)
  events.enable()

  -- Show the tabline
  set_option('showtabline', 2)
end

return barbar
