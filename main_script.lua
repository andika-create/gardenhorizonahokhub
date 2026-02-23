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

-- // Security & Helpers
local function cref(s)
    return (cloneref or function(v) return v end)(s)
end

-- // Robust Remote Detection
local function FindRemote(Name)
    local r = ReplicatedStorage:FindFirstChild(Name, true)
    if not r then warn("Remote not found: " .. Name) end
    return r
end

local Remotes = {
    Harvest = cref(FindRemote("HarvestFruit")),
    Sell = cref(FindRemote("SellItems")),
    UseGear = cref(FindRemote("UseGear")),
    ClaimQuest = cref(FindRemote("ClaimQuest")),
    LuckyBlock = cref(FindRemote("RequestLuckyBlock")),
    Shop = cref(FindRemote("PurchaseShopItem")),
    Spin = cref(FindRemote("RequestSpin")),
    Plant = cref(FindRemote("PlantSeed")),
    Reward = cref(FindRemote("ClaimReward")),
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
    AutoSpin = false,
    AutoPlant = false,
    AutoClaim = false,
    InfiniteZoom = false,
    
    SelectedHarvest = "All",
    SelectedSell = "All",
    SelectedBuy = "Carrot Seed",
    SelectedPlant = "Carrot Seed",
    
    HarvestInterval = 1,
    SellInterval = 15,
    WaterInterval = 0.5,
    PlantInterval = 1,
    ZoomDistance = 128
}

local PlantTypes = {"All", "Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"}
local AllSeeds = {"Carrot Seed", "Corn Seed", "Onion Seed", "Strawberry Seed", "Mushroom Seed", "Beetroot Seed", "Tomato Seed", "Apple Seed"}
local AllGear = {"Watering Can", "Basic Sprinkler", "Harvest Bell", "Turbo Sprinkler", "Favorite Tool"}
local ShopOptions = {}
for _, v in ipairs(AllSeeds) do table.insert(ShopOptions, v) end
for _, v in ipairs(AllGear) do table.insert(ShopOptions, v) end

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
                        local pName = GetPlantName(plant)
                        local matchesFilter = (Flags.SelectedHarvest == "All" or Flags.SelectedHarvest == pName)
                        
                        if matchesFilter then
                            -- Check if the main plant is harvestable (e.g. Carrot, Onion)
                            local uuid = plant:GetAttribute("Uuid")
                            local ripeness = plant:GetAttribute("RipenessStage")
                            local fullyGrown = plant:GetAttribute("FullyGrown")
                            
                            if uuid and (ripeness == "Ripe" or ripeness == "Lush" or fullyGrown) then
                                table.insert(harvestBatch, {Uuid = uuid})
                            end
                            
                            -- Check for regrowable fruits (e.g. Corn, Strawberry) which are children models
                            for _, child in pairs(plant:GetChildren()) do
                                if child:IsA("Model") and child:GetAttribute("FullyGrown") then
                                    local fruitUuid = child:GetAttribute("Uuid")
                                    if fruitUuid then
                                        table.insert(harvestBatch, {Uuid = fruitUuid})
                                    end
                                end
                            end
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

-- Sell/Quest/Lucky/Spin Loop
task.spawn(function()
    local lastSell = 0
    local lastQuest = 0
    local lastLucky = 0
    local lastSpin = 0
    local lastClaim = 0
    
    while task.wait(1) do
        pcall(function()
            -- Auto Sell (Selective supported via backpack check)
            if Flags.AutoSell and Remotes.Sell and (os.time() - lastSell >= Flags.SellInterval) then
                if Flags.SelectedSell == "All" then
                    Remotes.Sell:InvokeServer("SellAll")
                else
                    -- For selective sell, we must equip the item first for "SellSingle" logic
                    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
                        if item.Name:find(Flags.SelectedSell) and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                            LocalPlayer.Character.Humanoid:EquipTool(item)
                            task.wait(0.2)
                            Remotes.Sell:InvokeServer("SellSingle")
                        end
                    end
                end
                lastSell = os.time()
            end

            -- Auto Buy
            if Flags.AutoBuy and Remotes.Shop and Flags.SelectedBuy ~= "None" then
                pcall(function()
                    local shopType = table.find(AllGear, Flags.SelectedBuy) and "GearShop" or "SeedShop"
                    -- Correct key removal of " Seed" for remote if needed, but game data shows keys are "Carrot", "Corn"
                    local cleanName = Flags.SelectedBuy:gsub(" Seed", "")
                    Remotes.Shop:InvokeServer(shopType, cleanName)
                end)
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

            -- Auto Spin
            if Flags.AutoSpin and Remotes.Spin and (os.time() - lastSpin >= 10) then
                Remotes.Spin:InvokeServer()
                lastSpin = os.time()
            end

            -- Auto Claim Rewards
            if Flags.AutoClaim and Remotes.Reward and (os.time() - lastClaim >= 300) then
                Remotes.Reward:FireServer()
                lastClaim = os.time()
            end
        end)
    end
end)

