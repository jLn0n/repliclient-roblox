-- variables
local http_request = (syn and syn.request) or (http and http.request) or request or http_request

-- functions
getgenv().import = function(path, branch)
	branch = (branch or "websocket")
	local result, cloudSrc

	if (DEV_MODE) then
		result = {Success = true}
	else
		result = http_request({
			Url = string.format("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/%s/%s", branch, path),
			Method = "GET",
			Headers = {
				["Content-Type"] = "text/html; charset=utf-8",
			}
		})
	end

	if result.Success then
		cloudSrc = result.Body
		local sepPath = string.split(path, "/")
		local currentPath = "repliclient"

		for pathIndex, pathStr in sepPath do
			if pathIndex == #sepPath then
				currentPath ..= "/" .. pathStr
				local origSrc = isfile(currentPath) and readfile(currentPath) or ""

				if (origSrc ~= cloudSrc) and not DEV_MODE then
					writefile(currentPath, cloudSrc)
				elseif DEV_MODE then
					cloudSrc = (origSrc or cloudSrc)
				end
			else
				currentPath ..= "/" .. pathStr
				if not isfolder(currentPath) then makefolder(currentPath) end
			end
		end
	else
		return error(string.format("Cannot get '%s' with branch '%s' from the repository.", path, branch))
	end
	return loadstring(cloudSrc, "@repliclient/" .. path)
end

local identifyexecutor = (identifyexecutor or function()
	return "Unknown Executor"
end)
-- main
if string.find(identifyexecutor(), "Synapse") then
	local luauVM = import("src-synapse/luau-vm")
	local mainBytecode = game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/src-synapse/main.bin")

	luauVM.wrap_proto(luauVM.luau_load(mainBytecode))(...)
else
	import("src/main.lua")(...)
end