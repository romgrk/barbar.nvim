--
-- jump_mode.lua
--

local utils = require'bufferline.utils'
local state = require'bufferline.state'

----------------------------------------
-- Section: Buffer-picking mode state --
----------------------------------------

local m = {
  letters = vim.g.bufferline.letters, -- array
  index_by_letter = {}, -- object
  letter_status = {}, -- array
  buffer_by_letter = {}, -- object
  letter_by_buffer = {}, -- object
}

-- Initialize m.index_by_letter
local function initialize_indexes()
  m.index_by_letter = {}
  m.letter_status = {}
  m.buffer_by_letter = {}
  m.letter_by_buffer = {}

  for index = 1, utils.len(m.letters) do
    local letter = string.sub(m.letters, index, index)
    m.index_by_letter[letter] = index
    m.letter_status[index] = false
  end
end

initialize_indexes()

-- local empty_bufnr = vim.api.nvim_create_buf(0, 1)

local function assign_next_letter(bufnr)
  bufnr = tonumber(bufnr)

  if m.letter_by_buffer[bufnr] ~= nil then
    return
  end

  -- First, try to assign a letter based on name
  if vim.g.bufferline.semantic_letters == true then
    local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ':t:r')

    for i = 1, vim.api.nvim_strwidth(name) do
      local letter = string.lower(string.sub(name, i, i))

      if m.index_by_letter[letter] ~= nil then
        local index = m.index_by_letter[letter]
        local status = m.letter_status[index]
        if status == false then
          m.letter_status[index] = true
          -- letter = m.letters[index]
          m.buffer_by_letter[letter] = bufnr
          m.letter_by_buffer[bufnr] = letter
          return letter
        end
      end
    end
  end

  -- Otherwise, assign a letter by usable order
  for i, status in ipairs(m.letter_status) do
    if status == false then
      local letter = m.letters:sub(i, i)
      m.letter_status[i] = true
      m.buffer_by_letter[letter] = bufnr
      m.letter_by_buffer[bufnr] = letter
      return letter
    end
  end

  return nil
end

local function unassign_letter(letter)
  if letter == '' or letter == nil then
    return
  end

  local index = m.index_by_letter[letter]

  m.letter_status[index] = false

  if m.buffer_by_letter[letter] ~= nil then
    local bufnr = m.buffer_by_letter[letter]
    m.buffer_by_letter[letter] = nil
    m.letter_by_buffer[bufnr] = nil
  end
end

local function get_letter(bufnr)
   if m.letter_by_buffer[bufnr] ~= nil then
      return m.letter_by_buffer[bufnr]
   end
   return assign_next_letter(bufnr)
end

local function unassign_letter_for(bufnr)
  unassign_letter(get_letter(bufnr))
end


local function activate()
  state.is_picking_buffer = true
  state.update()
  vim.api.nvim_command('redraw')
  state.is_picking_buffer = false

  local ok, char = pcall(vim.fn.getchar)

  if ok then
    local letter = vim.fn.nr2char(char)

    if letter ~= '' then
      if m.buffer_by_letter[letter] ~= nil then
        vim.api.nvim_set_current_buf(m.buffer_by_letter[letter])
      else
        vim.notify("Couldn't find buffer", vim.log.levels.WARN, {title = 'barbar.nvim'})
      end
    end
  else
    vim.notify("Invalid input", vim.log.levels.WARN, {title = 'barbar.nvim'})
  end

  state.update()
  vim.api.nvim_command('redraw')
end

m.activate = activate
m.get_letter = get_letter
m.unassign_letter = unassign_letter
m.unassign_letter_for = unassign_letter_for
m.assign_next_letter = assign_next_letter
m.initialize_indexes = initialize_indexes

return m
