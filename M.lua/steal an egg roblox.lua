-- ==============================================================================
--  HYPER HUB - Steal an Egg Roblox  v4.0
--  Features: God Mode, 3-Stage Fly, Noclip, Speed,
--            ESP (EggState + AskEggRecord), Earning Calc,
--            Auto Round-Trip TP (Egg<->Home), Red Beam Trail
--  Created by K2NTA ST | Project Singularity
-- ==============================================================================

local _cloneref = (cloneref or function(...) return ... end)
local function getService(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    return ok and _cloneref(s) or nil
end

local Players              = getService("Players")
local RunService           = getService("RunService")
local TweenService         = getService("TweenService")
local UserInputService     = getService("UserInputService")
local Workspace            = getService("Workspace")
local ReplicatedStorage    = getService("ReplicatedStorage") or game:GetService("ReplicatedStorage")
local ProximityPromptService = getService("ProximityPromptService") or game:GetService("ProximityPromptService")
local LocalPlayer          = Players.LocalPlayer

-- ==============================================================================
-- // UI Library Loader
-- ==============================================================================
local env = (getgenv and getgenv()) or _G
local Library
if env.HYPER_UI and type(env.HYPER_UI) == "table" and env.HYPER_UI.Window then
    Library = env.HYPER_UI
elseif env.Library and type(env.Library) == "table" and env.Library.Window then
    Library = env.Library
else
    local function cleanLua(str)
        if type(str) ~= "string" then return "" end
        return str:gsub("^98791", ""):gsub("^%s+", "")
    end
    if typeof(isfile) == "function" and typeof(readfile) == "function" then
        local paths = { "ui.lua", "UI.main/ui.lua", "Scripts/UI.main/ui.lua", "Scripts/ui.lua", "HYPER_Cache/ui.lua" }
        for _, p in ipairs(paths) do
            if isfile(p) then
                local content = cleanLua(readfile(p))
                if #content > 50 then
                    local fn = loadstring(content)
                    if fn then
                        local ok, lib = pcall(fn)
                        if ok and type(lib) == "table" and lib.Window then
                            Library = lib; env.HYPER_UI = lib; break
                        end
                    end
                end
            end
        end
    end
    if not Library then
        local urls = { "https://raw.githubusercontent.com/projecthyper10-stack/HYPER-LOADER/refs/heads/main/UI.main/ui.lua" }
        local req = (request or http_request or (syn and syn.request) or (http and http.request))
        for _, u in ipairs(urls) do
            local s, src = pcall(function()
                if req then
                    local r = req({ Url = u, Method = "GET" })
                    if r and (r.StatusCode == 200 or r.Status == 200) and r.Body and #r.Body > 50 then return r.Body end
                end
                return game:HttpGet(u)
            end)
            if s and src and type(src) == "string" and #src > 50 then
                src = cleanLua(src)
                local fn = loadstring(src)
                if fn then
                    local ok, lib = pcall(fn)
                    if ok and type(lib) == "table" and lib.Window then
                        Library = lib; env.HYPER_UI = lib; break
                    end
                end
            end
        end
    end
    if not Library or not Library.Window then
        error("[HYPER HUB] Failed to load UI Library!")
    end
end

-- ==============================================================================
-- // Zone Coordinates
-- ==============================================================================
local Zones = {
    ["Home"]    = Vector3.new(539, 70, -364),
    ["Zone 1"]  = Vector3.new(605, 70, -368),
    ["Zone 2"]  = Vector3.new(716, 70, -368),
    ["Zone 3"]  = Vector3.new(889, 70, -366),
    ["Zone 4"]  = Vector3.new(1136, 70, -364),
    ["Zone 5"]  = Vector3.new(1491, 70, -361),
    ["Zone 6"]  = Vector3.new(1885, 70, -358),
    ["Zone 7"]  = Vector3.new(2284, 70, -355),
    ["Zone 8"]  = Vector3.new(2809, 70, -355),
    ["Zone 9"]  = Vector3.new(3389, 70, -357),
    ["Zone 10"] = Vector3.new(4021, 70, -359),
    ["Zone 11"] = Vector3.new(4787, 70, -375),
    ["Zone 12"] = Vector3.new(5997, 71, -364),
}
local ZoneOrder = {
    "Home","Zone 1","Zone 2","Zone 3","Zone 4","Zone 5",
    "Zone 6","Zone 7","Zone 8","Zone 9","Zone 10","Zone 11","Zone 12"
}

-- ==============================================================================
-- // State
-- ==============================================================================
local State = {
    SelectedZone       = "Home",
    TweenSpeed         = 500,
    AscendSpeed        = 380,
    DescendSpeed       = 220,
    TweenHeight        = 160,
    IsTweening         = false,
    CurrentTween       = nil,
    GodMode            = true,
    Noclip             = false,
    InfJump            = false,
    AutoDoffTreadmill  = true,
    InstantPrompt      = true,
    FaceDown           = false,
    FaceDownConnection = nil,
    HeadDown           = false,
    HeadDownConnection = nil,
    NoclipConnection   = nil,
    WalkSpeed          = 16,
    JumpPower          = 50,
    EggESP             = true,
    ESP_Highlight      = true,
    ESP_ShowMutations  = true,
    ESP_ShowDistance   = true,
    ESP_MaxDistance    = 5000,
    ESP_Filter         = "All",
    AutoTP_Running     = false,
    AutoTP_EggPos      = nil,
    AutoTP_HomePos     = Vector3.new(532, 71, -356),
    AutoTP_Speed       = 500,
    AutoTP_Delay       = 0.5,
    AutoTP_Thread      = nil,
    RedTrail           = true,
    SpeedMethod        = "WalkSpeed",
}

-- ==============================================================================
-- // Metamethod Hook (Speed/Jump Spoofing & Protection)
-- ==============================================================================
pcall(function()
    if hookmetamethod and checkcaller then
        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if not checkcaller() and self:IsA("Humanoid") then
                if key == "WalkSpeed" then return 16 end
                if key == "JumpPower" then return 50 end
            end
            return oldIndex(self, key)
        end)

        local oldNewIndex
        oldNewIndex = hookmetamethod(game, "__newindex", function(self, key, value)
            if not checkcaller() and self:IsA("Humanoid") then
                if key == "WalkSpeed" then return end
                if key == "JumpPower" then return end
            end
            return oldNewIndex(self, key, value)
        end)
    end
end)

-- ==============================================================================
-- // Game Module References (EggState, Assets, Mutations)
-- ==============================================================================
local EggStateModule  = nil
local AssetsModule    = nil
local MutationsModule = nil

-- Try multiple paths for EggState
local function tryLoadEggState()
    -- Method 1: Standard path ReplicatedStorage.Client.EggState
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Client")
        local m = client and client:FindFirstChild("EggState")
        if m then EggStateModule = require(m) end
    end)
    if EggStateModule then return end
    -- Method 2: Find anywhere in ReplicatedStorage
    pcall(function()
        local m = ReplicatedStorage:FindFirstChild("EggState", true)
        if m then EggStateModule = require(m) end
    end)
    if EggStateModule then return end
    -- Method 3: getgenv hook (already loaded by game)
    pcall(function()
        local genv = (getgenv and getgenv()) or _G
        if genv.EggState and type(genv.EggState) == "table" and genv.EggState.ReadFieldEggs then
            EggStateModule = genv.EggState
        end
    end)
end
pcall(tryLoadEggState)

pcall(function()
    local data = ReplicatedStorage:FindFirstChild("Data")
    if data then AssetsModule = require(data:FindFirstChild("Assets")) end
end)
pcall(function()
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local mods   = shared and shared:FindFirstChild("Modules")
    if mods then MutationsModule = require(mods:FindFirstChild("Mutations")) end
end)

local AskEggRecordRF = nil
local function tryFindAskEggRecord()
    pcall(function()
        local pkgs = ReplicatedStorage:FindFirstChild("Packages")
        local net  = pkgs and pkgs:FindFirstChild("Networking")
        AskEggRecordRF = net and net:FindFirstChild("RF/EggWorld/AskEggRecord")
    end)
    if AskEggRecordRF then return end
    pcall(function()
        AskEggRecordRF = ReplicatedStorage:FindFirstChild("RF/EggWorld/AskEggRecord", true)
    end)
end
pcall(tryFindAskEggRecord)

-- ==============================================================================
-- // Earning Calculator
-- ==============================================================================
local function scalePayoutFactor(scale)
    scale = tonumber(scale) or 1
    if scale <= 5 then return scale ^ 1.85 end
    return (scale / 5) ^ 1.2 * 19.637875755794113
end

local function GetEarningPerSecond(eggData)
    if not AssetsModule or not MutationsModule then return nil end
    local ok, result = pcall(function()
        local cat  = eggData.AssetCategory or eggData.Category or "None"
        local dir  = AssetsModule.Directory
        local er   = dir and dir[cat] and dir[cat].EarningRate or 0
        local sr   = scalePayoutFactor(eggData.AssetScale or eggData.Scale or 1)
        local mr   = MutationsModule.EarningsFor(eggData.Mutations) or 1
        return math.max(1, math.round(er * sr * mr))
    end)
    return ok and result or nil
end

-- ==============================================================================
-- // Notify (forward-declared Window)
-- ==============================================================================
local Window
local function notify(title, desc, icon, time)
    if Window and Window.Notify then
        Window:Notify({ Title=title, Desc=desc, Icon=icon or "rbxassetid://10709791437", Time=time or 3 })
    elseif Library and Library.Notify then
        Library:Notify({ Title=title, Desc=desc, Icon=icon or "rbxassetid://10709791437", Time=time or 3 })
    end
end

-- ==============================================================================
-- // Character Helpers
-- ==============================================================================
local function getCharacter() return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait() end
local function getHRP()
    local c = getCharacter()
    return c:FindFirstChild("HumanoidRootPart") or c:WaitForChild("HumanoidRootPart", 3)
end
local function getHumanoid()
    local c = getCharacter()
    return c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 3)
end

-- ==============================================================================
-- // God Mode Engine
-- ==============================================================================
local H = RunService
local R  = H.RenderStepped
local RE = H.RenderStepped.Wait
local currentCharacter = nil
local currentHumanoid  = nil
local godConnections   = {}

