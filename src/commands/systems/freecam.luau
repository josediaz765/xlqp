local robloxServices = require('../../framework/services/rbxServices')
local createService = require('../../framework/services/createService')
local keyboardService = require('../../framework/services/keyboardService')
local playerService = require('../../framework/services/playerService')
local localPlayer = require('../../framework/services/localPlayer')
local isMobile = require('../../framework/environment/isMobile')
local coreGui = require('../../ui/coreGui')
local ContextActionService = robloxServices.ContextActionService
local UserInputService = robloxServices.UserInputService
local freecam = {}

freecam.DEFAULT_SPEED = 1
freecam.DEFAULT_BOOST = 2
freecam.MIN_BOOST = 1
freecam.MAX_BOOST = 50

local BOOST_SETTING = 'freecam.boost'
local GARBAGE_NAME = 'freecam'
local KEYS_ACTION = 'freecamKeys'
local MOUSE_ACTION = 'freecamMouse'
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value
local GUI_NAME = 'freecamControls'
local MOVE_KEYS = {
    Enum.KeyCode.W,
    Enum.KeyCode.A,
    Enum.KeyCode.S,
    Enum.KeyCode.D,
    Enum.KeyCode.E,
    Enum.KeyCode.Q,
    Enum.KeyCode.Up,
    Enum.KeyCode.Down,
}
local REFERENCE_FOV = 70
local STUDS_PER_SECOND = 64
local SPRING_FREQUENCY = 5
local PAN_PER_PIXEL = math.pi / 64
local MAX_PITCH = math.rad(89)
local SPEED_CHANGE_PER_SECOND = 0.75
local MIN_MULTIPLIER = 0.01
local MAX_MULTIPLIER = 4
local SHIFT_MULTIPLIER = 0.25
local NEAR_PLANE = 0.1
local MAX_FOCUS_DISTANCE = 512
local TOUCH_LOOK_SCALE = 1
local BUTTON_SIZE = 64
local EDGE_OFFSET = 24
local BOTTOM_OFFSET = 40

local function sinkInput()
    return Enum.ContextActionResult.Sink
end
local function newSpring(initial)
    return {
        position = initial,
        velocity = initial * 0,
    }
end
local function updateSpring(spring, dt, goal)
    local frequency = SPRING_FREQUENCY * 2 * math.pi
    local offset = goal - spring.position
    local decay = math.exp(-frequency * dt)
    local position = goal + (spring.velocity * dt - offset * (frequency * dt + 1)) * decay
    local velocity = (frequency * dt * (offset * frequency - spring.velocity) + spring.velocity) * decay

    spring.position = position
    spring.velocity = velocity

    return position
end
local function readAxis(positiveKey, negativeKey)
    local positive = UserInputService:IsKeyDown(positiveKey) and 1 or 0
    local negative = UserInputService:IsKeyDown(negativeKey) and 1 or 0

    return positive - negative
end
local function getFocusDistance(camera, cframe, fieldOfView)
    local viewport = camera.ViewportSize
    local projY = 2 * math.tan(math.rad(fieldOfView) / 2)
    local projX = viewport.X / viewport.Y * projY
    local minDistance = MAX_FOCUS_DISTANCE
    local minDirection = cframe.LookVector

    for x = 0, 1, 0.5 do
        for y = 0, 1, 0.5 do
            local offset = cframe.RightVector * ((x - 0.5) * projX) - cframe.UpVector * ((y - 0.5) * projY) + cframe.LookVector
            local direction = offset.Unit
            local origin = cframe.Position + offset * NEAR_PLANE
            local result = workspace:Raycast(origin, direction * MAX_FOCUS_DISTANCE)
            local distance = result and (result.Position - origin).Magnitude or MAX_FOCUS_DISTANCE

            if distance < minDistance then
                minDistance = distance
                minDirection = direction
            end
        end
    end

    return cframe.LookVector:Dot(minDirection) * minDistance
end
local function readThumbstick(humanoid, yaw)
    if not humanoid then
        return Vector3.zero
    end

    local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
    local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
    local move = humanoid.MoveDirection

    return Vector3.new(move:Dot(right), 0, -move:Dot(forward))
end
local function isTouch(input)
    return input.UserInputType == Enum.UserInputType.Touch
