--
-- nvim.lua
--

local vim = vim
local api = vim.api

local nvim = {}

setmetatable(nvim, {
  __index = function(tbl, k)
    local fn = api["nvim_" .. k]
    nvim[k] = fn
    return fn
  end
})

return nvim
