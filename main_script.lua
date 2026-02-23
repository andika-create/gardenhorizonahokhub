--[[
    GARDEN HORIZONS ULTIMATE SCRIPT
    Features: Auto-Farm (Harvest/Sell), Mutation ESP, Anti-AFK, Anti-Cheat Mitigation
    UI Library: Rayfield
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Ahok Hub | Garden Horizons",
    LoadingTitle = "Loading Ahok Hub...",
    LoadingSubtitle = "by Ahok Team",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "GardenHorizons",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false
})

-- // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- // Remotes
local Remotes = {
    Harvest = ReplicatedStorage:WaitForChild("HarvestFruit"),
    Plant = ReplicatedStorage:WaitForChild("PlantSeed"),
    Sell = ReplicatedStorage:WaitForChild("SellItems"),
    ClaimQuest = ReplicatedStorage:WaitForChild("ClaimQuest"),
    Integrity = ReplicatedStorage:FindFirstChild("IntegrityCheckProcessorKey2_LocalizationTableAnalyticsSender_LocalizationService")
}

-- // Variables
local Flags = {
    AutoHarvest = false,
    AutoSell = false,
    MutationESP = false,
    AntiAFK = true
}

local ESP_Highlights = {}

-- // Anti-Cheat Mitigation
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if not checkcaller() then
        if (method == "FireServer" or method == "InvokeServer") and (tostring(self):find("Integrity") or tostring(self):find("Analytics")) then
            return nil
        end
    end
    
    return oldNamecall(self, ...)
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Flags.AntiAFK then
        local VirtualUser = game:GetService("VirtualUser")
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- // Helper Functions
local function GetMyPlot()
    -- Look for a plot owned by the local player
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end
    
    for _, plot in pairs(Plots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer then
            return plot
        end
    end
    return nil
end

local function UpdateESP()
    for plant, highlight in pairs(ESP_Highlights) do
        if not plant.Parent then
            highlight:Destroy()
            ESP_Highlights[plant] = nil
        end
    end

    if Flags.MutationESP then
        local myPlot = GetMyPlot()
        if not myPlot then return end
        
        for _, plant in pairs(myPlot:WaitForChild("Plants"):GetChildren()) do
            if plant:IsA("Model") and not ESP_Highlights[plant] then
                local mutation = plant:GetAttribute("Mutation")
                if mutation and mutation ~= "None" then
                    local highlight = Instance.new("Highlight")
                    highlight.Parent = plant
                    highlight.FillColor = (mutation == "Gold" and Color3.fromHex("#FFD700")) or (mutation == "Silver" and Color3.fromHex("#C0C0C0")) or Color3.new(1, 0, 1)
                    highlight.OutlineColor = Color3.new(1, 1, 1)
                    highlight.FillTransparency = 0.5
                    ESP_Highlights[plant] = highlight
                end
            end
        end
    else
        for _, highlight in pairs(ESP_Highlights) do
            highlight:Destroy()
        end
        ESP_Highlights = {}
    end
end

-- // Main Loop
task.spawn(function()
    while task.wait(0.5) do
        local myPlot = GetMyPlot()
        if not myPlot then continue end

        -- Auto Harvest Logic
        if Flags.AutoHarvest then
            for _, plant in pairs(myPlot:WaitForChild("Plants"):GetChildren()) do
                -- Check for 'Stage' or 'Ripe' attributes found in data
                local stage = plant:GetAttribute("Stage")
                local maxStage = plant:GetAttribute("MaxStage") or 4 -- Default to 4 if nil
                
                if (stage and maxStage and stage >= maxStage) or plant:GetAttribute("IsRipe") then
                    Remotes.Harvest:FireServer(plant)
                    -- Random wait to mimic human behavior and avoid detection
                    task.wait(math.random(1, 5) / 10)
                end
            end
        end

        -- Auto Sell Logic
        if Flags.AutoSell then
            -- Only sell if inventory is likely full or at intervals
            -- Assuming the remote handles selling all inventory
            Remotes.Sell:InvokeServer()
            task.wait(5) -- Don't spam sell
        end
        
        -- ESP Update
        UpdateESP()
    end
end)

-- // UI Tabs
local MainTab = Window:CreateTab("Main", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)
local MiscTab = Window:CreateTab("Misc", 4483362458)

MainTab:CreateSection("Auto-Farm")

MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(Value)
        Flags.AutoHarvest = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(Value)
        Flags.AutoSell = Value
    end,
})

MainTab:CreateSection("Quests")

MainTab:CreateButton({
    Name = "Claim Available Quests",
    Callback = function()
        -- Attempt to claim quests
        Remotes.ClaimQuest:FireServer()
        Rayfield:Notify({Title="Quests", Content="Attempted to claim all available quests."})
    end,
})

VisualsTab:CreateSection("ESP")

VisualsTab:CreateToggle({
    Name = "Mutation ESP",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(Value)
        Flags.MutationESP = Value
    end,
})

MiscTab:CreateSection("Utilities")

MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(Value)
        Flags.AntiAFK = Value
    end,
})

MiscTab:CreateButton({
    Name = "Force Reset UI",
    Callback = function()
        Rayfield:Destroy()
    end,
})

Rayfield:Notify({
    Title = "Ready to Garden!",
    Content = "Script loaded. Use the UI to enable features.",
    Duration = 5,
    Image = 4483362458,
})
