local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Library = ReplicatedStorage.Library
local SaveMod = require(Library.Client.Save)
local player = Players.LocalPlayer
local playerName = player and player.Name or "Unknown Player"
local playerId = player and player.UserId or 0

local function IsPlayerConnected()
    local player = Players.LocalPlayer
    return player and player:IsDescendantOf(game)
end

local function GetPlayerAvatar(userId)
    return string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", userId)
end

local function GetDiamondsFromLeaderstats()
    local diamondAmount = 0
    local leaderstats = player:FindFirstChild("leaderstats")
    
    if leaderstats then
        local diamondStat = leaderstats:FindFirstChild("💎 Diamonds")
        if diamondStat and diamondStat:IsA("IntValue") then
            diamondAmount = diamondStat.Value
        else
            warn("No 💎 Diamonds found in leaderstats.")
        end
    else
        warn("No leaderstats found.")
    end
    
    return diamondAmount
end

local function SendToWebhook(diamondAmount)
    local descriptionLines = {
        string.format("\n**Username: ||%s||**", playerName),
        "```",
        string.format("%-15s = %d", "💎 Diamonds", diamondAmount),
        "```"
    }
    
    local embedColor = IsPlayerConnected() and 0x00FF00 or 0xFF0000
    
    local mainEmbed = {
        title = "💎 **Diamond Inventory Update** 💎",
        description = table.concat(descriptionLines, "\n"),
        color = embedColor,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = "https://cdn.discordapp.com/attachments/1350797858240204810/1357324447996051526/8355-moon.png"
        },
        footer = {
            text = string.format("discord.gg/ProjectX | 🌙 | Next update: %d mins", getgenv().Config.Webhook.UpdateIntervalMinutes),
        }
    }
    
    -- Add player avatar as footer icon
    if player then
        mainEmbed.footer.icon_url = GetPlayerAvatar(playerId)
    end

    local success, err = pcall(function()
        local response = request({
            Url = getgenv().Config.Webhook.URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
                embeds = {mainEmbed}
            })
        })
        return response
    end)
    
    if not success then
        warn("Failed to send webhook:", err)
    end
end

local function CheckAndNotifyDiamonds()
    local diamondAmount = GetDiamondsFromLeaderstats()
    
    print("\n=====Current Diamonds:=====")
    print(string.format("%-15s = %d", "💎 Diamonds", diamondAmount))
    
    SendToWebhook(diamondAmount)
end

CheckAndNotifyDiamonds()
while true do
    wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
    CheckAndNotifyDiamonds()
end
