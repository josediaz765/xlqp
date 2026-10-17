local eventBindsConfig = require('../../framework/config/services/eventBinds')
local eventBindsData = require('../../storage/data/eventBinds')
local commandRunner = require('./commandRunner')
local commandsController = require('../controllers/commandsController')
local resolvePlayers = require('./resolvePlayers')
local ANY = eventBindsConfig.ANY
local eventBinds = {}

eventBinds.events = eventBindsConfig.events

local eventsByName = {}

for _, event in eventBindsConfig.events do
    eventsByName[event.name] = event
end

local function trim(text)
    return text:match('^%s*(.-)%s*$') or ''
end

function eventBinds.getEvent(name)
    return eventsByName[name]
end
function eventBinds.getBinds(eventName)
    local binds = eventBindsData.object[eventName]

    if type(binds) ~= 'table' then
        return {}
    end

    return table.clone(binds)
end

local function normalizeCondition(condition, text)
    local value = trim(text or '')

    if value == '' then
        value = condition.default
    end
    if value:lower() == ANY then
        return ANY
    end
    if condition.kind == 'Number' and tonumber(value) == nil then
        return nil, `{condition.label} must be a number or any`
    end

    return value
end

function eventBinds.add(eventName, command, delay, conditions)
    local event = eventsByName[eventName]

    if not event then
        return false, 'invalid event'
    end

    local text = trim(command)
    local valid, reason = commandRunner.checkText(text)

    if not valid then
        return false, reason
    end
    if type(delay) ~= 'number' or delay < 0 then
        return false, 'the delay must be 0 or more'
    end

    local saved = {}

    for index, condition in event.conditions do
        local value, problem = normalizeCondition(condition, conditions and conditions[index])

        if not value then
            return false, problem
        end

        saved[index] = value
    end

    local binds = eventBindsData.object[eventName]

    if type(binds) ~= 'table' then
        binds = {}
        eventBindsData.object[eventName] = binds
    end

    table.insert(binds, {
        command = text,
        delay = delay,
        conditions = saved,
    })
    eventBindsData:save()

    return true
end
function eventBinds.remove(eventName, index)
    local binds = eventBindsData.object[eventName]

    if type(binds) ~= 'table' or binds[index] == nil then
        return nil
    end

    local removed = table.remove(binds, index)

    eventBindsData:save()

    return removed
end
function eventBinds.restore(eventName, index, bind)
    if not eventsByName[eventName] or type(bind) ~= 'table' then
        return false
    end

    local binds = eventBindsData.object[eventName]

    if type(binds) ~= 'table' then
        binds = {}
        eventBindsData.object[eventName] = binds
    end

    table.insert(binds, math.clamp(index, 1, #binds + 1), bind)
    eventBindsData:save()

    return true
end
function eventBinds.setDelay(eventName, index, delay)
    local binds = eventBindsData.object[eventName]

    if type(binds) ~= 'table' or type(binds[index]) ~= 'table' then
        return false
    end
    if type(delay) ~= 'number' or delay < 0 then
        return false
    end

    binds[index].delay = delay

    eventBindsData:save()

    return true
end

local function isPlayerMatch(filter, name)
    local success, players = pcall(resolvePlayers, filter)

    if not success then
        return false
    end

    for _, player in players do
        if player.Name == name then
            return true
        end
    end

    return false
end
local function conditionMet(condition, filter, value)
    if filter:lower() == ANY then
        return true
    end
    if condition.kind == 'Player' then
        return isPlayerMatch(filter, tostring(value))
    end
    if condition.kind == 'String' then
        return tostring(value):lower():find(filter:lower(), 1, true) ~= nil
    end
    if condition.kind == 'Number' then
        local limit, number = tonumber(filter), tonumber(value)

        return limit ~= nil and number ~= nil and number <= limit
    end

    return false
end
local function matches(event, bind, values)
    local saved = bind.conditions or {}

    for index, condition in event.conditions do
        local filter = tostring(saved[index] or condition.default)

        if not conditionMet(condition, filter, values[index]) then
            return false
        end
    end

    return true
end
local function quote(text)
    if text:match('^[%w_%-%.]+$') then
        return text
    end

    return '"' .. (text:gsub('"', '\\"')) .. '"'
end
local function substitute(command, values)
    return (command:gsub('%$(%d+)', function(digits)
        local value = values[tonumber(digits)]

        if value == nil then
            return nil
        end

        return quote(tostring(value))
    end))
end
local function runBind(bind, values)
    local delay = bind.delay or 0

    if delay > 0 then
        task.wait(delay)
    end

    local command = substitute(bind.command, values)
    local success, reason = commandRunner.runText(command)

    if not success then
        commandsController:notify('Event Bind', `'{command}' did not run: {reason}`)
    end
end

function eventBinds.fire(eventName, ...)
    local event = eventsByName[eventName]
    local binds = eventBindsData.object[eventName]

    if not event or type(binds) ~= 'table' then
        return
    end

    local values = {...}

    for _, bind in table.clone(binds)do
        if type(bind) == 'table' and matches(event, bind, values) then
            task.spawn(runBind, bind, values)
        end
    end
end

return eventBinds