local function cleanupGodConnections()
    for _, conn in ipairs(godConnections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then conn:Disconnect() end
    end
    table.clear(godConnections)
end

local function restoreHealth(hum)
    if not hum or not hum.Parent then return end
    pcall(function()
        if hum.MaxHealth < 100 then hum.MaxHealth = 100 end
        hum.Health = hum.MaxHealth
    end)
end

local function setupGodState(character)
    if not character then return end
    local oldHumanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
    if not oldHumanoid then return end
    cleanupGodConnections()

    local humanoid = oldHumanoid
    if not oldHumanoid:GetAttribute("IsGodHumanoid") then
        local ok, cloned = pcall(function()
            local newHum = oldHumanoid:Clone()
            newHum.Name = "Humanoid"
            newHum:SetAttribute("IsGodHumanoid", true)
            newHum.Parent = character
            oldHumanoid:Destroy()
            return newHum
        end)
        if ok and cloned then
            humanoid = cloned
            pcall(function()
                local camera = Workspace.CurrentCamera
                if camera then camera.CameraSubject = humanoid end
            end)
            pcall(function()
                local animate = character:FindFirstChild("Animate")
                if animate and animate:IsA("LocalScript") then
                    animate.Disabled = true; task.wait(0.05); animate.Disabled = false
                end
            end)
        end
    end

    currentCharacter = character
    currentHumanoid  = humanoid
    humanoid.BreakJointsOnDeath = false
    pcall(function() humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
    restoreHealth(humanoid)

    table.insert(godConnections, humanoid.StateChanged:Connect(function(_, state)
        if State.GodMode and state == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp); restoreHealth(humanoid)
        end
    end))
    table.insert(godConnections, H.Heartbeat:Connect(function()
        if not State.GodMode or not character or not character.Parent or not humanoid or not humanoid.Parent then return end
        if humanoid:GetState() == Enum.HumanoidStateType.Dead then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
        if humanoid.Health <= 0 or humanoid.Health < humanoid.MaxHealth then restoreHealth(humanoid) end
    end))
    table.insert(godConnections, H.RenderStepped:Connect(function()
        if not State.GodMode or not character or not character.Parent or not humanoid or not humanoid.Parent then return end
        if humanoid.Health < humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
    end))

    local jumping = false
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Space then
            jumping = true
            task.spawn(function()
                while jumping do
                    if humanoid and humanoid.Parent then humanoid.Jump = true end
                    task.wait(0.1)
                end
            end)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space then
            jumping = false
            if humanoid then humanoid.Jump = false end
        end
    end)
end

task.spawn(function()
    while true do
        if State.GodMode and currentHumanoid and currentHumanoid.Parent then
            if currentHumanoid.Health < currentHumanoid.MaxHealth then
                currentHumanoid.Health = currentHumanoid.MaxHealth
            end
        end
        RE(R)
    end
end)

if LocalPlayer.Character then task.spawn(setupGodState, LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(function(char) task.wait(0.2); setupGodState(char) end)

local function toggleGodMode(enabled)
    State.GodMode = enabled
    if enabled then
        if LocalPlayer.Character then setupGodState(LocalPlayer.Character) end
        notify("GOD MODE", "Recreate Humanoid Active", "rbxassetid://10709791437", 2.5)
    else
        cleanupGodConnections()
        if currentHumanoid then pcall(function() currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end) end
        notify("GOD MODE", "Disabled", "rbxassetid://10709791437", 2.5)
    end
end

-- ==============================================================================
-- // Noclip
-- ==============================================================================
local function toggleNoclip(enabled)
    State.Noclip = enabled
    if enabled then
        if State.NoclipConnection then State.NoclipConnection:Disconnect() end
        State.NoclipConnection = RunService.Stepped:Connect(function()
            if not State.Noclip then
                if State.NoclipConnection then State.NoclipConnection:Disconnect(); State.NoclipConnection = nil end
                return
            end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
                end
            end
        end)
    else
        if State.NoclipConnection then State.NoclipConnection:Disconnect(); State.NoclipConnection = nil end
    end
end

-- ==============================================================================
-- // RED BEAM TRAIL SYSTEM
-- ==============================================================================
local ActiveTrailFolder = nil

local function clearRedTrail()
    if ActiveTrailFolder and ActiveTrailFolder.Parent then
        ActiveTrailFolder:Destroy(); ActiveTrailFolder = nil
    end
end

local function createRedTrail(fromPos, toPos)
    clearRedTrail()
    if not State.RedTrail then return end

    local folder = Instance.new("Folder")
    folder.Name  = "HyperRedTrail"; folder.Parent = Workspace
    local terrain = Workspace.Terrain

    local a0 = Instance.new("Attachment"); a0.WorldPosition = fromPos + Vector3.new(0, 2, 0); a0.Parent = terrain
    local a1 = Instance.new("Attachment"); a1.WorldPosition = toPos   + Vector3.new(0, 2, 0); a1.Parent = terrain

    local beam = Instance.new("Beam")
    beam.Attachment0    = a0; beam.Attachment1 = a1
    beam.Color          = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 30, 30)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 30)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 30, 30)),
    })
    beam.Transparency   = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   0.3),
        NumberSequenceKeypoint.new(0.5, 0.05),
        NumberSequenceKeypoint.new(1,   0.3),
    })
    beam.Width0         = 0.6; beam.Width1 = 0.6
    beam.FaceCamera     = true; beam.LightEmission = 0.9; beam.Segments = 25
    beam.Parent         = folder

    local hrp = getHRP()
    if hrp then
        local attA = Instance.new("Attachment"); attA.Name = "TrailA"; attA.Parent = hrp
        local attB = Instance.new("Attachment"); attB.Name = "TrailB"
        attB.Position = Vector3.new(0, -2.5, 0); attB.Parent = hrp
        local trail = Instance.new("Trail")
        trail.Attachment0 = attA; trail.Attachment1 = attB
        trail.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
        trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) })
        trail.Lifetime = 1.2; trail.MinLength = 0; trail.FaceCamera = true; trail.LightEmission = 1
        trail.Parent = folder
    end
    ActiveTrailFolder = folder
end

-- ==============================================================================
-- // 3-Stage Smooth Fly Engine
-- ==============================================================================
local function cancelTween()
    if State.CurrentTween then State.CurrentTween:Cancel(); State.CurrentTween = nil end
    State.IsTweening = false
    local hrp = getHRP()
    if hrp then
        hrp.Anchored = false
        local bv = hrp:FindFirstChild("HyperFlyVelocity")
        if bv then bv:Destroy() end
    end
    clearRedTrail()
end

local function flyToTarget(targetPos, onFinished, skipTrail)
    local hrp = getHRP(); if not hrp then return end
    cancelTween(); State.IsTweening = true
    if not skipTrail then createRedTrail(hrp.Position, targetPos) end

    local bv = Instance.new("BodyVelocity")
    bv.Name = "HyperFlyVelocity"; bv.Velocity = Vector3.new(0,0,0)
    bv.MaxForce = Vector3.new(0, math.huge, 0); bv.Parent = hrp

    task.spawn(function()
        local distance = (targetPos - hrp.CFrame.Position).Magnitude
        local duration = distance / (State.TweenSpeed or 500)

        State.CurrentTween = TweenService:Create(
            hrp,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            {CFrame = CFrame.new(targetPos)}
        )

        State.CurrentTween:Play()
        State.CurrentTween.Completed:Wait()

        if not State.IsTweening then
            if bv and bv.Parent then bv:Destroy() end
            clearRedTrail()
            return
        end

        if bv and bv.Parent then bv:Destroy() end
        clearRedTrail(); State.IsTweening = false; State.CurrentTween = nil
        if onFinished then onFinished() end
    end)
end

local function teleportDirect(targetPos)
    local hrp = getHRP()
    if hrp then cancelTween(); hrp.CFrame = CFrame.new(targetPos + Vector3.new(0,3,0)) end
end

-- ==============================================================================
-- // AUTO ROUND-TRIP TP ENGINE
-- ==============================================================================
local function stopAutoTP()
    State.AutoTP_Running = false
    if State.AutoTP_Thread then task.cancel(State.AutoTP_Thread); State.AutoTP_Thread = nil end
    cancelTween()
    notify("AUTO TP", "Round-Trip stopped.", "rbxassetid://10709790948", 2)
end

local function startAutoTP()
    if State.AutoTP_Running then notify("AUTO TP","Already running! Stop first.","rbxassetid://10709790948",2); return end
    if not State.AutoTP_EggPos then
        notify("AUTO TP","Set Point A (Egg) first!\nClick egg in Radar or use Set Point A.","rbxassetid://10709790948",3)
        return
    end
    State.AutoTP_Running = true
    notify("AUTO TP","Round-Trip started! Egg <-> Home loop.","rbxassetid://10709790948",3)

    State.AutoTP_Thread = task.spawn(function()
        while State.AutoTP_Running do
            local hrp = getHRP()
            if hrp then createRedTrail(hrp.Position, State.AutoTP_EggPos) end
            local doneA = false
            flyToTarget(State.AutoTP_EggPos, function() doneA = true end, true)
            while not doneA and State.AutoTP_Running do task.wait(0.1) end
            if not State.AutoTP_Running then break end
            task.wait(State.AutoTP_Delay)
            if not State.AutoTP_Running then break end

            createRedTrail(State.AutoTP_EggPos, State.AutoTP_HomePos)
            local doneB = false
            flyToTarget(State.AutoTP_HomePos, function() doneB = true end, true)
            while not doneB and State.AutoTP_Running do task.wait(0.1) end
            if not State.AutoTP_Running then break end
            task.wait(State.AutoTP_Delay)
        end
        clearRedTrail()
        notify("AUTO TP","Loop ended.","rbxassetid://10709790948",2)
    end)
end

