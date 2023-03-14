local table_concat = table.concat

local ERROR = vim.diagnostic.severity.ERROR --- @type integer
local HINT = vim.diagnostic.severity.HINT --- @type integer
local INFO = vim.diagnostic.severity.INFO --- @type integer
local tbl_deep_extend = vim.tbl_deep_extend
local WARN = vim.diagnostic.severity.WARN --- @type integer

local utils = require'bufferline.utils'

--- The prefix used for `utils.deprecate`
local DEPRECATE_PREFIX = '\nThe barbar.nvim option '

--- Retrieve some value under `key` from `g:bufferline`, or return a `default` if none was present.
--- @generic T
--- @param g_bufferline table
--- @param default? T
--- @param key string
--- @return T value
local function get(g_bufferline, key, default)
  local value = (g_bufferline or {})[key]
  if value == nil or value == vim.NIL then
    return default
  else
    return value
  end
end

--- @class bufferline.options.hide
--- @field alternate? boolean
--- @field current? boolean
--- @field extensions? boolean
--- @field inactive? boolean
--- @field visible? boolean

--- @class bufferline.options.icons.diagnostics.severity
--- @field enabled boolean
--- @field icon string

--- @class bufferline.options.icons.diagnostics
--- @field [1] bufferline.options.icons.diagnostics.severity
--- @field [2] bufferline.options.icons.diagnostics.severity
--- @field [3] bufferline.options.icons.diagnostics.severity
--- @field [4] bufferline.options.icons.diagnostics.severity
local DEFAULT_DIAGNOSTIC_ICONS = {
  [vim.diagnostic.severity.ERROR] = {enabled = false, icon = 'Ⓧ '},
  [vim.diagnostic.severity.HINT] = {enabled = false, icon = '💡'},
  [vim.diagnostic.severity.INFO] = {enabled = false, icon = 'ⓘ '},
  [vim.diagnostic.severity.WARN] = {enabled = false, icon = '⚠️ '},
}

--- @class bufferline.options.icons.filetype
--- @field custom_color? boolean if present, this color will be used for ALL filetype icons
--- @field enabled? boolean iff `true`, show the `devicons` for the associated buffer's `filetype`.

--- @class bufferline.options.icons.separator
--- @field left? string a buffer's left separator
--- @field right? string a buffer's right separator

--- @class bufferline.options.icons.buffer
--- @field buffer_index? boolean iff `true`, show the index of the associated buffer with respect to the ordering of the buffers in the tabline.
--- @field buffer_number? boolean iff `true`, show the `bufnr` for the associated buffer.
--- @field button? false|string the button which is clicked to close / save a buffer, or indicate that it is pinned.
--- @field diagnostics? bufferline.options.icons.diagnostics the diagnostic icons
--- @field filetype? bufferline.options.icons.filetype filetype icon options
--- @field separator? bufferline.options.icons.separator the left-hand separator between buffers in the tabline

--- @class bufferline.options.icons.state: bufferline.options.icons.buffer
--- @field modified? bufferline.options.icons.buffer the icons used for an modified buffer
--- @field pinned? bufferline.options.icons.buffer the icons used for a pinned buffer

--- @class bufferline.options.icons: bufferline.options.icons.state
--- @field alternate? bufferline.options.icons.state the icons used for an alternate buffer
--- @field current? bufferline.options.icons.state the icons for the current buffer
--- @field inactive? bufferline.options.icons.state the icons for inactive buffers
--- @field visible? bufferline.options.icons.state the icons for visible buffers

--- @alias bufferline.options.icons.preset boolean|"both"|"buffer_number_with_icon"|"buffer_numbers"|"numbers"

--- @type {[bufferline.options.icons.preset]: bufferline.options.icons}
local PRESETS = {
  [false] = {
    buffer_number = false,
    buffer_index = false,
    filetype = {enabled = false},
  },
  [true] = {
    buffer_number = false,
    buffer_index = false,
    filetype = {enabled = true},
  },
  both = {
    buffer_index = true,
    buffer_number = false,
    filetype = {enabled = true},
  },
  buffer_number_with_icon = {
    buffer_index = false,
    buffer_number = true,
    filetype = {enabled = true},
  },
  buffer_numbers = {
    buffer_index = false,
    buffer_number = true,
    filetype = {enabled = false},
  },
  numbers = {
    buffer_index = true,
    buffer_number = false,
    filetype = {enabled = false},
  },
}

--- @type bufferline.options.icons
local DEFAULT_ICONS = vim.tbl_extend('keep', PRESETS[true], {
  button = '',
  inactive = {separator = {left = '▎', right = ''}},
  modified = {button = '●'},
  pinned = {button = ''},
  separator = {left = '▎', right = ''},
})

--- A table of options that used to exist, and where they are located now.
--- @type {[string]: string[]}
local DEPRECATED_ICON_OPTIONS = {
  diagnostics = {'diagnostics'},
  icon_close_tab = {'button'},
  icon_close_tab_modified = {'modified', 'button'},
  icon_custom_colors = {'filetype', 'custom_color'},
  icon_pinned = {'pinned', 'button'},
  icon_separator_active = {'separator', 'left'},
  icon_separator_inactive = {'inactive', 'separator', 'left'},
}

--- @class bufferline.options
local options = {}

--- @param g_bufferline table
--- @return boolean enabled
function options.animation(g_bufferline)
  return get(g_bufferline, 'animation', true)
end

--- @param g_bufferline table
--- @return boolean enabled
function options.auto_hide(g_bufferline)
  return get(g_bufferline, 'auto_hide', false)
end

--- @param g_bufferline table
--- @return boolean enabled
function options.clickable(g_bufferline)
  return get(g_bufferline, 'clickable', true)