end
local function isOverControls(garbage, position)
    for _, control in garbage.controls do
        local corner = control.AbsolutePosition
        local size = control.AbsoluteSize

        if position.X >= corner.X and position.X <= corner.X + size.X and position.Y >= corner.Y and position.Y <= corner.Y + size.Y then
            return true
        end
    end

    return false
end
local function createControls(self, garbage)
    local gui = createService.new('ScreenGui', coreGui, {
        Name = GUI_NAME,
        ResetOnSpawn = false,
        DisplayOrder = 50,
    })

    garbage.gui = gui

    local function holdButton(name, text, position)
        local button = createService.new('TextButton', gui, {
            Name = name,
            AnchorPoint = Vector2.new(1, 1),
            Position = position,
            Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            AutoButtonColor = false,
            Text = text,
            TextColor3 = Color3.new(1, 1, 1),
            TextScaled = true,
            Active = true,
        })

        table.insert(garbage.controls, button)
        table.insert(garbage.connections, self:connect(button.InputBegan, function(
            input
        )
            if isTouch(input) then
                garbage.holds[name] = input
            end
        end))
    end

    holdButton('rise', 'UP', UDim2.new(1, -EDGE_OFFSET, 1, -BOTTOM_OFFSET - BUTTON_SIZE - 12))
    holdButton('fall', 'DOWN', UDim2.new(1, -EDGE_OFFSET, 1, -BOTTOM_OFFSET))
    holdButton('boost', 'BOOST', UDim2.new(1, -EDGE_OFFSET - BUTTON_SIZE - 12, 1, 
-BOTTOM_OFFSET))

    local close = createService.new('TextButton', gui, {
        Name = 'Close',
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -EDGE_OFFSET, 0, EDGE_OFFSET),
        Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        AutoButtonColor = false,
        Text = 'X',
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,
        Active = true,
    })

    table.insert(garbage.controls, close)
    table.insert(garbage.connections, self:connect(close.Activated, function()
        freecam.stop(self)
    end))

    local teleport = createService.new('TextButton', gui, {
        Name = 'Teleport',
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -EDGE_OFFSET - BUTTON_SIZE - 12, 0, EDGE_OFFSET),
        Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        AutoButtonColor = false,
        Text = 'TP',
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,
        Active = true,
    })

    table.insert(garbage.controls, teleport)
    table.insert(garbage.connections, self:connect(teleport.Activated, function()
        freecam.teleport(self)
    end))
    table.insert(garbage.connections, self:connect(UserInputService.InputEnded, function(
        input
    )
        for name, touch in garbage.holds do
            if input == touch then
                garbage.holds[name] = nil
            end
        end
    end))
end
local function hideJumpButton(self, garbage)
    local playerGui = robloxServices.Players.LocalPlayer:FindFirstChildOfClass('PlayerGui')
    local touchGui = playerGui and playerGui:FindFirstChild('TouchGui')
    local jumpButton = touchGui and touchGui:FindFirstChild('JumpButton', true)

    if not jumpButton then
        return
    end

    garbage.jumpButton = jumpButton
    garbage.jumpVisible = jumpButton.Visible
    jumpButton.Visible = false

    table.insert(garbage.connections, self:connect(jumpButton:GetPropertyChangedSignal('Visible'), function(
    )
        if jumpButton.Visible then
            jumpButton.Visible = false
        end
    end))
end
local function freezeCharacter(self, garbage)
    local root = self.playerService:getRootPart()

    if not root then
        return
    end

    garbage.root = root
    garbage.rootAnchored = root.Anchored
    root.Anchored = true
end
local function releaseCharacter(garbage)
    local root = garbage.root

    if root and root.Parent ~= nil then
        root.Anchored = garbage.rootAnchored
    end