-- ==============================================================================
-- // Jump & Treadmill Doff
-- ==============================================================================
local lastDoffTime = 0
local function doffTreadmill()
    if not State.AutoDoffTreadmill then return end
    local now = tick(); if now - lastDoffTime < 0.25 then return end
    lastDoffTime = now
    task.spawn(function()
        pcall(function()
            local pkgs  = ReplicatedStorage:FindFirstChild("Packages")
            local net   = pkgs and pkgs:FindFirstChild("Networking")
            local event = (net and net:FindFirstChild("RF/Treadmill/AskDoff"))
                       or ReplicatedStorage:FindFirstChild("RF/Treadmill/AskDoff", true)
            if event then
                if event:IsA("RemoteFunction") then event:InvokeServer()
                elseif event:IsA("RemoteEvent") then event:FireServer() end
            end
        end)
    end)
end
UserInputService.JumpRequest:Connect(function()
    doffTreadmill()
    local hum = currentHumanoid or getHumanoid()
    if not hum or not hum.Parent then return end
    if State.InfJump then hum:ChangeState(Enum.HumanoidStateType.Jumping)
    else
        hum.Jump = true
        local st = hum:GetState()
        if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.RunningNoPhysics
           or st == Enum.HumanoidStateType.Landed or hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.Space then doffTreadmill() end
end)

-- ==============================================================================
-- // Instant Proximity Prompts
-- ==============================================================================
local originalHoldDurations = {}
local function applyPromptInstant(prompt, isInstant)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if originalHoldDurations[prompt] == nil then originalHoldDurations[prompt] = prompt.HoldDuration end
    prompt.HoldDuration = isInstant and 0 or (originalHoldDurations[prompt] or 1)
end
local function toggleInstantPrompt(enabled)
    State.InstantPrompt = enabled
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then applyPromptInstant(obj, enabled) end
    end
end
if ProximityPromptService then
    ProximityPromptService.PromptShown:Connect(function(p) if State.InstantPrompt then applyPromptInstant(p,true) end end)
    ProximityPromptService.PromptButtonHoldBegan:Connect(function(p)
        if State.InstantPrompt then
            applyPromptInstant(p,true)
            if typeof(fireproximityprompt) == "function" then task.spawn(pcall, fireproximityprompt, p, 0) end
        end
    end)
end
Workspace.DescendantAdded:Connect(function(obj)
    if State.InstantPrompt and obj:IsA("ProximityPrompt") then task.defer(function() applyPromptInstant(obj,true) end) end
end)
task.spawn(function() task.wait(0.3); if State.InstantPrompt then toggleInstantPrompt(true) end end)

-- ==============================================================================
-- // Character Orientation
-- ==============================================================================
local originalNeckC0 = nil
local function toggleFaceDown(enabled)
    State.FaceDown = enabled
    if State.FaceDownConnection then State.FaceDownConnection:Disconnect(); State.FaceDownConnection = nil end
    local hum = currentHumanoid or getHumanoid()
    if enabled then
        if hum then hum.AutoRotate = false end
        State.FaceDownConnection = RunService.RenderStepped:Connect(function()
            if not State.FaceDown then return end
            local hrp = getHRP()
            if hrp and hrp.Parent then
                local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0,yaw,0) * CFrame.Angles(-math.pi/2,0,0)
            end
        end)
    else
        if hum then hum.AutoRotate = true end
        local hrp = getHRP()
        if hrp and hrp.Parent then
            local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0,yaw,0)
        end
    end
end
local function toggleHeadDown(enabled)
    State.HeadDown = enabled
    if State.HeadDownConnection then State.HeadDownConnection:Disconnect(); State.HeadDownConnection = nil end
    local char = LocalPlayer.Character; if not char then return end
    if enabled then
        State.HeadDownConnection = RunService.RenderStepped:Connect(function()
            if not State.HeadDown then return end
            local c = LocalPlayer.Character; if not c then return end
            local t = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
            local h = c:FindFirstChild("Head")
            local neck = (t and t:FindFirstChild("Neck")) or (h and h:FindFirstChild("Neck"))
            if neck then
                if not originalNeckC0 then originalNeckC0 = neck.C0 end
                neck.C0 = originalNeckC0 * CFrame.Angles(-math.pi/2,0,0)
            end
        end)
    else
        local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local h = char:FindFirstChild("Head")
        local neck = (t and t:FindFirstChild("Neck")) or (h and h:FindFirstChild("Neck"))
        if neck and originalNeckC0 then neck.C0 = originalNeckC0; originalNeckC0 = nil end
    end
end

-- ==============================================================================
-- // EGG DATA SYSTEM
-- ==============================================================================
local EggDataCache      = {}
local PendingEggQueries = {}

local function getPartFromModel(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    if m:IsA("Model") then
        if m.PrimaryPart then return m.PrimaryPart end
        for _, c in ipairs(m:GetChildren()) do if c:IsA("BasePart") then return c end end
        return m:FindFirstChildWhichIsA("BasePart", true)
    end
    return m:FindFirstChildWhichIsA("BasePart", true)
end

local function parseMutations(muts, baseMut)
    local result, seen = {}, {}
    local function add(m)
        if not m then return end
        local s = tostring(m):gsub("^%s+",""):gsub("%s+$","")
        if #s > 0 and not seen[s:lower()] then seen[s:lower()] = true; table.insert(result, s) end
    end
    if type(baseMut) == "string" and #baseMut > 0 then add(baseMut) end
    if type(muts) == "table" then
        for k, v in pairs(muts) do
            if type(v) == "string" then add(v)
            elseif type(k) == "string" and v == true then add(k)
            elseif type(v) == "table" then for _, sv in pairs(v) do if type(sv)=="string" then add(sv) end end end
        end
    elseif type(muts) == "string" then
        for part in muts:gmatch("[^,;%s]+") do add(part) end
    end
    return result
end

local function getEggRarityTheme(allMuts, baseMut)
    local str = ((baseMut or "") .. " " .. table.concat(allMuts," ")):lower()
    if str:find("rainbow") then return Color3.fromRGB(255,105,180),"RAINBOW",true
    elseif str:find("gold")   then return Color3.fromRGB(255,215,0),  "GOLD",true
    elseif str:find("silver") then return Color3.fromRGB(200,215,230),"SILVER",true
    elseif str:find("diamond")then return Color3.fromRGB(0,230,255),  "DIAMOND",true
    elseif str:find("giant") or str:find("huge") then return Color3.fromRGB(255,140,20),"GIANT",true
    elseif #allMuts > 0 then return Color3.fromRGB(180,110,255), allMuts[1]:upper(), true end
    return Color3.fromRGB(80,200,255),"NORMAL",false
end

-- Query house egg via AskEggRecord RF
local function queryEggRecordServer(uid)
    if not uid or type(uid)~="string" or #uid<10 then return end
    if PendingEggQueries[uid] then return end
    if not AskEggRecordRF then
        pcall(function()
            local pkgs = ReplicatedStorage:FindFirstChild("Packages")
            local net  = pkgs and pkgs:FindFirstChild("Networking")
            AskEggRecordRF = net and net:FindFirstChild("RF/EggWorld/AskEggRecord")
        end)
    end
    if not AskEggRecordRF then return end
    PendingEggQueries[uid] = true
    task.spawn(function()
        local ok, data = pcall(function() return AskEggRecordRF:InvokeServer(uid) end)
        if ok and type(data) == "table" then
            local egg = EggDataCache[uid] or { Uid=uid, IsBase=true }
            if data.AssetCategory and #tostring(data.AssetCategory)>0 then egg.AssetCategory = data.AssetCategory end
            if data.Mutations    then egg.Mutations    = data.Mutations end
            if data.BaseMutation then egg.BaseMutation = data.BaseMutation end
            if data.NestScale    then egg.NestScale    = tonumber(data.NestScale) end
            if data.AssetScale   then egg.AssetScale   = tonumber(data.AssetScale) end
            if data.TargetScale  then egg.TargetScale  = tonumber(data.TargetScale) end
            if data.Ready ~= nil      then egg.Ready      = data.Ready end
            if data.IsHatching ~= nil then egg.IsHatching = data.IsHatching end
            EggDataCache[uid] = egg
        end
        task.wait(4); PendingEggQueries[uid] = nil
    end)
end

-- PRIMARY: EggState.ReadFieldEggs()
local function scanEggStateField()
    if not EggStateModule then return end
    pcall(function()
        if typeof(EggStateModule.ReadFieldEggs) ~= "function" then return end
        local fieldData = EggStateModule.ReadFieldEggs()
        local records   = fieldData and fieldData.Records
        if not records or type(records) ~= "table" then return end
        local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
        local currentRecords = {}
        for uid, data in pairs(records) do
            if type(data)=="table" and type(uid)=="string" and #uid>=10 then
                currentRecords[uid] = true
                local egg = EggDataCache[uid] or { Uid=uid, IsBase=false }
                egg.AssetCategory = data.AssetCategory or egg.AssetCategory
                egg.BaseMutation  = data.BaseMutation  or egg.BaseMutation
                egg.Mutations     = data.Mutations     or egg.Mutations
                egg.NestScale     = data.NestScale     or egg.NestScale
                egg.AssetScale    = data.AssetScale    or egg.AssetScale
                egg.TargetScale   = data.TargetScale   or egg.TargetScale
                egg.Ready = data.Ready; egg.IsHatching = data.IsHatching; egg.IsBase = false
                if typeof(data.Position)=="Vector3"  then egg.Position = data.Position
                elseif typeof(data.Position)=="CFrame" then egg.Position = data.Position.Position end
                if slotsFolder then
                    local slot = slotsFolder:FindFirstChild(uid)
                    if slot then
                        egg.Instance = slot
                        local part = getPartFromModel(slot)
                        if part then egg.Part = part; egg.Position = part.Position end
                    end
                end
                EggDataCache[uid] = egg
            end
        end
        -- Remove wild eggs that are no longer in the records
        for uid, egg in pairs(EggDataCache) do
            if not egg.IsBase and not currentRecords[uid] then
                EggDataCache[uid] = nil
                removeFieldEggESP(uid)
            end
        end
    end)
end

-- SECONDARY: GC scan for house eggs + position lookup
local isScanningGC = false
local function scanGCForEggs()
    if isScanningGC or typeof(getgc)~="function" then return end
    isScanningGC = true
    pcall(function()
        local gcs = getgc(true)
        for i = 1, #gcs do
            local v = gcs[i]
            if type(v)=="table" then
                local uid = rawget(v,"Uid") or rawget(v,"uid")
                if uid and type(uid)=="string" and #uid>=8 then
                    local egg = EggDataCache[uid] or { Uid=uid, IsBase=true }
                    local function rg(k) return rawget(v,k) end
                    if rg("AssetCategory") then egg.AssetCategory = rg("AssetCategory") end
                    if rg("BaseMutation")  then egg.BaseMutation  = rg("BaseMutation") end
                    if rg("Mutations")     then egg.Mutations     = rg("Mutations") end
                    if rg("NestScale")     then egg.NestScale     = tonumber(rg("NestScale")) end
                    if rg("AssetScale")    then egg.AssetScale    = tonumber(rg("AssetScale")) end
                    -- Try to grab position from GC table itself
                    local gPos = rg("Position") or rg("WorldPosition")
                    if typeof(gPos)=="Vector3" then egg.Position = gPos
                    elseif typeof(gPos)=="CFrame" then egg.Position = gPos.Position end
                    -- Owner
                    local ownerUid = rg("OwnerUserId")
                    if ownerUid then
                        egg.OwnerUserId = tonumber(ownerUid) or ownerUid
                        local p = Players:GetPlayerByUserId(tonumber(ownerUid) or 0)
                        if p then
                            egg.Owner = p.DisplayName or p.Name
                            -- Use owner character position as fallback for house egg
                            if not egg.Position and p.Character then
                                local hrpOwner = p.Character:FindFirstChild("HumanoidRootPart")
                                if hrpOwner then egg.Position = hrpOwner.Position end
                            end
                        else
                            egg.Owner = tostring(ownerUid)
                        end
                    end
                    EggDataCache[uid] = egg
                    if not egg.Position then queryEggRecordServer(uid) end
                end
            end
            if i % 5000 == 0 then task.wait() end
        end
    end)
    isScanningGC = false
end

-- TERTIARY: Direct Workspace model scan (finds eggs placed in world)
local function scanWorkspaceModels()
    pcall(function()
        -- Scan AreaEggSlotsClient
        local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
        if slotsFolder then
            for _, slot in ipairs(slotsFolder:GetChildren()) do
                local uid = slot.Name
                if uid and type(uid)=="string" and #uid>=8 then
                    local egg = EggDataCache[uid] or { Uid=uid, IsBase=false }
                    egg.Instance = slot
                    local part = getPartFromModel(slot)
                    if part then egg.Part = part; egg.Position = part.Position end
                    -- Try read attributes
                    pcall(function()
                        local cat = slot:GetAttribute("AssetCategory") or slot:GetAttribute("Category")
                        if cat then egg.AssetCategory = cat end
                        local bm  = slot:GetAttribute("BaseMutation")
                        if bm  then egg.BaseMutation = bm end
                    end)
                    EggDataCache[uid] = egg
                end
            end
        end
        -- Scan EggWorld or similar model folders
        for _, folderName in ipairs({"EggWorld","FieldEggs","Eggs","EggSlots","ActiveEggs"}) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, child in ipairs(folder:GetChildren()) do
                    local uid = child.Name
                    if uid and #uid>=8 and not EggDataCache[uid] then
                        local egg = { Uid=uid, IsBase=false, Instance=child }
                        local part = getPartFromModel(child)
                        if part then egg.Position = part.Position end
                        pcall(function()
                            local cat = child:GetAttribute("AssetCategory") or child:GetAttribute("Category")
                            if cat then egg.AssetCategory = cat end
                        end)
                        EggDataCache[uid] = egg
                    end
                end
            end
        end
    end)
end

local function hookAreaEggSlots()
    local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then
        task.spawn(function()
            folder = Workspace:WaitForChild("AreaEggSlotsClient", 15)
            if folder then hookAreaEggSlots() end
        end)
        return
    end
    folder.ChildAdded:Connect(function(slot)
        local uid = slot.Name
        if uid and type(uid)=="string" and #uid>=8 then
            local egg = EggDataCache[uid] or { Uid=uid, IsBase=false }
            egg.Instance = slot
            task.defer(function()
                local part = getPartFromModel(slot)
                if part then egg.Part = part; egg.Position = part.Position end
                EggDataCache[uid] = egg
            end)
        end
    end)
    folder.ChildRemoved:Connect(function(slot)
        local uid = slot.Name
        if uid and EggDataCache[uid] and not EggDataCache[uid].IsBase then EggDataCache[uid] = nil end
    end)
end
task.spawn(hookAreaEggSlots)
task.spawn(function()
    task.wait(0.5)
    pcall(tryLoadEggState)  -- retry EggState load after game loaded
    pcall(tryFindAskEggRecord)
    scanEggStateField()
    scanGCForEggs()
    scanWorkspaceModels()
    while true do
        task.wait(3);  pcall(scanEggStateField); pcall(scanWorkspaceModels)
        task.wait(5);  pcall(scanGCForEggs)
    end
end)

-- Continuously update positions of house eggs from owner characters
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            for uid, egg in pairs(EggDataCache) do
                if egg.IsBase and egg.OwnerUserId and not egg.Position then
                    local p = Players:GetPlayerByUserId(tonumber(egg.OwnerUserId) or 0)
                    if p and p.Character then
                        local hrpOwner = p.Character:FindFirstChild("HumanoidRootPart")
                        if hrpOwner then egg.Position = hrpOwner.Position end
                    end
                end
            end
        end)
    end
