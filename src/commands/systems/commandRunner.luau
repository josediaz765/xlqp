local commandsController = require('../controllers/commandsController')
local commandParser = require('./commandParser')
local argsManager = require('./argsManager')
local loopService = require('../services/loopService')
local logger = require('../../utils/logger')
local commandRunner = {}

function commandRunner.runStatement(info)
    local name = info.commandData.name
    local argValues = info.args

    if info.repeatLast then
        argValues = commandsController:getLastArgs(name) or {}
    end
    if info.loop then
        commandRunner.startLoop(name, argValues, info.loop)

        return
    end

    commandsController:run(name, argsManager.new(argValues))
end
function commandRunner.startLoop(name, argValues, loop)
    local runs = 0
    local id

    id = loopService:add(function()
        runs += 1

        local success, failure = pcall(function()
            commandsController:run(name, argsManager.new(argValues))
        end)

        if not success then
            loopService:remove(id)
            logger:error(`loop of '{name}' stopped: {failure}`)

            return
        end
        if runs >= loop.count then
            loopService:remove(id)
        end
    end, loop.delay)
end

local function read(text)
    local cmdInput = {}
    local parser = commandParser.new(cmdInput, function() end)

    parser:highlight(parser:parse(text))

    return cmdInput.statements, cmdInput.runError
end
local function missingCommand(statements)
    for _, info in statements do
        if info.empty then
            return 'write the command to run'
        end
        if not info.commandData then
            return `'{info.commandName}' is not a command`
        end
    end

    return nil
end

function commandRunner.checkText(text)
    local statements = read(text)
    local reason = missingCommand(statements)

    if reason then
        return false, reason
    end

    return true
end
function commandRunner.runText(text)
    local statements, problem = read(text)
    local reason = missingCommand(statements)

    if reason then
        return false, reason
    end
    if problem then
        return false, (problem:gsub('^%s*%-%s*', ''))
    end

    for _, info in statements do
        local success, failure = pcall(commandRunner.runStatement, info)

        if not success then
            return false, tostring(failure)
        end
    end

    return true
end

return commandRunner
