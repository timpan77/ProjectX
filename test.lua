-- == SERVICES & GLOBALS == --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Library = ReplicatedStorage:WaitForChild("Library")
local Client = Library.Client
local SaveMod = require(Client.Save)
local Network = require(Client.Network)
local ExistCmds = require(Client.ExistCountCmds)
local StoredUIDs = {}

-- == UTILITIES == --
local function Formatint(int)
    local Suffix = {"", "k", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No", "De", "UDe", "DDe", "TDe"}
    local Index = 1
    while int >= 1000 and Index < #Suffix do
        int = int / 1000
        Index += 1
    end
    return string.format("%.2f%s", int, Suffix[Index])
end

local function GetAsset(Id, pt)
    local Asset = require(Library.Directory.Pets)[Id]
    return string.gsub(Asset and (pt == 1 and Asset.goldenThumbnail or Asset.thumbnail) or "14976456685", "rbxassetid://", "")
end

local function GetStats(Cmds, Class, ItemTable)
    return Cmds.Get({
        Class = { Name = Class },
        IsA = function(InputClass) return InputClass == Class end,
        GetId = function() return ItemTable.id end,
        StackKey = function()
            return HttpService:JSONEncode({id = ItemTable.id, sh = ItemTable.sh, pt = ItemTable.pt, tn = ItemTable.tn})
        end
    }) or nil
end

local function SendPetWebhook(Id, pt, sh)
    local Img = string.format("https://biggamesapi.io/image/%s", GetAsset(Id, pt))
    local Version = pt == 1 and "Golden " or pt == 2 and "Rainbow " or ""
    local Title = string.format("||%s|| obtained a %s%s%s", LocalPlayer.Name, Version, sh and "Shiny " or "", Id)

    local Exist = GetStats(ExistCmds, "Pet", { id = Id, pt = pt, sh = sh, tn = nil })

    local Body = HttpService:JSONEncode({
        content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
        embeds = {{
            title = Title,
            color = 0xFF00FF,
            timestamp = DateTime.now():ToIsoDate(),
            thumbnail = { url = Img },
            fields = {{
                name = string.format("💫 Exist: ``%s``", Formatint(Exist or 0)),
                value = ""
            }},
            footer = { text = "Hippo Logs" }
        }}
    })

    pcall(function()
        request({
            Url = getgenv().Config.Webhook.URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = Body
        })
    end)
end

-- == PET MONITOR == --
for i, v in pairs(SaveMod.Get()['Inventory']['Pet'] or {}) do
    if string.find(v.id, "Huge") or string.find(v.id, "Titanic") or string.find(v.id, "Gargantuan") then
        StoredUIDs[i] = true
    end
end

Network.Fired("Items: Update"):Connect(function(_, Inventory)
    if Inventory["set"] and Inventory["set"]["Pet"] then
        for uid, v in pairs(Inventory["set"]["Pet"]) do
            if (string.find(v.id, "Huge") or string.find(v.id, "Titanic") or string.find(v.id, "Gargantuan")) and not StoredUIDs[uid] then
                SendPetWebhook(v.id, v.pt, v.sh)
                StoredUIDs[uid] = true
            end
        end
    end
end)

-- == DIAMOND TRACKER == --
local function IsPlayerConnected()
    return LocalPlayer and LocalPlayer:IsDescendantOf(game)
end

local function GetPlayerAvatar(userId)
    return string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", userId)
end

local function GetDiamondsFromLeaderstats()
    local diamondAmount = 0
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats then
        local diamondStat = leaderstats:FindFirstChild("💎 Diamonds")
        if diamondStat and diamondStat:IsA("IntValue") then
            diamondAmount = diamondStat.Value
        end
    end
    return diamondAmount
end

local function SendDiamondWebhook(diamondAmount)
    local embedColor = IsPlayerConnected() and 0x00FF00 or 0xFF0000

    local embed = {
        title = "💎 **Diamond Inventory Update** 💎",
        description = string.format("**Username: ||%s||**\n```\n%-15s = %d\n```", LocalPlayer.Name, "💎 Diamonds", diamondAmount),
        color = embedColor,
        timestamp = DateTime.now():ToIsoDate(),
        thumbnail = {
            url = "https://cdn.discordapp.com/attachments/1350797858240204810/1357324447996051526/8355-moon.png"
        },
        footer = {
            text = string.format("discord.gg/ProjectX | 🌙 | Next update: %d mins", getgenv().Config.Webhook.UpdateIntervalMinutes),
            icon_url = GetPlayerAvatar(LocalPlayer.UserId)
        }
    }

    local body = HttpService:JSONEncode({
        content = getgenv().Config.Webhook.PingID and string.format("<@%s>", getgenv().Config.Webhook.PingID) or nil,
        embeds = {embed}
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

local function StartDiamondLoop()
    task.spawn(function()
        while true do
            SendDiamondWebhook(GetDiamondsFromLeaderstats())
            task.wait(getgenv().Config.Webhook.UpdateIntervalMinutes * 60)
        end
    end)
end

-- == START AFTER GAME LOADED == --
repeat task.wait() until game:IsLoaded()
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild('__INTRO')

StartDiamondLoop()
