-- variables
local WebSocket = (syn and syn.websocket) or WebSocket
-- main
local wsLib = {}
wsLib.__index = wsLib

function wsLib.new(url: string)
	local succ, socket = pcall(WebSocket.connect, url)

	if succ then
		local wsObj = {
			_forcedClose = false,
			_socket = nil,
			_connections = table.create(0),
			_onMsgCallbacks = table.create(0)
		}

		local function onSocketMsg(message)
			for _, callback in wsObj._onMsgCallbacks do
				task.spawn(callback, message)
			end
		end

		local function initializeSocket(socket, reconnectCallback)
			for index, connection in wsObj._connections do
				connection:Disconnect()
				table.remove(wsObj._connections, index)
			end

			socket.OnMessage:Connect(onSocketMsg)
			socket.OnClose:Connect(reconnectCallback)
			wsObj._socket = socket
		end

		local function reconnectSocket()
			if wsObj._forcedClose then return end
			local newSocket, reconnected, reconnectCount = nil, false, 0

			print("Lost connection, reconnecting...")
			wsObj._socket = nil
			repeat
				local succ, result = pcall(WebSocket.connect, url)

				if succ then
					reconnected, newSocket = true, result
				else
					reconnectCount += 1
				end
			until (reconnected or reconnectCount >= 15)

			if reconnected then
				print("Reconnected successfully!")
				initializeSocket(newSocket, reconnectSocket)
			else
				warn("Failed to reconnect after 15 tries, trying again.")
				reconnectSocket()
			end
		end

		initializeSocket(socket, reconnectSocket)
		return setmetatable(wsObj, wsLib)
	else
		return nil
	end
end

function wsLib:Send(message)
	if not self._socket then return end
	self._socket:Send(message)
end

function wsLib:AddMessageCallback(callback)
	table.insert(self._onMsgCallbacks, callback)
end

function wsLib:Close()
	for index, connection in self._connections do
		connection:Disconnect()
		table.remove(self._connections, index)
	end

	self._forcedClose = true
	if self._socket then self._socket:Close() end
	setmetatable(self, nil)
end

return wsLib