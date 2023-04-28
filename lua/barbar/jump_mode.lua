--
-- jump_mode.lua
--

local buf_get_name = vim.api.nvim_buf_get_name --- @type function
local fnamemodify = vim.fn.fnamemodify --- @type function
local split = vim.fn.split --- @type function
local strcharpart = vim.fn.strcharpart --- @type function
local strwidth = vim.api.nvim_strwidth --- @type function

local config = require('barbar.config')

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

--- The letters which can be assigned to a buffer for a user to pick when entering `jump_mode`.
--- @type string[]
local letters = {}

--- @class barbar.JumpMode
--- @field buffer_by_letter {[string]: integer} a bi-directional map of buffer integers and their letters.
--- @field private index_by_letter {[string]: integer} `letters` in the order they were provided
--- @field private letter_by_buffer {[integer]: string} a bi-directional map of buffer integers and their letters.
--- @field private letter_status {[integer]: boolean}
--- @field reinitialize boolean whether an `initialize_indexes` operation has been queued.
local jump_mode = {}

--- Reset the module to a valid default state
--- @return nil
function jump_mode.initialize_indexes()
  jump_mode.buffer_by_letter = {}
  jump_mode.index_by_letter = {}
  jump_mode.letter_by_buffer = {}
  jump_mode.letter_status = {}

  for index, letter in ipairs(letters) do
    jump_mode.index_by_letter[letter] = index
    jump_mode.letter_status[index] = false
  end

  jump_mode.reinitialize = false
end

--- Set the letters which can be used by jump mode.
--- @param chars string
--- @return nil
function jump_mode.set_letters(chars)
  letters = split(chars, [[\zs]])
  jump_mode.initialize_indexes()
end

--- @param bufnr integer
--- @return nil|string assigned
function jump_mode.assign_next_letter(bufnr)
  if jump_mode.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if config.options.semantic_letters == true then
    local name = fnamemodify(buf_get_name(bufnr), ':t:r')

    for i = 1, strwidth(name) do
      local letter = strcharpart(name, i - 1, 1):lower()

      if jump_mode.index_by_letter[letter] ~= nil then
        local index = jump_mode.index_by_letter[letter]
        local status = jump_mode.letter_status[index]
        if status == false then
          jump_mode.letter_status[index] = true
          -- letter = m.letters[index]
          jump_mode.buffer_by_letter[letter] = bufnr
          jump_mode.letter_by_buffer[bufnr] = letter
          return letter
        end
      end
    end
  end

  -- Otherwise, assign a letter by usable order
  for i, status in ipairs(jump_mode.letter_status) do
    if status == false then
      local letter = letters[i]
      jump_mode.letter_status[i] = true
      jump_mode.buffer_by_letter[letter] = bufnr
      jump_mode.letter_by_buffer[bufnr] = letter
      return letter
    end
  end
end

--- @param bufnr integer
--- @return string letter assiegned to `bufnr`
function jump_mode.get_letter(bufnr)
  return jump_mode.letter_by_buffer[bufnr] or jump_mode.assign_next_letter(bufnr)
end

--- @param letter string
--- @return nil
function jump_mode.unassign_letter(letter)
  if letter == '' or letter == nil then
    return
  end

  local index = jump_mode.index_by_letter[letter]

  jump_mode.letter_status[index] = false

  if jump_mode.buffer_by_letter[letter] ~= nil then
    local bufnr = jump_mode.buffer_by_letter[letter]
    jump_mode.buffer_by_letter[letter] = nil
    jump_mode.letter_by_buffer[bufnr] = nil
  end

  jump_mode.reinitialize = true
end

--- Unassign the letter which is assigned to `bufnr.`
--- @param bufnr integer
--- @return nil
function jump_mode.unassign_letter_for(bufnr)
  jump_mode.unassign_letter(jump_mode.letter_by_buffer[bufnr])
end

return jump_mode
