local table_concat = table.concat

local tbl_deep_extend = vim.tbl_deep_extend

local utils = require'barbar.utils'

--- The prefix used for `utils.deprecate`
local DEPRECATE_PREFIX = '\nThe barbar.nvim option '

--- @param key string
--- @param expected_type type
--- @param default any
local function set_default(options, key, expected_type, default)
  if type(options[key]) ~= expected_type then
    options[key] = default
  end
end

--- @class barbar.config.options.hide
--- @field alternate? boolean
--- @field current? boolean
--- @field extensions? boolean
--- @field inactive? boolean
--- @field visible? boolean

--- @class barbar.config.options.icons.diagnostics.severity
--- @field enabled boolean
--- @field icon string

--- @class barbar.config.options.icons.buffer.diagnostics
--- @field [1] barbar.config.options.icons.diagnostics.severity
--- @field [2] barbar.config.options.icons.diagnostics.severity
--- @field [3] barbar.config.options.icons.diagnostics.severity
--- @field [4] barbar.config.options.icons.diagnostics.severity
local DEFAULT_DIAGNOSTIC_ICONS = {
  [vim.diagnostic.severity.ERROR] = {enabled = false, icon = 'Ⓧ '},
  [vim.diagnostic.severity.HINT] = {enabled = false, icon = '💡'},
  [vim.diagnostic.severity.INFO] = {enabled = false, icon = 'ⓘ '},
  [vim.diagnostic.severity.WARN] = {enabled = false, icon = '⚠️ '},
}

--- @class barbar.config.options.icons.buffer.filetype
--- @field custom_colors? boolean if present, this color will be used for ALL filetype icons
--- @field enabled? boolean iff `true`, show the `devicons` for the associated buffer's `filetype`.

--- @class barbar.config.options.icons.buffer.separator
--- @field left? string a buffer's left separator
--- @field right? string a buffer's right separator

--- @class barbar.config.options.icons.buffer
--- @field buffer_index? boolean iff `true`, show the index of the associated buffer with respect to the ordering of the buffers in the tabline.
--- @field buffer_number? boolean iff `true`, show the `bufnr` for the associated buffer.
--- @field filename? boolean iff `true`, show the filename
--- @field button? false|string the button which is clicked to close / save a buffer, or indicate that it is pinned.
--- @field diagnostics? barbar.config.options.icons.buffer.diagnostics the diagnostic icons
--- @field filetype? barbar.config.options.icons.buffer.filetype filetype icon options
--- @field separator? barbar.config.options.icons.buffer.separator the left-hand separator between buffers in the tabline

--- @class barbar.config.options.icons.state: barbar.config.options.icons.buffer
--- @field modified? barbar.config.options.icons.buffer the icons used for an modified buffer
--- @field pinned? barbar.config.options.icons.buffer the icons used for a pinned buffer

--- @class barbar.config.options.icons: barbar.config.options.icons.state
--- @field alternate? barbar.config.options.icons.state the icons used for an alternate buffer
--- @field current? barbar.config.options.icons.state the icons for the current buffer
--- @field inactive? barbar.config.options.icons.state the icons for inactive buffers
--- @field visible? barbar.config.options.icons.state the icons for visible buffers

--- @alias barbar.config.options.icons.preset boolean|"both"|"buffer_number_with_icon"|"buffer_numbers"|"numbers"

--- @type {[barbar.config.options.icons.preset]: barbar.config.options.icons}
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
local DEPRECATED_OPTIONS = {
  diagnostics = {'icons', 'diagnostics'},
  icon_close_tab = {'icons', 'button'},
  icon_close_tab_modified = {'icons', 'modified', 'button'},
  icon_custom_colors = {'icons', 'filetype', 'custom_colors'},
  icon_pinned = {'icons', 'pinned', 'button'},
  icon_separator_active = {'icons', 'separator', 'left'},
  icon_separator_inactive = {'icons', 'inactive', 'separator', 'left'},
}

--- @class barbar.config.options.sidebar_filetype
--- @field event? string
--- @field text? string

--- @class barbar.config.options
--- @field animation boolean
--- @field auto_hide boolean
--- @field clickable boolean
--- @field exclude_ft string[]
--- @field exclude_name string[]
--- @field focus_on_close 'left'|'right'
--- @field hide barbar.config.options.hide
--- @field highlight_alternate boolean
--- @field highlight_inactive_file_icons boolean
--- @field highlight_visible boolean
--- @field icons barbar.config.options.icons
--- @field insert_at_end boolean
--- @field insert_at_start boolean
--- @field letters string
--- @field maximum_length integer
--- @field maximum_padding integer
--- @field minimum_padding integer
--- @field no_name_title string
--- @field semantic_letters boolean
--- @field sidebar_filetypes {[string]: nil|barbar.config.options.sidebar_filetype}
--- @field tabpages boolean

--- @class barbar.config
--- @field options barbar.config.options
local config = { options = {} }