-- Auto Plant Loop
task.spawn(function()
    while task.wait(1) do
        if Flags.AutoPlant and Remotes.Plant then
            pcall(function()
                local plots = workspace:FindFirstChild("Plots")
                if not plots then return end
                
                local myPlot = nil
                for _, plot in pairs(plots:GetChildren()) do
                    if plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                        myPlot = plot
                        break
                    end
                end
                
                if myPlot then
                    local plantableAreas = {}
                    for _, child in pairs(myPlot:GetChildren()) do
                        if child.Name == "PlantableArea" then
                            table.insert(plantableAreas, child)
                        end
                    end
                    
                    if #plantableAreas > 0 then
                        local selectedArea = plantableAreas[math.random(1, #plantableAreas)]
                        local cleanName = Flags.SelectedPlant:gsub(" Seed", "")
                        -- Planting at the area position
                        Remotes.Plant:InvokeServer(cleanName, selectedArea.Position)
                    end
                end
            end)
            task.wait(Flags.PlantInterval)
        end
    end
end)

-- Visual Zoom Loop
task.spawn(function()
    while task.wait(1) do
        if Flags.InfiniteZoom then
            LocalPlayer.CameraMaxZoomDistance = Flags.ZoomDistance
        end
    end
end)

-- Visual ESP Loop
local ESPObjects = {}
local function CreateESP(part, name)
    local bbg = Instance.new("BillboardGui")
    bbg.Size = UDim2.new(0, 100, 0, 50)
    bbg.Adornee = part
    bbg.AlwaysOnTop = true
    
    local label = Instance.new("TextLabel", bbg)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 0, 255) -- Purple for mutations
    label.TextStrokeTransparency = 0
    label.Text = "[MUTATION: " .. name .. "]"
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    
    bbg.Parent = part
    table.insert(ESPObjects, bbg)
end

task.spawn(function()
    while task.wait(1) do
        if Flags.MutationESP then
            for _, obj in pairs(ESPObjects) do if obj then obj:Destroy() end end
            ESPObjects = {}
            for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                if plant:GetAttribute("Mutation") then
                    local pName = GetPlantName(plant)
                    local root = plant:FindFirstChild("PrimaryPart") or plant:FindFirstChildWhichIsA("BasePart")
                    if root then
                        CreateESP(root, pName)
                    end
                end
            end
        else
            if #ESPObjects > 0 then
                for _, obj in pairs(ESPObjects) do if obj then obj:Destroy() end end
                ESPObjects = {}
            end
        end
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
    Name = "Auto Buy Items",
    CurrentValue = false,
    Flag = "AutoBuy",
    Callback = function(v) Flags.AutoBuy = v end,
})
MainTab:CreateDropdown({
    Name = "Select Item to Buy",
    Options = ShopOptions,
    CurrentOption = "Carrot Seed",
    Callback = function(v) Flags.SelectedBuy = v[1] end,
})

MainTab:CreateSection("Auto Plant Settings")
MainTab:CreateToggle({
    Name = "Auto Plant Enabled",
    CurrentValue = false,
    Flag = "AutoPlant",
    Callback = function(v) Flags.AutoPlant = v end,
})
MainTab:CreateDropdown({
    Name = "Select Seed to Plant",
    Options = AllSeeds,
    CurrentOption = "Carrot Seed",
    Callback = function(v) Flags.SelectedPlant = v[1] end,
})
MainTab:CreateSlider({
    Name = "Plant Delay (seconds)",
    Range = {0.1, 5},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = 1,
    Callback = function(v) Flags.PlantInterval = v end,
})

-- Visuals Tab
VisualsTab:CreateSection("Visual Enhancements")
VisualsTab:CreateToggle({
    Name = "Mutation ESP",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(v) Flags.MutationESP = v end,
})
VisualsTab:CreateToggle({
    Name = "Infinite Zoom",
    CurrentValue = false,
    Flag = "InfiniteZoom",
    Callback = function(v) Flags.InfiniteZoom = v end,
})
VisualsTab:CreateSlider({
    Name = "Zoom Distance",
    Range = {128, 5000},
    CurrentValue = 128,
    Callback = function(v) Flags.ZoomDistance = v end,
})

-- Misc Tab
MiscTab:CreateSection("Automation Extras")
MiscTab:CreateToggle({
    Name = "Auto Spin (RNG Wheel)",
    CurrentValue = false,
    Flag = "AutoSpin",
    Callback = function(v) Flags.AutoSpin = v end,
})
MiscTab:CreateToggle({
    Name = "Auto Claim Rewards",
    CurrentValue = false,
    Flag = "AutoClaim",
    Callback = function(v) Flags.AutoClaim = v end,
})
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
    Title = "Ahok Hub Pro v3",
    Content = "Update: Auto-Spin, Auto-Plant & Infinite Zoom added!",
    Duration = 5
})
