--
-- utils.lua
--

local fnamemodify = vim.fn.fnamemodify
local get_hl_by_name = vim.api.nvim_get_hl_by_name
local set_hl = vim.api.nvim_set_hl

local function index_of(tbl, n)
  for i, value in ipairs(tbl) do
    if value == n then
      return i
    end
  end
  return nil
end

--- Generate a color.
--- @param index string where to look for the color.
--- @param groups table<string> the groups to source the color from.
--- @param default string the color to use if no `groups` have a valid color.
--- @param default_cterm number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return number|string color
local function attribute_or_default(index, groups, default, default_cterm)
  local guicolors = vim.go.termguicolors
  for _, group in ipairs(groups) do
    local hl = get_hl_by_name(group, guicolors)
    if hl[index] then
      return guicolors and string.format('#%06x', hl[index]) or hl[index]
    end
  end
  return guicolors and default or default_cterm
end

return {
  basename = function (path)
     return fnamemodify(path, ':t')
  end,

  has = function (tbl, n)
    return index_of(tbl, n) ~= nil
  end,

  --- utilities for working with highlight groups.
  hl = {
    --- Generate a background color.
    --- @param groups table<string> the groups to source the background color from.
    --- @param default string the background color to use if no `groups` have a valid background color.
    --- @param default_cterm nil|number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
    --- @return number|string color
    bg_or_default = function(groups, default, default_cterm)
      return attribute_or_default('background', groups, default, default_cterm or default)
    end,

    --- Generate a foreground color.
    --- @param groups table<string> the groups to source the foreground color from.
    --- @param default string the foreground color to use if no `groups` have a valid foreground color.
    --- @param default_cterm nil|number|string the color to use if no `groups` have a valid color and `termguicolors == false`.
    --- @return number|string color
    fg_or_default = function(groups, default, default_cterm)
      return attribute_or_default('foreground', groups, default, default_cterm or default)
    end,

    --- @return function setter can set the default for a highlight group, depending on `vim.go.termguicolors`.
    get_default_setter = function()
      --- Set some highlight `group`'s default definition with respect to `&termguicolors`
      --- @param group string the name of the highlight group to set
      --- @param background number|string the background color
      --- @param foreground number|string the foreground color
      --- @param bold boolean|nil whether the highlight group should be bolded
      return vim.go.termguicolors and
        function(group, background, foreground, bold)
          set_hl(0, group, {bg = background, bold = bold, default = true, fg = foreground})
        end or
        function(group, background, foreground, bold)
          set_hl(0, group, {bold = bold, ctermbg = background, ctermfg = foreground, default = true})
        end
    end,

    --- Set the default highlight `group_name` as a link to `link_name`
    --- @param group_name string the name of the group to by-default be linked to `link_name`
    --- @param link_name string the name of the group to by-default link `group_name` to
    set_default_link = function (group_name, link_name)
      set_hl(0, group_name, {default = true, link = link_name})
    end,
  },

  index_of = index_of,

  is_nil = function (value)
    return value == nil or value == vim.NIL
  end,

  reverse = function (tbl)
    local reversed = {}
    while #reversed < #tbl do
      reversed[#reversed + 1] = tbl[#tbl - #reversed]
    end
    return reversed
  end,
}
