function! bufferline#events#dict_changed(_dict, _key, changes) abort
  silent! call dictwatcherdel(a:changes.old, '*', 'bufferline#events#on_option_changed')
  call dictwatcheradd(a:changes.new, '*', 'bufferline#events#on_option_changed')
  call bufferline#events#on_option_changed(a:changes.new, v:null, v:null)
endfunction

" TODO: get rid of this and use `v:lua` after raising minimum Neovim ver > 0.7
function! bufferline#events#close_click_handler(minwid, _clicks, _btn, _modifiers) abort
  call luaeval("require'bufferline.events'.close_click_handler(_A)", a:minwid)
endfunction

" TODO: get rid of this and use `v:lua` after raising minimum Neovim ver > 0.7
function! bufferline#events#main_click_handler(minwid, _clicks, btn, _modifiers) abort
  call luaeval("require'bufferline.events'.main_click_handler(_A[1], nil, _A[2])", [a:minwid, a:btn])
endfunction

function! bufferline#events#on_option_changed(dict, _1, _2) abort
  call luaeval("require'bufferline.events'.on_option_changed(_A)", a:dict)
endfunction
