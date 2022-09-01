-- !::exe [So]

local hl = require'bufferline.utils'.hl
local icons = require 'bufferline.icons'

-- Setup the highlight groups used by the plugin.
hl.set_default_link('BufferCurrent', 'BufferDefaultCurrent')
hl.set_default_link('BufferCurrentIcon', 'BufferCurrent')
hl.set_default_link('BufferCurrentIndex', 'BufferDefaultCurrentIndex')
hl.set_default_link('BufferCurrentMod', 'BufferDefaultCurrentMod')
hl.set_default_link('BufferCurrentSign', 'BufferDefaultCurrentSign')
hl.set_default_link('BufferCurrentTarget', 'BufferDefaultCurrentTarget')
hl.set_default_link('BufferInactive', 'BufferDefaultInactive')
hl.set_default_link('BufferInactiveIcon', 'BufferInactive')
hl.set_default_link('BufferInactiveIndex', 'BufferDefaultInactiveIndex')
hl.set_default_link('BufferInactiveMod', 'BufferDefaultInactiveMod')
hl.set_default_link('BufferInactiveSign', 'BufferDefaultInactiveSign')
hl.set_default_link('BufferInactiveTarget', 'BufferDefaultInactiveTarget')
hl.set_default_link('BufferOffset', 'BufferTabpageFill')
hl.set_default_link('BufferTabpageFill', 'BufferDefaultTabpageFill')
hl.set_default_link('BufferTabpages', 'BufferDefaultTabpages')
hl.set_default_link('BufferVisible', 'BufferDefaultVisible')
hl.set_default_link('BufferVisibleIcon', 'BufferVisible')
hl.set_default_link('BufferVisibleIndex', 'BufferDefaultVisibleIndex')
hl.set_default_link('BufferVisibleMod', 'BufferDefaultVisibleMod')
hl.set_default_link('BufferVisibleSign', 'BufferDefaultVisibleSign')
hl.set_default_link('BufferVisibleTarget', 'BufferDefaultVisibleTarget')

-- NOTE: these should move to `setup_defaults` if the definition stops being a link
hl.set_default_link('BufferDefaultCurrentIcon', 'BufferDefaultCurrent')
hl.set_default_link('BufferDefaultInactiveIcon', 'BufferDefaultInactive')
hl.set_default_link('BufferDefaultVisibleIcon', 'BufferDefaultVisible')
hl.set_default_link('BufferDefaultOffset', 'BufferDefaultTabpageFill')

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
    hl.set('BufferDefaultCurrent',        bg_current, fg_current)
    hl.set('BufferDefaultCurrentIndex',   bg_current, fg_special)
    hl.set('BufferDefaultCurrentMod',     bg_current, fg_modified)
    hl.set('BufferDefaultCurrentSign',    bg_current, fg_special)
    hl.set('BufferDefaultCurrentTarget',  bg_current, fg_target, true)
    hl.set('BufferDefaultInactive',       bg_inactive, fg_inactive)
    hl.set('BufferDefaultInactiveIndex',  bg_inactive, fg_subtle)
    hl.set('BufferDefaultInactiveMod',    bg_inactive, fg_modified)
    hl.set('BufferDefaultInactiveSign',   bg_inactive, fg_subtle)
    hl.set('BufferDefaultInactiveTarget', bg_inactive, fg_target, true)
    hl.set('BufferDefaultTabpageFill',    bg_inactive, fg_inactive)
    hl.set('BufferDefaultTabpages',       bg_inactive, fg_special, true)
    hl.set('BufferDefaultVisible',        bg_visible, fg_visible)
    hl.set('BufferDefaultVisibleIndex',   bg_visible, fg_visible)
    hl.set('BufferDefaultVisibleMod',     bg_visible, fg_modified)
    hl.set('BufferDefaultVisibleSign',    bg_visible, fg_visible)
    hl.set('BufferDefaultVisibleTarget',  bg_visible, fg_target, true)

    icons.set_highlights()
  end
}
