local inputUtils = require('../utils/inputUtils')
local rbxServices = require('../../framework/services/rbxServices')
local signal = require('../../utils/signal')
local userInputService = rbxServices.UserInputService
local LERP_VALUE = 0.28
local BUTTON_DEBOUNCE = 0.2
local CLICK_TRAVEL = 10
local dragService = {}

dragService.__index = dragService

local function isMouse(input)
    return input.UserInputType ~= Enum.UserInputType.Touch
end
local function isPressMove(press, input)
    if input == press.input then
        return true
    end

    return press.isMouse and input.UserInputType == Enum.UserInputType.MouseMovement
end
local function isPressEnd(press, input)
    if input == press.input then
        return true
    end

    return press.isMouse and input.UserInputType == press.input.UserInputType
end

function dragService:_resetDrag()
    for _, connection in self._pressConnections do
        connection:Disconnect()
    end

    table.clear(self._pressConnections)

    self._press = nil
    self.isDragging = false
    self.draggingObject = nil
    self.dragStart = nil
    self.startPos = nil
    self.lastPos = nil
    self.pressTime = 0
    self.travel = 0
end
function dragService:_endPress(press)
    if self._press ~= press then
        return
    end

    local wasDragging = self.isDragging
    local object = self.draggingObject
    local gesture = nil

    if wasDragging then
        gesture = {
            duration = os.clock() - self.pressTime,
            travel = self.travel,
            dy = self.lastPos.Y - self.dragStart.Y,
        }
    end

    self:_resetDrag()

    if wasDragging then
        self.dragEnded:Fire(object, gesture)
    end
end
function dragService:_beginDrag(press)
    if self.isDragging or self._press ~= press then
        return
    end

    self.isDragging = true
    self.draggingObject = press.object

    self.dragStarted:Fire(press.object)
end
function dragService:_onPressMoved(press, input)
    if self._press ~= press or not isPressMove(press, input) then
        return
    end
    if press.isButton and not self.isDragging then
        if (input.Position - self.dragStart).Magnitude <= CLICK_TRAVEL then
            return
        end

        self:_beginDrag(press)
    end
    if self.isDragging then
        self:update(press.object, input)
    end
end
function dragService:_startPress(object, input)
    local press = {
        object = object,
        input = input,
        isMouse = isMouse(input),
        isButton = object:IsA('GuiButton'),
    }

    self._press = press
    self.dragStart = input.Position
    self.lastPos = input.Position
    self.startPos = object.Position
    self.pressTime = os.clock()
    self.travel = 0
    self._pressConnections = {
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                self:_endPress(press)
            end
        end),
        userInputService.InputChanged:Connect(function(changed)
            self:_onPressMoved(press, changed)
        end),
        userInputService.InputEnded:Connect(function(ended)
            if isPressEnd(press, ended) then
                self:_endPress(press)
            end
        end),
    }

    if not press.isButton then
        self:_beginDrag(press)

        return
    end

    task.delay(BUTTON_DEBOUNCE, function()
        self:_beginDrag(press)
    end)
end
function dragService:addGuiObject(object, handle)
    return (handle or object).InputBegan:Connect(function(input)
        if not inputUtils.isPressingInput(input) then
            return
        end
        if self._press then
            return
        end

        self:_startPress(object, input)
    end)
end
function dragService:update(object, input)
    local delta = input.Position - self.dragStart
    local scaleSize = (self._uiScale and self._uiScale.Scale) or 1

    self.lastPos = input.Position
    self.travel = math.max(self.travel, delta.Magnitude)

    local newPosition = UDim2.new(self.startPos.X.Scale, self.startPos.X.Offset + (delta.X / scaleSize), self.startPos.Y.Scale, self.startPos.Y.Offset + (delta.Y / scaleSize))

    if self.filters[object] ~= nil then
        local customPos = self.filters[object](newPosition, scaleSize)

        newPosition = customPos or newPosition
    end

    object.Position = object.Position:Lerp(newPosition, LERP_VALUE)

    self.onDragged:Fire(object)
end
function dragService:canDragObject(object)
    return (not self.isDragging) or (self.draggingObject == object)
end
function dragService:setFilter(object, callback)
    self.filters[object] = callback
end
function dragService.new(uiScale)
    return setmetatable({
        isDragging = false,
        draggingObject = nil,
        _uiScale = uiScale,
        dragStart = nil,
        startPos = nil,
        lastPos = nil,
        pressTime = 0,
        travel = 0,
        _press = nil,
        _pressConnections = {},
        filters = {},
        onDragged = signal.new(),
        dragStarted = signal.new(),
        dragEnded = signal.new(),
    }, dragService)
end

return dragService
