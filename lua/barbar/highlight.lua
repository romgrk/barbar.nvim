-- !::exe [So]

local config = require('barbar.config')
local hl = require('barbar.utils.highlight')
local icons = require('barbar.icons')

-- Setup the highlight groups used by the plugin.
hl.set_default_link('BufferAlternate', 'BufferDefaultAlternate')
hl.set_default_link('BufferAlternateADDED', 'BufferDefaultAlternateADDED')
hl.set_default_link('BufferAlternateBtn', 'BufferDefaultAlternateBtn')
hl.set_default_link('BufferAlternateCHANGED', 'BufferDefaultAlternateCHANGED')
hl.set_default_link('BufferAlternateDELETED', 'BufferDefaultAlternateDELETED')
hl.set_default_link('BufferAlternateERROR', 'BufferDefaultAlternateERROR')
hl.set_default_link('BufferAlternateHINT', 'BufferDefaultAlternateHINT')
hl.set_default_link('BufferAlternateIcon', 'BufferDefaultAlternateIcon')
hl.set_default_link('BufferAlternateIndex', 'BufferDefaultAlternateIndex')
hl.set_default_link('BufferAlternateINFO', 'BufferDefaultAlternateINFO')
hl.set_default_link('BufferAlternateMod', 'BufferDefaultAlternateMod')
hl.set_default_link('BufferAlternateModBtn', 'BufferDefaultAlternateModBtn')
hl.set_default_link('BufferAlternateNumber', 'BufferDefaultAlternateNumber')
hl.set_default_link('BufferAlternatePin', 'BufferDefaultAlternatePin')
hl.set_default_link('BufferAlternatePinBtn', 'BufferDefaultAlternatePinBtn')
hl.set_default_link('BufferAlternateSign', 'BufferDefaultAlternateSign')
hl.set_default_link('BufferAlternateSignRight', 'BufferDefaultAlternateSignRight')
hl.set_default_link('BufferAlternateTarget', 'BufferDefaultAlternateTarget')
hl.set_default_link('BufferAlternateWARN', 'BufferDefaultAlternateWARN')

hl.set_default_link('BufferCurrent', 'BufferDefaultCurrent')
hl.set_default_link('BufferCurrentADDED', 'BufferDefaultCurrentADDED')
hl.set_default_link('BufferCurrentBtn', 'BufferDefaultCurrentBtn')
hl.set_default_link('BufferCurrentCHANGED', 'BufferDefaultCurrentCHANGED')
hl.set_default_link('BufferCurrentDELETED', 'BufferDefaultCurrentDELETED')
hl.set_default_link('BufferCurrentERROR', 'BufferDefaultCurrentERROR')
hl.set_default_link('BufferCurrentHINT', 'BufferDefaultCurrentHINT')
hl.set_default_link('BufferCurrentIcon', 'BufferDefaultCurrentIcon')
hl.set_default_link('BufferCurrentIndex', 'BufferDefaultCurrentIndex')
hl.set_default_link('BufferCurrentINFO', 'BufferDefaultCurrentINFO')
hl.set_default_link('BufferCurrentMod', 'BufferDefaultCurrentMod')
hl.set_default_link('BufferCurrentModBtn', 'BufferDefaultCurrentModBtn')
hl.set_default_link('BufferCurrentNumber', 'BufferDefaultCurrentNumber')
hl.set_default_link('BufferCurrentPin', 'BufferDefaultCurrentPin')
hl.set_default_link('BufferCurrentPinBtn', 'BufferDefaultCurrentPinBtn')
hl.set_default_link('BufferCurrentSign', 'BufferDefaultCurrentSign')
hl.set_default_link('BufferCurrentSignRight', 'BufferDefaultCurrentSignRight')
hl.set_default_link('BufferCurrentTarget', 'BufferDefaultCurrentTarget')
hl.set_default_link('BufferCurrentWARN', 'BufferDefaultCurrentWARN')

