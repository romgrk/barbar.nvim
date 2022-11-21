--
-- jump_mode.lua
--

local buf_get_name = vim.api.nvim_buf_get_name
local fnamemodify = vim.fn.fnamemodify
local split = vim.fn.split
local strcharpart = vim.fn.strcharpart
local strwidth = vim.api.nvim_strwidth

--- @type bufferline.options
local options = require'bufferline.options'

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

--- The letters which can be assigned to a buffer for a user to pick when entering `jump_mode`.
--- @type string[]
local letters = {}

--- @class bufferline.JumpMode
--- @field buffer_by_letter {[string]: integer} a bi-directional map of buffer integers and their letters.
--- @field private index_by_letter {[string]: integer} `letters` in the order they were provided
--- @field private letter_by_buffer {[integer]: string} a bi-directional map of buffer integers and their letters.
--- @field private letter_status {[integer]: boolean}
--- @field reinitialize boolean whether an `initialize_indexes` operation has been queued.
local JumpMode = {}

--- Reset the module to a valid default state
function JumpMode.initialize_indexes()
  JumpMode.buffer_by_letter = {}
  JumpMode.index_by_letter = {}
  JumpMode.letter_by_buffer = {}
  JumpMode.letter_status = {}

  for index, letter in ipairs(letters) do
    JumpMode.index_by_letter[letter] = index
    JumpMode.letter_status[index] = false
  end

  JumpMode.reinitialize = false
end

--- Set the letters which can be used by jump mode.
--- @param chars string
function JumpMode.set_letters(chars)
  letters = split(chars, [[\zs]])
  JumpMode.initialize_indexes()
end

-- local empty_bufnr = vim.api.nvim_create_buf(0, 1)

--- @param bufnr integer
--- @return nil|string assigned
function JumpMode.assign_next_letter(bufnr)
  if JumpMode.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if options.semantic_letters() == true then
    local name = fnamemodify(buf_get_name(bufnr), ':t:r')

    for i = 1, strwidth(name) do
      local letter = strcharpart(name, i - 1, 1):lower()

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
      local letter = letters[i]
      JumpMode.letter_status[i] = true
      JumpMode.buffer_by_letter[letter] = bufnr
      JumpMode.letter_by_buffer[bufnr] = letter
      return letter
    end
  end
end

--- @param bufnr integer
--- @return string letter assiegned to `bufnr`
function JumpMode.get_letter(bufnr)
  return JumpMode.letter_by_buffer[bufnr] or JumpMode.assign_next_letter(bufnr)
end

--- @param letter string
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

  JumpMode.reinitialize = true
end

--- Unassign the letter which is assigned to `bufnr.`
--- @param bufnr integer
function JumpMode.unassign_letter_for(bufnr)
  JumpMode.unassign_letter(JumpMode.letter_by_buffer[bufnr])
end

return JumpMode
