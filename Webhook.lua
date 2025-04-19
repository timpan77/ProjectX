local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local LocalDataService = require(ReplicatedStorage.Client.Framework.Services.LocalData) 

local LegendaryPets = {}

local function convertToShorter(number, type)
    if type == "seconds" then
        local hours = math.floor(number / 3600)
        local minutes = math.floor((number % 3600) / 60)
        local seconds = number % 60
        return hours .. "h " .. minutes .. "m " .. seconds .. "s"
    end
    if type == "hatches" then
        return string.format("%.2fk", number / 1000)
    end
    if type == "bubbles" then
        if number < 1_000_000 then
            return tostring(number)
        elseif number < 1_000_000_000 then
            return string.format("%.2fm", number / 1_000_000)
        else
            return string.format("%.2fb", number / 1_000_000_000)
        end
    end
end

local function getStats()
    local playerData = LocalDataService:Get()
    local gems = playerData.Gems
    local PetsData = playerData.Pets
    local Stats = playerData.Stats

    local totalPets = 0
    for _, v in pairs(PetsData) do
        totalPets = totalPets + (v.Amount or 0)
    end

    return {
        playTime = convertToShorter(Stats.Playtime or 0, "seconds"),
        hatches = convertToShorter(Stats.Hatches or 0, "hatches"),
        bubbles = convertToShorter(Stats.Bubbles or 0, "bubbles"),
        gems = convertToShorter(gems or 0, "bubbles"),
        totalPets = convertToShorter(totalPets or 0, "hatches"),
    }
end

local function getImageThumbnail(assetId)
    local assetIdNumber = assetId:match("rbxassetid://(%d+)")
    if not assetIdNumber then return nil end

    local url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetIdNumber .. "&size=420x420&format=png&isCircular=false"
    local request = http_request or request or HttpPost or syn.request
    local response = request({ Url = url, Method = "GET", Headers = {["Content-Type"] = "application/json"} })

    if response and response.Body then
        local data = HttpService:JSONDecode(response.Body)
        return data and data.data and data.data[1] and data.data[1].imageUrl or nil
    end
end

for name, pet in pairs(Pets) do
    if pet.Rarity == "Legendary" then
        table.insert(LegendaryPets, name)
    end
end

local WebhookHandler = {}
WebhookHandler.__index = WebhookHandler

function WebhookHandler.new()
    local self = setmetatable({}, WebhookHandler)
    self.remoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.Event
    self.webhookUrl = getgenv().Settings.Notifications.Webhook
    self:initialize()
    return self
end

function WebhookHandler:initialize()
    self.remoteEvent.OnClientEvent:Connect(function(...)
        self:handleEvent(...)
    end)
end

function WebhookHandler:handleEvent(...)
    local args = {...}
    if args[1] == "HatchEgg" and typeof(args[2]) == "table" then
        self:processHatchEggEvent(args[2])
    end
end

function WebhookHandler:processHatchEggEvent(hatchData)
    if typeof(hatchData.Pets) == "table" then
        for _, pet in ipairs(hatchData.Pets) do
            if pet.Pet and typeof(pet.Pet) == "table" then
                self:checkLegendaryPet(pet.Pet)
            end
        end
    end
end

function WebhookHandler:checkLegendaryPet(petData)
    if petData.Name and table.find(LegendaryPets, petData.Name) then
        self:sendWebhook(petData)
    end
end

function WebhookHandler:sendWebhook(petData)
    local petInfo = Pets[petData.Name]
    if not petInfo then return end

    local imageUrl = petInfo.Images and petInfo.Images.Normal and getImageThumbnail(petInfo.Images.Normal) or nil
    local player = game.Players.LocalPlayer
    local playerData = LocalDataService:Get()
    local stats = getStats()

    local embed = {
        title = "🎉 Legendary Pet Hatched!",
        description = player.Name .. " hatched a legendary pet!",
        color = 0xFF9900,
        fields = {
            { name = "🐾 Pet Name", value = petData.Name, inline = true },
            { name = "⭐ Rarity", value = petInfo.Rarity or "Unknown", inline = true },
            { name = "✨ Shiny", value = petData.Shiny and "Yes" or "No", inline = true },
            {
                name = "📊 Player Stats",
                value = string.format("Gems: %s\nTotal Pets: %s\nPlaytime: %s\nHatches: %s\nBubbles: %s",
                    stats.gems, stats.totalPets, stats.playTime, stats.hatches, stats.bubbles),
                inline = false
            },
        },
        footer = {
            text = "ProjectX-BGSInfinity by MajorX • " .. os.date("%Y-%m-%d %H:%M:%S")
        }
    }

    if petInfo.Stats then
        local statsText = ""
        for stat, value in pairs(petInfo.Stats) do
            statsText = statsText .. stat .. ": " .. tostring(value) .. "\n"
        end
        table.insert(embed.fields, {
            name = "📈 Pet Stats",
            value = statsText,
            inline = false
        })
    end

    if imageUrl then
        embed.thumbnail = { url = imageUrl }
    end

    local payload = {
        username = "Legendary Pet Notifier",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=420&height=420&format=png",
        embeds = {embed}
    }

    local requestData = {
        Url = self.webhookUrl,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(payload)
    }

    local request = http_request or request or HttpPost or syn.request
    pcall(function()
        request(requestData)
    end)
end

WebhookHandler.new()
