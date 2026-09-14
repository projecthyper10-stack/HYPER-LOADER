-- ==============================================================================
--  HYPER HUB - Steal an Egg Roblox
--  Features: God Mode, Zone Fly/Tween (Height 160), Noclip, Speed Controller
--  Created by K2NTA ST | Project Singularity
-- ==============================================================================

local _cloneref = (cloneref or function(...) return ... end)
local function getService(name)
    local ok, s = pcall(function() return game:GetService(name) end)
    return ok and _cloneref(s) or nil
end

local Players = getService("Players")
local RunService = getService("RunService")
local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local Workspace = getService("Workspace")
local ReplicatedStorage = getService("ReplicatedStorage") or game:GetService("ReplicatedStorage")
local ProximityPromptService = getService("ProximityPromptService") or game:GetService("ProximityPromptService")
local LocalPlayer = Players.LocalPlayer

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
        return str:gsub("^98791", ""):gsub("^%s+", "")
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
                            Library = lib
                            env.HYPER_UI = lib
                            break
                        end
                    end
                end
            end
        end
    end

    if not Library then
        local urls = {
            "https://raw.githubusercontent.com/projecthyper10-stack/HYPER-LOADER/refs/heads/main/UI.main/ui.lua",
            "https://raw.githubusercontent.com/projecthyper10-stack/HYPER-LOADER/refs/heads/main/UI.main/ui.lua"
        }
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
                        Library = lib
                        env.HYPER_UI = lib
                        break
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
-- // Configuration & Zone Coordinates
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
    "Home", "Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5",
    "Zone 6", "Zone 7", "Zone 8", "Zone 9", "Zone 10", "Zone 11", "Zone 12"
}

local State = {
    SelectedZone = "Home",
    TweenSpeed = 110,       -- ความเร็วทางตรง (ช้าลง นุ่มนวล ไม่โดนดีดกลับ)
    AscendSpeed = 380,      -- ความเร็วพุ่งขึ้นฟ้า (พุ่งขึ้นไวทันใจ)
    DescendSpeed = 220,     -- ความเร็วร่อนลงเป้าหมาย
    TweenHeight = 160,
    IsTweening = false,
    CurrentTween = nil,
    GodMode = true, -- Auto-enabled on script execution
    Noclip = false,
    InfJump = false,
    AutoDoffTreadmill = true,
    InstantPrompt = true,
    FaceDown = false,
    FaceDownConnection = nil,
    HeadDown = false,
    HeadDownConnection = nil,
    GodHeartbeat = nil,
    NoclipConnection = nil,
    WalkSpeed = 16,
    JumpPower = 50,
    -- EggState ESP Settings
    EggESP = true,
    ESP_Highlight = true,
    ESP_ShowMutations = true,
    ESP_ShowDistance = true,
    ESP_ShowScales = true,
    ESP_MaxDistance = 5000,
    ESP_Filter = "All",
}

-- ==============================================================================
local function notify(title, desc, icon, time)
    if Window and Window.Notify then
        Window:Notify({ Title = title, Desc = desc, Icon = icon or "rbxassetid://10709791437", Time = time or 3 })
    elseif Library and Library.Notify then
        Library:Notify({ Title = title, Desc = desc, Icon = icon or "rbxassetid://10709791437", Time = time or 3 })
    end
end

-- // Character & Utility Helpers
-- ==============================================================================
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 3)
end

local function getHumanoid()
    local char = getCharacter()
    return char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
end

-- ==============================================================================
-- // Auto God Mode / Health Lock (setupGodState Engine)
-- ==============================================================================
local H = RunService or game:GetService("RunService")
local R = H.RenderStepped
local RE = H.RenderStepped.Wait

local currentCharacter = nil
local currentHumanoid = nil
local godConnections = {}

local function cleanupGodConnections()
    for _, conn in ipairs(godConnections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(godConnections)
end

local function restoreHealth(hum)
    if not hum or not hum.Parent then return end
    pcall(function()
        if hum.MaxHealth < 100 then
            hum.MaxHealth = 100
        end
        hum.Health = hum.MaxHealth
    end)
end

local function setupGodState(character)
    if not character then return end
    local oldHumanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
    if not oldHumanoid then return end

    cleanupGodConnections()

    -- 0. Recreate / Clone Humanoid ตัวใหม่ (ตัดขาดจากระบบดาเมจและการตายของเซิร์ฟเวอร์ - โหมดอมตะเดิม)
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
                local camera = Workspace.CurrentCamera or workspace.CurrentCamera
                if camera then
                    camera.CameraSubject = humanoid
                end
            end)

            pcall(function()
                local animate = character:FindFirstChild("Animate")
                if animate and animate:IsA("LocalScript") then
                    animate.Disabled = true
                    task.wait(0.05)
                    animate.Disabled = false
                end
            end)
        end
    end

    currentCharacter = character
    currentHumanoid = humanoid

    humanoid.BreakJointsOnDeath = false

    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end)

    restoreHealth(humanoid)

    local stateConn = humanoid.StateChanged:Connect(function(_, state)
        if State.GodMode and state == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            restoreHealth(humanoid)
        end
    end)
    table.insert(godConnections, stateConn)

    local heartbeatConn = H.Heartbeat:Connect(function()
        if not State.GodMode then return end
        if not character or not character.Parent or not humanoid or not humanoid.Parent then
            return
        end

        if humanoid:GetState() == Enum.HumanoidStateType.Dead then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        if humanoid.Health < humanoid.MaxHealth or humanoid.Health <= 0 then
            restoreHealth(humanoid)
        end
    end)
    table.insert(godConnections, heartbeatConn)

    local renderConn = H.RenderStepped:Connect(function()
        if not State.GodMode then return end
        if not character or not character.Parent or not humanoid or not humanoid.Parent then
            return
        end
        if humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
    table.insert(godConnections, renderConn)

    local jumping = false
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        if input.KeyCode == Enum.KeyCode.Space then
            jumping = true

            task.spawn(function()
                while jumping do
                    if humanoid and humanoid.Parent then
                        humanoid.Jump = true
                    end

                    task.wait(0.1)
                end
            end)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space then
            jumping = false
            if humanoid then
                humanoid.Jump = false
            end
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

-- ทำงานกับตัวละครปัจจุบันทันทีที่รันสคริปต์
if LocalPlayer.Character then
    task.spawn(setupGodState, LocalPlayer.Character)
end

-- ทำงานอัตโนมัติทุกครั้งที่เกิดใหม่ (Respawn)
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    setupGodState(char)
end)

local function toggleGodMode(enabled)
    State.GodMode = enabled
    if enabled then
        if LocalPlayer.Character then
            setupGodState(LocalPlayer.Character)
        end
        notify("GOD MODE", "Recreate Humanoid God Mode Active", "rbxassetid://10709791437", 2.5)
    else
        cleanupGodConnections()
        if currentHumanoid then
            pcall(function()
                currentHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            end)
        end
        notify("GOD MODE", "God Mode Disabled", "rbxassetid://10709791437", 2.5)
    end
end

-- ==============================================================================
-- // Noclip Handler
-- ==============================================================================
local function toggleNoclip(enabled)
    State.Noclip = enabled
    if enabled then
        if State.NoclipConnection then State.NoclipConnection:Disconnect() end
        State.NoclipConnection = RunService.Stepped:Connect(function()
            if not State.Noclip then
                if State.NoclipConnection then State.NoclipConnection:Disconnect() State.NoclipConnection = nil end
                return
            end
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if State.NoclipConnection then
            State.NoclipConnection:Disconnect()
            State.NoclipConnection = nil
        end
    end
end

-- ==============================================================================
-- // Smooth 3-Stage Tween Fly Engine (Sky Height: 160)
-- ==============================================================================
local function cancelTween()
    if State.CurrentTween then
        State.CurrentTween:Cancel()
        State.CurrentTween = nil
    end
    State.IsTweening = false
    local hrp = getHRP()
    if hrp then
        hrp.Anchored = false
        local bv = hrp:FindFirstChild("HyperFlyVelocity")
        if bv then bv:Destroy() end
    end
end

local function flyToTarget(targetPos, onFinished)
    local hrp = getHRP()
    if not hrp then return end

    cancelTween()
    State.IsTweening = true

    -- Anti-physics fall prevention during fly
    local bv = Instance.new("BodyVelocity")
    bv.Name = "HyperFlyVelocity"
    bv.Velocity = Vector3.new(0, 0, 0)
    bv.MaxForce = Vector3.new(0, math.huge, 0)
    bv.Parent = hrp

    task.spawn(function()
        local currentPos = hrp.Position
        local skyY = State.TweenHeight -- Default 160

        -- Stage 1: Ascend rapidly to sky altitude (160) - พุ่งขึ้นฟ้าอย่างรวดเร็ว
        local startSkyPos = Vector3.new(currentPos.X, skyY, currentPos.Z)
        local dist1 = math.abs(skyY - currentPos.Y)
        local ascendSpeed = State.AscendSpeed or 380
        local time1 = math.clamp(dist1 / ascendSpeed, 0.05, 3.0)

        local tInfo1 = TweenInfo.new(time1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        State.CurrentTween = TweenService:Create(hrp, tInfo1, { CFrame = CFrame.new(startSkyPos) })
        State.CurrentTween:Play()
        State.CurrentTween.Completed:Wait()

        if not State.IsTweening then if bv then bv:Destroy() end return end

        -- Stage 2: Smooth straight flight across the sky (ทางตรง)
        local targetSkyPos = Vector3.new(targetPos.X, skyY, targetPos.Z)
        local dist2 = (Vector3.new(startSkyPos.X, 0, startSkyPos.Z) - Vector3.new(targetSkyPos.X, 0, targetSkyPos.Z)).Magnitude
        local straightSpeed = State.TweenSpeed or 110
        local time2 = math.clamp(dist2 / straightSpeed, 0.08, 90)

        local tInfo2 = TweenInfo.new(time2, Enum.EasingStyle.Linear)
        State.CurrentTween = TweenService:Create(hrp, tInfo2, { CFrame = CFrame.new(targetSkyPos) })
        State.CurrentTween:Play()
        State.CurrentTween.Completed:Wait()

        if not State.IsTweening then if bv then bv:Destroy() end return end

        -- Stage 3: Descend smoothly to the zone target
        local dist3 = math.abs(skyY - targetPos.Y)
        local descendSpeed = State.DescendSpeed or 220
        local time3 = math.clamp(dist3 / descendSpeed, 0.05, 3.0)

        local tInfo3 = TweenInfo.new(time3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        State.CurrentTween = TweenService:Create(hrp, tInfo3, { CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0)) })
        State.CurrentTween:Play()
        State.CurrentTween.Completed:Wait()

        if bv and bv.Parent then bv:Destroy() end
        State.IsTweening = false
        State.CurrentTween = nil

        if onFinished then onFinished() end
    end)
end

local function teleportDirect(targetPos)
    local hrp = getHRP()
    if hrp then
        cancelTween()
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end
end

-- ==============================================================================
-- // Jump Controller (Fixes Jump on Cloned Humanoid + Infinite Jump + Treadmill Doff)
-- ==============================================================================
local lastDoffTime = 0
local function doffTreadmill()
    if State.AutoDoffTreadmill == false then return end
    local now = tick()
    if now - lastDoffTime < 0.25 then return end
    lastDoffTime = now

    task.spawn(function()
        pcall(function()
            local rep = ReplicatedStorage or getService("ReplicatedStorage") or game:GetService("ReplicatedStorage")
            local pkgs = rep:FindFirstChild("Packages")
            local net = pkgs and pkgs:FindFirstChild("Networking")
            local event = (net and net:FindFirstChild("RF/Treadmill/AskDoff"))
                or rep:FindFirstChild("RF/Treadmill/AskDoff", true)

            if event then
                if event:IsA("RemoteFunction") then
                    event:InvokeServer()
                elseif event:IsA("RemoteEvent") then
                    event:FireServer()
                end
            end
        end)
    end)
end

UserInputService.JumpRequest:Connect(function()
    doffTreadmill()
    local hum = currentHumanoid or getHumanoid()
    if not hum or not hum.Parent then return end

    if State.InfJump then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    else
        hum.Jump = true
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Running 
           or state == Enum.HumanoidStateType.RunningNoPhysics 
           or state == Enum.HumanoidStateType.Landed 
           or hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Space then
        doffTreadmill()
    end
end)

-- ==============================================================================
-- // INSTANT PROXIMITY PROMPTS ENGINE
-- ==============================================================================
local originalHoldDurations = {}

local function applyPromptInstant(prompt, isInstant)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if originalHoldDurations[prompt] == nil then
        originalHoldDurations[prompt] = prompt.HoldDuration
    end
    if isInstant then
        prompt.HoldDuration = 0
    else
        if originalHoldDurations[prompt] ~= nil then
            prompt.HoldDuration = originalHoldDurations[prompt]
        end
    end
end

local function toggleInstantPrompt(enabled)
    State.InstantPrompt = enabled
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            applyPromptInstant(obj, enabled)
        end
    end
end

if ProximityPromptService then
    ProximityPromptService.PromptShown:Connect(function(prompt)
        if State.InstantPrompt then
            applyPromptInstant(prompt, true)
        end
    end)

    ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        if State.InstantPrompt then
            applyPromptInstant(prompt, true)
            if typeof(fireproximityprompt) == "function" then
                task.spawn(pcall, fireproximityprompt, prompt, 0)
            end
        end
    end)
