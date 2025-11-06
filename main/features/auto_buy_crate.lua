local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local p = Players.LocalPlayer
local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function runAutoBuyHalloweenCrate()
    _G.cleanup("AutoBuyHalloweenCrate")
    if not _G.Config.AutoBuyHalloweenCrate then return end

    local remote = remotes:FindFirstChild("BuyCrate")
    local gui = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("Event_Candy") and playerGui.Main.Event_Candy:FindFirstChild("CurrentFrame") and playerGui.Main.Event_Candy.CurrentFrame:FindFirstChild("Amount")

    if not remote or not gui then return end

    local function getAmount()
        local txt = tostring(gui.Text or "")
        local cleaned = txt:gsub(",", "")
        return tonumber(cleaned) or 0
    end

    local thread = coroutine.create(function()
        while _G.Config.AutoBuyHalloweenCrate do
            local amt = getAmount()
            if amt >= 50 then
                pcall(remote.FireServer, remote, "Candy Spooky Crate")
                task.wait(0.1)
            else
                task.wait(1)
            end
        end
    end)
    _G.ScriptManager.Threads["AutoBuyHalloweenCrate"] = thread
    coroutine.resume(thread)
end

runAutoBuyHalloweenCrate()
