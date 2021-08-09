--
-- animate.lua
--

local float2nr = vim.fn.float2nr
local reltime = vim.fn.reltime
local reltimefloat = vim.fn.reltimefloat



local animation_frequency = 50

function start(duration, initial, final, type, callback)
  local ticks = (duration / animation_frequency) + 10

  local state = {}
  state.running = true
  state.fn = callback
  state.type = type
  state.step = (final - initial) / ticks
  state.duration = duration
  state.current = initial
  state.initial = initial
  state.final = final
  state.start = reltime()
  state.timer = vim.loop.new_timer()

  state.timer:start(0, animation_frequency, vim.schedule_wrap(function()
    animate_tick(state.timer, state)
  end))

  state.fn(state.current, state)
  return state
end

function animate_tick(timer, state)
  -- Alternative to finding current value:
  --
  --   let state.current += state.step
  --   call state.Fn(a:timer, current)
  --
  -- The reason why I go the long way (below) is because
  -- the timer callback might not be called exactly on time,
  -- therefore relying on the current time to find the current
  -- value is more reliable. It also ensure we end the animation
  -- on time, because we know if we have run for too long.

  local duration = state.duration
  local elapsed = reltimefloat(reltime(state.start)) * 1000
  local ratio = elapsed / duration

  -- We're still good here
  if ratio < 1 then
    local current = lerp(ratio, state.initial, state.final, state.type)
    state.fn(current, state)
  else
  -- Went overtime, stop the animation!
    state.running = false
    state.fn(state.final, state)
    timer:stop()
  end
end

function stop(state)
  state.timer:stop()
end

function lerp(ratio, initial, final, ...)
  local arg = {...}
  local type = (#arg > 0) and arg[1] or vim.v.t_number

  local range = final - initial
  local delta =
    (type == vim.v.t_number) and
      float2nr(ratio * range) or
              (ratio * range)

  return initial + delta
end


return {
  start = start,
  stop = stop,
  lerp = lerp,
}
