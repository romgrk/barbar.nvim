-- !::exe [So]

--- @type bufferline.utils.hl
local hl = require'bufferline.utils'.hl

--- @type bufferline.icons
local icons = require 'bufferline.icons'

--- @type bufferline.options
local options = require 'bufferline.options'

-- Setup the highlight groups used by the plugin.
hl.set_default_link('BufferAlternate', 'BufferDefaultAlternate')
hl.set_default_link('BufferAlternateERROR', 'BufferDefaultAlternateERROR')
hl.set_default_link('BufferAlternateHINT', 'BufferDefaultAlternateHINT')
hl.set_default_link('BufferAlternateIcon', 'BufferDefaultAlternateIcon')
hl.set_default_link('BufferAlternateIndex', 'BufferDefaultAlternateIndex')
hl.set_default_link('BufferAlternateINFO', 'BufferDefaultAlternateINFO')
hl.set_default_link('BufferAlternateMod', 'BufferDefaultAlternateMod')
hl.set_default_link('BufferAlternateSign', 'BufferDefaultAlternateSign')
hl.set_default_link('BufferAlternateTarget', 'BufferDefaultAlternateTarget')
hl.set_default_link('BufferAlternateWARN', 'BufferDefaultAlternateWARN')

hl.set_default_link('BufferCurrent', 'BufferDefaultCurrent')
hl.set_default_link('BufferCurrentERROR', 'BufferDefaultCurrentERROR')
hl.set_default_link('BufferCurrentHINT', 'BufferDefaultCurrentHINT')
hl.set_default_link('BufferCurrentIcon', 'BufferDefaultCurrentIcon')
hl.set_default_link('BufferCurrentIndex', 'BufferDefaultCurrentIndex')
hl.set_default_link('BufferCurrentINFO', 'BufferDefaultCurrentINFO')
hl.set_default_link('BufferCurrentMod', 'BufferDefaultCurrentMod')
hl.set_default_link('BufferCurrentSign', 'BufferDefaultCurrentSign')
hl.set_default_link('BufferCurrentTarget', 'BufferDefaultCurrentTarget')
hl.set_default_link('BufferCurrentWARN', 'BufferDefaultCurrentWARN')

hl.set_default_link('BufferInactive', 'BufferDefaultInactive')
hl.set_default_link('BufferInactiveERROR', 'BufferDefaultInactiveERROR')
hl.set_default_link('BufferInactiveHINT', 'BufferDefaultInactiveHINT')
hl.set_default_link('BufferInactiveIcon', 'BufferDefaultInactiveIcon')
hl.set_default_link('BufferInactiveIndex', 'BufferDefaultInactiveIndex')
hl.set_default_link('BufferInactiveINFO', 'BufferDefaultInactiveINFO')
hl.set_default_link('BufferInactiveMod', 'BufferDefaultInactiveMod')
hl.set_default_link('BufferInactiveSign', 'BufferDefaultInactiveSign')
hl.set_default_link('BufferInactiveTarget', 'BufferDefaultInactiveTarget')
hl.set_default_link('BufferInactiveWARN', 'BufferDefaultInactiveWARN')

hl.set_default_link('BufferOffset', 'BufferTabpageFill')

hl.set_default_link('BufferTabpageFill', 'BufferDefaultTabpageFill')
hl.set_default_link('BufferTabpages', 'BufferDefaultTabpages')

hl.set_default_link('BufferVisible', 'BufferDefaultVisible')
hl.set_default_link('BufferVisibleERROR', 'BufferDefaultVisibleERROR')
hl.set_default_link('BufferVisibleHINT', 'BufferDefaultVisibleHINT')
hl.set_default_link('BufferVisibleIcon', 'BufferDefaultVisibleIcon')
hl.set_default_link('BufferVisibleIndex', 'BufferDefaultVisibleIndex')
hl.set_default_link('BufferVisibleINFO', 'BufferDefaultVisibleINFO')
hl.set_default_link('BufferVisibleMod', 'BufferDefaultVisibleMod')
hl.set_default_link('BufferVisibleSign', 'BufferDefaultVisibleSign')
hl.set_default_link('BufferVisibleTarget', 'BufferDefaultVisibleTarget')
hl.set_default_link('BufferVisibleWARN', 'BufferDefaultVisibleWARN')

-- NOTE: these should move to `setup_defaults` if the definition stops being a link
hl.set_default_link('BufferDefaultAlternateIcon', 'BufferAlternate')
hl.set_default_link('BufferDefaultCurrentIcon', 'BufferCurrent')
hl.set_default_link('BufferDefaultInactiveIcon', 'BufferInactive')
hl.set_default_link('BufferDefaultVisibleIcon', 'BufferVisible')
hl.set_default_link('BufferDefaultOffset', 'BufferTabpageFill')

