local get_hl = vim.api.nvim_get_hl --- @type function
local get_hl_by_name = vim.api.nvim_get_hl_by_name --- @type function
local hlexists = vim.fn.hlexists --- @type function
local set_hl = vim.api.nvim_set_hl --- @type function
local tbl_isempty = vim.tbl_isempty

local tbl = require('barbar.utils.table')

--- @type {[string]: nil|table}
local hl_groups_cache = {}

local get_hl_util = get_hl and
  --- @param name string
  --- @return table
  function(name) return get_hl(0, {link = false, name = name}) end or
  function(name)
    if hlexists(name) < 1 then
      return {}
    end

    local definition = get_hl_by_name(name, true)
    for original, new in pairs {background = 'bg', foreground = 'fg', special = 'sp'} do
      local attribute_definition = tbl.remove_key(definition, original)
      if attribute_definition then
        definition[new] = attribute_definition
      end
    end

    local cterm = get_hl_by_name(name, false)
    definition.ctermfg = cterm.foreground
    definition.ctermbg = cterm.background

    return definition
  end

--- @param group string the groups to source the color from.
--- @return table
local function get_hl_cached(group)
  do
    local hl_cached = hl_groups_cache[group]
    if hl_cached then
      return hl_cached
    end
  end

  local hl = get_hl_util(group)
  hl_groups_cache[group] = hl
  return hl
end

--- Generate a color.
--- @param groups string[] the groups to source the color from.
--- @param attribute 'bg'|'ctermbg'|'ctermfg'|'fg'|'sp' where to look for the color.
--- @param default barbar.utils.hl.color.value a color name (`string`), GUI hex (`string`), or cterm color code (`integer`).
--- @return barbar.utils.hl.color.value color
local function get_hl_color_or_default(groups, attribute, default)
  for _, group in ipairs(groups) do
    local hl_attribute = get_hl_cached(group)[attribute]
    if hl_attribute then
      return hl_attribute
    end
  end

  return default
end

--- @class barbar.utils.hl.attributes see |:h attr-list|
--- @field blend? integer 0–100
--- @field bold? boolean
--- @field default? boolean
--- @field italic? boolean
--- @field nocombine? boolean
--- @field reverse? boolean
--- @field standout? boolean
--- @field strikethrough? boolean
--- @field undercurl? boolean
--- @field underdashed? boolean
--- @field underdotted? boolean
--- @field underdouble? boolean
--- @field underline? boolean

--- @alias barbar.utils.hl.color.value integer|string

--- @class barbar.utils.hl.color
--- @field cterm barbar.utils.hl.color.value
--- @field gui barbar.utils.hl.color.value

--- @class barbar.utils.hl.definition: barbar.utils.hl.attributes
--- @field bg? barbar.utils.hl.color.value
--- @field cterm? barbar.utils.hl.attributes
--- @field ctermbg? barbar.utils.hl.color.value
--- @field ctermfg? barbar.utils.hl.color.value
--- @field fg? barbar.utils.hl.color.value
--- @field sp? barbar.utils.hl.color.value

--- utilities for working with highlight groups.
--- @class barbar.utils.Hl
local hl = {}

--- Generate a background color.
--- @param groups string[] the groups to source the background color from.
--- @param default barbar.utils.hl.color.value the background color to use if no `groups` have a valid background color.
--- @param default_cterm? barbar.utils.hl.color.value the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return barbar.utils.hl.color color
function hl.bg_or_default(groups, default, default_cterm)
  return {
    cterm = get_hl_color_or_default(groups, 'ctermbg', default_cterm or default),
    gui = get_hl_color_or_default(groups, 'bg', default),
  }
end

--- Generate a color.
--- @param groups string[] the groups to source the color from.
--- @return nil|barbar.utils.hl.definition
function hl.definition(groups)
  for _, group in ipairs(groups) do
    local cached = get_hl_cached(group)
    if not tbl_isempty(cached) then
      return vim.deepcopy(cached)
    end
  end
end

--- Generate a foreground color.
--- @param groups string[] the groups to source the foreground color from.
--- @param default barbar.utils.hl.color.value the foreground color to use if no `groups` have a valid foreground color.
--- @param default_cterm? barbar.utils.hl.color.value the color to use if no `groups` have a valid color and `termguicolors == false`.
--- @return barbar.utils.hl.color color
function hl.fg_or_default(groups, default, default_cterm)
  return {
    cterm = get_hl_color_or_default(groups, 'ctermfg', default_cterm or default),
    gui = get_hl_color_or_default(groups, 'fg', default),
  }
end

--- Reset the `nvim_get_hl` cache
function hl.reset_cache() hl_groups_cache = {} end

--- Remove all attributes related to underlining from the definition provided
--- WARN: mutates `definition`!
--- @param definition barbar.utils.hl.definition the definition to remove underline from
--- @return nil
function hl.remove_underline_attributes(definition)
  definition.undercurl = nil
  definition.underdashed = nil
  definition.underdotted = nil
  definition.underdouble = nil
  definition.underline = nil

  if definition.cterm then
    definition.cterm.undercurl = nil
    definition.cterm.underdashed = nil
    definition.cterm.underdotted = nil
    definition.cterm.underdouble = nil
    definition.cterm.underline = nil
  end
end

--- Set some highlight `group`'s default definition with respect to `&termguicolors`
--- WARN: this mutates `definition`!
--- @param group string the name of the highlight group to set
--- @param bg barbar.utils.hl.color
--- @param fg barbar.utils.hl.color
--- @param sp? barbar.utils.hl.color.value
--- @param definition? barbar.utils.hl.definition whether the highlight group should be bolded
--- @return nil
function hl.set(group, bg, fg, sp, definition)
  if not definition then
    definition = {}
  end

  definition.bg = bg.gui
  definition.ctermbg = bg.cterm
  definition.ctermfg = fg.cterm
  definition.fg = fg.gui
  definition.reverse = nil
  definition.sp = sp
  definition[vim.type_idx] = nil

  set_hl(0, group, definition)
end

--- Set the default highlight `group_name` as a link to `link_name`
--- @param group_name string the name of the group to by-default be linked to `link_name`
--- @param link_name string the name of the group to by-default link `group_name` to
--- @return nil
function hl.set_default_link(group_name, link_name)
  set_hl(0, group_name, {default = true, link = link_name})
end

--- Generate a foreground color.
--- @param groups string[] the groups to source the foreground color from.
--- @param default barbar.utils.hl.color.value the foreground color to use if no `groups` have a valid foreground color.
--- @return barbar.utils.hl.color.value color
function hl.sp_or_default(groups, default)
  return get_hl_color_or_default(groups, 'sp', default)
end

return hl
