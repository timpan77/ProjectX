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

local function CountPetsByKeyword(keyword)
    local pets = SaveMod.Get()['Inventory']['Pet'] or {}
    local count = 0
    for _, pet in pairs(pets) do
        if string.find(pet.id, keyword) then
            count += 1
        end
    end
    return count
end

-- == Persistent Storage (for 24h diamond diff) == --
local stored24hData = {
    timestamp = os.time(),
    diamonds = GetDiamonds()
}

-- == SEND WEBHOOK == --
local function SendInventoryWebhook()
    local diamonds = GetDiamonds()
    local diamondDifference = diamonds - stored24hData.diamonds
    local hugeCount = CountPetsByKeyword("Huge")
    local titanicCount = CountPetsByKeyword("Titanic")

    local descriptionLines = {
        string.format("**Username: ||%s||**", LocalPlayer.Name),
        "**Have right now**",
        "```",
        string.format("%-15s = %s", "💎 Diamonds", Formatint(diamonds)),
        string.format("%-15s = %s", "⏳ 24h Diff", (diamondDifference >= 0 and "+" or "") .. Formatint(diamondDifference)),
        string.format("%-15s = %d", "🐾 Huge", hugeCount),
        string.format("%-15s = %d", "🐾 Titanic", titanicCount),
        "```",
    }

    local embed = {
        title = "📦 **Inventory Update** 📦",
        description = table.concat(descriptionLines, "\n"),
        color = 0xFF00FF,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = GetPlayerAvatar(LocalPlayer.UserId)
        },
        footer = {
            text = string.format("discord.gg/ProjectX | 🌙 | Next update: %d mins", getgenv().Config.Webhook.UpdateIntervalMinutes)
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

-- == 24H RESET CHECK == --
local function Update24hDataIfNeeded()
    local elapsed = os.time() - stored24hData.timestamp
    if elapsed >= 86400 then -- 24 timmar = 86400 sekunder
        stored24hData.timestamp = os.time()
        stored24hData.diamonds = GetDiamonds()
    end
end

-- == MAIN LOOP == --
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

task.spawn(function()
    while true do
        Update24hDataIfNeeded()
        SendInventoryWebhook()
        task.wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
    end
end)
