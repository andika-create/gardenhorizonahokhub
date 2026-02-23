--[[
    AHOK HUB | GARDEN HORIZONS
    Robust Version (Fixed Remote Detection)
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
local LocalPlayer = Players.LocalPlayer

-- // Robust Remote Detection
local function FindRemote(Name)
    local remote = ReplicatedStorage:FindFirstChild(Name, true)
    if not remote then
        warn("[Ahok Hub] Could not find remote: " .. Name)
        Rayfield:Notify({Title="Debug", Content="Missing Remote: " .. Name, Duration=10})
    end
    return remote
end

local Remotes = {
    Harvest = FindRemote("HarvestFruit"),
    Plant = FindRemote("PlantSeed"),
    Sell = FindRemote("SellItems"),
    ClaimQuest = FindRemote("ClaimQuest"),
}

-- Check if core remotes are missing
if not Remotes.Harvest then
    Rayfield:Notify({
        Title = "Warning",
        Content = "Core game remotes not found. Some features may not work.",
        Duration = 10
    })
end

-- // Variables
local Flags = {
    AutoHarvest = false,
    AutoSell = false,
    MutationESP = false,
    AntiAFK = true
}

-- // Minimal Security Hook (Less likely to cause 'Anomality')
local success, err = pcall(function()
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if not checkcaller() then
            -- Block specific analytics/integrity remotes by name match
            local name = tostring(self)
            if (method == "FireServer") and (name:find("Integrity") or name:find("Analytics")) then
                return nil
            end
        end
        return oldNamecall(self, ...)
    end)
end)

if not success then
    warn("[Ahok Hub] Hook failed: " .. tostring(err))
end

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if Flags.AntiAFK then
        local VirtualUser = game:GetService("VirtualUser")
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- // Logic
local function GetMyPlot()
    local Plots = workspace:FindFirstChild("Plots")
    if not Plots then return nil end
    for _, plot in pairs(Plots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner")
        if owner and owner.Value == LocalPlayer then return plot end
    end
    return nil
end

local function MainLoop()
    while task.wait(0.5) do
        if Flags.AutoHarvest and Remotes.Harvest then
            local myPlot = GetMyPlot()
            if myPlot then
                local plants = myPlot:FindFirstChild("Plants")
                if plants then
                    for _, plant in pairs(plants:GetChildren()) do
                        if plant:GetAttribute("IsRipe") or (plant:GetAttribute("Stage") and plant:GetAttribute("MaxStage") and plant:GetAttribute("Stage") >= plant:GetAttribute("MaxStage")) then
                            Remotes.Harvest:FireServer(plant)
                            task.wait(0.2)
                        end
                    end
                end
            end
        end

        if Flags.AutoSell and Remotes.Sell then
            Remotes.Sell:InvokeServer()
            task.wait(10)
        end
    end
end

-- // UI
local MainTab = Window:CreateTab("Main", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483345998)
local MiscTab = Window:CreateTab("Misc", 4483362458)

MainTab:CreateSection("Auto-Farm")
MainTab:CreateToggle({
    Name = "Auto Harvest",
    CurrentValue = false,
    Flag = "AutoHarvest",
    Callback = function(v) Flags.AutoHarvest = v end,
})
MainTab:CreateToggle({
    Name = "Auto Sell",
    CurrentValue = false,
    Flag = "AutoSell",
    Callback = function(v) Flags.AutoSell = v end,
})

VisualsTab:CreateSection("ESP")
VisualsTab:CreateToggle({
    Name = "Mutation ESP (Beta)",
    CurrentValue = false,
    Flag = "MutationESP",
    Callback = function(v) Flags.MutationESP = v end,
})

MiscTab:CreateSection("Utilities")
MiscTab:CreateToggle({
    Name = "Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(v) Flags.AntiAFK = v end,
})

task.spawn(MainLoop)

Rayfield:Notify({
    Title = "Ahok Hub Loaded",
    Content = "Script is running. If UI doesn't appear, check console (F9).",
    Duration = 5
})