end

--- @param g_bufferline table
--- @return bufferline.options.diagnostics
function options.diagnostics(g_bufferline)
  return tbl_deep_extend('keep', get(g_bufferline, 'diagnostics', {}), DEFAULT_DIAGNOSTICS)
end

--- @param g_bufferline table
--- @return string[] excluded
function options.exclude_ft(g_bufferline)
  return get(g_bufferline, 'exclude_ft', {})
end

--- @param g_bufferline table
--- @return string[] excluded
function options.exclude_name(g_bufferline)
  return get(g_bufferline, 'exclude_name', {})
end

--- @return 'left'|'right' enabled
function options.focus_on_close()
  return get('focus_on_close', 'left')
end

--- @param g_bufferline table
--- @return bufferline.options.hide
function options.hide(g_bufferline)
  return get(g_bufferline, 'hide', {})
end

--- @param g_bufferline table
--- @return boolean
function options.highlight_alternate(g_bufferline)
  return get(g_bufferline, 'highlight_alternate', false)
end

--- @param g_bufferline table
--- @return boolean
function options.highlight_inactive_file_icons(g_bufferline)
  return get(g_bufferline, 'highlight_inactive_file_icons', false)
end

--- @param g_bufferline table
--- @return boolean
function options.highlight_visible(g_bufferline)
  return get(g_bufferline, 'highlight_visible', true)
end

--- @param g_bufferline table
--- @return bufferline.options.icons
function options.icons(g_bufferline)
  --- @type bufferline.options.icons|bufferline.options.icons.preset
  local icons = get(g_bufferline, 'icons', {})

  local do_global_option_sync = false
  if type(icons) ~= 'table' then
    local preset = PRESETS[icons]
    utils.deprecate(
      DEPRECATE_PREFIX .. utils.markdown_inline_code('icons = ' .. vim.inspect(icons)),
      utils.markdown_inline_code('icons = ' .. vim.inspect(
        vim.tbl_map(function(v) return v or nil end, preset),
        {newline = ' ', indent = ''}
      ))
    )

    do_global_option_sync = true
    icons = preset
  end

  local corrected_options = {}
  for deprecated_option, new_option in pairs(DEPRECATED_ICON_OPTIONS) do
    local user_setting = get(g_bufferline, deprecated_option)
    if user_setting then
      utils.tbl_set(icons, new_option, user_setting)
      utils.deprecate(
        DEPRECATE_PREFIX .. utils.markdown_inline_code(deprecated_option),
        utils.markdown_inline_code('icons.' .. table_concat(new_option, '.'))
      )

      do_global_option_sync = true
      corrected_options[deprecated_option] = vim.NIL
    end
  end

  do
    --- Edge case deprecated option
    --- @type boolean|nil
    local closable = get(g_bufferline, 'closable')
    if closable == false then
      icons.button = false
      utils.tbl_set(icons, {'modified', 'button'}, false)
      utils.deprecate(
        DEPRECATE_PREFIX .. utils.markdown_inline_code'closable',
        utils.markdown_inline_code'icons.button' ..
          ' and ' .. utils.markdown_inline_code'icons.modified.button'
      )

      do_global_option_sync = true
      corrected_options.closable = vim.NIL
    end
  end

  if do_global_option_sync then
    corrected_options.icons = icons
    vim.g.bufferline = tbl_deep_extend('force', g_bufferline, corrected_options)
  end

  icons = tbl_deep_extend('keep', deepcopy(icons), DEFAULT_ICONS)

  if icons.diagnostics == nil then
    icons.diagnostics = {}
  end

  -- NOTE: we do this because `vim.tbl_deep_extend` doesn't deep copy lists
  for i, default_diagnostic_severity_icons in ipairs(DEFAULT_DIAGNOSTIC_ICONS) do
    local diagnostic_severity_icons = icons.diagnostics[i] or {}

    if diagnostic_severity_icons.enabled == nil then
      diagnostic_severity_icons.enabled = default_diagnostic_severity_icons.enabled
    end

    if diagnostic_severity_icons.icon == nil then
      diagnostic_severity_icons.icon = default_diagnostic_severity_icons.icon
    end
  end

  return icons
end

--- @param g_bufferline table
--- @return boolean enabled
function options.insert_at_start(g_bufferline)
  return get(g_bufferline, 'insert_at_start', false)
end

--- @param g_bufferline table
--- @return boolean enabled
function options.insert_at_end(g_bufferline)
  return get(g_bufferline, 'insert_at_end', false)
end

--- @param g_bufferline table
--- @return string letters
function options.letters(g_bufferline)
  return get(g_bufferline, 'letters', 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP')
end

--- @param g_bufferline table
--- @return integer padding
function options.maximum_padding(g_bufferline)
  return get(g_bufferline, 'maximum_padding', 4)
end

--- @param g_bufferline table
--- @return integer padding
function options.minimum_padding(g_bufferline)
  return get(g_bufferline, 'minimum_padding', 1)
end

--- @param g_bufferline table
--- @return integer length
function options.maximum_length(g_bufferline)
  return get(g_bufferline, 'maximum_length', 30)
end

--- @param g_bufferline table
--- @return nil|string title
function options.no_name_title(g_bufferline)
  return get(g_bufferline, 'no_name_title')
end

--- @param g_bufferline table
--- @return boolean enabled
function options.semantic_letters(g_bufferline)
  return get(g_bufferline, 'semantic_letters', true)
end

--- @param g_bufferline table
--- @return boolean enabled
function options.tabpages(g_bufferline)
  return get(g_bufferline, 'tabpages', true)
end

return options
