--
-- jump_mode.lua
--

local buf_get_name = vim.api.nvim_buf_get_name
local command = vim.api.nvim_command
local fnamemodify = vim.fn.fnamemodify
local getchar = vim.fn.getchar
local set_current_buf = vim.api.nvim_set_current_buf
local strcharpart = vim.fn.strcharpart
local strwidth = vim.api.nvim_strwidth

local state = require'bufferline.state'

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

local M = {
  letters = vim.g.bufferline.letters, -- array
  index_by_letter = {}, -- object
  letter_status = {}, -- array
  buffer_by_letter = {}, -- object
  letter_by_buffer = {}, -- object
}

-- Initialize m.index_by_letter
function M.initialize_indexes()
  M.index_by_letter = {}
  M.letter_status = {}
  M.buffer_by_letter = {}
  M.letter_by_buffer = {}

  for index = 1, #M.letters do
    local letter = strcharpart(M.letters, index - 1, 1)
    M.index_by_letter[letter] = index
    M.letter_status[index] = false
  end
end

M.initialize_indexes()

-- local empty_bufnr = vim.api.nvim_create_buf(0, 1)

function M.assign_next_letter(bufnr)
  bufnr = tonumber(bufnr)

  if M.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if vim.g.bufferline.semantic_letters == true then
    local name = fnamemodify(buf_get_name(bufnr), ':t:r')

    for i = 1, strwidth(name) do
      local letter = string.lower(strcharpart(name, i - 1, 1))

      if M.index_by_letter[letter] ~= nil then
        local index = M.index_by_letter[letter]
        local status = M.letter_status[index]
        if status == false then
          M.letter_status[index] = true
          -- letter = m.letters[index]
          M.buffer_by_letter[letter] = bufnr
          M.letter_by_buffer[bufnr] = letter
          return letter
        end
      end
    end
  end

  -- Otherwise, assign a letter by usable order
  for i, status in ipairs(M.letter_status) do
    if status == false then
      local letter = M.letters:sub(i, i)
      M.letter_status[i] = true
      M.buffer_by_letter[letter] = bufnr
      M.letter_by_buffer[bufnr] = letter
      return letter
    end
  end

  return nil
end

function M.unassign_letter(letter)
  if letter == '' or letter == nil then
    return
  end

  local index = M.index_by_letter[letter]

  M.letter_status[index] = false

  if M.buffer_by_letter[letter] ~= nil then
    local bufnr = M.buffer_by_letter[letter]
    M.buffer_by_letter[letter] = nil
    M.letter_by_buffer[bufnr] = nil
  end
end

function M.get_letter(bufnr)
  if M.letter_by_buffer[bufnr] ~= nil then
    return M.letter_by_buffer[bufnr]
  end

  return M.assign_next_letter(bufnr)
end

function M.unassign_letter_for(bufnr)
  M.unassign_letter(M.get_letter(bufnr))
end


function M.activate()
  state.is_picking_buffer = true
  state.update()
  command('redraw')
  state.is_picking_buffer = false

  local ok, char = pcall(getchar)

  if ok then
    local letter = string.char(char)

    if letter ~= '' then
      if M.buffer_by_letter[letter] ~= nil then
        set_current_buf(M.buffer_by_letter[letter])
      else
        vim.notify("Couldn't find buffer", vim.log.levels.WARN, {title = 'barbar.nvim'})
      end
    end
  else
    vim.notify("Invalid input", vim.log.levels.WARN, {title = 'barbar.nvim'})
  end

  state.update()
  command('redraw')
end

return M
