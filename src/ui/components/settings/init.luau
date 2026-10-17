local createService = require('../../services/createService')
local connectionService = require('../../../framework/services/connectionService')
local settingsData = require('../../../storage/data/settings')
local config = require('../../../framework/config/ui/settings')
local frameworkSettings = require('../../../framework/settings')
local robloxServices = require('../../../framework/services/rbxServices')
local uiTweens = require('../../../framework/services/tweenService')
local widgets = require('./widgets')
local buildThemePicker = require('./themePicker')
local keybindPages = require('./keybindsEditor')
local buildImportExport = require('./importExportEditor')
local buildAliasesEditor = require('./aliasesEditor')
local buildWaypointsEditor = require('./waypointsEditor')
local buildPluginsEditor = require('./pluginsEditor')
local buildEventBindsEditor = require('./eventBindsEditor')
local PANEL = config.panel
local BOX = config.box
local ROW = config.row
local VALUE = config.value
local TweenService = robloxServices.TweenService
local SHOWN_Y = PANEL.shownY
local HIDDEN_Y = PANEL.hiddenY
local FLOAT_SIZE = PANEL.floatBackSize
local FLOAT_REST = UDim2.new(1, -(PANEL.floatBackMargin + PANEL.scrollBarThickness), 0, PANEL.floatBackMargin)
local FLOAT_SQUARE = UDim2.fromOffset(FLOAT_SIZE, FLOAT_SIZE)
local FLOAT_FLAT = UDim2.fromOffset(FLOAT_SIZE * PANEL.floatBackFlat, FLOAT_SIZE)
local FLOAT_START = UDim2.new(1, 0, 0, -FLOAT_SIZE * PANEL.floatBackOut)
local PAGES = {
    theme = buildThemePicker,
    keybinds = keybindPages.interface,
    commands = keybindPages.commands,
    importExport = buildImportExport,
    aliases = buildAliasesEditor,
    waypoints = buildWaypointsEditor,
    plugins = buildPluginsEditor,
    eventBinds = buildEventBindsEditor,
}
local settings = {}

settings.__index = settings

local function saveFlag(key, enabled)
    settingsData:setValue(key, enabled == true)
    settingsData:save()
end
local function readFlag(key)
    return settingsData:getValue(key) == true
end
local function slide(frame, position, onDone)
    frame:TweenPosition(position, Enum.EasingDirection.InOut, Enum.EasingStyle.Quart, PANEL.tweenTime, true, onDone)
end

function settings.isKeepMenuOpen()
    return readFlag(config.keys.keepMenuOpen)
end
function settings.setKeepMenuOpen(enabled)
    saveFlag(config.keys.keepMenuOpen, enabled)
end
function settings.isKeepIY()
    return readFlag(config.keys.keepIY)
end
function settings.setKeepIY(enabled)
    saveFlag(config.keys.keepIY, enabled)
end
function settings:createOption(list, option)
    local row = widgets.row(list)

    if option.icon then
        widgets.icon(row, option.icon)
    end
    if option.kind == 'switch' then
        local key = config.keys[option.setting]

        widgets.label(row, option.label, BOX.size + 2 * PANEL.padding)

        local _, fill = widgets.box(row)

        local function refresh()
            fill.Visible = readFlag(key)
        end

        row.Activated:Connect(function()
            local enabled = not readFlag(key)

            saveFlag(key, enabled)
            refresh()

            if self.onSwitch then
                self.onSwitch(option.setting, enabled)
            end
        end)
        refresh()

        return refresh
    end
    if option.kind == 'keybind' then
        widgets.label(row, option.label, VALUE.keybindWidth + 2 * PANEL.padding)

        local refresh, stop = widgets.keybind(row, option.binding)

        table.insert(self.stoppers, stop)

        return refresh
    end

    local hasPage = PAGES[option.action] ~= nil

    if hasPage then
        widgets.chevron(row)
    end

    widgets.label(row, option.label, if hasPage then ROW.chevronSize + 2 * PANEL.padding else 0)
    row.Activated:Connect(function()
        if PAGES[option.action] then
            self:openPage(option.action)
        elseif self.onButton then
            self.onButton(option.action)
        end
    end)

    return nil
