local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function runAutoAcceptGifts()
    _G.cleanup("AutoAcceptGifts")
    if not _G.Config.AutoAcceptGifts then return end

    local connections = {}
    _G.ScriptManager.Connections["AutoAcceptGifts"] = connections

    local acceptGiftRemote = remotes:WaitForChild("AcceptGift")
    local giftItemRemote = remotes:WaitForChild("GiftItem")

    if not acceptGiftRemote or not giftItemRemote then return end

    local conn = giftItemRemote.OnClientEvent:Connect(function(giftPayload)
        if not _G.Config.AutoAcceptGifts then return end
        if giftPayload and type(giftPayload) == "table" and giftPayload.ID then
            acceptGiftRemote:FireServer({
                ID = giftPayload.ID
            })
        end
    end)
    table.insert(connections, conn)
end

runAutoAcceptGifts()
