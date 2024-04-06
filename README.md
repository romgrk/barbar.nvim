![demo](./static/demo.gif)

<h1 align="center">
  barbar.nvim
</h1>

<p align="center">
  <b>Tabs, as understood by any other editor.</b>
</p>

`barbar.nvim` is a tabline plugin with re-orderable, auto-sizing, clickable tabs,
icons, nice highlighting, sort-by commands and a magic jump-to-buffer mode. Plus
the tab names are made unique when two filenames match.

In jump-to-buffer mode, tabs display a target letter instead of their icon. Jump to
any buffer by simply typing their target letter. Even better, the target letter
stays constant for the lifetime of the buffer, so if you're working with a set of
files you can even type the letter ahead from memory.

##### Table of content

- [Install](#install)
- [Features](#features)
- [Usage](#usage)
- [Options](#options)
- [Highlighting](#highlighting)
- [Integrations](#integrations)
- [Known Issues](#known-issues)
- [About Barbar](#about)

## Install

**Requirements:**

- Neovim v0.7+

**Optional Requirements:**

- File icons: [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons)
  - NOTE: Requires a [nerd font](https://www.nerdfonts.com/) by default. Can be [configured](https://github.com/nvim-tree/nvim-web-devicons#setup) to remove this requirement.
- Git integration: [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim)

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
require('lazy').setup {
  {'romgrk/barbar.nvim',
    dependencies = {
      'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
      'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
    },
    init = function() vim.g.barbar_auto_setup = false end,
    opts = {
      -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
      -- animation = true,
      -- insert_at_start = true,
      -- …etc.
    },
    version = '^1.0.0', -- optional: only update when a new 1.x version is released
  },
}
```

#### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
-- These optional plugins should be loaded directly because of a bug in Packer lazy loading
use 'nvim-tree/nvim-web-devicons' -- OPTIONAL: for file icons
use 'lewis6991/gitsigns.nvim' -- OPTIONAL: for git status
use 'romgrk/barbar.nvim'
```

#### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-tree/nvim-web-devicons' " OPTIONAL: for file icons
Plug 'lewis6991/gitsigns.nvim' " OPTIONAL: for git status
Plug 'romgrk/barbar.nvim'
```

## Features

##### Re-order tabs

![reorder](./static/reorder.gif)

##### Auto-sizing tabs, fill the space when available

![resize](./static/resize.gif)

##### Jump-to-buffer mode

![jump](./static/jump.gif)

Type a letter to jump to a buffer. Letters stay constant for the lifetime of the buffer.
By default, letters are assigned based on buffer name, eg `README.md` will get letter `r`.
You can change this so that letters are assigned based on usability:
home row (`asdfjkl;gh`) first, then other rows.

##### Sort tabs automatically

![jump](./static/sort.gif)

`:BufferOrderByName`, `:BufferOrderByDirectory`, `:BufferOrderByLanguage`, `:BufferOrderByWindowNumber`, `:BufferOrderByBufferNumber`

##### Clickable & closable tabs

![click](./static/click.gif)

Left-click to go, middle-click or close button to close. Don't forget to `set mouse+=a`.

##### Unique names when filenames match

![unique-name](./static/unique-name.png)

##### Pinned buffers

![pinned](./static/pinned.png)

##### bbye.vim for closing buffers

A modified version of [bbye.vim](https://github.com/moll/vim-bbye) is included in this
plugin to close buffers without messing with your window layout and more. Available
as `BufferClose` and `bufferline#bbye#delete(buf)`.

##### Scrollable tabs, to always show the current buffer

![scroll](./static/scroll.gif)

##### Offset bufferline when showing sidebars

![filetree-with-offset](./static/filetree-with-offset.png)

## Usage

### Mappings & commands

#### Vim script

No default mappings are provided, here is an example. It is recommended to use
the `BufferClose` command to close buffers instead of `bdelete` because it will
not mess your window layout.

> **Note**
>
> In the below key mappings, the Alt key is being used.
> If you are using a terminal like iTerm on Mac, you
> will want to make sure that your Option key is properly
> mapped to Alt. Its under Profiles > Keys, select Esc+

```vim
" Move to previous/next
nnoremap <silent>    <A-,> <Cmd>BufferPrevious<CR>
nnoremap <silent>    <A-.> <Cmd>BufferNext<CR>

" Re-order to previous/next
nnoremap <silent>    <A-<> <Cmd>BufferMovePrevious<CR>
nnoremap <silent>    <A->> <Cmd>BufferMoveNext<CR>

" Goto buffer in position...
nnoremap <silent>    <A-1> <Cmd>BufferGoto 1<CR>
nnoremap <silent>    <A-2> <Cmd>BufferGoto 2<CR>
nnoremap <silent>    <A-3> <Cmd>BufferGoto 3<CR>
nnoremap <silent>    <A-4> <Cmd>BufferGoto 4<CR>
nnoremap <silent>    <A-5> <Cmd>BufferGoto 5<CR>
nnoremap <silent>    <A-6> <Cmd>BufferGoto 6<CR>
nnoremap <silent>    <A-7> <Cmd>BufferGoto 7<CR>
nnoremap <silent>    <A-8> <Cmd>BufferGoto 8<CR>
nnoremap <silent>    <A-9> <Cmd>BufferGoto 9<CR>
nnoremap <silent>    <A-0> <Cmd>BufferLast<CR>

" Pin/unpin buffer
nnoremap <silent>    <A-p> <Cmd>BufferPin<CR>

" Close buffer
nnoremap <silent>    <A-c> <Cmd>BufferClose<CR>
" Restore buffer
nnoremap <silent>    <A-s-c> <Cmd>BufferRestore<CR>

" Wipeout buffer
"                          :BufferWipeout
" Close commands
"                          :BufferCloseAllButCurrent
"                          :BufferCloseAllButVisible
"                          :BufferCloseAllButPinned
"                          :BufferCloseAllButCurrentOrPinned
"                          :BufferCloseBuffersLeft
"                          :BufferCloseBuffersRight

" Magic buffer-picking mode
nnoremap <silent> <C-p>    <Cmd>BufferPick<CR>
nnoremap <silent> <C-p>    <Cmd>BufferPickDelete<CR>

" Sort automatically by...
nnoremap <silent> <Space>bb <Cmd>BufferOrderByBufferNumber<CR>
nnoremap <silent> <Space>bn <Cmd>BufferOrderByName<CR>
nnoremap <silent> <Space>bd <Cmd>BufferOrderByDirectory<CR>
nnoremap <silent> <Space>bl <Cmd>BufferOrderByLanguage<CR>
nnoremap <silent> <Space>bw <Cmd>BufferOrderByWindowNumber<CR>

" Other:
" :BarbarEnable - enables barbar (enabled by default)
" :BarbarDisable - very bad command, should never be used
```

#### Lua

```lua
local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Move to previous/next
map('n', '<A-,>', '<Cmd>BufferPrevious<CR>', opts)
map('n', '<A-.>', '<Cmd>BufferNext<CR>', opts)
-- Re-order to previous/next
map('n', '<A-<>', '<Cmd>BufferMovePrevious<CR>', opts)
map('n', '<A->>', '<Cmd>BufferMoveNext<CR>', opts)
-- Goto buffer in position...
map('n', '<A-1>', '<Cmd>BufferGoto 1<CR>', opts)
map('n', '<A-2>', '<Cmd>BufferGoto 2<CR>', opts)
map('n', '<A-3>', '<Cmd>BufferGoto 3<CR>', opts)
map('n', '<A-4>', '<Cmd>BufferGoto 4<CR>', opts)
map('n', '<A-5>', '<Cmd>BufferGoto 5<CR>', opts)
map('n', '<A-6>', '<Cmd>BufferGoto 6<CR>', opts)
map('n', '<A-7>', '<Cmd>BufferGoto 7<CR>', opts)
map('n', '<A-8>', '<Cmd>BufferGoto 8<CR>', opts)
map('n', '<A-9>', '<Cmd>BufferGoto 9<CR>', opts)
map('n', '<A-0>', '<Cmd>BufferLast<CR>', opts)
-- Pin/unpin buffer
map('n', '<A-p>', '<Cmd>BufferPin<CR>', opts)
-- Close buffer
map('n', '<A-c>', '<Cmd>BufferClose<CR>', opts)
-- Wipeout buffer
--                 :BufferWipeout
-- Close commands
--                 :BufferCloseAllButCurrent
--                 :BufferCloseAllButPinned
--                 :BufferCloseAllButCurrentOrPinned
--                 :BufferCloseBuffersLeft
--                 :BufferCloseBuffersRight
-- Magic buffer-picking mode
map('n', '<C-p>', '<Cmd>BufferPick<CR>', opts)
-- Sort automatically by...
map('n', '<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>', opts)
map('n', '<Space>bn', '<Cmd>BufferOrderByName<CR>', opts)
map('n', '<Space>bd', '<Cmd>BufferOrderByDirectory<CR>', opts)
map('n', '<Space>bl', '<Cmd>BufferOrderByLanguage<CR>', opts)
map('n', '<Space>bw', '<Cmd>BufferOrderByWindowNumber<CR>', opts)

-- Other:
-- :BarbarEnable - enables barbar (enabled by default)
-- :BarbarDisable - very bad command, should never be used
```

## Options

> **Note**
>
> If you're using Vim Script, just wrap `setup` like this:
>
> ```vim
> let g:barbar_auto_setup = v:false " disable auto-setup
> lua << EOF
>   require'barbar'.setup {…}
> EOF
> ```

```lua
vim.g.barbar_auto_setup = false -- disable auto-setup

require'barbar'.setup {
  -- WARN: do not copy everything below into your config!
  --       It is just an example of what configuration options there are.
  --       The defaults are suitable for most people.

  -- Enable/disable animations
  animation = true,

  -- Automatically hide the tabline when there are this many buffers left.
  -- Set to any value >=0 to enable.
  auto_hide = false,

  -- Enable/disable current/total tabpages indicator (top right corner)
  tabpages = true,

  -- Enables/disable clickable tabs
  --  - left-click: go to buffer
  --  - middle-click: delete buffer
  clickable = true,

  -- Excludes buffers from the tabline
  exclude_ft = {'javascript'},
  exclude_name = {'package.json'},

  -- A buffer to this direction will be focused (if it exists) when closing the current buffer.
  -- Valid options are 'left' (the default), 'previous', and 'right'
  focus_on_close = 'left',

  -- Hide inactive buffers and file extensions. Other options are `alternate`, `current`, and `visible`.
  hide = {extensions = true, inactive = true},

  -- Disable highlighting alternate buffers
  highlight_alternate = false,

  -- Disable highlighting file icons in inactive buffers
  highlight_inactive_file_icons = false,

  -- Enable highlighting visible buffers
  highlight_visible = true,

  icons = {
    -- Configure the base icons on the bufferline.
    -- Valid options to display the buffer index and -number are `true`, 'superscript' and 'subscript'
    buffer_index = false,
    buffer_number = false,
    button = '',
    -- Enables / disables diagnostic symbols
    diagnostics = {
      [vim.diagnostic.severity.ERROR] = {enabled = true, icon = 'ﬀ'},
      [vim.diagnostic.severity.WARN] = {enabled = false},
      [vim.diagnostic.severity.INFO] = {enabled = false},
      [vim.diagnostic.severity.HINT] = {enabled = true},
    },
    gitsigns = {
      added = {enabled = true, icon = '+'},
      changed = {enabled = true, icon = '~'},
      deleted = {enabled = true, icon = '-'},
    },
    filetype = {
      -- Sets the icon's highlight group.
      -- If false, will use nvim-web-devicons colors
      custom_colors = false,

      -- Requires `nvim-web-devicons` if `true`
      enabled = true,
    },
    separator = {left = '▎', right = ''},

    -- If true, add an additional separator at the end of the buffer list
    separator_at_end = true,

    -- Configure the icons on the bufferline when modified or pinned.
    -- Supports all the base icon options.
    modified = {button = '●'},
    pinned = {button = '', filename = true},

    -- Use a preconfigured buffer appearance— can be 'default', 'powerline', or 'slanted'
    preset = 'default',

    -- Configure the icons on the bufferline based on the visibility of a buffer.
    -- Supports all the base icon options, plus `modified` and `pinned`.
    alternate = {filetype = {enabled = false}},
    current = {buffer_index = true},
    inactive = {button = '×'},
    visible = {modified = {buffer_number = false}},
  },

  -- If true, new buffers will be inserted at the start/end of the list.
  -- Default is to insert after current buffer.
  insert_at_end = false,
  insert_at_start = false,

  -- Sets the maximum padding width with which to surround each tab
  maximum_padding = 1,

  -- Sets the minimum padding width with which to surround each tab
  minimum_padding = 1,

  -- Sets the maximum buffer name length.
  maximum_length = 30,

  -- Sets the minimum buffer name length.
  minimum_length = 0,

  -- If set, the letters for each buffer in buffer-pick mode will be
  -- assigned based on their name. Otherwise or in case all letters are
  -- already assigned, the behavior is to assign letters in order of
  -- usability (see order below)
  semantic_letters = true,

  -- Set the filetypes which barbar will offset itself for
  sidebar_filetypes = {
    -- Use the default values: {event = 'BufWinLeave', text = '', align = 'left'}
    NvimTree = true,
    -- Or, specify the text used for the offset:
    undotree = {
      text = 'undotree',
      align = 'center', -- *optionally* specify an alignment (either 'left', 'center', or 'right')
    },
    -- Or, specify the event which the sidebar executes when leaving:
    ['neo-tree'] = {event = 'BufWipeout'},
    -- Or, specify all three
    Outline = {event = 'BufWinLeave', text = 'symbols-outline', align = 'right'},
  },

  -- New buffer letters are assigned in this order. This order is
  -- optimal for the qwerty keyboard layout but might need adjustment
  -- for other layouts.
  letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',

  -- Sets the name of unnamed buffers. By default format is "[Buffer X]"
  -- where X is the buffer number. But only a static string is accepted here.
  no_name_title = nil,
}
```

### Highlighting

Highlight groups are created in this way: `Buffer<STATUS><PART>`.

| `<STATUS>`  | Meaning                                                 |
|:------------|:--------------------------------------------------------|
| `Alternate` | The `:h alternate-file`.                                |
| `Current`   | The current buffer.                                     |
| `Inactive`  | `:h hidden-buffer`s and `:h inactive-buffer`s.          |
| `Visible`   | `:h active-buffer`s which are not alternate or current. |

| `<PART>`       | Meaning                                                                              |
|:---------------|:-------------------------------------------------------------------------------------|
| `ADDED`        | Git status added.                                                                    |
| `Btn`          | The button that shows when a buffer is unpinned and unmodified.                      |
| `CHANGED`      | Git status changed.                                                                  |
| `DELETED`      | Git status deleted.                                                                  |
| `ERROR`        | Diagnostic errors.                                                                   |
| `HINT`         | Diagnostic hints.                                                                    |
| `Icon`         | The filetype icon (when `icons.filetype == {custom_colors = true, enabled = true}`). |
| `Index`        | The buffer's position in the tabline.                                                |
| `INFO`         | Diagnostic info.                                                                     |
| `Mod`          | When the buffer is modified.                                                         |
| `ModBtn`       | The button that shows when a buffer is modified.                                     |
| `Number`       | The `:h bufnr()`.                                                                    |
| `Pin`          | When the buffer is pinned.                                                           |
| `PinBtn`       | The button that shows when a buffer is pinned.                                       |
| `Sign`         | The separator between buffers.                                                       |
| `SignRight`    | The separator between buffers.                                                       |
| `Target`       | The letter in buffer-pick mode.                                                      |
| `WARN`         | Diagnostic warnings.                                                                 |

* e.g. the current buffer's highlight when modified is `BufferCurrentMod`

There are a few highlight groups which do not follow this rule. They are:

| Group               | Usage                                                                                                      |
|:--------------------|:-----------------------------------------------------------------------------------------------------------|
| `BufferOffset`      | The background of the header for a `sidebar_filetype`                                                      |
| `BufferScrollArrow` | The arrow which shows to indicate that there are more buffers to the left or right of the scroll position. |
| `BufferTabpageFill` | The space between the open buffer list and the tabpage                                                     |
| `BufferTabpages`    | The color of the tabpages indicator.                                                                       |
| `BufferTabpagesSep` | The separator between the tabpages count.                                                                  |

You can also use the [doom-one.vim](https://github.com/romgrk/doom-one.vim)
colorscheme that defines those groups and is also very pleasant as you could see
in the demos above.

## Integrations

#### [scope.nvim]

To preserve buffer order while using [scope.nvim], you can add this to your config:

```lua
require('scope').setup {
  hooks = {
    pre_tab_leave = function()
      vim.api.nvim_exec_autocmds('User', {pattern = 'ScopeTabLeavePre'})
      -- [other statements]
    end,

    post_tab_enter = function()
      vim.api.nvim_exec_autocmds('User', {pattern = 'ScopeTabEnterPost'})
      -- [other statements]
    end,

    -- [other hooks]
  },

  -- [other options]
}
```

#### Sessions

`barbar.nvim` can restore the order that your buffers were in, as well as whether a buffer was pinned. To do this, `sessionoptions` must contain `globals`, and the `User SessionSavePre` event must be executed before `:mksession`.

##### [mini.nvim]

Here is a [mini.sessions][mini.nvim] config which can be used:

```lua
vim.opt.sessionoptions:append 'globals'
require'mini.sessions'.setup {
  hooks = {
    pre = {
      write = function() vim.api.nvim_exec_autocmds('User', {pattern = 'SessionSavePre'}) end,
    },
  },
}
```

##### [persistence.nvim]

Here is a [persistence.nvim] config which can be used:

```lua
require'persistence'.setup {
  options = {--[[<other options>,]] 'globals'},
  pre_save = function() vim.api.nvim_exec_autocmds('User', {pattern = 'SessionSavePre'}) end,
}
```

##### Custom

You can add this snippet to your config to take advantage of our session integration:

```lua
vim.opt.sessionoptions:append 'globals'
vim.api.nvim_create_user_command(
  'Mksession',
  function(attr)
    vim.api.nvim_exec_autocmds('User', {pattern = 'SessionSavePre'})

    -- Neovim 0.8+
    vim.cmd.mksession {bang = attr.bang, args = attr.fargs}

    -- Neovim 0.7
    vim.api.nvim_command('mksession ' .. (attr.bang and '!' or '') .. attr.args)
  end,
  {bang = true, complete = 'file', desc = 'Save barbar with :mksession', nargs = '?'}
)
```

## Known Issues

#### Lightline

Barbar doesn't show up because lightline changes the tabline setting. Add:

```vim
let g:lightline={ 'enable': {'statusline': 1, 'tabline': 0} }
```

#### Netrw

`netrw` has a lot of bugs which make it hard to support. It may work partially, but we will not make changes to barbar.nvim to work-around `netrw`-specific bugs (e.g. #82).

You can use any other [file explorer](https://github.com/rockerBOO/awesome-neovim#file-explorer) instead.

#### Sidebars On Startup

The `sidebar_filetypes` option may not work as expected if your sidebar opens on startup. See nvim-tree/nvim-tree.lua#2130 for details, and romgrk/barbar.nvim#421 for a workaround.

## About

Barbar is called barbar because it's a bar, but it's also more than a bar:
a "barbar".

It is pronounced like "Jar Jar" in "Jar Jar Binks", but with Bs.

No, barbar has nothing to do with barbarians.

## License

* **barbar.nvim:** Distributed under the terms of the JSON license.
* **bbye.vim:** Distributed under the terms of the GNU Affero license.

[mini.nvim]: https://github.com/echasnovski/mini.nvim
[persistence.nvim]: https://github.com/folke/persistence.nvim
[scope.nvim]: https://github.com/tiagovla/scope.nvim
