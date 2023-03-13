local ERROR = vim.diagnostic.severity.ERROR --- @type integer
local HINT = vim.diagnostic.severity.HINT --- @type integer
local INFO = vim.diagnostic.severity.INFO --- @type integer
local tbl_deep_extend = vim.tbl_deep_extend
local WARN = vim.diagnostic.severity.WARN --- @type integer

--- Retrieve some value under `key` from `g:bufferline`, or return a `default` if none was present.
--- PERF: this implementation was profiled be an improvement over `vim.g.bufferline and vim.g.bufferline[key] or default`
--- @generic T
--- @param default? T
--- @param key string
--- @return T value
local function get(key, default)
  local value = (vim.g.bufferline or {})[key]
  if value == nil or value == vim.NIL then
    return default
  else
    return value
  end
end

--- @class bufferline.options.diagnostics.severity
--- @field enabled boolean
--- @field icon string

--- @class bufferline.options.diagnostics
--- @field [1] bufferline.options.diagnostics.severity
--- @field [2] bufferline.options.diagnostics.severity
--- @field [3] bufferline.options.diagnostics.severity
--- @field [4] bufferline.options.diagnostics.severity
local DEFAULT_DIAGNOSTICS = {
  [ERROR] = {enabled = false, icon = 'Ⓧ '},
  [HINT] = {enabled = false, icon = '💡'},
  [INFO] = {enabled = false, icon = 'ⓘ '},
  [WARN] = {enabled = false, icon = '⚠️ '},
}

--- @class bufferline.options.hide
--- @field alternate? boolean
--- @field current? boolean
--- @field extensions? boolean
--- @field inactive? boolean
--- @field visible? boolean

--- @alias bufferline.options.icons boolean|"both"|"buffer_number_with_icon"|"buffer_numbers"|"numbers"

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

--- @return boolean enabled
function options.closable()
  return get('closable', true)
end

--- @return bufferline.options.diagnostics
function options.diagnostics()
  return tbl_deep_extend('keep', get('diagnostics', {}), DEFAULT_DIAGNOSTICS)
end

--- @return string[] excluded
function options.exclude_ft()
  return get('exclude_ft', {})
end

--- @return string[] excluded
function options.exclude_name()
  return get('exclude_name', {})
end

--- @param icon_option bufferline.options.icons
--- @return boolean enabled
function options.file_icons(icon_option)
  return icon_option == true or icon_option == 'both' or icon_option == 'buffer_number_with_icon'
end

--- @return 'left'|'right' enabled
function options.focus_on_close()
  return get('focus_on_close', 'left')
end

--- @return bufferline.options.hide
function options.hide()
  return get('hide', {})
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

--- @return string icon
function options.icon_close_tab()
  return get('icon_close_tab', '')
end

--- @return string icon
function options.icon_close_tab_modified()
  return get('icon_close_tab_modified', '●')
end

--- @return string icon
function options.icon_pinned()
  return get('icon_pinned', '')
end

--- @return string icon
function options.icon_separator_active()
  return get('icon_separator_active', '▎')
end

--- @return string icon
function options.icon_separator_inactive()
  return get('icon_separator_inactive', '▎')
end

--- @return string icon
function options.icon_separator_visible()
  return get('icon_separator_inactive', '▎')
end

--- @return bufferline.options.icons
function options.icons()
  return get('icons', true)
end

--- @return boolean enabled
function options.icon_custom_colors()
  return get('icon_custom_colors', false)
end

--- @param icon_option bufferline.options.icons
--- @return boolean enabled
function options.index_buffers(icon_option)
  return icon_option == 'both' or icon_option == 'numbers'
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

--- @param icon_option bufferline.options.icons
--- @return boolean enabled
function options.number_buffers(icon_option)
  return icon_option == 'buffer_numbers' or icon_option == 'buffer_number_with_icon'
end

--- @return boolean enabled
function options.semantic_letters()
  return get('semantic_letters', true)
