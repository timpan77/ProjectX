-- == SERVICES == --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Library = ReplicatedStorage:WaitForChild("Library")
local Client = Library.Client
local SaveMod = require(Client.Save)
local Network = require(Client.Network)

-- == CONFIG == --
getgenv().Config = getgenv().Config or {}
getgenv().Config.Webhook = getgenv().Config.Webhook or {}
getgenv().Config.Webhook.UpdateIntervalMinutes = getgenv().Config.Webhook.UpdateIntervalMinutes or 10
getgenv().Config.Webhook.Diamonds24hIntervalHours = getgenv().Config.Webhook.Diamonds24hIntervalHours or 24

-- == UTILS == --
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

local function CountPets()
    local pets = SaveMod.Get()['Inventory']['Pet'] or {}
    local huge, titanic = 0, 0
    for _, pet in pairs(pets) do
        if string.find(pet.id, "Huge") then huge += 1 end
        if string.find(pet.id, "Titanic") then titanic += 1 end
    end
    return huge, titanic
end

-- == DIAMOND TRACKER == --
local last24hDiamonds = GetDiamonds()
local last24hUpdate = os.time()

-- == SEND WEBHOOK == --
local function SendInventoryWebhook()
    local diamondAmount = GetDiamonds()
    local hugeCount, titanicCount = CountPets()
    local diamondDifference = diamondAmount - last24hDiamonds
    local now = os.time()

    local descriptionLines = {
        string.format("**%s har just nu:**", LocalPlayer.Name),
        "```",
        string.format("%-15s = %s%s", "💎 Diamonds", Formatint(diamondAmount), diamondDifference > 0 and string.format(" (+%s)", Formatint(diamondDifference)) or ""),
        string.format("%-15s = %d", "🐾 Huge", hugeCount),
        string.format("%-15s = %d", "🐾 Titanic", titanicCount),
        "```",
        string.format("\n**Username: ||%s||**", LocalPlayer.Name)
    }

    -- Only include 24h change if it's time
    if now - last24hUpdate >= getgenv().Config.Webhook.Diamonds24hIntervalHours * 3600 then
        table.insert(descriptionLines, string.format("```%-15s = %s```", "24h Change", Formatint(diamondDifference)))
        last24hDiamonds = diamondAmount
        last24hUpdate = now
    end

    local mainEmbed = {
        title = "💎 **Gem Inventory Update** 💎",
        description = table.concat(descriptionLines, "\n"),
        color = 0xFF00FF,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = "https://cdn.discordapp.com/attachments/1350797858240204810/1357324447996051526/8355-moon.png"
        },
        footer = {
            text = string.format("discord.gg/projectlunar | 🌙 | Next update: %d min | 24h-check varje %d h", getgenv().Config.Webhook.UpdateIntervalMinutes, getgenv().Config.Webhook.Diamonds24hIntervalHours)
        }
    }

    local body = HttpService:JSONEncode({
        content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
        embeds = { mainEmbed }
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

-- == MAIN LOOP == --
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

task.spawn(function()
    while true do
        SendInventoryWebhook()
        task.wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
    end
end)
