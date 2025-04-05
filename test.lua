-- == SERVICES == --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Library = ReplicatedStorage:WaitForChild("Library")
local Client = Library.Client
local SaveMod = require(Client.Save)
local Network = require(Client.Network)

-- == UTILS == --
local function IsPlayerConnected()
    return LocalPlayer and LocalPlayer:IsDescendantOf(game)
end

local function GetPlayerAvatar(userId)
    return string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", userId)
end

local function Formatint(int)
    local Suffix = {"", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No"}
    local Index = 1
    while int >= 1000 and Index < #Suffix do
        int = int / 1000
        Index += 1
    end
    return string.format("%.2f%s", int, Suffix[Index])
end

local function GetDiamonds()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local diamonds = leaderstats:FindFirstChild("💎 Diamonds")
        if diamonds then
            return diamonds.Value
        end
    end
    return 0
end

local function CountSpecialPets()
    local pets = SaveMod.Get()['Inventory']['Pet'] or {}
    local hugeCount, titanicCount, gargantuanCount = 0, 0, 0
    for _, pet in pairs(pets) do
        if string.find(pet.id, "Huge") then
            hugeCount += 1
        elseif string.find(pet.id, "Titanic") then
            titanicCount += 1
        elseif string.find(pet.id, "Gargantuan") then
            gargantuanCount += 1
        end
    end
    return hugeCount, titanicCount, gargantuanCount
end

-- == SEND INVENTORY SUMMARY == --
local function SendInventoryWebhook()
    local diamonds = GetDiamonds()
    local hugeCount, titanicCount, gargantuanCount = CountSpecialPets()

    local diff = ""
    if lastDiamondCount ~= nil then
        local change = diamonds - lastDiamondCount
        if change ~= 0 then
            local sign = change > 0 and "+" or ""
            diff = string.format(" (%s%s)", sign, Formatint(change))
        end
    end
    lastDiamondCount = diamonds

    local embed = {
        title = "📦 Inventory Update",
        description = string.format("**%s har just nu:**\n```💎 Diamonds       = %s\n🐾 Huge/Titanics  = %d```", LocalPlayer.Name, Formatint(diamonds), specialCount),
        color = 0xFF00FF,  -- Samma färg som Huge
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = GetPlayerAvatar(LocalPlayer.UserId)
        },
        footer = {
            text = string.format("discord.gg/ProjectX | 🌙 | Uppdatering var %d min", getgenv().Config.Webhook.UpdateIntervalMinutes),
            icon_url = GetPlayerAvatar(LocalPlayer.UserId)
        }
    }

    local body = HttpService:JSONEncode({
        content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
        embeds = { embed }
    })

    pcall(function()
        request({
            Url = getgenv().Config.Webhook.URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)
end

-- == SEND NEW PET NOTIFICATION == --
local function SendNewHugeWebhook(pet)
    local assetId = "14976456685"
    pcall(function()
        local asset = require(Library.Directory.Pets)[pet.id]
        assetId = (pet.pt == 1 and asset.goldenThumbnail or asset.thumbnail):gsub("rbxassetid://", "") or assetId
    end)

    local petName = ""
    if pet.pt == 1 then petName = petName .. "🟡 Golden " end
    if pet.pt == 2 then petName = petName .. "🌈 Rainbow " end
    if pet.sh then petName = petName .. "✨ Shiny " end
    petName = petName .. pet.id

    local embed = {
        title = "🎉 Ny Huge/Titanic Fångad!",
        description = string.format("**%s** har fått en:\n```%s```", LocalPlayer.Name, petName),
        color = 0xFF00FF,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = "https://biggamesapi.io/image/" .. assetId
        },
        footer = {
            text = "discord.gg/ProjectX"
        }
    }

    local body = HttpService:JSONEncode({
        content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
        embeds = { embed }
    })

    pcall(function()
        request({
            Url = getgenv().Config.Webhook.URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body
        })
    end)
end

-- == TRACK NEW SPECIAL PETS == --
local StoredUIDs = {}

for uid, pet in pairs(SaveMod.Get()['Inventory']['Pet'] or {}) do
    if string.find(pet.id, "Huge") or string.find(pet.id, "Titanic") or string.find(pet.id, "Gargantuan") then
        StoredUIDs[uid] = true
    end
end

Network.Fired("Items: Update"):Connect(function(_, Inventory)
    if Inventory.set and Inventory.set.Pet then
        for uid, pet in pairs(Inventory.set.Pet) do
            if (string.find(pet.id, "Huge") or string.find(pet.id, "Titanic") or string.find(pet.id, "Gargantuan")) and not StoredUIDs[uid] then
                SendNewHugeWebhook(pet)
                StoredUIDs[uid] = true
            end
        end
    end
end)

-- == MAIN LOOP == --
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

task.spawn(function()
    while true do
        SendInventoryWebhook()
        task.wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
    end
end)