end
function settings:createOptions()
    local list = widgets.list(self.panel)

    for _, section in config.sections do
        widgets.header(list, section.title)

        for _, option in section.options do
            local refresh = self:createOption(list, option)

            if refresh then
                table.insert(self.refreshers, refresh)
            end
        end
    end

    local footer = config.footer:gsub('{name}', frameworkSettings.applicationName):gsub('{version}', frameworkSettings.version)

    widgets.footer(list, footer)
end
function settings:createPages()
    for name, build in PAGES do
        local frame = widgets.page(self.holder, `{name}Page`, UDim2.fromScale(1, HIDDEN_Y))

        frame.Visible = false
        self.pages[name] = {
            frame = frame,
            build = build,
        }
    end
end
function settings.new(options)
    return setmetatable({
        onSwitch = options.onSwitch,
        onButton = options.onButton,
        onOpenChanged = options.onOpenChanged,
        isOpen = false,
        isShown = false,
        holder = nil,
        panel = nil,
        current = nil,
        pages = {},
        refreshers = {},
        stoppers = {},
        pageStoppers = {},
        pageConnections = {},
        backRow = nil,
        floatingBack = nil,
        floatingIcon = nil,
        floatingShown = false,
        floatingTween = nil,
        backIcon = nil,
    }, settings)
end
function settings:create(parent, listArea)
    local holder = createService.new('Frame', 'SettingsHolder', parent, {
        AnchorPoint = listArea.AnchorPoint,
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Position = listArea.Position,
        Size = listArea.Size,
        Visible = false,
    })

    self.holder = holder
    self.panel = widgets.page(holder, 'Settings', UDim2.fromScale(0, HIDDEN_Y))
    self.current = self.panel

    self:createOptions()
    self:createPages()
    self:createFloatingBack(holder)

    return holder
end
function settings:createFloatingBack(holder)
    local button = createService.new('TextButton', 'FloatingBack', holder, {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = FLOAT_REST,
        Size = FLOAT_SQUARE,
        Text = '',
        Visible = false,
        ZIndex = 2,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Holding',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
        createService.new('UIStroke', {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1,
            ThemeTag = {
                Color = 'Colors.Border.Default',
            },
        }),
    })
    local icon = widgets.icon(button, config.pages.backIcon)

    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromScale(0.5, 0.5)
    icon.Size = UDim2.fromScale(ROW.iconSize / PANEL.floatBackSize, ROW.iconSize / PANEL.floatBackSize)
    icon.ZIndex = button.ZIndex + 1

    button.Activated:Connect(function()
        self:back()
    end)

    self.floatingBack = button
    self.floatingIcon = icon
end
function settings:syncFloatingIcon()
    local icon, source = self.floatingIcon, self.backIcon

    if icon and source and source.Image ~= '' and icon.Image ~= source.Image then
        icon.Image = source.Image
    end
end
function settings:updateFloatingBack()
    local button = self.floatingBack

    if not button then
        return
    end

    local page = self.current
    local row = self.backRow
    local show = false

    if self.isShown and page ~= self.panel and row and row.Parent then
        show = row.AbsolutePosition.Y + row.AbsoluteSize.Y <= page.AbsolutePosition.Y
    end
    if show then
        self:syncFloatingIcon()
    end
    if show == self.floatingShown then
        return
    end

    self.floatingShown = show

    if show then
        self:showFloatingBack()
    else
        self:hideFloatingBack()
    end
