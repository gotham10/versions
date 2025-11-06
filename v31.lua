_G.ScriptManager = _G.ScriptManager or { Connections = {}, Threads = {} }

local function cleanup(key)
    if _G.ScriptManager.Connections[key] then
        for _, conn in ipairs(_G.ScriptManager.Connections[key]) do
            pcall(conn.Disconnect, conn)
        end
    end
    _G.ScriptManager.Connections[key] = {}
    
    if _G.ScriptManager.Threads[key] then
        pcall(coroutine.close, _G.ScriptManager.Threads[key])
    end
    _G.ScriptManager.Threads[key] = nil
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local p = Players.LocalPlayer
if not _G.Config or not table.find(_G.Config.wl, p.Name) then return end

local player = p
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local mainGui = playerGui:WaitForChild("Main")
local modules = ReplicatedStorage:WaitForChild("Modules")
local registries = modules:WaitForChild("Registries")

local function runSeedBuyer()
    cleanup("SeedBuyer")
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

local function runGearBuyer()
    cleanup("GearBuyer")
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

local function runAutoSellLimited()
    cleanup("AutoSellLimited")
    if not _G.Config.AutoSellLimited then return end
    
    local connections = {}
    _G.ScriptManager.Connections["AutoSellLimited"] = connections

    local b = playerGui.Main:FindFirstChild("AutoSell") and playerGui.Main.AutoSell:FindFirstChild("Frame") and playerGui.Main.AutoSell.Frame:FindFirstChild("Limited") and playerGui.Main.AutoSell.Frame.Limited:FindFirstChild("TextButton")
    local rem = remotes:FindFirstChild("AutoSell")
    
    if not b or not rem then return end

    local g = {}
    for _, v in pairs(b:GetDescendants()) do
        if v:IsA("UIGradient") then
            g[v.Name] = v
        end
    end

    if not g.selected or not g.unselected then return end
    
    local lastToggleTime = 0
    local function updateAutoSell()
        if not _G.Config.AutoSellLimited or (tick() - lastToggleTime < 0.25) then return end
        
        local e = ws:GetAttribute("ActiveEvents") or ""
        
        if string.find(e, "HalloweenEvent") then
            if not g.selected.Enabled then
                lastToggleTime = tick()
                pcall(rem.FireServer, rem, "Limited")
            end
        else
            if not g.unselected.Enabled then
                lastToggleTime = tick()
                pcall(rem.FireServer, rem, "Limited")
            end
        end
    end
    
    pcall(updateAutoSell)
    
    table.insert(connections, ws.AttributeChanged:Connect(function(attr)
        if not _G.Config.AutoSellLimited then return end
        if attr == "ActiveEvents" then
            pcall(updateAutoSell)
        end
    end))
    
    table.insert(connections, g.selected:GetPropertyChangedSignal("Enabled"):Connect(updateAutoSell))
    table.insert(connections, g.unselected:GetPropertyChangedSignal("Enabled"):Connect(updateAutoSell))
end


local function runAutoSellSecret()
    cleanup("AutoSellSecret")
    if not _G.Config.AutoSellSecret or not _G.Config.AutoSellSecretNames then return end

    local connections = {}
    _G.ScriptManager.Connections["AutoSellSecret"] = connections

    local autoSellRemote = remotes:WaitForChild("AutoSell", 5)
    local brainrotsFolder = ws:FindFirstChild("ScriptedMap") and ws.ScriptedMap:FindFirstChild("MissionBrainrots")
    local plotsFolder = ws:FindFirstChild("Plots")
    local secretButton = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("AutoSell") and playerGui.Main.AutoSell:FindFirstChild("Frame") and playerGui.Main.AutoSell.Frame:FindFirstChild("Secret") and playerGui.Main.AutoSell.Frame.Secret:FindFirstChild("TextButton")

    if not autoSellRemote or not brainrotsFolder or not plotsFolder or not secretButton then
        return
    end

    local selectedGradient = secretButton:WaitForChild("selected", 5)
    local unselectedGradient = secretButton:WaitForChild("unselected", 5)

    if not selectedGradient or not unselectedGradient then
        return
    end

    local lastToggleTime = 0
    local function toggleSecret()
        if tick() - lastToggleTime < 0.25 then return end
        lastToggleTime = tick()
        
        pcall(function()
            autoSellRemote:FireServer("Secret")
        end)
    end

    local function checkBrainrots()
        if not _G.Config.AutoSellSecret then return end
        
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
                toggleSecret()
            end
        else
            if not selectedGradient.Enabled then
                toggleSecret()
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

