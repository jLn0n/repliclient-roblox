# Repliclient

<i>Client replication for other clients</i>

Note: This is still on development, so expect bugs!  
Also join our discord server by clicking this link: https://discord.gg/NsY3maz7dj  

## Script

```lua
local config = {
	-- server
	serverUrl = "wss://repliclient-server.jlnn0n.repl.co",

	-- misc
	chatBubble = false,
	collidableCharacters = true,
}
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/loader.lua"))("lmao", config)
```
