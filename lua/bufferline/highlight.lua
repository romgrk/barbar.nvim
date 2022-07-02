-- !::exe [So]

local hl = require'bufferline.utils'.hl
local icons = require 'bufferline.icons'

return {
  --- Setup the highlight groups for this plugin.
  setup = function()

    local fg_target = 'red'

    local fg_current  = hl.fg_or_default({'Normal'}, '#efefef', 255)
    local fg_visible  = hl.fg_or_default({'TabLineSel'}, '#efefef', 255)
    local fg_inactive = hl.fg_or_default({'TabLineFill'}, '#888888', 102)

    local fg_modified = hl.fg_or_default({'WarningMsg'}, '#E5AB0E', 178)
    local fg_special  = hl.fg_or_default({'Special'}, '#599eff', 75)
    local fg_subtle = hl.fg_or_default({'NonText', 'Comment'}, '#555555', 240)

    local bg_current  = hl.bg_or_default({'Normal'}, 'none')
    local bg_visible  = hl.bg_or_default({'TabLineSel', 'Normal'}, 'none')
    local bg_inactive = hl.bg_or_default({'TabLineFill', 'StatusLine'}, 'none')

    local set_default_hl = hl.get_default_setter()

    --      Current: current buffer
    --      Visible: visible but not current buffer
    --     Inactive: invisible but not current buffer
    --        -Icon: filetype icon
    --       -Index: buffer index
    --         -Mod: when modified
    --        -Sign: the separator between buffers
    --      -Target: letter in buffer-picking mode
    set_default_hl('BufferCurrent',        bg_current, fg_current)
    set_default_hl('BufferCurrentIndex',   bg_current, fg_special)
    set_default_hl('BufferCurrentMod',     bg_current, fg_modified)
    set_default_hl('BufferCurrentSign',    bg_current, fg_special)
    set_default_hl('BufferCurrentTarget',  bg_current, fg_target, true)
    set_default_hl('BufferInactive',       bg_inactive, fg_inactive)
    set_default_hl('BufferInactiveIndex',  bg_inactive, fg_subtle)
    set_default_hl('BufferInactiveMod',    bg_inactive, fg_modified)
    set_default_hl('BufferInactiveSign',   bg_inactive, fg_subtle)
    set_default_hl('BufferInactiveTarget', bg_inactive, fg_target, true)
    set_default_hl('BufferTabpageFill',    bg_inactive, fg_inactive)
    set_default_hl('BufferTabpages',       bg_inactive, fg_special, true)
    set_default_hl('BufferVisible',        bg_visible, fg_visible)
    set_default_hl('BufferVisibleIndex',   bg_visible, fg_visible)
    set_default_hl('BufferVisibleMod',     bg_visible, fg_modified)
    set_default_hl('BufferVisibleSign',    bg_visible, fg_visible)
    set_default_hl('BufferVisibleTarget',  bg_visible, fg_target, true)

    hl.set_default_link('BufferCurrentIcon', 'BufferCurrent')
    hl.set_default_link('BufferInactiveIcon', 'BufferInactive')
    hl.set_default_link('BufferVisibleIcon', 'BufferVisible')
    hl.set_default_link('BufferOffset', 'BufferTabpageFill')

    icons.set_highlights()
  end
}
