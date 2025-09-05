local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local player = Players.LocalPlayer
local spillSystem = workspace:WaitForChild('SpillSystem')
local heightOffset = Vector3.new(0, 4, 0)
local isRunning = true
local currentCharacter = player.Character

local TELEPORT_SPEED = 50
local PROMPT_WAIT = 0.3
local BETWEEN_SPILLS_WAIT = 0.1

local function onCharacterRespawned()
    isRunning = false
end

player.CharacterRemoving:Connect(onCharacterRespawned)
player.CharacterAdded:Connect(function(newCharacter)
    currentCharacter = newCharacter
    onCharacterRespawned()
end)

local function getCharacterAndHRP()
    local character = player.Character
    if character and character == currentCharacter then
        local hrp = character:FindFirstChild('HumanoidRootPart')
        if hrp then
            return character, hrp
        end
    end
    return nil, nil
end

local function getAllSpills()
    local spills = {}

    local function searchForSpills(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA('BasePart') then
                local name = child.Name:lower()
                if
                    name:find('spill')
                    or child:FindFirstChildWhichIsA('ProximityPrompt', true)
                then
                    local prompt =
                        child:FindFirstChildWhichIsA('ProximityPrompt', true)
                    if prompt then
                        table.insert(spills, {
                            part = child,
                            prompt = prompt,
                            name = child.Name,
                        })
                    end
                end
            end
            if child:IsA('Model') or child:IsA('Folder') then
                searchForSpills(child)
            end
        end
    end

    searchForSpills(spillSystem)

    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA('BasePart') then
            local name = child.Name:lower()
            if name:find('spill') then
                local prompt =
                    child:FindFirstChildWhichIsA('ProximityPrompt', true)
                if prompt then
                    table.insert(spills, {
                        part = child,
                        prompt = prompt,
                        name = child.Name,
                    })
                end
            end
        end
    end

    return spills
end

local function smoothTeleport(targetPosition, hrp)
    local currentPos = hrp.Position
    local distance = (targetPosition - currentPos).Magnitude

    if distance < 5 then
        hrp.CFrame = CFrame.new(targetPosition)
        return
    end

    local tweenInfo = TweenInfo.new(
        math.min(distance / TELEPORT_SPEED, 2),
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )

    local tween = TweenService:Create(hrp, tweenInfo, {
        CFrame = CFrame.new(targetPosition),
    })

    tween:Play()
    tween.Completed:Wait()
end

local function cleanSpill(spillData)
    local part = spillData.part
    local prompt = spillData.prompt

    if not part.Parent or not prompt.Parent then
        return false
    end

    local character, hrp = getCharacterAndHRP()
    if not character or not hrp then
        task.wait(2)
        return false
    end

    if not isRunning then
        return false
    end

    local targetPosition = part.Position + heightOffset
    local success = pcall(function()
        smoothTeleport(targetPosition, hrp)
    end)

    if not success then
        hrp.CFrame = CFrame.new(targetPosition)
    end

    task.wait(PROMPT_WAIT)

    for i = 1, 3 do
        if prompt.Parent and prompt.Enabled and isRunning then
            pcall(function()
                fireproximityprompt(prompt)
            end)
            task.wait(0.1)
        end
    end

    task.wait(1)

    if not prompt.Parent or not prompt.Enabled or not part.Parent then
        return true
    else
        return false
    end
end

local function mainLoop()
    while isRunning do
        local success = pcall(function()
            local spills = getAllSpills()

            if #spills == 0 then
                task.wait(3)
                return
            end

            for i, spillData in ipairs(spills) do
                if not isRunning then
                    break
                end

                cleanSpill(spillData)
                task.wait(BETWEEN_SPILLS_WAIT)
            end
        end)

        if not success then
            task.wait(2)
        end

        task.wait(0.5)
    end
end

_G.stopCleaner = function()
    isRunning = false
end
