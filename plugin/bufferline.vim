" File: bufferline.vim
" Author: romgrk
" Description: Buffer line
" Date: Fri 22 May 2020 02:22:36 AM EDT
" !::exe [So]

set showtabline=2

"=================
" Section: Commands
"=================

command!                BarbarEnable           call bufferline#enable()
command!                BarbarDisable          call bufferline#disable()

command! -count   -bang BufferNext             call s:goto_buffer_relative(v:count1)
command! -count   -bang BufferPrevious         call s:goto_buffer_relative(-v:count1)

command! -nargs=1 -bang BufferGoto             call s:goto_buffer(<f-args>)
command!          -bang BufferLast             call s:goto_buffer(-1)

command! -count   -bang BufferMoveNext         call s:move_current_buffer(v:count1)
command! -count   -bang BufferMovePrevious     call s:move_current_buffer(-v:count1)
command! -nargs=1 -bang BufferMove             call s:move_current_buffer_to(<f-args>)

command!          -bang BufferPick             call bufferline#pick_buffer()
command!                BufferPin              lua require'bufferline.state'.toggle_pin()

command!          -bang BufferOrderByBufferNumber   call bufferline#order_by_buffer_number()
command!          -bang BufferOrderByDirectory call bufferline#order_by_directory()
command!          -bang BufferOrderByLanguage  call bufferline#order_by_language()
command!          -bang BufferOrderByWindowNumber    call bufferline#order_by_window_number()

command! -bang -complete=buffer -nargs=?
                      \ BufferClose            call bufferline#bbye#delete('bdelete', <q-bang>, <q-args>, <q-mods>)
command! -bang -complete=buffer -nargs=?
                      \ BufferDelete           call bufferline#bbye#delete('bdelete', <q-bang>, <q-args>, <q-mods>)
command! -bang -complete=buffer -nargs=?
                      \ BufferWipeout          call bufferline#bbye#delete('bwipeout', <q-bang>, <q-args>, <q-mods>)

command!                BufferCloseAllButCurrent            lua require'bufferline.state'.close_all_but_current()
command!                BufferCloseAllButPinned             lua require'bufferline.state'.close_all_but_pinned()
command!                BufferCloseAllButCurrentOrPinned    lua require'bufferline.state'.close_all_but_current_or_pinned()
command!                BufferCloseBuffersLeft              lua require'bufferline.state'.close_buffers_left()
command!                BufferCloseBuffersRight             lua require'bufferline.state'.close_buffers_right()

"=================
" Section: Options
"=================

let s:DEFAULT_OPTIONS = {
\ 'animation': v:true,
\ 'auto_hide': v:false,
\ 'clickable': v:true,
\ 'closable': v:true,
\ 'exclude_ft': v:null,
\ 'exclude_name': v:null,
\ 'icon_close_tab': '',
\ 'icon_close_tab_modified': '●',
\ 'icon_pinned': '',
\ 'icon_separator_active':   '▎',
\ 'icon_separator_inactive': '▎',
\ 'icons': v:true,
\ 'icon_custom_colors': v:false,
\ 'insert_at_start': v:false,
\ 'insert_at_end': v:false,
\ 'letters': 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
\ 'maximum_padding': 4,
\ 'maximum_length': 30,
\ 'no_name_title': v:null,
\ 'semantic_letters': v:true,
\ 'tabpages': v:true,
\}

let bufferline = extend(s:DEFAULT_OPTIONS, get(g:, 'bufferline', {}))

call dictwatcheradd(g:bufferline, '*', 'BufferlineOnOptionChanged')

"========================
" Section: Event handlers
"========================

" Needs to be global -_-
function! BufferlineOnOptionChanged(d, k, z)
   let g:bufferline = extend(s:DEFAULT_OPTIONS, get(g:, 'bufferline', {}))
   if a:k == 'letters'
      call luaeval("require'bufferline.jump_mode'.initialize_indexes()")
   end
endfunc

" Needs to be global -_-
function! BufferlineMainClickHandler(minwid, clicks, btn, modifiers) abort
   if a:minwid == 0
      return
   end
   if a:btn =~ 'm'
      call bufferline#bbye#delete('bdelete', '', a:minwid)
   else
      call luaeval("require'bufferline.state'.open_buffer_in_listed_window(_A)", a:minwid)
   end
endfunction

" Needs to be global -_-
function! BufferlineCloseClickHandler(minwid, clicks, btn, modifiers) abort
   call bufferline#bbye#delete('bdelete', '', a:minwid)
endfunction


" Buffer movement

function! s:move_current_buffer(steps)
   call luaeval("require'bufferline.state'.move_current_buffer(_A)", a:steps)
endfunc

function! s:move_current_buffer_to(number)
   call luaeval("require'bufferline.state'.move_current_buffer_to(_A)", a:number)
endfunc

function! s:goto_buffer(number)
   call luaeval("require'bufferline.state'.goto_buffer(_A)", a:number)
endfunc

function! s:goto_buffer_relative(steps)
   call luaeval("require'bufferline.state'.goto_buffer_relative(_A)", a:steps)
endfunc

" Final setup

call bufferline#enable()

let g:bufferline# = s:
