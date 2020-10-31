
" Initialize highlights
function bufferline#highlight#setup()
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
