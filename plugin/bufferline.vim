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
augroup END

function! s:did_load (...)
    augroup bufferline_update
        au!
        au BufNew,BufDelete       * call bufferline#update()
        au BufWinEnter,BufEnter   * call bufferline#update()
        au BufWritePost           * call bufferline#update()
        au TabEnter,TabNewEntered * call bufferline#update()
        au SessionLoadPost        * call bufferline#update()
    augroup END

    call bufferline#update()
 endfunc
call timer_start(100, function('s:did_load'))


command!          -bang BufferNext             call s:goto_buffer_relative(+1)
command!          -bang BufferPrevious         call s:goto_buffer_relative(-1)

command! -nargs=1 -bang BufferGoto             call s:goto_buffer(<f-args>)
command!          -bang BufferLast             call s:goto_buffer(-1)

command!          -bang BufferMoveNext         call s:move_current_buffer(+1)
command!          -bang BufferMovePrevious     call s:move_current_buffer(-1)

command!          -bang BufferPick             call bufferline#pick_buffer()

command!          -bang BufferOrderByDirectory call bufferline#order_by_directory()
command!          -bang BufferOrderByLanguage  call bufferline#order_by_language()

"=================
" Section: Options
"=================

let bufferline = extend({
\ 'shadow': v:true,
\ 'icons': v:true,
\ 'semantic_letters': v:true,
\ 'clickable': v:false,
\ 'letters': 'asdfjkl;ghnmxcbziowerutyqpASDFJKLGHNMXCBZIOWERUTYQP',
\}, get(g:, 'bufferline', {}))

"==========================
" Section: Bufferline state
"==========================

" Constants
let s:SPACE = '%( %)'

" Hl groups used for coloring
let s:hl_picking = 'BufferTargetSign'
let s:hl_status = ['Inactive', 'Visible', 'Current']
let s:hl_groups = ['BufferInactive', 'BufferVisible', 'BufferCurrent']

" Initialize highlights
function s:setup_hl()
   let bg_current = get(nvim_get_hl_by_name('Normal',     1), 'background', '#000000')
   let bg_visible = get(nvim_get_hl_by_name('TabLineSel', 1), 'background', '#000000')
   let bg_inactive = get(nvim_get_hl_by_name('TabLine',   1), 'background', '#000000')
   hi default link BufferCurrent      Normal
   hi default link BufferCurrentMod   Normal
   hi default link BufferCurrentSign  Normal
   exe 'hi default BufferCurrentTarget   guifg=red gui=bold guibg=' . bg_current
   hi default link BufferVisible      TabLineSel
   hi default link BufferVisibleMod   TabLineSel
   hi default link BufferVisibleSign  TabLineSel
   exe 'hi default BufferVisibleTarget   guifg=red gui=bold guibg=' . bg_visible
   hi default link BufferInactive     TabLine
   hi default link BufferInactiveMod  TabLine
   hi default link BufferInactiveSign TabLine
   exe 'hi default BufferInactiveTarget   guifg=red gui=bold guibg=' . bg_inactive
   hi default BufferShadow guifg=#000000 guibg=#000000
endfunc

call s:setup_hl()

" Current buffers in tabline (ordered)
let s:buffers = []

" If the user is in buffer-picking mode
let s:is_picking_buffer = v:false

" Default icons
let g:icons = extend(get(g:, 'icons', {}), {
\ 'bufferline_default_file': '',
\ 'bufferline_separator_active':   '▎',
\ 'bufferline_separator_inactive': '▎',
\})


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

function! bufferline#update ()
   let &tabline = bufferline#render()
endfu

