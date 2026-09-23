local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ป้องกันการรันสคริปต์ซ้อนกัน (Anti-Overlap)
local env = (getgenv and getgenv()) or _G
if env.FlyScriptSystem then
    if env.FlyScriptSystem.InputConnection then env.FlyScriptSystem.InputConnection:Disconnect() end
    if env.FlyScriptSystem.RenderConnection then env.FlyScriptSystem.RenderConnection:Disconnect() end
    if env.FlyScriptSystem.GodModeConnection then env.FlyScriptSystem.GodModeConnection:Disconnect() end
    if env.FlyScriptSystem.NoclipConnection then env.FlyScriptSystem.NoclipConnection:Disconnect() end
    
    if env.FlyScriptSystem.BodyVelocity and env.FlyScriptSystem.BodyVelocity.Parent then env.FlyScriptSystem.BodyVelocity:Destroy() end
    if env.FlyScriptSystem.BodyGyro and env.FlyScriptSystem.BodyGyro.Parent then env.FlyScriptSystem.BodyGyro:Destroy() end
end

env.FlyScriptSystem = {
    Flying = false,
    GodMode = false,
    InputConnection = nil,
    RenderConnection = nil,
    GodModeConnection = nil,
    NoclipConnection = nil,
    BodyVelocity = nil,
    BodyGyro = nil
}
local fSystem = env.FlyScriptSystem

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local speed = 50

local function toggleGodMode()
    fSystem.GodMode = not fSystem.GodMode
    
    if fSystem.GodMode then
        -- เปิดอมตะ
        fSystem.GodModeConnection = RunService.RenderStepped:Connect(function()
            local character = player.Character
            if character then
                local humanoid = character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.MaxHealth = math.huge
                    humanoid.Health = math.huge
                end
            end
        end)
    else
        -- ปิดอมตะ
        if fSystem.GodModeConnection then
            fSystem.GodModeConnection:Disconnect()
            fSystem.GodModeConnection = nil
        end
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid and humanoid.MaxHealth > 1000 then
                humanoid.MaxHealth = 100
                humanoid.Health = 100
            end
        end
    end
end

local function toggleFly()
    fSystem.Flying = not fSystem.Flying
    
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = character.HumanoidRootPart
    local humanoid = character:FindFirstChild("Humanoid")
    
    if fSystem.Flying then
        if humanoid then
            humanoid.PlatformStand = true
        end
        
        fSystem.BodyVelocity = Instance.new("BodyVelocity")
        fSystem.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
        fSystem.BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        fSystem.BodyVelocity.Parent = rootPart
        
        fSystem.BodyGyro = Instance.new("BodyGyro")
        fSystem.BodyGyro.P = 9e4
        fSystem.BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        fSystem.BodyGyro.CFrame = rootPart.CFrame
        fSystem.BodyGyro.Parent = rootPart
        
        -- ทะลุกำแพง (Noclip)
        fSystem.NoclipConnection = RunService.Stepped:Connect(function()
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        
    else
        if humanoid then
            humanoid.PlatformStand = false
        end
        if fSystem.BodyVelocity then
            fSystem.BodyVelocity:Destroy()
            fSystem.BodyVelocity = nil
        end
        if fSystem.BodyGyro then
            fSystem.BodyGyro:Destroy()
            fSystem.BodyGyro = nil
        end
        
        -- ปิดการทะลุกำแพง
        if fSystem.NoclipConnection then
            fSystem.NoclipConnection:Disconnect()
            fSystem.NoclipConnection = nil
        end
    end
end

-- กดปุ่ม F เพื่อเปิด/ปิดการบิน, กดปุ่ม G เพื่อเปิด/ปิดอมตะ
fSystem.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.F then
        toggleFly()
    elseif input.KeyCode == Enum.KeyCode.G then
        toggleGodMode()
    end
end)

-- ควบคุมการบิน
fSystem.RenderConnection = RunService.RenderStepped:Connect(function()
    if fSystem.Flying then
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            fSystem.Flying = false
            return
        end
        
        local moveVector = Vector3.new(0, 0, 0)
        
        -- W A S D สำหรับการเคลื่อนที่
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveVector = moveVector + Vector3.new(0, 0, -1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveVector = moveVector + Vector3.new(0, 0, 1)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveVector = moveVector + Vector3.new(-1, 0, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveVector = moveVector + Vector3.new(1, 0, 0)
        end
        
        -- Space สำหรับบินขึ้น, Left Control สำหรับบินลง
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveVector = moveVector + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveVector = moveVector + Vector3.new(0, -1, 0)
        end
        
        if moveVector.Magnitude > 0 then
            moveVector = moveVector.Unit
        end
        
        local cameraCFrame = camera.CFrame
        local moveDirection = (cameraCFrame * CFrame.new(moveVector)).Position - cameraCFrame.Position
        
        if fSystem.BodyVelocity then
            fSystem.BodyVelocity.Velocity = moveDirection * speed
        end
        if fSystem.BodyGyro then
            fSystem.BodyGyro.CFrame = cameraCFrame
        end
    end
end)