--- @param options? table
function config.setup(options)
  vim.g.barbar_auto_setup = false

  if type(options) ~= 'table' then
    options = {}
  end

  do -- TODO: remove after v2
    local icons_type = type(options.icons)
    if icons_type == 'string' or icons_type == 'boolean' then
      local preset = PRESETS[options.icons]
      utils.deprecate(
        DEPRECATE_PREFIX .. utils.markdown_inline_code('icons = ' .. vim.inspect(options.icons)),
        utils.markdown_inline_code('icons = ' .. vim.inspect(
          vim.tbl_map(function(v) return v or nil end, preset),
          {newline = ' ', indent = ''}
        ))
      )

      options.icons = preset
    end
  end

  -- TODO: remove after v2
  for deprecated_option, new_option in pairs(DEPRECATED_OPTIONS) do
    local user_setting = options[deprecated_option]
    if user_setting then
      utils.tbl_set(options, new_option, user_setting)
      utils.deprecate(
        DEPRECATE_PREFIX .. utils.markdown_inline_code(deprecated_option),
        utils.markdown_inline_code(table_concat(new_option, '.'))
      )

      options[deprecated_option] = nil
    end
  end

  -- TODO: remove after v2
  -- Edge case deprecated option
  if options.closable == false then
    utils.tbl_set(options, {'icons', 'button'}, false)
    utils.tbl_set(options, {'icons', 'modified', 'button'}, false)
    utils.deprecate(
      DEPRECATE_PREFIX .. utils.markdown_inline_code'closable',
      utils.markdown_inline_code'icons.button' ..
        ' and ' .. utils.markdown_inline_code'icons.modified.button'
    )

    options.closable = nil
  end

  set_default(options, 'animation', 'boolean', true)
  set_default(options, 'auto_hide', 'boolean', false)
  set_default(options, 'clickable', 'boolean', true)
  set_default(options, 'exclude_ft', 'table', {})
  set_default(options, 'exclude_name', 'table', {})
  set_default(options, 'focus_on_close', 'string', 'left')
  set_default(options, 'hide', 'table', {})
  set_default(options, 'highlight_alternate', 'boolean', false)
  set_default(options, 'highlight_inactive_file_icons', 'boolean', false)
  set_default(options, 'highlight_visible', 'boolean', true)
  set_default(options, 'insert_at_end', 'boolean', false)
  set_default(options, 'insert_at_start', 'boolean', false)
  set_default(options, 'letters', 'string', 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP')
  set_default(options, 'maximum_length', 'number', 30)
  set_default(options, 'maximum_padding', 'number', 4)
  set_default(options, 'minimum_padding', 'number', 1)
  set_default(options, 'no_name_title', 'string', nil)
  set_default(options, 'semantic_letters', 'boolean', true)
  set_default(options, 'tabpages', 'boolean', true)

  do -- normalize `sidebar_filetypes` format
    local sidebar_filetypes = options.sidebar_filetypes
    if type(sidebar_filetypes) == 'table' then
      for k, v in pairs(sidebar_filetypes) do
        if v == true then
          sidebar_filetypes[k] = {}
        end
      end
    else
      options.sidebar_filetypes = {}
    end
  end

  do -- resolve the icons
    local icons = options.icons or {}

    do
      local default_icons = {
        buffer_index = false,
        buffer_number = false,
        button = '',
        diagnostics = {},
        filename = true,
        filetype = {enabled = true},
        inactive = {separator = {left = '▎', right = ''}},
        modified = {button = '●'},
        pinned = {button = false, filename = false},
        separator = {left = '▎', right = ''},
      }

      do -- improves the look of minimized pinned tabs
        local pinned_icons = icons.pinned
        if pinned_icons == nil or (
          (pinned_icons.button == false or #pinned_icons.button < 1) and
          pinned_icons.filename == false
        ) then
          default_icons.pinned.separator = {right = ' '}
        end
      end

      icons = tbl_deep_extend('keep', icons, default_icons)
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

    do
      --- `options.icons` without the recursive structure
      --- @type barbar.config.options.icons.buffer
      local base_icons = {
        buffer_index = icons.buffer_index,
        buffer_number = icons.buffer_number,
        filename = icons.filename,
        button = icons.button,
        diagnostics = icons.diagnostics,
        filetype = icons.filetype,
        separator = icons.separator,
      }

      local modified_icons = icons.modified or {}
      local pinned_icons = icons.pinned or {}

      -- resolve all of the icons for the activities
      for _, activity in ipairs {'alternate', 'current', 'inactive', 'visible'} do
        local activity_icons = tbl_deep_extend('keep', icons[activity] or {}, base_icons)

        icons[activity] = activity_icons
        icons[activity].pinned = tbl_deep_extend('keep', icons[activity].pinned or {}, pinned_icons, activity_icons)
        icons[activity].modified = tbl_deep_extend(
          'keep',
          icons[activity].modified or {},
          modified_icons,
          activity_icons
        )
      end
    end

    options.icons = icons
  end

  config.options = options
end

return config
