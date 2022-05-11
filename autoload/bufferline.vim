function! bufferline#enable()
  lua require'bufferline'.enable()
endfunc

function! bufferline#disable()
  lua require'bufferline'.disable()
endfunc

"========================
" Section: Main functions
"========================

function! bufferline#update(...)
  lua require'bufferline'.update(...)
endfu

function! bufferline#update_async(...)
  lua require'bufferline'.update_async(...)
endfu

function! bufferline#render(update_names) abort
  lua require'bufferline'.render(update_names)
endfu

function! bufferline#pick_buffer()
  BufferPick
endfunc

function! bufferline#order_by_buffer_number()
  BufferOrderByBufferNumber
endfunc

function! bufferline#order_by_directory()
  BuferOrderByDirectory
endfunc

function! bufferline#order_by_language()
  BufferOrderByLanguage
endfunc

function! bufferline#order_by_window_number()
  BufferOrderByWindowNumber
endfunc

function! bufferline#close(abuf)
  call luaeval("require'bufferline.state'.close_buffer_animated(_A)", a:abuf)
endfunc

function! bufferline#close_direct(abuf)
  call luaeval("require'bufferline.state'.close_buffer(_A)", a:abuf)
endfunc
