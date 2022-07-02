-- !::exe [So]

local hl = require'bufferline.utils'.hl
local icons = require 'bufferline.icons'

return {
  --- Setup the highlight groups for this plugin.
  setup = function()

    --- @type barbar.util.Highlight
    local fg_target = {cterm = 'red'}
    fg_target.gui = fg_target.cterm

    local fg_current  = hl.fg_or_default({'Normal'}, '#efefef', 255)
    local fg_visible  = hl.fg_or_default({'TabLineSel'}, '#efefef', 255)
    local fg_inactive = hl.fg_or_default({'TabLineFill'}, '#888888', 102)

    local fg_modified = hl.fg_or_default({'WarningMsg'}, '#E5AB0E', 178)
    local fg_special  = hl.fg_or_default({'Special'}, '#599eff', 75)
    local fg_subtle = hl.fg_or_default({'NonText', 'Comment'}, '#555555', 240)

    local bg_current  = hl.bg_or_default({'Normal'}, 'none')
    local bg_visible  = hl.bg_or_default({'TabLineSel', 'Normal'}, 'none')
    local bg_inactive = hl.bg_or_default({'TabLineFill', 'StatusLine'}, 'none')

    --      Current: current buffer
    --      Visible: visible but not current buffer
    --     Inactive: invisible but not current buffer
    --        -Icon: filetype icon
    --       -Index: buffer index
    --         -Mod: when modified
    --        -Sign: the separator between buffers
    --      -Target: letter in buffer-picking mode
    hl.set_default('BufferCurrent',        bg_current, fg_current)
    hl.set_default('BufferCurrentIndex',   bg_current, fg_special)
    hl.set_default('BufferCurrentMod',     bg_current, fg_modified)
    hl.set_default('BufferCurrentSign',    bg_current, fg_special)
    hl.set_default('BufferCurrentTarget',  bg_current, fg_target, true)
    hl.set_default('BufferInactive',       bg_inactive, fg_inactive)
    hl.set_default('BufferInactiveIndex',  bg_inactive, fg_subtle)
    hl.set_default('BufferInactiveMod',    bg_inactive, fg_modified)
    hl.set_default('BufferInactiveSign',   bg_inactive, fg_subtle)
    hl.set_default('BufferInactiveTarget', bg_inactive, fg_target, true)
    hl.set_default('BufferTabpageFill',    bg_inactive, fg_inactive)
    hl.set_default('BufferTabpages',       bg_inactive, fg_special, true)
    hl.set_default('BufferVisible',        bg_visible, fg_visible)
    hl.set_default('BufferVisibleIndex',   bg_visible, fg_visible)
    hl.set_default('BufferVisibleMod',     bg_visible, fg_modified)
    hl.set_default('BufferVisibleSign',    bg_visible, fg_visible)
    hl.set_default('BufferVisibleTarget',  bg_visible, fg_target, true)

    hl.set_default_link('BufferCurrentIcon', 'BufferCurrent')
    hl.set_default_link('BufferInactiveIcon', 'BufferInactive')
    hl.set_default_link('BufferVisibleIcon', 'BufferVisible')
    hl.set_default_link('BufferOffset', 'BufferTabpageFill')

    icons.set_highlights()
  end
}
