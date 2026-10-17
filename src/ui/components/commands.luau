local connectionService = require('../../framework/services/connectionService')
local robloxServices = require('../../framework/services/rbxServices')
local playerService = require('../../framework/services/playerService')
local createService = require('../services/createService')
local commandData = require('../../commands/systems/commandData')
local commandParser = require('../../commands/systems/commandParser')
local commandRunner = require('../../commands/systems/commandRunner')
local inputUtils = require('../utils/inputUtils')
local assetsService = require('../services/assetsService')
local commandsList = require('../../commands/list')
local signal = require('../../utils/signal')
local logger = require('../../utils/logger')
local tools = require('../../utils/tools')
local scaleObject = require('../utils/scaleObject')
local settingsData = require('../../storage/data/settings')
local cmdsColors = require('../../framework/config/ui/colors').commands
local isMobile = require('../../framework/environment/isMobile')
local userInputService = robloxServices.UserInputService
local runService = robloxServices.RunService
local tweenService = robloxServices.TweenService
local richFontSize = tools.richFontSize
local colorFromRGB = tools.colorFromRGB
local commands = {}

commands.__index = commands

local FOCUS_FRAMES = 6
local SEND_WIDTH = 24
local SEND_HEIGHT = 18
local SEND_ICON_INSET = 3
local SEND_MARGIN = 5
local SEND_GAP = 4
local BAR_TWEEN_TIME = 0.2
local BAR_FULL = UDim2.new(1, -2 * SEND_MARGIN, 0, SEND_HEIGHT)
local BAR_WITH_SEND = UDim2.new(1, -(SEND_MARGIN + SEND_GAP + SEND_WIDTH + SEND_MARGIN), 0, SEND_HEIGHT)
local SWIPE_DOWN_MIN = 50

local function getCommand(commandName)
    return commandsList.lookup[commandName]
end
local function zerofloor(number)
    return math[(number < 0) and 'ceil' or 'floor'](number)
end
local function cleanInput(text)
    text = text:gsub('[\r\n]+$', '')
    text = text:gsub('[\r\n]+', ' ')

    return text
end

function commands:refresh(text)
    local statements = self.parser:parse(text)

    self.parser:highlight(statements)
    self:updateSearchBoxHighlight()

    self:updateSearchedCommand()
end
function commands:applyCorrection()
    local cmdInput = self.commandInput
    local correction = cmdInput.correction
    local raw = cmdInput.rawText
    local newText = raw:sub(1, correction.from - 1) .. correction.text .. raw:sub(correction.to + 1)

    if settingsData:getValue('spaceAfterCorrection') then
        newText ..= ' '
    end

    self:writeText(newText)
end
function commands:ensureFocus()
    local searchBox = self.searchBox

    if not searchBox or not self.isEnabled or not self.interactive then
        return
    end

    self.focusRequest = (self.focusRequest or 0) + 1

    local request = self.focusRequest

    task.spawn(function()
        for _ = 1, FOCUS_FRAMES do
            if request ~= self.focusRequest or not self.isEnabled or not self.interactive then
                return
            end
            if searchBox:IsFocused() then
                return
            end
            if searchBox.Parent ~= nil then
                searchBox:CaptureFocus()
                searchBox.CursorPosition = #searchBox.Text + 1
            end

            runService.Heartbeat:Wait()
        end
    end)
end
function commands:sendText()
    local text = cleanInput(self.searchBox.Text)

    if not text:match('%S') then
        return
    end

    self:refresh(text)
    self:sendInputCommand()
end
function commands:updateSendButton()
    local sendButton = self.sendButton
    local searchBox = self.searchBox

    if not (sendButton and searchBox) then
        return
    end

    local shown = not searchBox:IsFocused() and searchBox.Text:match('%S') ~= nil

    if shown == self.sendShown then
        return
    end

    self.sendShown = shown
    sendButton.Visible = shown

    self:tweenSearchBar(if shown then BAR_WITH_SEND else BAR_FULL)