end)

-- ==============================================================================
-- // ESP BILLBOARD SYSTEM (EggState-Driven)
-- ==============================================================================
local ActiveFieldESP = {}
local function removeFieldEggESP(uid)
    local esp = ActiveFieldESP[uid]
    if esp then
        if esp.Billboard and esp.Billboard.Parent then esp.Billboard:Destroy() end
        if esp.Highlight  and esp.Highlight.Parent  then esp.Highlight:Destroy() end
        if esp.Anchor     and esp.Anchor.Parent     then esp.Anchor:Destroy() end
        ActiveFieldESP[uid] = nil
    end
end
local function clearAllFieldEggESP()
    for uid in pairs(ActiveFieldESP) do removeFieldEggESP(uid) end
    table.clear(ActiveFieldESP)
end

local function createOrUpdateFieldEggESP(uid, data)
    if not State.EggESP then removeFieldEggESP(uid); return end
    local eggPos = nil
    if typeof(data.Position)=="Vector3"  then eggPos = data.Position
    elseif typeof(data.Position)=="CFrame" then eggPos = data.Position.Position end
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    local slotModel   = slotsFolder and slotsFolder:FindFirstChild(uid)
    if not eggPos and slotModel then
        local p = getPartFromModel(slotModel); if p then eggPos = p.Position end
    end
    if not eggPos then removeFieldEggESP(uid); return end

    local hrp   = getHRP(); local myPos = hrp and hrp.Position or Vector3.zero
    local dist  = math.floor((eggPos - myPos).Magnitude)
    if dist > State.ESP_MaxDistance then removeFieldEggESP(uid); return end

    local mutsList                      = parseMutations(data.Mutations, data.BaseMutation)
    local themeColor, rarityTag, isRare = getEggRarityTheme(mutsList, data.BaseMutation)
    if State.ESP_Filter=="Rare"   and not isRare then removeFieldEggESP(uid); return end
    if State.ESP_Filter=="Gold"   and not rarityTag:find("GOLD")   then removeFieldEggESP(uid); return end
    if State.ESP_Filter=="Silver" and not rarityTag:find("SILVER") then removeFieldEggESP(uid); return end

    local esp = ActiveFieldESP[uid]
    if not esp or not esp.Billboard or not esp.Billboard.Parent then
        local anchor = Instance.new("Part"); anchor.Name="EggAnchor_"..uid:sub(1,8)
        anchor.Size=Vector3.new(1,1,1); anchor.Transparency=1; anchor.CanCollide=false
        anchor.CanTouch=false; anchor.CanQuery=false; anchor.Anchored=true
        anchor.Position=eggPos; anchor.Parent=Workspace

        local bg = Instance.new("BillboardGui"); bg.Name="EggESP_"..uid:sub(1,8)
        bg.AlwaysOnTop=true; bg.Size=UDim2.new(0,225,0,75)
        bg.StudsOffset=Vector3.new(0,4.5,0); bg.MaxDistance=State.ESP_MaxDistance; bg.Adornee=anchor

        local frame = Instance.new("Frame",bg); frame.Name="Card"
        frame.Size=UDim2.new(1,0,1,0); frame.BackgroundColor3=Color3.fromRGB(15,15,24)
        frame.BackgroundTransparency=0.15; frame.BorderSizePixel=0
        Instance.new("UICorner",frame).CornerRadius=UDim.new(0,7)
        local stroke=Instance.new("UIStroke",frame); stroke.Name="Stroke"
        stroke.Thickness=1.2; stroke.Color=themeColor; stroke.Transparency=0.1
        local pad=Instance.new("UIPadding",frame)
        pad.PaddingLeft=UDim.new(0,10); pad.PaddingRight=UDim.new(0,10)
        pad.PaddingTop=UDim.new(0,7); pad.PaddingBottom=UDim.new(0,7)

        local function mkL(pos,size,fsize,font,color)
            local l=Instance.new("TextLabel",frame); l.Size=size; l.Position=pos
            l.BackgroundTransparency=1; l.Font=font or Enum.Font.GothamMedium; l.TextSize=fsize or 11
            l.TextColor3=color or Color3.fromRGB(255,255,255)
            l.TextXAlignment=Enum.TextXAlignment.Left; l.RichText=true; return l
        end
        local titleLbl   = mkL(UDim2.new(0,0,0,0),  UDim2.new(1,0,0,19), 12, Enum.Font.GothamBold)
        local mutLbl     = mkL(UDim2.new(0,0,0,19), UDim2.new(1,0,0,14), 10, Enum.Font.Gotham, Color3.fromRGB(195,165,255))
        local earningLbl = mkL(UDim2.new(0,0,0,33), UDim2.new(1,0,0,14), 10, Enum.Font.GothamBold, Color3.fromRGB(255,220,70))
        local distLbl    = mkL(UDim2.new(0,0,0,48), UDim2.new(1,0,0,13), 10, Enum.Font.Gotham, Color3.fromRGB(110,195,255))

        local hl = nil
        if State.ESP_Highlight and slotModel then
            hl = Instance.new("Highlight"); hl.Adornee=slotModel
            hl.FillColor=themeColor; hl.FillTransparency=0.65
            hl.OutlineColor=themeColor; hl.OutlineTransparency=0.1
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=slotModel
        end
        bg.Parent = anchor
        esp = { Billboard=bg, Highlight=hl, Anchor=anchor, Stroke=stroke,
                TitleLbl=titleLbl, MutLbl=mutLbl, EarningLbl=earningLbl, DistLbl=distLbl, SlotModel=slotModel }
        ActiveFieldESP[uid] = esp
    end

    if esp.Anchor and esp.Anchor.Position ~= eggPos then esp.Anchor.Position = eggPos end
    esp.Stroke.Color = themeColor
    if esp.Highlight then
        esp.Highlight.FillColor=themeColor; esp.Highlight.OutlineColor=themeColor
        esp.Highlight.Enabled=State.ESP_Highlight
    elseif State.ESP_Highlight and slotModel and not esp.Highlight then
        local hl=Instance.new("Highlight"); hl.Adornee=slotModel
        hl.FillColor=themeColor; hl.FillTransparency=0.65; hl.OutlineColor=themeColor
        hl.OutlineTransparency=0.1; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=slotModel
        esp.Highlight=hl
    end

    local name    = data.AssetCategory or "Unknown"
    local sPfx    = ""
    if data.Ready==true    then sPfx='<font color="#00FF88">[READY] </font>'
    elseif data.IsHatching then sPfx='<font color="#FFA500">[HATCH] </font>' end
    esp.TitleLbl.Text = string.format('%s<b>%s</b>  <font color="#%02X%02X%02X">[%s]</font>',
        sPfx, name, math.floor(themeColor.R*255), math.floor(themeColor.G*255), math.floor(themeColor.B*255), rarityTag)

    if State.ESP_ShowMutations and #mutsList>0 then
        esp.MutLbl.Text="mut: "..table.concat(mutsList," / "); esp.MutLbl.Visible=true
    else esp.MutLbl.Visible=false end

    local eps = GetEarningPerSecond(data)
    if eps then
        esp.EarningLbl.Text=string.format('$ <b>%d</b>/s', math.floor(eps)); esp.EarningLbl.Visible=true
    else esp.EarningLbl.Visible=false end

    if State.ESP_ShowDistance then
        esp.DistLbl.Text=string.format('~ <b>%d</b>  [%s]', dist, data.IsBase and "House" or "Wild")
        esp.DistLbl.Visible=true
    else esp.DistLbl.Visible=false end