end

--- @return boolean enabled
function options.tabpages()
  return get('tabpages', true)
end

--- `vim.validate` the `user_config` provided
--- @param user_config table
--- @return nil # errors otherwise
function options.validate(user_config)
  vim.validate {
    animation = {user_config.animation, 'boolean', true},
    auto_hide = {user_config.auto_hide, 'boolean', true},
    clickable = {user_config.clickable, 'boolean', true},
    closable = {user_config.closable, 'boolean', true},
    diagnostics = {user_config.diagnostics, 'table', true},
    exclude_ft = {user_config.exclude_ft, 'table', true},
    exclude_name = {user_config.exclude_name, 'table', true},
    focus_on_close = {
      user_config.focus_on_close,
      function(v) return v == 'left' or v == 'right' end,
      '"left" or "right"',
    },
    file_icons = {user_config.file_icons, 'boolean', true},
    hide = {user_config.hide, 'table', true},
    highlight_alternate = {user_config.highlight_alternate, 'boolean', true},
    highlight_inactive_file_icons = {user_config.highlight_inactive_file_icons, 'boolean', true},
    highlight_visible = {user_config.highlight_visible, 'boolean', true},
    icon_close_tab = {user_config.icon_close_tab, 'string', true},
    icon_close_tab_modified = {user_config.icon_close_tab_modified, 'string', true},
    icon_pinned = {user_config.icon_pinned, 'string', true},
    icon_separator_active = {user_config.icon_separator_active, 'string', true},
    icon_separator_inactive = {user_config.icon_separator_inactive, 'string', true},
    icon_separator_visible = {user_config.icon_separator_visible, 'string', true},
    icons = {
      user_config.icons,
      function(v)
        return v == true or
          v == 'both' or
          v == 'buffer_number_with_icon' or
          v == 'buffer_numbers' or
          v == 'numbers' or
          not v
      end,
      'true, false, "both", "buffer_number_with_icon", "buffer_numbers", or "numbers"',
    },
    icon_custom_colors = {user_config.icon_custom_colors, 'boolean', true},
    index_buffers = {user_config.index_buffers, 'boolean', true},
    insert_at_start = {user_config.insert_at_start, 'boolean', true},
    insert_at_end = {user_config.insert_at_end, 'boolean', true},
    letters = {user_config.letters, 'string', true},
    maximum_padding = {user_config.maximum_padding, 'number', true},
    minimum_padding = {user_config.minimum_padding, 'number', true},
    maximum_length = {user_config.maximum_length, 'number', true},
    no_name_title = {user_config.no_name_title, 'string', true},
    number_buffers = {user_config.number_buffers, 'boolean', true},
    semantic_letters = {user_config.semantic_letters, 'boolean', true},
    tabpages = {user_config.tabpages, 'boolean', true},
  }

  if user_config.diagnostics then
    for severity, config in ipairs(user_config.diagnostics) do
      local arg = 'diagnostics[' ..
        'vim.diagnostic.severity.' .. vim.diagnostic.severity[severity] ..
      ']'

      config = config or {}
      vim.validate {
        [arg] = {config, 'table'},
        [arg .. '.enabled'] = {config.enabled, 'boolean', true},
        [arg .. '.icon'] = {config.icon, 'string', true},
      }
    end
  end

  if user_config.hide then
    local arg = 'hide.'
    for _, field in ipairs {'alternate', 'current', 'extensions', 'inactive', 'visible'} do
      vim.validate {[arg .. field] = {user_config.hide[field], 'boolean', true}}
    end
  end

  for option_name, value_type in pairs {exclude_ft = 'string', exclude_name = 'string'} do
    local option_value = user_config[option_name]
    if option_value then
      for i, v in ipairs(option_value) do
        vim.validate {['user_config.' .. option_name .. '[' .. i .. ']'] = {v, value_type}}
      end
    end
  end
end

return options
