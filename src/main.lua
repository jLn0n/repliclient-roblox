-- initialization
if not import then return error("[REPLICLIENT]: not using the loader!") end
local version = "1.1.0"

local config do
	local loadedConfig = select(2, ...)
	local isATable = (typeof(loadedConfig) == "table")
	loadedConfig = (if isATable then loadedConfig else table.create(0))

	if not isATable then warn("[REPLICLIENT]: Failed to load configuration, loading default...") end

	loadedConfig.serverUrl = (if not loadedConfig.serverUrl then "wss://repliclient-server.jlnn0n.repl.co" else loadedConfig.serverUrl)

	loadedConfig.chatBubbleEnabled = (if typeof(loadedConfig.chatBubbleEnabled) ~= "boolean" then false else loadedConfig.chatBubbleEnabled)
	loadedConfig.collidableCharacters = (if typeof(loadedConfig.collidableCharacters) ~= "boolean" then true else loadedConfig.collidableCharacters)

	loadedConfig.debugMode = (if typeof(loadedConfig.debugMode) ~= "boolean" then false else loadedConfig.debugMode)

	config = loadedConfig
end
-- env modifications
local identifyexecutor = (identifyexecutor or function()
	return "Unknown Executor"
end)
-- services
local chatService = game:GetService("Chat")
local coreGui = game:GetService("CoreGui")
local httpService = game:GetService("HttpService")
local inputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local starterGui = game:GetService("StarterGui")
local textService = game:GetService("TextService")
-- imports
local base64 = import("src/utils/base64.lua")()
local bitBuffer = import("src/utils/bitbuffer.lua")()
local wsLib = import("src/utils/ws-lib.lua")()
-- objects
local player = players.LocalPlayer
local character = player.Character
local humanoid = character.Humanoid
local characterTemplate = game:GetObjects("rbxassetid://6843243348")[1]
local debugUI, debugUIFormats = import("src/utils/ui.lua")()
-- variables
local serverConfig
local pingStartTime
local clientReady = false
local accumulatedRecieveTime = 0
local wsObj = assert(wsLib.new(config.serverUrl), string.format("Failed to connect to '%s'. This might happen because server is closed or unreachable.", config.serverUrl))
local rateInfos = table.create(0)
local connections, refs = table.create(10), table.create(0)
local connectedPlrs, connectedPlrChars = table.create(0), table.create(0)
local userIdCache = table.create(0)
local characterParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
local characterLimbParts = {"Left Arm", "Right Arm", "Left Leg", "Right Leg"}
local replicationIDs = {
	-- player related
	["ID_PLR_ADD"] = 0x000,
	["ID_PLR_CHATTED"] = 0x001,
	["ID_PLR_REMOVE"] = 0x002,

	-- character related
	["ID_CHAR_UPDATE"] = 0x100,

	-- instance related
	["ID_INSTANCE_ADD"] = 0x200,
	["ID_INSTANCE_DESTROY"] = 0x201,
	["ID_PROPERTY_MODIFY"] = 0x202,
}
-- functions
local function createFakePlr(name, userId, character)
	local plrInstance = Instance.new("Player")

	plrInstance.Name = name
	plrInstance.Character = character
	sethiddenproperty(plrInstance, "UserId", userId)
	connectedPlrs[name] = plrInstance
end

local function createPacketBuffer(packetId, ...)
	--[[
		TODO: packet should be encrypted with the encryption key
	--]]

	local packetBuffer = bitBuffer()

	packetBuffer.writeInt16(replicationIDs[packetId])
	return packetBuffer, packetBuffer.dumpBase64 --[[aka bufferFinish]]
end

local function disconnectToServer()
	local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_REMOVE")

	packetBuffer.writeString(player.Name)
	wsObj:Send("data_send", bufferFinish()) -- removes player to other clients
	wsObj:Close() -- disconnects us entirely

	for index, connection in connections do
		connection:Disconnect()
		table.remove(connections, index)
	end
end