end

local function tickESP()
    if not State.EggESP then if next(ActiveFieldESP) then clearAllFieldEggESP() end; return end
    local uids = {}
    for uid, egg in pairs(EggDataCache) do
        -- Clean up destroyed instances
        if egg.Instance and egg.Instance.Parent == nil then
            EggDataCache[uid] = nil
            removeFieldEggESP(uid)
        elseif egg.Position or (egg.Instance and getPartFromModel(egg.Instance)) then
            uids[uid]=true; createOrUpdateFieldEggESP(uid, egg)
        end
    end
    for uid in pairs(ActiveFieldESP) do
        if not uids[uid] then removeFieldEggESP(uid) end
    end
end
task.spawn(function() while true do task.wait(0.3); pcall(tickESP) end end)

-- ==============================================================================
-- // RADAR FLOATING HUD
-- ==============================================================================
local EggRadarGui, RadarFeedScroll, RadarCountLabel = nil, nil, nil
local RadarPreviewTitle, RadarPreviewStatus, RadarPreviewMuts = nil, nil, nil
local RadarPreviewScale, RadarPreviewEarning, RadarPreviewLoc = nil, nil, nil
local RadarSearchBox, SelectedRadarUid, RadarFilter = nil, nil, "All"
local IsRadarMinimized, RadarMainFrame = false, nil

local function refreshRadarList()
    if not RadarFeedScroll then return end
    for _, child in ipairs(RadarFeedScroll:GetChildren()) do
        if child:IsA("GuiObject") and child.Name:find("EggCard_") then child:Destroy() end
    end
    local searchText = RadarSearchBox and RadarSearchBox.Text:lower() or ""
    local hrp = getHRP(); local myPos = hrp and hrp.Position or Vector3.zero
    local sorted, total, wild, base = {}, 0, 0, 0
    for uid, egg in pairs(EggDataCache) do
        total=total+1; if egg.IsBase then base=base+1 else wild=wild+1 end
        local muts = parseMutations(egg.Mutations, egg.BaseMutation)
        local _, rarityTag, isRare = getEggRarityTheme(muts, egg.BaseMutation)
        local pass = true
        if RadarFilter=="Rare"   and not isRare then pass=false end
        if RadarFilter=="Gold"   and not rarityTag:find("GOLD")   then pass=false end
        if RadarFilter=="Silver" and not rarityTag:find("SILVER") then pass=false end
        if RadarFilter=="Wild"   and egg.IsBase  then pass=false end
        if RadarFilter=="Base"   and not egg.IsBase then pass=false end
        if #searchText>0 then
            if not (egg.AssetCategory or ""):lower():find(searchText,1,true)
            and not (egg.Owner or ""):lower():find(searchText,1,true) then pass=false end
        end
        if pass then
            local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            local dist = pos and (pos-myPos).Magnitude or 99999
            table.insert(sorted, { Egg=egg, Dist=dist })
        end
    end
    table.sort(sorted, function(a,b) return a.Dist < b.Dist end)
    if RadarCountLabel then RadarCountLabel.Text = string.format("egg:%d wild:%d house:%d", total, wild, base) end

    for idx, item in ipairs(sorted) do
        local egg  = item.Egg
        local muts = parseMutations(egg.Mutations, egg.BaseMutation)
        local themeColor, rarityTag = getEggRarityTheme(muts, egg.BaseMutation)

        local card = Instance.new("TextButton")
        card.Name="EggCard_"..tostring(egg.Uid):sub(1,8)
        card.Size=UDim2.new(1,-6,0,52); card.BorderSizePixel=0; card.LayoutOrder=idx
        card.BackgroundColor3=(SelectedRadarUid==egg.Uid) and Color3.fromRGB(28,34,52) or Color3.fromRGB(15,15,24)
        card.AutoButtonColor=false; card.Text=""
        Instance.new("UICorner",card).CornerRadius=UDim.new(0,7)
        local cs=Instance.new("UIStroke",card); cs.Thickness=(SelectedRadarUid==egg.Uid) and 2 or 1
        cs.Color=(SelectedRadarUid==egg.Uid) and themeColor or Color3.fromRGB(36,38,56)
        local cp=Instance.new("UIPadding",card)
        cp.PaddingLeft=UDim.new(0,9); cp.PaddingRight=UDim.new(0,9)
        cp.PaddingTop=UDim.new(0,5); cp.PaddingBottom=UDim.new(0,5)

        local tL=Instance.new("TextLabel",card); tL.Size=UDim2.new(1,0,0,18); tL.BackgroundTransparency=1
        tL.Font=Enum.Font.GothamBold; tL.TextSize=12; tL.TextColor3=Color3.fromRGB(255,255,255)
        tL.TextXAlignment=Enum.TextXAlignment.Left; tL.RichText=true
        local st=(egg.Ready==true) and '<font color="#00FF88">[OK] </font>' or ""
        tL.Text=string.format('%s<b>%s</b>  <font color="#%02X%02X%02X">[%s]</font>',
            st, egg.AssetCategory or "Unknown",
            math.floor(themeColor.R*255), math.floor(themeColor.G*255), math.floor(themeColor.B*255), rarityTag)

        local sL=Instance.new("TextLabel",card); sL.Size=UDim2.new(0.6,0,0,14); sL.Position=UDim2.new(0,0,0,20)
        sL.BackgroundTransparency=1; sL.Font=Enum.Font.Gotham; sL.TextSize=10
        sL.TextColor3=Color3.fromRGB(120,180,255); sL.TextXAlignment=Enum.TextXAlignment.Left; sL.RichText=true
        local loc = egg.IsBase and ("house:"..tostring(egg.Owner or "?")) or "wild"
        local dStr = item.Dist<90000 and string.format("%d stud",math.floor(item.Dist)) or "--"
        sL.Text = string.format("~ %s  [%s]", dStr, loc)

        local epsVal = GetEarningPerSecond(egg)
        if epsVal then
            local eL=Instance.new("TextLabel",card); eL.Size=UDim2.new(0.38,0,0,14); eL.Position=UDim2.new(0.62,0,0,20)
            eL.BackgroundTransparency=1; eL.Font=Enum.Font.GothamBold; eL.TextSize=10
            eL.TextColor3=Color3.fromRGB(255,215,65); eL.TextXAlignment=Enum.TextXAlignment.Right; eL.RichText=true
            eL.Text = "$ "..tostring(math.floor(epsVal)).."/s"
        end

        card.MouseButton1Click:Connect(function()
            SelectedRadarUid = egg.Uid
            local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            if pos then State.AutoTP_EggPos = pos end
            if RadarPreviewTitle then
                local mc,rt = getEggRarityTheme(muts,egg.BaseMutation)
                RadarPreviewTitle.Text = '<b>'..( egg.AssetCategory or "Unknown")..'</b>  ['..rt..']'
                RadarPreviewTitle.TextColor3 = mc
            end
            if RadarPreviewStatus then
                local s = "Field Egg"
                if egg.Ready then s = "READY TO STEAL" elseif egg.IsHatching then s = "HATCHING" end
                RadarPreviewStatus.Text = s
            end
            if RadarPreviewMuts then RadarPreviewMuts.Text = #muts>0 and ("mut: "..table.concat(muts,", ")) or "Mutations: None" end
            if RadarPreviewScale then
                local sc={}
                if egg.NestScale  then table.insert(sc,string.format("Nest %.1fx",egg.NestScale)) end
                if egg.AssetScale then table.insert(sc,string.format("Pet %.1fx", egg.AssetScale)) end
                RadarPreviewScale.Text = #sc>0 and ("Scale: "..table.concat(sc," | ")) or "Scale: Default"
            end
            if RadarPreviewEarning then
                local e2=GetEarningPerSecond(egg)
                RadarPreviewEarning.Text = e2 and ("$ "..string.format("%d/sec",math.floor(e2))) or "$ N/A"
            end
            if RadarPreviewLoc then
                local d = pos and string.format("%d studs",math.floor((pos-myPos).Magnitude)) or "--"
                local lc = egg.IsBase and ("house: "..tostring(egg.Owner or "?")) or "Wild"
                RadarPreviewLoc.Text = lc.."  |  "..d
            end
            refreshRadarList()
        end)
        card.Parent = RadarFeedScroll
    end
