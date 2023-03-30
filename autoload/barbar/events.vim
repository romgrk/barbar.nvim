function! barbar#events#dict_changed(_dict, _key, changes) abort
  silent! call dictwatcherdel(a:changes.old, '*', 'barbar#events#on_option_changed')
  call dictwatcheradd(a:changes.new, '*', 'barbar#events#on_option_changed')
  call barbar#events#on_option_changed(a:changes.new, v:null, v:null)
endfunction

" TODO: get rid of this and use `v:lua` after raising minimum Neovim ver > 0.7
function! barbar#events#close_click_handler(minwid, _clicks, _btn, _modifiers) abort
  call luaeval("require'barbar.events'.close_click_handler(_A)", a:minwid)
endfunction

" TODO: get rid of this and use `v:lua` after raising minimum Neovim ver > 0.7
function! barbar#events#main_click_handler(minwid, _clicks, btn, _modifiers) abort
  call luaeval("require'barbar.events'.main_click_handler(_A[1], nil, _A[2])", [a:minwid, a:btn])
endfunction

function! barbar#events#on_option_changed(dict, _1, _2) abort
  lua require'barbar.utils'.notify_once("`g:bufferline` is deprecated, use `require'barbar'.setup` instead. See `:h barbar-setup` for more information.", vim.log.levels.WARN)
  call luaeval("require'barbar.events'.on_option_changed(_A)", a:dict)
endfunction