local function getUserIdFromName(name)
	if userIdCache[name] then return userIdCache[name] end

	local plr = players:FindFirstChild(name)
	if plr then
		userIdCache[name] = plr.UserId
		return plr.UserId
	end

	local succ, plrUserId = pcall(players.GetUserIdFromNameAsync, players, name)
	if succ then
		userIdCache[name] = plrUserId
		return plrUserId
	end
end

local function getCharacterFromUserId(userId)
	local newChar = characterTemplate:Clone()
	local _humanoid = newChar:FindFirstChild("Humanoid")

	local succ, humDesc = pcall(players.GetHumanoidDescriptionFromUserId, players, userId)

	if succ then
		newChar.Parent = workspace

		_humanoid:ApplyDescription(humDesc)
		return newChar
	else
		newChar:Destroy()
	end
end

local function rateCheck(name, rate, timestamp)
	timestamp = (timestamp or os.clock())
	rateInfos[name] = (if not rateInfos[name] then {
		["lastTime"] = -1,
	} else rateInfos[name])
	local rateInfo = rateInfos[name]

	if rateInfo.lastTime == -1 then
		-- initializes rateInfo
		rateInfo.lastTime = timestamp

		return true
	else
		rateInfo.lastTime = (rateInfo.lastTime or timestamp)
		local timeElapsed = timestamp - rateInfo.lastTime

		if timeElapsed >= (1 / rate) then
			rateInfo.lastTime = timestamp

			return true
		else
			return false
		end
	end
end

local function renderChat(chatter, chatMsg, adornee)
	chatService:Chat(adornee, chatMsg, Enum.ChatColor.Green)
	starterGui:SetCore("ChatMakeSystemMessage", {
		Text = string.format("Repliclient | [%s]: %s", chatter, chatMsg),
		Color = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.SourceSansBold,
		FontSize = Enum.FontSize.Size32,
	})
end

local function getTextSize(label: TextLabel)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = label.Text
	params.Font = label.FontFace
	params.Size = label.TextSize
	params.Width = 1e6

	local succ, textSize = pcall(textService.GetTextBoundsAsync, textService, params)
	return (
		if succ then
			textSize
		else
			error(textSize)
	)
end

local function unpackOrientation(vectRot, dontUseRadians)
	vectRot = (if not dontUseRadians then vectRot * (math.pi / 180) else vectRot)
	return vectRot.X, vectRot.Y, (if typeof(vectRot) == "Vector2" then 0 else vectRot.Z)
end
-- main
if humanoid.RigType ~= Enum.HumanoidRigType.R6 then return warn("Repliclient currently only support R6 characters.") end

refs.gameIndex = hookmetamethod(game, "__index", function(...)
	local self, index = ...

	-- returns the connected player when called from exploit environment, returns nil if not
	if checkcaller() then
		if self == players and connectedPlrs[index] then
			return connectedPlrs[index]
		elseif (self:IsA("Player") and connectedPlrs[tostring(self)]) and index == "Parent" then -- self.Name causes C stack overflow
			return players
		end
	end
	return refs.gameIndex(...)
end)

-- connection
wsObj:on("connect", function(serverInfo)
	--[[
		some connection post initialization here
	--]]
	serverInfo = httpService:JSONDecode(serverInfo)
	serverConfig = serverInfo.serverConfig
	do
		local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_ADD")

		packetBuffer.writeString(player.Name)
		wsObj:Send("data_send", bufferFinish())
		refs["ID_PLR_ADD-bufferCache"] = bufferFinish
	end

	debugUI.Parent = coreGui.RobloxGui
	debugUI.Version.Text = string.format(debugUIFormats.Version, version)
	debugUI.ClientID.Text = string.format(debugUIFormats.ClientID, serverInfo.clientId)
	debugUI.ServerURL.Text = string.format(debugUIFormats.ServerURL, config.serverUrl)

	print(string.format("\n|  Repliclient [v%s]\n|  Client ID: `%s`\n|  Server URL: `%s`\n|  Host: `%s`", version, serverInfo.clientId, config.serverUrl, identifyexecutor()))
	clientReady = true
end)
repeat runService.Heartbeat:Wait() until clientReady

