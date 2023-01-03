local I2L = {};

-- mainUI
I2L["1"] = Instance.new("Frame", game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"));
I2L["1"]["BackgroundColor3"] = Color3.fromRGB(19, 19, 19);
I2L["1"]["AnchorPoint"] = Vector2.new(0, 1);
I2L["1"]["BackgroundTransparency"] = 0.85;
I2L["1"]["Size"] = UDim2.new(0, 300, 0, 80);
I2L["1"]["BorderColor3"] = Color3.fromRGB(255, 255, 255);
I2L["1"]["Position"] = UDim2.new(0, 1, 1, -1);
I2L["1"]["Visible"] = false;
I2L["1"]["Name"] = [[mainUI]];

-- mainUI.Version
I2L["2"] = Instance.new("TextLabel", I2L["1"]);
I2L["2"]["TextStrokeTransparency"] = 0;
I2L["2"]["TextXAlignment"] = Enum.TextXAlignment.Left;
I2L["2"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
I2L["2"]["FontFace"] = Font.new([[rbxasset://fonts/families/RobotoMono.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
I2L["2"]["TextSize"] = 18;
I2L["2"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
I2L["2"]["Size"] = UDim2.new(1, -5, 0, 20);
I2L["2"]["Text"] = [==[Repliclient [v${version}]]==];
I2L["2"]["Name"] = [[Version]];
I2L["2"]["Font"] = Enum.Font.RobotoMono;
I2L["2"]["BackgroundTransparency"] = 1;
I2L["2"]["Position"] = UDim2.new(0, 5, 0, 0);

-- mainUI.ServerPing
I2L["3"] = Instance.new("TextLabel", I2L["1"]);
I2L["3"]["TextStrokeTransparency"] = 0;
I2L["3"]["TextXAlignment"] = Enum.TextXAlignment.Left;
I2L["3"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
I2L["3"]["FontFace"] = Font.new([[rbxasset://fonts/families/RobotoMono.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
I2L["3"]["TextSize"] = 18;
I2L["3"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
I2L["3"]["Size"] = UDim2.new(1, -5, 0, 20);
I2L["3"]["Text"] = [[Ping: ${latency}ms]];
I2L["3"]["Name"] = [[ServerPing]];
I2L["3"]["Font"] = Enum.Font.RobotoMono;
I2L["3"]["BackgroundTransparency"] = 1;
I2L["3"]["Position"] = UDim2.new(0, 5, 0, 20);

-- mainUI.ClientID
I2L["4"] = Instance.new("TextLabel", I2L["1"]);
I2L["4"]["TextStrokeTransparency"] = 0;
I2L["4"]["TextXAlignment"] = Enum.TextXAlignment.Left;
I2L["4"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
I2L["4"]["FontFace"] = Font.new([[rbxasset://fonts/families/RobotoMono.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
I2L["4"]["TextSize"] = 18;
I2L["4"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
I2L["4"]["Size"] = UDim2.new(1, -5, 0, 20);
I2L["4"]["Text"] = [[Client ID: ${clientId}]];
I2L["4"]["Name"] = [[ClientID]];
I2L["4"]["Font"] = Enum.Font.RobotoMono;
I2L["4"]["BackgroundTransparency"] = 1;
I2L["4"]["Position"] = UDim2.new(0, 5, 0, 40);

-- mainUI.ServerURL
I2L["5"] = Instance.new("TextLabel", I2L["1"]);
I2L["5"]["TextStrokeTransparency"] = 0;
I2L["5"]["TextXAlignment"] = Enum.TextXAlignment.Left;
I2L["5"]["BackgroundColor3"] = Color3.fromRGB(255, 255, 255);
I2L["5"]["FontFace"] = Font.new([[rbxasset://fonts/families/RobotoMono.json]], Enum.FontWeight.Regular, Enum.FontStyle.Normal);
I2L["5"]["TextSize"] = 18;
I2L["5"]["TextColor3"] = Color3.fromRGB(255, 255, 255);
I2L["5"]["Size"] = UDim2.new(1, -5, 0, 20);
I2L["5"]["Text"] = [[Server URL: ${serverUrl}]];
I2L["5"]["Name"] = [[ServerURL]];
I2L["5"]["Font"] = Enum.Font.RobotoMono;
I2L["5"]["BackgroundTransparency"] = 1;
I2L["5"]["Position"] = UDim2.new(0, 5, 0, 60);

return I2L["1"], {
	["Version"] = "Repliclient [v%s]",
	["ServerPing"] = "Ping: %.2fms | %s",
	["ClientID"] = "Client ID: `%s`",
	["ServerURL"] = "Server URL: `%s`"
}