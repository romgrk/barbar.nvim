" Bbye
"
" source: https://github.com/moll/vim-bbye/blob/master/plugin/bbye.vim
" license:
"
" Copyright (C) 2013 Andri Möll
"
" This program is free software: you can redistribute it and/or modify it under
" the terms of the GNU Affero General Public License as published by the Free
" Software Foundation, either version 3 of the License, or any later version.
"
" Additional permission under the GNU Affero GPL version 3 section 7:
" If you modify this Program, or any covered work, by linking or
" combining it with other code, such other code is not for that reason
" alone subject to any of the requirements of the GNU Affero GPL version 3.
"
" In summary:
" - You can use this program for no cost.
" - You can use this program for both personal and commercial reasons.
" - You do not have to share your own program's code which uses this program.
" - You have to share modifications (e.g bug-fixes) you've made to this program.
"
" For the full copy of the GNU Affero General Public License see:
" http://www.gnu.org/licenses.

function! bufferline#bbye#delete(action, bang, buffer_name, ...)
    if a:0 == 0
        let l:mods = ""
    else
        let l:mods = a:1
    endif

    let buffer = s:str2bufnr(a:buffer_name)

    if buffer < 0
        return s:error("E516: No buffers were deleted. No match for ".a:buffer_name)
    endif

    let is_modified = nvim_buf_get_option(buffer, 'modified')
    let has_confirm = nvim_get_option('confirm') || (match(l:mods, 'conf') != -1)

    if is_modified && empty(a:bang) && !has_confirm
        let error = "E89: No write since last change for buffer "
        return s:error(error . buffer . " (add ! to override)")
    endif

    let w:bbye_back = 1

    " If the buffer is set to delete and it contains changes, we can't switch
    " away from it. Hide it before eventual deleting:
    if is_modified && !empty(a:bang)
        call setbufvar(buffer, "&bufhidden", "hide")
    endif

    " For cases where adding buffers causes new windows to appear or hiding some
    " causes windows to disappear and thereby decrement, loop backwards.
    for window in reverse(range(1, winnr("$")))
        " For invalid window numbers, winbufnr returns -1.
        if winbufnr(window) != buffer | continue | endif
        execute window . "wincmd w"

        " Bprevious also wraps around the buffer list, if necessary:
        try | exe bufnr("#") > 0 && buflisted(bufnr("#")) ? "buffer #" : "bprevious"
        catch /^Vim([^)]*):E85:/ " E85: There is no listed buffer
        endtry

        " If found a new buffer for this window, mission accomplished:
        if bufnr("%") != buffer | continue | endif

        call s:new(a:bang)
    endfor

    " Because tabbars and other appearing/disappearing windows change
    " the window numbers, find where we were manually:
    let back = filter(range(1, winnr("$")), "getwinvar(v:val, 'bbye_back')")[0]
    if back | exe back . "wincmd w" | unlet w:bbye_back | endif

    " If it hasn't been already deleted by &bufhidden, end its pains now.
    " Unless it previously was an unnamed buffer and :enew returned it again.
    "
    " Using buflisted() over bufexists() because bufhidden=delete causes the
    " buffer to still _exist_ even though it won't be :bdelete-able.
    if buflisted(buffer) && buffer != bufnr("%")
        try
            exe l:mods . " " . a:action . a:bang . " " . buffer
        catch /^Vim([^)]*):E516:/ " E516: No buffers were deleted
            " Canceled by `set confirm`
            exe buffer . 'b'
        endtry
    endif

    doautocmd BufWinEnter
endfunction

function! s:str2bufnr(buffer)
    if empty(a:buffer)
        return bufnr("%")
    elseif a:buffer =~# '^\d\+$'
        return bufnr(str2nr(a:buffer))
    else
        return bufnr(a:buffer)
    endif
endfunction

let s:empty_buffer = v:null

function! s:new(bang)
    exe "enew" . a:bang

    let s:empty_buffer = bufnr()

    let b:empty_buffer = v:true

    " Regular buftype warns people if they have unsaved text there.  Wouldn't
    " want to lose someone's data:
    setl buftype=
    setl noswapfile

    " If empty and out of sight, delete it right away:
    setl bufhidden=wipe

    augroup bbye_empty_buffer
        au!
        au BufWipeout <buffer> call bufferline#close_direct(s:empty_buffer)
    augroup END
endfunction

" Using the built-in :echoerr prints a stacktrace, which isn't that nice.
function! s:error(msg)
    echohl ErrorMsg
    echomsg a:msg
    echohl NONE
    let v:errmsg = a:msg
endfunction
