local rshift = bit.rshift
local table_insert = table.insert

local buf_call = vim.api.nvim_buf_call --- @type function
local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local buf_set_var = vim.api.nvim_buf_set_var --- @type function
local command = vim.api.nvim_command --- @type function
local create_augroup = vim.api.nvim_create_augroup --- @type function
local create_autocmd = vim.api.nvim_create_autocmd --- @type function
local defer_fn = vim.defer_fn
local del_autocmd = vim.api.nvim_del_autocmd --- @type function
local exec_autocmds = vim.api.nvim_exec_autocmds --- @type function
local get_option = vim.api.nvim_get_option --- @type function
local schedule_wrap = vim.schedule_wrap
local set_current_buf = vim.api.nvim_set_current_buf --- @type function
local tbl_isempty = vim.tbl_isempty
local win_get_position = vim.api.nvim_win_get_position --- @type function
local win_get_width = vim.api.nvim_win_get_width --- @type function

local bdelete = require('barbar.bbye').bdelete
local config = require('barbar.config')
local highlight_reset_cache = require('barbar.utils.highlight').reset_cache
local highlight_setup = require('barbar.highlight').setup
local jump_mode = require('barbar.jump_mode')
local render = require('barbar.ui.render')
local set_offset = require('barbar.api').set_offset
local state = require('barbar.state')

--- The `<mods>` used for the close click handler
local CLOSE_CLICK_MODS = vim.api.nvim_cmd and { confirm = true } or 'confirm'

--- Whether barbar is currently set up to render.
local enabled = false

--- @class barbar.Events
local events = {}

--- Create and reset autocommand groups associated with this plugin.
--- @param clear? boolean
--- @return integer misc, integer render
function events.augroups(clear)
  if clear == nil then
    clear = true
  end

  return create_augroup('barbar_misc', {clear = clear}),
    create_augroup('barbar_render', {clear = clear})
end

--- What to do when clicking a buffer close button
--- NOTE: must be global -_-
--- @param buffer integer
--- @return nil
function events.close_click_handler(buffer)
  if buf_get_option(buffer, 'modified') then
    buf_call(buffer, function() command('w') end)
    exec_autocmds('BufModifiedSet', {buffer = buffer})
  else
    bdelete(false, buffer, CLOSE_CLICK_MODS)
  end
end

--- Stop listening and responding to various editor events
--- @return nil
events.disable = schedule_wrap(function()
  events.augroups() -- clear the autocommands
  render.set_tabline(nil) -- clear the tabline
  enabled = false -- mark as disabled
end)