end

local function createStandaloneRadarUI()
    if EggRadarGui and EggRadarGui.Parent then EggRadarGui.Enabled=true; refreshRadarList(); return end
    local guiParent = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
    EggRadarGui = Instance.new("ScreenGui"); EggRadarGui.Name="HyperEggRadar_Gui"
    EggRadarGui.ResetOnSpawn=false; EggRadarGui.Parent=guiParent

    local mf = Instance.new("Frame",EggRadarGui); mf.Name="RadarWindow"
    mf.Size=UDim2.new(0,600,0,400); mf.Position=UDim2.new(0.5,-300,0.5,-200)
    mf.BackgroundColor3=Color3.fromRGB(11,11,18); mf.BorderSizePixel=0; RadarMainFrame=mf
    Instance.new("UICorner",mf).CornerRadius=UDim.new(0,10)
    local ms=Instance.new("UIStroke",mf); ms.Thickness=1.8; ms.Color=Color3.fromRGB(45,115,255)

    local tb=Instance.new("Frame",mf); tb.Size=UDim2.new(1,0,0,36)
    tb.BackgroundColor3=Color3.fromRGB(17,19,30); tb.BorderSizePixel=0
    Instance.new("UICorner",tb).CornerRadius=UDim.new(0,10)

    local titleL=Instance.new("TextLabel",tb); titleL.Size=UDim2.new(0,200,1,0); titleL.Position=UDim2.new(0,12,0,0)
    titleL.BackgroundTransparency=1; titleL.Font=Enum.Font.GothamBold; titleL.TextSize=13
    titleL.TextColor3=Color3.fromRGB(255,255,255); titleL.TextXAlignment=Enum.TextXAlignment.Left; titleL.Text="EGG RADAR"

    RadarCountLabel=Instance.new("TextLabel",tb); RadarCountLabel.Size=UDim2.new(0,200,1,0); RadarCountLabel.Position=UDim2.new(0,210,0,0)
    RadarCountLabel.BackgroundTransparency=1; RadarCountLabel.Font=Enum.Font.GothamMedium; RadarCountLabel.TextSize=10
    RadarCountLabel.TextColor3=Color3.fromRGB(90,170,255); RadarCountLabel.TextXAlignment=Enum.TextXAlignment.Left; RadarCountLabel.Text="Scanning..."

    local bc=Instance.new("Frame",tb); bc.Size=UDim2.new(0,92,1,0); bc.Position=UDim2.new(1,-100,0,0); bc.BackgroundTransparency=1
    local bl=Instance.new("UIListLayout",bc); bl.FillDirection=Enum.FillDirection.Horizontal
    bl.HorizontalAlignment=Enum.HorizontalAlignment.Right; bl.VerticalAlignment=Enum.VerticalAlignment.Center; bl.Padding=UDim.new(0,4)
    local function mkTB(txt,col)
        local b=Instance.new("TextButton",bc); b.Size=UDim2.new(0,26,0,26); b.BackgroundColor3=col or Color3.fromRGB(30,34,50)
        b.Font=Enum.Font.GothamBold; b.TextSize=12; b.TextColor3=Color3.fromRGB(255,255,255); b.Text=txt
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
    end
    local refreshBtn=mkTB("R"); local miniBtn=mkTB("-"); local closeBtn=mkTB("X",Color3.fromRGB(195,48,58))

    local dragging,dragInput,dragStart,startPos
    tb.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=inp.Position; startPos=mf.Position
            inp.Changed:Connect(function() if inp.UserInputState==Enum.UserInputState.End then dragging=false end end)
        end
    end)
    tb.InputChanged:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseMovement then dragInput=inp end end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp==dragInput and dragging then
            local d=inp.Position-dragStart
            mf.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)

    local body=Instance.new("Frame",mf); body.Size=UDim2.new(1,-16,1,-44); body.Position=UDim2.new(0,8,0,40); body.BackgroundTransparency=1
    local lc=Instance.new("Frame",body); lc.Size=UDim2.new(0,275,1,0); lc.BackgroundTransparency=1

    local sb=Instance.new("TextBox",lc); sb.Size=UDim2.new(1,0,0,26); sb.BackgroundColor3=Color3.fromRGB(19,21,32)
    sb.Font=Enum.Font.Gotham; sb.TextSize=11; sb.TextColor3=Color3.fromRGB(235,235,255)
    sb.PlaceholderColor3=Color3.fromRGB(85,95,125); sb.PlaceholderText="Search..."; sb.Text=""; sb.ClearTextOnFocus=false
    Instance.new("UICorner",sb).CornerRadius=UDim.new(0,6); RadarSearchBox=sb
    sb:GetPropertyChangedSignal("Text"):Connect(function() refreshRadarList() end)

    local fb=Instance.new("Frame",lc); fb.Size=UDim2.new(1,0,0,22); fb.Position=UDim2.new(0,0,0,30); fb.BackgroundTransparency=1
    local fl=Instance.new("UIListLayout",fb); fl.FillDirection=Enum.FillDirection.Horizontal; fl.Padding=UDim.new(0,3)
    for _,fn in ipairs({"All","Rare","Gold","Silver","Wild","Base"}) do
        local fbt=Instance.new("TextButton",fb); fbt.Size=UDim2.new(0,44,1,0)
        fbt.BackgroundColor3=(RadarFilter==fn) and Color3.fromRGB(45,115,255) or Color3.fromRGB(22,24,38)
        fbt.Font=Enum.Font.GothamBold; fbt.TextSize=10; fbt.TextColor3=Color3.fromRGB(255,255,255); fbt.Text=fn
        Instance.new("UICorner",fbt).CornerRadius=UDim.new(0,4)
        fbt.MouseButton1Click:Connect(function()
            RadarFilter=fn
            for _, b in ipairs(fb:GetChildren()) do
                if b:IsA("TextButton") then b.BackgroundColor3=(b.Text==fn) and Color3.fromRGB(45,115,255) or Color3.fromRGB(22,24,38) end
            end
            refreshRadarList()
        end)
    end

    local scroll=Instance.new("ScrollingFrame",lc); scroll.Size=UDim2.new(1,0,1,-56); scroll.Position=UDim2.new(0,0,0,56)
    scroll.BackgroundTransparency=1; scroll.BorderSizePixel=0; scroll.ScrollBarThickness=3
    scroll.ScrollBarImageColor3=Color3.fromRGB(50,70,110); scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y; RadarFeedScroll=scroll
    local sl=Instance.new("UIListLayout",scroll); sl.Padding=UDim.new(0,4); sl.SortOrder=Enum.SortOrder.LayoutOrder

    local rc=Instance.new("Frame",body); rc.Size=UDim2.new(1,-287,1,0); rc.Position=UDim2.new(0,287,0,0); rc.BackgroundTransparency=1

    local ib=Instance.new("Frame",rc); ib.Size=UDim2.new(1,0,0,130); ib.BackgroundColor3=Color3.fromRGB(14,16,26)
    Instance.new("UICorner",ib).CornerRadius=UDim.new(0,8); Instance.new("UIStroke",ib).Color=Color3.fromRGB(34,52,96)
    local ip=Instance.new("UIPadding",ib); ip.PaddingLeft=UDim.new(0,10); ip.PaddingRight=UDim.new(0,10)
    ip.PaddingTop=UDim.new(0,8); ip.PaddingBottom=UDim.new(0,8)

    local function mkI(pos,size,fsize,font,col)
        local l=Instance.new("TextLabel",ib); l.Size=size; l.Position=pos; l.BackgroundTransparency=1
        l.Font=font or Enum.Font.Gotham; l.TextSize=fsize or 11; l.TextColor3=col or Color3.fromRGB(215,215,225)
        l.TextXAlignment=Enum.TextXAlignment.Left; l.RichText=true; return l
    end
    RadarPreviewTitle   = mkI(UDim2.new(0,0,0,0),  UDim2.new(1,0,0,20), 14, Enum.Font.GothamBold, Color3.fromRGB(255,255,255))
    RadarPreviewTitle.Text="Select an Egg"
    RadarPreviewStatus  = mkI(UDim2.new(0,0,0,21), UDim2.new(1,0,0,16), 11, Enum.Font.GothamMedium, Color3.fromRGB(0,195,135))
    RadarPreviewStatus.Text="--"
    RadarPreviewMuts    = mkI(UDim2.new(0,0,0,38), UDim2.new(1,0,0,15), 10, nil, Color3.fromRGB(190,155,255))
    RadarPreviewMuts.Text="Mutations: None"
    RadarPreviewScale   = mkI(UDim2.new(0,0,0,54), UDim2.new(1,0,0,15), 10, nil, Color3.fromRGB(190,190,205))
    RadarPreviewScale.Text="Scale: Default"
    RadarPreviewEarning = mkI(UDim2.new(0,0,0,70), UDim2.new(1,0,0,15), 12, Enum.Font.GothamBold, Color3.fromRGB(255,210,65))
    RadarPreviewEarning.Text="$ Earning: N/A"
    RadarPreviewLoc     = mkI(UDim2.new(0,0,0,86), UDim2.new(1,0,0,15), 10, nil, Color3.fromRGB(105,185,255))
    RadarPreviewLoc.Text="Location: --"

    local ar=Instance.new("Frame",rc); ar.Size=UDim2.new(1,0,0,30); ar.Position=UDim2.new(0,0,0,138); ar.BackgroundTransparency=1
    local al=Instance.new("UIListLayout",ar); al.FillDirection=Enum.FillDirection.Horizontal; al.Padding=UDim.new(0,6)
    local function mkAB(txt,col)
        local b=Instance.new("TextButton",ar); b.Size=UDim2.new(0.5,-3,1,0); b.BackgroundColor3=col
        b.Font=Enum.Font.GothamBold; b.TextSize=11; b.TextColor3=Color3.fromRGB(255,255,255); b.Text=txt
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
    end
    local flyBtn=mkAB("Fly to Egg", Color3.fromRGB(34,105,215))
    local warpBtn=mkAB("Teleport",  Color3.fromRGB(14,155,115))
    flyBtn.MouseButton1Click:Connect(function()
        if not SelectedRadarUid or not EggDataCache[SelectedRadarUid] then notify("RADAR","Select egg first!","rbxassetid://10709791437",2); return end
        local egg=EggDataCache[SelectedRadarUid]
        local pos=egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
        if pos then flyToTarget(pos,function() notify("ARRIVED",egg.AssetCategory or "Egg","rbxassetid://10709791437",2) end)
            notify("FLYING","To "..(egg.AssetCategory or "Egg"),"rbxassetid://10709790948",2)
        else notify("ERROR","Position unknown.","rbxassetid://10709791437",2) end
    end)
    warpBtn.MouseButton1Click:Connect(function()
        if not SelectedRadarUid or not EggDataCache[SelectedRadarUid] then notify("RADAR","Select egg first!","rbxassetid://10709791437",2); return end
        local egg=EggDataCache[SelectedRadarUid]
        local pos=egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
        if pos then teleportDirect(pos); notify("WARPED",egg.AssetCategory or "Egg","rbxassetid://10709791437",2)
        else notify("ERROR","Position unknown.","rbxassetid://10709791437",2) end
    end)

    refreshBtn.MouseButton1Click:Connect(function()
        scanEggStateField(); scanGCForEggs(); refreshRadarList()
        notify("RADAR","Rescanned!","rbxassetid://10709791437",2)
    end)
    miniBtn.MouseButton1Click:Connect(function()
        IsRadarMinimized=not IsRadarMinimized; body.Visible=not IsRadarMinimized
        mf.Size=IsRadarMinimized and UDim2.new(0,360,0,36) or UDim2.new(0,600,0,400)
        miniBtn.Text=IsRadarMinimized and "+" or "-"
        if not IsRadarMinimized then refreshRadarList() end
    end)
    closeBtn.MouseButton1Click:Connect(function() EggRadarGui.Enabled=false end)
    refreshRadarList()
