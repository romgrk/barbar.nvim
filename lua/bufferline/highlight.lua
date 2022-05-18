-- !::exe [So]

local icons = require 'bufferline.icons'

-------------------
-- Section: helpers
-------------------

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

--- Generate a foreground color.
--- @param groups table<string> the groups to source the foreground color from.
--- @param default string the foreground color to use if no `groups` have a valid foreground color.
--- @param default_cterm number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function fg(groups, default, default_cterm)
  return color('foreground', groups, default, default_cterm or default)
end

--- Generate a background color.
--- @param groups table<string> the groups to source the background color from.
--- @param default string the background color to use if no `groups` have a valid background color.
--- @param default_cterm number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function bg(groups, default, default_cterm)
  return color('background', groups, default, default_cterm or default)
end

------------------
-- Section: module
------------------

--- @class bufferline.highlight
local highlight = {}

-- Initialize highlights
function highlight.setup()
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

  --      Current: current buffer
  --      Visible: visible but not current buffer
  --     Inactive: invisible but not current buffer
  --        -Icon: filetype icon
  --       -Index: buffer index
  --         -Mod: when modified
  --        -Sign: the separator between buffers
  --      -Target: letter in buffer-picking mode
  local hl = vim.go.termguicolors and
    function(group, background, foreground, bold)
      vim.api.nvim_set_hl(0, group, {
        bg = background,
        bold = bold,
        default = true,
        fg = foreground,
      })
    end or
    function(group, background, foreground, bold)
      vim.api.nvim_set_hl(0, group, {
        bold = bold,
        ctermbg = background,
        ctermfg = foreground,
        default = true,
      })
    end

  hl('BufferCurrent',        bg_current, fg_current)
  hl('BufferCurrentIndex',   bg_current, fg_special)
  hl('BufferCurrentMod',     bg_current, fg_modified)
  hl('BufferCurrentSign',    bg_current, fg_special)
  hl('BufferCurrentTarget',  bg_current, fg_target, true)
  hl('BufferInactive',       bg_inactive, fg_inactive)
  hl('BufferInactiveIndex',  bg_inactive, fg_subtle)
  hl('BufferInactiveMod',    bg_inactive, fg_modified)
  hl('BufferInactiveSign',   bg_inactive, fg_subtle)
  hl('BufferInactiveTarget', bg_inactive, fg_target, true)
  hl('BufferTabpageFill',    bg_inactive, fg_inactive)
  hl('BufferTabpages',       bg_inactive, fg_special, true)
  hl('BufferVisible',        bg_visible, fg_visible)
  hl('BufferVisibleIndex',   bg_visible, fg_visible)
  hl('BufferVisibleMod',     bg_visible, fg_modified)
  hl('BufferVisibleSign',    bg_visible, fg_visible)
  hl('BufferVisibleTarget',  bg_visible, fg_target, true)

  vim.api.nvim_set_hl(0, 'BufferCurrentIcon', {default = true, link = 'BufferCurrent'})
  vim.api.nvim_set_hl(0, 'BufferInactiveIcon', {default = true, link = 'BufferInactive'})
  vim.api.nvim_set_hl(0, 'BufferVisibleIcon', {default = true, link = 'BufferVisible'})
  vim.api.nvim_set_hl(0, 'BufferOffset', {default = true, link = 'BufferTabpageFill'})

  icons.set_highlights()
end

return highlight
