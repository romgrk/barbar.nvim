--
-- groups.lua
--

local table_insert = table.insert
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function

local utils = require'barbar.utils'

local m = {}

--- Concatenates some `groups` into a valid tabline string.
--- @param groups barbar.render.group[]
--- @return string
function m.to_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    -- NOTE: We have to escape the text in case it contains '%', which is a special character to the
    --       tabline.
    --       To escape '%', we make it '%%'. It just so happens that '%' is also a special character
    --       in Lua, so we have write '%%' to mean '%'.
    result = result .. group.hl .. group.text:gsub('%%', '%%%%')
  end

  return result
end

--- Concatenates some `groups` into a raw string.
--- For debugging purposes.
--- @param groups barbar.render.group[]
--- @return string
--- @diagnostic disable-next-line:unused-function,unused-local
function m.to_raw_string(groups)
  local result = ''

  for _, group in ipairs(groups) do
    result = result .. group.text
  end

  return result
end

--- Insert `others` into `groups` at the `position`.
--- @param groups barbar.render.group[]
--- @param position integer
--- @param others barbar.render.group[]
--- @return barbar.render.group[] with_insertions
function m.insert(groups, position, others)
  local current_position = 0

  local new_groups = {}

  local i = 1
  while i <= #groups do
    local group = groups[i]
    local group_width = strwidth(group.text)

    -- While we haven't found the position...
    if current_position + group_width <= position then
      table_insert(new_groups, group)
      i = i + 1
      current_position = current_position + group_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current group if it `position` is inside it
      if available_width > 0 then
        table_insert(new_groups, {
          text = strcharpart(group.text, 0, available_width),
          hl = group.hl,
        })
      end

      -- Add new other groups
      local others_width = 0
      for _, other in ipairs(others) do
        local other_width = strwidth(other.text)
        others_width = others_width + other_width
        table_insert(new_groups, other)
      end

      local end_position = position + others_width

      -- Then, resume adding previous groups
      -- table.insert(new_groups, 'then')
      while i <= #groups do
        local previous_group = groups[i]
        local previous_group_width = strwidth(previous_group.text)
        local previous_group_start_position = current_position
        local previous_group_end_position   = current_position + previous_group_width

        if previous_group_end_position <= end_position and previous_group_width ~= 0 then
          -- continue
        elseif previous_group_start_position >= end_position then
          -- table.insert(new_groups, 'direct')
          table_insert(new_groups, previous_group)
        else
          local remaining_width = previous_group_end_position - end_position
          local start = previous_group_width - remaining_width
          local end_  = previous_group_width
          table_insert(new_groups, { hl = previous_group.hl, text = strcharpart(previous_group.text, start, end_) })
        end

        i = i + 1
        current_position = current_position + previous_group_width
      end

      break
    end
  end

  return new_groups
end

--- Select from `groups` while fitting within the provided `width`, discarding all indices larger than the last index that fits.
--- @param groups barbar.render.group[]
--- @param width integer
--- @return barbar.render.group[]
function m.slice_right(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(groups) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      table_insert(new_groups, { hl = group.hl, text = strcharpart(group.text, 0, diff) })
      break
    end

    table_insert(new_groups, group)
  end

  return new_groups
end

--- Select from `groups` in reverse while fitting within the provided `width`, discarding all indices less than the last index that fits.
--- @param groups barbar.render.group[]
--- @param width integer
--- @return barbar.render.group[]
function m.slice_left(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(utils.list_reverse(groups)) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      table_insert(new_groups, 1, { hl = group.hl, text = strcharpart(group.text, start, length) })
      break
    end

    table_insert(new_groups, 1, group)
  end

  return new_groups
end

return m