local function getPlayerPlot()
    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        if plot:GetAttribute("Owner") == player.Name then
            return plot
        end
    end
    return nil
end

local function runAutoBrainrot()
    cleanup("AutoBrainrot")
    if not _G.Config.AutoBrainrot then return end

    local remotesFolder = remotes
    local equipRemote = remotesFolder:FindFirstChild("EquipBestBrainrots") or remotesFolder:FindFirstChild("EquipBest")

	local thread = coroutine.create(function()
		while _G.Config.AutoBrainrot and task.wait(_G.Config.AutoBrainrotWait or 60) do
			pcall(function()
				local playerPlot = getPlayerPlot()
				if not playerPlot then return end

				if equipRemote then
					equipRemote:FireServer()
				end

				task.wait(1)

				if playerPlot:FindFirstChild("Brainrots") then
					for _, brainrot in ipairs(playerPlot.Brainrots:GetChildren()) do
						if brainrot:FindFirstChild("Hitbox") and brainrot.Hitbox:FindFirstChild("ProximityPrompt") then
							local prompt = brainrot.Hitbox.ProximityPrompt
							if prompt.Enabled then
								prompt:InputHoldBegin()
								prompt:InputHoldEnd()
							end
						end
					end
				end
			end)
		end
	end)
	_G.ScriptManager.Threads["AutoBrainrot"] = thread
	coroutine.resume(thread)
end

local function runAutoAcceptGifts()
    cleanup("AutoAcceptGifts")
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

local function runAutoBuyHalloweenCrate()
    cleanup("AutoBuyHalloweenCrate")
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

local function runAntiAFK()
    cleanup("AntiAFK")
    if not _G.Config.AntiAFK then return end

    local connections = {}
    _G.ScriptManager.Connections["AntiAFK"] = connections

    local vu = game:GetService("VirtualUser")

    local conn = p.Idled:Connect(function()
        vu:CaptureController()
        vu:ClickButton2(Vector2.new())
    end)
    table.insert(connections, conn)
end

local function runShopTimer()
    pcall(function()
        local oldGui = playerGui:FindFirstChild("ShopRestockUI")
        if oldGui then
            oldGui:Destroy()
        end
    end)

    cleanup("ShopTimer")
    if not _G.Config.ShowShopTimer then return end

    local connections = {}
    _G.ScriptManager.Connections["ShopTimer"] = connections

    local Workspace = game:GetService("Workspace")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShopRestockUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.Parent = playerGui

    local label = Instance.new("TextLabel")
    label.Parent = screenGui
    label.AnchorPoint = Vector2.new(0, 1)
    label.Position = UDim2.new(0.0015, 0, 1.005, -5)
    label.Size = UDim2.new(0.1, 0, 0.03, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Bottom

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = screenGui
    uiScale.Scale = 0.8

    local rsConn = RunService.RenderStepped:Connect(function()
        local screenSize = Workspace.CurrentCamera.ViewportSize
        if screenSize.Y < 700 then
            uiScale.Scale = 0.7
        else
            uiScale.Scale = 0.8
        end
    end)
    table.insert(connections, rsConn)

    local function formatTime(seconds)
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end

    local function updateTimer()
        while _G.Config.ShowShopTimer do
            local success, result = pcall(function()
                local restockTime = Workspace:GetAttribute("NextSeedRestock")
                if restockTime and type(restockTime) == "number" and restockTime > 0 then
                    for i = restockTime, 0, -1 do
                        if not _G.Config.ShowShopTimer or not label or not label.Parent then return end
                        label.Text = "Shop Restocks in: " .. formatTime(i)
                        task.wait(1)
                    end
                else
                    if not label or not label.Parent then return end
                    label.Text = "Shop Restocks in: --:--"
                    task.wait(1)
                end
            end)
            if not success then
                task.wait(5)
            end
        end
    end

    local thread = coroutine.create(updateTimer)
    _G.ScriptManager.Threads["ShopTimer"] = thread
    coroutine.resume(thread)
end

local function runSafeLocation()
    cleanup("SafeLocation")
    
    local connections = {}
    _G.ScriptManager.Connections["SafeLocation"] = connections
    
    local targetPosition = Vector3.new(-197, 13, 1055)
    
    local uisConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.KeyCode == Enum.KeyCode.T and not gameProcessedEvent then
            _G.Config.SafeLocation = not _G.Config.SafeLocation
        end
    end)
    table.insert(connections, uisConn)
    
    local hbConn = RunService.Heartbeat:Connect(function()
        if not _G.Config.SafeLocation then return end
        
        local char = p.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if hrp and (hrp.Position - targetPosition).Magnitude > 10 then
            hrp.CFrame = CFrame.new(targetPosition)
        end
    end)
    table.insert(connections, hbConn)
