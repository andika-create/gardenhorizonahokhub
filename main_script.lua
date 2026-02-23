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

-- // Security & Helpers
local function cref(s)
    return (cloneref or function(v) return v end)(s)
end

local ReplicatedStorage = cref(game:GetService("ReplicatedStorage"))
local Players = cref(game:GetService("Players"))
local CollectionService = cref(game:GetService("CollectionService"))
local RunService = cref(game:GetService("RunService"))
local LocalPlayer = Players.LocalPlayer

-- // Robust Remote Detection
local function FindRemote(Name)
    local r = ReplicatedStorage:FindFirstChild(Name, true)
    if not r then warn("Remote not found: " .. Name) end
    return cref(r)
end

local Remotes = {
    Harvest = FindRemote("HarvestFruit"),
    Sell = FindRemote("SellItems"),
    UseGear = FindRemote("UseGear"),
    ClaimQuest = FindRemote("ClaimQuest"),
    LuckyBlock = FindRemote("RequestLuckyBlock"),
    Shop = FindRemote("PurchaseShopItem"),
    Spin = FindRemote("RequestSpin"),
    Plant = FindRemote("PlantSeed"),
    Reward = FindRemote("ClaimReward"),
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
    
    SelectedHarvest = {},
    SelectedSell = {},
    SelectedBuy = {},
    SelectedPlant = {},
    
    HarvestInterval = 1,
    SellInterval = 15,
    WaterInterval = 0.5,
    PlantInterval = 1,
    ZoomDistance = 128,
    MasterAFK = false,
    UI_Ready = false
}

local PlantTypesOnly = {"Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"}
local AllSeeds = {"Carrot Seed", "Corn Seed", "Onion Seed", "Strawberry Seed", "Mushroom Seed", "Beetroot Seed", "Tomato Seed", "Apple Seed"}
local AllGear = {"Watering Can", "Basic Sprinkler", "Harvest Bell", "Turbo Sprinkler", "Favorite Tool"}
local PlantTypesWithAll = {"All", "Carrot", "Corn", "Onion", "Strawberry", "Mushroom", "Beetroot", "Tomato", "Apple"}

-- Initialize filters
for _, p in pairs(PlantTypesOnly) do Flags.SelectedHarvest[p] = true end
for _, p in pairs(PlantTypesOnly) do Flags.SelectedSell[p] = true end
for _, s in pairs(AllSeeds) do Flags.SelectedBuy[s] = false end
for _, g in pairs(AllGear) do Flags.SelectedBuy[g] = false end
for _, s in pairs(AllSeeds) do Flags.SelectedPlant[s] = false end
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
    for _, pType in pairs(PlantTypesOnly) do
        if name:find(pType) then return pType end
    end
    return name
end