end

Workspace.DescendantAdded:Connect(function(obj)
    if State.InstantPrompt and obj:IsA("ProximityPrompt") then
        task.defer(function()
            applyPromptInstant(obj, true)
        end)
    end
end)

task.spawn(function()
    task.wait(0.3)
    if State.InstantPrompt then
        toggleInstantPrompt(true)
    end
end)

-- ==============================================================================
-- // Character Orientation & Face Down Controller
-- ==============================================================================
local originalNeckC0 = nil

local function toggleFaceDown(enabled)
    State.FaceDown = enabled
    if State.FaceDownConnection then
        State.FaceDownConnection:Disconnect()
        State.FaceDownConnection = nil
    end

    local hum = currentHumanoid or getHumanoid()
    if enabled then
        if hum then hum.AutoRotate = false end
        State.FaceDownConnection = RunService.RenderStepped:Connect(function()
            if not State.FaceDown then return end
            local hrp = currentHRP or getHRP()
            if hrp and hrp.Parent then
                local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
                hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
            end
        end)
    else
        if hum then hum.AutoRotate = true end
        local hrp = currentHRP or getHRP()
        if hrp and hrp.Parent then
            local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0)
        end
    end
end

local function toggleHeadDown(enabled)
    State.HeadDown = enabled
    if State.HeadDownConnection then
        State.HeadDownConnection:Disconnect()
        State.HeadDownConnection = nil
    end

    local char = LocalPlayer.Character
    if not char then return end

    if enabled then
        State.HeadDownConnection = RunService.RenderStepped:Connect(function()
            if not State.HeadDown then return end
            local c = LocalPlayer.Character
            if not c then return end
            local t = c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso")
            local h = c:FindFirstChild("Head")
            local neck = (t and t:FindFirstChild("Neck")) or (h and h:FindFirstChild("Neck"))
            if neck then
                if not originalNeckC0 then originalNeckC0 = neck.C0 end
                neck.C0 = originalNeckC0 * CFrame.Angles(-math.pi / 2, 0, 0)
            end
        end)
    else
        local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        local h = char:FindFirstChild("Head")
        local neck = (t and t:FindFirstChild("Neck")) or (h and h:FindFirstChild("Neck"))
        if neck and originalNeckC0 then
            neck.C0 = originalNeckC0
            originalNeckC0 = nil
        end
    end
end

-- ==============================================================================
-- // STANDALONE 3D PET RADAR SYSTEM
-- ==============================================================================

local EggDataCache = {}      -- [uid] = egg table
local SelectedRadarUid = nil
local CurrentPreviewModel = nil
local CurrentPreviewCenter = Vector3.zero
local CurrentPreviewMaxDim = 2
local CurrentPreviewCam = nil
local SpinAngle = 0

-- RemoteFunction for House Eggs & Record Lookup (RF/EggWorld/AskEggRecord)
local AskEggRecordRF = nil
pcall(function()
    local pkgs = ReplicatedStorage:FindFirstChild("Packages")
    local net = pkgs and pkgs:FindFirstChild("Networking")
    AskEggRecordRF = net and net:FindFirstChild("RF/EggWorld/AskEggRecord")
end)

local PendingAskEggQueries = {}

local function queryEggRecordServer(uid)
    if not uid or type(uid) ~= "string" or #uid < 10 then return end
    if PendingAskEggQueries[uid] then return end

    if not AskEggRecordRF then
        pcall(function()
            local pkgs = ReplicatedStorage:FindFirstChild("Packages")
            local net = pkgs and pkgs:FindFirstChild("Networking")
            AskEggRecordRF = net and net:FindFirstChild("RF/EggWorld/AskEggRecord")
        end)
    end
    if not AskEggRecordRF then return end

    PendingAskEggQueries[uid] = true
    task.spawn(function()
        local ok, data = pcall(function()
            return AskEggRecordRF:InvokeServer(uid)
        end)
        if ok and type(data) == "table" then
            local egg = EggDataCache[uid] or { Uid = uid }
            if data.AssetCategory and type(data.AssetCategory) == "string" and #data.AssetCategory > 0 then
                egg.AssetCategory = data.AssetCategory
            end
            if data.Mutations then egg.Mutations = data.Mutations end
            if data.BaseMutation then egg.BaseMutation = data.BaseMutation end
            if data.NestScale then egg.NestScale = tonumber(data.NestScale) end
            if data.AssetScale then egg.AssetScale = tonumber(data.AssetScale) end
            if data.TargetScale then egg.TargetScale = tonumber(data.TargetScale) end
            if data.Ready ~= nil then egg.Ready = data.Ready end
            if data.IsHatching ~= nil then egg.IsHatching = data.IsHatching end
            EggDataCache[uid] = egg
        end
        task.wait(3)
        PendingAskEggQueries[uid] = nil
    end)
end

-- Fast Direct Scanner for Wild Eggs Folder: workspace.AreaEggSlotsClient
local function scanAreaEggSlots()
    local folder = Workspace:FindFirstChild("AreaEggSlotsClient") or Workspace:FindFirstChild("areaeggslotsclient")
    if not folder then return end
    for _, slot in ipairs(folder:GetChildren()) do
        local uid = slot.Name
        if uid and type(uid) == "string" and #uid >= 10 then
            local egg = EggDataCache[uid] or { Uid = uid }
            egg.Instance = slot
            local part = getPartFromModel(slot)
            if part then
                egg.Part = part
                egg.Position = part.Position
            elseif slot:IsA("Model") then
                pcall(function() egg.Position = slot:GetPivot().Position end)
            end
            if egg.IsBase == nil then egg.IsBase = false end
            EggDataCache[uid] = egg

            -- Automatically fetch details via Remote if missing
            if not egg.AssetCategory or egg.AssetCategory == "Unknown Egg" or not egg.Mutations then
                queryEggRecordServer(uid)
            end
        end
    end
end

local function hookAreaEggSlots()
    local folder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if not folder then
        task.spawn(function()
            folder = Workspace:WaitForChild("AreaEggSlotsClient", 10)
            if folder then hookAreaEggSlots() end
        end)
        return
    end

    folder.ChildAdded:Connect(function(slot)
        local uid = slot.Name
        if uid and type(uid) == "string" and #uid >= 10 then
            local egg = EggDataCache[uid] or { Uid = uid }
            egg.Instance = slot
            task.defer(function()
                local part = getPartFromModel(slot) or slot:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    egg.Part = part
                    egg.Position = part.Position
                elseif slot:IsA("Model") then
                    pcall(function() egg.Position = slot:GetPivot().Position end)
                end
                if egg.IsBase == nil then egg.IsBase = false end
                EggDataCache[uid] = egg
            end)
        end
    end)

    folder.ChildRemoved:Connect(function(slot)
        local uid = slot.Name
        if uid and EggDataCache[uid] and not EggDataCache[uid].IsBase then
            EggDataCache[uid] = nil
        end
    end)
end

task.spawn(hookAreaEggSlots)

local function getPlayerNameByUserId(userId)
    if not userId then return nil end
    local numId = tonumber(userId)
    if not numId then return tostring(userId) end
    if LocalPlayer and LocalPlayer.UserId == numId then
        return "You"
    end
    local p = Players:GetPlayerByUserId(numId)
    if p then
        return p.DisplayName or p.Name
    end
    return tostring(userId)
end

local function parseMutations(muts, baseMut)
    local result = {}
    local seen = {}

    local function addMut(m)
        if not m then return end
        local str = tostring(m):gsub("^%s+", ""):gsub("%s+$", "")
        if #str > 0 and not seen[str:lower()] then
            seen[str:lower()] = true
            table.insert(result, str)
        end
    end

    if type(baseMut) == "string" and #baseMut > 0 then
        addMut(baseMut)
    end

    if type(muts) == "table" then
        for k, v in pairs(muts) do
            if type(v) == "string" then
                addMut(v)
            elseif type(v) == "table" then
                for _, sub in pairs(v) do
                    if type(sub) == "string" then addMut(sub) end
                end
            elseif type(k) == "string" and type(v) == "boolean" and v == true then
                addMut(k)
            end
        end
    elseif type(muts) == "string" then
        for mutName in muts:gmatch("[^,;%s]+") do
            addMut(mutName)
        end
    end

    return result
end

local function getEggRarityTheme(allMuts, baseMut)
    local str = ((baseMut or "") .. " " .. table.concat(allMuts, " ")):lower()

    if str:find("rainbow") then
        return Color3.fromRGB(255, 105, 180), "🌈 RAINBOW", true
    elseif str:find("gold") then
        return Color3.fromRGB(255, 215, 0), "🏆 GOLD", true
    elseif str:find("silver") then
        return Color3.fromRGB(200, 215, 230), "🥈 SILVER", true
    elseif str:find("diamond") then
        return Color3.fromRGB(0, 230, 255), "💎 DIAMOND", true
    elseif str:find("giant") or str:find("huge") then
        return Color3.fromRGB(255, 140, 20), "🐘 GIANT", true
    elseif #allMuts > 0 then
        return Color3.fromRGB(180, 110, 255), "✨ " .. allMuts[1]:upper(), true
    end

    return Color3.fromRGB(80, 200, 255), "NORMAL", false
end

