--- Retrieve some value under `key` from `g:bufferline`, or return a `default` if none was present.
--- PERF: this implementation was profiled be an improvement over `vim.g.bufferline and vim.g.bufferline[key] or default`
--- @generic T
--- @param default? T
--- @param key string
--- @return T value
local function get(key, default)
  return (vim.g.bufferline or {})[key] or default
end

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

--- @return string[] excluded
function options.exclude_ft()
  return get('exclude_ft', {})
end

--- @return string[] excluded
function options.exclude_name()
  return get('exclude_name', {})
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

--- @return boolean enabled
function options.icons()
  return get('icons', true)
end

--- @return boolean enabled
function options.icon_custom_colors()
  return get('icon_custom_colors', false)
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

--- @return boolean enabled
function options.tabpages()
  return get('tabpages', true)
end

return options
