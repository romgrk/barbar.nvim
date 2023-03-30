" !::exe [So]

" Initialize highlights
function bufferline#highlight#setup()
  lua require'barbar.highlight'.setup()
endfunc

" call bufferline#highlight#setup()
