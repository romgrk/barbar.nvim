--
-- buffer.lua
--


local vim = vim
local nvim = require'bufferline.nvim'


-- returns 0: none, 1: active, 2: current
local function get_activity(number)
  if nvim.get_current_buf() == number then
    return 2
  end
  if vim.fn.bufwinnr(number) ~= -1 then
    return 1
  end
  return 0
end


return {
  get_activity = get_activity,
}
