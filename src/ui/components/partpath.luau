local createService = require('../services/createService')
local assetsService = require('../services/assetsService')
local themeService = require('../services/themeService')
local notifier = require('../notifier')
local dragInstance = require('../utils/dragInstance')
local coreGui = require('../coreGui')
local connectionService = require('../../framework/services/connectionService')
local playerService = require('../../framework/services/playerService')
local executorEnv = require('../../framework/environment/executor')
local config = require('../../framework/config/ui/partpath')
local getHierarchy = require('../../utils/getHierarchy')
local highlight = require('../../utils/textHighlight')
local tools = require('../../utils/tools')
local windowConfig = config.window
local textSizes = config.textSizes
local buttonsConfig = config.buttons
local SHOWN_POSITION = UDim2.new(0.5, -windowConfig.width / 2, 0, windowConfig.shownY)
local HIDDEN_POSITION = UDim2.new(0.5, -windowConfig.width / 2, 0, windowConfig.hiddenY)
local HOVER_COLOR = Color3.fromRGB(255, 255, 255)
local SELECTED_COLOR = Color3.fromRGB(0, 166, 0)
local partPath = {}

partPath.__index = partPath

function partPath.new()
    return setmetatable({
        frame = nil,
        hoverBox = nil,
        selectedBox = nil,
        pathLabel = nil,
        copyButton = nil,
        isOpen = false,
        path = nil,
        selectedPart = nil,
        onSelectPart = nil,
        connections = {},
    }, partPath)
end

local function createRow(body, layoutOrder, height, name)
    return createService.new('Frame', name, body, {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = if layoutOrder % 2 == 1 then windowConfig.stripeTransparency else 1,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        Size = UDim2.new(1, 0, 0, height),
    })
end
local function createTextRow(body, layoutOrder, name, look)
    local row = createService.new('Frame', name, body, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = if layoutOrder % 2 == 1 then windowConfig.stripeTransparency else 1,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        Size = UDim2.new(1, 0, 0, 0),
        createService.new('UIPadding', {
            PaddingBottom = UDim.new(0, windowConfig.rowPadding),
            PaddingLeft = UDim.new(0, windowConfig.textInset),
            PaddingRight = UDim.new(0, windowConfig.textInset),
            PaddingTop = UDim.new(0, windowConfig.rowPadding),
        }),
        createService.new('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local label = createService.new('TextLabel', look.labelName, row, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        TextSize = look.textSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = look.color,
        },
    })

    return row, label
end
local function breakPath(path)
    local segments = {}
    local current = ''

    for index = 1, #path do
        local char = string.sub(path, index, index)

        if (char == '.' or char == '[') and current ~= '' then
            table.insert(segments, current)

            current = ''
        end

        current = current .. char
    end

    if current ~= '' then
        table.insert(segments, current)
    end

    local lines = {}
    local line = ''

    for _, segment in segments do
        if line ~= '' and #line + #segment > config.window.pathCharsPerLine then
            table.insert(lines, line)

            line = ''
        end

        line = line .. segment
    end

    if line ~= '' then
        table.insert(lines, line)
    end

    return table.concat(lines, '\n')
end
local function createSection(body, layoutOrder, title)
    local row = createRow(body, layoutOrder, windowConfig.rowHeight, 'Section')

    createService.new('TextLabel', 'Title', row, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(windowConfig.textInset, 0),
        Size = UDim2.new(1, -windowConfig.textInset * 2, 1, 0),
        RichText = true,
        Text = `<b>{tools.escapeRichText(title)}</b>`,
        TextSize = textSizes.section,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Darker',
        },
    })

    return row
end
local function createButton(parent, name, text, position, size)
    local button = createService.new('TextButton', name, parent, {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        Text = text,
        TextSize = textSizes.button,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, buttonsConfig.cornerRadius),
        }),
    })

    connectionService:Connect(button.MouseEnter, function()
        themeService:updateObjectProperties(button, {
            BackgroundColor3 = 'Colors.Buttons.Holding',
        })
    end)
    connectionService:Connect(button.MouseLeave, function()
        themeService:updateObjectProperties(button, {
            BackgroundColor3 = 'Colors.Buttons.Default',
        })
    end)

    return button
end

