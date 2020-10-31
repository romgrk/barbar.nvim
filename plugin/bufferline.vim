" File: bufferline.vim
" Author: romgrk
" Description: Buffer line
" Date: Fri 22 May 2020 02:22:36 AM EDT
" !::exe [So]

set showtabline=2

augroup bufferline
   au!
   au BufReadPost,BufNewFile * call <SID>on_buffer_open(expand('<abuf>'))
   au BufDelete              * call <SID>on_buffer_close(expand('<abuf>'))

   au BufWritePost <buffer> call <SID>check_modified()
   au TextChanged  <buffer> call <SID>check_modified()
augroup END

function! s:did_load (...)
   augroup bufferline_update
      au!
      au BufNew                 * call bufferline#update()
      au BufEnter               * call bufferline#update()
      au BufWipeout             * call bufferline#update()
      au BufWinEnter            * call bufferline#update()
      au BufWinLeave            * call bufferline#update()
      au BufWritePost           * call bufferline#update()
      au SessionLoadPost        * call bufferline#update()
      au WinEnter               * call bufferline#update()
      au WinLeave               * call bufferline#update()
      au WinClosed              * call bufferline#update_async()
   augroup END

   call bufferline#update()
endfunc
call timer_start(25, function('s:did_load'))


call bufferline#highlight#setup()

"=================
" Section: Commands
"=================

command!          -bang BufferNext             call s:goto_buffer_relative(+1)
command!          -bang BufferPrevious         call s:goto_buffer_relative(-1)

command! -nargs=1 -bang BufferGoto             call s:goto_buffer(<f-args>)
command!          -bang BufferLast             call s:goto_buffer(-1)

command!          -bang BufferMoveNext         call s:move_current_buffer(+1)
command!          -bang BufferMovePrevious     call s:move_current_buffer(-1)

command!          -bang BufferPick             call bufferline#pick_buffer()

command!          -bang BufferOrderByDirectory call bufferline#order_by_directory()
command!          -bang BufferOrderByLanguage  call bufferline#order_by_language()

command! -bang -complete=buffer -nargs=?
                      \ BufferClose            call bufferline#bbye#delete('bdelete', <q-bang>, <q-args>)
command! -bang -complete=buffer -nargs=?
                      \ BufferDelete           call bufferline#bbye#delete('bdelete', <q-bang>, <q-args>)
command! -bang -complete=buffer -nargs=?
                      \ BufferWipeout          call bufferline#bbye#delete('bwipeout', <q-bang>, <q-args>)

"=================
" Section: Options
"=================

let bufferline = extend({
\ 'shadow': v:true,
\ 'animation': v:true,
\ 'icons': v:true,
\ 'closable': v:true,
\ 'semantic_letters': v:true,
\ 'clickable': v:true,
\ 'maximum_padding': 4,
\ 'letters': 'asdfjkl;ghnmxcbziowerutyqpASDFJKLGHNMXCBZIOWERUTYQP',
\}, get(g:, 'bufferline', {}))

" Default icons
let icons = extend({
\ 'bufferline_default_file': '',
\ 'bufferline_separator_active':   '▎',
\ 'bufferline_separator_inactive': '▎',
\ 'bufferline_close_tab': '',
\ 'bufferline_close_tab_modified': '●',
\}, get(g:, 'icons', {})) " 

"==========================
" Section: Bufferline state
"==========================

" Hl groups used for coloring
let s:hl_status = ['Inactive', 'Visible', 'Current']

" Last value for tabline
let s:last_tabline = ''

" Current buffers in tabline (ordered)
let s:buffers = []
" Current buffers's width
let s:buffer_widths = {} " Map<String, [nameWidth: Number, restOfWidth: Number]> 

" Buffers being closed
let s:buffers_closing = {}

" If the user is in buffer-picking mode
let s:is_picking_buffer = v:false

"===================================
" Section: Buffer-picking mode state
"===================================

" Constants
let s:LETTERS = g:bufferline.letters
let s:INDEX_BY_LETTER = {}

let s:letter_status = map(range(len(s:LETTERS)), {-> 0})
let s:buffer_by_letter = {}
let s:letter_by_buffer = {}

" Initialize INDEX_BY_LETTER
function s:init()
   let index = 0
   for index in range(len(s:LETTERS))
      let letter = s:LETTERS[index]
      let s:INDEX_BY_LETTER[letter] = index
      let index += 1
   endfor
