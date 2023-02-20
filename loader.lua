-- variables
local http_request = (syn and syn.request) or (http and http.request) or request or http_request
local wrapperEnv = table.create(0)
-- functions
local function wrapFuncGlobal(func, customFenv)
	customFenv = customFenv or table.create(0)
	local fenvCache = getfenv(0)
	local fenv = setmetatable(table.create(0), {
		__index = function(_, index)
			return customFenv[index] or fenvCache[index]
		end,
		__newindex = function(_, index, value)
			customFenv[index] = value
		end
	})

	return setfenv(func, fenv)
end

local function import(path, branch)
	branch = (branch or "websocket")
	local result = (
		if wrapperEnv.DEV_MODE then
			{Success = true}
		else
			http_request({
				Url = string.format("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/%s/%s", branch, path),
				Method = "GET",
				Headers = {
					["Content-Type"] = "text/html; charset=utf-8",
				}
			})
	)
	local srcFile = (if result.Success then result.Body else nil)
	local sepPath = string.split(path, "/")
	local currentPath = "repliclient"

	for pathIndex, pathStr in sepPath do
		if pathIndex == #sepPath then
			currentPath ..= ("/" .. pathStr)
			local localSrcFile = (if isfile(currentPath) then readfile(currentPath) else nil)

			if (wrapperEnv.DEV_MODE or not result.Success) then -- if DEV_MODE or file fetch failed then we load local file
				if localSrcFile then
					srcFile = localSrcFile
					warn(string.format("Loading local file '%s'.", path))
				else
					warn(string.format("Failed to load `%s` of branch `%s` from the repository.", path, branch))
				end
			else -- loads the fetched file online
				if (localSrcFile ~= srcFile) then
					writefile(currentPath, srcFile)
				end
			end
		else
			currentPath ..= ("/" .. pathStr)
			if not isfolder(currentPath) then makefolder(currentPath) end
		end
	end
	return wrapFuncGlobal(loadstring(srcFile, "@repliclient/" .. path), wrapperEnv)
end
-- main
do -- environment init
	wrapperEnv["import"] = import
	wrapperEnv["DEV_MODE"] = DEV_MODE
end

import("src/main.lua")(...)
