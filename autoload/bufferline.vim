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
  call luaeval("require'bufferline'.update(_A)", get(a:, 1, v:null))
endfu

function! bufferline#update_async(...)
  call luaeval("require'bufferline'.update_async(_A[1], _A[2])", [get(a:, 1, v:null), get(a:, 2, v:null)])
endfu

function! bufferline#render(update_names) abort
  call luaeval("require'bufferline'.render(_A)", a:update_names)
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