hl.set_default_link('BufferInactive', 'BufferDefaultInactive')
hl.set_default_link('BufferInactiveADDED', 'BufferDefaultInactiveADDED')
hl.set_default_link('BufferInactiveBtn', 'BufferDefaultInactiveBtn')
hl.set_default_link('BufferInactiveCHANGED', 'BufferDefaultInactiveCHANGED')
hl.set_default_link('BufferInactiveDELETED', 'BufferDefaultInactiveDELETED')
hl.set_default_link('BufferInactiveERROR', 'BufferDefaultInactiveERROR')
hl.set_default_link('BufferInactiveHINT', 'BufferDefaultInactiveHINT')
hl.set_default_link('BufferInactiveIcon', 'BufferDefaultInactiveIcon')
hl.set_default_link('BufferInactiveIndex', 'BufferDefaultInactiveIndex')
hl.set_default_link('BufferInactiveINFO', 'BufferDefaultInactiveINFO')
hl.set_default_link('BufferInactiveMod', 'BufferDefaultInactiveMod')
hl.set_default_link('BufferInactiveModBtn', 'BufferDefaultInactiveModBtn')
hl.set_default_link('BufferInactiveNumber', 'BufferDefaultInactiveNumber')
hl.set_default_link('BufferInactivePin', 'BufferDefaultInactivePin')
hl.set_default_link('BufferInactivePinBtn', 'BufferDefaultInactivePinBtn')
hl.set_default_link('BufferInactiveSign', 'BufferDefaultInactiveSign')
hl.set_default_link('BufferInactiveSignRight', 'BufferDefaultInactiveSignRight')
hl.set_default_link('BufferInactiveTarget', 'BufferDefaultInactiveTarget')
hl.set_default_link('BufferInactiveWARN', 'BufferDefaultInactiveWARN')

hl.set_default_link('BufferOffset', 'BufferDefaultOffset')
hl.set_default_link('BufferScrollArrow', 'BufferDefaultTabpagesSep')

hl.set_default_link('BufferTabpageFill', 'BufferDefaultTabpageFill')
hl.set_default_link('BufferTabpages', 'BufferDefaultTabpages')
hl.set_default_link('BufferTabpagesSep', 'BufferDefaultTabpagesSep')

hl.set_default_link('BufferVisible', 'BufferDefaultVisible')
hl.set_default_link('BufferVisibleADDED', 'BufferDefaultVisibleADDED')
hl.set_default_link('BufferVisibleBtn', 'BufferDefaultVisibleBtn')
hl.set_default_link('BufferVisibleCHANGED', 'BufferDefaultVisibleCHANGED')
hl.set_default_link('BufferVisibleDELETED', 'BufferDefaultVisibleDELETED')
hl.set_default_link('BufferVisibleERROR', 'BufferDefaultVisibleERROR')
hl.set_default_link('BufferVisibleHINT', 'BufferDefaultVisibleHINT')
hl.set_default_link('BufferVisibleIcon', 'BufferDefaultVisibleIcon')
hl.set_default_link('BufferVisibleIndex', 'BufferDefaultVisibleIndex')
hl.set_default_link('BufferVisibleINFO', 'BufferDefaultVisibleINFO')
hl.set_default_link('BufferVisibleMod', 'BufferDefaultVisibleMod')
hl.set_default_link('BufferVisibleModBtn', 'BufferDefaultVisibleModBtn')
hl.set_default_link('BufferVisibleNumber', 'BufferDefaultVisibleNumber')
hl.set_default_link('BufferVisiblePin', 'BufferDefaultVisiblePin')
hl.set_default_link('BufferVisiblePinBtn', 'BufferDefaultVisiblePinBtn')
hl.set_default_link('BufferVisibleSign', 'BufferDefaultVisibleSign')
hl.set_default_link('BufferVisibleSignRight', 'BufferDefaultVisibleSignRight')
hl.set_default_link('BufferVisibleTarget', 'BufferDefaultVisibleTarget')
hl.set_default_link('BufferVisibleWARN', 'BufferDefaultVisibleWARN')

-- NOTE: these should move to `setup_defaults` if the definition stops being a link

