-- !::exe [luafile %]
--
-- render.lua
--

local max = math.max
local min = math.min
local table_insert = table.insert
local table_concat = table.concat

local buf_call = vim.api.nvim_buf_call
local buf_delete = vim.api.nvim_buf_delete
local buf_get_lines = vim.api.nvim_buf_get_lines
local buf_get_name = vim.api.nvim_buf_get_name
local buf_get_option = vim.api.nvim_buf_get_option
local buf_is_valid = vim.api.nvim_buf_is_valid
local buf_line_count = vim.api.nvim_buf_line_count
local buf_set_var = vim.api.nvim_buf_set_var
local bufadd = vim.fn.bufadd
local command = vim.api.nvim_command
local create_augroup = vim.api.nvim_create_augroup
local create_autocmd = vim.api.nvim_create_autocmd
local defer_fn = vim.defer_fn
local exec_autocmds = vim.api.nvim_exec_autocmds
local get_current_buf = vim.api.nvim_get_current_buf
local has = vim.fn.has
local haslocaldir = vim.fn.haslocaldir
local list_bufs = vim.api.nvim_list_bufs
local list_tabpages = vim.api.nvim_list_tabpages
local list_wins = vim.api.nvim_list_wins
local notify = vim.notify
local schedule = vim.schedule
local set_current_buf = vim.api.nvim_set_current_buf
local set_current_win = vim.api.nvim_set_current_win
local strcharpart = vim.fn.strcharpart
local strwidth = vim.api.nvim_strwidth
local tabpage_list_wins = vim.api.nvim_tabpage_list_wins
local tabpagenr = vim.fn.tabpagenr
local tbl_contains = vim.tbl_contains
local tbl_filter = vim.tbl_filter
local win_get_buf = vim.api.nvim_win_get_buf

--- @type bufferline.animate
local animate = require'bufferline.animate'

--- @type bbye
local bbye = require'bufferline.bbye'

--- @type bufferline.buffer
local Buffer = require'bufferline.buffer'

--- @type bufferline.highlight
local highlight = require'bufferline.highlight'

--- @type bufferline.icons
local icons = require'bufferline.icons'

--- @type bufferline.JumpMode
local JumpMode = require'bufferline.jump_mode'

--- @type bufferline.Layout
local Layout = require'bufferline.layout'

--- @type bufferline.options
local options = require'bufferline.options'

--- @type bufferline.state
local state = require'bufferline.state'

--- @type bufferline.utils
local utils = require'bufferline.utils'

--- The highlight to use based on the state of a buffer.
local HL_BY_ACTIVITY = {'Inactive', 'Visible', 'Current'}

--- Last value for tabline
--- @type nil|string
local last_tabline

--- Create and reset autocommand groups associated with this plugin.
--- @return integer bufferline, integer bufferline_update
local function create_augroups()
  return create_augroup('bufferline', {}), create_augroup('bufferline_update', {})
end

--- Create valid `&tabline` syntax which highlights the next item in the tabline with the highlight `group` specified.
--- @param group string
--- @return string syntax
local function hl_tabline(group)
  return '%#' .. group .. '#'
end

--- @class bufferline.render.animation
--- @field CLOSE_DURATION integer
--- @field OPEN {DURATION: integer, DELAY: integer}
--- @field SCROLL_DURATION integer
local ANIMATION = {
  CLOSE_DURATION = 150,
  OPEN = {DELAY = 50, DURATION = 150},
  SCROLL_DURATION = 200,
}

--- @class bufferline.render.group
--- @field hl string the highlight group to use
--- @field text string the content being rendered

--- @class bufferline.render.scroll
--- @field current integer the place where the bufferline is currently scrolled to
--- @field target integer the place where the bufferline is scrolled/wants to scroll to.
local scroll = {current = 0, target = 0}

--- Concatenates some `groups` into a valid string.
--- @param groups bufferline.render.group[]
--- @return string
local function groups_to_string(groups)
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

