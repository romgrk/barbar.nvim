--
-- persistence.lua
--

local PERSISTENCE = {}

local function save_session()
  vim.fn.timer_start(1000, function()
    vim.api.nvim_exec_autocmds('User', { pattern = 'SessionSavePre' })

    require('persistence').save()
  end)
end

function PERSISTENCE.setup(opts)
  if not (opts) or not (opts.integrations) or not (opts.integrations.persistence) then
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
        save_session()
      end
    end,
  })
end

return PERSISTENCE
