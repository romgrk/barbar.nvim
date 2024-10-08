local M = {}
local render = require("barbar.ui.render")
local state = require("barbar.state")

M.on_save = function()
  local buffers = state.export_buffers()
  return "lua require('barbar.state').restore_buffers "
    .. vim.inspect(buffers, { newline = " ", indent = "" })
end

M.on_post_load = function(data)
  if data then
    vim.api.nvim_command(data)
  end
  render.update(true)
end

return M
