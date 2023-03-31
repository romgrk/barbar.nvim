--
-- utils.lua
--

local table_insert = table.insert

local fnamemodify = vim.fn.fnamemodify --- @type function
local get_hl = vim.api.nvim_get_hl --- @type function
local get_hl_by_name = vim.api.nvim_get_hl_by_name --- @type function
local hlexists = vim.fn.hlexists --- @type function
local list_slice = vim.list_slice
local notify = vim.notify
local notify_once = vim.notify_once
local set_hl = vim.api.nvim_set_hl --- @type function

--- @type {[string]: table}
local hl_groups_cache = {}

--- Remove `tbl[key]` from `tbl` and return it
--- @param tbl table
--- @param key string
--- @return any
local function tbl_remove_key (tbl, key)
  local value = rawget(tbl, key)
  rawset(tbl, key, nil)
  return value
end

local get_hl_util = get_hl and
  --- @param name string
  --- @return table
  function(name) return get_hl(0, {link = false, name = name}) end or
  --- @param name string
  --- @return table
  function(name)
    if hlexists(name) < 1 then
      return {}
    end

    local definition = get_hl_by_name(name, true)
    for original, new in pairs {background = 'bg', foreground = 'fg', special = 'sp'} do
      local attribute_definition = tbl_remove_key(definition, original)
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
  local hl_cached = hl_groups_cache[group]
  if hl_cached then
    return hl_cached
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

