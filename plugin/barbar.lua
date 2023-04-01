-- File: barbar.vim
-- Author: romgrk
-- Description: Buffer line
-- Date: Fri 22 May 2020 02:22:36 AM EDT
-- !::exe [So]

local user_config = vim.g.bufferline

if user_config then
  require'barbar.utils'.notify_once(
    "`g:bufferline` is deprecated, use `require'barbar'.setup` instead. " ..
      'See `:h barbar-setup` for more information.',
    vim.log.levels.WARN
  )
end

if require'barbar.config'.did_initialize == false then
  require'bufferline'.setup(user_config)
end
