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
local split = vim.fn.split
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
--- @field private letters table<string> the letters to allow while jumping
local JumpMode = {}

-- Initialize m.index_by_letter
function JumpMode.initialize_indexes()
  JumpMode.buffer_by_letter = {}
  JumpMode.index_by_letter = {}
  JumpMode.letter_by_buffer = {}
  JumpMode.letter_status = {}
  JumpMode.letters = split(vim.g.bufferline.letters, [[\zs]])

  for index, letter in ipairs(JumpMode.letters) do
    JumpMode.index_by_letter[letter] = index
    JumpMode.letter_status[index] = false
  end

  reinitialize = false
end

-- local empty_bufnr = vim.api.nvim_create_buf(0, 1)

function JumpMode.assign_next_letter(bufnr)
  if JumpMode.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if vim.g.bufferline.semantic_letters == true then
    local name = fnamemodify(buf_get_name(bufnr), ':t:r')

    for i = 1, strwidth(name) do
      local letter = string_lower(strcharpart(name, i - 1, 1))

      if JumpMode.index_by_letter[letter] ~= nil then
        local index = JumpMode.index_by_letter[letter]
        local status = JumpMode.letter_status[index]
        if status == false then
          JumpMode.letter_status[index] = true
          -- letter = m.letters[index]
          JumpMode.buffer_by_letter[letter] = bufnr
          JumpMode.letter_by_buffer[bufnr] = letter
          return letter
        end
      end
    end
  end

  -- Otherwise, assign a letter by usable order
  for i, status in ipairs(JumpMode.letter_status) do
    if status == false then
      local letter = JumpMode.letters[i]
      JumpMode.letter_status[i] = true
      JumpMode.buffer_by_letter[letter] = bufnr
      JumpMode.letter_by_buffer[bufnr] = letter
      return letter
    end
  end

  return nil
end

function JumpMode.unassign_letter(letter)
  if letter == '' or letter == nil then
    return
  end

  local index = JumpMode.index_by_letter[letter]

  JumpMode.letter_status[index] = false

  if JumpMode.buffer_by_letter[letter] ~= nil then
    local bufnr = JumpMode.buffer_by_letter[letter]
    JumpMode.buffer_by_letter[letter] = nil
    JumpMode.letter_by_buffer[bufnr] = nil
  end

  reinitialize = true
end

function JumpMode.get_letter(bufnr)
  return JumpMode.letter_by_buffer[bufnr] or JumpMode.assign_next_letter(bufnr)
end

function JumpMode.unassign_letter_for(bufnr)
  JumpMode.unassign_letter(JumpMode.get_letter(bufnr))
end


function JumpMode.activate()
  if reinitialize then
    JumpMode.initialize_indexes()
  end

  state.is_picking_buffer = true
  state.update()
  command('redraw')
  state.is_picking_buffer = false

  local ok, byte = pcall(getchar)

  if ok then
    local letter = char(byte)

    if letter ~= '' then
      if JumpMode.buffer_by_letter[letter] ~= nil then
        set_current_buf(JumpMode.buffer_by_letter[letter])
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

JumpMode.initialize_indexes()
return JumpMode
