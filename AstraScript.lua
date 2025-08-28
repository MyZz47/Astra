-- ESP + Lock classique + TeamCheck + Barre de vie + Notifications stylées + Bras tournants
-- LocalScript

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- Variables
local lockedTarget = nil
local lockActive = false
local teamCheck = true
local MAX_LOCK_DISTANCE = 500

-- Notification stylée
local function notify(text, color)
    local gui = Instance.new("ScreenGui")
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 40)
    frame.Position = UDim2.new(1, -240, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -10, 1, -10)
    label.Position = UDim2.new(0,5,0,5)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.Font = Enum.Font.GothamSemibold
    label.TextScaled = true
    label.Text = text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    task.spawn(function()
        task.wait(1.2)
        for i = 1, 30 do
            task.wait(0.03)
            frame.BackgroundTransparency = frame.BackgroundTransparency + 0.02
            label.TextTransparency = label.TextTransparency + 0.02
        end
        gui:Destroy()
    end)
end

-- Fonctions
local function isVisible(player)
    if not player.Character or not player.Character:FindFirstChild("Head") then return false end
    local origin = Camera.CFrame.Position
    local target = player.Character.Head.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
    local result = workspace:Raycast(origin, (target - origin), raycastParams)
    return not result
end

local function areAllies(player1, player2)
    if not player1.Team or not player2.Team then return false end
    return player1.Team == player2.Team
end

-- ESP + barre de vie
local function addHighlight(character)
    if character:FindFirstChild("Highlight") then return end

    local esp = Instance.new("Highlight")
    esp.Name = "Highlight"
    esp.FillTransparency = 0.5
    esp.OutlineTransparency = 0
    esp.FillColor = Color3.fromRGB(0, 255, 0)
    esp.OutlineColor = Color3.fromRGB(255, 255, 255)
    esp.Adornee = character
    esp.Parent = character

    if not character:FindFirstChild("HealthBar") then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "HealthBar"
        billboard.Size = UDim2.new(0, 50, 0, 6)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = character

        local barBackground = Instance.new("Frame")
        barBackground.Size = UDim2.new(1,0,1,0)
        barBackground.BackgroundColor3 = Color3.fromRGB(50,50,50)
        barBackground.BorderSizePixel = 0
        barBackground.Parent = billboard

        local barFill = Instance.new("Frame")
        barFill.Name = "Fill"
        barFill.Size = UDim2.new(1,0,1,0)
        barFill.BackgroundColor3 = Color3.fromRGB(0,255,0)
        barFill.BorderSizePixel = 0
        barFill.Parent = barBackground
    end
end

local function updateESP(player, character)
    local highlight = character:FindFirstChild("Highlight")
    local humanoid = character:FindFirstChild("Humanoid")
    if not highlight or not humanoid then return end

    local dist = (character.PrimaryPart.Position - Camera.CFrame.Position).Magnitude
    local visible = isVisible(player)

    -- TeamCheck : enlever ESP alliés
    if teamCheck and areAllies(LocalPlayer, player) then
        highlight.Enabled = false
        local healthBar = character:FindFirstChild("HealthBar")
        if healthBar then healthBar.Enabled = false end
        return
    else
        highlight.Enabled = true
    end

    -- Highlight couleur selon visibilité
    highlight.FillTransparency = 0.5
    highlight.FillColor = visible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)

    -- Barre de vie
    local healthBar = character:FindFirstChild("HealthBar")
    if healthBar and humanoid.Health > 0 and dist <= MAX_LOCK_DISTANCE then
        healthBar.Enabled = true
        local fill = healthBar:FindFirstChild("Fill")
        if fill then
            local healthScale = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            fill.Size = UDim2.new(healthScale, 0, 1, 0)
            if humanoid.Health <= 50 then
                fill.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            else
                fill.BackgroundColor3 = visible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(150, 0, 0)
            end
        end
    else
        if healthBar then healthBar.Enabled = false end
    end
end

