local robloxServices = require('../../framework/services/rbxServices')
local connectionService = require('../../framework/services/connectionService')
local uiTweens = require('../../framework/services/tweenService')
local TweenService = robloxServices.TweenService
local UserInputService = robloxServices.UserInputService
local RunService = robloxServices.RunService
local MOVE_TIME = 0.32
local TAP_MAX_TIME = 0.1
local TAP_MAX_TRAVEL = 10
local DRAG_DOWN_MIN = 50
local CLICK_MAX_TIME = 0.3
local SWIPE_OUTSIDE_MIN = 20
local LOCK_IDLE_TIME = 3
local MOVING_GRACE = 0.5
local HOVER_EXPAND_TIME = 0.2
local HOVER_MINIMIZE_TIME = 0.5
local HOVER_MINIMIZE_DELAY = 1
local PRESS_TYPES = {
    [Enum.UserInputType.MouseButton1] = true,
    [Enum.UserInputType.Touch] = true,
}
local dock = {}

dock.__index = dock

function dock.new(options)
    local self = setmetatable({
        frame = options.frame,
        screenGui = options.screenGui,
        topBarHeight = options.topBarHeight,
        clampPosition = options.clampPosition,
        getScale = options.getScale,
        onMinimize = options.onMinimize,
        onInteractive = options.onInteractive,
        hoverToOpen = options.hoverToOpen == true and UserInputService.MouseEnabled,
        commandBarInUse = options.commandBarInUse,
        isMoving = options.isMoving,
        lastMovingAt = -math.huge,
        state = 'minimized',
        interactive = nil,
        hovering = false,
        hoverRequest = 0,
        dragging = false,
        keepOpen = options.keepOpen == true,
        windowParts = {},
        tween = nil,
        press = nil,
        touches = {},
        outsideTouches = {},
        swipeLocked = false,
        lastInteractionAt = -math.huge,
        connections = {},
    }, dock)

    self.frame.Position = self:targetFor('minimized')

    table.insert(self.connections, connectionService:Connect(UserInputService.InputBegan, function(
        input
    )
        self:onInputBegan(input)
    end))
    table.insert(self.connections, connectionService:Connect(UserInputService.InputEnded, function(
        input
    )
        self:onInputEnded(input)
    end))
    table.insert(self.connections, connectionService:Connect(UserInputService.InputChanged, function(
        input
    )
        self:onInputChanged(input)
    end))
    table.insert(self.connections, connectionService:Connect(RunService.Heartbeat, function(
    )
        if self.isMoving and self.isMoving() then
            self.lastMovingAt = os.clock()
        end

        self:checkLockIdle()
    end))
    self:setInteractive(false)

    if self.hoverToOpen then
        table.insert(self.connections, connectionService:Connect(self.frame.MouseEnter, function(
        )
            if self.frame.Visible then
                self:setHovering(true)
            end
        end))
        table.insert(self.connections, connectionService:Connect(self.frame.MouseLeave, function(
        )
            self:setHovering(false)
        end))
    end

    return self
end

local function pointInside(object, point)
    local pos = object.AbsolutePosition
    local size = object.AbsoluteSize

    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function dock:isOverWindow(point)
    if pointInside(self.frame, point) then
        return true
    end

    for _, part in self.windowParts do
        if pointInside(part, point) then
            return true
        end
    end

    return false
end
function dock:addWindowPart(object)
    table.insert(self.windowParts, object)
end
function dock:setKeepOpen(enabled)
    self.keepOpen = enabled == true

    if self.keepOpen and self.state == 'minimized' then
        self:expand()
    end
end
function dock:reveal()
    self:lockSwipe()

    if self.state == 'minimized' then
        self:expand()
    end
end
function dock:lockSwipe()
    if self.hoverToOpen then
        return
    end
    if not self:fingerOutsideWindow() then
        return
    end

    self.swipeLocked = true
    self.lastInteractionAt = os.clock()
end
function dock:fingerOutsideWindow()
    for _, position in self.touches do
        if not self:isOverWindow(position) then
            return true
        end
    end

    return false
end
function dock:unlockSwipe()
    self.swipeLocked = false
end
function dock:noteInteraction()
    self.lastInteractionAt = os.clock()
end
function dock:checkLockIdle()
    if self.swipeLocked and os.clock() - self.lastInteractionAt >= LOCK_IDLE_TIME then
        self.swipeLocked = false
    end