--- Return the index of element `n` in `list.
--- @generic T
--- @param list T[]
--- @param t T
--- @return nil|integer index
local function index_of(list, t)
  for i, value in ipairs(list) do
    if value == t then
      return i
    end
  end
  return nil
end

--- Use `vim.notify` with a `msg` and log `level`. Integrates with `nvim-notify`.
--- @param msg string
--- @param level 0|1|2|3|4|5
--- @return nil
local function notify_once_util(msg, level)
  notify_once(msg, level, {title = 'barbar.nvim'})
end

--- @param path string
--- @return string relative_path
local function relative(path)
  return fnamemodify(path, ':~:.')
end

--- @class barbar.utils
local utils = {
  --- @param path string
  --- @param hide_extension? boolean if `true`, exclude the extension of the file in the basename
  --- @return string basename
  basename = function(path, hide_extension)
    local modifier = ':t'

    if hide_extension then
      modifier = modifier .. ':r'
    end

    return fnamemodify(path, modifier)
  end,

  deprecate = vim.deprecate and
    --- Notify a user that something has been deprecated, and that there is an alternative.
    --- @param name string
    --- @param alternative string
    --- @return nil
    function(name, alternative)
      vim.deprecate(name, alternative, '2.0.0', 'barbar.nvim')
    end or
    function(name, alternative)
      notify_once_util(name .. ' is deprecated. Use ' .. alternative .. 'instead.', vim.log.levels.WARN)
    end,

  --- utilities for working with highlight groups.
  --- @class barbar.utils.hl
  hl = {
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

    --- Generate a color.
    --- @param groups string[] the groups to source the color from.
    --- @return nil|barbar.utils.hl.attributes
    attributes = function(groups)
      for _, group in ipairs(groups) do
        local hl = get_hl_cached(group)
        if vim.tbl_count(hl) > 0 then
          return hl
        end
      end
    end,

    --- Generate a background color.
    --- @param groups string[] the groups to source the background color from.
    --- @param default barbar.utils.hl.color.value the background color to use if no `groups` have a valid background color.
    --- @param default_cterm? barbar.utils.hl.color.value the color to use if no `groups` have a valid color and `termguicolors == false`.
    --- @return barbar.utils.hl.color color
    bg_or_default = function(groups, default, default_cterm)
      return {
        cterm = get_hl_color_or_default(groups, 'ctermbg', default_cterm or default),
        gui = get_hl_color_or_default(groups, 'bg', default),
      }
    end,

    --- Generate a foreground color.
    --- @param groups string[] the groups to source the foreground color from.
    --- @param default barbar.utils.hl.color.value the foreground color to use if no `groups` have a valid foreground color.
    --- @param default_cterm? barbar.utils.hl.color.value the color to use if no `groups` have a valid color and `termguicolors == false`.
    --- @return barbar.utils.hl.color color
    fg_or_default = function(groups, default, default_cterm)
      return {
        cterm = get_hl_color_or_default(groups, 'ctermfg', default_cterm or default),
        gui = get_hl_color_or_default(groups, 'fg', default),
      }
    end,

    --- Reset the `nvim_get_hl` cache
    reset_cache = function() hl_groups_cache = {} end,

    --- Set some highlight `group`'s default definition with respect to `&termguicolors`
    --- @param group string the name of the highlight group to set
    --- @param bg barbar.utils.hl.color
    --- @param fg barbar.utils.hl.color
    --- @param sp? barbar.utils.hl.color.value
    --- @param attributes? barbar.utils.hl.attributes whether the highlight group should be bolded
    --- @return nil
    set = function(group, bg, fg, sp, attributes)
      if not attributes then
        attributes = {}
      end

      attributes.bg = bg.gui
      attributes.ctermbg = bg.cterm
      attributes.ctermfg = fg.cterm
      attributes.fg = fg.gui
      attributes.sp = sp
      attributes[vim.type_idx] = nil

      set_hl(0, group, attributes)
    end,

    --- Set the default highlight `group_name` as a link to `link_name`
    --- @param group_name string the name of the group to by-default be linked to `link_name`
    --- @param link_name string the name of the group to by-default link `group_name` to
    --- @return nil
    set_default_link = function(group_name, link_name)
      set_hl(0, group_name, {default = true, link = link_name})
    end,

    --- Generate a foreground color.
    --- @param groups string[] the groups to source the foreground color from.
    --- @param default string the foreground color to use if no `groups` have a valid foreground color.
    --- @return barbar.utils.hl.color.value color
    sp_or_default = function(groups, default)
      return get_hl_color_or_default(groups, 'sp', default)
    end,
  },

  index_of = index_of,

  --- @param path string
  --- @return boolean is_relative `true` if `path` is relative to the CWD
  is_relative_path = function(path)
    return relative(path) == path
  end,

  --- Reverse the order of elements in some `list`.
  --- @generic T
  --- @param list T[]
  --- @return T[] reversed
  list_reverse = function(list)
    local reversed = {}
    for i = #list, 1, -1 do
      table_insert(reversed, list[i])
    end
    return reversed
  end,

  --- Run `vim.list_slice` on some `list`, `index`ed from the end of the list.
  --- @generic T
  --- @param list T[]
  --- @param index_from_end number
  --- @return T[] sliced
  list_slice_from_end = function(list, index_from_end)
    return list_slice(list, #list - index_from_end + 1)
  end,

  --- Return "\``s`\`"
  --- @param s string
  --- @return string inline_code
  markdown_inline_code = function(s)
    return '`' .. s .. '`'
  end,

  --- Use `vim.notify` with a `msg` and log `level`. Integrates with `nvim-notify`.
  --- @param msg string
  --- @param level 0|1|2|3|4|5
  --- @return nil
  notify = function(msg, level)
    notify(msg, level, {title = 'barbar.nvim'})
  end,

  notify_once = notify_once_util,

  relative = relative,

  --- Set `fallback` as a secondary source of keys when indexing `tbl`. Example:
  ---
  --- ```lua
  --- local fallback = {bar = true}
  --- local tbl = {}
  ---
  --- print(tbl.bar) -- `nil`
  --- setfallbacktable(tbl, fallback)
  --- print(tbl.bar) -- `true`
  ---
  --- tbl.bar = false
  --- print(tbl.bar, fallback.bar) -- `false`, `true`
  --- ```
  ---
  --- WARN: this mutates `tbl`!
  --- @param tbl? table
  --- @param fallback table
  --- @return table tbl corresponding to the `tbl` parameter
  setfallbacktable = function(tbl, fallback)
    return setmetatable(tbl or {}, {__index = fallback})
  end,

  tbl_remove_key = tbl_remove_key,

  --- Set a `value` in a `tbl` multiple `keys` deep.
  --
  --- ```lua
  --- assert(vim.deep_equal(
  ---  {a = {b = {c = 'd'}}},
  ---  tbl_set({}, {'a', 'b', 'c'}, 'd')
  --- ))
  --- ```
  ---
  --- WARN: this mutates `tbl`!
  ---
  --- @generic T
  --- @param tbl table
  --- @param keys table<number|string|table>
  --- @param value T
  --- @return nil
  tbl_set = function(tbl, keys, value)
    local current = tbl
    for i = 1, #keys - 1 do
      local key = keys[i]
      current[key] = current[key] or {}
      current = current[key]
    end

    current[keys[#keys]] = value
  end,
}

return utils
