local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local p = Players.LocalPlayer
local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function runAutoSellLimited()
    _G.cleanup("AutoSellLimited")
    if not _G.Config.AutoSellLimited or not _G.Config.AutoSellSecretNames then return end

    local connections = {}
    _G.ScriptManager.Connections["AutoSellLimited"] = connections

    local autoSellRemote = remotes:WaitForChild("AutoSell", 5)
    local brainrotsFolder = ws:FindFirstChild("ScriptedMap") and ws.ScriptedMap:FindFirstChild("MissionBrainrots")
    local plotsFolder = ws:FindFirstChild("Plots")
    local limitedButton = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("AutoSell") and playerGui.Main.AutoSell:FindFirstChild("Frame") and playerGui.Main.AutoSell.Frame:FindFirstChild("Limited") and playerGui.Main.AutoSell.Frame.Limited:FindFirstChild("TextButton")

    if not autoSellRemote or not brainrotsFolder or not plotsFolder or not limitedButton then
        return
    end

    local selectedGradient = limitedButton:WaitForChild("selected", 5)
    local unselectedGradient = limitedButton:WaitForChild("unselected", 5)

    if not selectedGradient or not unselectedGradient then
        return
    end

    local function toggleLimited()
        pcall(function()
            autoSellRemote:FireServer("Limited")
        end)
    end

    local function checkBrainrots()
        if not _G.Config.AutoSellLimited then return end
        
        local foundPlot = false
        for _, model in ipairs(brainrotsFolder:GetChildren()) do
            local brainrotName = model:GetAttribute("Brainrot")
            if brainrotName and table.find(_G.Config.AutoSellSecretNames, brainrotName) then
                local plotNumber = model:GetAttribute("Plot")
                if plotNumber then
                    local plotFolder = plotsFolder:FindFirstChild(tostring(plotNumber))
                    if plotFolder and plotFolder:GetAttribute("Owner") == p.Name then
                        foundPlot = true
                        break
                    end
                end
            end
        end

        if foundPlot then
            if not unselectedGradient.Enabled then
                toggleLimited()
            end
        else
            if not selectedGradient.Enabled then
                toggleLimited()
            end
        end
    end

    local function connectToModel(model)
        if model:IsA("Model") then
            table.insert(connections, model:GetAttributeChangedSignal("Brainrot"):Connect(checkBrainrots))
            table.insert(connections, model:GetAttributeChangedSignal("Plot"):Connect(checkBrainrots))
        end
    end

    for _, model in ipairs(brainrotsFolder:GetChildren()) do
        connectToModel(model)
    end
    table.insert(connections, brainrotsFolder.ChildAdded:Connect(connectToModel))
    table.insert(connections, brainrotsFolder.ChildRemoved:Connect(checkBrainrots))

    table.insert(connections, selectedGradient:GetPropertyChangedSignal("Enabled"):Connect(checkBrainrots))
    table.insert(connections, unselectedGradient:GetPropertyChangedSignal("Enabled"):Connect(checkBrainrots))

    pcall(checkBrainrots)
end

runAutoSellLimited()
