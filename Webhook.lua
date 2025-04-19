local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Pets = require(ReplicatedStorage.Shared.Data.Pets)
local LocalDataService = require(ReplicatedStorage.Client.Framework.Services.LocalData) 

local LegendaryPets = {}


local function convertToShorter(number, type)
    print("[DEBUG] convertToShorter - Input:", number, "Type:", type)
    if type == "seconds" then
        local hours = math.floor(number / 3600)
        local minutes = math.floor((number % 3600) / 60)
        local seconds = number % 60
        local result = hours .. "h " .. minutes .. "m " .. seconds .. "s"
        print("[DEBUG] convertToShorter - Result:", result)
        return result
    end

    if type == "hatches" then
        local result = string.format("%.2fk", number / 1000)
        print("[DEBUG] convertToShorter - Result:", result)
        return result
    end

    if type == "bubbles" then
        local result
        if number < 1000000 then
            result = number
        elseif number < 1000000000 then
            result = string.format("%.2fm", number / 1000000)
        else
            result = string.format("%.2fb", number / 1000000000)
        end
        print("[DEBUG] convertToShorter - Result:", result)
        return result
    end
end

local function getStats()
    print("[DEBUG] getStats - Starting")
    local playerData = LocalDataService:Get()
    print("[DEBUG] getStats - PlayerData:", playerData)
    
    local gems = playerData.Gems
    local Pets = playerData.Pets
    local Stats = playerData.Stats
    print("[DEBUG] getStats - Raw values - Gems:", gems, "Pets:", Pets, "Stats:", Stats)

    local totalPets = 0
    local totalEggsOpened = 0

    for i,v in pairs(Pets) do
        print("[DEBUG] getStats - Processing pet:", i, "Data:", v)
        local amount = v.Amount or 0
        totalPets = totalPets + amount
        print("[DEBUG] getStats - Current total:", totalPets)
    end

    local playTimeInSeconds = Stats.Playtime or 0
    local hatches = Stats.Hatches or 0
    local bubbles = Stats.Bubbles or 0
    print("[DEBUG] getStats - Raw stats - Playtime:", playTimeInSeconds, "Hatches:", hatches, "Bubbles:", bubbles)

    local playTime = convertToShorter(playTimeInSeconds, "seconds")
    local hatches = convertToShorter(hatches, "hatches")
    local bubbles = convertToShorter(bubbles, "bubbles")
    
    local result = {
        playTime = playTime,
        hatches = hatches,
        bubbles = bubbles
    }
    print("[DEBUG] getStats - Final result:", result)
    return result
end


local function getImageThumbnail(assetId)
    local assetIdNumber = assetId:match("rbxassetid://(%d+)")
    if not assetIdNumber then return nil end
    
    local url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetIdNumber .. "&size=420x420&format=png&isCircular=false"
    
    local request = http_request or request or HttpPost or syn.request
    local headers = {
        ["Content-Type"] = "application/json"
    }
    local abcdef = {Url = url, Method = "GET", Headers = headers}
    local success, result = pcall(function()
        return request(abcdef).Body
    end)
    
    if success then
        local data = HttpService:JSONDecode(result)
        if data and data.data and data.data[1] and data.data[1].imageUrl then
            return data.data[1].imageUrl
        end
    end
    
    return nil
end

for name, pet in pairs(Pets) do
    for i,v in pairs(pet) do
        if i == "Rarity" and v == "Legendary" then
            table.insert(LegendaryPets, name)
        end
    end
end

local WebhookHandler = {}
WebhookHandler.__index = WebhookHandler

function WebhookHandler.new()
    local self = setmetatable({}, WebhookHandler)
    self.remoteEvent = ReplicatedStorage.Shared.Framework.Network.Remote.Event
    self.webhookUrl = getgenv().Settings.Notifications.Webhook
    print("[DEBUG] WebhookHandler.new - Initialized with URL:", self.webhookUrl)
    self:initialize()
    return self
end

function WebhookHandler:initialize()
    self.remoteEvent.OnClientEvent:Connect(function(...)
        self:handleEvent(...)
    end)
end

function WebhookHandler:handleEvent(...)
    local eventArgs = {...}
    
    if eventArgs[1] == "HatchEgg" and typeof(eventArgs[2]) == "table" then
        self:processHatchEggEvent(eventArgs[2])
    end
    
    self:logAllArguments(eventArgs)
end

function WebhookHandler:processHatchEggEvent(hatchData)
    if typeof(hatchData.Pets) == "table" then
        self:processPets(hatchData.Pets)
    end
end

function WebhookHandler:processPets(pets)
    for i, pet in ipairs(pets) do
        if typeof(pet) == "table" then
            self:processPetData(pet)
        end
    end
end

function WebhookHandler:processPetData(pet)
    for petKey, petValue in pairs(pet) do
        if petKey == "Pet" and typeof(petValue) == "table" then
            self:checkLegendaryPet(petValue)
        end
    end
