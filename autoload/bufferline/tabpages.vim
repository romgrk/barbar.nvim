
function! bufferline#tabpages#width()
  if !g:bufferline.tabpages
    return 0
  end

  let last = tabpagenr('$')

  if last == 1
    return 0
  end

  let current = nvim_get_current_tabpage()

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

  let current = nvim_get_current_tabpage()

  let result = '%=%#TabLineSel# ' . current . '/' . last . ' '

  return result
endfu

