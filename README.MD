# Repliclient

<i>Client replication for other clients</i>

This is the websocket version, you can only connect to websocket-based server!  
If you wanna use the long-polling version, [click this link](https://github.com/jLn0n/repliclient-roblox/tree/long-polling).

## Script

```lua
local config = {
	-- server
	socketUrl = "ws://eu-repliclient-ws.herokuapp.com/",

	-- replication
	sendPerSecond = 5, -- 5 hertz per second
	recievePerSecond = 10, -- 10 hertz per second

	-- misc
	chatBubble = false,
	collidableCharacters = true,
}
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/init.lua"))("pump sheshin'", config)
```