end
function commands:tweenSearchBar(size)
    local holder = self.searchBoxHolder

    if not holder then
        return
    end
    if self.barTween then
        self.barTween:Cancel()

        self.barTween = nil
    end
    if holder.Size == size then
        return
    end
    if not self.isEnabled then
        holder.Size = size

        return
    end

    local tween = tweenService:Create(holder, TweenInfo.new(BAR_TWEEN_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = size})

    self.barTween = tween

    tween:Play()
end
function commands:captureFocus()
    local searchBox = self.searchBox

    if not searchBox or not self.isEnabled or not self.interactive then
        return
    end
    if searchBox.Parent ~= nil then
        searchBox:CaptureFocus()
        searchBox.CursorPosition = #searchBox.Text + 1
    end
end
function commands:setInteractive(enabled)
    enabled = enabled == true

    if self.interactive == enabled then
        return
    end

    self.interactive = enabled

    local searchBox = self.searchBox
    if searchBox then
        searchBox.Active = enabled
        searchBox.TextEditable = enabled
        pcall(function() searchBox.Interactable = enabled end)
    end

    self.scrollBar:setLocked(not enabled)

    if not enabled then
        self.focusRequest = (self.focusRequest or 0) + 1
        local searchBox = self.searchBox

        if searchBox and searchBox:IsFocused() then
            searchBox:ReleaseFocus()
        end
    end
end
function commands:isInteractive()
    return self.interactive
end
function commands:awake()
    local cmdInput = self.commandInput
    local searchBox = self.searchBox
    local searchHolder = self.searchBoxHolder
    local marker = self.inputMarker
    local placeholder = searchHolder.Placeholder
    local textChangedSignal = searchBox:GetPropertyChangedSignal('Text')
    local function closeSearchBox()
        if searchBox:IsFocused() then
            searchBox:ReleaseFocus()
        end
    end
    local function onEnterPressed()
        if cmdInput.correction then
            self:applyCorrection()
            self:ensureFocus()

            return true
        end

        self:sendInputCommand()

        return false
    end
    local function updatePlaceholder()
        local visible = not searchBox:IsFocused() and #searchBox.Text == 0

        placeholder.Visible = visible

        self:updateSearchBoxHighlight()

        self:updateSendButton()
    end

    self.commandClickedSignal:Connect(function(data)
        if not self.interactive then
            return
        end

        self:writeText(data.aliases[1])
        self:ensureFocus()
    end)
    connectionService:Connect(searchHolder.Activated, function()
        if not self.interactive then
            return
        end

        self:ensureFocus()
    end)
    connectionService:Connect(self.sendButton.Activated, function()
        if not self.interactive then
            return
        end
        if searchBox:IsFocused() then
            searchBox:ReleaseFocus()
        end

        self:sendText()
    end)
    connectionService:Connect(searchBox.Focused, function()
        if self.onInteraction then
            self.onInteraction()
        end

        updatePlaceholder()

        marker.Visible = false

        if #searchBox.Text == 0 then
            self:setComment('')
        end
    end)
    connectionService:Connect(searchBox.FocusLost, function(enterPressed)
        updatePlaceholder()

        marker.Visible = false

        connectionService:disconnect(self.markerConnection)

        if enterPressed then
            self:refresh(cleanInput(searchBox.Text))
            onEnterPressed()
        end
    end)
    connectionService:Connect(textChangedSignal, function()
        if self.onInteraction then
            self.onInteraction()
        end

        local text = searchBox.Text

        if text:find('\t') then
            searchBox.Text = (text:gsub('\t', ''))

            return
        end
        if self.historyIndex and text ~= self.historyText then
            self.historyIndex = nil
        end

        local isEnter = text:sub(-1) == '\n' or text:sub(-1) == '\r'

        if text:find('[\r\n]') then
            text = cleanInput(text)
            searchBox.Text = text

            if isEnter then
                self:refresh(text)

                if not onEnterPressed() then
                    closeSearchBox()
                end

                return
            end
        end

        self.lastText = text

        updatePlaceholder()
        self:refresh(text)
    end)
    connectionService:Connect(userInputService.InputBegan, function(input)
        if not searchBox:IsFocused() then
            return
        end
        if input.KeyCode == Enum.KeyCode.Up then
            self:browseHistory(-1)
        elseif input.KeyCode == Enum.KeyCode.Down then
            self:browseHistory(1)
        elseif input.KeyCode == Enum.KeyCode.Tab and self.commandInput.correction then
            self:applyCorrection()
            self:ensureFocus()
        end
    end)
