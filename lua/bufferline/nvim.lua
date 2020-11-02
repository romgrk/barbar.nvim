--
-- nvim.lua
--

local vim = vim
local api = vim.api

local nvim = {}
setmetatable(nvim, {
  __index = function(tbl, k)
    return api["nvim_" .. k]
  end
})

return nvim