end

local lastRadarRefresh=0
RunService.Heartbeat:Connect(function()
    local now=tick()
    if EggRadarGui and EggRadarGui.Enabled and not IsRadarMinimized and (now-lastRadarRefresh>3) then
        lastRadarRefresh=now; refreshRadarList()
    end
end)

-- ==============================================================================
-- // MAIN UI WINDOW
-- ==============================================================================
Window = Library:Window({
    Title="HYPER HUB", Desc="Steal an Egg | v4.0 | K2NTA ST", Version="v4.0",
    Icon="https://i.postimg.cc/5tRtv6F0/89-B301701.png", Theme="Dark",
    Config={ Keybind=Enum.KeyCode.RightControl, Size=UDim2.new(0,650,0,500),
             DesktopSize=UDim2.new(0,650,0,500), MobileSize=UDim2.new(0,600,0,440), TabWidth=150 },
    CloseUIButton={Enabled=true},
    Profile={ Username=LocalPlayer.Name, Email="Steal an Egg Hub",
              AvatarUrl="rbxthumb://type=AvatarHeadShot&id="..tostring(LocalPlayer.UserId).."&w=150&h=150" },
})

-- TAB 1: EGG RADAR
local EggRadarTab = Window:Tab({ Title="Egg Radar", Icon="rbxassetid://10723346959" })
EggRadarTab:Section({ Title="Live ESP" })
EggRadarTab:Toggle({ Title="Egg ESP (Billboard)", Desc="Labels above all eggs", Value=State.EggESP,
    Callback=function(v) State.EggESP=v; if not v then clearAllFieldEggESP() end end })
EggRadarTab:Toggle({ Title="ESP Highlight", Value=State.ESP_Highlight,
    Callback=function(v) State.ESP_Highlight=v end })
EggRadarTab:Toggle({ Title="Show Mutations", Value=State.ESP_ShowMutations,
    Callback=function(v) State.ESP_ShowMutations=v end })
EggRadarTab:Toggle({ Title="Show Distance", Value=State.ESP_ShowDistance,
    Callback=function(v) State.ESP_ShowDistance=v end })
EggRadarTab:Slider({ Title="Max ESP Distance (studs)", Min=100, Max=10000, Value=State.ESP_MaxDistance,
    Callback=function(v) State.ESP_MaxDistance=v end })
EggRadarTab:Section({ Title="Radar & Navigation" })
EggRadarTab:Button({ Title="Open Radar Window", Desc="Standalone floating HUD",
    Callback=function() createStandaloneRadarUI(); notify("RADAR","Opened!","rbxassetid://10723346959",2) end })
EggRadarTab:Button({ Title="Fly to Closest Rare Egg", Desc="Gold/Silver/Rare only",
    Callback=function()
        local hrp=getHRP(); if not hrp then return end; local myPos=hrp.Position
        local best,bestDist=nil,math.huge
        for _,egg in pairs(EggDataCache) do
            local pos=egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            if pos then
                local muts=parseMutations(egg.Mutations,egg.BaseMutation)
                local _,_,isRare=getEggRarityTheme(muts,egg.BaseMutation)
                if isRare then local d=(pos-myPos).Magnitude; if d<bestDist then bestDist=d; best=egg end end
            end
        end
        if best then
            local pos=best.Position or getPartFromModel(best.Instance).Position
            flyToTarget(pos,function() notify("ARRIVED",best.AssetCategory or "Rare","rbxassetid://10709791437",2) end)
            notify("FLYING","To "..(best.AssetCategory or "Rare").." ("..math.floor(bestDist).." studs)","rbxassetid://10709790948",3)
        else notify("NO RARE","No rare eggs found!","rbxassetid://10709791437",3) end
    end })
EggRadarTab:Button({ Title="Teleport to Closest Egg",
    Callback=function()
        local hrp=getHRP(); if not hrp then return end; local myPos=hrp.Position
        local best,bestDist,bestName=nil,math.huge,"Egg"
        for _,egg in pairs(EggDataCache) do
            local pos=egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            if pos then local d=(pos-myPos).Magnitude; if d<bestDist then bestDist=d; best=egg; bestName=egg.AssetCategory or "Egg" end end
        end
        if best then
            local pos=best.Position or getPartFromModel(best.Instance).Position
            teleportDirect(pos); notify("WARPED",bestName.." ("..math.floor(bestDist).." studs)","rbxassetid://10709791437",2)
        else notify("NO EGGS","No eggs found.","rbxassetid://10709791437",2) end
    end })
EggRadarTab:Button({ Title="Force Rescan All Eggs",
    Callback=function()
        scanEggStateField(); scanGCForEggs()
        local t,w,b=0,0,0
        for _,e in pairs(EggDataCache) do t=t+1; if e.IsBase then b=b+1 else w=w+1 end end
        refreshRadarList(); notify("SCAN",string.format("%d eggs (%d Wild,%d House)",t,w,b),"rbxassetid://10709791437",3)
    end })

-- TAB 2: AUTO TP
local AutoTPTab = Window:Tab({ Title="Auto TP", Icon="rbxassetid://10709790948" })
AutoTPTab:Section({ Title="Round-Trip Fly Engine" })
AutoTPTab:Button({ Title="START Auto TP  (Egg <-> Home)", Desc="Select egg in Radar first, then start",
    Callback=startAutoTP })
AutoTPTab:Button({ Title="STOP Auto TP", Callback=stopAutoTP })
AutoTPTab:Section({ Title="Point Configuration" })
AutoTPTab:Button({ Title="Set Point A = My Position (Egg Spot)",
    Callback=function()
        local hrp=getHRP()
        if hrp then
            State.AutoTP_EggPos=hrp.Position
            notify("POINT A",string.format("Egg: %.0f,%.0f,%.0f",hrp.Position.X,hrp.Position.Y,hrp.Position.Z),"rbxassetid://10709790948",2.5)
        end
    end })
AutoTPTab:Button({ Title="Set Point B = My Position (Home Base)",
    Callback=function()
        local hrp=getHRP()
        if hrp then
            State.AutoTP_HomePos=hrp.Position
            notify("POINT B",string.format("Home: %.0f,%.0f,%.0f",hrp.Position.X,hrp.Position.Y,hrp.Position.Z),"rbxassetid://10709790948",2.5)
        end
    end })
AutoTPTab:Button({ Title="Reset Point B to Default (532,71,-356)",
    Callback=function() State.AutoTP_HomePos=Vector3.new(532,71,-356); notify("POINT B","Reset to default","rbxassetid://10709790948",2) end })
AutoTPTab:Section({ Title="Speed & Timing" })
AutoTPTab:Slider({ Title="Flight Speed (studs/s)", Min=50, Max=2000, Value=State.AutoTP_Speed,
    Callback=function(v) State.AutoTP_Speed=v; State.TweenSpeed=v end })
AutoTPTab:Slider({ Title="Wait Delay at Each Point (sec)", Min=0, Max=10, Value=State.AutoTP_Delay,
    Callback=function(v) State.AutoTP_Delay=v end })
AutoTPTab:Toggle({ Title="Red Beam Trail", Desc="Show red beam while flying", Value=State.RedTrail,
    Callback=function(v) State.RedTrail=v; if not v then clearRedTrail() end end })

-- TAB 3: FLIGHT & ZONES
local MainTab = Window:Tab({ Title="Flight & Zones", Icon="rbxassetid://10709791437" })
MainTab:Section({ Title="Zone Teleportation" })
MainTab:Dropdown({ Title="Select Zone", List=ZoneOrder, Value=State.SelectedZone,
    Callback=function(v) State.SelectedZone=v end })
MainTab:Button({ Title="Fly to Selected Zone", Desc="3-stage smooth flight",
    Callback=function()
        local pos=Zones[State.SelectedZone]
        if pos then flyToTarget(pos,function() notify("ARRIVED",State.SelectedZone,"rbxassetid://10709791437",2) end)
            notify("FLYING","-> "..State.SelectedZone,"rbxassetid://10709790948",2) end
    end })