-- // Feature Loops
-- Harvest Loop (Fixed: correct attribute names, skip IsHarvested, regrowable-safe)
task.spawn(function()
    while task.wait() do
        local success, err = pcall(function()
            if Flags.AutoHarvest and Remotes.Harvest then
                local harvestBatch = {}
                
                -- Scan object and descendants for harvestable fruits
                local function ScanForHarvest(object)
                    -- Skip already-harvested / bare regrowable stalks
                    if object:GetAttribute("IsHarvested") then return end
                    
                    local uuid = object:GetAttribute("Uuid")
                    local fullyGrown = object:GetAttribute("FullyGrown")
                    local ripeness = object:GetAttribute("RipenessStage")
                    
                    if uuid and (fullyGrown == true or ripeness == "Ripe" or ripeness == "Lush") then
                        table.insert(harvestBatch, {Uuid = uuid})
                    end
                    
                    for _, child in pairs(object:GetChildren()) do
                        ScanForHarvest(child)
                    end
                end

                -- Find player's plot (game uses "Owner" attribute, not "OwnerUserId")
                local plots = workspace:FindFirstChild("Plots")
                if plots then
                    for _, plot in pairs(plots:GetChildren()) do
                        if plot:GetAttribute("Owner") == LocalPlayer.UserId then
                            -- Scan plants on my plot
                            for _, plant in pairs(plot:GetDescendants()) do
                                if plant:IsA("Model") and plant:GetAttribute("PlantType") then
                                    local pName = GetPlantName(plant)
                                    if Flags.SelectedHarvest[pName] then
                                        ScanForHarvest(plant)
                                    end
                                end
                            end
                            break
                        end
                    end
                end
                
                -- Fallback: use CollectionService tagged plants
                if #harvestBatch == 0 then
                    for _, plant in pairs(CollectionService:GetTagged("Plant")) do
                        if plant:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                            local pName = GetPlantName(plant)
                            if Flags.SelectedHarvest[pName] and not plant:GetAttribute("IsHarvested") then
                                ScanForHarvest(plant)
                            end
                        end
                    end
                end
                
                if #harvestBatch > 0 then
                    Remotes.Harvest:FireServer(harvestBatch)
                end
            end
        end)
        if not success then warn("Harvest Error: " .. tostring(err)) end
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
            -- Auto Sell (Fixed: game uses SellAll remote - SellSingle doesn't exist)
            if Flags.AutoSell and Remotes.Sell and (os.time() - lastSell >= Flags.SellInterval) then
                pcall(function()
                    Remotes.Sell:InvokeServer("SellAll")
                end)
                lastSell = os.time()
            end

            -- Auto Buy (Standard Items - Supports Multiple Seeds & Gear)
            if Flags.AutoBuy and Remotes.Shop then
                for item, enabled in pairs(Flags.SelectedBuy) do
                    if enabled then
                        pcall(function()
                            local shopType = table.find(AllGear, item) and "GearShop" or "SeedShop"
                            -- Fix: Send full name (e.g. "Carrot Seed") as required by PurchaseShopItem
                            Remotes.Shop:InvokeServer(shopType, item)
                        end)
                        task.wait(0.5)
                    end
                end
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

-- Auto Plant Loop (Fixed: Owner attr, PlantableArea is a Folder with Part children)
task.spawn(function()
    while task.wait(1) do
        if Flags.AutoPlant and Remotes.Plant then
            local success, err = pcall(function()
                local plots = workspace:FindFirstChild("Plots")
                if not plots then return end
                
                -- FIXED: game uses "Owner" attribute for plots, not "OwnerUserId"
                local myPlot = nil
                for _, plot in pairs(plots:GetChildren()) do
                    if plot:GetAttribute("Owner") == LocalPlayer.UserId then
                        myPlot = plot
                        break
                    end
                end
                
                if myPlot then
                    -- FIXED: PlantableArea is a Folder that contains BasePart children
                    local areas = {}
                    local plantableFolder = myPlot:FindFirstChild("PlantableArea")
                    if plantableFolder then
                        for _, child in pairs(plantableFolder:GetChildren()) do
                            if child:IsA("BasePart") then
                                table.insert(areas, child)
                            end
                        end
                    else
                        -- Fallback: look for any BasePart inside the plot
                        for _, child in pairs(myPlot:GetDescendants()) do
                            if child:IsA("BasePart") and child.Name:lower():find("plant") then
                                table.insert(areas, child)
                            end
                        end
                    end
                    
                    if #areas > 0 then
                        for seed, enabled in pairs(Flags.SelectedPlant) do
                            if enabled then
                                local area = areas[math.random(1, #areas)]
                                local sz = area.Size
                                local cf = area.CFrame
                                
                                -- Random position on top surface of plantable part
                                local rx = (math.random() - 0.5) * (sz.X * 0.8)
                                local rz = (math.random() - 0.5) * (sz.Z * 0.8)
                                local pos = (cf * CFrame.new(rx, sz.Y / 2, rz)).Position
                                
                                local seedType = seed:gsub(" Seed", "")
                                pcall(function()
                                    Remotes.Plant:InvokeServer(seedType, pos)
                                end)
                                task.wait(0.3)
                            end
                        end
                    else
                        warn("AutoPlant: No PlantableArea parts found on plot!")
                    end
                else
                    warn("AutoPlant: Could not find your plot (Owner attribute check). Make sure you have a plot!")
                end
            end)
            if not success then warn("Plant Error: " .. tostring(err)) end
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

-- Anti-AFK Logic (Pro Version)
task.spawn(function()
    while task.wait(30) do
        if Flags.AntiAFK then
            pcall(function()
                local vu = cref(game:GetService("VirtualUser"))
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
        end
    end
end)

-- // UI Creation
local MainTab = Window:CreateTab("Auto-Farm", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)
local MiscTab = Window:CreateTab("Misc", 4483362458)

MainTab:CreateSection("Master Controls")
MainTab:CreateToggle({
    Name = "MASTER AFK (Enable All)",
    CurrentValue = false,
    Flag = "MasterAFK",
    Callback = function(v) 
        Flags.MasterAFK = v
        if v then
            Flags.AutoHarvest = true
            Flags.AutoWater = true
            Flags.AutoSell = true
            Flags.AutoBuy = true
            Flags.AutoPlant = true
            Flags.AutoQuest = true
            Flags.AutoSpin = true
            Flags.AutoClaim = true
            Flags.AntiAFK = true
            
            -- Enable all filters for maximum AFK
            for p, _ in pairs(Flags.SelectedHarvest) do Flags.SelectedHarvest[p] = true end
            for p, _ in pairs(Flags.SelectedSell) do Flags.SelectedSell[p] = true end
            for s, _ in pairs(Flags.SelectedBuy) do Flags.SelectedBuy[s] = true end
            for s, _ in pairs(Flags.SelectedPlant) do Flags.SelectedPlant[s] = true end
            
            Rayfield:Notify({Title = "Master AFK", Content = "All features and filters enabled for 24/7 AFK!", Duration = 5})
        end
    end,
})

-- Auto-Farm Tab Sections
MainTab:CreateSection("Harvesting Settings")
MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(v) Flags.AutoHarvest = v end,
})
MainTab:CreateSection("Harvest Filters (Multiple)")
for _, p in pairs(PlantTypesOnly) do
    MainTab:CreateToggle({
        Name = "Harvest " .. p,
        CurrentValue = Flags.SelectedHarvest[p],
        Callback = function(v) Flags.SelectedHarvest[p] = v end,
    })
end

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
MainTab:CreateSection("Sell Filters (Multiple)")
for _, p in pairs(PlantTypesOnly) do
    MainTab:CreateToggle({
        Name = "Sell " .. p,
        CurrentValue = Flags.SelectedSell[p],
        Callback = function(v) Flags.SelectedSell[p] = v end,
    })
end
MainTab:CreateSlider({
    Name = "Sell Delay (seconds)",
    Range = {5, 60},
    CurrentValue = 15,
    Callback = function(v) Flags.SellInterval = v end,
})

MainTab:CreateSection("Auto Buy Settings")
MainTab:CreateToggle({
    Name = "Auto Buy Enabled",
    CurrentValue = Flags.AutoBuy,
    Callback = function(v) Flags.AutoBuy = v end,
})
MainTab:CreateSection("Buy Filters (Multiple)")
for _, s in pairs(AllSeeds) do
    MainTab:CreateToggle({
        Name = "Buy " .. s,
        CurrentValue = Flags.SelectedBuy[s],
        Callback = function(v) Flags.SelectedBuy[s] = v end,
    })
end
for _, g in pairs(AllGear) do
    MainTab:CreateToggle({
        Name = "Buy " .. g,
        CurrentValue = Flags.SelectedBuy[g],
        Callback = function(v) Flags.SelectedBuy[g] = v end,
    })
end

MainTab:CreateSection("Auto Plant Settings")
MainTab:CreateToggle({
    Name = "Auto Plant Enabled",
    CurrentValue = Flags.AutoPlant,
    Callback = function(v) Flags.AutoPlant = v end,
})
MainTab:CreateSection("Plant Filters (Multiple)")
for _, s in pairs(AllSeeds) do
    MainTab:CreateToggle({
        Name = "Plant " .. s,
        CurrentValue = Flags.SelectedPlant[s],
        Callback = function(v) Flags.SelectedPlant[s] = v end,
    })
end

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
