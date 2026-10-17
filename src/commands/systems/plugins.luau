local executorEnv = require('../../framework/environment/executor')
local storageConfig = require('../../framework/config/storage')
local pluginsData = require('../../storage/data/plugins')
local plugins = {}
local EXTENSION = '.luau'
local FOLDER = `{storageConfig.privateFolder}/plugins`

plugins.FOLDER = FOLDER

local loaded = {}
local lastErrors = {}

local function removeFromArray(array, value)
    local index = table.find(array, value)

    if index then
        table.remove(array, index)
    end
end
local function normalizeName(text)
    local name = text

    if name:sub(-#EXTENSION) == EXTENSION then
        name = name:sub(1, -#EXTENSION - 1)
    end
    if name:match('^[%w_%-]+$') then
        return name
    end

    return nil
end
local function filePath(name)
    return `{FOLDER}/{name}{EXTENSION}`
end
local function readSource(name)
    if executorEnv.readfile == nil or executorEnv.isfile == nil then
        return nil, 'your exploit does not support readfile'
    end

    local path = filePath(name)
    local existsSuccess, exists = pcall(executorEnv.isfile, path)

    if not (existsSuccess and exists) then
        return nil, `file not found: {path}`
    end

    local readSuccess, content = pcall(executorEnv.readfile, path)

    if not (readSuccess and type(content) == 'string') then
        return nil, `could not read {path}`
    end

    return content
end
local function compile(source)
    if executorEnv.loadstring == nil then
        return nil, 'your exploit does not support loadstring'
    end

    local loadSuccess, chunk, compileError = pcall(executorEnv.loadstring, source)

    if not loadSuccess then
        return nil, tostring(chunk)
    end
    if not chunk then
        return nil, tostring(compileError)
    end

    local runSuccess, result = pcall(chunk)

    if not runSuccess then
        return nil, `error while loading the plugin: {result}`
    end
    if type(result) ~= 'table' then
        return nil, 'the plugin must return a table of commands'
    end

    return result
end
local function prepare(result)
    local entries = result

    if type(result.action) == 'string' then
        entries = {result}
    end

    local prepared = {}

    for _, source in entries do
        if type(source) ~= 'table' or type(source.action) ~= 'string' then
            return nil, 'every command needs an action string'
        end
        if source.run ~= nil and type(source.run) ~= 'function' then
            return nil, `run of '{source.action}' must be a function`
        end

        local names = {}

        for _, text in source.action:split('|')do
            local name = text:lower()

            if name == '' then
                return nil, `empty name in '{source.action}'`
            end

            table.insert(names, name)
        end

        local entry = {}

        for key, value in source do
            entry[key] = value
        end

        local args = entry.args or {}

        if #args == 0 and next(args) then
            args = {args}
        end

        entry.args = args

        local aliases = table.clone(names)

        table.sort(aliases, function(a, b)
            return #a < #b
        end)

        entry.name = names[1]
        entry.aliases = aliases
        entry.action = nil

        table.insert(prepared, {
            entry = entry,
            names = names,
        })
    end

    if #prepared == 0 then
        return nil, 'the plugin has no commands'
    end

    return prepared
end
local function loadFromFile(list, name)
    local source, readError = readSource(name)

    if not source then
        return false, readError
    end

    local result, compileError = compile(source)

    if not result then
        return false, compileError
    end

    local prepared, checkError = prepare(result)

    if not prepared then
        return false, checkError
    end

    local keys = {}
    local taken = {}

    for _, item in prepared do
        for _, key in item.names do
            if list.lookup[key] ~= nil or taken[key] then
                return false, `'{key}' is already a command or an alias`
            end

            taken[key] = true

            table.insert(keys, key)
        end
    end
    for _, item in prepared do
        for _, key in item.names do
            list.lookup[key] = item.entry

            table.insert(list.array, key)
        end
    end

    loaded[name] = {
        keys = keys,
        commands = #prepared,
    }

    return true, #prepared
end
local function loadInto(list, name)
    local success, detail = loadFromFile(list, name)

    lastErrors[name] = if success then nil else tostring(detail)

    return success, detail
end
local function unloadFrom(list, name)
    local record = loaded[name]

    if not record then
        return
    end

    for _, key in record.keys do
        list.lookup[key] = nil

        removeFromArray(list.array, key)
    end

    loaded[name] = nil
end

function plugins.add(list, text)
    local name = normalizeName(text)

    if not name then
        return false, "plugin names can only use letters, numbers, '_' and '-'"
    end
    if loaded[name] then
        return false, `'{name}' is already loaded`
    end

    local success, detail = loadInto(list, name)

    if not success then
        return false, detail
    end

    pluginsData.object[name] = name .. EXTENSION

    pluginsData:save()

    return true, detail
end
function plugins.remove(list, name)
    if pluginsData.object[name] == nil and loaded[name] == nil then
        return false
    end

    unloadFrom(list, name)

    lastErrors[name] = nil
    pluginsData.object[name] = nil

    pluginsData:save()

    return true
end
function plugins.reload(list, name)
    if pluginsData.object[name] == nil then
        return false, `'{name}' is not installed`
    end

    unloadFrom(list, name)

    return loadInto(list, name)
end
function plugins.restore(list)
    local failures = {}

    for name in pluginsData.object do
        if not loaded[name] then
            local success, detail = loadInto(list, name)

            if not success then
                failures[name] = tostring(detail)
            end
        end
    end

    return failures
end
function plugins.addAll(list)
    if executorEnv.listfiles == nil then
        return nil, 'your exploit does not support listfiles'
    end

    local success, paths = pcall(executorEnv.listfiles, FOLDER)

    if not (success and type(paths) == 'table') then
        return nil, `could not read the folder {FOLDER} (create it and put your .luau plugins there)`
    end

    local result = {
        added = {},
        failed = {},
    }

    for _, path in paths do
        local name = type(path) == 'string' and path:match('([^/\\]+)%.luau$')

        if name and not loaded[name] then
            local addSuccess, detail = plugins.add(list, name)

            if addSuccess then
                table.insert(result.added, name)
            else
                table.insert(result.failed, `{name}: {detail}`)
            end
        end
    end

    return result
end
function plugins.getInstalled()
    local installed = {}

    for name in pluginsData.object do
        local record = loaded[name]

        table.insert(installed, {
            name = name,
            loaded = record ~= nil,
            commands = if record then record.commands else 0,
            error = if record then nil else lastErrors[name],
        })
    end

    table.sort(installed, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return installed
end
function plugins.getAvailable()
    if executorEnv.listfiles == nil then
        return nil, 'your exploit does not support listfiles'
    end

    local success, paths = pcall(executorEnv.listfiles, FOLDER)

    if not (success and type(paths) == 'table') then
        return nil, `could not read the folder {FOLDER} (create it and put your .luau plugins there)`
    end

    local names = {}

    for _, path in paths do
        local name = type(path) == 'string' and path:match('([^/\\]+)%.luau$')

        if name and normalizeName(name) and pluginsData.object[name] == nil then
            table.insert(names, name)
        end
    end

    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)

    return names
end

return plugins