end

function WebhookHandler:checkLegendaryPet(petData)
    if petData.Name and typeof(petData.Name) == "string" and table.find(LegendaryPets, petData.Name) then
        print(petData.Name)
        self:sendWebhook(petData)
    end
end

function WebhookHandler:getPetStats(petName)
    local petInfo = Pets[petName]
    if not petInfo or not petInfo.Stats then return nil end
    
    local stats = {}
    for stat, value in pairs(petInfo.Stats) do
        table.insert(stats, {
            name = stat,
            value = tostring(value)
        })
    end
    
    return stats
end

function WebhookHandler:sendWebhook(petData)
    print("[DEBUG] sendWebhook - Starting with petData:", petData)
    local petInfo = Pets[petData.Name]
    print("[DEBUG] sendWebhook - PetInfo:", petInfo)
    if not petInfo then 
        print("[DEBUG] sendWebhook - No pet info found, returning")
        return 
    end
    
    local imageUrl = nil
    if petInfo.Images and petInfo.Images.Normal then
        print("[DEBUG] sendWebhook - Getting image thumbnail for:", petInfo.Images.Normal)
        imageUrl = getImageThumbnail(petInfo.Images.Normal)
        print("[DEBUG] sendWebhook - Image URL:", imageUrl)
    end
    
    local playerName = game.Players.LocalPlayer.Name
    local playerData = LocalDataService:Get()
    print("[DEBUG] sendWebhook - Player data:", playerData)
    
    local petName = petData.Name
    local petRarity = petInfo.Rarity or "Unknown"
    local isShiny = petData.Shiny and "Yes" or "No"
    print("[DEBUG] sendWebhook - Pet details - Name:", petName, "Rarity:", petRarity, "Shiny:", isShiny)
    
    -- Get player stats
    local stats = getStats()
    local gems = playerData.Gems or 0
    local totalPets = 0
    print("[DEBUG] sendWebhook - Processing pets for total count")
    for i,v in pairs(playerData.Pets or {}) do
        print("[DEBUG] sendWebhook - Processing pet:", i, "Data:", v)
        totalPets = totalPets + (v.Amount or 0)
        print("[DEBUG] sendWebhook - Current total:", totalPets)
    end
    
    print("[DEBUG] sendWebhook - Final stats - Gems:", gems, "Total Pets:", totalPets)
    print("[DEBUG] sendWebhook - Stats from getStats:", stats)
    
    local embedColor = 0xFF9900
    
    local embed = {
        title = "Legendary Pet Hatched!",
        description = playerName .. " hatched a legendary pet!",
        color = embedColor,
        fields = {
            {
                name = "Pet Name",
                value = petName,
                inline = true
            },
            {
                name = "Rarity",
                value = petRarity,
                inline = true
            },
            {
                name = "Shiny",
                value = isShiny,
                inline = true
            },
            {
                name = "Player Stats",
                value = string.format("Gems: %s\nTotal Pets: %s\nPlaytime: %s\nHatches: %s\nBubbles: %s", 
                    convertToShorter(gems, "bubbles"),
                    convertToShorter(totalPets, "hatches"),
                    stats.playTime,
                    stats.hatches,
                    stats.bubbles),
                inline = false
            }
        },
        footer = {
            text = "BGSInfinity by ProjectX •" .. os.date("%Y-%m-%d %H:%M:%S")
        }
    }
    
    if petInfo.Stats then
        local statsText = ""
        for stat, value in pairs(petInfo.Stats) do
            statsText = statsText .. stat .. ": " .. tostring(value) .. "\n"
        end
        
        table.insert(embed.fields, {
            name = "Pet Stats",
            value = statsText,
            inline = false
        })
    end
    
    if imageUrl then
        embed.thumbnail = {
            url = imageUrl
        }
    end
    
    local data = {
        username = "Legendary Pet Notifier",
        avatar_url = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. game.Players.LocalPlayer.UserId .. "&width=420&height=420&format=png",
        embeds = {embed}
    }
    
    print("[DEBUG] sendWebhook - Preparing to send webhook with data:", data)
    
    local jsonData = HttpService:JSONEncode(data)
    print("[DEBUG] sendWebhook - JSON data prepared")
    
    local request = http_request or request or HttpPost or syn.request
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    local requestData = {
        Url = self.webhookUrl,
        Method = "POST",
        Headers = headers,
        Body = jsonData
    }
    
    print("[DEBUG] sendWebhook - Sending request to:", self.webhookUrl)
    
    local success, response = pcall(function()
        return request(requestData)
    end)
    
    if success then
        print("[DEBUG] sendWebhook - Request successful, response:", response)
    else
        print("[DEBUG] sendWebhook - Request failed, error:", response)
    end
end

function WebhookHandler:logAllArguments(args)
    for i, arg in ipairs(args) do
        print(i, typeof(arg), arg)
    end
end

local webhookHandler = WebhookHandler.new()
