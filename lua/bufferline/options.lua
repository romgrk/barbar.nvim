local table_concat = table.concat

local deepcopy = vim.deepcopy
local tbl_deep_extend = vim.tbl_deep_extend

local utils = require'bufferline.utils'

--- The prefix used for `utils.deprecate`
local DEPRECATE_PREFIX = '\nThe barbar.nvim option '

--- A cached value of `g:bufferline`
local g_bufferline = {}

--- Retrieve some value under `key` from `g:bufferline`, or return a `default` if none was present.
--- @generic T
--- @param default? T
--- @param key string
--- @return T value
local function get(key, default)
  local value = g_bufferline[key]
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

--- @return boolean enabled
function options.animation()
  return get('animation', true)
end

--- @return boolean enabled
function options.auto_hide()
  return get('auto_hide', false)
end

--- @return boolean enabled
function options.clickable()
  return get('clickable', true)
end

--- @return string[] excluded
function options.exclude_ft()
  return get('exclude_ft', {})
end

--- @return string[] excluded
function options.exclude_name()
  return get('exclude_name', {})
end

--- @return 'left'|'right' enabled
function options.focus_on_close()
  return get('focus_on_close', 'left')
end

--- @return bufferline.options.hide
function options.hide()
  return deepcopy(get('hide', {}))
end

--- @return boolean
function options.highlight_alternate()
  return get('highlight_alternate', false)
end

--- @return boolean
function options.highlight_inactive_file_icons()
  return get('highlight_inactive_file_icons', false)
end

--- @return boolean
function options.highlight_visible()
  return get('highlight_visible', true)
end

--- @return bufferline.options.icons
function options.icons()
  --- @type bufferline.options.icons|bufferline.options.icons.preset
  local icons = get('icons', {})

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
    local user_setting = get(deprecated_option)
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
    local closable = get'closable'
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

    g_bufferline = tbl_deep_extend('force', g_bufferline, corrected_options)
    vim.schedule(function() vim.g.bufferline = g_bufferline end)
  end

  icons = tbl_deep_extend('keep', deepcopy(icons), {
    buffer_index = false,
    buffer_number = false,
    button = '',
    filetype = {enabled = true},
    inactive = {separator = {left = '▎', right = ''}},
    modified = {button = '●'},
    pinned = {button = ''},
    separator = {left = '▎', right = ''},
  })

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

--- @return boolean enabled
function options.insert_at_start()
  return get('insert_at_start', false)
end

--- @return boolean enabled
function options.insert_at_end()
  return get('insert_at_end', false)
end

--- @return string letters
function options.letters()
  return get('letters', 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP')
end

--- @return integer padding
function options.maximum_padding()
  return get('maximum_padding', 4)
end

--- @return integer padding
function options.minimum_padding()
  return get('minimum_padding', 1)
end

--- @return integer length
function options.maximum_length()
  return get('maximum_length', 30)
end

--- @return nil|string title
function options.no_name_title()
  return get('no_name_title')
end

--- @return boolean enabled
function options.semantic_letters()
  return get('semantic_letters', true)
end

--- @param user_config? table
function options.setup(user_config)
  if user_config == nil or user_config == vim.NIL then
    user_config = {}
  end

  g_bufferline = user_config
end

--- @return boolean enabled
function options.tabpages()
  return get('tabpages', true)
end

return options
