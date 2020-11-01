--
-- buffer.lua
--


local vim = vim
local api = vim.api
local nvim = require'bufferline.nvim'
local fun = require'bufferline.fun'
local len = fun.operator.len
local range = fun.range
local utils = require'bufferline.utils'
local state = require'bufferline.state'


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
