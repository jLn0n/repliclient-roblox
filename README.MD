# Repliclient

<i>Client replication for other clients</i>

Note: This is still on beta stage, so expect bugs!  
Also join our discord server by clicking this link: https://discord.gg/NsY3maz7dj  

<details>
    <summary>CLICK ME!!</summary>
    <br>
    <p>
        This is the websocket version, you can only connect to websocket-based server.<br>
        If you wanna use the long-polling version, <a href="https://github.com/jLn0n/repliclient-roblox/tree/long-polling">click this link</a>.
    </p>
</details>

## Script

```lua
local config = {
    -- server
    socketUrl = "ws://eu-repliclient-ws.herokuapp.com/",

    -- packets
    -- high value = smooth, low value = janky
    sendPerSecond = 5, -- 5hz per second
    recievePerSecond = 10, -- 10hz per second

    -- misc
    chatBubble = false,
    collidableCharacters = true,
}
loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/jLn0n/repliclient-roblox/websocket/init.lua"))("pump sheshin'", config)
```