end

local HISTORY_LIMIT = 50

function commands:sendInputCommand()
    local cmdInput = self.commandInput

    if cmdInput.runError then
        self:setComment(cmdInput.runError, 'error')

        return
    end

    local statements = cmdInput.statements

    for _, info in statements do
        if not info.commandData then
            return
        end
    end

    if self.onCommandSent then
        self.onCommandSent()
    end

    local rawText = cmdInput.rawText
    local failure, failedName = nil, nil

    for _, info in statements do
        local success, reason = pcall(function()
            self:runStatement(info)
        end)

        if not success then
            failure = reason
            failedName = info.commandData.name

            break
        end
    end

    if settingsData:getValue('clearOnEnter') then
        self:writeText('')
    end

    self.historyIndex = nil

    if failure then
        self:setComment(`failed - {failure}`, 'error')
        logger:error(`failed to run command '{failedName}': {failure}`)
    else
        self:addToHistory(rawText)
    end
end
function commands:runStatement(info)
    commandRunner.runStatement(info)
end
function commands:addToHistory(text)
    local line = (text or ''):match('^(.-)%s*$')

    if line == '' then
        return
    end

    local history = self.history

    if history[#history] == line then
        return
    end

    table.insert(history, line)

    if #history > HISTORY_LIMIT then
        table.remove(history, 1)
    end
end
function commands:browseHistory(direction)
    local history = self.history

    if #history == 0 then
        return
    end

    local index

    if self.historyIndex == nil then
        if direction > 0 then
            return
        end

        index = #history
    else
        index = self.historyIndex + direction
    end
    if index < 1 then
        index = 1
    end
    if index > #history then
        self.historyIndex = nil

        self:setSearchText('')

        return
    end

    self.historyIndex = index

    self:setSearchText(history[index])
end
function commands:setSearchText(text)
    self.historyText = text

    self:writeText(text)
end
function commands:writeText(text)
    self.searchBox.Text = text
    self.lastText = text

    self:refresh(text)
    self.searchBox.CursorPosition = #text + 1
end
function commands:create()
    self.searchBoxHolder = createService.new('ImageButton', {
        Size = BAR_FULL,
        Position = UDim2.new(0, SEND_MARGIN, 0, 0),
        AnchorPoint = Vector2.new(0, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, 6),
        }),
        createService.new('TextLabel', 'Input', {
            Size = UDim2.fromScale(0, 1),
            Position = UDim2.new(0, 5, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            TextSize = self.configs.textSize,
            Visible = false,
            RichText = true,
            ThemeTag = {
                TextColor3 = 'Colors.Text.Default',
                Font = 'Font.MonoSpace',
            },
            createService.new('Frame', 'Holder', {
                Size = UDim2.fromScale(0, 1),
                Position = UDim2.fromScale(1, 0),
            }),
        }),
        createService.new('TextLabel', 'Placeholder', {
            Size = UDim2.new(1, -5, 1, 0),
            Position = UDim2.new(0, 5, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            BackgroundTransparency = 1,
            TextSize = self.configs.textSize - 1,
            Text = self.configs.placeholderText,
            ThemeTag = {
                TextColor3 = 'Colors.Text.Dark',
                Font = 'Font.MonoSpace',
            },
        }),
    })

    local searchHolder = self.searchBoxHolder
    local inputHolder = searchHolder.Input.Holder

    self.inputMarker = createService.new('Frame', 'Marker', inputHolder, {
        Size = UDim2.new(0, 1.5, 1, -3),
        Position = UDim2.new(1, 0.2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BorderSizePixel = 0,
        Visible = false,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Primary',
        },
    })
    self.inputComment = createService.new('TextLabel', 'Comment', inputHolder, {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(1, 0.5),
        AnchorPoint = Vector2.new(0, 0.5),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BackgroundTransparency = 1,
        TextSize = self.configs.textSize,
        RichText = true,
        Text = '',
        ThemeTag = {
            TextColor3 = 'Colors.Text.Default',
            Font = 'Font.MonoSpace',
        },
    })
    self.commandInfo = createService.new('TextLabel', 'Info', {
        Size = UDim2.new(1, -25, 0, 0),
        Position = UDim2.new(0, 10, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = self.configs.textFont,
        TextSize = self.configs.textSize - 5,
        Visible = false,
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, 4),
        }),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
            TextColor3 = 'Colors.Text.Default',
        },
    })
    self.searchBox = createService.new('TextBox', 'SearchBox', {
        Active = true,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextTransparency = 0,
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        ClearTextOnFocus = false,
        ShowNativeInput = true,
        TextEditable = true,
        TextSize = self.configs.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        RichText = false,
        Text = '',
        MultiLine = false,
        ZIndex = 2,
        ThemeTag = {
            TextColor3 = 'Colors.Text.Default',
            PlaceholderColor3 = 'Colors.Text.Dark',
            Font = 'Font.MonoSpace',
        },
    })

    pcall(function()
        self.searchBox.Interactable = true
    end)

    self.commandsFolder = createService.new('Folder', 'Commands')

    self:createSendButton()