end
local function stepFreecam(self, garbage, dt)
    local camera = workspace.CurrentCamera

    garbage.navMultiplier = math.clamp(garbage.navMultiplier + dt * readAxis(Enum.KeyCode.Up, Enum.KeyCode.Down) * SPEED_CHANGE_PER_SECOND, MIN_MULTIPLIER, MAX_MULTIPLIER)

    local humanoid = self.playerService:getHumanoid()
    local thumbstick = if isMobile then readThumbstick(humanoid, garbage.rotation.Y)else Vector3.zero

    if isMobile and humanoid then
        humanoid.Jump = false
    end

    local rise = garbage.holds.rise and 1 or 0
    local fall = garbage.holds.fall and 1 or 0
    local keys = Vector3.new(readAxis(Enum.KeyCode.D, Enum.KeyCode.A) + thumbstick.X, readAxis(Enum.KeyCode.E, Enum.KeyCode.Q) + rise - fall, readAxis(Enum.KeyCode.S, Enum.KeyCode.W) + thumbstick.Z)
    local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and SHIFT_MULTIPLIER or 1
    local boostHeld = garbage.holds.boost or UserInputService:IsKeyDown(keyboardService:getBinding('freecamBoost'))
    local boost = if boostHeld then freecam.getBoost(self)else 1
    local speed = (self.privateEnv.freecamSpeed or freecam.DEFAULT_SPEED) * garbage.navMultiplier * shift * boost
    local velocity = updateSpring(garbage.velocitySpring, dt, keys * speed)
    local pan = updateSpring(garbage.panSpring, dt, garbage.mouseDelta * PAN_PER_PIXEL)

    garbage.mouseDelta = Vector2.zero

    local zoomFactor = math.sqrt(math.tan(math.rad(REFERENCE_FOV / 2)) / math.tan(math.rad(garbage.fieldOfView / 2)))
    local rotation = garbage.rotation + pan * Vector2.new(0.75, 1) * 8 * (dt / zoomFactor)

    garbage.rotation = Vector2.new(math.clamp(rotation.X, -MAX_PITCH, MAX_PITCH), rotation.Y % (2 * math.pi))

    local orientation = CFrame.fromOrientation(garbage.rotation.X, garbage.rotation.Y, 0)
    local cframe = CFrame.new(garbage.position) * orientation * CFrame.new(velocity * STUDS_PER_SECOND * dt)

    garbage.position = cframe.Position
    camera.CFrame = cframe

    if garbage.anchor then
        garbage.anchor.CFrame = cframe
    end

    camera.Focus = cframe * CFrame.new(0, 0, -getFocusDistance(camera, cframe, garbage.fieldOfView))
    camera.FieldOfView = garbage.fieldOfView
end
local function createAnchor(garbage)
    return createService.new('Part', workspace, {
        Name = 'freecamAnchor',
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Transparency = 1,
        Size = Vector3.one * 0.2,
        CFrame = CFrame.new(garbage.position),
    })
end
local function waitNextCharacter(camera)
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild('Humanoid', 100)

    if camera and (camera.CameraSubject == nil or not camera.CameraSubject:IsDescendantOf(workspace)) and playerService:isAlive(character) then
        camera.CameraSubject = humanoid
    end
end

function freecam.stop(self)
    local garbage = self:collectGarbage(GARBAGE_NAME)

    if not garbage then
        return false
    end

    for _, connection in garbage.connections do
        connection:Disconnect()
    end

    ContextActionService:UnbindAction(KEYS_ACTION)
    ContextActionService:UnbindAction(MOUSE_ACTION)

    if garbage.gui then
        garbage.gui:Destroy()
    end
    if garbage.jumpButton then
        garbage.jumpButton.Visible = garbage.jumpVisible
    end

    releaseCharacter(garbage)

    local cameraSubject = garbage.cameraSubject
    local camera = workspace.CurrentCamera

    camera.CameraSubject = cameraSubject

    if garbage.isLPHumanoid or (cameraSubject and not cameraSubject:IsDescendantOf(workspace)) then
        task.spawn(waitNextCharacter, camera)
    end

    camera.CameraType = garbage.cameraType

    if garbage.anchor then
        garbage.anchor:Destroy()
    end

    camera.Focus = garbage.focus
    camera.FieldOfView = garbage.fieldOfView
    UserInputService.MouseBehavior = garbage.mouseBehavior
    UserInputService.MouseIconEnabled = garbage.mouseIconEnabled

    return true
end
function freecam.teleport(self)
    local garbage = self:getGarbage(GARBAGE_NAME)

    if not garbage then
        return false
    end

    local cframe = CFrame.new(garbage.position) * CFrame.Angles(0, garbage.rotation.Y, 0)

    freecam.stop(self)

    if not self.playerService:teleportTo(cframe) then
        self:notify('Freecam', 'your character was not found')
    end

    return true
end