local function getPartFromModel(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    if m:IsA("Model") then
        if m.PrimaryPart then return m.PrimaryPart end
        local hb = m:FindFirstChild("Hitbox") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Part") or m:FindFirstChild("Egg")
        if hb and hb:IsA("BasePart") then return hb end
        for _, child in ipairs(m:GetChildren()) do
            if child:IsA("BasePart") then return child end
        end
        return m:FindFirstChildWhichIsA("BasePart", true)
    end
    -- Support Folders / Configurations / Containers (like AreaEggSlotsClient slots)
    local hb = m:FindFirstChild("Hitbox", true) or m:FindFirstChild("Egg", true) or m:FindFirstChild("Part", true)
    if hb and hb:IsA("BasePart") then return hb end
    return m:FindFirstChildWhichIsA("BasePart", true)
end

local function processEggTable(v, forcedUid)
    if type(v) ~= "table" then return end
    local uid = forcedUid or rawget(v, "Uid") or rawget(v, "uid") or rawget(v, "ID")
    if not uid or type(uid) ~= "string" or #uid < 10 then return end

    local egg = EggDataCache[uid] or { Uid = uid }
    local rec = rawget(v, "Record")
    local res = rawget(v, "Result")

    local assetCat = rawget(v, "AssetCategory") or rawget(v, "assetCategory") or rawget(v, "Category") or rawget(v, "PetName") or rawget(v, "Name")
    if not assetCat and type(rec) == "table" then
        assetCat = rawget(rec, "AssetCategory") or rawget(rec, "PetName") or rawget(rec, "Name")
    end
    if not assetCat and type(res) == "table" then
        assetCat = rawget(res, "AssetCategory") or rawget(res, "PetName") or rawget(res, "Name")
    end
    if assetCat and type(assetCat) == "string" and #assetCat > 0 then
        egg.AssetCategory = assetCat
    end

    local baseMut = rawget(v, "BaseMutation") or rawget(v, "baseMutation") or rawget(v, "Mutation")
    if not baseMut and type(rec) == "table" then baseMut = rawget(rec, "BaseMutation") or rawget(rec, "Mutation") end
    if not baseMut and type(res) == "table" then baseMut = rawget(res, "BaseMutation") or rawget(res, "Mutation") end
    if baseMut and type(baseMut) == "string" and #baseMut > 0 then
        egg.BaseMutation = baseMut
    end

    local nestScale = rawget(v, "NestScale") or rawget(v, "nestScale") or rawget(v, "EggScale")
    if not nestScale and type(rec) == "table" then nestScale = rawget(rec, "NestScale") end
    if not nestScale and type(res) == "table" then nestScale = rawget(res, "NestScale") end
    if nestScale and tonumber(nestScale) then egg.NestScale = tonumber(nestScale) end

    local assetScale = rawget(v, "AssetScale") or rawget(v, "assetScale") or rawget(v, "StartScale") or rawget(v, "PetScale")
    if not assetScale and type(rec) == "table" then assetScale = rawget(rec, "AssetScale") or rawget(rec, "StartScale") end
    if not assetScale and type(res) == "table" then assetScale = rawget(res, "AssetScale") or rawget(res, "StartScale") end
    if assetScale and tonumber(assetScale) then egg.AssetScale = tonumber(assetScale) end

    local targetScale = rawget(v, "TargetScale")
    if not targetScale and type(rec) == "table" then targetScale = rawget(rec, "TargetScale") end
    if not targetScale and type(res) == "table" then targetScale = rawget(res, "TargetScale") end
    if targetScale and tonumber(targetScale) then egg.TargetScale = tonumber(targetScale) end

    local muts = rawget(v, "Mutations") or rawget(v, "mutations")
    if not muts and type(rec) == "table" then muts = rawget(rec, "Mutations") end
    if not muts and type(res) == "table" then muts = rawget(res, "Mutations") end
    if muts then egg.Mutations = muts end

    if rawget(v, "Ready") ~= nil then egg.Ready = rawget(v, "Ready") end
    if rawget(v, "IsHatching") ~= nil then egg.IsHatching = rawget(v, "IsHatching") end

    local ownerUserId = rawget(v, "OwnerUserId") or (type(rec) == "table" and rawget(rec, "OwnerUserId")) or (type(res) == "table" and rawget(res, "OwnerUserId"))
    if ownerUserId then
        egg.OwnerUserId = tonumber(ownerUserId) or ownerUserId
        local pName = getPlayerNameByUserId(ownerUserId)
        if pName then egg.Owner = pName end
        egg.IsBase = true
    end

    local owner = rawget(v, "Owner") or rawget(v, "OwnerName") or rawget(v, "Player")
    if owner then
        egg.Owner = tostring(owner)
        egg.IsBase = true
    end

    local rawPos = rawget(v, "Position") or rawget(v, "BasePivot") or rawget(v, "CFrame")
    if typeof(rawPos) == "Vector3" then
        egg.Position = rawPos
    elseif typeof(rawPos) == "CFrame" then
        egg.Position = rawPos.Position
    end

    local rawInst = rawget(v, "Instance") or rawget(v, "Model")
    if typeof(rawInst) == "Instance" then
        egg.Instance = rawInst
        if not egg.Part then egg.Part = getPartFromModel(rawInst) end
    elseif type(rawInst) == "string" and #rawInst > 0 then
        egg.ModelName = rawInst
        if not egg.Instance or not egg.Instance.Parent then
            local found = Workspace:FindFirstChild(rawInst, true)
            if found then
                egg.Instance = found
                if not egg.Part then egg.Part = getPartFromModel(found) end
            end
        end
    end

    local rawPart = rawget(v, "Part")
    if typeof(rawPart) == "Instance" and rawPart:IsA("BasePart") then
        egg.Part = rawPart
    elseif egg.Instance and not egg.Part then
        egg.Part = getPartFromModel(egg.Instance)
    end

    if egg.Owner or egg.OwnerUserId then
        egg.IsBase = true
    elseif rawget(v, "IsBase") ~= nil then
        egg.IsBase = rawget(v, "IsBase")
    end

    if egg.IsBase and (not egg.AssetCategory or egg.AssetCategory == "Unknown Egg" or not egg.Mutations) then
        queryEggRecordServer(uid)
    end

    EggDataCache[uid] = egg
    return egg
end

local isScanningGC = false
local function scanGCForEggs()
    if isScanningGC then return end
    if typeof(getgc) ~= "function" then return end
    isScanningGC = true
    pcall(function()
        local gcs = getgc(true)
        for i = 1, #gcs do
            local v = gcs[i]
            if type(v) == "table" then
                local uid = rawget(v, "Uid") or rawget(v, "uid")
                if uid and type(uid) == "string" and #uid >= 10 then
                    processEggTable(v, uid)
                end
            end
            if i % 4000 == 0 then
                task.wait()
            end
        end
    end)
    isScanningGC = false
end

-- Ultra-Fast Cache-Driven Workspace Egg Resolver (Zero Full-Tree Scans)
local function resolveWorkspaceEggPositions()
    local resolved = {}

    -- 1. Direct fetch wild eggs from workspace.AreaEggSlotsClient (0ms instant)
    scanAreaEggSlots()

    -- 2. Link parts and positions
    for uid, egg in pairs(EggDataCache) do
        local part = egg.Part
        if not part or not part.Parent then
            if egg.Instance and egg.Instance.Parent then
                part = getPartFromModel(egg.Instance)
                egg.Part = part
            elseif egg.ModelName and #egg.ModelName > 0 then
                local found = Workspace:FindFirstChild(egg.ModelName, true)
                if found then
                    egg.Instance = found
                    part = getPartFromModel(found)
                    egg.Part = part
                end
            end
        end

        if part and part.Parent and part:IsA("BasePart") then
            egg.Position = part.Position
        end

        -- If Part is not physically found yet but egg.Position is known, create invisible anchor part
        if (not egg.Part or not egg.Part.Parent) and egg.Position then
            if not egg.VirtualPart or not egg.VirtualPart.Parent then
                local vp = Instance.new("Part")
                vp.Name = "VirtualEggPart_" .. tostring(uid):sub(1, 8)
                vp.Size = Vector3.new(1.5, 1.5, 1.5)
                vp.Transparency = 1
                vp.CanCollide = false
                vp.Anchored = true
                vp.Position = egg.Position
                vp.Parent = Workspace
                egg.VirtualPart = vp
            else
                egg.VirtualPart.Position = egg.Position
            end
            egg.Part = egg.VirtualPart
        end

        if egg.Part and egg.Part.Parent then
            resolved[uid] = egg
        end
    end

    return resolved
end

-- Event-driven linker for new egg spawns (Zero CPU overhead)
Workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") or desc:IsA("BasePart") then
        local dName = desc.Name
        for uid, egg in pairs(EggDataCache) do
            if not egg.Instance or not egg.Instance.Parent then
                if dName:find(uid, 1, true) or (egg.OwnerUserId and dName:find(tostring(egg.OwnerUserId), 1, true)) then
                    egg.Instance = desc
                    egg.Part = getPartFromModel(desc)
                    if egg.Part then egg.Position = egg.Part.Position end
                end
            end
        end
    end
end)

-- ==============================================================================
-- // OFFICIAL EGGSTATE ESP ENGINE (Clean, Ultra-Fast, 0ms Lag)
-- ==============================================================================
local ActiveFieldESP = {}

local function removeFieldEggESP(uid)
    local esp = ActiveFieldESP[uid]
    if esp then
        if esp.Billboard and esp.Billboard.Parent then esp.Billboard:Destroy() end
        if esp.Highlight and esp.Highlight.Parent then esp.Highlight:Destroy() end
        if esp.Anchor and esp.Anchor.Parent then esp.Anchor:Destroy() end
        ActiveFieldESP[uid] = nil
    end
end

local function clearAllFieldEggESP()
    for uid in pairs(ActiveFieldESP) do
        removeFieldEggESP(uid)
    end
    table.clear(ActiveFieldESP)
end