function! bufferline#render ()
   let bufferNames = {}
   let bufferDetails = map(
      \ copy(s:get_updated_buffers()),
      \ {k, number -> { 'number': 0+number, 'name': s:get_buffer_name(number) }})

   for i in range(len(bufferDetails))
      let buffer = bufferDetails[i]

      if !has_key(bufferNames, buffer.name)
         let bufferNames[buffer.name] = i
      else
         let other = bufferNames[buffer.name]
         let name = buffer.name
         let results = s:get_unique_name(bufname(buffer.number), bufname(bufferDetails[other].number))
         let newName = results[0]
         let newOtherName = results[1]
         let buffer.name = newName
         let bufferDetails[other].name = newOtherName
         let bufferNames[buffer.name] = buffer
         let bufferNames[bufferDetails[other].name] = bufferDetails[other]
         call remove(bufferNames, name)
      end
   endfor

   let currentnr = bufnr()
   let click_enabled = has('tablineat') && g:bufferline.clickable

   let result = ''

   for i in range(len(bufferDetails))
      let buffer = bufferDetails[i]
      let type = buf#activity(0+buffer.number)
      let is_visible = type == 1
      let is_current = currentnr == buffer.number

      let status = s:hl_status[type]
      let mod = buf#modified(0+buffer.number) ? 'Mod' : ''
      let has_icon = g:bufferline.icons

      let signPrefix = s:hl('Buffer' . status . 'Sign')
      let sign = status == 'Inactive' ?
         \ g:icons.bufferline_separator_inactive :
         \ g:icons.bufferline_separator_active

      let namePrefix = s:hl('Buffer' . status . mod)
      let name = '%{"' . (!has_icon && s:is_picking_buffer ? buffer.name[1:] : buffer.name) .'"}'

      if s:is_picking_buffer
         let letter = s:get_letter(buffer.number)
         let iconPrefix = s:hl('Buffer' . status . 'Target')
         let icon = '%{"' . (!empty(letter) ? letter : ' ') . (has_icon ? ' ' : '') . '"}'
      elseif has_icon
         let [icon, iconHl] = s:get_icon(buffer.name)
         let iconPrefix = status is 'Inactive' ? namePrefix : s:hl(iconHl)
         let icon = '%{"' . icon .' "}'
      else
         let iconPrefix = ''
         let icon = ''
      end

      let clickable =
         \ click_enabled ?
            \ '%' . buffer.number . '@BufferlineClickHandler@' : ''

      let result .=
         \ clickable .
         \ signPrefix . sign .
         \ iconPrefix . icon .
         \ namePrefix . name .
         \ s:SPACE

   endfor

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


"========================
" Section: Event handlers
"========================

function! s:on_buffer_open(abuf)
   let buffer = bufnr()
   " Buffer might be listed but not loaded, thus why it has already a letter
   if !has_key(s:letter_by_buffer, buffer)
      call s:assign_next_letter(bufnr())
   end
   if &buftype == '' && &buflisted
      augroup BUFFER_MOD
      au!
      au BufWritePost <buffer> call <SID>check_modified()
      au TextChanged  <buffer> call <SID>check_modified()
      au TextChangedI <buffer> call <SID>check_modified()
      augroup END
   end
endfunc

function! s:on_buffer_close(bufnr)
   call s:unassign_letter(s:get_letter(a:bufnr))
endfunc

function! s:check_modified()
   if (&modified != get(b:,'checked'))
      let b:checked = &modified
      call bufferline#update()
   end
endfunc

" Needs to be global -_-
function! BufferlineClickHandler(minwid, clicks, btn, modifiers) abort
   if a:btn =~ 'm'
      execute 'bdelete ' . a:minwid
      call bufferline#update()
   else
      execute 'buffer ' . a:minwid
   end
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

   let current_buffers = buf#filter('&buflisted')
   let new_buffers =
      \ filter(
      \   copy(current_buffers),
      \   {i, bufnr -> index(s:buffers, bufnr) == -1}
      \ )
   " Remove closed buffers
   call filter(s:buffers, {i, bufnr -> index(current_buffers, bufnr) != -1})
   " Add new buffers
   call extend(s:buffers, new_buffers)

   return s:buffers
endfunc

function! s:get_buffer_name (number)
   let name = bufname(a:number)
   if empty(name)
      return '[buffer ' . a:number . ']'
   end
   return s:basename(name)
endfunc

function! s:get_unique_name (first, second)
   let first_parts  = split(a:first, '/')
   let second_parts = split(a:second, '/')

   let length = 1
   let first_result  = join(first_parts[-length:], '/')
   let second_result = join(second_parts[-length:], '/')
   while first_result == second_result && length < max([len(first_parts), len(second_parts)])
      let length = length + 1
      let first_result  = join(first_parts[-min([len(first_parts), length]):], '/')
      let second_result = join(second_parts[-min([len(second_parts), length]):], '/')
   endwhile

   return [first_result, second_result]
endfunc

function! s:basename(path)
   return fnamemodify(a:path, ':t')
endfunc

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
