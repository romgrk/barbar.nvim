" !::exe [So]

" Initialize highlights
function bufferline#highlight#setup()
  lua require'bufferline.highlight'.setup()
endfunc

" call bufferline#highlight#setup()
