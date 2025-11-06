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

task.spawn(function()
	while task.wait(0.5) do
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
