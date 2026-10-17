local aliasesData = require('../../storage/data/aliases')
local customAliases = {}

local function removeFromArray(array, value)
    local index = table.find(array, value)

    if index then
        table.remove(array, index)
    end
end

function customAliases.add(list, alias, commandName)
    alias = alias:lower()

    if list.lookup[alias] ~= nil then
        return false, `'{alias}' is already a command or an alias`
    end

    local command = list.lookup[commandName:lower()]

    if not command then
        return false, 'invalid command'
    end

    list.lookup[alias] = command

    table.insert(list.array, alias)

    aliasesData.object[alias] = command.name

    aliasesData:save()

    return true
end
function customAliases.remove(list, alias)
    alias = alias:lower()

    local target = aliasesData.object[alias]

    if type(target) ~= 'string' then
        return false
    end

    list.lookup[alias] = nil

    removeFromArray(list.array, alias)

    aliasesData.object[alias] = nil

    aliasesData:save()

    return true, target
end
function customAliases.clear(list)
    local aliases = {}

    for alias in aliasesData.object do
        table.insert(aliases, alias)
    end
    for _, alias in aliases do
        list.lookup[alias] = nil

        removeFromArray(list.array, alias)

        aliasesData.object[alias] = nil
    end

    aliasesData:save()

    return #aliases
end
function customAliases.restore(list)
    for alias, commandName in aliasesData.object do
        local command = type(commandName) == 'string' and list.lookup[commandName]

        if command and list.lookup[alias] == nil then
            list.lookup[alias] = command

            table.insert(list.array, alias)
        end
    end
end

return customAliases
