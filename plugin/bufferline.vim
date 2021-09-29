" File: bufferline.vim
" Author: romgrk
" Description: Buffer line
" Date: Fri 22 May 2020 02:22:36 AM EDT
" !::exe [So]

set showtabline=2

function! bufferline#enable()
   augroup bufferline
      au!
      au BufReadPost    * call <SID>on_buffer_open(expand('<abuf>'))
      au BufNewFile     * call <SID>on_buffer_open(expand('<abuf>'))
      au BufDelete      * call <SID>on_buffer_close(expand('<abuf>'))
      au VimEnter       * call bufferline#highlight#setup()
      au ColorScheme    * call bufferline#highlight#setup()
      if exists('##BufModifiedSet')
      au BufModifiedSet * call <SID>check_modified()
      else
      au BufWritePost   * call <SID>check_modified()
      au TextChanged    * call <SID>check_modified()
      end
      au User SessionSavePre lua require'bufferline.state'.on_pre_save()
   augroup END

   augroup bufferline_update
      au!
      au BufNew                 * call bufferline#update(v:true)
      au BufEnter               * call bufferline#update()
      au BufWipeout             * call bufferline#update()
      au BufWinEnter            * call bufferline#update()
      au BufWinLeave            * call bufferline#update()
      au BufWritePost           * call bufferline#update()
      au SessionLoadPost        * call bufferline#update()
      au OptionSet      buflisted call bufferline#update()
      au VimResized             * call bufferline#update()
      au WinEnter               * call bufferline#update()
      au WinLeave               * call bufferline#update()
      au WinClosed              * call bufferline#update_async()
      au TermOpen               * call bufferline#update_async(v:true, 500)
   augroup END

   call bufferline#highlight#setup()
   call bufferline#update()
endfunc

function! bufferline#disable()
   augroup bufferline | au! | augroup END
   augroup bufferline_update | au! | augroup END
   let &tabline = ''
endfunc

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

command!                BufferCloseAllButCurrent   lua require'bufferline.state'.close_all_but_current()
command!                BufferCloseAllButPinned    lua require'bufferline.state'.close_all_but_pinned()
command!                BufferCloseBuffersLeft     lua require'bufferline.state'.close_buffers_left()
command!                BufferCloseBuffersRight    lua require'bufferline.state'.close_buffers_right()

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

"==========================
" Section: Bufferline state
"==========================

" Last value for tabline
let s:last_tabline = ''

" Debugging
" let g:events = []

"========================
" Section: Main functions
"========================

function! bufferline#update(...)
   if get(g:, 'SessionLoad')
      return
   endif
   let new_value = bufferline#render(a:0 > 0 ? a:1 : v:false)
   if new_value == s:last_tabline
      return
   end
   let &tabline = new_value
   let s:last_tabline = new_value
endfu

function! bufferline#update_async(...)
   let update_names = a:0 > 0 ? a:1 : v:false
   let delay = a:0 > 1 ? a:2 : 1
   call timer_start(delay, {->bufferline#update(a:0 > 0 ? a:1 : v:false)})
endfu

function! bufferline#render(update_names) abort
   let result = luaeval("require'bufferline.render'.render_safe(_A)", a:update_names)

   if result[0]
      return result[1]
   end

   let error = result[1]

   BarbarDisable
   echohl ErrorMsg
   echom "Barbar detected an error while running. Barbar disabled itself :/"
   echom "Include this in your report: " . string(error)
   echohl None
endfu

function! bufferline#pick_buffer()
   call luaeval("require'bufferline.jump_mode'.activate()")
endfunc

function! bufferline#order_by_buffer_number()
   call luaeval("require'bufferline.state'.order_by_buffer_number()")
endfunc

function! bufferline#order_by_directory()
   call luaeval("require'bufferline.state'.order_by_directory()")
endfunc

function! bufferline#order_by_language()
   call luaeval("require'bufferline.state'.order_by_language()")
endfunc

function! bufferline#order_by_window_number()
   call luaeval("require'bufferline.state'.order_by_window_number()")
endfunc

function! bufferline#close(abuf)
   call luaeval("require'bufferline.state'.close_buffer_animated(_A)", a:abuf)
endfunc

function! bufferline#close_direct(abuf)
   call luaeval("require'bufferline.state'.close_buffer(_A)", a:abuf)
endfunc

"========================
" Section: Event handlers
"========================

function! s:on_buffer_open(abuf)
   call luaeval("require'bufferline.jump_mode'.assign_next_letter(_A)", a:abuf)
endfunc

function! s:on_buffer_close(bufnr)
   call luaeval("require'bufferline.jump_mode'.unassign_letter_for(_A)", a:bufnr)
   call bufferline#update_async() " BufDelete is called before buffer deletion
endfunc

function! s:check_modified()
   if (&modified != get(b:, 'checked'))
      let b:checked = &modified
      call bufferline#update()
   end
endfunc

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
