local char = string.char
local max = math.max
local min = math.min
local table_sort = table.sort

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local buf_get_option = vim.api.nvim_buf_get_option --- @type function
local bufnr = vim.fn.bufnr --- @type function
local bufwinnr = vim.fn.bufwinnr --- @type function
local get_current_buf = vim.api.nvim_get_current_buf --- @type function
local getchar = vim.fn.getchar --- @type function
local set_current_buf = vim.api.nvim_set_current_buf --- @type function

-- TODO: remove `vim.fs and` after 0.8 release
local normalize = vim.fs and vim.fs.normalize

local bbye = require'barbar.bbye'
local Buffer = require'barbar.buffer'
local JumpMode = require'barbar.jump_mode'
local render = require'barbar.ui.render'
local state = require'barbar.state'
local utils = require'barbar.utils'

local ESC = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)

--- Initialize the buffer pick mode.
--- @param fn fun()
--- @return nil
local function pick_buffer_wrap(fn)
  if JumpMode.reinitialize then
    JumpMode.initialize_indexes()
  end

  state.is_picking_buffer = true
  render.update()

  fn()

  state.is_picking_buffer = false
  render.update()
end

--- Shows an error that `bufnr` was not among the `state.buffers`
--- @param buffer_number integer
--- @return nil
local function notify_buffer_not_found(buffer_number)
  utils.notify(
    'Current buffer (' .. buffer_number .. ") not found in barbar.nvim's list of buffers: " .. vim.inspect(state.buffers),
    vim.log.levels.ERROR
  )
end

--- Forwards some `order_func` after ensuring that all buffers sorted in the order of pinned first.
--- @param order_func fun(bufnr_a: integer, bufnr_b: integer): boolean accepts `(integer, integer)` params.
--- @return fun(bufnr_a: integer, bufnr_b: integer): boolean
local function with_pin_order(order_func)
  return function(a, b)
    local a_pinned = state.is_pinned(a)
    local b_pinned = state.is_pinned(b)

    if a_pinned and not b_pinned then
      return true
    elseif b_pinned and not a_pinned then
      return false
    else
      return order_func(a, b)
    end
  end
end

--- @class barbar.api
local api = {}

--- Close all open buffers, except the current one.
--- @return nil
function api.close_all_but_current()
  local current_bufnr = get_current_buf()

  for _, buffer_number in ipairs(state.buffers) do
    if buffer_number ~= current_bufnr then
      bbye.bdelete(false, buffer_number)
    end
  end

  render.update()
end

--- Close all open buffers, except those in visible windows.
--- @return nil
function api.close_all_but_visible()
  local visible = Buffer.activities.Visible
  for _, buffer_number in ipairs(state.buffers) do
    if Buffer.get_activity(buffer_number) < visible then
      bbye.bdelete(false, buffer_number)
    end
  end

  render.update()
end

--- Close all open buffers, except pinned ones.
--- @return nil
function api.close_all_but_pinned()
  for _, buffer_number in ipairs(state.buffers) do
    if not state.is_pinned(buffer_number) then
      bbye.bdelete(false, buffer_number)
    end
  end

  render.update()
end

--- Close all open buffers, except pinned ones or the current one.
--- @return nil
function api.close_all_but_current_or_pinned()
  local current_bufnr = get_current_buf()

  for _, buffer_number in ipairs(state.buffers) do
    if not state.is_pinned(buffer_number) and buffer_number ~= current_bufnr then
      bbye.bdelete(false, buffer_number)
    end
  end

  render.update()
end

--- Close all buffers which are visually left of the current buffer.
--- @return nil
function api.close_buffers_left()
  local idx = utils.index_of(state.buffers, get_current_buf())
  if idx == nil or idx == 1 then
    return
  end

  for i = idx - 1, 1, -1 do
    bbye.bdelete(false, state.buffers[i])
  end

  render.update()
end

--- Close all buffers which are visually right of the current buffer.
--- @return nil
function api.close_buffers_right()
  local idx = utils.index_of(state.buffers, get_current_buf())
  if idx == nil then
    return
  end

  for i = #state.buffers, idx + 1, -1 do
    bbye.bdelete(false, state.buffers[i])
  end

  render.update()
end

-- Restore last recently closed buffer
function api.restore_buffer()
  state.pop_recently_closed()
end