hl.set_default_link('BufferDefaultAlternateBtn', 'BufferAlternate')
hl.set_default_link('BufferDefaultAlternateIcon', 'BufferAlternate')
hl.set_default_link('BufferDefaultAlternateModBtn', 'BufferAlternateMod')
hl.set_default_link('BufferDefaultAlternateNumber', 'BufferAlternateIndex')
hl.set_default_link('BufferDefaultAlternatePin', 'BufferAlternate')
hl.set_default_link('BufferDefaultAlternatePinBtn', 'BufferAlternatePin')
hl.set_default_link('BufferDefaultAlternateSignRight', 'BufferAlternateSign')
hl.set_default_link('BufferDefaultCurrentBtn', 'BufferCurrent')
hl.set_default_link('BufferDefaultCurrentIcon', 'BufferCurrent')
hl.set_default_link('BufferDefaultCurrentModBtn', 'BufferCurrentMod')
hl.set_default_link('BufferDefaultCurrentNumber', 'BufferCurrentIndex')
hl.set_default_link('BufferDefaultCurrentPin', 'BufferCurrent')
hl.set_default_link('BufferDefaultCurrentPinBtn', 'BufferCurrentPin')
hl.set_default_link('BufferDefaultCurrentSignRight', 'BufferCurrentSign')
hl.set_default_link('BufferDefaultInactiveBtn', 'BufferInactive')
hl.set_default_link('BufferDefaultInactiveIcon', 'BufferInactive')
hl.set_default_link('BufferDefaultInactiveModBtn', 'BufferInactiveMod')
hl.set_default_link('BufferDefaultInactiveNumber', 'BufferInactiveIndex')
hl.set_default_link('BufferDefaultInactivePin', 'BufferInactive')
hl.set_default_link('BufferDefaultInactivePinBtn', 'BufferInactivePin')
hl.set_default_link('BufferDefaultInactiveSignRight', 'BufferInactiveSign')
hl.set_default_link('BufferDefaultOffset', 'BufferTabpageFill')
hl.set_default_link('BufferDefaultVisibleBtn', 'BufferVisible')
hl.set_default_link('BufferDefaultVisibleIcon', 'BufferVisible')
hl.set_default_link('BufferDefaultVisibleModBtn', 'BufferVisibleMod')
hl.set_default_link('BufferDefaultVisibleNumber', 'BufferVisibleIndex')
hl.set_default_link('BufferDefaultVisiblePin', 'BufferVisible')
hl.set_default_link('BufferDefaultVisiblePinBtn', 'BufferVisiblePin')
hl.set_default_link('BufferDefaultVisibleSignRight', 'BufferVisibleSign')

--- @class barbar.Highlight
local highlight = {}

