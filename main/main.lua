_G.ScriptManager = _G.ScriptManager or { Connections = {}, Threads = {} }

function _G.cleanup(key)
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

local p = game:GetService("Players").LocalPlayer
if not _G.Config or not table.find(_G.Config.wl, p.Name) then return end

-- This URL should point to the folder where you store the feature files
-- For example: "https://raw.githubusercontent.com/gotham10/versions/main/features/"
local baseURL = "YOUR_GITHUB_RAW_URL/features/"

local features = {
    "seed_buyer.lua",
    "gear_buyer.lua",
    "autosell_limited.lua",
    "autosell_secret.lua",
    "auto_brainrot.lua",
    "auto_accept_gifts.lua",
    "auto_buy_crate.lua"
}

for _, featureFile in ipairs(features) do
    local success, err = pcall(function()
        loadstring(game:HttpGet(baseURL .. featureFile))()
    end)
    if not success then
        warn("Failed to load feature:", featureFile, "Error:", err)
    end
end
