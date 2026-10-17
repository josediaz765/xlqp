local createService = require('./services/createService')
local assetsService = require('./services/assetsService')
local themeService = require('./services/themeService')
local scaleObject = require('./utils/scaleObject')
local connectionService = require('../framework/services/connectionService')
local robloxServices = require('../framework/services/rbxServices')
local config = require('../framework/config/ui/notifier')
local textHighlight = require('../utils/textHighlight')
local ICON_MARGIN = 4
local TITLE_GAP = 8
local BODY_BOTTOM = 5
local TEXT_INSET = 5
local BODY_CHROME = config.titleHeight + BODY_BOTTOM + TEXT_INSET * 2
local notifier = {
    container = nil,
    items = {},
    nextOrder = 0,
    queue = {},
    room = math.huge,
}

local function createPopup(parent, order)
    local popup = createService.new('Frame', 'Notification', parent, {
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = order,
        Size = UDim2.fromOffset(config.size.X.Offset, 0),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
        },
    })
    local titleInset = ICON_MARGIN + config.iconSize + TITLE_GAP
    local titleLabel = createService.new('TextLabel', 'Title', popup, {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0),
        Size = UDim2.new(1, -titleInset * 2, 0, config.titleHeight),
        Text = '',
        TextSize = config.titleTextSize,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ThemeTag = {
            Font = 'Font.Normal',
            TextColor3 = 'Colors.Text.Default',
        },
    })
    local descHolder = createService.new('Frame', 'Description', popup, {
        AnchorPoint = Vector2.new(0.5, 1),
        ClipsDescendants = true,
        Position = UDim2.new(0.5, 0, 1, -BODY_BOTTOM),
        Size = UDim2.new(1, -10, 1, -(config.titleHeight + BODY_BOTTOM)),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
    })

    createService.new('UICorner', descHolder, {
        CornerRadius = UDim.new(0, config.cornerRadius),
    })

    local textLabel = createService.new('TextLabel', 'Text', descHolder, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(TEXT_INSET, TEXT_INSET),
        Size = UDim2.new(1, -TEXT_INSET * 2, 0, 0),
        Text = '',
        TextSize = config.textSize,
        RichText = true,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
    })
    local pinButton = createService.new('ImageButton', 'PinButton', popup, {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, ICON_MARGIN, 0, config.titleHeight / 2),
        Size = UDim2.fromOffset(config.iconSize, config.iconSize),
        ThemeTag = {
            ImageColor3 = 'Colors.Icons',
        },
    })
    local closeButton = createService.new('ImageButton', 'CloseButton', popup, {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -ICON_MARGIN, 0, config.titleHeight / 2),
        Size = UDim2.fromOffset(config.iconSize, config.iconSize),
        ThemeTag = {
            ImageColor3 = 'Colors.Icons',
        },
    })

    assetsService:loadImage(pinButton, 'pin')
    assetsService:loadImage(closeButton, 'close')

    return popup, titleLabel, textLabel, pinButton, closeButton, descHolder
end
local function createActions(descHolder, choices, connections)
    local row = createService.new('Frame', 'Actions', descHolder, {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 1, -TEXT_INSET),
        Size = UDim2.new(1, -TEXT_INSET * 2, 0, config.actionHeight),
        ZIndex = 2,
        createService.new('UIListLayout', {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, config.actionGap),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        }),
    })
    local buttons = {}

    for index, choice in choices do
        local primary = choice.primary == true
        local button = createService.new('TextButton', 'Action', row, {
            AutoButtonColor = false,
            AutomaticSize = Enum.AutomaticSize.X,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Size = UDim2.fromOffset(0, config.actionHeight),
            Text = choice.text,
            TextSize = config.textSize,
            ZIndex = 2,
            ThemeTag = {
                BackgroundColor3 = if choice.primary then'Colors.Primary'else'Colors.Background',
                Font = 'Font.Normal',
                TextColor3 = 'Colors.Text.Default',
            },
            createService.new('UICorner', {
                CornerRadius = UDim.new(0, config.cornerRadius),
            }),
            createService.new('UIPadding', {
                PaddingLeft = UDim.new(0, config.actionPadding),
                PaddingRight = UDim.new(0, config.actionPadding),
            }),
            createService.new('UISizeConstraint', {
                MinSize = Vector2.new(config.actionMinWidth, 0),
            }),
        })

        local function paint(hovered)
            if primary then
                button.BackgroundTransparency = if hovered then 0.2 else 0
            else
                themeService:updateObjectProperties(button, {
                    BackgroundColor3 = if hovered then'Colors.Buttons.Holding'else'Colors.Background',
                })
            end
        end

        table.insert(connections, connectionService:Connect(button.MouseEnter, function(
        )
            paint(true)
        end))
        table.insert(connections, connectionService:Connect(button.MouseLeave, function(
        )
            paint(false)
        end))

        buttons[index] = button
    end

    return buttons
