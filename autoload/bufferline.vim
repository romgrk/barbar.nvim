

" returns 0: none, 1: active, 2: current
function! bufferline#activity(number)
    if bufnr() == a:number
        return 2 | endif
    if bufwinnr(a:number) != -1
        return 1 | endif
    return 0
endfu " }}}

function! bufferline#filter(...)
    let list = []
    for line in split(execute('ls!'), "\n")
        call add(list, 0+matchstr(line, '\v\d+'))
    endfor
    for a_expr in a:000
        let expr = a_expr
        let expr = substitute(expr, '&\w\+', 'getbufvar(v:val, "\0")', 'g')
        call filter(list, expr)
    endfor
    return list
endfunc
