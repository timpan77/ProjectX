local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Library = ReplicatedStorage.Library
local SaveMod = require(Library.Client.Save)
local player = Players.LocalPlayer
local playerName = player and player.Name or "Unknown Player"
local playerId = player and player.UserId or 0
local StoredUIDs = {}  -- För att hålla koll på tidigare Huge pets

local function IsPlayerConnected()
    local player = Players.LocalPlayer
    return player and player:IsDescendantOf(game)
end

local function GetPlayerAvatar(userId)
    return string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", userId)
end

-- Funktion för att hämta diamanter från leaderstats
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

-- Funktion för att kolla om nya Huge pets har lagts till
local function CheckForNewHugePets()
    local newHugePets = {}
    
    -- Kolla de pets vi redan har
    for i, v in pairs(SaveMod.Get()['Inventory']['Pet'] or {}) do
        if (string.find(v.id, "Huge") or string.find(v.id, "Titanic") or string.find(v.id, "Gargantuan")) then
            StoredUIDs[i] = true
        end
    end

    -- Lyssna efter uppdateringar på pets
    Network.Fired("Items: Update"):Connect(function(_, Inventory)
        if Inventory["set"] and Inventory["set"]["Pet"] then
            for uid, v in pairs(Inventory["set"]["Pet"]) do
                if (string.find(v.id, "Huge") or string.find(v.id, "Titanic") or string.find(v.id, "Gargantuan")) and not StoredUIDs[uid] then
                    -- Här skickar vi webhooken när en ny Huge pet har lagts till
                    table.insert(newHugePets, v)
                    StoredUIDs[uid] = true
                end
            end
        end
    end)

    return newHugePets
end

-- Skicka data till Webhooken
local function SendToWebhook(diamondAmount, newHugePets)
    local descriptionLines = {
        string.format("\n**Username: ||%s||**", playerName),
        "```",
        string.format("%-15s = %d", "💎 Diamonds", diamondAmount),
    }

    -- Lägg till Huge pets till webhookbeskrivningen
    if #newHugePets > 0 then
        table.insert(descriptionLines, "\n**New Huge Pets:**")
        for _, pet in pairs(newHugePets) do
            table.insert(descriptionLines, string.format("%-15s = %s", pet.id, pet.pt))
        end
    end

    table.insert(descriptionLines, "```")
    
    local embedColor = IsPlayerConnected() and 0x00FF00 or 0xFF0000
    
    local mainEmbed = {
        title = "💎 **Diamond & Pet Update** 💎",
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
    
    -- Lägg till spelarens avatar som footer-ikon
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

-- Kolla och skicka både diamanter och nya Huge pets
local function CheckAndNotifyDiamondsAndPets()
    local diamondAmount = GetDiamondsFromLeaderstats()
    local newHugePets = CheckForNewHugePets()
    
    print("\n=====Current Diamonds:=====")
    print(string.format("%-15s = %d", "💎 Diamonds", diamondAmount))
    
    if #newHugePets > 0 then
        print("\n=====New Huge Pets:=====")
        for _, pet in pairs(newHugePets) do
            print(string.format("%-15s = %s", pet.id, pet.pt))
        end
    end

    SendToWebhook(diamondAmount, newHugePets)
end

CheckAndNotifyDiamondsAndPets()
while true do
    wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
    CheckAndNotifyDiamondsAndPets()
end
