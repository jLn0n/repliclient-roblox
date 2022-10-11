--[[
	TODO: (not in order)
	#1 DONE: reduce the bandwidth, and use some shenanigans
	#2 DONE: add packet delay
	#3 DONE: fix the flickering of character parts on some cases
	#4 DONE: host a personal server because yes
	#5 DONE: add a id for packet comms (for better packet handling)
	#6 DONE: rewrite the networking code and make it like the roblox ones
	#7: change the name (repliclient kinda sucks)
	#8 DONE: fix character being cloned so many times
	#9: add a thing for handling instance replication (i got no idea on how to do that, and i dont want to sacrifice performance)
	#10: fix a rare case when the packet "ID_CHAR_UPDATE" errors causing delays
	#11 DONE: fix already connected client not showing the character to newly connected client
	#12: centralize the server instead of running on clients
	#13: make character limbs uncollidable
	#14: fix erroring when reconnecting
	#15: publish the script to public use
--]]
-- initialization
local version = "1.0.0"

local config do
	local loadedConfig = select(2, ...)
	local isATable = (typeof(loadedConfig) == "table")
	loadedConfig = (if isATable then loadedConfig else table.create(0))
	
	if not isATable then warn("[REPLICLIENT]: Failed to load configuration, loading default...") end

	loadedConfig.socketUrl = (if not loadedConfig.socketUrl then "ws://eu-repliclient-ws.herokuapp.com" else loadedConfig.socketUrl)
	loadedConfig.sendPerSecond = (if typeof(loadedConfig.sendPerSecond) ~= "number" then 5 else loadedConfig.sendPerSecond)
	loadedConfig.recievePerSecond = (if typeof(loadedConfig.recievePerSecond) ~= "number" then 10 else loadedConfig.recievePerSecond)
	
	loadedConfig.chatBubble = (if typeof(loadedConfig.chatBubble) ~= "boolean" then false else loadedConfig.chatBubble)
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
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local starterGui = game:GetService("StarterGui")
-- objects
local player = players.LocalPlayer
local character = player.Character
local humanoid = character.Humanoid
local characterTemplate = game:GetObjects("rbxassetid://6843243348")[1]
-- libraries
local bitBuffer = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Dekkonot/bitbuffer/main/src/roblox.lua"))()
local base64 = loadstring(game:HttpGetAsync("https://gist.githubusercontent.com/Reselim/40d62b17d138cc74335a1b0709e19ce2/raw/fast_base64.lua"))()
local wsLib = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/src/utils/wslib.lua"))()
-- variables
local accumulatedRecieveTime = 0
local socketObj = wsLib.new(config.socketUrl)
local connections, refs = table.create(10), table.create(0)
local connectedPlrs, connectedPlrChars = table.create(0), table.create(0)
local userIdCache = table.create(0)
local rateInfos = table.create(0)
local characterParts = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg", "HumanoidRootPart"}
local characterLimbParts = {"Left Arm", "Right Arm", "Left Leg", "Right Leg"}
local replicationIDs = {
	--["ID_TEMPLATE"] = 0x000,
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
	local packetBuffer, packetPayload = bitBuffer(), "\26|" -- payload starts with arrowleft character with a seperator

	packetBuffer.writeInt16(replicationIDs[packetId])

	local function bufferFinish()
		packetPayload ..= packetBuffer.dumpBase64()
		return packetPayload
	end

	return packetBuffer, bufferFinish
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

local function rateCheck(name, rate)
	rate /= 10
	rateInfos[name] = (if not rateInfos[name] then {
		["lastTime"] = -1,
	} else rateInfos[name])
	local rateInfo = rateInfos[name]

	if rateInfo.lastTime == -1 then
		-- initializes rateInfo
		rateInfo.lastTime = os.time()

		return true
	else
		rateInfo.lastTime = (rateInfo.lastTime or os.clock())
		local timeElapsed = os.time() - rateInfo.lastTime

		if timeElapsed >= (1 / rate) then
			rateInfo.lastTime = os.clock()

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

local function disconnectToSocket()
	local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_REMOVE")

	packetBuffer.writeString(player.Name)
	socketObj:Send(bufferFinish())

	for index, connection in connections do
		connection:Disconnect()
		table.remove(connections, index)
	end
end

local function unpackOrientation(vectRot, dontUseRadians)
	vectRot = (if not dontUseRadians then vectRot * (math.pi / 180) else vectRot)
	return vectRot.X, vectRot.Y, (if typeof(vectRot) == "Vector2" then 0 else vectRot.Z)
end
-- main
if not socketObj then return warn(string.format("Failed to connect to '%s'. This might happen because server is closed or unreachable.", config.socketUrl)) end
if humanoid.RigType ~= Enum.HumanoidRigType.R6 then return warn("Repliclient currently only support R6 characters.") end

-- post initialization
task.defer(function()
	-- letting the other clients to know that self joined
	local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_ADD")

	packetBuffer.writeString(player.Name)
	socketObj:Send(bufferFinish())
	refs["ID_PLR_ADD-bufferCache"] = bufferFinish
	print(string.format("\n|  Repliclient - v%s\n|  Server URL: `%s`\n|  Host: `%s`", version, config.socketUrl, identifyexecutor()))
end)

refs.oldIndex = hookmetamethod(game, "__index", function(...)
	local self, index = ...

	-- returns the connected player when called from exploit environment, returns nil if not
	if checkcaller() then
		if self == players and connectedPlrs[index] then
			return connectedPlrs[index]
		elseif (self:IsA("Player") and connectedPlrs[tostring(self)]) and index == "Parent" then -- self.Name causes C stack overflow
			return players
		end
	end
	return refs.oldIndex(...)
end)

-- packet reciever
socketObj:AddMessageCallback(function(message)
	if not rateCheck("recieve", config.recievePerSecond) then return end
	accumulatedRecieveTime = runService.Stepped:Wait()

	if string.sub(message, 1, 1) == "\26" then
		message = string.sub(message, 3, #message) -- removes "\26|"
		local succ, packetBuffer = pcall(function()
			return bitBuffer(base64.decode(message))
		end)
		if not succ then return warn("Failed to parse data recieved:\n", message) end

		local packetId = packetBuffer.readInt16()

		if packetId == replicationIDs["ID_PLR_ADD"] then
			local plrName = packetBuffer.readString()

			if (player.Name ~= plrName) then
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

				socketObj:Send(refs["ID_PLR_ADD-bufferCache"]()) -- kinda hacky I think, fixes TODO #11
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
	end
end)

-- packet data sender
table.insert(connections, runService.Stepped:Connect(function()
	if not (character and humanoid) then return end
	if not rateCheck("send", config.sendPerSecond) then return end

	local packetBuffer, bufferFinish = createPacketBuffer("ID_CHAR_UPDATE")

	packetBuffer.writeString(player.Name) -- sender

	packetBuffer.writeInt8(#characterParts) -- count of character parts
	for _, partName in characterParts do
		local object = character:FindFirstChild(partName)
		if not object:IsA("BasePart") then continue end
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

	socketObj:Send(bufferFinish())
end))

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
			part.CanCollide = (if ((not config.collidableCharacters) or table.find(characterLimbParts, part.Name)) then false else true)
		end
	end
end))

table.insert(connections, player.Chatted:Connect(function(chatMsg)
	if chatService.BubbleChatEnabled then chatService:Chat(character, chatMsg, Enum.ChatColor.White) end
	local packetBuffer, bufferFinish = createPacketBuffer("ID_PLR_CHATTED")

	packetBuffer.writeString(player.Name)
	packetBuffer.writeString(chatMsg)

	socketObj:Send(bufferFinish())
end))

table.insert(connections, player.CharacterAdded:Connect(function(newChar)
	task.wait()
	character = newChar
	humanoid = newChar:FindFirstChild("Humanoid")
end))

table.insert(connections, game.Close:Connect(disconnectToSocket))