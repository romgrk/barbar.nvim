-- !::exe [So]

-------------------
-- Section: helpers
-------------------

--- Generate a color.
--- @param index string where to look for the color.
--- @param groups table<string> the groups to source the color from.
--- @param default string the foreground color to use if no `groups` have a valid color.
--- @return string color
local function color(index, groups, default)
  local guicolors = vim.go.termguicolors
  for _, group in ipairs(groups) do
    local hl = vim.api.nvim_get_hl_by_name(group, guicolors)
    if hl[index] then
      return guicolors and string.format('#%06x', hl[index]) or hl[index]
    end
  end
  return default
end

--- Generate a foreground color.
--- @param groups table<string> the groups to source the foreground color from.
--- @param default string the foreground color to use if no `groups` have a valid foreground color.
--- @return string color
local function fg(groups, default)
  return color('foreground', groups, default)
end

--- Generate a background color.
--- @param groups table<string> the groups to source the background color from.
--- @param default string the background color to use if no `groups` have a valid background color.
--- @return string color
local function bg(groups, default)
  return color('background', groups, default)
end

------------------
-- Section: module
------------------

--- @class bufferline.highlight
local highlight = {}

-- Initialize highlights
function highlight.setup()
  local guicolors = vim.go.termguicolors

  local fg_target = 'red'

  local fg_current  = fg({'Normal'}, guicolors and '#efefef' or 255)
  local fg_visible  = fg({'TabLineSel'}, guicolors and '#efefef' or 255)
  local fg_inactive = fg({'TabLineFill'}, guicolors and '#888888' or 102)

  local fg_modified = fg({'WarningMsg'}, guicolors and '#E5AB0E' or 178)
  local fg_special  = fg({'Special'}, guicolors and '#599eff' or 75)
  local fg_subtle = fg({'NonText', 'Comment'}, guicolors and '#555555' or 240)

  local bg_current  = bg({'Normal'}, 'none')
  local bg_visible  = bg({'TabLineSel', 'Normal'}, 'none')
  local bg_inactive = bg({'TabLineFill', 'StatusLine'}, 'none')

  --      Current: current buffer
  --      Visible: visible but not current buffer
  --     Inactive: invisible but not current buffer
  --        -Icon: filetype icon
  --       -Index: buffer index
  --         -Mod: when modified
  --        -Sign: the separator between buffers
  --      -Target: letter in buffer-picking mode
  local hl = vim.api.nvim_set_hl
  hl(0, 'BufferCurrent',        {bg = bg_current, fg = fg_current, default = true})
  hl(0, 'BufferCurrentIndex',   {bg = bg_current, fg = fg_special, default = true})
  hl(0, 'BufferCurrentMod',     {bg = bg_current, fg = fg_modified, default = true})
  hl(0, 'BufferCurrentSign',    {bg = bg_current, fg = fg_special, default = true})
  hl(0, 'BufferCurrentTarget',  {bg = bg_current, fg = fg_target, bold = true, default = true})
  hl(0, 'BufferInactive',       {bg = bg_inactive, fg = fg_inactive, default = true})
  hl(0, 'BufferInactiveIndex',  {bg = bg_inactive, fg = fg_subtle, default = true})
  hl(0, 'BufferInactiveMod',    {bg = bg_inactive, fg = fg_modified, default = true})
  hl(0, 'BufferInactiveSign',   {bg = bg_inactive, fg = fg_subtle, default = true})
  hl(0, 'BufferInactiveTarget', {bg = bg_inactive, fg = fg_target, bold = true, default = true})
  hl(0, 'BufferTabpageFill',    {bg = bg_inactive, fg = fg_inactive, default = true})
  hl(0, 'BufferTabpages',       {bg = bg_inactive, fg = fg_special, bold = true, default = true})
  hl(0, 'BufferVisible',        {bg = bg_visible, fg = fg_visible, default = true})
  hl(0, 'BufferVisibleIndex',   {bg = bg_visible, fg = fg_visible, default = true})
  hl(0, 'BufferVisibleMod',     {bg = bg_visible, fg = fg_modified, default = true})
  hl(0, 'BufferVisibleSign',    {bg = bg_visible, fg = fg_visible, default = true})
  hl(0, 'BufferVisibleTarget',  {bg = bg_visible, fg = fg_target, bold = true, default = true})

  hl(0, 'BufferCurrentIcon', {default = true, link = 'BufferCurrent'})
  hl(0, 'BufferInactiveIcon', {default = true, link = 'BufferInactive'})
  hl(0, 'BufferVisibleIcon', {default = true, link = 'BufferVisible'})
  hl(0, 'BufferOffset', {default = true, link = 'BufferTabpageFill'})

  require'bufferline.icons'.set_highlights()
end

return highlight
