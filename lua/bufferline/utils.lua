local utils = vim.deepcopy(require('barbar.utils'))

do
  local fs = require('barbar.fs')
  utils.basename = fs.basename
  utils.is_relative_path = fs.is_relative_path
  utils.relative = fs.relative
end

utils.hl = require('barbar.utils.hl')

do
  local list = require('barbar.utils.list')
  utils.index_of = list.index_of
  utils.list_reverse = list.reverse
  utils.list_slice_from_end = list.slice_from_end
end

do
  local tbl = require('barbar.utils.table')
  utils.tbl_remove_key = tbl.remove_key
  utils.tbl_set = tbl.set
end

return utils