end
function commands:createSendButton()
    local sendButton = createService.new('TextButton', 'Send', {
        AnchorPoint = Vector2.new(1, 1),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -SEND_MARGIN, 0, 0),
        Size = UDim2.new(0, SEND_WIDTH, 0, SEND_HEIGHT),
        Text = '',
        Visible = false,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, 4),
        }),
    })
    local sendIcon = createService.new('ImageLabel', 'Icon', sendButton, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.new(1, -2 * SEND_ICON_INSET, 1, -2 * SEND_ICON_INSET),
        ThemeTag = {
            ImageColor3 = 'Colors.Icons',
        },
    })

    assetsService:loadImage(sendIcon, 'lucide-send')

    self.sendIcon = sendIcon
    self.sendButton = sendButton
    self.sendShown = false
end
function commands:createCommandsData()
    for pos, command in commandsList.original do
        local cmdData = commandData.new(command)

        command.commandData = cmdData
        cmdData.position = pos - 1

        table.insert(self.commandsData, cmdData)
    end
end
function commands:updateSearchBoxHighlight()
    local text = self.commandInput.highlightText
    local searchHolder = self.searchBoxHolder
    local input = searchHolder.Input
    local scale = scaleObject:getScale()

    input.Text = text
    local focused = self.searchBox:IsFocused()
    input.Visible = #text > 0 and not focused
    self.searchBox.TextTransparency = if focused then 0 else 1
    self.inputMarker.Visible = false

    local totalHolderWidth = searchHolder.AbsoluteSize.X * scale
    local halfHolderWidth = totalHolderWidth / 2
    local currentInputWidth = input.AbsoluteSize.X * scale

    if currentInputWidth <= halfHolderWidth then
        input.AnchorPoint = Vector2.new(0, 0.5)
        input.Position = UDim2.new(0, 5, 0.5, 0)
    else
        input.AnchorPoint = Vector2.new(1, 0.5)
        input.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end
function commands:updateSearchBoxPosition()
    local searchBox = self.searchBox
    local searchHolder = self.searchBoxHolder

    if not self.isEnabled or not (searchBox and searchHolder) then
        return
    end
    searchBox.Parent = searchHolder
    searchBox.Position = UDim2.new(0, 5, 0.5, 0)
    searchBox.Size = UDim2.new(1, -10, 1, 0)
end
function commands:updateSearchedCommand()
    local query = (self.commandInput.commandName or ''):lower()

    if query == self.filterQuery then
        return
    end

    self.filterQuery = query
    self.filteredData = {}
    self.hoveredCommand = nil
    self:clearHoverDescription()

    for _, data in self.commandsData do
        local matches = query == ''

        if not matches and not data.isSection then
            matches = data.name:lower():find(query, 1, true) ~= nil

            if not matches then
                for _, alias in data.aliases or {} do
                    if alias:lower():find(query, 1, true) then
                        matches = true
                        break
                    end
                end
            end
        end

        data.filteredPosition = if matches then #self.filteredData else nil

        if matches then
            table.insert(self.filteredData, data)
        end
    end

    self.scrollBar:scrollTo(0, true)
    self:update()