local function createOrUpdateFieldEggESP(uid, data)
    if not State.EggESP then
        removeFieldEggESP(uid)
        return
    end

    local rawPos = data.Position
    local eggPos = nil
    if typeof(rawPos) == "Vector3" then
        eggPos = rawPos
    elseif typeof(rawPos) == "CFrame" then
        eggPos = rawPos.Position
    end

    local slotModel = nil
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    if slotsFolder then
        slotModel = slotsFolder:FindFirstChild(uid)
    end

    if not eggPos and slotModel then
        local p = getPartFromModel(slotModel)
        if p then eggPos = p.Position end
    end

    if not eggPos then
        removeFieldEggESP(uid)
        return
    end

    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    local dist = math.floor((eggPos - myPos).Magnitude)

    if dist > State.ESP_MaxDistance then
        removeFieldEggESP(uid)
        return
    end

    local mutsList = parseMutations(data.Mutations, data.BaseMutation)
    local themeColor, rarityTag, isRare = getEggRarityTheme(mutsList, data.BaseMutation)

    -- Filter logic
    if State.ESP_Filter == "Rare (Gold/Silver)" and not isRare then
        removeFieldEggESP(uid)
        return
    elseif State.ESP_Filter == "Gold Only" and not rarityTag:find("GOLD") then
        removeFieldEggESP(uid)
        return
    elseif State.ESP_Filter == "Silver Only" and not rarityTag:find("SILVER") then
        removeFieldEggESP(uid)
        return
    end

    local esp = ActiveFieldESP[uid]
    if not esp or not esp.Billboard or not esp.Billboard.Parent then
        local anchor = Instance.new("Part")
        anchor.Name = "EggAnchor_" .. tostring(uid):sub(1, 8)
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.Transparency = 1
        anchor.CanCollide = false
        anchor.CanTouch = false
        anchor.CanQuery = false
        anchor.Anchored = true
        anchor.Position = eggPos
        anchor.Parent = Workspace

        local bg = Instance.new("BillboardGui")
        bg.Name = "EggESP_" .. tostring(uid):sub(1, 8)
        bg.AlwaysOnTop = true
        bg.Size = UDim2.new(0, 190, 0, 52)
        bg.StudsOffset = Vector3.new(0, 3.5, 0)
        bg.MaxDistance = State.ESP_MaxDistance
        bg.Adornee = anchor

        local frame = Instance.new("Frame")
        frame.Name = "Card"
        frame.Size = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
        frame.BackgroundTransparency = 0.2
        frame.BorderSizePixel = 0
        frame.Parent = bg

        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(0, 7)

        local stroke = Instance.new("UIStroke", frame)
        stroke.Name = "Stroke"
        stroke.Thickness = 1.6
        stroke.Color = themeColor
        stroke.Transparency = 0.15

        local padding = Instance.new("UIPadding", frame)
        padding.PaddingTop = UDim.new(0, 4)
        padding.PaddingBottom = UDim.new(0, 4)
        padding.PaddingLeft = UDim.new(0, 7)
        padding.PaddingRight = UDim.new(0, 7)

        local titleLabel = Instance.new("TextLabel", frame)
        titleLabel.Name = "TitleLabel"
        titleLabel.Size = UDim2.new(1, 0, 0, 17)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 12
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.RichText = true
        titleLabel.Parent = frame

        local detailLabel = Instance.new("TextLabel", frame)
        detailLabel.Name = "DetailLabel"
        detailLabel.Size = UDim2.new(1, 0, 0, 14)
        detailLabel.Position = UDim2.new(0, 0, 0, 17)
        detailLabel.BackgroundTransparency = 1
        detailLabel.Font = Enum.Font.GothamMedium
        detailLabel.TextSize = 10
        detailLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.RichText = true
        detailLabel.Parent = frame

        local distLabel = Instance.new("TextLabel", frame)
        distLabel.Name = "DistLabel"
        distLabel.Size = UDim2.new(1, 0, 0, 13)
        distLabel.Position = UDim2.new(0, 0, 0, 31)
        distLabel.BackgroundTransparency = 1
        distLabel.Font = Enum.Font.Gotham
        distLabel.TextSize = 10
        distLabel.TextColor3 = Color3.fromRGB(150, 225, 255)
        distLabel.TextXAlignment = Enum.TextXAlignment.Left
        distLabel.RichText = true
        distLabel.Parent = frame

        local hl = nil
        if State.ESP_Highlight and slotModel then
            hl = Instance.new("Highlight")
            hl.Name = "EggHL_" .. tostring(uid):sub(1, 8)
            hl.Adornee = slotModel
            hl.FillColor = themeColor
            hl.FillTransparency = 0.65
            hl.OutlineColor = themeColor
            hl.OutlineTransparency = 0.15
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = slotModel
        end

        bg.Parent = anchor

        esp = {
            Billboard = bg,
            Highlight = hl,
            Anchor = anchor,
            Card = frame,
            Stroke = stroke,
            TitleLabel = titleLabel,
            DetailLabel = detailLabel,
            DistLabel = distLabel,
            SlotModel = slotModel
        }
        ActiveFieldESP[uid] = esp
    end

    if esp.Anchor and esp.Anchor.Position ~= eggPos then
        esp.Anchor.Position = eggPos
    end
    esp.Stroke.Color = themeColor

    if esp.Highlight then
        esp.Highlight.FillColor = themeColor
        esp.Highlight.OutlineColor = themeColor
        esp.Highlight.Enabled = State.ESP_Highlight
    elseif State.ESP_Highlight and slotModel and not esp.Highlight then
        local hl = Instance.new("Highlight")
        hl.Name = "EggHL_" .. tostring(uid):sub(1, 8)
        hl.Adornee = slotModel
        hl.FillColor = themeColor
        hl.FillTransparency = 0.65
        hl.OutlineColor = themeColor
        hl.OutlineTransparency = 0.15
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = slotModel
        esp.Highlight = hl
    end

    local animalName = data.AssetCategory or "Unknown Egg"
    local statusPrefix = ""
    if data.Ready == true then
        statusPrefix = '<font color="#00FF88">[READY]</font> '
    elseif data.IsHatching == true then
        statusPrefix = '<font color="#FFA500">[HATCHING]</font> '
    end

    esp.TitleLabel.Text = string.format('🥚 %s<b>%s</b> <font color="#%02X%02X%02X">[%s]</font>',
        statusPrefix,
        animalName,
        math.floor(themeColor.R * 255),
        math.floor(themeColor.G * 255),
        math.floor(themeColor.B * 255),
        rarityTag
    )

    local details = {}
    if State.ESP_ShowMutations and #mutsList > 0 then
        table.insert(details, "✨ " .. table.concat(mutsList, ", "))
    end
    if State.ESP_ShowScales then
        local sc = {}
        if data.NestScale then table.insert(sc, string.format("Nest: %.1fx", tonumber(data.NestScale) or 1)) end
        if data.AssetScale then table.insert(sc, string.format("Pet: %.1fx", tonumber(data.AssetScale) or 1)) end
        if #sc > 0 then table.insert(details, "📏 " .. table.concat(sc, " | ")) end
    end
    if #details == 0 then
        table.insert(details, "Zone Field Egg")
    end
    esp.DetailLabel.Text = table.concat(details, " • ")

    if State.ESP_ShowDistance then
        esp.DistLabel.Text = string.format("📍 <b>%d studs</b> • <font color=\"#00FF7F\">🌲 Wild</font>", dist)
        esp.DistLabel.Visible = true
    else
        esp.DistLabel.Visible = false
    end
end

local function scanAndRenderEggStateESP()
    local ok, EggState = pcall(function()
        local client = ReplicatedStorage:FindFirstChild("Client")
        return client and client:FindFirstChild("EggState") and require(client.EggState)
    end)
    if not ok or not EggState then return end

    local fieldEggs = nil
    pcall(function()
        if typeof(EggState.ReadFieldEggs) == "function" then
            fieldEggs = EggState.ReadFieldEggs()
        end
    end)

    local records = fieldEggs and fieldEggs.Records
    if not records or type(records) ~= "table" then
        if not State.EggESP then clearAllFieldEggESP() end
        return
    end

    local currentUids = {}
    for uid, data in pairs(records) do
        if type(data) == "table" and uid then
            currentUids[uid] = true

            -- Sync directly with EggDataCache for 3D Radar and quick actions
            local egg = EggDataCache[uid] or { Uid = uid }
            egg.AssetCategory = data.AssetCategory
            egg.BaseMutation = data.BaseMutation
            egg.Mutations = data.Mutations
            egg.NestScale = data.NestScale
            egg.AssetScale = data.AssetScale
            egg.Position = data.Position
            egg.Ready = data.Ready
            egg.IsHatching = data.IsHatching
            egg.IsBase = false

            local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
            if slotsFolder then
                local slot = slotsFolder:FindFirstChild(uid)
                if slot then
                    egg.Instance = slot
                    egg.Part = getPartFromModel(slot)
                end
            end
            EggDataCache[uid] = egg

            if State.EggESP then
                createOrUpdateFieldEggESP(uid, data)
            end
        end
    end

    -- Clean up removed eggs
    for activeUid in pairs(ActiveFieldESP) do
        if not currentUids[activeUid] then
            removeFieldEggESP(activeUid)
        end
    end
    for cacheUid, egg in pairs(EggDataCache) do
        if not egg.IsBase and not currentUids[cacheUid] then
            EggDataCache[cacheUid] = nil
        end
    end

    if not State.EggESP and next(ActiveFieldESP) then
        clearAllFieldEggESP()
    end
end

-- Dedicated fast background loop for EggState ESP (0ms lag, smooth updates)
task.spawn(function()
    while true do
        task.wait(0.35)
        pcall(scanAndRenderEggStateESP)
    end
end)

-- ==============================================================================
-- // Pet Model Database & 3D Animal Model Resolver (แสดงตัวสัตว์ ไม่ใช่ไข่)
-- ==============================================================================
local PetModelCache = {}
local PetIndexDone = false

local function indexPetFolder(parent, depth)
    depth = depth or 1
    if not parent or depth > 4 then return end
    for _, item in ipairs(parent:GetChildren()) do
        if item:IsA("Model") or item:IsA("BasePart") then
            local k = item.Name:lower():gsub("[%s_%-]+", "")
            if not PetModelCache[k] then PetModelCache[k] = item end
            for _, sub in ipairs(item:GetChildren()) do
                if sub:IsA("Model") or sub:IsA("BasePart") then
                    local sk = sub.Name:lower():gsub("[%s_%-]+", "")
                    if not PetModelCache[sk] then PetModelCache[sk] = sub end
                end
            end
        elseif item:IsA("Folder") or item:IsA("Configuration") then
            indexPetFolder(item, depth + 1)
        end
    end
end

local function scanAllPetModels()
    if PetIndexDone then return end
    PetIndexDone = true

    local repRoots = {
        ReplicatedStorage:FindFirstChild("Pets"),
        ReplicatedStorage:FindFirstChild("PetModels"),
        ReplicatedStorage:FindFirstChild("Animals"),
        ReplicatedStorage:FindFirstChild("Assets"),
        ReplicatedStorage:FindFirstChild("Models"),
        ReplicatedStorage:FindFirstChild("Packages"),
        ReplicatedStorage:FindFirstChild("Shared"),
        ReplicatedStorage:FindFirstChild("Common"),
        ReplicatedStorage:FindFirstChild("Prefabs"),
        ReplicatedStorage:FindFirstChild("Entities"),
        Workspace:FindFirstChild("Pets"),
        Workspace:FindFirstChild("PetModels"),
        Workspace:FindFirstChild("Animals"),
        Workspace:FindFirstChild("WildPets")
    }

    for _, r in ipairs(repRoots) do
        if r then
            indexPetFolder(r, 1)
            if r.Name == "Assets" or r.Name == "Models" or r.Name == "Packages" or r.Name == "Shared" then
                indexPetFolder(r:FindFirstChild("Pets"), 1)
                indexPetFolder(r:FindFirstChild("Animals"), 1)
                indexPetFolder(r:FindFirstChild("Models"), 1)
                indexPetFolder(r:FindFirstChild("PetModels"), 1)
            end
        end
    end

    for _, ch in ipairs(ReplicatedStorage:GetChildren()) do
        local n = ch.Name:lower()
        if n:find("pet") or n:find("animal") or n:find("creature") then
            indexPetFolder(ch, 1)
        end
    end
end

task.spawn(function()
    task.wait(0.5)
    scanAllPetModels()
end)

local function find3DModelForPet(petName, eggInstance)
    local pClean = petName and petName:lower():gsub("[%s_%-]+", "") or ""

    -- 1. Check PetModelCache (Fast O(1) lookup of indexed pet model)
    if #pClean > 0 then
        if not PetIndexDone then scanAllPetModels() end
        if PetModelCache[pClean] then
            return PetModelCache[pClean]
        end
        for name, model in pairs(PetModelCache) do
            if name:find(pClean, 1, true) or pClean:find(name, 1, true) then
                return model
            end
        end
    end

    -- 2. Fast native C++ recursive search in ReplicatedStorage
    if petName and #petName > 0 then
        local direct = ReplicatedStorage:FindFirstChild(petName, true)
        if direct and (direct:IsA("Model") or direct:IsA("BasePart")) then
            if #pClean > 0 then PetModelCache[pClean] = direct end
            return direct
        end
    end

    -- 3. Check inside eggInstance in Workspace for nested pet model
    if eggInstance then
        if #pClean > 0 then
            for _, desc in ipairs(eggInstance:GetDescendants()) do
                if desc:IsA("Model") or desc:IsA("BasePart") then
                    local dn = desc.Name:lower():gsub("[%s_%-]+", "")
                    if dn == pClean or dn:find(pClean, 1, true) or pClean:find(dn, 1, true) then
                        return desc
                    end
                end
            end
        end

        for _, desc in ipairs(eggInstance:GetDescendants()) do
            if desc:IsA("Model") then
                local dn = desc.Name:lower()
                if not dn:find("nest") and not dn:find("egg") and not dn:find("shell") and not dn:find("hitbox") and not dn:find("stand") then
                    return desc
                end
            end
        end

        for _, child in ipairs(eggInstance:GetChildren()) do
            local cn = child.Name:lower()
            if (child:IsA("Model") or child:IsA("BasePart")) and not cn:find("nest") and not cn:find("egg") and not cn:find("shell") and not cn:find("hitbox") and not cn:find("prompt") then
                return child
            end
        end
    end

    -- 4. Check equipped pets in Workspace
    if #pClean > 0 then
        for _, pl in ipairs(Players:GetPlayers()) do
            local char = pl.Character
            if char then
                for _, ch in ipairs(char:GetChildren()) do
                    if ch:IsA("Model") then
                        local cClean = ch.Name:lower():gsub("[%s_%-]+", "")
                        if cClean:find(pClean, 1, true) or pClean:find(cClean, 1, true) then
                            PetModelCache[pClean] = ch
                            return ch
                        end
                    end
                end
            end
        end
    end

    -- 5. Fallback: Return eggInstance
    if eggInstance and (eggInstance:IsA("Model") or eggInstance:IsA("BasePart")) then
        return eggInstance
    end

    return nil
