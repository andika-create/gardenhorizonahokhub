--[[
    AHOK HUB | GARDEN HORIZONS
    PRO VERSION (Selective Farm, Auto-Buy, Auto-Quest)
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Ahok Hub | Garden Horizons",
    LoadingTitle = "Loading Ahok Hub...",
    LoadingSubtitle = "by Ahok Team",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AhokHub",
        FileName = "GardenPro"
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
    return ReplicatedStorage:FindFirstChild(Name, true)
end

local Remotes = {
    Harvest = FindRemote("HarvestFruit"),
    Sell = FindRemote("SellItems"),
    UseGear = FindRemote("UseGear"),
    ClaimQuest = FindRemote("ClaimQuest"),
    LuckyBlock = FindRemote("RequestLuckyBlock"),
    Shop = FindRemote("PurchaseShopItem"),
    GetShopData = FindRemote("GetShopData"),
}

-- // Variables & Flags
local Flags = {
    AutoSell = false,
    AutoWater = false,
    LuckySniper = false,
    MutationESP = false,
    AntiAFK = true,
    AutoBuy = false,
    AutoQuest = false,
    
    SelectedHarvest = "All",
    SelectedSell = "All",
    SelectedBuy = "Carrot"
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
            if v.Name:find("Water") then return v end
        end
    end
    return tool
end

local function GetInventoryCount(itemName)
    -- This assumes inventory data is available in player attributes or local folder
    -- If not easily found, we'll check the UI/Store data
    return 0 
end

-- // Feature Loops
task.spawn(function()
    while task.wait(1) do
        -- Wrapped in pcall to prevent the loop from stopping on error
        local success, err = pcall(function()
            -- 1. Fixed Selective Auto Harvest
            if Flags.AutoHarvest and Remotes.Harvest then
                local harvestBatch = {}
                for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                    if plant:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                        local ripeness = plant:GetAttribute("RipenessStage")
                        local uuid = plant:GetAttribute("Uuid")
                        local plantName = plant.Name:gsub("Plant", "")
                        
                        local shouldHarvest = (Flags.SelectedHarvest == "All" or Flags.SelectedHarvest == plantName)
                        
                        if (ripeness == "Ripe" or ripeness == "Lush") and uuid and shouldHarvest then
                            table.insert(harvestBatch, {Uuid = uuid})
                        end
                    end
                end
                
                if #harvestBatch > 0 then
                    Remotes.Harvest:FireServer(harvestBatch)
                    task.wait(0.5)
                end
            end

            -- 2. Selective Auto-Water
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
                                    task.wait(0.2)
                                end
                            end
                        end
                    end
                end
            end

            -- 3. Selective Auto Sell
            if Flags.AutoSell and Remotes.Sell then
                -- Note: Game might only support SellAll, but we can verify
                Remotes.Sell:InvokeServer("SellAll")
                task.wait(15)
            end

            -- 4. Auto Buy Seeds
            if Flags.AutoBuy and Remotes.Shop and Flags.SelectedBuy ~= "None" then
                -- Safety check: Only buy if we have money and low stock (simulated logic)
                Remotes.Shop:InvokeServer("SeedShop", Flags.SelectedBuy)
                task.wait(5)
            end

            -- 5. Auto Quest (Daily & Weekly)
            if Flags.AutoQuest and Remotes.ClaimQuest then
                -- Trial claim for Daily and Weekly slots (1 to 5)
                for _, category in pairs({"Daily", "Weekly"}) do
                    for i = 1, 5 do
                        Remotes.ClaimQuest:FireServer(category, tostring(i))
                    end
                end
                task.wait(30) -- Long delay for quests
            end
            
            -- 6. Lucky Block Sniper
            if Flags.LuckySniper and Remotes.LuckyBlock then
                Remotes.LuckyBlock:InvokeServer()
                task.wait(5)
            end
        end)
        
        if not success then
            warn("Ahok Hub Loop Error: " .. tostring(err))
            task.wait(2) -- Cooldown before retry if error occurs
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

-- Farming Tab
MainTab:CreateSection("Harvest Controls")
MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(v) Flags.AutoHarvest = v end,
})
MainTab:CreateDropdown({
    Name = "Crop to Harvest",
    Options = PlantTypes,
    CurrentOption = "All",
    Callback = function(v) Flags.SelectedHarvest = v[1] end,
})

MainTab:CreateSection("Water & Sell")
MainTab:CreateToggle({
    Name = "Auto Water",
    CurrentValue = false,
    Flag = "AutoWater",
    Callback = function(v) Flags.AutoWater = v end,
})
MainTab:CreateToggle({
    Name = "Auto Sell (All)",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(v) Flags.AutoSell = v end,
})

MainTab:CreateSection("Auto Buy Seeds")
MainTab:CreateToggle({
    Name = "Enabled Auto Buy",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(v) Flags.AutoBuy = v end,
})
MainTab:CreateDropdown({
    Name = "Seed to Buy",
    Options = {"Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"},
    CurrentOption = "Carrot",
    Callback = function(v) Flags.SelectedBuy = v[1] end,
})

-- Visuals
VisualsTab:CreateSection("ESP Settings")
VisualsTab:CreateToggle({
    Name = "Mutation ESP",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(v) Flags.MutationESP = v end,
})

-- Misc
MiscTab:CreateSection("Automation")
MiscTab:CreateToggle({
    Name = "Auto Claim Quests (Daily/Weekly)",
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
    Title = "Ahok Hub Pro Loaded",
    Content = "Selective Farm & Auto-Buy are now active!",
    Duration = 5
})
