local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local p = Players.LocalPlayer
local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mainGui = playerGui:WaitForChild("Main")

local function runGearBuyer()
    _G.cleanup("GearBuyer")
    if not _G.Config.AutoGearBuyer then return end

    local connections = {}
    _G.ScriptManager.Connections["GearBuyer"] = connections

    local buyRemote = remotes:FindFirstChild("BuyGear")
    local gearsGui = mainGui:FindFirstChild("Gears")

    if not gearsGui or not buyRemote then return end

    local scrolling = gearsGui:FindFirstChild("Frame") and gearsGui.Frame:FindFirstChild("ScrollingFrame")
    if not scrolling then return end

    local restockLabel = gearsGui:FindFirstChild("Restock") or gearsGui.Frame:FindFirstChild("Restock")

    local function isIgnored(i)
        if not i or i.Name == "Padding" then return true end
        local c = i.ClassName
        return c == "UIPadding" or c == "UIListLayout"
    end

    local function findStockLabel(frame)
        if not frame then return nil end
        local direct = frame:FindFirstChild("Stock") or frame:FindFirstChild("StockValue")
        if direct and direct:IsA("TextLabel") then return direct end
        for _, v in ipairs(frame:GetDescendants()) do
            if v:IsA("TextLabel") and v.Text and v.Text:lower():find("in stock") then
                return v
            end
        end
        return nil
    end

    local function parseStock(text)
        if not text then return 0 end
        local n = text:match("x%s*(%d+)") or text:match("(%d+)")
        return tonumber(n) or 0
    end
    
    local function canBuy(gearName)
        if not gearName or gearName == "" then return false end
        local gearInfo = _G.Config.gearRegistryTable[gearName]
        if not gearInfo or not gearInfo.Price then
            return false
        end
        return gearInfo.Price >= _G.Config.GEAR_MIN_PRICE
    end

    local function attemptBuy(gearName)
        local success, err
        
        success, err = pcall(function() buyRemote:FireServer(gearName) end)
        if success then return true end
        task.wait(0.15)
        
        success, err = pcall(function() buyRemote:FireServer({ Name = gearName }) end)
        if success then return true end
        task.wait(0.15)
        
        success, err = pcall(function() buyRemote:FireServer({ ID = gearName }) end)
        if success then return true end
        
        return false
    end

    local processedFrames = {}

    local function processFrame(frame)
        if isIgnored(frame) or processedFrames[frame] then return end
        
        local gearName = frame.Name
        if not canBuy(gearName) then
            processedFrames[frame] = true
            return
        end
        
        local stockLabel = findStockLabel(frame)
        if not stockLabel then return end
        
        processedFrames[frame] = true

        local function onStockChanged()
            while _G.Config.AutoGearBuyer do
                local count = parseStock(stockLabel.Text)
                if count > 0 then
                    if not attemptBuy(gearName) then
                        break
                    end
                else
                    break
                end
                task.wait()
            end
        end

        table.insert(connections, stockLabel:GetPropertyChangedSignal("Text"):Connect(onStockChanged))
        task.spawn(onStockChanged)
    end

    local function scanAll()
        for _, child in ipairs(scrolling:GetChildren()) do
            if not isIgnored(child) then
                processFrame(child)
            end
        end
    end
    
    table.insert(connections, scrolling.ChildAdded:Connect(function(child)
        if not _G.Config.AutoGearBuyer then return end
        if not isIgnored(child) then
            processFrame(child)
        end
    end))

    local function parseTimeToSeconds(t)
        if not t then return 0 end
        local mm, ss = t:match("(%d+):(%d+)")
        if mm and ss then return tonumber(mm) * 60 + tonumber(ss) end
        local n = t:match("(%d+)")
        return tonumber(n) or 0
    end

    if restockLabel then
        local lastSeconds = parseTimeToSeconds(restockLabel.Text)
        table.insert(connections, restockLabel:GetPropertyChangedSignal("Text"):Connect(function()
            if not _G.Config.AutoGearBuyer then return end
            local s = parseTimeToSeconds(restockLabel.Text)
            if s > lastSeconds then
                task.wait(0.5)
                scanAll()
            end
            lastSeconds = s
        end))
    end

    scanAll()
end

runGearBuyer()
