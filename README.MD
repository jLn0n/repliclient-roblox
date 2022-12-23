# Repliclient

<i>Client replication for other clients</i>

Note: This is still on development, so expect bugs!  
Also join our discord server by clicking this link: https://discord.gg/NsY3maz7dj  

## Script

```lua
local config = {
    -- server
    serverUrl = "ws://eu-repliclient-ws.herokuapp.com/",

    -- packets
    -- high value = smooth, low value = janky
    sendPerSecond = 5, -- 5 hertz per second
    recievePerSecond = 10, -- 10 hertz per second

    -- misc
    chatBubble = false,
    collidableCharacters = true,
}
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/loader.lua"))("pump sheshin'", config)
```
