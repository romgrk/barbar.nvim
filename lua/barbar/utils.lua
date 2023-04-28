--
-- utils.lua
--

local notify = vim.notify
local notify_once = vim.notify_once

--- @class barbar.Utils
local utils = {}

utils.deprecate = vim.deprecate and
  --- Notify a user that something has been deprecated, and that there is an alternative.
  --- @param name string
  --- @param alternative string
  --- @return nil
  function(name, alternative)
    vim.deprecate(name, alternative, '2.0.0', 'barbar.nvim')
  end or
  function(name, alternative)
    utils.notify_once(name .. ' is deprecated. Use ' .. alternative .. 'instead.', vim.log.levels.WARN)
  end

--- Return "\``s`\`"
--- @param s string
--- @return string inline_code
function utils.markdown_inline_code(s)
  return '`' .. s .. '`'
end

--- Use `vim.notify` with a `msg` and log `level`. Integrates with `nvim-notify`.
--- @param msg string
--- @param level 0|1|2|3|4|5
--- @return nil
function utils.notify(msg, level)
  notify(msg, level, {title = 'barbar.nvim'})
end

--- Use `vim.notify` with a `msg` and log `level`. Integrates with `nvim-notify`.
--- @param msg string
--- @param level 0|1|2|3|4|5
--- @return nil
function utils.notify_once(msg, level)
  notify_once(msg, level, {title = 'barbar.nvim'})
end

return utils
