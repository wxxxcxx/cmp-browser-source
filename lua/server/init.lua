local utils = require('server.utils')
local HandshakeRequest = {
  description = '',
  headers = {},
}

function HandshakeRequest:create_handshake_response()
  return 'HTTP/1.1 101 Switching Protocols\n'
    .. 'Connection: Upgrade\r\n'
    .. 'Sec-WebSocket-Accept: '
    .. utils.base64(utils.sha1(self.headers['Sec-WebSocket-Key'] .. '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
    .. '\r\n'
    .. 'Upgrade: websocket\r\n'
    .. '\r\n'
end

function HandshakeRequest.ismatch(data)
  return string.find(data, 'GET') == 1
end

function HandshakeRequest.from(data)
  local instance = setmetatable({}, { __index = HandshakeRequest })
  local description_end = string.find(data, '\n')
  local description = string.sub(data, 1, description_end)
  instance.description = description
  local header_end = string.find(data, '\r\n\r\n')
  local header_string = string.sub(data, description_end, header_end)
  local headers = {}
  for key, value in string.gmatch(header_string, '([^:]+) *: *([^\r\n]+)\r?\n') do
    headers[utils.string_trim(key)] = utils.string_trim(value)
  end
  instance.headers = headers
  return instance
end

local Frame = { fin = nil, opcode = nil, payload = nil }
function Frame.from(data)
  local instance = setmetatable({}, { __index = Frame })
  local index = 1
  instance.fin = bit.rshift(string.byte(data, index), 7)
  -- local rsv1 = bit.band(bit.rshift(string.byte(data, 1), 6), 1)
  -- local rsv2 = bit.band(bit.rshift(string.byte(data, 1), 5), 1)
  -- local rsv3 = bit.band(bit.rshift(string.byte(data, 1), 4), 1)
  instance.opcode = bit.band(string.byte(data, index), 15)

  index = index + 1 -- 1bit
  local mask = bit.rshift(string.byte(data, index), 7)
  local payload_length = bit.band(string.byte(data, index), 127)
  index = index + 1 --1bit
  if payload_length == 126 then
    payload_length = bit.lshift(string.byte(data, 3), 8) + string.byte(data, 4)
    index = index + 2 --16bit
  elseif payload_length == 127 then
    payload_length = bit.lshift(string.byte(data, 3), 48)
      + bit.lshift(string.byte(data, 4), 40)
      + bit.lshift(string.byte(data, 5), 32)
      + bit.lshift(string.byte(data, 6), 24)
      + bit.lshift(string.byte(data, 7), 16)
      + bit.lshift(string.byte(data, 8), 8)
      + string.byte(data, 9)
    index = index + 8 -- 64bit
  end
  assert(mask == 1, 'Invalid mask')
  local masking_key = string.sub(data, index, index + 4)
  index = index + 4 -- 32bit
  local payload = ''
  local j = 1
  for i = index, index + payload_length - 1 do
    payload = payload .. string.char(bit.bxor(string.byte(data, i), string.byte(masking_key, j)))
    j = (j % 4) + 1
  end
  instance.payload = payload
  return instance
end

local OPCODES = {
  TEXT = 1,
  BINARY = 2,
  CLOSE = 8,
  PING = 9,
  PONG = 10,
}

local BrowserSourceServer = { }

function BrowserSourceServer.new()
  local instance = setmetatable({}, { __index = BrowserSourceServer })
  return instance
end

function BrowserSourceServer:start(options)
  options = options or {}
  local port = options.port or 18998
  local onmessage = options.onmessage

  self.server = vim.loop.new_tcp()
  self.server:nodelay(true)
  self.server:bind('127.0.0.1', port)
  self.server:listen(128, function(err)
    assert(not err, err)
    local client = vim.loop.new_tcp()
    self.server:accept(client)
    local message_type = 'text'
    local message = ''
    client:read_start(function(err, data)
      assert(not err, err)
      if data == nil then
        return
      end
      if HandshakeRequest.ismatch(data) then
        local request = HandshakeRequest.from(data)
        vim.loop.write(client, request:create_handshake_response())
      else
        local frame = Frame.from(data)
        if frame.opcode == OPCODES.TEXT then
          message_type = 'text'
        elseif frame == OPCODES.BINARY then
          message_type = 'binary'
        elseif frame == OPCODES.CLOSE then
          client:shutdown()
          client:close()
        end
        if frame.fin == 1 then
          message = message .. frame.payload
          if onmessage ~= nil and type(onmessage) == 'function' then
            if message_type == 'text' then
              options.onmessage(message)
            end
            client:shutdown()
            client:close()
          end
          message = ''
          message_type = 'text'
        elseif frame.fin == 0 then
          message = message + frame.payload
        end
      end
    end)
  end)
end

function BrowserSourceServer:stop()
  if self.server then
    vim.loop.close(self.server)
  end
end

return BrowserSourceServer
