-- services
local httpService = game:GetService("HttpService")
-- libraries
local base64 = import("src/utils/base64.lua")()
-- variables
local WebSocket = (
	if syn and syn.websocket then
		syn.websocket
	elseif WebSocket then
		WebSocket
	else table.create(0)
)
-- main
local wsLib = {}
wsLib.__index = wsLib

function wsLib.new(url)
	local success, wsSocket = pcall(WebSocket.connect, url)

	if success then
		local self = table.create(0)

		self.handlers = table.create(0)
		self._connections = table.create(10)
		self._forceClose = false
		self._socket = nil

		local function onSocketMsg(message)
			message = httpService:JSONDecode(base64.decode(message))
			local eventName, data, timestamp =
				base64.decode(message.name), message.data, message.timestamp

			if not self.handlers[eventName] then return end
			self.handlers[eventName](data, timestamp)
		end

		local function initializeSocket(socket, reconnectCallback)
			for index, connection in self._connections do
				connection:Disconnect()
				table.remove(self._connections, index)
			end

			socket.OnMessage:Connect(onSocketMsg)
			socket.OnClose:Connect(reconnectCallback)
			self._socket = socket
		end

		local function reconnectSocket()
			if self._forceClose then return end
			local newSocket, reconnected, reconnectCount = nil, false, 0

			self._socket = nil
			print("Lost connection, reconnecting...")
			repeat
				local succ, result = pcall(WebSocket.connect, url)

				if succ then
					reconnected, newSocket = true, result
					break
				else
					reconnectCount += 1
					task.wait(2.5)
				end
			until (reconnected or reconnectCount >= 5)

			if reconnected then
				print("Reconnected successfully!")
				task.defer(initializeSocket, newSocket, reconnectSocket)
			else
				warn("Failed to reconnect after 5 tries.")
			end
		end

		initializeSocket(wsSocket, reconnectSocket)
		return setmetatable(self, wsLib)
	end
	return nil
end

function wsLib:Send(eventName, data)
	if not self._socket then return end
	local rawData = {
		["name"] = base64.encode(eventName),
		["data"] = data
	}

	rawData = base64.encode(httpService:JSONEncode(rawData))
	self._socket:Send(rawData)
end

function wsLib:on(eventName, callbackHandler)
	self.handlers[eventName] = callbackHandler
end

function wsLib:Close()
	for index, connection in self._connections do
		if typeof(connection) == "RBXScriptSignal" then
			connection:Disconnect()
		end
		table.remove(self._connections, index)
	end

	self._forceClose = true
	if self._socket then self._socket:Close() end
	setmetatable(self, nil)
end

return wsLib