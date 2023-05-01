--
-- persistence.lua
--

local SESSION_AUTO_SAVE = {}

local function save_functions(opts)
  local m = opts.integrations.session_managers
  if m.persistence then
    return require("persistence").save
  elseif m.neovim_session_manager then
    return function() vim.cmd("SessionManager save_current_session") end
  end
end

local function save_session(save_function)
  vim.fn.timer_start(150, function()
    vim.api.nvim_exec_autocmds('User', { pattern = 'SessionSavePre' })

    save_function()
  end)
end

function SESSION_AUTO_SAVE.setup(opts)
  if not (opts) or not (opts.integrations) or not(opts.integrations.session_managers) then
    return
  end

  vim.g.barbar_vim_exiting = false

  vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
    pattern = '*',
    callback = function()
      vim.g.barbar_vim_exiting = true
    end,
  })

  -- TODO: i need to call save_session for those events too, how can i do that?
  local events = { 'BufferMove', 'BufferMovePrevious', 'BufferMoveNext' }

  vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufDelete' }, {
    pattern = '*',
    callback = function(ft)
      if vim.g.barbar_vim_exiting == false and ft.file and ft.file ~= '' then
        save_session(save_functions(opts))
      end
    end,
  })
end

return SESSION_AUTO_SAVE
