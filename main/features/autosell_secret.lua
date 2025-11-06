local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local p = Players.LocalPlayer
local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function runAutoSellSecret()
    _G.cleanup("AutoSellSecret")
    if not _G.Config.AutoSellSecret then return end
    
    local connections = {}
    _G.ScriptManager.Connections["AutoSellSecret"] = connections

    local b = playerGui.Main:FindFirstChild("AutoSell") and playerGui.Main.AutoSell:FindFirstChild("Frame") and playerGui.Main.AutoSell.Frame:FindFirstChild("Secret") and playerGui.Main.AutoSell.Frame.Secret:FindFirstChild("TextButton")
    local rem = remotes:FindFirstChild("AutoSell")
    
    if not b or not rem then return end

    local g = {}
    for _, v in pairs(b:GetDescendants()) do
        if v:IsA("UIGradient") then
            g[v.Name] = v
        end
    end

    if not g.selected or not g.unselected then return end
    
    local function updateAutoSell()
        if not _G.Config.AutoSellSecret then return end
        local e = ws:GetAttribute("ActiveEvents") or ""
        
        if string.find(e, "HalloweenEvent") then
            if not g.unselected.Enabled then
                pcall(rem.FireServer, rem, "Secret")
            end
        else
            if not g.selected.Enabled then
                pcall(rem.FireServer, rem, "Secret")
            end
        end
    end
    
    pcall(updateAutoSell)
    
    table.insert(connections, ws.AttributeChanged:Connect(function(attr)
        if not _G.Config.AutoSellSecret then return end
        if attr == "ActiveEvents" then
            pcall(updateAutoSell)
        end
    end))
    
    table.insert(connections, g.selected:GetPropertyChangedSignal("Enabled"):Connect(updateAutoSell))
    table.insert(connections, g.unselected:GetPropertyChangedSignal("Enabled"):Connect(updateAutoSell))
end

runAutoSellSecret()
