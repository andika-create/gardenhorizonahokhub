--[[
    AHOK HUB | GARDEN HORIZONS
    Stable Version (Fixed Harvest & Sell)
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Ahok Hub | Garden Horizons",
    LoadingTitle = "Loading Ahok Hub...",
    LoadingSubtitle = "by Ahok Team",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AhokHub",
        FileName = "Garden"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- // Robust Remote Detection
local function FindRemote(Name)
    return ReplicatedStorage:FindFirstChild(Name, true)
end

local Remotes = {
    Harvest = FindRemote("HarvestFruit"),
    Sell = FindRemote("SellItems"),
    UseGear = FindRemote("UseGear"),
    ClaimQuest = FindRemote("ClaimQuest"),
    LuckyBlock = FindRemote("RequestLuckyBlock"),
}

-- // Variables
local Flags = {
    AutoHarvest = false,
    AutoSell = false,
    AutoWater = false,
    LuckySniper = false,
    MutationESP = false,
    AntiAFK = true
}

-- // Security Mitigation
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not checkcaller() then
            local method = getnamecallmethod()
            local name = tostring(self)
            if (method == "FireServer") and (name:find("Integrity") or name:find("Analytics")) then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
end)

-- // Helper Functions
local function GetWateringCan()
    local tool = LocalPlayer.Backpack:FindFirstChild("Watering Can") or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Watering Can"))
    if not tool then
        -- Search for any tool with 'Water' in name
        for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do
            if v.Name:find("Water") then return v end
        end
    end
    return tool
end

-- // Feature Loops
task.spawn(function()
    while task.wait(0.5) do
        -- 1. Fixed Auto Harvest
        if Flags.AutoHarvest and Remotes.Harvest then
            local harvestBatch = {}
            for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                -- Verify ownership via attribute
                if plant:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                    local ripeness = plant:GetAttribute("RipenessStage")
                    local uuid = plant:GetAttribute("Uuid")
                    
                    if (ripeness == "Ripe" or ripeness == "Lush") and uuid then
                        table.insert(harvestBatch, {Uuid = uuid})
                    end
                end
            end
            
            if #harvestBatch > 0 then
                Remotes.Harvest:FireServer(harvestBatch)
                task.wait(1) -- Batching cooldown
            end
        end

        -- 2. Improved Auto-Water
        if Flags.AutoWater and Remotes.UseGear then
            local wateringCan = GetWateringCan()
            if wateringCan then
                for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                    if plant:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                        if plant:GetAttribute("NeedsWater") then
                            local uuid = plant:GetAttribute("Uuid")
                            local anchor = plant:GetAttribute("GrowthAnchorIndex")
                            if uuid then
                                Remotes.UseGear:FireServer(wateringCan, {
                                    PlantUuid = uuid;
                                    GrowthAnchorIndex = anchor;
                                })
                                task.wait(0.5)
                            end
                        end
                    end
                end
            end
        end

        -- 3. Corrected Auto Sell
        if Flags.AutoSell and Remotes.Sell then
            Remotes.Sell:InvokeServer("SellAll")
            task.wait(15)
        end
        
        -- 4. Lucky Block Sniper
        if Flags.LuckySniper and Remotes.LuckyBlock then
            Remotes.LuckyBlock:InvokeServer()
            task.wait(5)
        end
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Flags.AntiAFK then
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    end
end)

-- // UI Implementation
local MainTab = Window:CreateTab("Auto-Farm", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)
local MiscTab = Window:CreateTab("Misc", 4483362458)

MainTab:CreateSection("Farming controls")

MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(v) Flags.AutoHarvest = v end,
})

MainTab:CreateToggle({
    Name = "Auto Water",
    CurrentValue = false,
    Flag = "AutoWater",
    Callback = function(v) Flags.AutoWater = v end,
})

MainTab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(v) Flags.AutoSell = v end,
})

VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
    Name = "Mutation ESP",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(v) Flags.MutationESP = v end,
})

MiscTab:CreateSection("Utilities")

MiscTab:CreateToggle({
    Name = "Lucky Block Sniper",
    CurrentValue = false,
    Flag = "LuckySniper",
    Callback = function(v) Flags.LuckySniper = v end,
})

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(v) Flags.AntiAFK = v end,
})

MiscTab:CreateButton({
    Name = "Force Claim Quests",
    Callback = function()
        if Remotes.ClaimQuest then
            Remotes.ClaimQuest:FireServer()
            Rayfield:Notify({Title="Quests", Content="Quests claimed!"})
        end
    end,
})

Rayfield:Notify({
    Title = "Ahok Hub Ready",
    Content = "Auto-Harvest and Auto-Sell have been fixed!",
    Duration = 5
})