end
function settings:showFloatingBack()
    local button = self.floatingBack

    if not button.Visible then
        button.Position = FLOAT_START
        button.Size = FLOAT_FLAT
        button.Visible = true
    end

    self:tweenFloatingBack(FLOAT_REST, FLOAT_SQUARE, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end
function settings:hideFloatingBack()
    local button = self.floatingBack

    if not button.Visible then
        return
    end

    self:tweenFloatingBack(FLOAT_START, FLOAT_FLAT, Enum.EasingStyle.Quart, Enum.EasingDirection.In, function(
    )
        button.Visible = false
    end)
end
function settings:tweenFloatingBack(position, size, style, direction, onDone)
    local button = self.floatingBack

    self:stopFloatingTween()

    local duration = uiTweens:getScale(PANEL.floatBackTime)

    if duration <= 0 then
        button.Position = position
        button.Size = size

        if onDone then
            onDone()
        end

        return
    end

    local tween = TweenService:Create(button, TweenInfo.new(duration, style, direction), {
        Position = position,
        Size = size,
    })

    self.floatingTween = tween

    tween.Completed:Connect(function(playback)
        if playback ~= Enum.PlaybackState.Completed then
            return
        end
        if self.floatingTween == tween then
            self.floatingTween = nil
        end
        if onDone then
            onDone()
        end
    end)
    tween:Play()
end
function settings:stopFloatingTween()
    local tween = self.floatingTween

    if not tween then
        return
    end

    self.floatingTween = nil

    tween:Cancel()
end
function settings:refresh()
    for _, refresh in self.refreshers do
        refresh()
    end
end
function settings:stopWaiting()
    for _, stop in self.stoppers do
        stop()
    end
    for _, stop in self.pageStoppers do
        stop()
    end
end
function settings:buildPage(page)
    widgets.clear(page.frame)

    self.pageStoppers = {}

    for _, connection in self.pageConnections do
        connection:Disconnect()
    end

    table.clear(self.pageConnections)
    page.build(page.frame, {
        back = function()
            self:back()
        end,
        stoppers = self.pageStoppers,
    })

    self.backRow = page.frame:FindFirstChild('BackRow')
    self.backIcon = if self.backRow then self.backRow:FindFirstChild('Icon')else nil

    if self.backIcon then
        table.insert(self.pageConnections, self.backIcon:GetPropertyChangedSignal('Image'):Connect(function(
        )
            self:syncFloatingIcon()
        end))
        self:syncFloatingIcon()
    end

    table.insert(self.pageConnections, page.frame:GetPropertyChangedSignal('CanvasPosition'):Connect(function(
    )
        self:updateFloatingBack()
    end))
end
function settings:hideWhenGone(frame)
    return function(completed)
        if completed and frame ~= self.current then
            frame.Visible = false
        end
    end
end
function settings:openPage(name)
    local page = self.pages[name]

    if not page or not self.isShown or self.current ~= self.panel then
        return
    end

    self:stopWaiting()

    page.frame.Visible = true

    self:buildPage(page)

    page.frame.CanvasPosition = Vector2.zero
    page.frame.Position = UDim2.fromScale(1, SHOWN_Y)
    self.current = page.frame

    slide(self.panel, UDim2.fromScale(-1, SHOWN_Y), self:hideWhenGone(self.panel))
    slide(page.frame, UDim2.fromScale(0, SHOWN_Y))
    self:updateFloatingBack()
end
function settings:back()
    if self.current == self.panel then
        return
    end

    self:stopWaiting()

    local leaving = self.current

    self.panel.Visible = true

    slide(leaving, UDim2.fromScale(1, SHOWN_Y), self:hideWhenGone(leaving))
    slide(self.panel, UDim2.fromScale(0, SHOWN_Y))

    self.current = self.panel

    self:updateFloatingBack()
end
function settings:reset()
    self.current = self.panel
    self.panel.Visible = true
    self.panel.Position = UDim2.fromScale(0, HIDDEN_Y)

    for _, page in self.pages do
        page.frame.Visible = false
        page.frame.Position = UDim2.fromScale(1, HIDDEN_Y)
    end
end
function settings:toggle()
    self.isOpen = not self.isOpen

    self:setShown(self.isOpen)

    if self.onOpenChanged then
        self.onOpenChanged(self.isOpen)
    end
end
function settings:setShown(shown)
    if not self.panel or self.isShown == shown then
        return
    end

    self.isShown = shown

    local current = self.current

    self:updateFloatingBack()

    if shown then
        self.holder.Visible = true

        slide(current, UDim2.fromScale(0, SHOWN_Y))

        return
    end

    self:stopWaiting()
    slide(current, UDim2.fromScale(0, HIDDEN_Y), function(completed)
        if completed and not self.isShown then
            self.holder.Visible = false

            if not self.isOpen then
                self:reset()
            end
        end
    end)
end
function settings:watchCommandBar(searchBox)
    connectionService:Connect(searchBox.Focused, function()
        self:setShown(false)
    end)
    connectionService:Connect(searchBox.FocusLost, function()
        self:setShown(self.isOpen)
    end)
end

return settings