end
function commands:setComment(text, color)
    if color ~= nil then
        text = commandParser.colorFromName(text, color)
    end

    self.inputComment.Text = text
    self.inputComment.Visible = #text > 0
end
function commands:updateElementColor(element, elementPos)
    local transparency = if elementPos % 2 == 1 then 1 else 0.96

    element.BackgroundTransparency = transparency
end
function commands:updateElements()
    local elementPos = 0
    local longestCommand = 0
    local visibleCommands = {}
    local scrollBar = self.scrollBar
    local commandsFolder = self.commandsFolder

    for pos, cmdData in self.commandsData do
        local position = if self.filteredData then cmdData.filteredPosition else cmdData.position
        local isVisible = position ~= nil and scrollBar:isVisible(position)

        if not isVisible then
            if cmdData.element then
                cmdData.element.Parent = nil
            end

            continue
        end

        local element = cmdData.element

        if not element then
            element = self:createCommandElement(cmdData)
            cmdData.element = element
        end
        if not cmdData.isSection then
            if #cmdData.args > 0 and #cmdData.name > longestCommand then
                longestCommand = #cmdData.name
            end

            table.insert(visibleCommands, cmdData)
        end

        self:updateElementColor(element, position + 1)

        element.Parent = commandsFolder
        element.Position = UDim2.fromOffset(0, elementPos * (element.Size.Y.Offset + self.configs.padding))

        elementPos += 1
    end
    for key, cmdData in visibleCommands do
        self:updateDisplayName(cmdData, longestCommand + 3)
    end

    self.visibleCommands = visibleCommands
end
function commands:setCommandInfo(text)
    text = text or ''

    if text == '' then
        self.commandInfo.Visible = false

        return
    end

    self.commandInfo.Visible = true
    self.commandInfo.Text = text