local function applyESP(player, character)
    if player == LocalPlayer then return end
    addHighlight(character)
    RunService.RenderStepped:Connect(function()
        if character and character.Parent then
            updateESP(player, character)
        end
    end)
end

-- Ciblage lock
local function getClosestTargetInFOV()
    local nearest = nil
    local shortestDistance = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, player in ipairs(Players:GetPlayers()) do
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and humanoid and humanoid.Health > 0 then
            if (not teamCheck or not areAllies(LocalPlayer, player)) and isVisible(player) then
                local dist = (player.Character.Head.Position - Camera.CFrame.Position).Magnitude
                if dist <= MAX_LOCK_DISTANCE then
                    local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    if onScreen then
                        local distance = (Vector2.new(pos.X,pos.Y) - screenCenter).Magnitude
                        if distance < shortestDistance then
                            shortestDistance = distance
                            nearest = player
                        end
                    end
                end
            end
        end
    end
    return nearest
end

local function getClosestVisibleTarget()
    local nearest = nil
    local shortestDistance = math.huge
    local camPos = Camera.CFrame.Position
    for _, player in ipairs(Players:GetPlayers()) do
        local humanoid = player.Character and player.Character:FindFirstChild("Humanoid")
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") and humanoid and humanoid.Health > 0 then
            if (not teamCheck or not areAllies(LocalPlayer, player)) and isVisible(player) then
                local dist = (player.Character.Head.Position - camPos).Magnitude
                if dist <= MAX_LOCK_DISTANCE and dist < shortestDistance then
                    shortestDistance = dist
                    nearest = player
                end
            end
        end
    end
    return nearest
end

-- Input
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.U then
        lockActive = not lockActive
        if lockActive then
            notify("Lock Activé", Color3.fromRGB(0,150,0))
        else
            lockedTarget = nil
            notify("Lock Désactivé", Color3.fromRGB(200,0,0))
        end
    elseif input.KeyCode == Enum.KeyCode.P then
        teamCheck = not teamCheck
        if teamCheck then
            notify("TeamCheck Activé", Color3.fromRGB(0,150,0))
        else
            notify("TeamCheck Désactivé", Color3.fromRGB(200,0,0))
        end
    end
end)

-- Mise à jour lock (caméra + bras seulement, ignore morts)
RunService.RenderStepped:Connect(function()
    if lockActive then
        if not lockedTarget 
            or not lockedTarget.Character 
            or not lockedTarget.Character:FindFirstChild("Head") 
            or not lockedTarget.Character:FindFirstChild("Humanoid") 
            or lockedTarget.Character.Humanoid.Health <= 0
            or not isVisible(lockedTarget)
        then
            lockedTarget = getClosestTargetInFOV()
        end

        if lockedTarget and lockedTarget.Character and lockedTarget.Character:FindFirstChild("Humanoid") and lockedTarget.Character.Humanoid.Health <= 0 then
            lockedTarget = getClosestVisibleTarget()
        end

        if lockedTarget and lockedTarget.Character and lockedTarget.Character:FindFirstChild("Head") then
            local headPos = lockedTarget.Character.Head.Position
            local camPos = Camera.CFrame.Position
            Camera.CFrame = CFrame.new(camPos, headPos)

            local character = LocalPlayer.Character
            if character then
                -- Bras droit
                local rightArm = character:FindFirstChild("RightUpperArm") or character:FindFirstChild("RightArm")
                if rightArm then
                    local shoulder = rightArm:FindFirstChildWhichIsA("Motor6D")
                    if shoulder then
                        shoulder.C0 = CFrame.new(shoulder.C0.Position, headPos - rightArm.Position)
                    end
                end
                -- Bras gauche
                local leftArm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("LeftArm")
                if leftArm then
                    local shoulder = leftArm:FindFirstChildWhichIsA("Motor6D")
                    if shoulder then
                        shoulder.C0 = CFrame.new(shoulder.C0.Position, headPos - leftArm.Position)
                    end
                end
            end
        end
    end
end)

-- Connexion ESP
local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(1)
        applyESP(player, char)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then applyESP(player, player.Character) end
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)
