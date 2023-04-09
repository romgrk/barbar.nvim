-- File: barbar.vim
-- Author: romgrk
-- Description: Buffer line
-- Date: Fri 22 May 2020 02:22:36 AM EDT
-- !::exe [So]

if vim.g.barbar_auto_setup ~= false then
  local options = vim.g.bufferline

  if options then
    require('barbar.utils').notify_once(
      "`g:bufferline` is deprecated, use `require('barbar').setup` instead. " ..
        'See `:h barbar-setup` for more information.',
      vim.log.levels.WARN
    )
  end

  require('barbar').setup(options)
end