function partPath:create()
    if self.frame then
        return self.frame
    end

    local frame = createService.new('Frame', 'PartPath', {
        Active = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Position = HIDDEN_POSITION,
        Size = UDim2.fromOffset(windowConfig.width, 0),
        Visible = false,
        createService.new('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local topBar = createService.new('Frame', 'TopBar', frame, {
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Size = UDim2.new(1, 0, 0, windowConfig.topBarHeight),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
        },
    })

    createService.new('TextLabel', 'Title', topBar, {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = windowConfig.title,
        TextSize = textSizes.title,
        ThemeTag = {
            Font = 'Font.Normal',
            TextColor3 = 'Colors.Text.Default',
        },
    })

    local exitButton = createService.new('ImageButton', 'Exit', topBar, {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -windowConfig.closeInset, 0.5, 0),
        Size = UDim2.fromOffset(windowConfig.closeIconSize, windowConfig.closeIconSize),
        ThemeTag = {
            ImageColor3 = 'Colors.Icons',
        },
    })

    assetsService:loadImage(exitButton, 'close')

    local body = createService.new('Frame', 'Body', frame, {
        Active = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        LayoutOrder = 2,
        Size = UDim2.new(1, 0, 0, 0),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
        },
        createService.new('UIPadding', {
            PaddingBottom = UDim.new(0, windowConfig.verticalPadding),
            PaddingTop = UDim.new(0, windowConfig.verticalPadding),
        }),
        createService.new('UIListLayout', {
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    createSection(body, 1, config.headers.path)

    local _, pathLabel = createTextRow(body, 2, 'PathRow', {
        labelName = 'Path',
        textSize = textSizes.value,
        color = 'Colors.Text.Default',
    })

    pathLabel.RichText = true

    createSection(body, 3, config.headers.actions)

    local buttonRow = createRow(body, 4, windowConfig.buttonRowHeight, 'ButtonRow')
    local half = windowConfig.buttonGap / 2
    local inset = windowConfig.textInset
    local buttonY = (windowConfig.buttonRowHeight - windowConfig.buttonHeight) / 2
    local buttonSize = UDim2.new(0.5, -(inset + half), 0, windowConfig.buttonHeight)
    local selectButton = createButton(buttonRow, 'SelectPart', buttonsConfig.selectPart, UDim2.new(0, inset, 0, buttonY), buttonSize)
    local copyButton = createButton(buttonRow, 'CopyPath', buttonsConfig.copyPath, UDim2.new(0.5, half, 0, buttonY), buttonSize)
    local _, helpLabel = createTextRow(body, 5, 'Help', {
        labelName = 'HelpText',
        textSize = textSizes.help,
        color = 'Colors.Text.Darker',
    })

    helpLabel.Text = config.labels.help

    local hoverBox = createService.new('SelectionBox', 'Hover', coreGui, {Color3 = HOVER_COLOR})
    local selectedBox = createService.new('SelectionBox', 'Selected', coreGui, {Color3 = SELECTED_COLOR})

    connectionService:Connect(exitButton.Activated, function()
        self:close()
    end)
    connectionService:Connect(selectButton.Activated, function()
        self:confirmSelection()
    end)
    connectionService:Connect(copyButton.Activated, function()
        self:copyPath()
    end)
    dragInstance:addGuiObject(frame)

    self.frame = frame
    self.hoverBox = hoverBox
    self.selectedBox = selectedBox
    self.pathLabel = pathLabel
    self.copyButton = copyButton

    self:setPath(nil)

    return frame
end
function partPath:open(onSelectPart)
    self:create()

    self.onSelectPart = onSelectPart

    if self.isOpen then
        return
    end

    self.isOpen = true
    self.frame.Visible = true

    self.frame:TweenPosition(SHOWN_POSITION, Enum.EasingDirection.InOut, Enum.EasingStyle.Quart, windowConfig.tweenTime, true)
    self:startSelecting()
end
function partPath:close()
    if not self.isOpen then
        return
    end

    self.isOpen = false

    self:disconnectMouse()
    self:clearSelection()
    self.frame:TweenPosition(HIDDEN_POSITION, Enum.EasingDirection.InOut, Enum.EasingStyle.Quart, windowConfig.tweenTime, true)
    task.delay(windowConfig.tweenTime, function()
        if not self.isOpen and self.frame then
            self.frame.Visible = false
        end
    end)
end
function partPath:isPointerOverWindow()
    return self.frame ~= nil and playerService:isMouseInGuiObject(self.frame)
end
function partPath:startSelecting()
    self:disconnectMouse()

    local mouse = playerService:getMouse()

    table.insert(self.connections, mouse.Move:Connect(function()
        local target = mouse.Target

        if self:isPointerOverWindow() or target == self.selectedPart then
            target = nil
        end

        self.hoverBox.Adornee = target
    end))
    table.insert(self.connections, mouse.Button1Down:Connect(function()
        if self:isPointerOverWindow() then
            return
        end

        local target = mouse.Target

        if target then
            self:selectPart(target)
        end
    end))
end
function partPath:disconnectMouse()
    for _, connection in self.connections do
        connection:Disconnect()
    end

    self.connections = {}
end
function partPath:selectPart(part)
    self.selectedPart = part
    self.selectedBox.Adornee = part
    self.hoverBox.Adornee = nil

    self:setPath(getHierarchy(part))
end
function partPath:setPath(path)
    local label = self.pathLabel

    self.path = path

    if path then
        themeService:addObject(label, {
            TextColor3 = 'Colors.Text.Default',
            Font = 'Font.MonoSpace',
        })

        label.RichText = true
        label.Text = highlight:apply(breakPath(path))
    else
        themeService:addObject(label, {
            TextColor3 = 'Colors.Text.Darker',
            Font = 'Font.MonoSpace',
        })

        label.RichText = false
        label.Text = config.labels.hint
    end
end
function partPath:clearSelection()
    self.selectedPart = nil
    self.hoverBox.Adornee = nil
    self.selectedBox.Adornee = nil

    self:setPath(nil)
end
function partPath:confirmSelection()
    local part = self.selectedPart

    if not part or not part.Parent then
        self:clearSelection()
        notifier:notify(windowConfig.title, config.messages.noPart)

        return
    end
    if self.onSelectPart then
        self.onSelectPart(part)
    end
end
function partPath:copyPath()
    local path = self.path

    if not path then
        notifier:notify(windowConfig.title, config.messages.noPath)

        return
    end
    if not executorEnv.setclipboard then
        notifier:notify(windowConfig.title, config.messages.noClipboard)

        return
    end

    executorEnv.setclipboard(path)

    local button = self.copyButton

    button.Text = buttonsConfig.copied

    task.delay(buttonsConfig.feedbackTime, function()
        button.Text = config.buttons.copyPath
    end)
end
function partPath:destroy()
    self.isOpen = false

    self:disconnectMouse()

    if self.hoverBox then
        self.hoverBox:Destroy()
    end
    if self.selectedBox then
        self.selectedBox:Destroy()
    end
    if self.frame then
        self.frame:Destroy()
    end

    self.frame = nil
    self.hoverBox = nil
    self.selectedBox = nil
    self.pathLabel = nil
    self.copyButton = nil
end

return partPath