end
local function disconnectItem(item)
    for _, connection in item.connections do
        connectionService:disconnect(connection)
    end

    table.clear(item.connections)
end

function notifier:getContainer(screenGui)
    if self.container then
        return self.container
    end

    local container = createService.new('Frame', 'Notifications', screenGui, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(config.size.X.Offset, 0),
    })

    createService.new('UIListLayout', container, {
        Padding = UDim.new(0, config.spacing),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    self.container = container

    container.ChildAdded:Connect(function()
        self:refreshLayout()
    end)
    container.ChildRemoved:Connect(function()
        self:refreshLayout()
    end)

    local pending = self.queue

    self.queue = {}

    for _, item in pending do
        self:add(item.title, item.message, item.duration, item.choices)
    end

    return container
end
function notifier:getStackHeight()
    local container = self.container

    if not container then
        return 0
    end

    local count = 0
    local height = 0

    for _, child in container:GetChildren()do
        if child:IsA('GuiObject') then
            count += 1
            height += child.Size.Y.Offset
        end
    end

    if count > 1 then
        height += (count - 1) * config.spacing
    end

    return height
end
function notifier:refreshLayout()
    local container = self.container

    if not container then
        return
    end

    container.Size = UDim2.fromOffset(config.size.X.Offset, self:getStackHeight())

    if self.onLayoutChanged then
        self.onLayoutChanged()
    end
end
function notifier:tweenHeight(item, height)
    if item.tween then
        item.tween:Cancel()
    end

    local info = TweenInfo.new(config.tweenTime, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

    item.tween = robloxServices.TweenService:Create(item.frame, info, {
        Size = UDim2.fromOffset(config.size.X.Offset, height),
    })

    item.tween:Play()
end
function notifier:wantedHeight(item)
    local scale = math.max(scaleObject:getScale(), 0.01)
    local textHeight = item.textLabel.AbsoluteSize.Y / scale
    local minHeight = if item.actionsHeight > 0 then 0 else config.size.Y.Offset
    local height = math.max(textHeight + BODY_CHROME + item.actionsHeight, minHeight)

    return math.min(height, config.maxHeight, self.room)
end
function notifier:fitHeight(item, instant)
    if item.removed or not item.textLabel then
        return
    end

    local height = self:wantedHeight(item)

    if height == item.height then
        return
    end

    item.height = height

    if instant then
        if item.tween then
            item.tween:Cancel()
        end

        item.frame.Size = UDim2.fromOffset(config.size.X.Offset, height)
    else
        self:tweenHeight(item, height)
    end
end
function notifier:setRoom(room)
    if room == self.room then
        return
    end

    self.room = room

    for _, item in self.items do
        self:fitHeight(item, true)
    end

    self:trimToRoom()
end
function notifier:liveHeight()
    local height = 0

    for _, item in self.items do
        height += item.height
    end

    if #self.items > 1 then
        height += (#self.items - 1) * config.spacing
    end

    return height
end
function notifier:trimToRoom()
    while#self.items > 1 and self:liveHeight() > self.room do
        local oldest = nil

        for index, item in self.items do
            if index == #self.items then
                break
            end
            if not item.pinned then
                oldest = item

                break
            end
        end

        if not oldest then
            break
        end

        self:remove(oldest)
    end
end
function notifier:pin(item)
    if item.pinned or item.removed then
        return
    end

    item.pinned = true
    item.titleLabel.Text = item.title .. ' (Pinned)'

    themeService:addObject(item.pinButton, {
        ImageColor3 = 'Colors.Primary',
    })

    local titleLabel = item.titleLabel

    task.spawn(function()
        titleLabel.TextTransparency = 0.5

        task.wait(config.flashTime)

        titleLabel.TextTransparency = 0
    end)
end
function notifier:remove(item)
    if item.removed then
        return
    end

    item.removed = true

    local index = table.find(self.items, item)

    if index then
        table.remove(self.items, index)
    end

    disconnectItem(item)
    self:tweenHeight(item, 0)
    task.delay(config.tweenTime, function()
        item.frame:Destroy()
    end)
end
function notifier:trim()
    while#self.items > config.maxVisible do
        local oldest = nil

        for _, item in self.items do
            if not item.pinned then
                oldest = item

                break
            end
        end

        if not oldest then
            break
        end

        self:remove(oldest)
    end
end
function notifier:add(title, message, duration, choices)
    self.nextOrder += 1

    local item = {
        title = title,
        pinned = false,
        removed = false,
        connections = {},
        height = config.size.Y.Offset,
        actionsHeight = if choices then config.actionHeight + config.actionsTopGap + TEXT_INSET else 0,
    }
    local descHolder

    item.frame, item.titleLabel, item.textLabel, item.pinButton, item.closeButton, descHolder = createPopup(self.container, self.nextOrder)
    item.titleLabel.Text = title
    item.textLabel.Text = textHighlight:apply(message)

    table.insert(item.connections, connectionService:Connect(item.pinButton.Activated, function(
    )
        self:pin(item)
    end))

    local sticky = choices ~= nil and type(duration) ~= 'number'

    if sticky then
        item.pinned = true
        item.pinButton.Visible = false
    end
    if choices then
        local buttons = createActions(descHolder, choices, item.connections)

        for index, button in buttons do
            local choice = choices[index]

            table.insert(item.connections, connectionService:Connect(button.Activated, function(
            )
                if item.removed then
                    return
                end

                self:remove(item)

                if choice.onTap then
                    choice.onTap()
                end
            end))
        end
    end

    table.insert(item.connections, connectionService:Connect(item.closeButton.Activated, function(
    )
        self:remove(item)
    end))
    table.insert(item.connections, connectionService:Connect(item.textLabel:GetPropertyChangedSignal('AbsoluteSize'), function(
    )
        self:fitHeight(item)
    end))
    table.insert(self.items, item)
    self:tweenHeight(item, item.height)
    item.frame:GetPropertyChangedSignal('Size'):Connect(function()
        self:refreshLayout()
    end)
    self:refreshLayout()

    if not sticky then
        local waitTime = if type(duration) == 'number'then duration else config.defaultTime

        task.delay(waitTime, function()
            if not item.pinned then
                self:remove(item)
            end
        end)
    end

    self:trim()
    self:trimToRoom()
end
function notifier:notify(title, message, duration)
    if message == nil then
        message = title
        title = config.defaultTitle
    end

    title = tostring(title)

    if not self.container then
        table.insert(self.queue, {
            title = title,
            message = message,
            duration = duration,
        })

        return
    end

    self:add(title, message, duration)
end
function notifier:ask(title, message, choices, duration)
    title = tostring(title)

    if not self.container then
        table.insert(self.queue, {
            title = title,
            message = message,
            choices = choices,
            duration = duration,
        })

        return
    end

    self:add(title, message, duration, choices)
end
function notifier:destroy()
    for _, item in self.items do
        disconnectItem(item)
    end

    table.clear(self.items)
    table.clear(self.queue)

    self.container = nil
end

return notifier
