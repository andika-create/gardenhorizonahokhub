--[[
    AHOK HUB | GARDEN HORIZONS
    PRO VERSION v2 (Selective Farm, Intervals, Stability Fixes)
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Ahok Hub | Garden Horizons",
    LoadingTitle = "Loading Ahok Hub Pro...",
    LoadingSubtitle = "by Ahok Team",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AhokHub",
        FileName = "GardenV2"
    },
    Discord = { Enabled = false },
    KeySystem = false
})

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- // Robust Remote Detection
local function FindRemote(Name)
    local r = ReplicatedStorage:FindFirstChild(Name, true)
    if not r then warn("Remote not found: " .. Name) end
    return r
end

local Remotes = {
    Harvest = FindRemote("HarvestFruit"),
    Sell = FindRemote("SellItems"),
    UseGear = FindRemote("UseGear"),
    ClaimQuest = FindRemote("ClaimQuest"),
    LuckyBlock = FindRemote("RequestLuckyBlock"),
    Shop = FindRemote("PurchaseShopItem"),
}

-- // Variables & Flags
local Flags = {
    AutoHarvest = false,
    AutoSell = false,
    AutoWater = false,
    LuckySniper = false,
    MutationESP = false,
    AntiAFK = true,
    AutoBuy = false,
    AutoQuest = false,
    
    SelectedHarvest = "All",
    SelectedSell = "All",
    SelectedBuy = "Carrot",
    
    HarvestInterval = 1,
    SellInterval = 15,
    WaterInterval = 0.5
}

local PlantTypes = {"All", "Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"}

-- // Security Mitigation
pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not checkcaller() then
            local method = getnamecallmethod()
            local name = tostring(self)
            if (method == "FireServer" or method == "InvokeServer") and (name:find("Integrity") or name:find("Analytics")) then
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
        for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do
            if v.Name:lower():find("water") then return v end
        end
    end
    return tool
end

local function GetPlantName(plant)
    local name = plant.Name
    for _, pType in pairs(PlantTypes) do
        if name:find(pType) then return pType end
    end
    return name
end

-- // Feature Loops
-- Harvest Loop
task.spawn(function()
    while task.wait() do
        local success, err = pcall(function()
            if Flags.AutoHarvest and Remotes.Harvest then
                local harvestBatch = {}
                for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                    if plant:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                        local ripeness = plant:GetAttribute("RipenessStage")
                        local uuid = plant:GetAttribute("Uuid")
                        local pName = GetPlantName(plant)
                        
                        local matchesFilter = (Flags.SelectedHarvest == "All" or Flags.SelectedHarvest == pName)
                        
                        if (ripeness == "Ripe" or ripeness == "Lush") and uuid and matchesFilter then
                            table.insert(harvestBatch, {Uuid = uuid})
                        end
                    end
                end
                
                if #harvestBatch > 0 then
                    Remotes.Harvest:FireServer(harvestBatch)
                end
            end
        end)
        if not success then warn("Harvest Error: " .. err) end
        task.wait(Flags.HarvestInterval)
    end
end)

-- Water Loop
task.spawn(function()
    while task.wait() do
        local success, err = pcall(function()
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
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                end
            end
        end)
        task.wait(Flags.WaterInterval)
    end
end)

-- Sell/Quest/Lucky Loop
task.spawn(function()
    local lastSell = 0
    local lastQuest = 0
    local lastLucky = 0
    
    while task.wait(1) do
        pcall(function()
            -- Auto Sell (Selective supported via backpack check)
            if Flags.AutoSell and Remotes.Sell and (os.time() - lastSell >= Flags.SellInterval) then
                if Flags.SelectedSell == "All" then
                    Remotes.Sell:InvokeServer("SellAll")
                else
                    -- For selective sell, we look for the specific item in backpack
                    -- Note: InvokeServer("SellSingle") usually sells the held item or takes arguments
                    -- We'll try to find the item and sell it
                    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
                        if item.Name:find(Flags.SelectedSell) then
                            -- Equip and sell if needed, or if remote accepts name
                            Remotes.Sell:InvokeServer("SellSingle", item.Name)
                        end
                    end
                end
                lastSell = os.time()
            end

            -- Auto Buy
            if Flags.AutoBuy and Remotes.Shop and Flags.SelectedBuy ~= "None" then
                Remotes.Shop:InvokeServer("SeedShop", Flags.SelectedBuy)
                task.wait(1)
            end

            -- Auto Quest
            if Flags.AutoQuest and Remotes.ClaimQuest and (os.time() - lastQuest >= 60) then
                for _, category in pairs({"Daily", "Weekly"}) do
                    for i = 1, 5 do
                        Remotes.ClaimQuest:FireServer(category, tostring(i))
                    end
                end
                lastQuest = os.time()
            end

            -- Lucky Block
            if Flags.LuckySniper and Remotes.LuckyBlock and (os.time() - lastLucky >= 10) then
                Remotes.LuckyBlock:InvokeServer()
                lastLucky = os.time()
            end
        end)
    end
end)

-- Anti-AFK Logic
LocalPlayer.Idled:Connect(function()
    if Flags.AntiAFK then
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new())
    end
end)

-- // UI Creation
local MainTab = Window:CreateTab("Auto-Farm", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)
local MiscTab = Window:CreateTab("Misc", 4483362458)

-- Auto-Farm Tab Sections
MainTab:CreateSection("Harvesting Settings")
MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(v) Flags.AutoHarvest = v end,
})
MainTab:CreateDropdown({
    Name = "Crop Filter",
    Options = PlantTypes,
    CurrentOption = "All",
    Callback = function(v) Flags.SelectedHarvest = v[1] end,
})
MainTab:CreateSlider({
    Name = "Harvest Delay (seconds)",
    Range = {0.1, 10},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1,
    Callback = function(v) Flags.HarvestInterval = v end,
})

MainTab:CreateSection("Water & Sell Settings")
MainTab:CreateToggle({
    Name = "Auto Water",
    CurrentValue = false,
    Flag = "AutoWater",
    Callback = function(v) Flags.AutoWater = v end,
})
MainTab:CreateToggle({
    Name = "Auto Sell Enabled",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(v) Flags.AutoSell = v end,
})
MainTab:CreateDropdown({
    Name = "Sell Filter",
    Options = PlantTypes,
    CurrentOption = "All",
    Callback = function(v) Flags.SelectedSell = v[1] end,
})
MainTab:CreateSlider({
    Name = "Sell Delay (seconds)",
    Range = {5, 60},
    CurrentValue = 15,
    Callback = function(v) Flags.SellInterval = v end,
})

MainTab:CreateSection("Auto Buy Settings")
MainTab:CreateToggle({
    Name = "Auto Buy Seeds",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(v) Flags.AutoBuy = v end,
})
MainTab:CreateDropdown({
    Name = "Target Seed",
    Options = {"Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"},
    CurrentOption = "Carrot",
    Callback = function(v) Flags.SelectedBuy = v[1] end,
})

-- Visuals Tab
VisualsTab:CreateSection("Visual Enhancements")
VisualsTab:CreateToggle({
    Name = "Mutation ESP",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(v) Flags.MutationESP = v end,
})

-- Misc Tab
MiscTab:CreateSection("Automation Extras")
MiscTab:CreateToggle({
    Name = "Auto Quest (Daily/Weekly)",
    CurrentValue = false,
    Flag = "AutoQuest",
    Callback = function(v) Flags.AutoQuest = v end,
})
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

Rayfield:Notify({
    Title = "Ahok Hub Pro v2",
    Content = "Fixes applied: Improved Corn detection & Interval Sliders added!",
    Duration = 5
})