wsObj:on("pong", function()
	local pingLatency = ((os.clock() - pingStartTime) / 2) * 1000
	local pingStatus = (
		if pingLatency <= 50 then
			"GREAT"
		elseif pingLatency <= 100 then
			"VERY GOOD"
		elseif pingLatency <= 150 then
			"GOOD"
		elseif pingLatency <= 200 then
			"OKAY"
		elseif pingLatency <= 250 then
			"BAD"
		elseif pingLatency <= 350 then
			"VERY BAD"
		else
			"AWFUL"
	)

	debugUI.ServerPing.Text = string.format(debugUIFormats.ServerPing, pingLatency, pingStatus)
end)

wsObj:on("data_recieve", function(data, timestamp)
	if not rateCheck("data_recieve", serverConfig.recievePerSecond, timestamp) then return end
	accumulatedRecieveTime = runService.Stepped:Wait()

	local succ, packetBuffer = pcall(function()
		return bitBuffer(base64.decode(data))
	end)
	if not succ then return warn("Failed to parse data recieved:\n", data) end

	local packetId = packetBuffer.readInt16()

	if packetId == replicationIDs["ID_PLR_ADD"] then
		local plrName = packetBuffer.readString()

		if (player.Name ~= plrName) and not connectedPlrs[plrName] then
			local plrChar = workspace:FindFirstChild(plrName)

			if (not players:FindFirstChild(plrName) and not connectedPlrs[plrName]) then
				local plrUserId = getUserIdFromName(plrName)
				plrChar = getCharacterFromUserId(plrUserId)

				createFakePlr(plrName, plrUserId, plrChar)
			end

			if not plrChar then return end
			connectedPlrChars[plrName] = plrChar
			plrChar.Name = plrName
			plrChar:BreakJoints()

			for _, part in plrChar:GetChildren() do
				part = (
					if (part:IsA("BasePart") and table.find(characterParts, part.Name)) then
						part
					elseif (part:IsA("Accessory") and part:FindFirstChild("Handle")) then
						part.Handle
					else nil
				)

				if not part then continue end
				part.Anchored = true
				part.CanCollide = (if ((not config.collidableCharacters) or table.find(characterLimbParts, part.Name)) then false else true)
				part.Velocity, part.RotVelocity = Vector3.zero, Vector3.zero -- no more character vibration
			end

			-- resends "ID_PLR_ADD" to other clients because its not automatically done by server (for now)
			wsObj:Send("data_send", refs["ID_PLR_ADD-bufferCache"]())
		end
	elseif packetId == replicationIDs["ID_PLR_CHATTED"] then
		local plrName = packetBuffer.readString()

		if (player.Name ~= plrName) and connectedPlrs[plrName] then
			local plrInstance = connectedPlrs[plrName]
			local chatMsg = packetBuffer.readString()

			renderChat(plrName, chatMsg, plrInstance.Character:FindFirstChild("Head"))
		end
	elseif packetId == replicationIDs["ID_PLR_REMOVE"] then
		local plrName = packetBuffer.readString()

		if (player.Name ~= plrName) and connectedPlrs[plrName] then
			local plrInstance = connectedPlrs[plrName]

			plrInstance.Character:Destroy()
			plrInstance:Destroy()
			connectedPlrs[plrName] = nil
			connectedPlrChars[plrName] = nil
		end
	elseif packetId == replicationIDs["ID_CHAR_UPDATE"] then
		local plrName = packetBuffer.readString()

		if player.Name ~= plrName then
			local plrChar = connectedPlrChars[plrName]

			if not plrChar then return end
			for _ = 1, packetBuffer.readInt8() do -- character parts
				local partObj = plrChar:FindFirstChild(packetBuffer.readString())
				local position, orientation = packetBuffer.readVector3(), packetBuffer.readVector3()

				if not (partObj and partObj:IsA("BasePart")) then continue end
				partObj.CFrame = partObj.CFrame:Lerp(
					(CFrame.new(position) *
					CFrame.fromOrientation(unpackOrientation(orientation))),
					math.min(accumulatedRecieveTime / (240 / 60), 1)
				)
			end

			for _ = 1, packetBuffer.readInt8() do -- character accessories
				local partObj = plrChar:FindFirstChild(packetBuffer.readString())
				local position, orientation = packetBuffer.readVector3(), packetBuffer.readVector3()

				if not (partObj and partObj:IsA("Accessory") and partObj:FindFirstChild("Handle")) then continue end
				partObj = partObj.Handle
				partObj.CFrame = partObj.CFrame:Lerp(
					(CFrame.new(position) *
					CFrame.fromOrientation(unpackOrientation(orientation))),
					math.min(accumulatedRecieveTime / (240 / 60), 1)
				)
			end
		end
	end
end)