local function guarded(self, what, fn, ...)
    local ok, err = pcall(fn, ...)

    if not ok then
        self:notify('Freecam', `{what} failed: {err}`)
    end
end
local function startFreecam(self, position)
    freecam.stop(self)

    local camera = workspace.CurrentCamera
    local startCFrame = camera.CFrame
    local pitch, yaw = startCFrame:ToOrientation()
    local garbage = self:createGarbage(GARBAGE_NAME)

    garbage.connections = {}
    garbage.controls = {}
    garbage.holds = {}
    garbage.cameraType = camera.CameraType
    garbage.cameraSubject = camera.CameraSubject

    local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass('Humanoid')

    garbage.isLPHumanoid = (garbage.cameraSubject ~= nil and humanoid == garbage.cameraSubject) or garbage.cameraSubject == nil
    garbage.focus = camera.Focus
    garbage.fieldOfView = camera.FieldOfView
    garbage.mouseBehavior = UserInputService.MouseBehavior
    garbage.mouseIconEnabled = UserInputService.MouseIconEnabled
    garbage.position = position or startCFrame.Position
    garbage.rotation = Vector2.new(pitch, yaw)
    garbage.mouseDelta = Vector2.zero
    garbage.navMultiplier = 1
    garbage.velocitySpring = newSpring(Vector3.zero)
    garbage.panSpring = newSpring(Vector2.zero)
    garbage.anchor = createAnchor(garbage)
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = garbage.anchor
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    UserInputService.MouseIconEnabled = true

    ContextActionService:BindActionAtPriority(KEYS_ACTION, sinkInput, false, ACTION_PRIORITY, table.unpack(MOVE_KEYS))
    ContextActionService:BindActionAtPriority(MOUSE_ACTION, function(
        _,
        _,
        input
    )
        local delta = input.Delta

        garbage.mouseDelta += Vector2.new(-delta.Y, -delta.X)

        return Enum.ContextActionResult.Sink
    end, false, ACTION_PRIORITY, Enum.UserInputType.MouseMovement)

    if isMobile then
        freezeCharacter(self, garbage)
        guarded(self, 'buttons', createControls, self, garbage)
        guarded(self, 'jump button', hideJumpButton, self, garbage)
        table.insert(garbage.connections, self:connect(UserInputService.InputBegan, function(
            input,
            gameProcessed
        )
            if gameProcessed or not isTouch(input) then
                return
            end
            if garbage.lookTouch ~= nil or isOverControls(garbage, input.Position) then
                return
            end
            if input.Position.X < workspace.CurrentCamera.ViewportSize.X / 2 then
                return
            end

            garbage.lookTouch = input
        end))
        table.insert(garbage.connections, self:connect(UserInputService.InputChanged, function(
            input
        )
            if input == garbage.lookTouch then
                garbage.mouseDelta += Vector2.new(-input.Delta.Y, -input.Delta.X) * TOUCH_LOOK_SCALE
            end
        end))
        table.insert(garbage.connections, self:connect(UserInputService.InputEnded, function(
            input
        )
            if input == garbage.lookTouch then
                garbage.lookTouch = nil
            end
        end))
    end

    table.insert(garbage.connections, self:connect(self.runService.RenderStepped, function(
        dt
    )
        local ok, err = pcall(stepFreecam, self, garbage, dt)

        if not ok then
            freecam.stop(self)
            self:notify('Freecam', `stopped, the camera was given back: {err}`)
        end
    end))
end

function freecam.start(self, position)
    local ok, err = pcall(startFreecam, self, position)

    if not ok then
        freecam.stop(self)
        self:notify('Freecam', `could not start: {err}`)
    end
end
function freecam.getBoost(self)
    local value = self.storage.settings:getValue(BOOST_SETTING)

    if type(value) ~= 'number' then
        return freecam.DEFAULT_BOOST
    end

    return math.clamp(value, freecam.MIN_BOOST, freecam.MAX_BOOST)
end
function freecam.addBoost(self, amount)
    local value = math.clamp(freecam.getBoost(self) + amount, freecam.MIN_BOOST, freecam.MAX_BOOST)

    self.storage.settings:setValue(BOOST_SETTING, value)
    self.storage.settings:save()

    return value
end
function freecam.getPosition(self)
    local garbage = self:getGarbage(GARBAGE_NAME)

    return garbage and garbage.position
end

return freecam
