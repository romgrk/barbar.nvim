--
-- jump_mode.lua
--

local char = string.char
local string_lower = string.lower

local buf_get_name = vim.api.nvim_buf_get_name
local command = vim.api.nvim_command
local fnamemodify = vim.fn.fnamemodify
local getchar = vim.fn.getchar
local notify = vim.notify
local set_current_buf = vim.api.nvim_set_current_buf
local strcharpart = vim.fn.strcharpart
local strwidth = vim.api.nvim_strwidth

local state = require'bufferline.state'

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

--- Whether an `initialize_indexes` operation has been queued.
local reinitialize = false

--- @class bufferline.JumpMode
--- @field private buffer_by_letter table<string, integer> a bi-directional map of buffer integers and their letters.
--- @field private index_by_letter table<string, integer> `letters` in the order they were provided
--- @field private letter_by_buffer table<integer, string> a bi-directional map of buffer integers and their letters.
--- @field private letter_status table<integer, boolean>
--- @field private letters string the letters to allow while jumping
local M = {
  letters = vim.g.bufferline.letters,
  index_by_letter = {},
  letter_status = {},
  buffer_by_letter = {},
  letter_by_buffer = {},
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

  reinitialize = false
end

-- local empty_bufnr = vim.api.nvim_create_buf(0, 1)

function M.assign_next_letter(bufnr)
  if M.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if vim.g.bufferline.semantic_letters == true then
    local name = fnamemodify(buf_get_name(bufnr), ':t:r')

    for i = 1, strwidth(name) do
      local letter = string_lower(strcharpart(name, i - 1, 1))

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
  if reinitialize then
    M.initialize_indexes()
  end

  state.is_picking_buffer = true
  state.update()
  command('redraw')
  state.is_picking_buffer = false

  local ok, byte = pcall(getchar)

  if ok then
    local letter = char(byte)

    if letter ~= '' then
      if M.buffer_by_letter[letter] ~= nil then
        set_current_buf(M.buffer_by_letter[letter])
      else
        notify("Couldn't find buffer", vim.log.levels.WARN, {title = 'barbar.nvim'})
      end
    end
  else
    notify("Invalid input", vim.log.levels.WARN, {title = 'barbar.nvim'})
  end

  state.update()
  command('redraw')
end

M.initialize_indexes()
return M