end

local function runOPlessLag()
	cleanup("OPlessLag")
	if not _G.Config.OPlessLag then return end

	local Players = game:GetService("Players")
	local player = Players.LocalPlayer
	local workspace = game:GetService("Workspace")

	local function safeDestroy(inst)
		pcall(function()
			if inst and inst.Parent and not inst:IsA("Terrain") then
				inst:Destroy()
			end
		end)
	end

	local function getPlayerPlot()
		local plots = workspace:FindFirstChild("Plots")
		if not plots then return nil end
		for _, folder in ipairs(plots:GetChildren()) do
			if folder:IsA("Folder") or folder:IsA("Model") then
				local owner = folder:GetAttribute("Owner")
				if owner == player.Name then
					return folder
				end
			end
		end
		return nil
	end

	local function cleanPlots()
		local plots = workspace:FindFirstChild("Plots")
		if not plots then return end
		for _, folder in ipairs(plots:GetChildren()) do
			if folder:IsA("Folder") or folder:IsA("Model") then
				local owner = folder:GetAttribute("Owner")
				if owner ~= player.Name then
					safeDestroy(folder)
				end
			end
		end
	end

	local function cleanMyPlot(plot)
		if not plot then return end
		local eventPlatforms = plot:FindFirstChild("EventPlatforms")
		if eventPlatforms then
			for _, model in ipairs(eventPlatforms:GetChildren()) do
				if model:IsA("Model") then
					local visualFolder = model:FindFirstChild("VisualFolder")
					if visualFolder then
						for _, m in ipairs(visualFolder:GetChildren()) do
							if m:IsA("Model") then
								safeDestroy(m)
							end
						end
					end
				end
			end
		end
		local decor = plot:FindFirstChild("Decor")
		if decor then safeDestroy(decor) end
		local hit = plot:FindFirstChild("Hitboxes")
		if hit then safeDestroy(hit) end
		local spawner = plot:FindFirstChild("Spawner")
		if spawner then
			for _, model in ipairs(spawner:GetChildren()) do
				if model:IsA("Model") then
					local road = model:FindFirstChild("Road")
					if road then
						road.Parent = plot
						break
					end
				end
			end
			safeDestroy(spawner)
		end
		local biome = plot:FindFirstChild("Biome")
		if biome then
			local island = biome:FindFirstChild("Island", true)
			if island then
				local toMove = {}
				for _, desc in ipairs(island:GetDescendants()) do
					if desc.Name == "Sand" or desc.Name == "Grass" or desc.Name == "Dirt" then
						table.insert(toMove, desc)
					end
				end
				for _, inst in ipairs(toMove) do
					if inst and inst.Parent then
						inst.Parent = plot
					end
				end
			end
			for _, model in ipairs(biome:GetChildren()) do
				if model:IsA("Model") then
					local rebirth = model:FindFirstChild("RebirthUnlock")
					if rebirth then
						rebirth.Parent = plot
						break
					end
				end
			end
			safeDestroy(biome)
		end
		local bridge = plot:FindFirstChild("Bridge")
		if bridge then safeDestroy(bridge) end
		local luckDisplay = plot:FindFirstChild("LuckDisplay")
		if luckDisplay then safeDestroy(luckDisplay) end
		for _, inst in ipairs(plot:GetChildren()) do
			if inst:IsA("Model") then
				local n = tonumber(inst.Name)
				if n and n >= 1 and n <= 6 then
					local rebirth = plot:FindFirstChild("RebirthUnlock")
					if not (rebirth and inst:IsDescendantOf(rebirth)) then
						safeDestroy(inst)
					end
				end
			end
		end
		for _, name in ipairs({"PlayerSign", "SpawnerUI", "StrikePoint", "BrainrotZone"}) do
			local obj = plot:FindFirstChild(name)
			if obj then safeDestroy(obj) end
		end
		local cardMachine = plot:FindFirstChild("CardMachine")
		if cardMachine then
			local locks = cardMachine:FindFirstChild("Locks")
			if locks then safeDestroy(locks) end
			for _, part in ipairs(cardMachine:GetChildren()) do
				if part:IsA("Part") and part.Name == "Part" then
					safeDestroy(part)
				end
				if part:IsA("Model") and part.Name == "Model" then
					safeDestroy(part)
				end
			end
			local cardSign = cardMachine:FindFirstChild("CardSign")
			if cardSign then safeDestroy(cardSign) end
		end
		local portal = plot:FindFirstChild("Portal")
		if portal then
			local models = {}
			for _, m in ipairs(portal:GetChildren()) do
				if m:IsA("Model") and m.Name == "Model" then
					table.insert(models, m)
				end
			end
			for _, m in ipairs(models) do
				local parts = {}
				for _, d in ipairs(m:GetChildren()) do
					if d:IsA("Part") then
						table.insert(parts, d)
					end
				end
				if #parts == 2 then
					safeDestroy(m)
				end
			end
			local remaining = {}
			for _, m in ipairs(portal:GetChildren()) do
				if m:IsA("Model") and m.Name == "Model" then
					table.insert(remaining, m)
				end
			end
			if #remaining == 2 then
				local targetModel = nil
				for _, m in ipairs(remaining) do
					for _, p in ipairs(m:GetDescendants()) do
						if p:IsA("Part") and p.Color == Color3.fromRGB(148,105,35) then
							targetModel = m
							break
						end
					end
				end
				if targetModel then
					for _, m in ipairs(remaining) do
						if m ~= targetModel then
							safeDestroy(m)
						end
					end
				end
			end
		end
	end

	local function cleanMap()
		local map = workspace:FindFirstChild("Map")
		if not map then return end
		local central = map:FindFirstChild("CentralIsland")
		if central then
			for _, inst in ipairs(central:GetDescendants()) do
				if inst:IsA("Model") or inst:IsA("MeshPart") then
					safeDestroy(inst)
				end
			end
			for _, inst in ipairs(central:GetChildren()) do
				if inst:IsA("Model") or inst:IsA("MeshPart") then
					safeDestroy(inst)
				end
			end
		end
		for _, v in ipairs(map:GetChildren()) do
			if v.Name ~= "IslandPortal" and v.Name ~= "Barriers" and v.Name ~= "CentralIsland" then
				safeDestroy(v)
			end
		end
	end

	local function cleanWorkspace()
		local del1 = workspace:FindFirstChild("1Copy")
		if del1 then safeDestroy(del1) end
		local eff = workspace:FindFirstChild("Effects")
		if eff then safeDestroy(eff) end
		for _, v in ipairs(workspace:GetChildren()) do
			if v:IsA("Model") or v:IsA("BasePart") or v:IsA("MeshPart") then
				if v.Parent == workspace and v.Name ~= "Map" and v.Name ~= "Plots" and v.Name ~= "Players" and v.Name ~= "ScriptedMap" then
					safeDestroy(v)
				end
			end
		end
	end

	local function cleanPlayers()
		local playersFolder = workspace:FindFirstChild("Players")
		if not playersFolder then return end
		for _, model in ipairs(playersFolder:GetChildren()) do
			if model:IsA("Model") and model.Name ~= player.Name then
				safeDestroy(model)
			end
		end
	end

	local function cleanMissionBrainrots(plotName)
		local sm = workspace:FindFirstChild("ScriptedMap")
		if not sm then return end
		local brainrots = sm:FindFirstChild("MissionBrainrots")
		if not brainrots then return end
		for _, model in ipairs(brainrots:GetChildren()) do
			if model:IsA("Model") then
				local plotNum = model:GetAttribute("Plot")
				if tostring(plotNum) ~= tostring(plotName) then
					safeDestroy(model)
				end
			end
		end
	end

	local function cleanScriptedMap()
		local sm = workspace:FindFirstChild("ScriptedMap")
		if not sm then return end
		local removeNames = {
			BrainrotCollisions = true,
			Brainrots = true,
			BuildingStores = true,
			Countdowns = true,
			NPCs = true,
			Placing = true,
			Secrets = true
		}
		for _, v in ipairs(sm:GetChildren()) do
			if removeNames[v.Name] then
				safeDestroy(v)
			end
		end
		local water = sm:FindFirstChild("Water")
		if water then
			for _, d in ipairs(water:GetDescendants()) do
				if d:IsA("TouchTransmitter") then
					safeDestroy(d)
				end
			end
		end
		local cardMerger = sm:FindFirstChild("CardMerger")
		if cardMerger then
			local sign = cardMerger:FindFirstChild("Sign")
			if sign then safeDestroy(sign) end
		end
		local dailys = sm:FindFirstChild("Dailys")
		if dailys then
			local dailyIsland = dailys:FindFirstChild("DailyIsland")
			if dailyIsland then
				local sign = dailyIsland:FindFirstChild("Sign")
				if sign then safeDestroy(sign) end
			end
		end
		local adminChest = sm:FindFirstChild("AdminChest")
		if adminChest then
			local woodSign = adminChest:FindFirstChild("WoodenSign")
			if woodSign then safeDestroy(woodSign) end
		end
		local leaderboards = sm:FindFirstChild("Leaderboards")
		if leaderboards then
			safeDestroy(leaderboards)
		end
		local candy = sm:FindFirstChild("CandyStand")
		if candy then
			for _, m in ipairs(candy:GetChildren()) do
				if m:IsA("Model") then
					if not table.find({"Candy Brainrot Crate","Candy Spooky Crate","Halloween Card Pack"},m.Name) then
						if m.Name == "Model" then
							local keep = false
							for _, p in ipairs(m:GetDescendants()) do
								if p:IsA("BasePart") or p:IsA("MeshPart") then
									local c = p.Color
									if c == Color3.fromRGB(204,78,80) or c == Color3.fromRGB(145,193,108) or c == Color3.fromRGB(245,140,255) then
										keep = true
										break
									end
								end
							end
							if not keep then
								safeDestroy(m)
							end
						else
							safeDestroy(m)
						end
					end
					if m.Name == "SignHelper" then
						safeDestroy(m)
					end
				end
			end
		end
	end

	local plotPositions = {
		["1"] = Vector3.new(41, 5, 560),
		["2"] = Vector3.new(-59, 5, 560),
		["3"] = Vector3.new(-160, 5, 560),
		["4"] = Vector3.new(-261, 5, 560),
		["5"] = Vector3.new(-362, 5, 560),
		["6"] = Vector3.new(-464, 5, 560)
	}

	local thread = coroutine.create(function()
		while _G.Config.OPlessLag and task.wait(0.5) do
			local myPlot = getPlayerPlot()
			local myPlotName = myPlot and myPlot.Name or nil
			cleanPlots()
			cleanMap()
			cleanWorkspace()
			cleanPlayers()
			cleanMissionBrainrots(myPlotName)
			cleanScriptedMap()
			cleanMyPlot(myPlot)
		end
	end)
	_G.ScriptManager.Threads["OPlessLag"] = thread
	coroutine.resume(thread)
end

runSeedBuyer()
runGearBuyer()
runAutoSellLimited()
runAutoSellSecret()
runAutoBrainrot()
runAutoAcceptGifts()
runAutoBuyHalloweenCrate()
runAntiAFK()
runShopTimer()
runSafeLocation()
runOPlessLag()
