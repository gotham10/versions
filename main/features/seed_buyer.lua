local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local p = Players.LocalPlayer
local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mainGui = playerGui:WaitForChild("Main")

local function runSeedBuyer()
    _G.cleanup("SeedBuyer")
    if not _G.Config.AutoSeedBuyer then return end

    local connections = {}
    _G.ScriptManager.Connections["SeedBuyer"] = connections

    local buyRemote = remotes:WaitForChild("BuyItem", 5)
    local seedsGui = mainGui:WaitForChild("Seeds", 5)

    if not seedsGui or not buyRemote then return end

    local scrolling = seedsGui.Frame:WaitForChild("ScrollingFrame", 5)
    if not scrolling then return end

    local restockLabel = seedsGui:WaitForChild("Restock", 5)

    local function isIgnored(inst)
        if not inst or inst.Name == "Padding" then return true end
        local c = inst.ClassName
        return c == "UIPadding" or c == "UIListLayout"
    end

    local function findStockLabel(frame)
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

    local seedPrices = {}
    for seedName, seedInfo in pairs(_G.Config.seedRegistryTable) do
        if type(seedInfo) == "table" and seedInfo.Price then
            seedPrices[seedName] = tonumber(seedInfo.Price)
        end
    end

    local function canBuy(seedName)
        local price = seedPrices[seedName]
        if not price then return false end
        return price >= _G.Config.SEED_MIN_PRICE
    end

    local function attemptBuy(seedName)
        local ok, err = pcall(function() buyRemote:FireServer(seedName) end)
        return ok
    end

    local processedFrames = {}

    local function processFrame(frame)
        if isIgnored(frame) or processedFrames[frame] then return end

        local seedName = frame.Name
        if not canBuy(seedName) then
            processedFrames[frame] = true
            return
        end

        local stockLabel = findStockLabel(frame)
        if not stockLabel then return end
        
        processedFrames[frame] = true

        local function onStockChanged()
            while _G.Config.AutoSeedBuyer do
                local count = parseStock(stockLabel.Text)
                if count > 0 then
                    if not attemptBuy(seedName) then break end
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
        if not _G.Config.AutoSeedBuyer then return end
        if not isIgnored(child) then
            processFrame(child)
        end
    end))

    local function parseTimeToSeconds(text)
        if not text then return 0 end
        local mm, ss = text:match("(%d+):(%d+)")
        if mm and ss then return tonumber(mm) * 60 + tonumber(ss) end
        return tonumber(text:match("(%d+)")) or 0
    end

    if restockLabel then
        local lastSeconds = parseTimeToSeconds(restockLabel.Text)
        table.insert(connections, restockLabel:GetPropertyChangedSignal("Text"):Connect(function()
            if not _G.Config.AutoSeedBuyer then return end
            local s = parseTimeToSeconds(restockLabel.Text)
            if s > lastSeconds then
                task.wait(0.5)
                scanAll()
            end
            lastSeconds = s
        end))
    end

    task.wait(1)
    scanAll()
end

runSeedBuyer()