end

-- ==============================================================================
-- // STANDALONE FLOATING HUD WINDOW: EGG RADAR & 3D PET INSPECTOR
-- ==============================================================================
local EggRadarGui = nil
local RadarMainFrame = nil
local RadarFeedScroll = nil
local RadarCountLabel = nil
local Radar3DViewport = nil
local RadarPreviewTitle = nil
local RadarPreviewStatus = nil
local RadarPreviewMuts = nil
local RadarPreviewScale = nil
local RadarPreviewLoc = nil
local RadarSearchBox = nil
local RadarFilter = "All"
local IsRadarMinimized = false

local function setupViewportModel(viewportFrame, model, petName)
    for _, child in ipairs(viewportFrame:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            child:Destroy()
        end
    end

    if not model then return nil end

    local pClean = petName and petName:lower():gsub("[%s_%-]+", "") or ""

    -- Check if model contains an explicit pet sub-model (separate from the egg)
    local targetModel = model
    if model:IsA("Model") or model:IsA("Folder") then
        if #pClean > 0 then
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("Model") then
                    local dn = desc.Name:lower():gsub("[%s_%-]+", "")
                    if dn == pClean or dn:find(pClean, 1, true) or pClean:find(dn, 1, true) then
                        targetModel = desc
                        break
                    end
                end
            end
        end
        if targetModel == model then
            for _, desc in ipairs(model:GetDescendants()) do
                if desc:IsA("Model") then
                    local dn = desc.Name:lower()
                    if not dn:find("egg") and not dn:find("nest") and not dn:find("shell") and not dn:find("hitbox") and not dn:find("stand") then
                        targetModel = desc
                        break
                    end
                end
            end
        end
    end

    local clone = targetModel:Clone()
    for _, d in ipairs(clone:GetDescendants()) do
        if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Highlight") or d:IsA("SurfaceGui") then
            d:Destroy()
        end
    end

    -- Remove egg shells, nests, stands, bases, and hitboxes so only the animal model is shown!
    local petParts = {}
    local eggParts = {}
    local eggKeywords = {"egg", "shell", "nest", "outer", "hitbox", "prompt", "stand", "base", "bowl", "hay", "pedestal", "ground", "platform", "shadow"}

    for _, child in ipairs(clone:GetDescendants()) do
        if child:IsA("BasePart") then
            local n = child.Name:lower()
            local isEgg = false
            for _, kw in ipairs(eggKeywords) do
                if n:find(kw) then
                    isEgg = true
                    break
                end
            end
            if isEgg then
                table.insert(eggParts, child)
            else
                table.insert(petParts, child)
            end
        end
    end

    if clone:IsA("BasePart") then
        local n = clone.Name:lower()
        local isEgg = false
        for _, kw in ipairs(eggKeywords) do
            if n:find(kw) then isEgg = true break end
        end
        if not isEgg then
            table.insert(petParts, clone)
        else
            table.insert(eggParts, clone)
        end
    end

    -- If we have animal parts alongside egg/nest parts, strip all egg parts completely!
    if #petParts > 0 and #eggParts > 0 then
        for _, ep in ipairs(eggParts) do
            ep:Destroy()
        end
    end

    -- Ensure all animal parts are completely visible (reset transparency if game hid the pet)
    for _, p in ipairs(clone:GetDescendants()) do
        if p:IsA("BasePart") then
            if p.Transparency > 0.8 then
                p.Transparency = 0
            end
            p.CastShadow = false
            p.CanCollide = false
        end
    end
    if clone:IsA("BasePart") and clone.Transparency > 0.8 then
        clone.Transparency = 0
    end

    clone.Parent = viewportFrame

    local cf, size
    if clone:IsA("Model") then
        cf, size = clone:GetBoundingBox()
    elseif clone:IsA("BasePart") then
        cf = clone.CFrame
        size = clone.Size
    else
        return nil
    end

    local maxDim = math.max(size.X, size.Y, size.Z)
    if maxDim <= 0 then maxDim = 2 end
    local dist = maxDim * 1.8

    local cam = viewportFrame:FindFirstChildOfClass("Camera")
    if not cam then
        cam = Instance.new("Camera")
        cam.Parent = viewportFrame
        viewportFrame.CurrentCamera = cam
    end

    local center = cf.Position
    cam.CFrame = CFrame.new(center + Vector3.new(0, maxDim * 0.35, dist), center)

    CurrentPreviewModel = clone
    CurrentPreviewCenter = center
    CurrentPreviewMaxDim = maxDim
    CurrentPreviewCam = cam

    return clone
end

local function selectEggForInspector(egg)
    if not egg then return end
    SelectedRadarUid = egg.Uid

    local mutsList = parseMutations(egg.Mutations, egg.BaseMutation)
    local themeColor, rarityTag = getEggRarityTheme(mutsList, egg.BaseMutation)
    local animalName = egg.AssetCategory or "Unknown Egg"

    if RadarPreviewTitle then
        RadarPreviewTitle.Text = string.format("<b>%s</b>", animalName)
        RadarPreviewTitle.TextColor3 = themeColor
    end

    if RadarPreviewStatus then
        local stText = "<font color=\"#38BDF8\">🥚 Egg In World</font>"
        if egg.Ready == true then
            stText = "<font color=\"#00FF88\">✨ [READY TO STEAL/HATCH]</font>"
        elseif egg.IsHatching == true then
            stText = "<font color=\"#FFA500\">⏳ [HATCHING IN PROGRESS]</font>"
        end
        RadarPreviewStatus.Text = stText .. " • <font color=\"#FFFFFF\">[" .. rarityTag .. "]</font>"
    end

    if RadarPreviewMuts then
        if #mutsList > 0 then
            RadarPreviewMuts.Text = "✨ Mutations: <b>" .. table.concat(mutsList, ", ") .. "</b>"
        else
            RadarPreviewMuts.Text = "✨ Mutations: <i>None (Normal)</i>"
        end
    end

    if RadarPreviewScale then
        local sc = {}
        if egg.NestScale then table.insert(sc, string.format("Nest: %.1fx", tonumber(egg.NestScale) or 1)) end
        if egg.AssetScale then table.insert(sc, string.format("Pet: %.1fx", tonumber(egg.AssetScale) or 1)) end
        if egg.TargetScale then table.insert(sc, string.format("Target: %.1fx", tonumber(egg.TargetScale) or 1)) end
        if #sc > 0 then
            RadarPreviewScale.Text = "📏 Scale Multipliers: <b>" .. table.concat(sc, " | ") .. "</b>"
        else
            RadarPreviewScale.Text = "📏 Scale Multipliers: <i>Default (1.0x)</i>"
        end
    end

    if RadarPreviewLoc then
        local hrp = getHRP()
        local myPos = hrp and hrp.Position or Vector3.zero
        local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
        local dStr = pos and string.format("%d studs", math.floor((pos - myPos).Magnitude)) or "Unknown"

        local locStr = egg.IsBase and ("🏠 House (" .. tostring(egg.Owner or "Player") .. ")") or "🌲 Wild Zone"
        RadarPreviewLoc.Text = string.format("📍 %s • <b>%s</b>", locStr, dStr)
    end

    if Radar3DViewport then
        local asset = find3DModelForPet(egg.AssetCategory, egg.Instance)
        setupViewportModel(Radar3DViewport, asset, egg.AssetCategory)
    end
end

local function refreshRadarList()
    if not RadarFeedScroll then return end

    for _, child in ipairs(RadarFeedScroll:GetChildren()) do
        if child:IsA("GuiObject") and child.Name:find("EggCard_") then
            child:Destroy()
        end
    end

    local searchText = RadarSearchBox and RadarSearchBox.Text:lower() or ""
    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Vector3.zero

    local sortedEggs = {}
    local totalCount = 0
    local wildCount = 0
    local baseCount = 0

    for uid, egg in pairs(EggDataCache) do
        totalCount = totalCount + 1
        if egg.IsBase then baseCount = baseCount + 1 else wildCount = wildCount + 1 end

        local mutsList = parseMutations(egg.Mutations, egg.BaseMutation)
        local _, rarityTag, isRare = getEggRarityTheme(mutsList, egg.BaseMutation)

        local passFilter = true
        if RadarFilter == "Rare" and not isRare then passFilter = false end
        if RadarFilter == "Gold" and not rarityTag:find("GOLD") then passFilter = false end
        if RadarFilter == "Silver" and not rarityTag:find("SILVER") then passFilter = false end
        if RadarFilter == "Wild" and egg.IsBase then passFilter = false end
        if RadarFilter == "Base" and not egg.IsBase then passFilter = false end

        local nameMatch = (egg.AssetCategory or ""):lower():find(searchText, 1, true)
        local ownerMatch = (egg.Owner or ""):lower():find(searchText, 1, true)
        if #searchText > 0 and not (nameMatch or ownerMatch) then
            passFilter = false
        end

        if passFilter then
            local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            local dist = pos and (pos - myPos).Magnitude or 99999
            table.insert(sortedEggs, { Egg = egg, Dist = dist, Theme = getEggRarityTheme(mutsList, egg.BaseMutation) })
        end
    end

    table.sort(sortedEggs, function(a, b) return a.Dist < b.Dist end)

    if RadarCountLabel then
        RadarCountLabel.Text = string.format("[ Total: %d | Wild: %d | Bases: %d ]", totalCount, wildCount, baseCount)
    end

    local layoutOrder = 0
    for _, item in ipairs(sortedEggs) do
        layoutOrder = layoutOrder + 1
        local egg = item.Egg
        local mutsList = parseMutations(egg.Mutations, egg.BaseMutation)
        local themeColor, rarityTag = getEggRarityTheme(mutsList, egg.BaseMutation)

        local card = Instance.new("TextButton")
        card.Name = "EggCard_" .. tostring(egg.Uid):sub(1, 8)
        card.Size = UDim2.new(1, -6, 0, 48)
        card.BackgroundColor3 = (SelectedRadarUid == egg.Uid) and Color3.fromRGB(32, 36, 52) or Color3.fromRGB(20, 20, 30)
        card.BorderSizePixel = 0
        card.LayoutOrder = layoutOrder
        card.AutoButtonColor = false
        card.Text = ""

        local cardCorner = Instance.new("UICorner", card)
        cardCorner.CornerRadius = UDim.new(0, 6)

        local cardStroke = Instance.new("UIStroke", card)
        cardStroke.Thickness = (SelectedRadarUid == egg.Uid) and 1.8 or 1
        cardStroke.Color = (SelectedRadarUid == egg.Uid) and themeColor or Color3.fromRGB(45, 45, 60)

        local cardPad = Instance.new("UIPadding", card)
        cardPad.PaddingLeft = UDim.new(0, 8)
        cardPad.PaddingRight = UDim.new(0, 8)
        cardPad.PaddingTop = UDim.new(0, 4)
        cardPad.PaddingBottom = UDim.new(0, 4)

        local titleLbl = Instance.new("TextLabel", card)
        titleLbl.Size = UDim2.new(1, 0, 0, 18)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 12
        titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.RichText = true

        local st = ""
        if egg.Ready == true then st = "<font color=\"#00FF88\">[READY]</font> " end
        titleLbl.Text = string.format("🥚 %s<b>%s</b> <font color=\"#%02X%02X%02X\">[%s]</font>",
            st,
            egg.AssetCategory or "Unknown",
            math.floor(themeColor.R * 255),
            math.floor(themeColor.G * 255),
            math.floor(themeColor.B * 255),
            rarityTag
        )

        local subLbl = Instance.new("TextLabel", card)
        subLbl.Size = UDim2.new(1, 0, 0, 16)
        subLbl.Position = UDim2.new(0, 0, 0, 20)
        subLbl.BackgroundTransparency = 1
        subLbl.Font = Enum.Font.Gotham
        subLbl.TextSize = 10
        subLbl.TextColor3 = Color3.fromRGB(160, 210, 255)
        subLbl.TextXAlignment = Enum.TextXAlignment.Left
        subLbl.RichText = true

        local locText = egg.IsBase and ("🏠 " .. tostring(egg.Owner or "Base")) or "🌲 Wild"
        local dStr = item.Dist < 90000 and string.format("%d studs", math.floor(item.Dist)) or "--"
        subLbl.Text = string.format("📍 %s • %s", dStr, locText)

        card.MouseButton1Click:Connect(function()
            selectEggForInspector(egg)
            refreshRadarList()
        end)

        card.Parent = RadarFeedScroll
    end

    if not SelectedRadarUid and #sortedEggs > 0 then
        selectEggForInspector(sortedEggs[1].Egg)
    end
end

local function createStandaloneRadarUI()
    if EggRadarGui and EggRadarGui.Parent then
        EggRadarGui.Enabled = true
        refreshRadarList()
        return
    end

    local guiParent = (gethui and gethui()) or LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
    EggRadarGui = Instance.new("ScreenGui")
    EggRadarGui.Name = "HyperEggRadar_Gui"
    EggRadarGui.ResetOnSpawn = false
    EggRadarGui.Parent = guiParent

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "RadarWindow"
    mainFrame.Size = UDim2.new(0, 590, 0, 390)
    mainFrame.Position = UDim2.new(0.5, -295, 0.5, -195)
    mainFrame.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = EggRadarGui
    RadarMainFrame = mainFrame

    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Thickness = 1.8
    stroke.Color = Color3.fromRGB(56, 140, 255)

    -- Topbar (Draggable)
    local topbar = Instance.new("Frame")
    topbar.Name = "Topbar"
    topbar.Size = UDim2.new(1, 0, 0, 38)
    topbar.BackgroundColor3 = Color3.fromRGB(22, 24, 36)
    topbar.BorderSizePixel = 0
    topbar.Parent = mainFrame

    local tbCorner = Instance.new("UICorner", topbar)
    tbCorner.CornerRadius = UDim.new(0, 10)

    local title = Instance.new("TextLabel", topbar)
    title.Size = UDim2.new(0, 280, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "🥚 EGG RADAR & 3D PET INSPECTOR"

    local countBadge = Instance.new("TextLabel", topbar)
    countBadge.Size = UDim2.new(0, 180, 1, 0)
    countBadge.Position = UDim2.new(0, 285, 0, 0)
    countBadge.BackgroundTransparency = 1
    countBadge.Font = Enum.Font.GothamMedium
    countBadge.TextSize = 11
    countBadge.TextColor3 = Color3.fromRGB(140, 200, 255)
    countBadge.TextXAlignment = Enum.TextXAlignment.Left
    countBadge.Text = "[ Scanning... ]"
    RadarCountLabel = countBadge

    -- Topbar Action Buttons
    local btnContainer = Instance.new("Frame", topbar)
    btnContainer.Size = UDim2.new(0, 85, 1, 0)
    btnContainer.Position = UDim2.new(1, -95, 0, 0)
    btnContainer.BackgroundTransparency = 1

    local btnLayout = Instance.new("UIListLayout", btnContainer)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    btnLayout.Padding = UDim.new(0, 6)

    local refreshBtn = Instance.new("TextButton", btnContainer)
    refreshBtn.Size = UDim2.new(0, 24, 0, 24)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 60)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = 12
    refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshBtn.Text = "🔄"
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)

    local miniBtn = Instance.new("TextButton", btnContainer)
    miniBtn.Size = UDim2.new(0, 24, 0, 24)
    miniBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 60)
    miniBtn.Font = Enum.Font.GothamBold
    miniBtn.TextSize = 12
    miniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    miniBtn.Text = "–"
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 6)

    local closeBtn = Instance.new("TextButton", btnContainer)
    closeBtn.Size = UDim2.new(0, 24, 0, 24)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 60)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Text = "✕"
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

    -- Window Dragging Logic
    local dragging, dragInput, dragStart, startPos
    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Body Container
    local body = Instance.new("Frame", mainFrame)
    body.Name = "Body"
    body.Size = UDim2.new(1, -20, 1, -48)
    body.Position = UDim2.new(0, 10, 0, 42)
    body.BackgroundTransparency = 1

    -- Left Column (List)
    local leftCol = Instance.new("Frame", body)
    leftCol.Name = "LeftCol"
    leftCol.Size = UDim2.new(0, 275, 1, 0)
    leftCol.BackgroundTransparency = 1

    -- Search bar
    local searchBar = Instance.new("TextBox", leftCol)
    searchBar.Name = "SearchBar"
    searchBar.Size = UDim2.new(1, 0, 0, 26)
    searchBar.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
    searchBar.Font = Enum.Font.Gotham
    searchBar.TextSize = 11
    searchBar.TextColor3 = Color3.fromRGB(240, 240, 255)
    searchBar.PlaceholderColor3 = Color3.fromRGB(120, 130, 160)
    searchBar.PlaceholderText = "🔍 Search pet or owner..."
    searchBar.Text = ""
    searchBar.ClearTextOnFocus = false
    Instance.new("UICorner", searchBar).CornerRadius = UDim.new(0, 6)
    RadarSearchBox = searchBar

    searchBar:GetPropertyChangedSignal("Text"):Connect(function()
        refreshRadarList()
    end)

    -- Filter Buttons Bar
    local filterBar = Instance.new("Frame", leftCol)
    filterBar.Name = "FilterBar"
    filterBar.Size = UDim2.new(1, 0, 0, 24)
    filterBar.Position = UDim2.new(0, 0, 0, 30)
    filterBar.BackgroundTransparency = 1

    local fLayout = Instance.new("UIListLayout", filterBar)
    fLayout.FillDirection = Enum.FillDirection.Horizontal
    fLayout.Padding = UDim.new(0, 4)

    local filters = { "All", "Rare", "Gold", "Silver", "Wild", "Base" }
    for _, fName in ipairs(filters) do
        local fBtn = Instance.new("TextButton", filterBar)
        fBtn.Size = UDim2.new(0, 42, 1, 0)
        fBtn.BackgroundColor3 = (RadarFilter == fName) and Color3.fromRGB(56, 140, 255) or Color3.fromRGB(28, 30, 44)
        fBtn.Font = Enum.Font.GothamBold
        fBtn.TextSize = 10
        fBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        fBtn.Text = fName
        Instance.new("UICorner", fBtn).CornerRadius = UDim.new(0, 4)

        fBtn.MouseButton1Click:Connect(function()
            RadarFilter = fName
            for _, b in ipairs(filterBar:GetChildren()) do
                if b:IsA("TextButton") then
                    b.BackgroundColor3 = (b.Text == fName) and Color3.fromRGB(56, 140, 255) or Color3.fromRGB(28, 30, 44)
                end
            end
            refreshRadarList()
        end)
    end

    -- Scroll Feed
    local scroll = Instance.new("ScrollingFrame", leftCol)
    scroll.Name = "FeedScroll"
    scroll.Size = UDim2.new(1, 0, 1, -60)
    scroll.Position = UDim2.new(0, 0, 0, 58)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(70, 80, 120)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    RadarFeedScroll = scroll

    local scrollLayout = Instance.new("UIListLayout", scroll)
    scrollLayout.Padding = UDim.new(0, 5)
    scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder

    -- Right Column (3D Viewport & Inspector)
    local rightCol = Instance.new("Frame", body)
    rightCol.Name = "RightCol"
    rightCol.Size = UDim2.new(1, -285, 1, 0)
    rightCol.Position = UDim2.new(0, 285, 0, 0)
    rightCol.BackgroundTransparency = 1

    -- Viewport Frame
    local vp = Instance.new("ViewportFrame", rightCol)
    vp.Name = "ModelViewport"
    vp.Size = UDim2.new(1, 0, 0, 160)
    vp.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    vp.BorderSizePixel = 0
    Instance.new("UICorner", vp).CornerRadius = UDim.new(0, 8)
    local vpStroke = Instance.new("UIStroke", vp)
    vpStroke.Color = Color3.fromRGB(50, 70, 110)
    vpStroke.Thickness = 1
    Radar3DViewport = vp

    local vpWatermark = Instance.new("TextLabel", vp)
    vpWatermark.Size = UDim2.new(1, -10, 0, 18)
    vpWatermark.Position = UDim2.new(0, 8, 1, -22)
    vpWatermark.BackgroundTransparency = 1
    vpWatermark.Font = Enum.Font.GothamMedium
    vpWatermark.TextSize = 10
    vpWatermark.TextColor3 = Color3.fromRGB(100, 130, 180)
    vpWatermark.TextXAlignment = Enum.TextXAlignment.Left
    vpWatermark.Text = "3D Real-Time Model Preview"

    -- Info Box
    local infoBox = Instance.new("Frame", rightCol)
    infoBox.Name = "InfoBox"
    infoBox.Size = UDim2.new(1, 0, 0, 110)
    infoBox.Position = UDim2.new(0, 0, 0, 168)
    infoBox.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
    Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)
    local infoPad = Instance.new("UIPadding", infoBox)
    infoPad.PaddingLeft = UDim.new(0, 8)
    infoPad.PaddingRight = UDim.new(0, 8)
    infoPad.PaddingTop = UDim.new(0, 6)
    infoPad.PaddingBottom = UDim.new(0, 6)

    local pTitle = Instance.new("TextLabel", infoBox)
    pTitle.Size = UDim2.new(1, 0, 0, 20)
    pTitle.BackgroundTransparency = 1
    pTitle.Font = Enum.Font.GothamBold
    pTitle.TextSize = 14
    pTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    pTitle.TextXAlignment = Enum.TextXAlignment.Left
    pTitle.RichText = true
    pTitle.Text = "Select an Egg"
    RadarPreviewTitle = pTitle

    local pStatus = Instance.new("TextLabel", infoBox)
    pStatus.Size = UDim2.new(1, 0, 0, 16)
    pStatus.Position = UDim2.new(0, 0, 0, 20)
    pStatus.BackgroundTransparency = 1
    pStatus.Font = Enum.Font.GothamMedium
    pStatus.TextSize = 11
    pStatus.TextColor3 = Color3.fromRGB(0, 255, 136)
    pStatus.TextXAlignment = Enum.TextXAlignment.Left
    pStatus.RichText = true
    pStatus.Text = "No Egg Selected"
    RadarPreviewStatus = pStatus

    local pMuts = Instance.new("TextLabel", infoBox)
    pMuts.Size = UDim2.new(1, 0, 0, 16)
    pMuts.Position = UDim2.new(0, 0, 0, 38)
    pMuts.BackgroundTransparency = 1
    pMuts.Font = Enum.Font.Gotham
    pMuts.TextSize = 10
    pMuts.TextColor3 = Color3.fromRGB(210, 210, 220)
    pMuts.TextXAlignment = Enum.TextXAlignment.Left
    pMuts.RichText = true
    pMuts.Text = "✨ Mutations: None"
    RadarPreviewMuts = pMuts

    local pScale = Instance.new("TextLabel", infoBox)
    pScale.Size = UDim2.new(1, 0, 0, 16)
    pScale.Position = UDim2.new(0, 0, 0, 56)
    pScale.BackgroundTransparency = 1
    pScale.Font = Enum.Font.Gotham
    pScale.TextSize = 10
    pScale.TextColor3 = Color3.fromRGB(200, 200, 210)
    pScale.TextXAlignment = Enum.TextXAlignment.Left
    pScale.RichText = true
    pScale.Text = "📏 Scale Multipliers: Default"
    RadarPreviewScale = pScale

    local pLoc = Instance.new("TextLabel", infoBox)
    pLoc.Size = UDim2.new(1, 0, 0, 16)
    pLoc.Position = UDim2.new(0, 0, 0, 74)
    pLoc.BackgroundTransparency = 1
    pLoc.Font = Enum.Font.Gotham
    pLoc.TextSize = 10
    pLoc.TextColor3 = Color3.fromRGB(160, 220, 255)
    pLoc.TextXAlignment = Enum.TextXAlignment.Left
    pLoc.RichText = true
    pLoc.Text = "📍 Location: --"
    RadarPreviewLoc = pLoc

    -- Action Buttons Row
    local actRow = Instance.new("Frame", rightCol)
    actRow.Name = "ActionRow"
    actRow.Size = UDim2.new(1, 0, 0, 34)
    actRow.Position = UDim2.new(0, 0, 1, -36)
    actRow.BackgroundTransparency = 1

    local actLayout = Instance.new("UIListLayout", actRow)
    actLayout.FillDirection = Enum.FillDirection.Horizontal
    actLayout.Padding = UDim.new(0, 8)

    local flyBtn = Instance.new("TextButton", actRow)
    flyBtn.Size = UDim2.new(0.48, -4, 1, 0)
    flyBtn.BackgroundColor3 = Color3.fromRGB(36, 110, 220)
    flyBtn.Font = Enum.Font.GothamBold
    flyBtn.TextSize = 11
    flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    flyBtn.Text = "🚀 Fly to Egg"
    Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(0, 6)

    flyBtn.MouseButton1Click:Connect(function()
        if not SelectedRadarUid or not EggDataCache[SelectedRadarUid] then
            notify("RADAR", "Please select an egg from the list first!", "rbxassetid://10709791437", 2)
            return
        end
        local egg = EggDataCache[SelectedRadarUid]
        local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
        if pos then
            notify("FLYING TO EGG", "Target: " .. tostring(egg.AssetCategory or "Egg"), "rbxassetid://10709790948", 2.5)
            flyToTarget(pos, function()
                notify("ARRIVED", "Reached target egg!", "rbxassetid://10709791437", 2)
            end)
        else
            notify("ERROR", "Could not locate position of this egg.", "rbxassetid://10709791437", 2)
        end
    end)

    local warpBtn = Instance.new("TextButton", actRow)
    warpBtn.Size = UDim2.new(0.48, -4, 1, 0)
    warpBtn.BackgroundColor3 = Color3.fromRGB(16, 160, 120)
    warpBtn.Font = Enum.Font.GothamBold
    warpBtn.TextSize = 11
    warpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    warpBtn.Text = "⚡ Teleport"
    Instance.new("UICorner", warpBtn).CornerRadius = UDim.new(0, 6)

    warpBtn.MouseButton1Click:Connect(function()
        if not SelectedRadarUid or not EggDataCache[SelectedRadarUid] then
            notify("RADAR", "Please select an egg from the list first!", "rbxassetid://10709791437", 2)
            return
        end
        local egg = EggDataCache[SelectedRadarUid]
        local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
        if pos then
            teleportDirect(pos)
            notify("WARPED", "Teleported to " .. tostring(egg.AssetCategory or "Egg"), "rbxassetid://10709791437", 2)
        else
            notify("ERROR", "Could not locate position of this egg.", "rbxassetid://10709791437", 2)
        end
    end)

    -- Topbar Button Actions
    refreshBtn.MouseButton1Click:Connect(function()
        scanGCForEggs()
        resolveWorkspaceEggPositions()
        refreshRadarList()
        notify("RADAR", "Scanned memory & workspace for eggs!", "rbxassetid://10709791437", 2)
    end)

    miniBtn.MouseButton1Click:Connect(function()
        IsRadarMinimized = not IsRadarMinimized
        if IsRadarMinimized then
            body.Visible = false
            mainFrame.Size = UDim2.new(0, 360, 0, 38)
            miniBtn.Text = "□"
        else
            body.Visible = true
            mainFrame.Size = UDim2.new(0, 590, 0, 390)
            miniBtn.Text = "–"
            refreshRadarList()
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        EggRadarGui.Enabled = false
    end)

    refreshRadarList()
