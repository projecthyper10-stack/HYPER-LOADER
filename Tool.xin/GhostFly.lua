local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

getgenv().GhostFlyEnabled = false
getgenv().GhostFlySpeed = 50

local flyVelocity = nil
local flyGyro = nil
local renderSteppedConn = nil
local steppedConn = nil

local keysDown = {
    W = false,
    A = false,
    S = false,
    D = false,
    Space = false,
    LeftShift = false
}

local function startGhostFly()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        humanoid.PlatformStand = true
    end
    
    -- ลบอันเก่าถ้ามีค้าง
    local oldBV = hrp:FindFirstChild("GhostFlyVelocity")
    if oldBV then oldBV:Destroy() end
    local oldBG = hrp:FindFirstChild("GhostFlyGyro")
    if oldBG then oldBG:Destroy() end

    flyVelocity = Instance.new("BodyVelocity")
    flyVelocity.Name = "GhostFlyVelocity"
    flyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyVelocity.Velocity = Vector3.new(0, 0, 0)
    flyVelocity.Parent = hrp
    
    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "GhostFlyGyro"
    flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyGyro.P = 3000
    flyGyro.D = 500
    flyGyro.CFrame = camera.CFrame
    flyGyro.Parent = hrp
    
    renderSteppedConn = RunService.RenderStepped:Connect(function()
        if not getgenv().GhostFlyEnabled then return end
        
        local moveDir = Vector3.new(0, 0, 0)
        
        if keysDown.W then moveDir = moveDir + camera.CFrame.LookVector end
        if keysDown.S then moveDir = moveDir - camera.CFrame.LookVector end
        if keysDown.A then moveDir = moveDir - camera.CFrame.RightVector end
        if keysDown.D then moveDir = moveDir + camera.CFrame.RightVector end
        
        local upDown = 0
        if keysDown.Space then upDown = upDown + 1 end
        if keysDown.LeftShift then upDown = upDown - 1 end
        
        moveDir = moveDir + Vector3.new(0, upDown, 0)
        
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end
        
        if flyVelocity then
            flyVelocity.Velocity = moveDir * getgenv().GhostFlySpeed
        end
        if flyGyro then
            flyGyro.CFrame = camera.CFrame
        end
    end)
    
    steppedConn = RunService.Stepped:Connect(function()
        if not getgenv().GhostFlyEnabled then return end
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopGhostFly()
    if renderSteppedConn then 
        renderSteppedConn:Disconnect() 
        renderSteppedConn = nil
    end
    if steppedConn then 
        steppedConn:Disconnect() 
        steppedConn = nil
    end
    
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.PlatformStand = false
        end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("GhostFlyVelocity")
            if bv then bv:Destroy() end
            local bg = hrp:FindFirstChild("GhostFlyGyro")
            if bg then bg:Destroy() end
            
            -- Reset velocity
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end
end

-- Key Input Handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then keysDown.W = true end
    if input.KeyCode == Enum.KeyCode.A then keysDown.A = true end
    if input.KeyCode == Enum.KeyCode.S then keysDown.S = true end
    if input.KeyCode == Enum.KeyCode.D then keysDown.D = true end
    if input.KeyCode == Enum.KeyCode.Space then keysDown.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then keysDown.LeftShift = true end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.W then keysDown.W = false end
    if input.KeyCode == Enum.KeyCode.A then keysDown.A = false end
    if input.KeyCode == Enum.KeyCode.S then keysDown.S = false end
    if input.KeyCode == Enum.KeyCode.D then keysDown.D = false end
    if input.KeyCode == Enum.KeyCode.Space then keysDown.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then keysDown.LeftShift = false end
end)

local function toggleGhostFly(state)
    getgenv().GhostFlyEnabled = state
    if state then
        stopGhostFly()
        startGhostFly()
    else
        stopGhostFly()
    end
end

-- Toggle via Key 'X' (Optional)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.X then
        toggleGhostFly(not getgenv().GhostFlyEnabled)
    end
end)

return {
    Toggle = toggleGhostFly,
    SetSpeed = function(speed)
        getgenv().GhostFlySpeed = speed
    end
}
