local Players = game:GetService('Players')
local TweenService = game:GetService('TweenService')
local player = Players.LocalPlayer
local spillSystem = workspace:WaitForChild('SpillSystem')
local heightOffset = Vector3.new(0, 4, 0)
local isRunning = true

local TELEPORT_SPEED = 50
local PROMPT_WAIT = 0.3
local BETWEEN_SPILLS_WAIT = 0.1

local function getCharacterAndHRP()
    local character = player.Character
    if character then
        local hrp = character:FindFirstChild('HumanoidRootPart')
        if hrp then
            return character, hrp
        end
    end
    return nil, nil
end

local function getAllSpills()
    local spills = {}

    -- Get ALL children, not just direct children
    local function searchForSpills(parent)
        for _, child in pairs(parent:GetChildren()) do
            -- More flexible spill detection
            if child:IsA('BasePart') then
                local name = child.Name:lower()
                -- Check for spill in name OR if it has a ProximityPrompt
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
            -- Recursively search folders and models too
            if child:IsA('Model') or child:IsA('Folder') then
                searchForSpills(child)
            end
        end
    end

    searchForSpills(spillSystem)

    -- Also search workspace directly for any missed spills
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
        -- Just instant teleport for short distances
        hrp.CFrame = CFrame.new(targetPosition)
        return
    end

    -- Smooth teleport for longer distances
    local tweenInfo = TweenInfo.new(
        math.min(distance / TELEPORT_SPEED, 2), -- max 2 seconds
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
    local name = spillData.name

    if not part.Parent or not prompt.Parent then
        return false -- spill was destroyed
    end

    local character, hrp = getCharacterAndHRP()
    if not character or not hrp then
        task.wait(2)
        return false
    end

    -- Smooth teleport to spill
    local targetPosition = part.Position + heightOffset
    local success = pcall(function()
        smoothTeleport(targetPosition, hrp)
    end)

    if not success then
        -- Fallback to instant teleport
        hrp.CFrame = CFrame.new(targetPosition)
    end

    task.wait(PROMPT_WAIT)

    -- Trigger prompt multiple times to ensure it works
    for i = 1, 3 do
        if prompt.Parent and prompt.Enabled then
            pcall(function()
                fireproximityprompt(prompt)
            end)
            task.wait(0.1)
        end
    end

    task.wait(1) -- wait for cleaning animation

    -- Check if successfully cleaned
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

            local cleaned = 0
            local failed = 0

            for i, spillData in ipairs(spills) do
                if not isRunning then
                    break
                end

                if cleanSpill(spillData) then
                    cleaned = cleaned + 1
                else
                    failed = failed + 1
                end

                task.wait(BETWEEN_SPILLS_WAIT)
            end
        end)

        if not success then
            task.wait(2)
        end

        task.wait(0.5) -- brief pause before next scan
    end
end

-- Handle character respawn
player.CharacterAdded:Connect(function()
    task.wait(2)
end)

-- Start the cleaner
spawn(mainLoop)

-- Global stop function
_G.stopCleaner = function()
    isRunning = false
end
