function! bufferline#enable()
  BarbarEnable
endfunc

function! bufferline#disable()
  BarbarDisable
endfunc

"========================
" Section: Main functions
"========================

function! bufferline#update(...)
  call luaeval("require'bufferline.render'.update(_A)", get(a:, 1, v:null))
endfu

function! bufferline#update_async(...)
  call timer_start(get(a:, 2, 1), {-> luaeval("require'bufferline.render'.update(_A)", get(a:, 1, v:null))})
endfu

function! bufferline#render(update_names) abort
  call bufferline#update(update_names)
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
  call luaeval("require'bufferline.render'.close_buffer_animated(_A)", a:abuf)
endfunc

function! bufferline#close_direct(abuf)
  call luaeval("require'bufferline.render'.close_buffer(_A)", a:abuf)
endfunc