--- Insert `others` into `groups` at the `position`.
--- @param groups bufferline.render.group[]
--- @param position integer
--- @param others bufferline.render.group[]
--- @return bufferline.render.group[] with_insertions
local function groups_insert(groups, position, others)
  local current_position = 0

  local new_groups = {}

  local i = 1
  while i <= #groups do
    local group = groups[i]
    local group_width = strwidth(group.text)

    -- While we haven't found the position...
    if current_position + group_width <= position then
      new_groups[#new_groups + 1] = group
      i = i + 1
      current_position = current_position + group_width

    -- When we found the position...
    else
      local available_width = position - current_position

      -- Slice current group if it `position` is inside it
      if available_width > 0 then
        new_groups[#new_groups + 1] = {
          text = strcharpart(group.text, 0, available_width),
          hl = group.hl,
        }
      end

      -- Add new other groups
      local others_width = 0
      for _, other in ipairs(others) do
        local other_width = strwidth(other.text)
        others_width = others_width + other_width
        new_groups[#new_groups + 1] = other
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
          new_groups[#new_groups + 1] = previous_group
        else
          local remaining_width = previous_group_end_position - end_position
          local start = previous_group_width - remaining_width
          local end_  = previous_group_width
          local new_group = { hl = previous_group.hl, text = strcharpart(previous_group.text, start, end_) }
          -- table.insert(new_groups, { group_start_position, group_end_position, end_position })
          new_groups[#new_groups + 1] = new_group
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
--- @param groups bufferline.render.group[]
--- @param width integer
local function slice_groups_right(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(groups) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local diff = text_width - (accumulated_width - width)
      local new_group = {hl = group.hl, text = strcharpart(group.text, 0, diff)}
      new_groups[#new_groups + 1] = new_group
      break
    end

    new_groups[#new_groups + 1] = group
  end

  return new_groups
end

--- Select from `groups` in reverse while fitting within the provided `width`, discarding all indices less than the last index that fits.
--- @param groups bufferline.render.group[]
--- @param width integer
local function slice_groups_left(groups, width)
  local accumulated_width = 0

  local new_groups = {}

  for _, group in ipairs(utils.reverse(groups)) do
    local text_width = strwidth(group.text)
    accumulated_width = accumulated_width + text_width

    if accumulated_width >= width then
      local length = text_width - (accumulated_width - width)
      local start = text_width - length
      local new_group = {hl = group.hl, text = strcharpart(group.text, start, length)}
      table_insert(new_groups, 1, new_group)
      break
    end

    table_insert(new_groups, 1, group)
  end

  return new_groups
end

--- Clears the tabline. Does not stop the tabline from being redrawn via autocmd.
--- @param tabline? string
local function set_tabline(tabline)
  last_tabline = tabline
  vim.opt.tabline = last_tabline
end

--- @class bufferline.render
local render = {}

--- An incremental animation for `close_buffer_animated`.
--- @param bufnr integer
--- @param new_width integer
local function close_buffer_animated_tick(bufnr, new_width, animation)
  if new_width > 0 and state.buffers_by_id[bufnr] ~= nil then
    local buffer_data = state.get_buffer_data(bufnr)
    buffer_data.width = new_width
    render.update()
    return
  end
  animate.stop(animation)
  render.close_buffer(bufnr, true)
end

--- Stop tracking the `bufnr` with barbar, and update the bufferline.
--- WARN: does NOT close the buffer in Neovim (see `:h nvim_buf_delete`)
--- @param bufnr integer
--- @param do_name_update? boolean refreshes all buffer names iff `true`
function render.close_buffer(bufnr, do_name_update)
  state.close_buffer(bufnr, do_name_update)
  render.update()
end

--- Same as `close_buffer`, but animated.
--- @param bufnr integer
function render.close_buffer_animated(bufnr)
  if options.animation() == false then
    return render.close_buffer(bufnr)
  end

  local buffer_data = state.get_buffer_data(bufnr)
  local current_width = buffer_data.real_width

  buffer_data.closing = true
  buffer_data.width = current_width

  animate.start(
    ANIMATION.CLOSE_DURATION, current_width, 0, vim.v.t_number,
    function(new_width, m)
      close_buffer_animated_tick(bufnr, new_width, m)
    end)
end

--- What to do when clicking a buffer close button.
--- @param buffer integer
function render.close_click_handler(buffer)
  if buf_get_option(buffer, 'modified') then
    buf_call(buffer, function() command('w') end)
    exec_autocmds('BufModifiedSet', {buffer = buffer})
  else
    bbye.bdelete(false, buffer)
  end
end

--- Disable the bufferline
function render.disable()
  create_augroups()
  set_tabline(nil)
  vim.cmd [[
    delfunction! BufferlineCloseClickHandler
    delfunction! BufferlineMainClickHandler
    delfunction! BufferlineOnOptionChanged
  ]]
end

--- The incremental animation for `open_buffer_start_animation`.
--- @param bufnr integer
--- @param new_width integer
--- @param animation unknown
local function open_buffer_animated_tick(bufnr, new_width, animation)
  local buffer_data = state.get_buffer_data(bufnr)
  buffer_data.width = animation.running and new_width or nil

  render.update()
end

--- Opens a buffer with animation.
--- @param bufnr integer
--- @param layout bufferline.layout.data
local function open_buffer_start_animation(layout, bufnr)
  local buffer_data = state.get_buffer_data(bufnr)
  local index = utils.index_of(state.buffers, bufnr)

  buffer_data.real_width = Layout.calculate_width(layout.base_widths[index], layout.padding_width)

  local target_width = buffer_data.real_width

  buffer_data.width = 1

  defer_fn(function()
    animate.start(
      ANIMATION.OPEN.DURATION, 1, target_width, vim.v.t_number,
      function(new_width, animation)
        open_buffer_animated_tick(bufnr, new_width, animation)
      end)
  end, ANIMATION.OPEN.DELAY)
end

--- Open the `new_buffers` in the bufferline.
local function open_buffers(new_buffers)
  local initial_buffers = #state.buffers

  -- Open next to the currently opened tab
  -- Find the new index where the tab will be inserted
  local new_index = utils.index_of(state.buffers, state.last_current_buffer)
  if new_index ~= nil then
    new_index = new_index + 1
  else
    new_index = #state.buffers + 1
  end

  -- Insert the buffers where they go
  for _, new_buffer in ipairs(new_buffers) do
    if utils.index_of(state.buffers, new_buffer) == nil then
      local actual_index = new_index

      local should_insert_at_start = options.insert_at_start()
      local should_insert_at_end = options.insert_at_end() or
        -- We add special buffers at the end
        buf_get_option(new_buffer, 'buftype') ~= ''

      if should_insert_at_start then
        actual_index = 1
        new_index = new_index + 1
      elseif should_insert_at_end then
        actual_index = #state.buffers + 1
      else
        new_index = new_index + 1
      end

      table_insert(state.buffers, actual_index, new_buffer)
    end
  end

  state.sort_pins_to_left()

  -- We're done if there is no animations
  if options.animation() == false then
    return
  end

  -- Case: opening a lot of buffers from a session
  -- We avoid animating here as well as it's a bit
  -- too much work otherwise.
  if initial_buffers <= 1 and #new_buffers > 1 or
     initial_buffers == 0 and #new_buffers == 1
  then
    return
  end

  -- Update names because they affect the layout
  state.update_names()

  local layout = Layout.calculate()

  for _, buffer_number in ipairs(new_buffers) do
    open_buffer_start_animation(layout, buffer_number)
  end
end

--- Enable the bufferline.
function render.enable()
  local augroup_bufferline, augroup_bufferline_update = create_augroups()

  create_autocmd({'BufNewFile', 'BufReadPost'}, {
    callback = function(tbl) JumpMode.assign_next_letter(tbl.buf) end,
    group = augroup_bufferline,
  })

  create_autocmd({'BufDelete', 'BufWipeout'}, {
    callback = function(tbl) JumpMode.unassign_letter_for(tbl.buf) end,
    group = augroup_bufferline,
  })

  create_autocmd('ColorScheme', {callback = highlight.setup, group = augroup_bufferline})

  create_autocmd('BufModifiedSet', {
    callback = function(tbl)
      local is_modified = buf_get_option(tbl.buf, 'modified')
      if is_modified ~= vim.b[tbl.buf].checked then
        buf_set_var(tbl.buf, 'checked', is_modified)
        render.update()
      end
    end,
    group = augroup_bufferline,
  })

  create_autocmd('User', {
    callback = function()
      local commands = vim.g.session_save_commands
      if not commands then
        return
      end

      -- We're allowed to use relative paths for buffers iff there are no tabpages
      -- or windows with a local directory (:tcd and :lcd)
      local use_relative_file_paths = true
      for tabnr,tabpage in ipairs(list_tabpages()) do
        if not use_relative_file_paths or haslocaldir(-1, tabnr) == 1 then
          use_relative_file_paths = false
          break
        end
        for _,win in ipairs(tabpage_list_wins(tabpage)) do
          if haslocaldir(win, tabnr) == 1 then
            use_relative_file_paths = false
            break
          end
        end
      end

      local bufnames = {}
      for _,bufnr in ipairs(state.buffers) do
        local name = buf_get_name(bufnr)
        if use_relative_file_paths then
          name = utils.relative(name)
        end
        -- escape quotes
        name = name:gsub('"', '\\"')
        bufnames[#bufnames + 1] = '"' .. name .. '"'
      end

      local bufarr = '{' .. table_concat(bufnames, ',') .. '}'

      commands[#commands + 1] = '" barbar.nvim'
      commands[#commands + 1] = "lua require'bufferline.render'.restore_buffers(" .. bufarr .. ")"

      vim.g.session_save_commands = commands
    end,
    group = augroup_bufferline,
    pattern = 'SessionSavePre',
  })

  create_autocmd('BufNew', {
    callback = function() render.update(true) end,
    group = augroup_bufferline_update,
  })

  create_autocmd(
    {'BufEnter', 'BufWinEnter', 'BufWinLeave', 'BufWritePost', 'SessionLoadPost', 'TabEnter', 'VimResized', 'WinEnter', 'WinLeave'},
    {
      callback = function() render.update() end,
      group = augroup_bufferline_update,
    }
  )

  create_autocmd('OptionSet', {
    callback = function() render.update() end,
    group = augroup_bufferline_update,
    pattern = 'buflisted',
  })

  create_autocmd('WinClosed', {
    callback = function() schedule(render.update) end,
    group = augroup_bufferline_update,
  })

  create_autocmd('TermOpen', {
    callback = function() defer_fn(function() render.update(true) end, 500) end,
    group = augroup_bufferline_update,
  })

  vim.cmd [[
    " Must be global -_-
    function! BufferlineCloseClickHandler(minwid, clicks, btn, modifiers) abort
      call luaeval("require'bufferline.render'.close_click_handler(_A)", a:minwid)
    endfunction

    " Must be global -_-
    function! BufferlineMainClickHandler(minwid, clicks, btn, modifiers) abort
      call luaeval("require'bufferline.render'.main_click_handler(_A[1], nil, _A[2])", [a:minwid, a:btn])
    endfunction

    " Must be global -_-
    function! BufferlineOnOptionChanged(dict, key, changes) abort
      call luaeval("require'bufferline.render'.on_option_changed(nil, _A)", a:key)
    endfunction

    call dictwatcheradd(g:bufferline, '*', 'BufferlineOnOptionChanged')
  ]]

  render.update()
  command('redrawtabline')
end

--- Refresh the buffer list.
function render.get_updated_buffers(update_names)
  local current_buffers = state.get_buffer_list()
  local new_buffers =
    tbl_filter(function(b) return not tbl_contains(state.buffers, b) end, current_buffers)

  -- To know if we need to update names
  local did_change = false

  -- Remove closed or update closing buffers
  local closed_buffers =
    tbl_filter(function(b) return not tbl_contains(current_buffers, b) end, state.buffers)

  for _, buffer_number in ipairs(closed_buffers) do
    local buffer_data = state.get_buffer_data(buffer_number)
    if not buffer_data.closing then
      did_change = true

      if buffer_data.real_width == nil then
        render.close_buffer(buffer_number)
      else
        render.close_buffer_animated(buffer_number)
      end
    end
  end

  -- Add new buffers
  if #new_buffers > 0 then
    did_change = true

    open_buffers(new_buffers)
  end

  state.buffers =
    tbl_filter(function(b) return buf_is_valid(b) end, state.buffers)

  if did_change or update_names then
    state.update_names()
  end

  return state.buffers
end

--- What to do when clicking a buffer label.
--- @param bufnr integer the buffer nummber
--- @param btn string
function render.main_click_handler(bufnr, _, btn, _)
  if bufnr == 0 then
    return
  end

  -- NOTE: in Vimscript this was not `==`, it was a regex compare `=~`
  if btn == 'm' then
    bbye.bdelete(false, bufnr)
  else
    render.set_current_win_listed_buffer()
    set_current_buf(bufnr)
  end
end

--- What to do when `vim.g.bufferline` is changed.
--- @param key string what option was changed.
function render.on_option_changed(_, key, _)
  if vim.g.bufferline and key == 'letters' then
    JumpMode.set_letters(options.letters())
  end
end

--- Restore the buffers
--- @param bufnames string[]
function render.restore_buffers(bufnames)
  -- Close all empty buffers. Loading a session may call :tabnew several times
  -- and create useless empty buffers.
  for _, bufnr in ipairs(list_bufs()) do
    if buf_get_name(bufnr) == ''
      and buf_get_option(bufnr, 'buftype') == ''
      and buf_line_count(bufnr) == 1
      and buf_get_lines(bufnr, 0, 1, true)[1] == ''
    then
        buf_delete(bufnr, {})
    end
  end

  state.buffers = {}
  for _,name in ipairs(bufnames) do
    state[#state + 1].buffers = bufadd(name)
  end

  render.update()
end

--- Open the window which contained the buffer which was clicked on.
--- @return integer current_bufnr
function render.set_current_win_listed_buffer()
  local current = get_current_buf()
  local is_listed = buf_get_option(current, 'buflisted')

  -- Check previous window first
  if not is_listed then
    command('wincmd p')
    current = get_current_buf()
    is_listed = buf_get_option(current, 'buflisted')
  end
  -- Check all windows now
  if not is_listed then
    local wins = list_wins()
    for _, win in ipairs(wins) do
      current = win_get_buf(win)
      is_listed = buf_get_option(current, 'buflisted')
      if is_listed then
        set_current_win(win)
        break
      end
    end
  end

  return current
end

--- Scroll the bufferline relative to its current position.
--- @param n integer the amount to scroll by. Use negative numbers to scroll left, and positive to scroll right.
function render.scroll(n)
  render.set_scroll(math.max(0, scroll.target + n))
end

local scroll_animation = nil

--- An incremental animation for `set_scroll`.
local function set_scroll_tick(new_scroll, animation)
  scroll.current = new_scroll
  if animation.running == false then
    scroll_animation = nil
  end
  render.update(nil, false)
end

--- Scrolls the bufferline to the `target`.
--- @param target integer where to scroll to
function render.set_scroll(target)
  scroll.target = target

  if scroll_animation ~= nil then
    animate.stop(scroll_animation)
  end

  scroll_animation = animate.start(
    ANIMATION.SCROLL_DURATION, scroll.current, target, vim.v.t_number,
    set_scroll_tick)
end

--- Generate the `&tabline` representing the current state of Neovim.
--- @param bufnrs integer[] the bufnrs to render
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @return nil|string syntax
local function generate_tabline(bufnrs, refocus)
  if options.auto_hide() then
    if #bufnrs <= 1 then
      if vim.o.showtabline == 2 then
        vim.o.showtabline = 0
      end
      return
    end
    if vim.o.showtabline == 0 then
      vim.o.showtabline = 2
    end
  end

  local current = get_current_buf()

  -- Store current buffer to open new ones next to this one
  if buf_get_option(current, 'buflisted') then
    if vim.b.empty_buffer then
      state.last_current_buffer = nil
    else
      state.last_current_buffer = current
    end
  end

  local icons_enabled = options.icons()

  local click_enabled = has('tablineat') and options.clickable()
  local has_close = options.closable()
  local has_icons = (icons_enabled == true) or (icons_enabled == 'both') or (icons_enabled == 'buffer_number_with_icon')
  local has_icon_custom_colors = options.icon_custom_colors()
  local has_buffer_number = (icons_enabled == 'buffer_numbers') or (icons_enabled == 'buffer_number_with_icon')
  local has_numbers = (icons_enabled == 'numbers') or (icons_enabled == 'both')

  local layout = Layout.calculate()

  local items = {}

  local current_buffer_index = nil
  local current_buffer_position = 0

  for i, bufnr in ipairs(bufnrs) do
    local buffer_data = state.get_buffer_data(bufnr)
    local buffer_name = buffer_data.name or '[no name]'

    buffer_data.real_width    = Layout.calculate_width(layout.base_widths[i], layout.padding_width)
    buffer_data.real_position = current_buffer_position

    local activity = Buffer.get_activity(bufnr)
    local is_inactive = activity == 1
    -- local is_visible = activity == 2
    local is_current = activity == 3
    local is_modified = buf_get_option(bufnr, 'modified')
    -- local is_closing = buffer_data.closing
    local is_pinned = state.is_pinned(bufnr)

    local status = HL_BY_ACTIVITY[activity]
    local mod = is_modified and 'Mod' or ''

    local separatorPrefix = hl_tabline('Buffer' .. status .. 'Sign')
    local separator = is_inactive and
      options.icon_separator_inactive() or
      options.icon_separator_active()

    local namePrefix = hl_tabline('Buffer' .. status .. mod)
    local name = buffer_name

    -- The buffer name
    local bufferIndexPrefix = ''
    local bufferIndex = ''

    -- The jump letter
    local jumpLetterPrefix = ''
    local jumpLetter = ''

    -- The devicon
    local iconPrefix = ''
    local icon = ''

    if has_buffer_number or has_numbers then
      local number_text = has_buffer_number and tostring(bufnr) or tostring(i)

      bufferIndexPrefix = hl_tabline('Buffer' .. status .. 'Index')
      bufferIndex = number_text .. ' '
    end

    if state.is_picking_buffer then
      local letter = JumpMode.get_letter(bufnr)

      -- Replace first character of buf name with jump letter
      if letter and not has_icons then
        name = strcharpart(name, 1)
      end

      jumpLetterPrefix = hl_tabline('Buffer' .. status .. 'Target')
      jumpLetter = (letter or '') ..
        (has_icons and (' ' .. (letter and '' or ' ')) or '')
    else

      if has_icons then
        local iconChar, iconHl = icons.get_icon(buffer_name, buf_get_option(bufnr, 'filetype'), status)
        local hlName = is_inactive and 'BufferInactive' or iconHl
        iconPrefix = has_icon_custom_colors and hl_tabline('Buffer' .. status .. 'Icon') or hlName and hl_tabline(hlName) or namePrefix
        icon = iconChar .. ' '
      end
    end

    local closePrefix = ''
    local close = ''
    if has_close or is_pinned then
      local closeIcon =
        is_pinned and
          options.icon_pinned() or
        (not is_modified and
          options.icon_close_tab() or
          options.icon_close_tab_modified())

      closePrefix = namePrefix
      close = closeIcon .. ' '

      if click_enabled then
        closePrefix =
            '%' .. bufnr .. '@BufferlineCloseClickHandler@' .. closePrefix
      end
    end

    local clickable = ''
    if click_enabled then
      clickable = '%' .. bufnr .. '@BufferlineMainClickHandler@'
    end

    local padding = (' '):rep(layout.padding_width)

    local item = {
      is_current = is_current,
      width = buffer_data.width
        -- <padding> <base_widths[i]> <padding>
        or layout.base_widths[i] + (2 * layout.padding_width),
      position = buffer_data.position or buffer_data.real_position,
      groups = {
        {hl = clickable .. separatorPrefix, text = separator},
        {hl = '',                           text = padding},
        {hl = bufferIndexPrefix,            text = bufferIndex},
        {hl = clickable .. iconPrefix,      text = icon},
        {hl = jumpLetterPrefix,             text = jumpLetter},
        {hl = clickable .. namePrefix,      text = name},
        {hl = '',                           text = padding},
        {hl = '',                           text = ' '},
        {hl = closePrefix,                  text = close},
      }
    }

    if is_current and refocus ~= false then
      current_buffer_index = i
      current_buffer_position = buffer_data.real_position

      local start = current_buffer_position
      local end_  = current_buffer_position + item.width

      if scroll.target > start then
        render.set_scroll(start)
      elseif scroll.target + layout.buffers_width < end_ then
        render.set_scroll(scroll.target + (end_ - (scroll.target + layout.buffers_width)))
      end
    end

    items[#items + 1] = item
    current_buffer_position = current_buffer_position + item.width
  end

  -- Create actual tabline string
  local result = ''

  -- Add offset filler & text (for filetree/sidebar plugins)
  if state.offset.width > 0 then
    local offset_available_width = state.offset.width - 2
    local groups = {{
      hl = hl_tabline(state.offset.hl or 'BufferOffset'),
      text = ' ' .. state.offset.text,
    }}

    result = result .. groups_to_string(slice_groups_right(groups, offset_available_width))
    result = result .. (' '):rep(offset_available_width - #state.offset.text)
    result = result .. ' '
  end

  -- Add bufferline
  local bufferline_groups = {{
    hl = hl_tabline('BufferTabpageFill'),
    text = (' '):rep(layout.actual_width),
  }}

  for i, item in ipairs(items) do
    if i ~= current_buffer_index then
      bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
    end
  end
  if current_buffer_index ~= nil then
    local item = items[current_buffer_index]
    bufferline_groups = groups_insert(bufferline_groups, item.position, item.groups)
  end

  -- Crop to scroll region
  local max_scroll = max(layout.actual_width - layout.buffers_width, 0)
  local scroll_current = min(scroll.current, max_scroll)
  local buffers_end = layout.actual_width - scroll_current

  if buffers_end > layout.buffers_width then
    bufferline_groups = slice_groups_right(bufferline_groups, scroll_current + layout.buffers_width)
  end
  if scroll_current > 0 then
    bufferline_groups = slice_groups_left(bufferline_groups, layout.buffers_width)
  end

  -- Render bufferline string
  result = result .. groups_to_string(bufferline_groups)

  -- To prevent the expansion of the last click group
  result = result .. '%0@BufferlineMainClickHandler@' .. hl_tabline('BufferTabpageFill')

  if layout.actual_width + strwidth(options.icon_separator_inactive()) <= layout.buffers_width and #items > 0 then
    result = result .. options.icon_separator_inactive()
  end

  local current_tabpage = tabpagenr()
  local total_tabpages  = tabpagenr('$')
  if layout.tabpages_width > 0 then
    result = result .. '%=%#BufferTabpages# ' .. tostring(current_tabpage) .. '/' .. tostring(total_tabpages) .. ' '
  end

  result = result .. hl_tabline('BufferTabpageFill')

  return result
end

--- Update `&tabline`
--- @param refocus? boolean if `true`, the bufferline will be refocused on the current buffer (default: `true`)
--- @param update_names? boolean whether to refresh the names of the buffers (default: `false`)
function render.update(update_names, refocus)
  if vim.g.SessionLoad then
    return
  end

  local ok, result =
    xpcall(generate_tabline, debug.traceback, render.get_updated_buffers(update_names), refocus)

  if not ok then
    render.disable()
    notify(
      "Barbar detected an error while running. Barbar disabled itself :/ " ..
        "Include this in your report: " ..
        tostring(result),
      vim.log.levels.ERROR,
      {title = 'barbar.nvim'}
    )

    return
  elseif result ~= last_tabline then
    set_tabline(result)
    command('redrawtabline')
  end
end

return render