--- Setup the highlight groups for this plugin.
--- @return nil
function highlight.setup()
  local preset = config.options.icons.preset

  local fg_target = {cterm = 'red', gui = 'red'} --- @type barbar.utils.hl.color

  local fg_added = hl.fg_or_default({'GitSignsAdd'}, '#59ff5a', 82)
  local fg_changed = hl.fg_or_default({'GitSignsChange'}, '#599eff', 75)
  local fg_deleted = hl.fg_or_default({'GitSignsDelete'}, '#A80000', 124)

  local fg_error = hl.fg_or_default({'DiagnosticSignError'}, '#A80000', 124)
  local fg_hint = hl.fg_or_default({'DiagnosticSignHint'}, '#D5508F', 168)
  local fg_info = hl.fg_or_default({'DiagnosticSignInfo'}, '#FFB7B7', 217)
  local fg_warn = hl.fg_or_default({'DiagnosticSignWarn'}, '#FF8900', 208)

  local fg_modified = hl.fg_or_default({'WarningMsg'}, '#E5AB0E', 178)
  local fg_special = hl.fg_or_default({'Special'}, '#599eff', 75)
  local fg_subtle = hl.fg_or_default({'NonText', 'Comment'}, '#555555', 240)

  local bg_tabline
  do
    local tabpage_hl = {'TabLineFill', 'StatusLine'}

    bg_tabline = hl.bg_or_default(tabpage_hl, 'none')

    hl.set('BufferDefaultTabpages', bg_tabline, hl.fg_or_default({'Number'}, '#599eff', 75), nil, {bold = true})
    hl.set('BufferDefaultTabpageFill', bg_tabline, hl.fg_or_default(tabpage_hl, '#888888', 102))
    hl.set('BufferDefaultTabpagesSep', bg_tabline, hl.fg_or_default({'Delimiter'}, 0xFFFFFF, 255), nil, {bold = true})
  end

  --    Alternate: alternate buffer
  --      Current: current buffer
  --      Visible: visible but not current buffer
  --     Inactive: invisible but not current buffer
  --        -Icon: filetype icon
  --       -Index: buffer index
  --      -Number: buffer number
  --         -Mod: when modified
  --        -Sign: the separator between buffers
  --      -Target: letter in buffer-picking mode
  if config.options.highlight_alternate then
    local alternate_hl = {'TabLine', 'StatusLine'}

    local attributes = hl.definition(alternate_hl) or {}

    local bg = hl.bg_or_default(alternate_hl, 'none')
    local fg = hl.fg_or_default(alternate_hl, 0xEAD0A0, 223)
    local sp --- @type barbar.utils.hl.color.value

    if preset == 'default' then
      hl.remove_underline_attributes(attributes)
      hl.set('BufferDefaultAlternateSign', bg, fg_special, sp, attributes)
    else
      sp = hl.fg_or_default({'DiagnosticSignHint'}, 0xD5508F).gui
      attributes.underline = true

      hl.set('BufferDefaultAlternateSign', bg, bg_tabline, sp, attributes)
      if preset == 'powerline' then
        hl.set('BufferDefaultAlternateSignRight', bg_tabline, bg, sp)
      end
    end

    hl.set('BufferDefaultAlternate',        bg, fg, sp, attributes)
    hl.set('BufferDefaultAlternateADDED',   bg, fg_added, sp, attributes)
    hl.set('BufferDefaultAlternateCHANGED', bg, fg_changed, sp, attributes)
    hl.set('BufferDefaultAlternateDELETED', bg, fg_deleted, sp, attributes)
    hl.set('BufferDefaultAlternateERROR',   bg, fg_error, sp, attributes)
    hl.set('BufferDefaultAlternateHINT',    bg, fg_hint, sp, attributes)
    hl.set('BufferDefaultAlternateIndex',   bg, fg_special, sp, attributes)
    hl.set('BufferDefaultAlternateINFO',    bg, fg_info, sp, attributes)
    hl.set('BufferDefaultAlternateMod',     bg, fg_modified, sp, attributes)
    hl.set('BufferDefaultAlternateWARN',    bg, fg_warn, sp, attributes)

    attributes.bold = true
    hl.set('BufferDefaultAlternateTarget',  bg, fg_target, sp, attributes)
  end

  do
    local current_hl = {'TabLineSel'}

    local attributes = hl.definition(current_hl) or {}
    local bg = hl.bg_or_default(current_hl, 'none')
    local fg = hl.fg_or_default(current_hl, '#efefef', 255)
    local sp --- @type barbar.utils.hl.color.value

    if preset == 'default' then
      hl.remove_underline_attributes(attributes)
      hl.set('BufferDefaultCurrentSign', bg, fg_special, sp, attributes)
    else
      sp = hl.sp_or_default(current_hl, 0x60AFFF)
      attributes.underline = true

      hl.set('BufferDefaultCurrentSign', bg, bg_tabline, sp, attributes)
      if preset == 'powerline' then
        hl.set('BufferDefaultCurrentSignRight', bg_tabline, bg, sp)
      end
    end

    hl.set('BufferDefaultCurrent',        bg, fg, sp, attributes)
    hl.set('BufferDefaultCurrentADDED',   bg, fg_added, sp, attributes)
    hl.set('BufferDefaultCurrentCHANGED', bg, fg_changed, sp, attributes)
    hl.set('BufferDefaultCurrentDELETED', bg, fg_deleted, sp, attributes)
    hl.set('BufferDefaultCurrentERROR',   bg, fg_error, sp, attributes)
    hl.set('BufferDefaultCurrentHINT',    bg, fg_hint, sp, attributes)
    hl.set('BufferDefaultCurrentIndex',   bg, fg_special, sp, attributes)
    hl.set('BufferDefaultCurrentINFO',    bg, fg_info, sp, attributes)
    hl.set('BufferDefaultCurrentMod',     bg, fg_modified, sp, attributes)
    hl.set('BufferDefaultCurrentWARN',    bg, fg_warn, sp, attributes)

    attributes.bold = true
    hl.set('BufferDefaultCurrentTarget',  bg, fg_target, sp, attributes)
  end

  do
    local inactive_hl = {'TabLine', 'StatusLine'}

    local attributes = hl.definition(inactive_hl) or {}
    hl.remove_underline_attributes(attributes)

    local bg = hl.bg_or_default(inactive_hl, 'none')
    local fg = hl.fg_or_default(inactive_hl, '#efefef', 255)

    hl.set('BufferDefaultInactive',       bg, fg, nil, attributes)
    hl.set('BufferDefaultInactiveADDED',  bg, fg_added, nil, attributes)
    hl.set('BufferDefaultInactiveCHANGED',bg, fg_changed, nil, attributes)
    hl.set('BufferDefaultInactiveDELETED',bg, fg_deleted, nil, attributes)
    hl.set('BufferDefaultInactiveERROR',  bg, fg_error, nil, attributes)
    hl.set('BufferDefaultInactiveHINT',   bg, fg_hint, nil, attributes)
    hl.set('BufferDefaultInactiveIndex',  bg, fg_subtle, nil, attributes)
    hl.set('BufferDefaultInactiveINFO',   bg, fg_info, nil, attributes)
    hl.set('BufferDefaultInactiveMod',    bg, fg_modified, nil, attributes)
    hl.set('BufferDefaultInactiveWARN',   bg, fg_warn, nil, attributes)

    if preset == 'default' then
      hl.set('BufferDefaultInactiveSign', bg, fg_subtle, nil, attributes)
    else
      hl.set('BufferDefaultInactiveSign', bg, bg_tabline, nil, attributes)
      if preset == 'powerline' then
        hl.set('BufferDefaultInactiveSignRight', bg_tabline, bg)
      end
    end

    attributes.bold = true
    hl.set('BufferDefaultInactiveTarget', bg, fg_target, nil, attributes)
  end

  if config.options.highlight_visible then
    local visible_hl = {'TabLine', 'StatusLine'}

    local attributes = hl.definition(visible_hl) or {}
    local bg = hl.bg_or_default(visible_hl, 'none')
    local fg = hl.fg_or_default(visible_hl, '#efefef', 255)
    local sp --- @type barbar.utils.hl.color.value

    if preset == 'default' then
      hl.remove_underline_attributes(attributes)
      hl.set('BufferDefaultVisibleSign', bg, fg, sp, attributes)
    else
      sp = hl.fg_or_default({'Delimiter'}, 0xFFFFFF).gui
      attributes.underline = true

      hl.set('BufferDefaultVisibleSign', bg, bg_tabline, sp, attributes)
      if preset == 'powerline' then
        hl.set('BufferDefaultVisibleSignRight', bg_tabline, bg, sp)
      end
    end

    hl.set('BufferDefaultVisible',        bg, fg, sp, attributes)
    hl.set('BufferDefaultVisibleADDED',   bg, fg_warn, sp, attributes)
    hl.set('BufferDefaultVisibleCHANGED', bg, fg_warn, sp, attributes)
    hl.set('BufferDefaultVisibleDELETED', bg, fg_warn, sp, attributes)
    hl.set('BufferDefaultVisibleERROR',   bg, fg_error, sp, attributes)
    hl.set('BufferDefaultVisibleHINT',    bg, fg_hint, sp, attributes)
    hl.set('BufferDefaultVisibleIndex',   bg, fg, sp, attributes)
    hl.set('BufferDefaultVisibleINFO',    bg, fg_info, sp, attributes)
    hl.set('BufferDefaultVisibleMod',     bg, fg_modified, sp, attributes)
    hl.set('BufferDefaultVisibleWARN',    bg, fg_warn, sp, attributes)

    attributes.bold = true
    hl.set('BufferDefaultVisibleTarget',  bg, fg_target, sp, attributes)
  end

  icons.set_highlights()
end

return highlight
