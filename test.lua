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
getgenv().Config = {
    Webhook = {
        URL = "DIN_WEBHOOK_HÄR",
        PingID = nil,
        UpdateIntervalHours = 24 -- antal timmar mellan 24h notiser
    }
}

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

local function CountSpecialPets()
    local pets = SaveMod.Get()['Inventory']['Pet'] or {}
    local huge, titanic = 0, 0
    for _, pet in pairs(pets) do
        if string.find(pet.id, "Titanic") then
            titanic += 1
        elseif string.find(pet.id, "Huge") then
            huge += 1
        end
    end
    return huge, titanic
end

-- == DIAMOND TRACKING == --
local diamondHistory = {
    last24h = os.time(),
    diamondAmount = GetDiamonds()
}

-- == SEND INVENTORY SUMMARY == --
local function SendInventoryWebhook()
    local diamonds = GetDiamonds()
    local diamondDiff = diamonds - (diamondHistory.diamondAmount or diamonds)
    local huge, titanic = CountSpecialPets()

    local descriptionLines = {
        string.format("**%s har just nu:**", LocalPlayer.Name),
        "```",
        string.format("%-15s = %s%s", "💎 Diamonds", Formatint(diamonds), diamondDiff > 0 and string.format(" (+%s)", Formatint(diamondDiff)) or ""),
        string.format("%-15s = %d", "🐾 Huge", huge),
        string.format("%-15s = %d", "🐾 Titanic", titanic),
        "```",
        string.format("\n**Username: ||%s||**", LocalPlayer.Name)
    }

    -- Kolla om 24h har gått
    local now = os.time()
    local hoursPassed = (now - diamondHistory.last24h) / 3600
    if hoursPassed >= getgenv().Config.Webhook.UpdateIntervalHours then
        table.insert(descriptionLines, string.format("\n**⏳ På %d timmar: 💎 %s**", getgenv().Config.Webhook.UpdateIntervalHours, Formatint(diamondDiff)))
        diamondHistory.last24h = now
        diamondHistory.diamondAmount = diamonds
    end

    local embed = {
        title = "💎 **Gem Inventory Update** 💎",
        description = table.concat(descriptionLines, "\n"),
        color = 0xFF00FF,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = "https://cdn.discordapp.com/attachments/1350797858240204810/1357324447996051526/8355-moon.png"
        },
        footer = {
            text = string.format("discord.gg/projectlunar | 🌙 | Next update: %d timmar", getgenv().Config.Webhook.UpdateIntervalHours)
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

-- == MAIN LOOP == --
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

task.spawn(function()
    while true do
        SendInventoryWebhook()
        task.wait(60 * 60) -- kör var timme (kan ändras)
    end
end)
