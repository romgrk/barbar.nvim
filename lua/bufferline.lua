-------------------------------
-- Section: `bufferline` module
-------------------------------

--- @class bufferline
local bufferline = {}

--------------------------
-- Section: Helpers
--------------------------

--- Create and reset autocommand groups associated with this plugin.
--- @return number bufferline, number bufferline_update
local function create_augroups()
  return vim.api.nvim_create_augroup('bufferline', {}), vim.api.nvim_create_augroup('bufferline_update', {})
end

--------------------------
-- Section: Event handlers
--------------------------

--- What to do when a buffer is closed.
--- @param bufnr number the number of the buffer which was closed
local function on_buffer_close(bufnr)
  require'bufferline.jump_mode'.unassign_letter_for(bufnr)
  bufferline.update_async()
end

--- Check whether the current buffer has been checked after modification.
--- If not, update the bufferline.
local function check_modified()
  if vim.bo.modified ~= vim.b.checked then
    vim.b.checked = vim.bo.modified
    bufferline.update()
  end
end

--- Enable the bufferline.
function bufferline.enable()
  local augroup_bufferline, augroup_bufferline_update = create_augroups()
  local highlight = require 'bufferline.highlight'

  vim.api.nvim_create_autocmd({'BufNewFile', 'BufReadPost'}, {
    callback = function(tbl) require'bufferline.jump_mode'.assign_next_letter(tbl.buf) end,
    group = augroup_bufferline,
  })

  vim.api.nvim_create_autocmd('BufDelete', {
    callback = function(tbl) on_buffer_close(tbl.buf) end,
    group = augroup_bufferline,
  })

  vim.api.nvim_create_autocmd({'ColorScheme', 'VimEnter'}, {
    callback = highlight.setup,
    group = augroup_bufferline,
  })

  vim.api.nvim_create_autocmd(
    vim.fn.exists '##BufModifiedSet' > 0 and 'BufModifiedSet' or {'BufWritePost', 'TextChanged'},
    {
      callback = function() check_modified() end,
      group = augroup_bufferline,
    }
  )

  vim.api.nvim_create_autocmd('User', {
    callback = function() require'bufferline.state'.on_pre_save() end,
    group = augroup_bufferline,
    pattern = 'SessionSavePre',
  })

  vim.api.nvim_create_autocmd('BufNew', {
    callback = function() bufferline.update(true) end,
    group = augroup_bufferline_update,
  })

  vim.api.nvim_create_autocmd(
    {'BufEnter', 'BufWinEnter', 'BufWinLeave', 'BufWipeout', 'BufWritePost', 'SessionLoadPost', 'VimResized', 'WinEnter', 'WinLeave'},
    {
      callback = function() bufferline.update() end,
      group = augroup_bufferline_update,
    }
  )

  vim.api.nvim_create_autocmd('OptionSet', {
    callback = function() bufferline.update() end,
    group = augroup_bufferline_update,
    pattern = 'buflisted',
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    callback = function() bufferline.update_async() end,
    group = augroup_bufferline_update,
  })

  vim.api.nvim_create_autocmd('TermOpen', {
    callback = function() bufferline.update_async(true, 500) end,
    group = augroup_bufferline_update,
  })

  highlight.setup()
  bufferline.update()
end

--- Disable the bufferline.
function bufferline.disable()
  create_augroups()
   vim.opt.tabline = ''
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
--- @param delay number|nil the number of milliseconds to defer updating the bufferline.
function bufferline.update_async(update_names, delay)
  vim.defer_fn(function() bufferline.update(update_names or false) end, delay or 1)
end

--- Render the bufferline.
--- @param update_names boolean if `true`, update the names of the buffers in the bufferline.
function bufferline.render(update_names)
  local result = require'bufferline.render'.render_safe(update_names)

  if result[1] then
    return result[2]
  end

  local err = result[2]

  vim.api.nvim_command 'BarbarDisable'
  vim.notify(
    "Barbar detected an error while running. Barbar disabled itself :/" ..
      "Include this in your report: " ..
      tostring(err),
    vim.log.levels.ERROR,
    {title = 'barbar.nvim'}
  )
end

return bufferline