--- Set the current buffer to the `number`
--- @param index integer
--- @return nil
function api.goto_buffer(index)
  if index < 0 then
    index = #state.buffers + index + 1
  else
    index = min(index, #state.buffers)
  end

  index = max(1, index)

  local buffer_number = state.buffers[index]
  if buffer_number then
    set_current_buf(buffer_number)
  else
    utils.notify(
      'E86: buffer at index ' .. index .. ' in list ' .. vim.inspect(state.buffers) .. ' does not exist.',
      vim.log.levels.ERROR
    )
  end
end

--- Go to the buffer a certain number of buffers away from the current buffer.
--- Use a positive number to go "right", and a negative one to go "left".
--- @param steps integer
--- @return nil
function api.goto_buffer_relative(steps)
  render.get_updated_buffers()

  if #state.buffers < 1 then
    return utils.notify('E85: There is no listed buffer', vim.log.levels.ERROR)
  end

  local current_bufnr = render.set_current_win_listed_buffer()
  local idx = utils.index_of(state.buffers, current_bufnr)

  if not idx then -- fall back to: 1. the alternate buffer, 2. the first buffer
    idx = utils.index_of(state.buffers, bufnr'#') or 1
    utils.notify(
      "Couldn't find buffer #" .. current_bufnr .. ' in the list: ' .. vim.inspect(state.buffers) ..
        '. Falling back to buffer #' .. state.buffers[idx],
      vim.log.levels.INFO
    )
  end

  set_current_buf(state.buffers[(idx + steps - 1) % #state.buffers + 1])
end

--- Move the current buffer to the index specified.
--- @param idx integer
--- @return nil
function api.move_current_buffer_to(idx)
  render.update()

  if idx == -1 then
    idx = #state.buffers
  end

  local current_bufnr = get_current_buf()
  local from_idx = utils.index_of(state.buffers, current_bufnr)

  if from_idx == nil then
    return notify_buffer_not_found(current_bufnr)
  end

  render.move_buffer(from_idx, idx)
end

--- Move the current buffer a certain number of times over.
--- @param steps integer
--- @return nil
function api.move_current_buffer(steps)
  render.update()

  local current_bufnr = get_current_buf()
  local idx = utils.index_of(state.buffers, current_bufnr)

  if idx == nil then
    return notify_buffer_not_found(current_bufnr)
  end

  render.move_buffer(idx, idx + steps)
end

--- Order the buffers by their buffer number.
--- @return nil
function api.order_by_buffer_number()
  table_sort(state.buffers, function(a, b) return a < b end)
  render.update()
end

--- Order the buffers by their parent directory.
--- @return nil
function api.order_by_directory()
  table_sort(state.buffers, with_pin_order(function(a, b)
    local name_of_a = buf_get_name(a)
    local name_of_b = buf_get_name(b)
    local a_less_than_b = name_of_b < name_of_a

    -- TODO: remove this block after 0.8 releases
    if not normalize then
      local a_is_relative = utils.is_relative_path(name_of_a)
      if a_is_relative and utils.is_relative_path(name_of_b) then
        return a_less_than_b
      end

      return a_is_relative
    end

    local level_of_a = #vim.split(normalize(name_of_a), '/')
    local level_of_b = #vim.split(normalize(name_of_b), '/')

    if level_of_a ~= level_of_b then
      return level_of_a < level_of_b
    end

    return a_less_than_b
  end))

  render.update()
end

--- Order the buffers by filetype.
--- @return nil
function api.order_by_language()
  table_sort(state.buffers, with_pin_order(function(a, b)
    return buf_get_option(a, 'filetype') < buf_get_option(b, 'filetype')
  end))

  render.update()
end

--- Order the buffers by their respective window number.
--- @return nil
function api.order_by_window_number()
  table_sort(state.buffers, with_pin_order(function(a, b)
    return bufwinnr(buf_get_name(a)) < bufwinnr(buf_get_name(b))
  end))

  render.update()
end

--- Activate the buffer pick mode.
--- @return nil
function api.pick_buffer()
  pick_buffer_wrap(function()
    local ok, letter = pcall(function() return char(getchar()) end)
    if ok and letter ~= '' then
      if JumpMode.buffer_by_letter[letter] ~= nil then
        set_current_buf(JumpMode.buffer_by_letter[letter])
      else
        utils.notify("Couldn't find buffer", vim.log.levels.WARN)
      end
    else
      utils.notify('Invalid input', vim.log.levels.WARN)
    end
  end)
end

--- Activate the buffer pick delete mode.
--- @return nil
function api.pick_buffer_delete()
  pick_buffer_wrap(function()
    while true do
      local ok, letter = pcall(function() return char(getchar()) end)
      if ok and letter ~= '' then
        if JumpMode.buffer_by_letter[letter] ~= nil then
          bbye.bdelete(false, JumpMode.buffer_by_letter[letter])
        elseif letter == ESC then
          break
        else
          utils.notify("Couldn't find buffer with letter '" .. letter .. "'", vim.log.levels.WARN)
        end
      else
        utils.notify('Invalid input', vim.log.levels.WARN)
      end

      render.update()
    end
  end)
end

--- Offset the rendering of the bufferline
--- @param width integer the amount to offset
--- @param text? string text to put in the offset
--- @param hl? string
--- @param side? 'left'|'right'
--- @return nil
function api.set_offset(width, text, hl, side)
  if side == nil then
    side = 'left'
  end

  if text == nil then
    text = ''
  end

  if hl == nil then
    hl = 'BufferOffset'
  end

  state.offset[side] = width > 0 and
    { hl = hl,  text = text, width = width } or
    { hl = nil, text = '',   width = 0 }

  render.update()
end

--- Toggle the `bufnr`'s "pin" state, visually.
--- @param buffer_number? integer
--- @return nil
function api.toggle_pin(buffer_number)
  state.toggle_pin(buffer_number or 0)
  render.update()
end

return api
