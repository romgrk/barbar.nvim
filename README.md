
# barbar.nvim

> Tabs, as understood by any other editor.

`barbar.nvim` is a tabline plugin that implements tabs in a way that is more
usable. Tabs are re-orderable, have icons, and are clearly highlighted. It also
offers a jump-to-buffer mode. When you activate it, the tabs display a target
letter instead of their icon. Jump to any buffer by simply typing their target
letter. Even better, the target letter stays constant for the lifetime of the
buffer, so if you're working with a set of files you can even type the letter
ahead from memory.

##### Table of content
 - [Features](#features)
 - [Install](#install)
 - [Usage](#usage)
 - [Options](#options)

## Features

##### Move

![move](./static/move.gif)

##### Re-order buffer

![reorder](./static/reorder.gif)

##### Jump-to-buffer

![jump](./static/jump.gif)

## Install

Is two dependencies a lot for one plugin? Yes it is. But is Barbar a very good
tabline plugin? Also yes. Do you now understand why the Install section is
strategically placed after the cool demos? Yes again.

```vim
Plug 'kyazdani42/nvim-web-devicons'
Plug 'romgrk/lib.kom'
Plug 'romgrk/barbar.nvim'
```

I might remove the dependencies in the future if I have enough time to port the
required functions, or if you complain loud enough. You can skip the dependency
on `'kyazdani42/nvim-web-devicons'` if you [disable icons](#options).

##### Requirements
 - Neovim `0.5`

## Usage

No default mappings are provided, here is an example:
```vim

" Magic buffer-picking mode
nnoremap <silent> <Space>b :BufferPick<CR>
" Move to previous/next
nnoremap <silent>    <A-,> :BufferPrevious<CR>
nnoremap <silent>    <A-.> :BufferNext<CR>
" Re-order to previous/next
nnoremap <silent>    <A-<> :BufferMovePrevious<CR>
nnoremap <silent>    <A->> :BufferMoveNext<CR>
" Goto buffer in position...
nnoremap <silent>    <A-1> :BufferGoto 1<CR>
nnoremap <silent>    <A-2> :BufferGoto 2<CR>
nnoremap <silent>    <A-3> :BufferGoto 3<CR>
nnoremap <silent>    <A-4> :BufferGoto 4<CR>
nnoremap <silent>    <A-5> :BufferGoto 5<CR>
nnoremap <silent>    <A-6> :BufferGoto 6<CR>
nnoremap <silent>    <A-7> :BufferGoto 7<CR>
nnoremap <silent>    <A-8> :BufferGoto 8<CR>
nnoremap <silent>    <A-9> :BufferLast<CR>

```

For the highligh groups, here are the default ones:
```vim

let bg_current = get(nvim_get_hl_by_name('Normal',     1), 'background', '#000000')
let bg_visible = get(nvim_get_hl_by_name('TabLineSel', 1), 'background', '#000000')
let bg_inactive = get(nvim_get_hl_by_name('TabLine',   1), 'background', '#000000')

" For the current active buffer
hi default link BufferCurrent      Normal
" For the current active buffer when modified
hi default link BufferCurrentMod   Normal
" For the current active buffer icon
hi default link BufferCurrentSign  Normal
" For the current active buffer target when buffer-picking
exe 'hi default BufferCurrentTarget   guifg=red gui=bold guibg=' . bg_current

" For buffers visible but not the current one
hi default link BufferVisible      TabLineSel
hi default link BufferVisibleMod   TabLineSel
hi default link BufferVisibleSign  TabLineSel
exe 'hi default BufferVisibleTarget   guifg=red gui=bold guibg=' . bg_visible

" For buffers invisible buffers
hi default link BufferInactive     TabLine
hi default link BufferInactiveMod  TabLine
hi default link BufferInactiveSign TabLine
exe 'hi default BufferInactiveTarget   guifg=red gui=bold guibg=' . bg_inactive


" For the shadow in buffer-picking mode
hi BufferShadow guifg=#ffffff guibg=#ffffff
```

You can also use the [doom-one.vim](https://github.com/romgrk/doom-one.vim)
colorscheme that defines those groups and is also very pleasant as you could see
in the demos above.

## Options

```vim
let bufferline = {}

" Show a shadow over the editor in buffer-pick mode
let bufferline.shadow = v:true

" Disable icons
let bufferline.icons = v:true
```
