
function! bufferline#tabpages#width()
  if !g:bufferline.tabpages
    return 0
  end

  let last = tabpagenr('$')

  if last == 1
    return 0
  end

  let current = tabpagenr()

  return 2 + len(string(current)) + len(string(last))
endfunc

function! bufferline#tabpages#render()
  if !g:bufferline.tabpages
    return ''
  end

  let last = tabpagenr('$')

  if last == 1
    return ''
  end

  let current = tabpagenr()

	call getchar()

  let result = '%=%#TabLineSel# ' . current . '/' . last . ' '

  return result
endfu

