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
