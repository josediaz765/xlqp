local LUA_KEYWORDS = {
    ['and'] = true,
    ['break'] = true,
    ['do'] = true,
    ['else'] = true,
    ['elseif'] = true,
    ['end'] = true,
    ['false'] = true,
    ['for'] = true,
    ['function'] = true,
    ['if'] = true,
    ['in'] = true,
    ['local'] = true,
    ['nil'] = true,
    ['not'] = true,
    ['or'] = true,
    ['repeat'] = true,
    ['return'] = true,
    ['then'] = true,
    ['true'] = true,
    ['until'] = true,
    ['while'] = true,
}

local function escapeString(text)
    local escaped = text:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')

    return escaped
end
local function indexFor(name)
    if string.match(name, '^[%a_][%w_]*$') and not LUA_KEYWORDS[name] then
        return '.' .. name
    end

    return '["' .. escapeString(name) .. '"]'
end
local function rootFor(top)
    local isService = pcall(game.GetService, game, top.ClassName)

    if isService then
        return `game:GetService("{top.ClassName}")`
    end

    return 'game' .. indexFor(top.Name)
end
local function getHierarchy(instance)
    if not instance then
        return ''
    end

    local chain = {}
    local node = instance

    while node and node ~= game do
        table.insert(chain, 1, node)

        node = node.Parent
    end

    if node ~= game then
        return instance:GetFullName()
    end
    if #chain == 0 then
        return 'game'
    end

    local path = rootFor(chain[1])

    for index = 2, #chain do
        path = path .. indexFor(chain[index].Name)
    end

    return path
end

return getHierarchy
