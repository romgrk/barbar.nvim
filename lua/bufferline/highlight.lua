-- !::exe [So]

local set_hl = vim.api.nvim_set_hl

local icons = require 'bufferline.icons'

--- Generate a color.
--- @param index string where to look for the color.
--- @param groups table<string> the groups to source the color from.
--- @param default string the color to use if no `groups` have a valid color.
--- @param default_cterm number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function color(index, groups, default, default_cterm)
  local guicolors = vim.go.termguicolors
  for _, group in ipairs(groups) do
    local hl = vim.api.nvim_get_hl_by_name(group, guicolors)
    if hl[index] then
      return guicolors and string.format('#%06x', hl[index]) or hl[index]
    end
  end
  return guicolors and default or default_cterm
end

--- Generate a background color.
--- @param groups table<string> the groups to source the background color from.
--- @param default string the background color to use if no `groups` have a valid background color.
--- @param default_cterm nil|number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function bg(groups, default, default_cterm)
  return color('background', groups, default, default_cterm or default)
end

--- Generate a foreground color.
--- @param groups table<string> the groups to source the foreground color from.
--- @param default string the foreground color to use if no `groups` have a valid foreground color.
--- @param default_cterm nil|number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function fg(groups, default, default_cterm)
  return color('foreground', groups, default, default_cterm or default)
end

--- Set the default highlight `group_name` as a link to `link_name`
--- @param group_name string the name of the group to by-default be linked to `link_name`
--- @param link_name string the name of the group to by-default link `group_name` to
local function set_default_hl_link(group_name, link_name)
  set_hl(0, group_name, {default = true, link = link_name})
end

return {
  --- Setup the highlight groups for this plugin.
  setup = function()

    local fg_target = 'red'

    local fg_current  = fg({'Normal'}, '#efefef', 255)
    local fg_visible  = fg({'TabLineSel'}, '#efefef', 255)
    local fg_inactive = fg({'TabLineFill'}, '#888888', 102)

    local fg_modified = fg({'WarningMsg'}, '#E5AB0E', 178)
    local fg_special  = fg({'Special'}, '#599eff', 75)
    local fg_subtle = fg({'NonText', 'Comment'}, '#555555', 240)

    local bg_current  = bg({'Normal'}, 'none', nil)
    local bg_visible  = bg({'TabLineSel', 'Normal'}, 'none', nil)
    local bg_inactive = bg({'TabLineFill', 'StatusLine'}, 'none', nil)

    --- Set some highlight `group`'s default definition with respect to `&termguicolors`
    --- @param group string the name of the highlight group to set
    --- @param background number|string the background color
    --- @param foreground number|string the foreground color
    --- @param bold boolean|nil whether the highlight group should be bolded
    local set_default_hl = vim.go.termguicolors and function(group, background, foreground, bold)
        set_hl(0, group, {bg = background, bold = bold, default = true, fg = foreground})
      end or function(group, background, foreground, bold)
        set_hl(0, group, {bold = bold, ctermbg = background, ctermfg = foreground, default = true})
      end

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

    set_default_hl_link('BufferCurrentIcon', 'BufferCurrent')
    set_default_hl_link('BufferInactiveIcon', 'BufferInactive')
    set_default_hl_link('BufferVisibleIcon', 'BufferVisible')
    set_default_hl_link('BufferOffset', 'BufferTabpageFill')

    icons.set_highlights()
  end
}