end

-- 360 Rotation Orbit Loop for 3D Viewport (Only runs when Radar is open & visible!)
RunService.RenderStepped:Connect(function(dt)
    if not EggRadarGui or not EggRadarGui.Enabled or IsRadarMinimized then return end
    if not CurrentPreviewCam or not CurrentPreviewCenter or not CurrentPreviewModel then return end
    SpinAngle = (SpinAngle + dt * 40) % 360
    local rad = math.rad(SpinAngle)
    local dist = CurrentPreviewMaxDim * 1.8
    local camX = CurrentPreviewCenter.X + math.sin(rad) * dist
    local camZ = CurrentPreviewCenter.Z + math.cos(rad) * dist
    local camY = CurrentPreviewCenter.Y + CurrentPreviewMaxDim * 0.35
    CurrentPreviewCam.CFrame = CFrame.new(Vector3.new(camX, camY, camZ), CurrentPreviewCenter)
end)

-- Immediate & Background Scanner Loop
task.spawn(function()
    -- Immediate scan upon script execution
    scanAreaEggSlots()
    scanGCForEggs()
    resolveWorkspaceEggPositions()
    while true do
        task.wait(4)
        scanAreaEggSlots()
        scanGCForEggs()
    end
end)

-- Background Radar Refresh Loop (Only runs when Radar is open)
local lastRadarRefresh = 0

