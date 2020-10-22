
# barbar.nvim

> Tabs, as understood by any other editor.

##### Content
 - [Features](#features)
 - [Install](#install)
 - [Usage](#usage)

`barbar.nvim` is a tabline plugin that implements tabs in a way that is more
usable. Tabs are re-orderable, have icons, and are clearly highlighted. It also
offers a jump-to-buffer mode. When you activate it, the tabs display a target
letter instead of their icon. Jump to any buffer by simply typing their target
letter. Even better, the target letter stays constant for the lifetime of the
buffer, so if you're working with a set of files you can even type the letter
ahead from memory.

## Features

##### Move

![move](./static/move.gif)

##### Re-order buffer

![reorder](./static/reorder.gif)

##### Jump-to-buffer

![jump](./static/jump.gif)

## Install

Is two dependencies a lot for one plugin? Yes it is. But is Barbar a very good
tabline plugin? Also yes.

```vim
Plug 'kyazdani42/nvim-web-devicons'
Plug 'romgrk/lib.kom'
Plug 'romgrk/barbar.nvim'
```

