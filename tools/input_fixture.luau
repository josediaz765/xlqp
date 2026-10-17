local SOURCES = ...
local function signal()
    local event = {listeners = {}, waiting = {}}
    function event:Connect(callback)
        local connection = {Connected = true}
        function connection:Disconnect() self.Connected = false end
        self.listeners[#self.listeners + 1] = {connection, callback}
        return connection
    end
    function event:Wait()
        self.waiting[#self.waiting + 1] = coroutine.running()
        return coroutine.yield()
    end
    function event:Fire(...)
        local waiting = self.waiting
        self.waiting = {}
        for _, thread in waiting do
            local ok, err = coroutine.resume(thread, ...)
            assert(ok, err)
        end
        for _, entry in table.clone(self.listeners) do
            if entry[1].Connected then entry[2](...) end
        end
    end
    return event
end

local Enum = setmetatable({}, {__index = function(self, category)
    local namespace
    namespace = setmetatable({}, {__index = function(values, name)
        local value = {Name = name, EnumType = namespace, kind = 'EnumItem'}
        rawset(values, name, value)
        return value
    end})
    rawset(self, category, namespace)
    return namespace
end})
local function dimension(x, y) return {Scale = x, Offset = y} end
local UDim2 = {}
function UDim2.new(x, a, y, b) return {X = dimension(x, a), Y = dimension(y, b)} end
function UDim2.fromScale(x, y) return UDim2.new(x, 0, y, 0) end
function UDim2.fromOffset(x, y) return UDim2.new(0, x, 0, y) end
local Vector2 = {new = function(x, y) return {X = x, Y = y} end}
local Color3 = {}
function Color3.fromRGB(r, g, b) return {R = r / 255, G = g / 255, B = b / 255, kind = 'Color3'} end
function Color3.new(r, g, b) return {R = r, G = g, B = b, kind = 'Color3'} end

local function check(mobile)
    local focused
    local deferred = {}
    local services = {
        UserInputService = {InputBegan = signal(), InputEnded = signal(), InputChanged = signal()},
        RunService = {Heartbeat = signal(), RenderStepped = signal(), Stepped = signal()},
    }
    function services.UserInputService:GetFocusedTextBox() return focused end
    local task = {}
    function task.spawn(callback)
        local thread = coroutine.create(callback)
        local ok, err = coroutine.resume(thread)
        assert(ok, err)
        return thread
    end
    function task.defer(callback) deferred[#deferred + 1] = callback end
    task.delay = function(_, callback) task.defer(callback) end
    local function flush()
        for _ = 1, 3 do
            services.RunService.RenderStepped:Fire()
            services.RunService.Heartbeat:Fire()
            local pending = deferred
            deferred = {}
            for _, callback in pending do task.spawn(callback) end
        end
    end
    local methods = {}
    local eventNames = {Focused = true, FocusLost = true, Activated = true, InputBegan = true, InputEnded = true, MouseEnter = true, MouseLeave = true}
    local function object(class)
        local props = {
            ClassName = class, Name = class, Active = true, Interactable = true, TextEditable = true,
            Text = '', TextSize = 14, TextTransparency = 0, Visible = true,
            Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(250, 18),
            AbsoluteSize = Vector2.new(250, 18), AbsolutePosition = Vector2.new(0, 0),
            AnchorPoint = Vector2.new(0, 0), children = {}, events = {},
        }
        local item = {_instance = true, _props = props}
        return setmetatable(item, {
            __index = function(_, key)
                if methods[key] then return methods[key] end
                if props[key] ~= nil then return props[key] end
                if eventNames[key] then
                    props.events[key] = props.events[key] or signal()
                    return props.events[key]
                end
                return props.children[key]
            end,
            __newindex = function(self, key, value)
                local previous = props[key]
                props[key] = value
                if key == 'Parent' then
                    if previous then previous._props.children[props.Name] = nil end
                    if value then value._props.children[props.Name] = self end
                end
                if previous ~= value and props.events['changed:' .. key] then
                    props.events['changed:' .. key]:Fire()
                end
            end,
        })
    end
    function methods:GetPropertyChangedSignal(key)
        self._props.events['changed:' .. key] = self._props.events['changed:' .. key] or signal()
        return self._props.events['changed:' .. key]
    end
    function methods:IsA(class) return self.ClassName == class or (class == 'GuiButton' and self.ClassName:find('Button') ~= nil) end
    function methods:IsFocused() return focused == self end
    function methods:CaptureFocus()
        if not self.Parent or not self.Active or not self.Interactable or not self.TextEditable then return end
        if self.Size.Y.Scale == 0 and self.Size.Y.Offset == 0 then return end
        if focused == self then return end
        if focused then focused:ReleaseFocus() end
        focused = self
        self.Focused:Fire()
    end
    function methods:ReleaseFocus(enterPressed)
        if focused ~= self then return end
        focused = nil
        self.FocusLost:Fire(enterPressed == true)
    end
    local create = {}
    function create.new(class, ...)
        local result = object(class)
        for _, arg in {...} do
            if type(arg) == 'string' then result.Name = arg
            elseif arg._instance then result.Parent = arg
            else
                for key, value in arg do
                    if type(key) == 'number' then value.Parent = result else result[key] = value end
                end
            end
        end
        return result
    end
    services.TweenService = {Create = function(_, target, _, values)
        return {Cancel = function() end, Play = function()
            for key, value in values do target[key] = value end
        end}
    end}
    local settings = {values = {}}
    function settings:getValue(key) return self.values[key] end
    function settings:setValue(key, value) self.values[key] = value end
    function settings:save() end
    local connections = {}
    function connections:Connect(event, callback) return event:Connect(callback) end
    function connections:disconnect(connection) if connection then connection:Disconnect() end end
    local inputUtils = {isPressingInput = function(input)
        return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
    end}
    local dependencies = {
        rbxServices = services, connectionService = connections, settings = settings, create = create,
    }
    local function load(key, requireFn)
        local chunk = assert(loadstring(assert(SOURCES[key], key), key))
        setfenv(chunk, setmetatable({
            require = requireFn, Enum = Enum, UDim2 = UDim2, UDim = {new = dimension}, Vector2 = Vector2,
            Color3 = Color3, TweenInfo = {new = function(...) return {...} end}, task = task,
            tick = os.clock, typeof = function(value) return type(value) == 'table' and value.kind or type(value) end,
        }, {__index = getfenv()}))
        return chunk()
    end
    local colors = load('colors', function() error('Unexpected palette dependency') end)
    local keyConfig = load('keys', function() error('Unexpected key config dependency') end)
    local sharedRequire
    sharedRequire = function(path)
        if path:find('connectionService', 1, true) then return connections end
        if path:find('rbxServices', 1, true) then return services end
        if path:find('playerService', 1, true) then return {isMouseInGuiObject = function() return false end} end
        if path:find('dragInstance', 1, true) then return {addGuiObject = function() end} end
        if path:find('keyboardService', 1, true) then return dependencies.keyboard end
        if path:find('data/settings', 1, true) then return settings end
        if path:find('config/services/keybinds', 1, true) then return keyConfig end
        if path:find('keysToText', 1, true) then return {} end
        if path:find('config/ui/colors', 1, true) then return colors end
        if path:find('createService', 1, true) then return create end
        if path:find('assetsService', 1, true) then return {loadImage = function() end} end
        if path:find('commands/list', 1, true) then return {lookup = {}, original = {}} end
        if path:find('commandParser', 1, true) then return {new = function() return {} end} end
        if path:find('isMobile', 1, true) then return mobile end
        if path:find('inputUtils', 1, true) then return inputUtils end
        if path:find('utils/signal', 1, true) then return {new = signal} end
        if path:find('scaleObject', 1, true) then return {getScale = function() return 1 end, uiScale = object('UIScale')} end
        if path:find('utils/tools', 1, true) then return {richFontSize = function() end, colorFromRGB = function() end, randomString = function() return 'XLQP-control' end} end
        return {}
    end
    dependencies.keyboard = load('keyboard', sharedRequire)
    local Commands = load('commands', sharedRequire)
    local screen = object('ScreenGui')
    local frame = object('Frame')
    local scroll = object('Frame')
    scroll.Parent = frame
    local cmd = Commands.new({
        scrollContainer = object('Frame'), scrolledSignal = signal(), scrollHolder = scroll, screenGui = screen,
        scrollBar = {
            index = 0, totalSpace = 0, visibleSpace = 20,
            setLocked = function() end,
            setTotalSpace = function(self, count) self.totalSpace = count end,
            setVisibleSpace = function(self, count) self.visibleSpace = count end,
            scrollTo = function(self, index) self.index = math.clamp(index, 0, math.max(0, self.totalSpace - self.visibleSpace)) end,
            isVisible = function(self, position) return position >= self.index and position < self.index + self.visibleSpace end,
        },
        configs = {placeholderText = '>_ command', padding = 0, labelSize = 17, textSize = 17},
    })
    cmd.update = function() end
    cmd.refresh = function(self, text)
        self.commandInput.rawText = text
        self.commandInput.highlightText = text
        self:updateSearchBoxHighlight()
    end
    cmd.sendInputCommand = function(self) self.sent = (self.sent or 0) + 1 end
    cmd:create()
    local box = cmd.searchBox
    assert(box.Interactable and box.TextEditable and box.Active, 'Native command textbox is disabled')
    assert(box.ShowNativeInput == true and box.TextSize > 0 and not box.MultiLine, 'Mobile/native input is not configured')
    cmd:awake()
    cmd:enable()
    if SOURCES.case == 'filter' then
        cmd.commandsData = {
            {isSection = true, sectionName = 'general', args = {}, position = 0},
            {name = 'explorer', aliases = {'explorer', 'dex'}, args = {}, position = 1},
            {name = 'fly', aliases = {'fly'}, args = {}, position = 2},
            {name = 'moondex', aliases = {'moondex', 'mdex'}, args = {}, position = 3},
            {name = 'plugin[dex]', aliases = {'plugin[dex]'}, args = {}, position = 4},
        }
        cmd.scrollContainer.AbsoluteSize = Vector2.new(250, 340)
        cmd.update = Commands.update
        cmd.refresh = Commands.refresh
        cmd.updateDisplayName = function() end
        cmd.parser = {
            parse = function(_, text)
                cmd.commandInput.commandName = text:match('^%s*([^%s]+)') or ''
                return {}
            end,
            highlight = function() end,
        }
        cmd:update()
        cmd:writeText('dex')
        assert(cmd.filteredData and #cmd.filteredData == 3, 'Typing dex does not filter unrelated command rows')
        assert(#cmd.visibleCommands == 3 and cmd.scrollBar.totalSpace == 3, 'Filtered list has stale visible rows or scroll bounds')
        assert(cmd.commandsData[3].element == nil or cmd.commandsData[3].element.Parent == nil, 'Unrelated fly row remains visible')
        cmd:writeText('DEX me')
        assert(#cmd.filteredData == 3, 'Case-insensitive filtering/command arguments changed results')
        cmd:writeText('explorer')
        assert(#cmd.visibleCommands == 1 and cmd.visibleCommands[1].name == 'explorer', 'Alias/main-name filtering failed')
        cmd:writeText('[dex]')
        assert(#cmd.visibleCommands == 1 and cmd.visibleCommands[1].name == 'plugin[dex]', 'Search treats punctuation as a pattern')
        cmd:writeText('no-command-matches-this')
        assert(#cmd.visibleCommands == 0 and cmd.scrollBar.totalSpace == 0, 'No-match query leaves unrelated commands')
        box.Text = ''
        assert(#cmd.filteredData == 5 and #cmd.visibleCommands == 4, 'Deleting text does not immediately restore rows')
        assert(cmd.commandsData[1].element.Parent == cmd.commandsFolder, 'Clearing search does not restore sections')
        cmd:writeText('dex')
        cmd.scrollBar.visibleSpace = 1
        cmd.scrollBar:scrollTo(1)
        cmd:updateElements()
        assert(#cmd.visibleCommands == 1 and cmd.visibleCommands[1].name == 'moondex', 'Filtered scrolling uses original positions')
        print('PASS: ' .. (if mobile then 'mobile' else 'keyboard') .. ' live command filtering, aliases, literal text, empty results, clear/reset, filtered scrolling')
        return
    end
    assert(box.Parent == cmd.searchBoxHolder and box.Size.Y.Scale == 1, 'Textbox does not cover the visible command bar')
    cmd.searchBoxHolder.Activated:Fire()
    flush()
    assert(box:IsFocused() and box.TextTransparency == 0, 'Click/touch does not expose native typed text')
    box.Text = 'fly 10'
    assert(cmd.commandInput.rawText == 'fly 10', 'Native keyboard text did not reach parser')
    assert(not cmd.searchBoxHolder.Input.Visible and not cmd.inputMarker.Visible, 'Fake text/caret obscures native editing')
    box:ReleaseFocus(true)
    assert(cmd.sent == 1, 'Enter did not submit')
    assert(cmd.searchBoxHolder.Input.Visible, 'Syntax highlight not restored on blur')
    cmd:setInteractive(false)
    cmd:ensureFocus()
    flush()
    assert(not box:IsFocused() and not box.TextEditable, 'Minimized textbox can steal focus')
    cmd:setInteractive(true)
    cmd.searchBoxHolder.Activated:Fire()
    flush()
    cmd:writeText('fl')
    cmd.commandInput.correction = {from = 1, to = 2, text = 'fly'}
    services.UserInputService.InputBegan:Fire({KeyCode = Enum.KeyCode.Tab}, true)
    assert(box.Text == 'fly' and box.CursorPosition == 4, 'Tab correction lost text/caret')
    cmd.commandInput.correction = nil
    cmd.sendButton.Activated:Fire()
    assert(cmd.sent == 2, 'Tap send did not submit')
    local ui = load('interface', sharedRequire)
    ui.screenGui, ui.mainFrame, ui.topBar, ui.commands = screen, frame, object('Frame'), cmd
    ui.updateNotificationsPosition = function() end
    ui.dock = {
        state = 'minimized',
        reveal = function(self) self.state = 'expanded'; cmd:setInteractive(true) end,
        cancel = function() end,
        moveTo = function(self, state, duration) assert(duration == 0); self.state = state; cmd:setInteractive(state ~= 'minimized') end,
        onSettled = function() end,
        addWindowPart = function() end,
    }
    ui:setupListeners()
    assert(ui.prefixConnection, 'Prefix binding is not registered')
    frame.Visible = false
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Semicolon}, false)
    flush()
    assert(frame.Visible and box:IsFocused(), 'Semicolon did not reveal/focus command input')
    box:ReleaseFocus()
    frame.Visible = false
    ui.dock.state = 'minimized'
    cmd:setInteractive(false)
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Semicolon}, true)
    flush()
    assert(frame.Visible and box:IsFocused() and box.CursorPosition == #box.Text + 1, 'Processed prefix does not focus editable textbox/caret')
    local unrelatedKeyCalls = 0
    dependencies.keyboard:onKeysPressed({Enum.KeyCode.F}, function() unrelatedKeyCalls += 1 end)
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.F}, true)
    assert(unrelatedKeyCalls == 0, 'Processed input incorrectly triggers unrelated keybinds')
    box:ReleaseFocus()
    frame.Visible = false
    local other = object('TextBox'); other.Parent = screen; other:CaptureFocus()
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Semicolon}, false)
    flush()
    assert(other:IsFocused() and not frame.Visible, 'Prefix steals another textbox focus')
    other:ReleaseFocus()
    settings.values['keybinds.prefix'] = 'Quote'
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Semicolon}, false)
    flush()
    assert(not frame.Visible, 'Saved prefix rebind ignored')
    services.UserInputService.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Quote}, false)
    flush()
    assert(frame.Visible and box:IsFocused(), 'Rebound prefix cannot open textbox')
    if mobile then
        box:ReleaseFocus()
        ui:createQuickCapture()
        ui.quickCapture.Activated:Fire()
        flush()
        assert(box:IsFocused(), 'Mobile XLQP button cannot focus input')
    end
    local allowed = {[colors.text.red] = true, [colors.text.purple] = true, [colors.text.green] = true}
    for _, color in colors.args do assert(allowed[color], 'Syntax color outside palette') end
    for _, color in colors.commands do assert(allowed[color], 'Command color outside palette') end
    for _, themeName in {'dark', 'light', 'classic'} do
        local theme = load(themeName, sharedRequire)
        for _, color in theme.Colors.Text do assert(allowed[color], 'Theme text outside palette') end
        assert(allowed[theme.Colors.Slider.SliderNumber] and allowed[theme.Colors.Error])
    end
    local nameColor = load('nameColor', sharedRequire)
    assert(allowed[nameColor.forPlayer({Name = 'TeamMember', Team = {TeamColor = {Color = Color3.new(0, 0, 1)}}})])
    local dragClass = load('drag', sharedRequire)
    local drag = dragClass.new(nil)
    local dragged
    drag._startPress = function(_, target) dragged = target end
    local bar = object('Frame')
    drag:addGuiObject(frame, bar)
    frame.InputBegan:Fire({UserInputType = Enum.UserInputType.Touch})
    assert(dragged == nil, 'Textbox/body press starts window dragging')
    bar.InputBegan:Fire({UserInputType = Enum.UserInputType.Touch})
    assert(dragged == frame, 'Title-bar drag lost target window')
    print('PASS: ' .. (if mobile then 'mobile' else 'keyboard') .. ' input, semicolon/rebind, native text, Tab, Enter/send, focus isolation, red/purple/green text')
end
check(false)
check(true)
