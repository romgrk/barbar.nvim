--
-- nodes.lua
--

local table_insert = table.insert
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function

--- @class barbar.ui.Nodes
--- @see barbar.ui.node
--- Operations on `node`s.
local Nodes = {}

--- Sums the width of the nodes
--- @param nodes barbar.ui.node[]
--- @return integer
function Nodes.width(nodes)
  local result = 0
  for _, node in ipairs(nodes) do
    result = result + strwidth(node.text)
  end
  return result
end

--- Concatenates some `nodes` into a valid tabline string.
--- @param nodes barbar.ui.node[]
--- @return string
function Nodes.to_string(nodes)
  local result = ''

  for _, node in ipairs(nodes) do
    -- NOTE: We have to escape the text in case it contains '%', which is a special character to the
    --       tabline.
    --       To escape '%', we make it '%%'. It just so happens that '%' is also a special character
    --       in Lua, so we have write '%%' to mean '%'.
    result = result .. node.hl .. node.text:gsub('%%', '%%%%')
  end

  return result
end

--- Concatenates some `nodes` into a raw string.
--- @param nodes barbar.ui.node[]
--- For debugging purposes.
--- @return string
function Nodes.to_raw_string(nodes)
  local result = ''

  for _, node in ipairs(nodes) do
    result = result .. node.text
  end

  return result
end

--- Insert `other` into `nodes` at the `position`.
--- @param nodes barbar.ui.node[]
--- @param position integer
--- @return barbar.ui.node[] with_insertions
function Nodes.insert(nodes, position, node)
  return Nodes.insert_many(nodes, position, { node })
end

--- Insert `others` into `nodes` at the `position`.
--- @param nodes barbar.ui.node[]
--- @param position integer
--- @param others barbar.ui.node[]
--- @return barbar.ui.node[] with_insertions
function Nodes.insert_many(nodes, position, others)
  if position < 0 then
    local others_width = Nodes.width(others)
    local others_end = position + others_width

    if others_end < 0 then
      return nodes
    end

    local available_width = others_end

    position = 0
    others = Nodes.slice_left(others, available_width)
  end


  local current_position = 0

  local new_nodes = {}

  local i = 1
  while i <= #nodes do
    local node = nodes[i]
    local node_width = strwidth(node.text)

    -- While we haven't found the position...
    if current_position + node_width <= position then
      table_insert(new_nodes, node)
      i = i + 1
      current_position = current_position + node_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current node if it `position` is inside it
      if available_width > 0 then
        table_insert(new_nodes, {
          text = strcharpart(node.text, 0, available_width),
          hl = node.hl,
        })
      end

      -- Add new other nodes
      local others_width = 0
      for _, other in ipairs(others) do
        local other_width = strwidth(other.text)
        others_width = others_width + other_width
        table_insert(new_nodes, other)
      end

      local end_position = position + others_width

      -- Then, resume adding previous nodes
      -- table.insert(new_nodes, 'then')
      while i <= #nodes do
        local previous_node = nodes[i]
        local previous_node_width = strwidth(previous_node.text)
        local previous_node_start_position = current_position
        local previous_node_end_position   = current_position + previous_node_width

        if previous_node_end_position <= end_position and previous_node_width ~= 0 then
          -- continue
        elseif previous_node_start_position >= end_position then
          -- table.insert(new_nodes, 'direct')
          table_insert(new_nodes, previous_node)
        else
          local remaining_width = previous_node_end_position - end_position
          local start = previous_node_width - remaining_width
          local end_  = previous_node_width
          table_insert(new_nodes, { hl = previous_node.hl, text = strcharpart(previous_node.text, start, end_) })
        end

        i = i + 1
        current_position = current_position + previous_node_width
      end

      break
    end
  end

  return new_nodes
end

--- Select from `nodes` while fitting within the provided `width`, discarding all indices larger than the last index that fits.
--- @param width integer
--- @return barbar.ui.node[] sliced
function Nodes.slice_right(nodes, width)
  local accumulated_width = 0

  local new_nodes = {}

  for _, node in ipairs(nodes) do
    local text_width = strwidth(node.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      table_insert(new_nodes, { hl = node.hl, text = strcharpart(node.text, 0, diff) })
      break
    end

    table_insert(new_nodes, node)
  end

  return new_nodes
end

--- Select from `nodes` in reverse while fitting within the provided `width`, discarding all indices less than the last index that fits.
--- @param nodes barbar.ui.node[]
--- @param width integer
--- @return barbar.ui.node[] sliced
function Nodes.slice_left(nodes, width)
  local accumulated_width = 0

  local new_nodes = {}

  for i = #nodes, 1, -1 do
    local node = nodes[i] --- @type barbar.ui.node (it cannot be `nil`)
    local text_width = strwidth(node.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      table_insert(new_nodes, 1, { hl = node.hl, text = strcharpart(node.text, start, length) })
      break
    end

    table_insert(new_nodes, 1, node)
  end

  return new_nodes
end

return Nodes