--- Start listening and responding to various editor events
--- @return nil
function events.enable()
  local augroup_misc, augroup_render = events.augroups()

  create_autocmd({'VimEnter'}, { callback = state.load_recently_closed, group = augroup_misc })
  create_autocmd({'VimLeave'}, { callback = state.save_recently_closed, group = augroup_misc })

  create_autocmd({'BufNewFile', 'BufReadPost'}, {
    callback = vim.schedule_wrap(function(event)
      jump_mode.assign_next_letter(event.buf)
      state.update_diagnostics(event.buf)
      state.update_gitsigns(event.buf)
    end),
    group = augroup_misc,
  })

  create_autocmd({'BufDelete', 'BufWipeout'}, {
    callback = schedule_wrap(function(tbl)
      jump_mode.unassign_letter_for(tbl.buf)
      state.push_recently_closed(tbl.file)
      render.update()
    end),
    group = augroup_render,
  })

  create_autocmd('ColorScheme', {
    callback = function()
      highlight_reset_cache()
      highlight_setup()
    end,
    group = augroup_misc,
  })

  create_autocmd('BufModifiedSet', {
    callback = function(tbl)
      local is_modified = buf_get_option(tbl.buf, 'modified')
      if is_modified ~= vim.b[tbl.buf].checked then
        buf_set_var(tbl.buf, 'checked', is_modified)
        render.update()
      end
    end,
    group = augroup_render,
  })

  create_autocmd({'BufEnter', 'BufNew'}, {
    callback = function() render.update(true) end,
    group = augroup_render,
  })

  create_autocmd(
    {
      'BufEnter', 'BufWinEnter', 'BufWinLeave', 'BufWritePost',
      'TabEnter',
      'VimResized',
      'WinEnter', 'WinLeave',
    },
    {
      callback = function() render.update() end,
      group = augroup_render,
    }
  )

  create_autocmd('DiagnosticChanged', {
    callback = function(event)
      state.update_diagnostics(event.buf)
      render.update()
    end,
    group = augroup_render,
  })

  create_autocmd('User', {
    callback = vim.schedule_wrap(function(event)
      state.update_gitsigns(event.buf)
      render.update()
    end),
    group = augroup_render,
    pattern = 'GitSignsUpdate',
  })

  if not tbl_isempty(config.options.sidebar_filetypes) then
    --- The `middle` column of the screen
    --- @type integer
    local middle

    --- Sets the `middle` of the screen
    local function set_middle()
      middle = rshift(get_option('columns'), 1) -- PERF: faster than math.floor(&columns / 2)
    end

    create_autocmd('VimResized', {callback = set_middle, group = augroup_misc})
    set_middle()

    local widths = {
      left = {}, --- @type {[string]: nil|integer}
      right = {}, --- @type {[string]: nil|integer}
    }

    --- @param side side
    --- @return integer total_width
    local function total_widths(side)
      local offset = 0
      local win_separator_width = side == 'left' and 1 or 2 -- It looks better like this… don't ask me why
      for _, width in pairs(widths[side]) do
        offset = offset + width + win_separator_width
      end

      -- we want the offset to begin ON the first win separator
      -- WARN: don't use `win_separator` here
      return offset - 1
    end

    for ft, option in pairs(config.options.sidebar_filetypes) do
      create_autocmd('FileType', {
        callback = function(tbl)
          local bufwinid --- @type nil|integer
          local side --- @type side
          local autocmd = create_autocmd({'BufWinEnter', 'WinScrolled'}, {
            callback = function()
              if bufwinid == nil then
                bufwinid = vim.fn.bufwinid(tbl.buf)
              end

              local col = win_get_position(bufwinid)[2]
              local other_side
              if col < middle then
                side, other_side = 'left', 'right'
              else
                side, other_side = 'right', 'left'
              end

              local width = win_get_width(bufwinid)
              if width ~= widths[ft] then
                widths[side][ft] = width
                widths[other_side][ft] = nil
                set_offset(total_widths(side), option.text, nil, side)
              end
            end,
            group = augroup_render,
          })

          create_autocmd(option.event or 'BufWinLeave', {
            buffer = tbl.buf,
            callback = function()
              widths[side][ft] = nil
              set_offset(total_widths(side), nil, nil, side)
              del_autocmd(autocmd)
            end,
            group = augroup_render,
            once = true,
          })
        end,
        group = augroup_misc,
        pattern = ft,
      })
    end
  end

  create_autocmd('OptionSet', {
    callback = function() render.update() end,
    group = augroup_render,
    pattern = 'buflisted',
  })

  create_autocmd('SessionLoadPost', {
    callback = vim.schedule_wrap(function()
      local restore_cmd = vim.g.Bufferline__session_restore
      if restore_cmd then command(restore_cmd) end

      render.update(true)
    end),
    group = augroup_render,
  })

  create_autocmd('TermOpen', {
    callback = function() defer_fn(function() render.update(true) end, 500) end,
    group = augroup_render,
  })

  create_autocmd('User', {
    callback = function()
      local relative = require('barbar.fs').relative

      --- List of open buffers, along with relevant data
      local buffers = {}

      for _, bufnr in ipairs(state.buffers) do
        table_insert(buffers, {
          name = relative(buf_get_name(bufnr)),
          pinned = state.is_pinned(bufnr) or nil,
        })
      end

      vim.g.Bufferline__session_restore = "lua require('barbar.state').restore_buffers " ..
        vim.inspect(buffers, {newline = ' ', indent = ''})
    end,
    group = augroup_misc,
    pattern = 'SessionSavePre',
  })

  create_autocmd('WinClosed', {
    callback = schedule_wrap(render.update),
    group = augroup_render,
  })

  -- TODO: merge the `vim.cmd` calls and references to `vim.g.bufferline` when v2 releases
  vim.schedule(function()
    vim.cmd [[
      silent! call dictwatcherdel(g:, 'bufferline', 'barbar#events#dict_changed')
      silent! call dictwatcherdel(g:bufferline, '*', 'barbar#events#on_option_changed')
    ]]

    local g_bufferline = vim.g.bufferline
    if type(g_bufferline) ~= 'table' or vim.tbl_islist(g_bufferline) then
      vim.g.bufferline = vim.empty_dict()
    end

    vim.cmd [[
      call dictwatcheradd(g:, 'bufferline', 'barbar#events#dict_changed')
      call dictwatcheradd(g:bufferline, '*', 'barbar#events#on_option_changed')
    ]]
  end)

  render.update()
  enabled = true
end

--- What to do when clicking a buffer label
--- NOTE: must be global -_-
--- @param bufnr integer the buffer number
--- @param btn string
--- @return nil
function events.main_click_handler(bufnr, _, btn, _)
  if bufnr == 0 then
    return
  end

  -- NOTE: in Vimscript this was not `==`, it was a regex compare `=~`
  if btn == 'm' then
    bdelete(false, bufnr)
  else
    render.set_current_win_listed_buffer()
    set_current_buf(bufnr)
  end
end

--- What to do when the user configuration changes
--- TODO: remove in v2; it can all go in `setup`
--- @param user_config? table
--- @return nil
function events.on_option_changed(user_config)
  config.setup(user_config) -- NOTE: must be first `setup` called here
  highlight_setup()
  jump_mode.set_letters(config.options.letters)

  -- Don't jump-start barbar if it is disabled
  if enabled then
    render.update(true)
  end
end

-- HACK: This is the only way to implement `dictwatcheradd` for global
--       variables in Lua. The devs said in neovim/neovim#18393 and
--       neovim/neovim#21469 that this is intended, no matter how hacky
--       it is.
do
  --- The `vim.g` functionality
  local vim_g_metatable = getmetatable(vim.g)

  --- The `vim.g.foo = bar` function
  local vim_g_metatable__newindex = vim_g_metatable.__newindex

  --- @param tbl table
  --- @param k string
  --- @param v any
  function vim_g_metatable.__newindex(tbl, k, v)
    if k == 'bufferline' and (type(v) ~= 'table' or vim.tbl_islist(v)) then
      v = vim.empty_dict()
    end

    vim_g_metatable__newindex(tbl, k, v)
  end
end

return events