MainTab:Button({ Title="Instant Teleport to Zone",
    Callback=function()
        local pos=Zones[State.SelectedZone]
        if pos then teleportDirect(pos); notify("WARPED",State.SelectedZone,"rbxassetid://10709791437",2) end
    end })
MainTab:Button({ Title="Cancel Flight",
    Callback=function() cancelTween(); notify("CANCELLED","Flight stopped.","rbxassetid://10709791437",2) end })
MainTab:Section({ Title="Flight Physics" })
MainTab:Slider({ Title="Straight Flight Speed", Min=20, Max=2000, Value=State.TweenSpeed,
    Callback=function(v) State.TweenSpeed=v end })
MainTab:Slider({ Title="Ascend Speed", Min=50, Max=1500, Value=State.AscendSpeed,
    Callback=function(v) State.AscendSpeed=v end })
MainTab:Slider({ Title="Descend Speed", Min=50, Max=1000, Value=State.DescendSpeed,
    Callback=function(v) State.DescendSpeed=v end })
MainTab:Slider({ Title="Flight Altitude (Y)", Min=50, Max=500, Value=State.TweenHeight,
    Callback=function(v) State.TweenHeight=v end })
MainTab:Section({ Title="Quick Zone Flights" })
for _,zName in ipairs(ZoneOrder) do
    local coord=Zones[zName]
    MainTab:Button({ Title="Fly: "..zName, Desc=string.format("X%d Z%d",math.floor(coord.X),math.floor(coord.Z)),
        Callback=function()
            State.SelectedZone=zName
            flyToTarget(coord,function() notify("ARRIVED",zName,"rbxassetid://10709791437",2) end)
        end })
end

-- TAB 4: PLAYER
local PlayerTab = Window:Tab({ Title="Player", Icon="rbxassetid://10709791523" })
PlayerTab:Section({ Title="Invincibility" })
PlayerTab:Toggle({ Title="God Mode (Clone Humanoid)", Value=State.GodMode, Callback=toggleGodMode })
PlayerTab:Toggle({ Title="Noclip", Value=State.Noclip, Callback=toggleNoclip })
PlayerTab:Toggle({ Title="Infinite Jump", Value=State.InfJump, Callback=function(v) State.InfJump=v end })
PlayerTab:Toggle({ Title="Auto Doff Treadmill", Value=State.AutoDoffTreadmill, Callback=function(v) State.AutoDoffTreadmill=v end })
PlayerTab:Toggle({ Title="Instant Proximity Prompts", Value=State.InstantPrompt,
    Callback=function(v) toggleInstantPrompt(v); notify("PROMPT",v and "ON" or "OFF","rbxassetid://10709791437",2) end })
PlayerTab:Section({ Title="Orientation" })
PlayerTab:Toggle({ Title="Face Down (Pitch 90)", Value=State.FaceDown,
    Callback=function(v) toggleFaceDown(v); notify("FACE DOWN",v and "ON" or "OFF","rbxassetid://10709791437",2) end })
PlayerTab:Toggle({ Title="Head Down", Value=State.HeadDown,
    Callback=function(v) toggleHeadDown(v); notify("HEAD DOWN",v and "ON" or "OFF","rbxassetid://10709791437",2) end })
PlayerTab:Section({ Title="Speed Method Selector" })
PlayerTab:Button({ Title="[1] Set Mode: WalkSpeed", Callback=function() State.SpeedMethod="WalkSpeed"; notify("SPEED METHOD","Set to WalkSpeed","rbxassetid://10709791437",2) end })
PlayerTab:Button({ Title="[2] Set Mode: CFrame", Callback=function() State.SpeedMethod="CFrame"; notify("SPEED METHOD","Set to CFrame","rbxassetid://10709791437",2) end })
PlayerTab:Button({ Title="[3] Set Mode: Velocity", Callback=function() State.SpeedMethod="Velocity"; notify("SPEED METHOD","Set to Velocity","rbxassetid://10709791437",2) end })
PlayerTab:Button({ Title="[4] Set Mode: Hybrid", Callback=function() State.SpeedMethod="Hybrid"; notify("SPEED METHOD","Set to Hybrid","rbxassetid://10709791437",2) end })
PlayerTab:Section({ Title="Speed & Jump Controls" })
PlayerTab:Slider({ Title="Speed Amount", Min=16, Max=500, Value=16,
    Callback=function(v) State.WalkSpeed=v; local h=currentHumanoid or getHumanoid(); if h and State.SpeedMethod=="WalkSpeed" then h.WalkSpeed=v end end })
PlayerTab:Button({ Title="Safe Runner (35/s)",
    Callback=function() State.WalkSpeed=35; local h=currentHumanoid or getHumanoid(); if h and State.SpeedMethod=="WalkSpeed" then h.WalkSpeed=35 end
        notify("SPEED","Speed 35 (Safe Delivery)","rbxassetid://10709791437",2) end })
PlayerTab:Button({ Title="Fast Runner (60/s)",
    Callback=function() State.WalkSpeed=60; local h=currentHumanoid or getHumanoid(); if h and State.SpeedMethod=="WalkSpeed" then h.WalkSpeed=60 end
        notify("SPEED","Speed 60","rbxassetid://10709791437",2) end })
PlayerTab:Button({ Title="Reset Speed (16/s)",
    Callback=function() State.WalkSpeed=16; local h=currentHumanoid or getHumanoid(); if h then h.WalkSpeed=16 end
        notify("SPEED","Speed 16 (Default)","rbxassetid://10709791437",2) end })
PlayerTab:Slider({ Title="Jump Power", Min=50, Max=600, Value=50,
    Callback=function(v) State.JumpPower=v; local h=currentHumanoid or getHumanoid(); if h then h.UseJumpPower=true; h.JumpPower=v end end })

RunService.RenderStepped:Connect(function(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = currentHumanoid or char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hum then
        if State.JumpPower ~= 50 and hum.JumpPower ~= State.JumpPower then 
            hum.UseJumpPower = true
            hum.JumpPower = State.JumpPower 
        end

        if State.WalkSpeed ~= 16 then
            if State.SpeedMethod == "WalkSpeed" then
                if hum.WalkSpeed ~= State.WalkSpeed then hum.WalkSpeed = State.WalkSpeed end
            else
                if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
                if hrp and hum.MoveDirection.Magnitude > 0 then
                    local moveDir = hum.MoveDirection
                    local extraSpeed = math.max(0, State.WalkSpeed - 16)
                    
                    if State.SpeedMethod == "CFrame" then
                        hrp.CFrame = hrp.CFrame + (moveDir * (extraSpeed * dt))
                    elseif State.SpeedMethod == "Velocity" then
                        local curY = (hrp.AssemblyLinearVelocity and hrp.AssemblyLinearVelocity.Y) or hrp.Velocity.Y
                        local targetVel = Vector3.new(moveDir.X * State.WalkSpeed, curY, moveDir.Z * State.WalkSpeed)
                        if hrp.AssemblyLinearVelocity then
                            hrp.AssemblyLinearVelocity = targetVel
                        else
                            hrp.Velocity = targetVel
                        end
                    elseif State.SpeedMethod == "Hybrid" then
                        hrp.CFrame = hrp.CFrame + (moveDir * (extraSpeed * dt * 0.4))
                        local curY = (hrp.AssemblyLinearVelocity and hrp.AssemblyLinearVelocity.Y) or hrp.Velocity.Y
                        local targetVel = Vector3.new(moveDir.X * (State.WalkSpeed * 0.8), curY, moveDir.Z * (State.WalkSpeed * 0.8))
                        if hrp.AssemblyLinearVelocity then
                            hrp.AssemblyLinearVelocity = targetVel
                        else
                            hrp.Velocity = targetVel
                        end
                    end
                end
            end
        else
            if hum.WalkSpeed ~= 16 then hum.WalkSpeed = 16 end
        end
    end
end)

-- TAB 5: SETTINGS
local SettingsTab = Window:Tab({ Title="Settings", Icon="rbxassetid://10709791130" })
SettingsTab:Section({ Title="Theme & UI" })
SettingsTab:Dropdown({ Title="UI Theme", List={"Dark","Amethyst","Liquid Glass","Rose","Ocean","Neon","Gold","Light"}, Value="Dark",
    Callback=function(t) Library:SetTheme(t) end })
local defScale=100
pcall(function()
    local gp=(gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if gp then
        for _,g in ipairs(gp:GetChildren()) do
            if g:IsA("ScreenGui") then
                local ws=g:FindFirstChild("Shadow") and g:FindFirstChild("Shadow"):FindFirstChild("WindowScale")
                if ws and ws:IsA("UIScale") then defScale=math.clamp(math.round(ws.Scale*100),70,150); break end
            end
        end
    end
end)
SettingsTab:Slider({ Title="UI Scale (%)", Min=70, Max=150, Value=defScale,
    Callback=function(v)
        pcall(function()
            local gp=(gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if gp then
                for _,g in ipairs(gp:GetChildren()) do
                    if g:IsA("ScreenGui") then
                        local ws=g:FindFirstChild("Shadow") and g:FindFirstChild("Shadow"):FindFirstChild("WindowScale")
                        if ws and ws:IsA("UIScale") then
                            TweenService:Create(ws,TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=v/100}):Play()
                        end
                    end
                end
            end
        end)
    end })
SettingsTab:Keybind({ Title="Toggle UI Keybind", Value=Enum.KeyCode.RightControl, Callback=function(_) end })
SettingsTab:Section({ Title="Unload" })
SettingsTab:Button({ Title="Unload Script", Desc="Remove all effects and destroy UI",
    Callback=function()
        stopAutoTP(); cancelTween(); clearAllFieldEggESP(); clearRedTrail()
        toggleGodMode(false); toggleNoclip(false); toggleInstantPrompt(false)
        toggleFaceDown(false); toggleHeadDown(false)
        if EggRadarGui and EggRadarGui.Parent then EggRadarGui:Destroy() end
        Window:Destroy()
    end })

-- ==============================================================================
notify("HYPER HUB v4.0","Loaded! God Mode ON | ESP Active | Auto TP Ready","rbxassetid://10709791437",4)
