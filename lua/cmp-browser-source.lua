local browser_source_server = require('server')

local source = { items = {}, server = nil, server_port = 18998 }

function source.setup(options)
  options = options or {}
  if options.server_port then
    source.server_port = options.server_port
  end
end

function source.start_server()
  source.server = browser_source_server.new()
  source.server:start({
    onmessage = function(message)
      local items = {}
      local count = 0
      for match in message:gmatch('[^%s]+') do
        count = count + 1
        table.insert(items, { label = match })
      end
      source.items = items
    end,
  })
end

function source.stop_server()
  print(type(source.server))
  if source.server then
    source.server:close()
  end
end

function source.new()
  local instance = setmetatable({}, { __index = source })
  return instance
end

function source:is_available()
  return true
end

function source:get_debug_name()
  return 'browser source'
end

function source:complete(params, callback)
  print(params.context.cursor_before_line)
  callback(self.items)
end

function source:resolve(completion_item, callback)
  callback(completion_item)
end

function source:execute(completion_item, callback)
  callback(completion_item)
end

return source
