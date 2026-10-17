local logger = require('../utils/logger')

local function createCommands(commandsInfo)
    local cmdsInfo = {}
    local lookup = {}
    local array = {}

    local function newCommand(command)
        logger:expect(command.action, {
            'string',
        }, 'command action')
        table.insert(cmdsInfo, command)

        local aliases = {}
        local args = command.args or {}

        command.args = args

        for _, text in command.action:split('|')do
            if not command.name then
                command.name = text
            end

            lookup[text] = command

            table.insert(aliases, text)
            table.insert(array, text)
        end

        table.sort(aliases, function(aliasA, aliasB)
            return #aliasA < #aliasB
        end)

        if #args == 0 and next(args) then
            command.args = {args}
        end

        command.aliases = aliases
        command.action = nil
    end

    for _, section in commandsInfo do
        logger:expect(section.name, {
            'string',
        }, 'section name')
        logger:expect(section.commands, {
            'table',
        }, 'section commands')
        table.insert(cmdsInfo, {
            isSection = true,
            sectionName = section.name,
        })

        for _, command in section.commands do
            if #command == 0 then
                logger:assert(next(command), 'the command cannot be empty')
                newCommand(command)

                continue
            end

            for key = 1, #command do
                newCommand(command[key])
            end
        end
    end

    return {
        array = array,
        lookup = lookup,
        original = cmdsInfo,
    }
end

return createCommands({
    {
        name = 'general',
        commands = require('./cmds/general'),
    },
    {
        name = 'interface',
        commands = require('./cmds/interface'),
    },
    {
        name = 'character',
        commands = require('./cmds/character'),
    },
    {
        name = 'waypoints',
        commands = require('./cmds/waypoints'),
    },
    {
        name = 'teleport',
        commands = require('./cmds/teleport'),
    },
    {
        name = 'communication',
        commands = require('./cmds/communication'),
    },
    {
        name = 'visual',
        commands = require('./cmds/visual'),
    },
    {
        name = 'camera',
        commands = require('./cmds/camera'),
    },
    {
        name = 'workspace',
        commands = require('./cmds/workspace'),
    },
    {
        name = 'lighting',
        commands = require('./cmds/lighting'),
    },
    {
        name = 'aliases',
        commands = require('./cmds/aliases'),
    },
    {
        name = 'plugins',
        commands = require('./cmds/plugins'),
    },
})