endfunc

call s:init()

let s:empty_bufnr = nvim_create_buf(0, 1)


"========================
" Section: Main functions
"========================

function! bufferline#update()
   let new_value = bufferline#render()
   if new_value == s:last_tabline
      return
   end
   let &tabline = new_value
   let s:last_tabline = new_value
endfu

function! bufferline#update_async()
   call timer_start(1, {->bufferline#update()})
endfu

let g:events = []

function! bufferline#render()
   let buffer_numbers = copy(s:get_updated_buffers())
   let buffer_names = bufferline#get_buffer_names(buffer_numbers)

   " Options & cached values
   let currentnr = bufnr()
   let click_enabled = has('tablineat') && g:bufferline.clickable
   let has_icons = g:bufferline.icons
   let has_close = g:bufferline.closable
   let buffers_length = len(buffer_numbers)

   let base_width = 1 + (has_icons ? 2 : 0) + (has_close ? 2 : 0) " separator + icon + space-after-icon + space-after-name
   let available_width = &columns
   let used_width = s:calculate_used_width(buffer_numbers, buffer_names, base_width)
   let remaining_width = available_width - used_width
   let remaining_width_per_buffer = remaining_width / buffers_length
   let remaining_padding_per_buffer = remaining_width_per_buffer / 2
   let padding_width = min([remaining_padding_per_buffer, g:bufferline.maximum_padding]) - 1
   let actual_width = used_width + padding_width * buffers_length

   " Actual rendering

   let result = ''

   for i in range(len(buffer_numbers))
      let buffer_number = buffer_numbers[i]
      let buffer_name   = buffer_names[i]

      let s:buffer_widths[buffer_number] = [len(buffer_name), base_width + 2 * padding_width]

      let activity = bufferline#activity(buffer_number)
      let is_visible = activity == 1
      let is_current = activity == 2
      " let is_inactive = activity == 0
      let is_modified = getbufvar(buffer_number, '&modified')
      let is_closing = has_key(s:buffers_closing, buffer_number)

      let status = s:hl_status[activity]
      let mod = is_modified ? 'Mod' : ''

      let separatorPrefix = s:hl('Buffer' . status . 'Sign')
      let separator = status == 'Inactive' ?
         \ g:icons.bufferline_separator_inactive :
         \ g:icons.bufferline_separator_active

      let namePrefix = s:hl('Buffer' . status . mod)
      let name = (!has_icons && s:is_picking_buffer ? buffer_name[1:] : buffer_name)

      if s:is_picking_buffer
         let letter = s:get_letter(buffer_number)
         let iconPrefix = s:hl('Buffer' . status . 'Target')
         let icon = (!empty(letter) ? letter : ' ') . (has_icons ? ' ' : '')
      elseif has_icons
         let [icon, iconHl] = s:get_icon(buffer_name)
         let iconPrefix = status is 'Inactive' ? s:hl('BufferInactive') : s:hl(iconHl)
         let icon = icon . ' '
      else
         let iconPrefix = ''
         let icon = ''
      end

      if has_close
         let closePrefix = namePrefix
         let close = (!is_modified ?
                  \ g:icons.bufferline_close_tab :
                  \ g:icons.bufferline_close_tab_modified) . ' '
         if click_enabled
            let closePrefix = 
               \ '%' . buffer_number . '@BufferlineCloseClickHandler@'
               \ . closePrefix
         end
      else
         let closePrefix = ''
         let close = ''
      end

      let clickable =
         \ click_enabled ?
            \ '%' . buffer_number . '@BufferlineMainClickHandler@' : ''

      let padding = repeat(' ', padding_width)

      if !is_closing
         let item =
            \ clickable .
            \ separatorPrefix . separator .
            \ padding .
            \ iconPrefix . icon .
            \ namePrefix . name .
            \ padding .
            \ ' ' .
            \ closePrefix . close
      else
         let width = s:buffers_closing[buffer_number]
         let text = 
            \ separator .
            \ padding .
            \ icon .
            \ name .
            \ padding .
            \ ' ' .
            \ close
         let text = strcharpart(text, 0, width)
         let g:events += [width, text]
         let item = namePrefix .  text
      end


      let result .= item
   endfor

   if actual_width < available_width
      let separatorPrefix = s:hl('BufferInactiveSign')
      let separator = g:icons.bufferline_separator_inactive
      let result .= separatorPrefix . separator
   end

   let result .= s:hl('TabLineFill')

   return result
endfu

function! bufferline#session (...)
   let name = ''

   if exists('g:xolox#session#current_session_name')
      let name = g:xolox#session#current_session_name
   end

   if empty(name)
      let name = substitute(getcwd(), $HOME, '~', '')
      if len(name) > 30
         let name = pathshorten(name)
      end
   end

   return '%#BufferPart#%( ' . name . ' %)'
endfunc

function! bufferline#tab_pages ()
   if tabpagenr('$') == 1
      return ''
   end
   let tabpart = ''
   for t in range(1, tabpagenr('$'))
      if !empty(t)
         let style = (t == tabpagenr()) ?  'TabLineSel'
                     \ : gettabvar(t, 'hl', 'LightLineRight_tabline_0')
         let tabpart .= s:hl(style, ' ' . t[0] . ' ')
      end
   endfor
   return tabpart
endfu

function! bufferline#pick_buffer()
   let s:is_picking_buffer = v:true
   call bufferline#update()
   call s:shadow_open()
   redraw
   let s:is_picking_buffer = v:false

   let char = getchar()
   let letter = nr2char(char)

   let did_switch = v:false

   if !empty(letter)
      if has_key(s:buffer_by_letter, letter)
         let bufnr = s:buffer_by_letter[letter]
         execute 'buffer' bufnr
      else
         echohl WarningMsg
         echom "Could't find buffer '" . letter . "'"
      end
   end

   if !did_switch
      call bufferline#update()
      call s:shadow_close()
      redraw
   end
endfunc

function! bufferline#order_by_directory()
   let new_buffers = copy(s:buffers)
   let new_buffers = map(new_buffers, {_, b -> bufname(b)})
   call sort(new_buffers, function('s:compare_directory'))
   let new_buffers = map(new_buffers, {_, b -> bufnr(b)})

   call remove(s:buffers, 0, -1)
   call extend(s:buffers, new_buffers)

   call bufferline#update()
endfunc

function! bufferline#order_by_language()
   let new_buffers = copy(s:buffers)
   let new_buffers = map(new_buffers, {_, b -> bufname(b)})
   call sort(new_buffers, function('s:compare_language'))
   let new_buffers = map(new_buffers, {_, b -> bufnr(b)})

   call remove(s:buffers, 0, -1)
   call extend(s:buffers, new_buffers)

   call bufferline#update()
endfunc

function! bufferline#close(buffer_number)
   call s:close_buffer_animated(a:buffer_number)
endfunc

function! bufferline#close_direct(buffer_number)
   call s:close_buffer(a:buffer_number)
endfunc

"========================
" Section: Event handlers
"========================

function! s:on_buffer_open(abuf)
   let buffer = bufnr()
   " Buffer might be listed but not loaded, thus why it has already a letter
   if !has_key(s:letter_by_buffer, buffer)
      call s:assign_next_letter(bufnr())
   end
endfunc

function! s:on_buffer_close(bufnr)
   call s:unassign_letter(s:get_letter(a:bufnr))
endfunc

function! s:check_modified()
   if (&modified != get(b:, 'checked'))
      let b:checked = &modified
      call bufferline#update()
   end
endfunc

" Needs to be global -_-
function! BufferlineMainClickHandler(minwid, clicks, btn, modifiers) abort
   if a:btn =~ 'm'
      call bufferline#bbye#delete('bdelete', '', a:minwid)
   else
      execute 'buffer ' . a:minwid
   end
endfunction

" Needs to be global -_-
function! BufferlineCloseClickHandler(minwid, clicks, btn, modifiers) abort
   call bufferline#bbye#delete('bdelete', '', a:minwid)
endfunction

" Buffer movement

function! s:move_current_buffer (direction)
   call s:get_updated_buffers()

   let currentnr = bufnr('%')
   let idx = index(s:buffers, currentnr)

   if idx == 0 && a:direction == -1
      return
   end
   if idx == len(s:buffers)-1 && a:direction == +1
      return
   end

   let othernr = s:buffers[idx + a:direction]
   let s:buffers[idx] = othernr
   let s:buffers[idx + a:direction] = currentnr

   call bufferline#update()
endfunc

function! s:goto_buffer (number)
   call s:get_updated_buffers()

   if a:number == -1
      let idx = len(s:buffers)-1
   else
      let idx = a:number - 1
   end

   silent execute 'buffer' . s:buffers[idx]
endfunc

function! s:goto_buffer_relative (direction)
   call s:get_updated_buffers()

   let currentnr = bufnr('%')
   let idx = index(s:buffers, currentnr)

   if idx == 0 && a:direction == -1
      let idx = len(s:buffers)-1
   elseif idx == len(s:buffers)-1 && a:direction == +1
      let idx = 0
   else
      let idx = idx + a:direction
   end

   silent execute 'buffer' . s:buffers[idx]
endfunc


" Buffer-picking mode

function! s:assign_next_letter(bufnr)
   let bufnr = 0 + a:bufnr

   " First, try to assign a letter based on name
   if g:bufferline.semantic_letters == v:true
      let name = fnamemodify(bufname(bufnr), ':t:r')

      for i in range(len(name))
         let letter = tolower(name[i])
         if !has_key(s:INDEX_BY_LETTER, letter)
            continue
         end
         let index = s:INDEX_BY_LETTER[letter]
         let status = s:letter_status[index]
         if status == 0
            let s:letter_status[index] = 1
            let s:letter = s:LETTERS[index]
            let s:buffer_by_letter[s:letter] = bufnr
            let s:letter_by_buffer[bufnr] = s:letter
            return s:letter
         end
      endfor
   end

   " Otherwise, assign a letter by usable order
   let i = 0
   for status in s:letter_status
      if status == 0
         let s:letter_status[i] = 1
         let s:letter = s:LETTERS[i]
         let s:buffer_by_letter[s:letter] = bufnr
         let s:letter_by_buffer[bufnr] = s:letter
         return s:letter
      end
      let i += 1
   endfor
   return v:null
endfunc

function! s:unassign_letter(letter)
   if a:letter == ''
      return
   end
   let index = s:INDEX_BY_LETTER[a:letter]
   let s:letter_status[index] = 0
   if has_key(s:buffer_by_letter, a:letter)
      let bufnr = s:buffer_by_letter[a:letter]
      call remove(s:buffer_by_letter, a:letter)
      if has_key(s:letter_by_buffer, bufnr)
         call remove(s:letter_by_buffer, bufnr)
      end
   end
endfunc

function! s:get_letter(bufnr)
   if has_key(s:letter_by_buffer, a:bufnr)
      return s:letter_by_buffer[a:bufnr]
   end
   return s:assign_next_letter(a:bufnr)
endfunc

function! s:update_buffer_letters()
   let assigned_letters = {}

   let index = 0
   for index in range(len(s:buffers))
      let bufnr = s:buffers[index]
      let letter_from_buffer = s:get_letter(bufnr)
      if letter_from_buffer == v:null || has_key(assigned_letters, letter_from_buffer)
         let letter_from_buffer = s:assign_next_letter(bufnr)
      else
         let s:letter_status[index] = 1
      end
      if letter_from_buffer != v:null
         let bufnr_from_state = get(s:buffer_by_letter, letter_from_buffer, v:null)

         if bufnr_from_state != bufnr
            let s:buffer_by_letter[letter_from_buffer] = bufnr
            if has_key(s:buffer_by_letter, bufnr_from_state)
               call remove(s:buffer_by_letter, bufnr_from_state)
            end
         end

         let assigned_letters[letter_from_buffer] = 1
      end
   endfor

   let index = 0
   for index in range(len(s:LETTERS))
      let letter = s:LETTERS[index]
      let status = s:letter_status[index]
      if status && !has_key(assigned_letters, letter)
         call s:unassign_letter(letter)
      end
   endfor
endfunc

function! s:shadow_open()
   if !g:bufferline.shadow
      return
   end
   let opts =  {
   \ 'relative': 'editor',
   \ 'style': 'minimal',
   \ 'width': &columns,
   \ 'height': &lines - 2,
   \ 'row': 2,
   \ 'col': 0,
   \ }
   let s:shadow_winid = nvim_open_win(s:empty_bufnr, v:false, opts)
   call setwinvar(s:shadow_winid, '&winhighlight', 'Normal:BufferShadow,NormalNC:BufferShadow,EndOfBuffer:BufferShadow')
   call setwinvar(s:shadow_winid, '&winblend', 80)
endfunc

function! s:shadow_close()
   if !g:bufferline.shadow
      return
   end
   if s:shadow_winid != v:null && nvim_win_is_valid(s:shadow_winid)
      call nvim_win_close(s:shadow_winid, v:true)
   end
   let s:shadow_winid = v:null
endfunc

" Helpers

if g:bufferline.icons
lua << END
local web = require'nvim-web-devicons'
function get_icon_wrapper(args)
   local basename  = args[1]
   local extension = args[2]
   local icon, hl = web.get_icon(basename, extension, { default = true })
   return { icon, hl }
end
END
end

function! s:get_icon (buffer_name)
   let basename = fnamemodify(a:buffer_name, ':t')
   let extension = matchstr(basename, '\v\.@<=\w+$', '', '')
   let [icon, hl] = luaeval("get_icon_wrapper(_A)", [basename, extension])
   if icon == ''
      let icon = g:icons.bufferline_default_file
   end
   return [icon, hl]
endfunc

function! s:get_updated_buffers ()
   if exists('g:session.buffers')
      let s:buffers = g:session.buffers
   elseif exists('g:session')
      let g:session.buffers = []
      let s:buffers = g:session.buffers
   end

   let current_buffers = bufferline#filter('&buflisted')
   let new_buffers =
      \ filter(
      \   copy(current_buffers),
      \   {i, bufnr -> index(s:buffers, bufnr) == -1}
      \ )

   " Remove closed or update closing buffers
   let closed_buffers = filter(copy(s:buffers), {i, bufnr -> index(current_buffers, bufnr) == -1})
   for buffer_number in closed_buffers
      if has_key(s:buffers_closing, buffer_number)
         continue
      end
      " echom 'closing' buffer_number
      if !has_key(s:buffer_widths, buffer_number)
         call s:close_buffer(buffer_number)
         continue
      end
      call s:close_buffer_animated(buffer_number)
   endfor

   " Add new buffers
   call extend(s:buffers, new_buffers)

   return s:buffers
endfunc

" Close buffer & cleanup associated data
function! s:close_buffer(buffer_number)
   call filter(s:buffers, {_, bufnr -> bufnr != a:buffer_number})
   if has_key(s:buffers_closing, a:buffer_number)
      call remove(s:buffers_closing, a:buffer_number)
   end
   if has_key(s:buffer_widths, a:buffer_number)
      call remove(s:buffer_widths, a:buffer_number)
   end
   call bufferline#update()
endfunc

function! s:close_buffer_animated(buffer_number)
   if g:bufferline.animation == v:false
      return s:close_buffer(a:buffer_number)
   end
   let current_width =
            \ s:buffer_widths[a:buffer_number][0] +
            \ s:buffer_widths[a:buffer_number][1]
   let s:buffers_closing[a:buffer_number] = current_width
   call bufferline#animate#start(150, current_width, 0, v:t_number,
            \ {new_width, state ->
            \   s:close_buffer_animated_tick(a:buffer_number, new_width, state)})
endfunc

function! s:close_buffer_animated_tick(buffer_number, new_width, state)
   if a:new_width > 0
      let s:buffers_closing[a:buffer_number] = a:new_width
      call bufferline#update()
      return
   end

   call s:close_buffer(a:buffer_number)
endfunc

function! s:calculate_used_width(buffer_numbers, buffer_names, base_width)
   let sum = 0

   for i in range(len(a:buffer_numbers))
      let buffer_number = a:buffer_numbers[i]
      let buffer_name = a:buffer_names[i]
      if has_key(s:buffers_closing, buffer_number)
         let sum += s:buffer_widths[buffer_number][0]
         continue
      end
      let sum += a:base_width + len(buffer_name)
   endfor

   return sum
endfunction

function! s:hl (...)
   let str = '%#' . a:1 . '#'
   if a:0 > 1
      let str .= join(a:000[1:], '')
   end
   return str
endfu

function! s:is_relative_path(path)
   return fnamemodify(a:path, ':p') != a:path
endfunc

function s:compare_directory(a, b)
   let ra = s:is_relative_path(a:a)
   let rb = s:is_relative_path(a:b)
   if ra && !rb
      return -1
   end
   if rb && !ra
      return +1
   end
   return a:a > a:b
endfunc

function s:compare_language(a, b)
   let ea = fnamemodify(a:a, ':e')
   let eb = fnamemodify(a:b, ':e')
   return ea > eb
endfunc


" Final setup

call s:get_updated_buffers()
call s:update_buffer_letters()

let g:bufferline# = s:
