-- allow usage of 'bufferline.xxx' instead of 'barbar.xxx'
-- get the current file path to find all files in `./barbar/`
-- -15 is the length of `bufferline.lua` from the end of the path
local dir = debug.getinfo(1, 'S').source:sub(2, -15) .. 'barbar/'
-- link all lua files in `./barbar/` to `bufferline.xxx`
for _, f in ipairs(vim.fn.globpath(dir, '*.lua', true, true)) do
  f = f:sub(#dir + 1, -5)
  package.preload['bufferline.'..f] = function() return require('barbar.' .. f) end
end
return require('barbar')
