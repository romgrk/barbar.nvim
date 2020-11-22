

function! bufferline#get_buffer_names(buffer_numbers)
   let buffer_number_by_name = {}
   let buffer_names = map(copy(a:buffer_numbers), {k, number -> s:get_buffer_name(number)})

   " Compute names
   for i in range(len(a:buffer_numbers))
      let buffer_number = a:buffer_numbers[i]
      let buffer_name   = buffer_names[i]

      if !has_key(buffer_number_by_name, buffer_name)
         let buffer_number_by_name[buffer_name] = i
      else
         let other = buffer_number_by_name[buffer_name]
         let name = buffer_name
         let results = s:get_unique_name(bufname(buffer_number), bufname(a:buffer_numbers[other]))
         let newName = results[0]
         let newOtherName = results[1]
         let buffer_name = newName
         let buffer_names[i] = buffer_name
         let buffer_names[other] = newOtherName
         let buffer_number_by_name[buffer_name] = buffer_number
         let buffer_number_by_name[buffer_names[other]] = a:buffer_numbers[other]
         call remove(buffer_number_by_name, name)
      end
   endfor

   return buffer_names
endfunc

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


" Helpers

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
   while first_result == second_result && length < max([strwidth(first_parts), strwidth(second_parts)])
      let length = length + 1
      let first_result  = join(first_parts[-min([strwidth(first_parts), length]):], '/')
      let second_result = join(second_parts[-min([strwidth(second_parts), length]):], '/')
   endwhile

   return [first_result, second_result]
endfunc

function! s:basename(path)
   return fnamemodify(a:path, ':t')
endfunc