RunService.Heartbeat:Connect(function()
    local now = tick()
    if EggRadarGui and EggRadarGui.Enabled and not IsRadarMinimized and (now - lastRadarRefresh > 3.0) then
        lastRadarRefresh = now
        resolveWorkspaceEggPositions()
        refreshRadarList()
    end
end)
-- ==============================================================================
-- // UI Window Creation (HYPER HUB UI)
-- ==============================================================================
local Window = Library:Window({
    Title = "HYPER HUB",
    Desc = "Steal an Egg Roblox | Pro Automation",
    Version = "v3.0",
    Icon = "https://i.postimg.cc/c4VhHd3s/HYPER-v2.png",
    Theme = "Dark",
    Config = {
        Keybind = Enum.KeyCode.RightControl,
        Size = UDim2.new(0, 650, 0, 500),
        DesktopSize = UDim2.new(0, 650, 0, 500),
        MobileSize = UDim2.new(0, 600, 0, 440),
        TabWidth = 160
    },
    CloseUIButton = {
        Enabled = true
    },
    Profile = {
        Username = LocalPlayer.Name,
        Email = "Steal an Egg Hub",
        AvatarUrl = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"
    }
})

-- TAB 1: FLIGHT & ZONES
local MainTab = Window:Tab({ Title = "Flight & Zones", Icon = "rbxassetid://10709790948" })

MainTab:Section({ Title = "Zone Teleportation & Fly Control" })

MainTab:Dropdown({
    Title = "Select Destination Zone",
    Desc = "Choose a destination zone to fly or teleport to",
    List = ZoneOrder,
    Value = State.SelectedZone,
    Callback = function(val)
        State.SelectedZone = val
    end
})

MainTab:Button({
    Title = "Fly to Selected Zone (Height 160)",
    Desc = "Starts 3-stage smooth flight to target coordinate",
    Callback = function()
        local pos = Zones[State.SelectedZone]
        if pos then
            notify("Flying to " .. State.SelectedZone, "Alt: " .. tostring(State.TweenHeight) .. " | Straight: " .. tostring(State.TweenSpeed) .. " | Ascend: " .. tostring(State.AscendSpeed), "rbxassetid://10709790948", 2.5)
            flyToTarget(pos, function()
                notify("Arrived!", "Successfully reached " .. State.SelectedZone, "rbxassetid://10709791437", 2.5)
            end)
        end
    end
})

MainTab:Button({
    Title = "Instant Teleport to Selected Zone",
    Desc = "Instantly warps your character directly to the zone",
    Callback = function()
        local pos = Zones[State.SelectedZone]
        if pos then
            teleportDirect(pos)
            notify("Teleported", "Warped to " .. State.SelectedZone, "rbxassetid://10709791437", 2)
        end
    end
})

MainTab:Button({
    Title = "Cancel Flight / Tween",
    Desc = "Stops current flight immediately",
    Callback = function()
        cancelTween()
        notify("Flight Cancelled", "Tween stopped.", "rbxassetid://10709791437", 2)
    end
})

MainTab:Section({ Title = "Flight Physics & Speed Adjustments" })

MainTab:Slider({
    Title = "Straight Flight Speed (ทางตรง)",
    Desc = "Cruise speed during straight flight (default: 110 | Max: 1200)",
    Min = 20,
    Max = 1200,
    Value = State.TweenSpeed,
    Callback = function(val)
        State.TweenSpeed = val
    end
})

MainTab:Slider({
    Title = "Ascend Launch Speed (พุ่งขึ้นฟ้า)",
    Desc = "Fast launch speed when ascending (default: 380 | Max: 1500)",
    Min = 50,
    Max = 1500,
    Value = State.AscendSpeed,
    Callback = function(val)
        State.AscendSpeed = val
    end
})

MainTab:Slider({
    Title = "Descend Landing Speed (ร่อนลงพื้น)",
    Desc = "Smooth descent speed to target zone (default: 220 | Max: 1000)",
    Min = 50,
    Max = 1000,
    Value = State.DescendSpeed,
    Callback = function(val)
        State.DescendSpeed = val
    end
})

MainTab:Slider({
    Title = "Flight Altitude Height (ความสูงเพดานบิน)",
    Desc = "Height during cruise stage (default: 160 | Max: 500)",
    Min = 50,
    Max = 500,
    Value = State.TweenHeight,
    Callback = function(val)
        State.TweenHeight = val
    end
})

-- ==============================================================================
-- // TAB 2: EGG RADAR
-- ==============================================================================
local EggRadarTab = Window:Tab({ Title = "Egg Radar", Icon = "rbxassetid://10723346959" })

EggRadarTab:Section({ Title = "📡 Standalone 3D Pet Inspector HUD" })

EggRadarTab:Button({
    Title = "Open 3D Egg Radar Window (เปิดหน้าต่างเรดาร์ 3D)",
    Desc = "Opens the standalone floating window with live 3D pet models & stats",
    Callback = function()
        createStandaloneRadarUI()
        notify("EGG RADAR", "Opened Standalone 3D Egg Radar HUD!", "rbxassetid://10723346959", 2.5)
    end
})

EggRadarTab:Section({ Title = "Navigation & Teleportation" })