end
function commands:createSection(data)
    local sectionLabel = createService.new('TextLabel', 'Command', {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(5, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        RichText = true,
        TextSize = self.configs.textSize - 3,
        Text = `<b>#{data.sectionName}</b>`,
        ThemeTag = {
            TextColor3 = 'Colors.Text.Darker',
            Font = 'Font.MonoSpace',
        },
    })

    return createService.new('Frame', {
        Size = UDim2.new(1, -10, 0, self.configs.labelSize),
        BackgroundTransparency = 1,
        sectionLabel,
    })
end
function commands:createCommandElement(data)
    if data.isSection then
        return self:createSection(data)
    end

    local commandLabel = createService.new('TextLabel', 'Command', {
        Size = UDim2.fromScale(0, 1),
        Position = UDim2.fromOffset(5, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.X,
        RichText = true,
        TextSize = self.configs.textSize,
        ThemeTag = {
            TextColor3 = 'Colors.Text.Default',
            Font = 'Font.MonoSpace',
        },
    })

    return createService.new('Frame', {
        Size = UDim2.new(1, 0, 0, self.configs.labelSize),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        commandLabel,
    })
end
function commands:createCommandDescription(data)
    if data.isSection then
        return
    end
    if not data.description then
        return
    end

    local descriptionLabel = createService.new('TextLabel', 'Description', {
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(25, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
        RichText = true,
        TextSize = self.configs.textSize,
        ThemeTag = {
            TextColor3 = 'Colors.Text.Dark',
            Font = 'Font.MonoSpace',
        },
    })

    return createService.new('Frame', 'Description', {
        Size = UDim2.new(1, -30, 0, self.configs.labelSize),
        BackgroundTransparency = 1,
        descriptionLabel,
    })
end
function commands:getCommandColor(cmdName, cmdData)
    local command = getCommand(cmdName)
    local colorName = if type(command.run) ~= 'function'
        then'undefined'
        elseif cmdData.isClient
        then'client'
        elseif cmdData.isDeprecated
        then'deprecated'
        else nil

    if colorName ~= nil then
        cmdName = colorFromRGB(cmdName, cmdsColors[colorName])
    end

    return cmdName
end
function commands:updateDisplayName(cmdData, spaceBeforeArgs)
    local element = cmdData.element
    local commandName = cmdData.name
    local spaces = string.rep('\u{2014}', (spaceBeforeArgs - #commandName) - 2)

    commandName = self:getCommandColor(commandName, cmdData)

    local displayName = `{commandName} {commandParser.colorFromName(spaces, 'comment')} `
    local argsText = self.parser:highlightArgsType(cmdData.args)
    local text = displayName .. argsText

    if cmdData.isHolding then
        cmdData.originalText = text
    else
        self:setCommandText(cmdData, text)
    end
end
function commands:setCommandText(cmdData, text)
    local element = cmdData.element

    if not element then
        return
    end

    element.Command.Text = text
end
function commands:getCommandText(cmdData)
    local element = cmdData.element

    return element and element.Command.Text or ''
end
function commands:calculateTotalSpace()
    return #(self.filteredData or self.commandsData)
end
function commands:calculateVisibleSpace()
    local scrollSize = self.scrollContainer.AbsoluteSize.Y

    return math.floor(scrollSize / self:calculateLabelSize())
end
function commands:calculateLabelSize()
    return self.configs.padding + self.configs.labelSize
end
function commands:getElementMouseIn()
    for _, data in self.visibleCommands do
        if playerService:isMouseInGuiObject(data.element) then
            return data
        end
    end
end
function commands:horizontalScroll(xOffset)
    for _, cmdData in self.visibleCommands do
        local element = cmdData.element

        element.Position = UDim2.fromOffset(math.min(element.Position.X.Offset + xOffset, 0), element.Position.Y.Offset)
    end
end
function commands:showHoverDescription(description)
    local comment = self.inputComment
    local showing = self.hoverText ~= nil and comment.Text == self.hoverText

    if not showing then
        if comment.Text ~= '' then
            self.hoverText = nil

            return false
        end

        self.savedComment = comment.Text
    end

    self.hoverText = commandParser.colorFromName(description, 'comment')
    comment.Text = self.hoverText
    comment.Visible = true

    return true
end
function commands:clearHoverDescription()
    if self.hoverText == nil then
        return
    end

    local comment = self.inputComment

    if comment.Text == self.hoverText then
        comment.Text = self.savedComment or ''
        comment.Visible = #comment.Text > 0
    end

    self.hoverText = nil
    self.savedComment = nil
end
function commands:updateHoverDescription()
    local hovered = nil

    if self.interactive and playerService:isMouseInGuiObject(self.scrollContainer) then
        hovered = self:getElementMouseIn()
    end

    local description = hovered and hovered.description

    if not description then
        self.hoveredCommand = nil

        self:clearHoverDescription()

        return
    end
    if hovered == self.hoveredCommand then
        return
    end
    if self:showHoverDescription(description) then
        self.hoveredCommand = hovered
    end
end
function commands:startedHoldingContainer(input)
    if not self.interactive then
        return
    end
    if not inputUtils.isPressingInput(input) then
        return
    end
    if self.scrollBar:isScrollBarDisabled() then
        return
    end

    self.scrollAxis = nil

    self.scrollBar:disableScroll()

    local playerMouse = playerService:getMouse()
    local lblSize = self:calculateLabelSize()
    local cmdData = self:getElementMouseIn()
    local clickedAt = tick()

    if cmdData and cmdData.description then
        cmdData.isHolding = true

        local desc = self.parser.colorFromName(cmdData.description, 'comment')

        cmdData.originalText = self:getCommandText(cmdData)

        self:setCommandText(cmdData, desc)
    end

    local lastMouseY = playerMouse.Y
    local lastMouseX = playerMouse.X
    local startMouseY = playerMouse.Y
    local swipeFromTop = self.scrollBar.index <= 0
    local downTravel = 0
    local swiped = false
    local mouseEvent

    local function disconnect()
        self.scrollBar:enableScroll()

        if swipeFromTop and self.scrollAxis == 'y' and downTravel >= SWIPE_DOWN_MIN and self.onSwipeDown then
            swiped = true

            self.onSwipeDown()
        end
        if cmdData then
            cmdData.isHolding = nil

            if cmdData.originalText then
                self:setCommandText(cmdData, cmdData.originalText)

                cmdData.originalText = nil
            end
            if (tick() - clickedAt) <= 0.15 and not swiped then
                self.commandClickedSignal:Fire(cmdData)
            end
        end
        if mouseEvent then
            mouseEvent:Disconnect()
        end
    end

    inputUtils.onReleaseEvent(disconnect)

    mouseEvent = inputUtils.onMouseEvent(function(inp)
        if not self.interactive then
            return
        end

        downTravel = playerMouse.Y - startMouseY

        local deltaX = playerMouse.X - lastMouseX
        local deltaY = playerMouse.Y - lastMouseY

        if not self.scrollAxis then
            if math.abs(deltaX) > 4 or math.abs(deltaY) > 4 then
                self.scrollAxis = math.abs(deltaX) > math.abs(deltaY) and 'x' or 'y'
            end

            return
        end
        if self.scrollAxis == 'x' then
            local xOffset = zerofloor(deltaX / 3)

            if math.floor(xOffset) ~= 0 then
                self:horizontalScroll(xOffset)

                lastMouseX = playerMouse.X
            end
        else
            local yOffset = zerofloor(deltaY / lblSize)

            if math.floor(yOffset) ~= 0 then
                self.scrollBar:scrollTo(self.scrollBar.index - yOffset)

                lastMouseY = playerMouse.Y
            end
        end
    end)
end
function commands:update()
    self.scrollBar:setVisibleSpace(self:calculateVisibleSpace())
    self.scrollBar:setTotalSpace(self:calculateTotalSpace())
    self:updateElements()
end
function commands:enable()
    if self.isEnabled then
        return
    end

    local container = self.scrollContainer

    self.isEnabled = true
    self.commandsFolder.Parent = container
    self.searchBoxHolder.Parent = self.scrollHolder
    self.searchBox.Parent = self.searchBoxHolder
    self.sendButton.Parent = self.scrollHolder
    self.commandInfo.Parent = self.scrollHolder
    self.scrollConnection = self.scrolledSignal:Connect(function()
        self:updateElements()
    end)
    self.containerConnection = container.InputBegan:Connect(function(input)
        self:startedHoldingContainer(input)
    end)

    self:update()
    self:updateSearchBoxPosition()

    if not isMobile then
        self.hoverConnection = connectionService:Connect(runService.RenderStepped, function(
        )
            self:updateHoverDescription()
        end)
    end
end
function commands:disable()
    if not self.isEnabled then
        return
    end

    self.isEnabled = false
    self.focusRequest = (self.focusRequest or 0) + 1
    if self.searchBox:IsFocused() then self.searchBox:ReleaseFocus() end
    self.commandsFolder.Parent = nil
    self.searchBox.Parent = nil
    self.searchBoxHolder.Parent = nil
    self.sendButton.Parent = nil
    self.commandInfo.Parent = nil

    connectionService:disconnect(self.containerConnection)
    connectionService:disconnect(self.markerConnection)
    connectionService:disconnect(self.scrollConnection)
    connectionService:disconnect(self.searchBoxConnection)
    connectionService:disconnect(self.hoverConnection)

    self.hoveredCommand = nil

    self:clearHoverDescription()
end
function commands.new(config)
    local function cfg(name)
        return assert(config.configs[name], `missing config.configs['{name}']`)
    end

    local self = setmetatable({
        scrollContainer = config.scrollContainer,
        scrolledSignal = config.scrolledSignal,
        scrollHolder = config.scrollHolder,
        scrollBar = config.scrollBar,
        screenGui = config.screenGui,
        configs = {
            placeholderText = cfg('placeholderText'),
            padding = cfg('padding'),
            labelSize = cfg('labelSize'),
            textSize = cfg('textSize'),
        },
        commandClickedSignal = signal.new(),
        interactive = true,
        commandInput = {
            bestMatch = nil,
            bestMatches = {},
            searchResult = {},
            isValidCommand = false,
            highlightText = '',
            noHighlightText = '',
            fullCommandText = '',
            commandName = '',
        },
        visibleCommands = {},
        commandsData = {},
        history = {},
        historyIndex = nil,
        historyText = '',
        lastText = '',
    }, commands)

    self.parser = commandParser.new(self.commandInput, function(text, color)
        return self:setComment(text, color)
    end)

    return self
end

return commands