-- character updates
table.insert(connections, runService.Stepped:Connect(function()
	if not (character and humanoid) then return end
	if not rateCheck("charUpdate", serverConfig.characterUpdateHz) then return end

	local packetBuffer, bufferFinish = createPacketBuffer("ID_CHAR_UPDATE")

	packetBuffer.writeString(player.Name)

	packetBuffer.writeInt8(#characterParts) -- count of character parts
	for _, partName in characterParts do
		local object = character:FindFirstChild(partName)
		if not (object and object:IsA("BasePart")) then continue end
		packetBuffer.writeString(object.Name) -- name
		packetBuffer.writeVector3(object.Position)
		packetBuffer.writeVector3(object.Orientation)
	end

	local accessories = humanoid:GetAccessories()
	packetBuffer.writeInt8(#accessories) -- count of accessories
	for _, accessory in accessories do
		if not accessory:FindFirstChild("Handle") then continue end
		packetBuffer.writeString(accessory.Name) -- name
		packetBuffer.writeVector3(accessory.Handle.Position)
		packetBuffer.writeVector3(accessory.Handle.Orientation)
	end

	wsObj:Send("data_send", bufferFinish())
end))

-- keepalive ping
table.insert(connections, runService.Heartbeat:Connect(function()
	if not rateCheck("ping", 1) then return end

	pingStartTime = os.clock()
	wsObj:Send("ping")
end))

-- chat send
table.insert(connections, player.Chatted:Connect(function(chatMsg)
	if (chatService.BubbleChatEnabled and config.chatBubbleEnabled) then chatService:Chat(character, chatMsg, Enum.ChatColor.White) end
	local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_CHATTED")

	packetBuffer.writeString(player.Name)
	packetBuffer.writeString(chatMsg)

	wsObj:Send("data_send", bufferFinish())
end))

-- character collision
table.insert(connections, runService.Stepped:Connect(function()
	for _, plrChar in connectedPlrChars do
		for _, part in plrChar:GetChildren() do
			part = (
				if (part:IsA("BasePart") and table.find(characterParts, part.Name)) then
					part
				elseif (part:IsA("Accessory") and part:FindFirstChild("Handle")) then
					part.Handle
				else nil
			)

			if not part then continue end
			part.CanCollide = (
				if config.collidableCharacters and
					(not part.Parent:IsA("Accessory")) and
					(not table.find(characterLimbParts, part.Name))
				then
					true
				else
					false
			)
		end
	end
end))

-- server disconnection
table.insert(connections, game.Close:Connect(disconnectToServer))

-- ui
local clientIDTextBounds, serverURLTextBounds = getTextSize(debugUI.ClientID), getTextSize(debugUI.ServerURL)
local textBoundsX = (
	if clientIDTextBounds.X < serverURLTextBounds.X then
		serverURLTextBounds.X
	else
		clientIDTextBounds.X
)
debugUI.Size = UDim2.fromOffset(textBoundsX + 10, 80)

table.insert(connections, inputService.InputBegan:Connect(function(input, gameProccessed)
	if input.UserInputType == Enum.UserInputType.Keyboard and (not inputService:GetFocusedTextBox()) then
		if inputService:IsKeyDown(Enum.KeyCode.LeftControl) and
			inputService:IsKeyDown(Enum.KeyCode.LeftShift)
		then
			if input.KeyCode == Enum.KeyCode.F8 then
				debugUI.Visible = not debugUI.Visible
			end
		end
	end
end))