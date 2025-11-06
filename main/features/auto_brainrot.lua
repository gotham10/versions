local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local p = Players.LocalPlayer
local player = p
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getPlayerPlot()
    for _, plot in ipairs(workspace.Plots:GetChildren()) do
        if plot:GetAttribute("Owner") == player.Name then
            return plot
        end
    end
    return nil
end

local function runAutoBrainrot()
    _G.cleanup("AutoBrainrot")
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

runAutoBrainrot()
