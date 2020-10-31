
let g:bufferline_animation_frequency = 50
    " \ get(g:, 'bufferline_animation_frequency', 2000)

function! bufferline#animate#start(duration, initial, final, type, Fn)
  let duration = a:duration
  let initial  = a:initial
  let final    = a:final
  let type     = a:type

  let ticks = (duration / g:bufferline_animation_frequency) + 10

  let state = {}
  let state.running = v:true
  let state.Fn = a:Fn
  let state.type = type
  let state.step = (final - initial) / ticks
  let state.duration = duration
  let state.current = initial
  let state.initial = initial
  let state.final = final
  let state.start = reltime()
  let state.timer = timer_start(
    \ g:bufferline_animation_frequency,
    \ {timer -> s:animate_tick(timer, state)},
    \ { 'repeat': ticks })

  call state.Fn(state.current, state)
  return state
endfunc

function! s:animate_tick(timer, state)
  let state = a:state

  " Alternative to finding current value:
  "
  "   let state.current += state.step
  "   call state.Fn(a:timer, current)
  "
  " The reason why I go the long way (below) is because
  " the timer callback might not be called exactly on time,
  " therefore relying on the current time to find the current
  " value is more reliable. It also ensure we end the animation
  " on time, because we know if we have run for too long.

  let duration = state.duration
  let elapsed = reltimefloat(reltime(state.start)) * 1000
  let ratio = elapsed / duration

  " We're still good here
  if ratio < 1
    let current = bufferline#animate#lerp(ratio, state.initial, state.final, state.type)
    call state.Fn(current, state)
  else
  " Went overtime, stop the animation!
    let state.running = v:false
    call state.Fn(state.final, state)
    call timer_stop(a:timer)
  end
endfunc

function! bufferline#animate#stop(state)
  call timer_stop(a:state.timer)
endfunc

function! bufferline#animate#lerp(ratio, initial, final, ...)
  let type = a:0 > 0 ? a:000[0] : v:t_number

  let range = a:final - a:initial
  let delta = type == v:t_number ?
    \ float2nr(a:ratio * range) :
    \          a:ratio * range

  return a:initial + delta
endfunc


