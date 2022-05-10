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