EggRadarTab:Button({
    Title = "Fly to Closest Rare Egg (Gold / Silver)",
    Desc = "Starts 3-stage smooth flight to nearest Gold, Silver, or Rare egg",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local myPos = hrp.Position

        local bestEgg = nil
        local bestDist = math.huge

        for uid, egg in pairs(EggDataCache) do
            local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            if pos then
                local mutsList = parseMutations(egg.Mutations, egg.BaseMutation)
                local _, _, isRare = getEggRarityTheme(mutsList, egg.BaseMutation)
                if isRare then
                    local d = (pos - myPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestEgg = egg
                    end
                end
            end
        end

        if bestEgg and (bestEgg.Position or (bestEgg.Instance and getPartFromModel(bestEgg.Instance))) then
            local targetPos = bestEgg.Position or getPartFromModel(bestEgg.Instance).Position
            notify("FLYING TO RARE EGG", "Target: " .. tostring(bestEgg.AssetCategory or "Rare Egg") .. " (" .. math.floor(bestDist) .. " studs)", "rbxassetid://10709790948", 3)
            flyToTarget(targetPos, function()
                notify("ARRIVED", "Reached Rare Egg!", "rbxassetid://10709791437", 2)
            end)
        else
            notify("NO RARE EGGS", "No Gold/Silver rare eggs detected in range!", "rbxassetid://10709791437", 3)
        end
    end
})

EggRadarTab:Button({
    Title = "Teleport to Closest Egg",
    Desc = "Warps directly to the nearest egg of any rarity",
    Callback = function()
        local hrp = getHRP()
        if not hrp then return end
        local myPos = hrp.Position

        local bestPos = nil
        local bestDist = math.huge
        local bestName = "Egg"

        for uid, egg in pairs(EggDataCache) do
            local pos = egg.Position or (egg.Instance and getPartFromModel(egg.Instance) and getPartFromModel(egg.Instance).Position)
            if pos then
                local d = (pos - myPos).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPos = pos
                    bestName = egg.AssetCategory or "Egg"
                end
            end
        end

        if bestPos then
            teleportDirect(bestPos)
            notify("WARPED TO EGG", "Teleported to " .. bestName .. " (" .. math.floor(bestDist) .. " studs)", "rbxassetid://10709791437", 2)
        else
            notify("NO EGGS", "No eggs detected in range yet.", "rbxassetid://10709791437", 2)
        end
    end
})

EggRadarTab:Button({
    Title = "Force Rescan Memory (Lua GC)",
    Desc = "Immediately scans Lua GC memory and links all eggs in houses & wild",
    Callback = function()
        scanGCForEggs()
        resolveWorkspaceEggPositions()
        local count = 0
        local wildCount = 0
        local baseCount = 0
        for _, egg in pairs(EggDataCache) do
            count = count + 1
            if egg.IsBase then baseCount = baseCount + 1 else wildCount = wildCount + 1 end
        end
        if refreshRadarList then refreshRadarList() end
        notify("EGG SCANNER", string.format("Scanned! Found %d eggs (%d Wild, %d In Houses).", count, wildCount, baseCount), "rbxassetid://10709791437", 3.5)
    end
})
-- TAB 3: QUICK ZONE TELEPORTS
local ZonesTab = Window:Tab({ Title = "Quick Zones", Icon = "rbxassetid://10709791437" })

ZonesTab:Section({ Title = "Direct 1-Click Zone Flights" })

for _, zName in ipairs(ZoneOrder) do
    local coord = Zones[zName]
    ZonesTab:Button({
        Title = "Fly to " .. zName,
        Desc = string.format("Coord: %d, %d, %d", coord.X, coord.Y, coord.Z),
        Callback = function()
            State.SelectedZone = zName
            flyToTarget(coord, function()
                notify("Arrived", "Reached " .. zName, "rbxassetid://10709791437", 2)
            end)
        end
    })
end

-- TAB 3: PLAYER & GOD MODE
local PlayerTab = Window:Tab({ Title = "Player & GodMode", Icon = "rbxassetid://10709791523" })

PlayerTab:Section({ Title = "Invincibility & Protection" })

PlayerTab:Toggle({
    Title = "God Mode (Recreate Humanoid)",
    Desc = "Clone Humanoid & sever server damage link (Old God Mode)",
    Value = State.GodMode,
    Callback = function(val)
        toggleGodMode(val)
    end
})

PlayerTab:Toggle({
    Title = "Noclip (Walk Through Walls)",
    Desc = "Disables collision on all character parts",
    Value = State.Noclip,
    Callback = function(val)
        toggleNoclip(val)
    end
})

PlayerTab:Toggle({
    Title = "Infinite Jump",
    Desc = "Allows jumping continuously in air",
    Value = State.InfJump,
    Callback = function(val)
        State.InfJump = val
    end
})

PlayerTab:Toggle({
    Title = "Auto Doff Treadmill on Jump",
    Desc = "Automatically exits treadmill (AskDoff) when pressing jump",
    Value = State.AutoDoffTreadmill,
    Callback = function(val)
        State.AutoDoffTreadmill = val
    end
})

PlayerTab:Toggle({
    Title = "Instant Proximity Prompts (กด E ทันที)",
    Desc = "Instantly triggers interact prompts without holding (HoldDuration = 0)",
    Value = State.InstantPrompt,
    Callback = function(val)
        toggleInstantPrompt(val)
        notify("INSTANT PROMPT", val and "Instant Proximity Prompts ENABLED!" or "Instant Proximity Prompts DISABLED.", "rbxassetid://10709791437", 2)
    end
})

PlayerTab:Section({ Title = "Character Orientation (หันหน้าลงดิน)" })

PlayerTab:Toggle({
    Title = "Character Face Down (หันหน้า/ตัวลงดิน 90°)",
    Desc = "Locks character pitch to face directly down into the ground (continuous)",
    Value = State.FaceDown,
    Callback = function(val)
        toggleFaceDown(val)
        notify("FACE DOWN", val and "Character facing DOWN towards ground!" or "Character orientation RESET.", "rbxassetid://10709791437", 2)
    end
})

PlayerTab:Toggle({
    Title = "Head Look Down (ก้มหัวมองดิน)",
    Desc = "Tilts character head & neck joints 90° down towards ground",
    Value = State.HeadDown,
    Callback = function(val)
        toggleHeadDown(val)
        notify("HEAD DOWN", val and "Head tilted down towards ground!" or "Head orientation RESET.", "rbxassetid://10709791437", 2)
    end
})

PlayerTab:Button({
    Title = "Snap Look Down (หันลงดินทันที)",
    Desc = "Immediately snaps character and camera orientation straight down",
    Callback = function()
        local hrp = currentHRP or getHRP()
        if hrp and hrp.Parent then
            local _, yaw, _ = hrp.CFrame:ToEulerAnglesYXZ()
            hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
        end
        local cam = workspace.CurrentCamera
        if cam then
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position - Vector3.new(0, 10, 0), -cam.CFrame.LookVector)
        end
        notify("LOOK DOWN", "Snapped character to face ground!", "rbxassetid://10709791437", 2)
    end
})

PlayerTab:Section({ Title = "Speed & Jump Modifications" })

PlayerTab:Slider({
    Title = "Walk Speed",
    Desc = "Adjust character walking speed (default: 16 | Max: 500)",
    Min = 16,
    Max = 500,
    Value = 16,
    Callback = function(val)
        State.WalkSpeed = val
        local hum = currentHumanoid or getHumanoid()
        if hum then hum.WalkSpeed = val end
    end
})

PlayerTab:Button({
    Title = "Egg Safe Runner Speed (35 studs/s)",
    Desc = "Safe running speed that prevents server speed-check from resetting the egg",
    Callback = function()
        State.WalkSpeed = 35
        local hum = currentHumanoid or getHumanoid()
        if hum then hum.WalkSpeed = 35 end
        notify("SPEED PRESET", "WalkSpeed set to 35 (Safe for Egg Delivery)! Run to base on ground.", "rbxassetid://10709791437", 3)
    end
})

PlayerTab:Button({
    Title = "Egg Fast Runner Speed (60 studs/s)",
    Desc = "Faster ground speed for returning",
    Callback = function()
        State.WalkSpeed = 60
        local hum = currentHumanoid or getHumanoid()
        if hum then hum.WalkSpeed = 60 end
        notify("SPEED PRESET", "WalkSpeed set to 60! Run to base on ground.", "rbxassetid://10709791437", 3)
    end
})

PlayerTab:Button({
    Title = "Reset Normal Speed (16 studs/s)",
    Desc = "Resets walking speed back to Roblox default (16)",
    Callback = function()
        State.WalkSpeed = 16
        local hum = currentHumanoid or getHumanoid()
        if hum then hum.WalkSpeed = 16 end
        notify("SPEED PRESET", "WalkSpeed reset to 16 (Normal).", "rbxassetid://10709791437", 2)
    end
})

PlayerTab:Slider({
    Title = "Jump Power",
    Desc = "Adjust character jumping power (default: 50 | Max: 600)",
    Min = 50,
    Max = 600,
    Value = 50,
    Callback = function(val)
        State.JumpPower = val
        local hum = currentHumanoid or getHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = val
        end
    end
})

-- Maintain WalkSpeed/JumpPower after respawn
RunService.Heartbeat:Connect(function()
    if State.WalkSpeed ~= 16 or State.JumpPower ~= 50 then
        local hum = currentHumanoid or getHumanoid()
        if hum then
            if State.WalkSpeed ~= 16 and hum.WalkSpeed ~= State.WalkSpeed then
                hum.WalkSpeed = State.WalkSpeed
            end
            if State.JumpPower ~= 50 and hum.JumpPower ~= State.JumpPower then
                hum.UseJumpPower = true
                hum.JumpPower = State.JumpPower
            end
        end
    end
end)

-- TAB 4: MISC & SETTINGS
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "rbxassetid://10709791130" })

SettingsTab:Section({ Title = "Theme & Configuration" })

SettingsTab:Dropdown({
    Title = "Change UI Theme",
    Desc = "Select visual style",
    List = { "Dark", "Amethyst", "Liquid Glass", "Rose", "Ocean", "Neon", "Gold", "Light" },
    Value = "Dark",
    Callback = function(tName)
        Library:SetTheme(tName)
    end
})

local function getWindowUIScale()
    if Window and Window.WindowScale and Window.WindowScale:IsA("UIScale") then
        return Window.WindowScale
    end
    local guiParent = (gethui and gethui()) or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")) or game:GetService("CoreGui")
    if guiParent then
        for _, gui in ipairs(guiParent:GetChildren()) do
            if gui:IsA("ScreenGui") then
                local shadow = gui:FindFirstChild("Shadow")
                if shadow then
                    local ws = shadow:FindFirstChild("WindowScale")
                    if ws and ws:IsA("UIScale") then
                        return ws
                    end
                end
            end
        end
    end
    return nil
end

local defaultScaleVal = 100
pcall(function()
    local ws = getWindowUIScale()
    if ws and ws.Scale then
        defaultScaleVal = math.clamp(math.round(ws.Scale * 100), 70, 150)
    end
end)

SettingsTab:Slider({
    Title = "UI Scale (ขนาดหน้าต่าง UI)",
    Desc = "Adjust the size/zoom of the main UI window (70% - 150%)",
    Min = 70,
    Max = 150,
    Value = defaultScaleVal,
    Callback = function(val)
        local ws = getWindowUIScale()
        if ws then
            TweenService:Create(ws, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Scale = val / 100
            }):Play()
        end
    end
})

SettingsTab:Keybind({
    Title = "Toggle UI Keybind",
    Desc = "Key to show/hide the interface",
    Value = Enum.KeyCode.RightControl,
    Callback = function(key)
        -- Keybind updated
    end
})

SettingsTab:Button({
    Title = "Unload & Destroy UI",
    Desc = "Cleanly removes the script interface",
    Callback = function()
        cancelTween()
        toggleGodMode(false)
        toggleNoclip(false)
        toggleInstantPrompt(false)
        toggleFaceDown(false)
        toggleHeadDown(false)
        if EggRadarGui and EggRadarGui.Parent then
            EggRadarGui:Destroy()
        end
        Window:Destroy()
    end
})

notify("HYPER HUB LOADED", "Steal an Egg Roblox loaded! Auto God Mode is ACTIVE.", "rbxassetid://10709791437", 4)