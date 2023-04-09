--
-- animate.lua
--

local floor = math.floor

local schedule_wrap = vim.schedule_wrap

--- @class barbar.animate.state
--- @field current number
--- @field duration number
--- @field final number
--- @field fn fun(current: number, state: self)
--- @field initial number
--- @field running boolean
--- @field start number
--- @field timer userdata
--- @field type unknown

--- @class barbar.Animate
local animate = {}

--- The amount of time between rendering the next part of the animation.
local FRAME_DURATION = 20

--- @param start? number some time point in the past
--- @return number milliseconds If `start` is not `nil`, then the time passed since `start`. Else, return the current time
local function time(start)
  local t = vim.loop.hrtime() / 1e6
  if start then
    t = t - start
  end
  return t
end

--- @param ratio number
--- @param initial number
--- @param final number
--- @return number
function animate.lerp(ratio, initial, final, delta_type)
  delta_type = delta_type or vim.v.t_number

  local range = final - initial
  local delta = delta_type == vim.v.t_number and floor(ratio * range) or (ratio * range)

  return initial + delta
end

--- @param state barbar.animate.state
--- @return nil
local function animate_tick(state)
  local duration = state.duration
  local elapsed = time(state.start)
  local ratio = elapsed / duration

  -- We're still good here
  if ratio < 1 then
    local current = animate.lerp(ratio, state.initial, state.final, state.type)
    state.fn(current, state)
  else
  -- Went overtime, stop the animation!
    state.running = false
    state.fn(state.final, state)
    animate.stop(state)
  end
end

--- @param callback fun(current: number, state: barbar.animate.state)
--- @param duration number
--- @param final number
--- @param initial number
--- @param type integer
--- @return barbar.animate.state
function animate.start(duration, initial, final, type, callback)
  local state = {
    current = initial,
    duration = duration,
    final = final,
    fn = callback,
    initial = initial,
    running = true,
    start = time(),
    timer = vim.loop.new_timer(),
    type = type,
  }

  state.timer:start(0, FRAME_DURATION, schedule_wrap(function()
    animate_tick(state)
  end))

  state.fn(state.current, state)
  return state
end

--- @param state barbar.animate.state
--- @return nil
function animate.stop(state)
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

return animate
