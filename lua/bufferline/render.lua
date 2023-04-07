local render = require('barbar.ui.render')

--- @deprecated use `state.restore_buffers` instead
render.restore_buffers = require('barbar.state').restore_buffers

return render