end
function dock:onSettled(fn)
    local tween = self.tween

    if tween and tween.PlaybackState == Enum.PlaybackState.Playing then
        tween.Completed:Once(fn)
    else
        task.defer(fn)
    end
end
function dock:nearestSnap()
    local frame = self.frame
    local distanceToTop = frame.AbsolutePosition.Y
    local distanceToBottom = self.screenGui.AbsoluteSize.Y - (frame.AbsolutePosition.Y + frame.AbsoluteSize.Y)

    if distanceToTop <= distanceToBottom then
        return 'top'
    end
    if self.state == 'expanded' then
        return 'expanded'
    end

    return 'minimized'
end
function dock:targetFor(state)
    local x = self.clampPosition(self.frame.Position).X

    if state == 'top' then
        return UDim2.new(x.Scale, x.Offset, 0, 0)
    end
    if state == 'expanded' then
        return UDim2.new(x.Scale, x.Offset, 1, -self.frame.Size.Y.Offset)
    end

    return UDim2.new(x.Scale, x.Offset, 1, -self.topBarHeight)
end
function dock:clampDrag(pos)
    local x = self.clampPosition(pos).X
    local scale = math.max(self.getScale(), 0.01)
    local screenHeight = self.screenGui.AbsoluteSize.Y / scale
    local maxY = math.max(screenHeight - self.topBarHeight, 0)
    local y = math.clamp(pos.Y.Scale * screenHeight + pos.Y.Offset, 0, maxY)

    return UDim2.new(x.Scale, x.Offset, 0, y)
end
function dock:wasMovingRecently()
    return os.clock() - self.lastMovingAt < MOVING_GRACE
end
function dock:setInteractive(enabled)
    if self.interactive == enabled then
        return
    end

    self.interactive = enabled

    if self.onInteractive then
        self.onInteractive(enabled)
    end
end
function dock:cancel()
    if self.tween then
        self.tween:Cancel()

        self.tween = nil
    end
end
function dock:moveTo(state, time, direction)
    if state == self.state and self.tween and self.tween.PlaybackState == Enum.PlaybackState.Playing then
        return
    end

    local wasMinimized = self.state == 'minimized'

    self.state = state

    self:cancel()

    if state == 'minimized' then
        self.swipeLocked = false
    elseif wasMinimized then
        self:lockSwipe()
    end
    if state == 'minimized' then
        self:setInteractive(false)
    end

    local target = self:targetFor(state)
    local duration = uiTweens:getScale(time or MOVE_TIME)

    if duration <= 0 then
        self.frame.Position = target

        self:setInteractive(state ~= 'minimized')

        return
    end

    local info = TweenInfo.new(duration, Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out)
    local tween = TweenService:Create(self.frame, info, {Position = target})

    self.tween = tween

    tween.Completed:Connect(function(playback)
        if playback ~= Enum.PlaybackState.Completed then
            return
        end
        if self.tween ~= tween or self.state == 'minimized' then
            return
        end

        self:setInteractive(true)
    end)
    tween:Play()
end
function dock:expand(time, direction)
    self:moveTo('expanded', time, direction)
end
function dock:setHovering(over)
    if over == self.hovering then
        return
    end

    self.hovering = over

    if self.dragging then
        return
    end
    if over then
        self:onHoverEnter()
    else
        self:onHoverLeave()
    end
end
function dock:onHoverEnter()
    self.hoverRequest = self.hoverRequest + 1

    if self.state == 'minimized' then
        self:expand(HOVER_EXPAND_TIME, Enum.EasingDirection.InOut)
    end
end
function dock:onHoverLeave()
    self.hoverRequest = self.hoverRequest + 1

    local request = self.hoverRequest

    if not self:canHoverMinimize() then
        return
    end

    task.delay(HOVER_MINIMIZE_DELAY, function()
        if request ~= self.hoverRequest or not self:canHoverMinimize() then
            return
        end

        self:minimize(HOVER_MINIMIZE_TIME, Enum.EasingDirection.InOut)
    end)
end
function dock:canHoverMinimize()
    return self.state == 'expanded' and not self.keepOpen and not self:commandBarBusy()
end
function dock:onCommandBarClosed(enteredCommand)
    if not self.hoverToOpen then
        return
    end
    if self:fingerOnWindow() then
        return
    end

    local request = self.hoverRequest

    task.wait()

    if request ~= self.hoverRequest or self.dragging or not self:canHoverMinimize() then
        return
    end
    if self.hovering and not enteredCommand then
        return
    end
    if self:fingerOnWindow() then
        return
    end

    self:minimize(HOVER_MINIMIZE_TIME, Enum.EasingDirection.InOut)