--- @class bufferline.highlight
return {
  --- Setup the highlight groups for this plugin.
  setup = function()
    local fg_current = hl.fg_or_default({'Normal'}, '#efefef', 255)
    local fg_inactive = hl.fg_or_default({'TabLineFill'}, '#888888', 102)
    --- @type barbar.utils.hl.group
    local fg_target = {gui = 'red'}
    fg_target.cterm = fg_target.gui

    local fg_error = hl.fg_or_default({'ErrorMsg'}, '#A80000', 124)
    local fg_hint = hl.fg_or_default({'HintMsg'}, '#D5508F', 168)
    local fg_info = hl.fg_or_default({'InfoMsg'}, '#FFB7B7', 217)
    local fg_warn = hl.fg_or_default({'WarningMsg'}, '#FF8900', 208)

    local fg_modified = hl.fg_or_default({'WarningMsg'}, '#E5AB0E', 178)
    local fg_special = hl.fg_or_default({'Special'}, '#599eff', 75)
    local fg_subtle = hl.fg_or_default({'NonText', 'Comment'}, '#555555', 240)

    local bg_current = hl.bg_or_default({'Normal'}, 'none')
    local bg_inactive = hl.bg_or_default({'TabLineFill', 'StatusLine'}, 'none')

    --    Alternate: alternate buffer
    --      Current: current buffer
    --      Visible: visible but not current buffer
    --     Inactive: invisible but not current buffer
    --        -Icon: filetype icon
    --       -Index: buffer index
    --         -Mod: when modified
    --        -Sign: the separator between buffers
    --      -Target: letter in buffer-picking mode
    if options.highlight_alternate() then
      local fg_alternate = hl.fg_or_default({'TabLineFill'}, '#ead0a0', 223)
      local bg_alternate = hl.bg_or_default({'TabLineSel', 'Normal'}, 'none')

      hl.set('BufferDefaultAlternate',        bg_alternate, fg_alternate)
      hl.set('BufferDefaultAlternateERROR',   bg_alternate, fg_error)
      hl.set('BufferDefaultAlternateHINT',    bg_alternate, fg_hint)
      hl.set('BufferDefaultAlternateIndex',   bg_alternate, fg_special)
      hl.set('BufferDefaultAlternateINFO',    bg_alternate, fg_info)
      hl.set('BufferDefaultAlternateMod',     bg_alternate, fg_modified)
      hl.set('BufferDefaultAlternateSign',    bg_alternate, fg_special)
      hl.set('BufferDefaultAlternateTarget',  bg_alternate, fg_target, true)
      hl.set('BufferDefaultAlternateWARN',    bg_alternate, fg_warn)
    end

    hl.set('BufferDefaultCurrent',        bg_current, fg_current)
    hl.set('BufferDefaultCurrentERROR',   bg_current, fg_error)
    hl.set('BufferDefaultCurrentHINT',    bg_current, fg_hint)
    hl.set('BufferDefaultCurrentIndex',   bg_current, fg_special)
    hl.set('BufferDefaultCurrentINFO',    bg_current, fg_info)
    hl.set('BufferDefaultCurrentMod',     bg_current, fg_modified)
    hl.set('BufferDefaultCurrentSign',    bg_current, fg_special)
    hl.set('BufferDefaultCurrentTarget',  bg_current, fg_target, true)
    hl.set('BufferDefaultCurrentWARN',    bg_current, fg_warn)

    hl.set('BufferDefaultInactive',       bg_inactive, fg_inactive)
    hl.set('BufferDefaultInactiveERROR',  bg_inactive, fg_error)
    hl.set('BufferDefaultInactiveHINT',   bg_inactive, fg_hint)
    hl.set('BufferDefaultInactiveIndex',  bg_inactive, fg_subtle)
    hl.set('BufferDefaultInactiveINFO',   bg_inactive, fg_info)
    hl.set('BufferDefaultInactiveMod',    bg_inactive, fg_modified)
    hl.set('BufferDefaultInactiveSign',   bg_inactive, fg_subtle)
    hl.set('BufferDefaultInactiveTarget', bg_inactive, fg_target, true)
    hl.set('BufferDefaultInactiveWARN',   bg_inactive, fg_warn)

    hl.set('BufferDefaultTabpageFill',    bg_inactive, fg_inactive)
    hl.set('BufferDefaultTabpages',       bg_inactive, fg_special, true)

    if options.highlight_visible() then
      local fg_visible = hl.fg_or_default({'TabLineSel'}, '#efefef', 255)
      local bg_visible = hl.bg_or_default({'TabLineSel', 'Normal'}, 'none')

      hl.set('BufferDefaultVisible',        bg_visible, fg_visible)
      hl.set('BufferDefaultVisibleERROR',   bg_visible, fg_error)
      hl.set('BufferDefaultVisibleHINT',    bg_visible, fg_hint)
      hl.set('BufferDefaultVisibleIndex',   bg_visible, fg_visible)
      hl.set('BufferDefaultVisibleINFO',    bg_visible, fg_info)
      hl.set('BufferDefaultVisibleMod',     bg_visible, fg_modified)
      hl.set('BufferDefaultVisibleSign',    bg_visible, fg_visible)
      hl.set('BufferDefaultVisibleTarget',  bg_visible, fg_target, true)
      hl.set('BufferDefaultVisibleWARN',    bg_visible, fg_warn)
    end

    icons.set_highlights()
  end
}
