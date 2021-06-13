-- This is a clock that starts at 0 and will only increment when the user is
-- active (controlled by calling report_activity()).
local accum = 0
local last_activity_start = os.time()
local active_until = last_activity_start + vim.g.bufferline.idle_timeout

local function report_activity()
  local now = os.time()
  if now > active_until then
    accum = accum + (active_until - last_activity_start)
    last_activity_start = now
  end
  active_until = now + vim.g.bufferline.idle_timeout
end

local function time()
  return accum + (math.min(os.time(), active_until) - last_activity_start)
end

return {
  report_activity = report_activity,
  time = time,
}