end
function dock:onMobileEnter(isFocused)
    if self.hoverToOpen then
        return
    end
    if not self:wasMovingRecently() then
        return
    end

    task.wait()

    if self.dragging or isFocused() then
        return
    end
    if self.state ~= 'expanded' or self.keepOpen then
        return
    end

    self:minimize()
end
function dock:setDragging(dragging)
    local wasDragging = self.dragging

    self.dragging = dragging == true

    if wasDragging and not self.dragging and self.hoverToOpen and not self.hovering then
        self:onHoverLeave()
    end
end
function dock:minimize(time, direction)
    if self.onMinimize then
        self.onMinimize()
    end

    self:moveTo('minimized', time, direction)
end
function dock:reflow()
    self:cancel()

    self.frame.Position = self:targetFor(self.state)

    self:setInteractive(self.state ~= 'minimized')
end
function dock:sleep()
    self:cancel()

    self.state = 'minimized'
    self.swipeLocked = false
    self.frame.Position = self:targetFor('minimized')

    self:setInteractive(false)
end
function dock:onDragEnded(gesture)
    if gesture.travel <= TAP_MAX_TRAVEL then
        self:moveTo(self.state)

        return
    end
    if gesture.dy >= DRAG_DOWN_MIN and not self:commandBarBusy() and not self.swipeLocked then
        self:minimize()

        return
    end

    self:moveTo(self:nearestSnap())
end
function dock:onListSwipeDown()
    if self.hoverToOpen or self.swipeLocked then
        return
    end
    if self.state == 'minimized' or self:commandBarBusy() then
        return
    end

    self:minimize()
end
function dock:commandBarBusy()
    return self.commandBarInUse ~= nil and self.commandBarInUse() == true
end
function dock:fingerOnWindow()
    for _, position in self.touches do
        if self:isOverWindow(position) then
            return true
        end
    end

    return false
end
function dock:onInputChanged(input)
    if input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    if self.touches[input] == nil then
        return
    end

    self.touches[input] = input.Position

    if self:isOverWindow(input.Position) then
        self:noteInteraction()
    end

    local startPos = self.outsideTouches[input]

    if startPos and (input.Position - startPos).Magnitude >= SWIPE_OUTSIDE_MIN then
        self:onOutsideSwipe()
    end
end
function dock:onOutsideSwipe()
    if self.hoverToOpen or self.dragging or self.swipeLocked then
        return
    end
    if self.state ~= 'expanded' or self.keepOpen or self:commandBarBusy() then
        return
    end

    table.clear(self.outsideTouches)
    self:minimize()
end
function dock:onInputBegan(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        self.touches[input] = input.Position

        if self:isOverWindow(input.Position) then
            self:noteInteraction()
        else
            self.outsideTouches[input] = input.Position
        end
    end
    if not PRESS_TYPES[input.UserInputType] then
        return
    end

    self.press = {
        type = input.UserInputType,
        time = os.clock(),
        position = input.Position,
        inside = self:isOverWindow(input.Position),
        startedExpanded = self.state == 'expanded',
    }
end
function dock:onInputEnded(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        self.touches[input] = nil
        self.outsideTouches[input] = nil
    end

    local press = self.press

    if not press or input.UserInputType ~= press.type then
        return
    end

    self.press = nil

    local duration = os.clock() - press.time
    local travel = (input.Position - press.position).Magnitude

    if press.inside then
        if duration <= TAP_MAX_TIME and travel <= TAP_MAX_TRAVEL and self.state == 'minimized' then
            self:expand()
        end

        return
    end

    local isClick = duration <= CLICK_MAX_TIME and travel <= TAP_MAX_TRAVEL

    if isClick and press.startedExpanded and not self.hoverToOpen and self.state == 'expanded' and not self.keepOpen and not self:commandBarBusy() and not self:wasMovingRecently() then
        self:minimize()
    end
end
function dock:destroy()
    self:cancel()

    self.hoverRequest = self.hoverRequest + 1

    for _, connection in self.connections do
        connectionService:disconnect(connection)
    end

    table.clear(self.connections)
    table.clear(self.touches)
    table.clear(self.outsideTouches)
end

return dock
