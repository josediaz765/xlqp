local robloxServices = require('./rbxServices')
local connectionService = require('./connectionService')
local settingsData = require('../../storage/data/settings')
local keybindsConfig = require('../config/services/keybinds')
local keysToText = require('../config/utils/keysToText')
local userInputService = robloxServices.UserInputService
local keyboardService = {}
local listeners = {}
local capturing = nil
local isConnected = false

local function keyCodeFromName(name)
    if type(name) ~= 'string' then
        return nil
    end

    local ok, keyCode = pcall(function()
        return Enum.KeyCode[name]
    end)

    return if ok then keyCode else nil
end
local function bindingConfig(name)
    local config = keybindsConfig.bindings[name]

    assert(config, `keyboardService: there is no binding named '{name}'`)

    return config
end
local function bindingKey(name)
    local config = bindingConfig(name)

    return keyCodeFromName(settingsData:getValue(config.settingKey)) or keyCodeFromName(config.default) or Enum.KeyCode.Unknown
end
local function bindingKeys(name)
    local config = bindingConfig(name)
    local keys = {
        bindingKey(name),
    }

    for _, fixedName in config.also or {}do
        local fixed = keyCodeFromName(fixedName)

        if fixed then
            table.insert(keys, fixed)
        end
    end

    return keys
end
local function onInputBegan(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyCode = input.KeyCode

    if keyCode == Enum.KeyCode.Unknown then
        return
    end
    if capturing then
        local request = capturing

        capturing = nil

        if keyCode == Enum.KeyCode.Escape then
            if request.onCancel then
                request.onCancel()
            end
        else
            request.onKey(keyCode)
        end

        return
    end
    for _, listener in table.clone(listeners)do
        if listener.connected and (not processed or listener.allowProcessed) and table.find(listener.getKeys(), keyCode) then
            listener.callback(input)
        end
    end
end
local function ensureConnected()
    if isConnected then
        return
    end

    isConnected = true

    connectionService:Connect(userInputService.InputBegan, onInputBegan)
end
local function addListener(getKeys, callback, allowProcessed)
    ensureConnected()

    local listener = {
        getKeys = getKeys,
        callback = callback,
        connected = true,
        allowProcessed = allowProcessed == true,
    }

    table.insert(listeners, listener)

    local connection = {}

    function connection:Disconnect()
        listener.connected = false

        local index = table.find(listeners, listener)

        if index then
            table.remove(listeners, index)
        end
    end

    return connection
end

function keyboardService:onKeysPressed(keys, callback)
    return addListener(function()
        return keys
    end, callback)
end
function keyboardService:onBindingPressed(name, callback, allowProcessed)
    bindingConfig(name)

    return addListener(function()
        return bindingKeys(name)
    end, callback, allowProcessed)
end
function keyboardService:capture(onKey, onCancel)
    ensureConnected()

    local request = {
        onKey = onKey,
        onCancel = onCancel,
    }

    capturing = request

    return function()
        if capturing == request then
            capturing = nil
        end
    end
end
function keyboardService:getBinding(name)
    return bindingKey(name)
end
function keyboardService:setBinding(name, keyCode)
    local config = bindingConfig(name)

    assert(typeof(keyCode) == 'EnumItem' and keyCode.EnumType == Enum.KeyCode, 'keyboardService: setBinding needs a KeyCode')
    settingsData:setValue(config.settingKey, keyCode.Name)
    settingsData:save()
end
function keyboardService:resetBinding(name)
    local config = bindingConfig(name)

    settingsData:setValue(config.settingKey, nil)
    settingsData:save()
end
function keyboardService:getKeyName(keyCode)
    return keysToText[keyCode] or keyCode.Name
end
function keyboardService:getBindingName(name)
    return self:getKeyName(bindingKey(name))
end

return keyboardService
