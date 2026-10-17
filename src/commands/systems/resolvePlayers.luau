local robloxServices = require('../../framework/services/rbxServices')
local playerService = require('../../framework/services/playerService')
local localPlayer = require('../../framework/services/localPlayer')

local function shuffle(list)
    for index = #list, 2, -1 do
        local other = math.random(1, index)

        list[index], list[other] = list[other], list[index]
    end

    return list
end
local function getHumanoid(player)
    local character = player.Character

    return character and character:FindFirstChildOfClass('Humanoid')
end
local function getRoot(player)
    local character = player.Character

    return character and character:FindFirstChild('HumanoidRootPart')
end
local function isAlive(player)
    local humanoid = getHumanoid(player)

    return humanoid ~= nil and humanoid.Health > 0
end
local function distanceFromLocal(player)
    local localRoot = getRoot(localPlayer)
    local root = getRoot(player)

    if not (localRoot and root) then
        return nil
    end

    return (root.Position - localRoot.Position).Magnitude
end
local function filter(players, predicate)
    local list = {}

    for _, player in players do
        if predicate(player) then
            table.insert(list, player)
        end
    end

    return list
end
local function withoutLocal(players)
    return filter(players, function(player)
        return player ~= localPlayer
    end)
end
local function isOnMyTeam(player)
    return localPlayer.Team ~= nil and player.Team == localPlayer.Team
end
local function hasBacon(player)
    local humanoid = getHumanoid(player)

    if not humanoid then
        return false
    end

    for _, accessory in humanoid:GetAccessories()do
        local name = accessory.Name:lower()

        if name:find('bacon', 1, true) or name:find('pal hair', 1, true) then
            return true
        end
    end

    return false
end
local function byDistance(players, farthest)
    local best = nil
    local bestDistance = nil

    for _, player in withoutLocal(players)do
        local distance = distanceFromLocal(player)

        if distance then
            local better = bestDistance == nil or (farthest and distance > bestDistance) or (not farthest and distance < bestDistance)

            if better then
                best, bestDistance = player, distance
            end
        end
    end

    if best then
        return {best}
    end

    return {}
end

local KEYWORDS = {
    me = function()
        return {localPlayer}
    end,
    all = function(players)
        return players
    end,
    others = function(players)
        return withoutLocal(players)
    end,
    random = function(players)
        if #players == 0 then
            return {}
        end

        return {
            players[math.random(1, #players)],
        }
    end,
    allies = function(players)
        return filter(players, isOnMyTeam)
    end,
    team = function(players)
        return filter(players, isOnMyTeam)
    end,
    enemies = function(players)
        return filter(withoutLocal(players), function(player)
            return not isOnMyTeam(player)
        end)
    end,
    nonteam = function(players)
        return filter(withoutLocal(players), function(player)
            return not isOnMyTeam(player)
        end)
    end,
    friends = function(players)
        return filter(withoutLocal(players), function(player)
            return localPlayer:IsFriendsWith(player.UserId)
        end)
    end,
    nonfriends = function(players)
        return filter(withoutLocal(players), function(player)
            return not localPlayer:IsFriendsWith(player.UserId)
        end)
    end,
    guests = function(players)
        return filter(players, function(player)
            return player.UserId <= 0
        end)
    end,
    bacons = function(players)
        return filter(players, hasBacon)
    end,
    alive = function(players)
        return filter(players, isAlive)
    end,
    dead = function(players)
        return filter(players, function(player)
            return not isAlive(player)
        end)
    end,
    nearest = function(players)
        return byDistance(players, false)
    end,
    farthest = function(players)
        return byDistance(players, true)
    end,
}
local PATTERNS = {
    {
        pattern = '^#(%d+)$',
        handler = function(players, captured)
            local list = shuffle(players)

            return table.move(list, 1, math.min(tonumber(captured), #list), 1, {})
        end,
    },
    {
        pattern = '^@(.+)$',
        handler = function(players, captured)
            return filter(players, function(player)
                return player.Name:lower():sub(1, #captured) == captured
            end)
        end,
    },
    {
        pattern = '^%%(.+)$',
        handler = function(players, captured)
            return filter(players, function(player)
                local team = player.Team

                return team ~= nil and team.Name:lower():sub(1, #captured) == captured
            end)
        end,
    },
    {
        pattern = '^age(%d+)$',
        handler = function(players, captured)
            local age = tonumber(captured)

            return filter(players, function(player)
                return player.AccountAge <= age
            end)
        end,
    },
    {
        pattern = '^rad(%d+)$',
        handler = function(players, captured)
            local radius = tonumber(captured)

            return filter(withoutLocal(players), function(player)
                local distance = distanceFromLocal(player)

                return distance ~= nil and distance <= radius
            end)
        end,
    },
    {
        pattern = '^group(%d+)$',
        handler = function(players, captured)
            local groupId = tonumber(captured)

            return filter(players, function(player)
                return player:IsInGroup(groupId)
            end)
        end,
    },
}

local function isSelector(text)
    local query = (text or 'me'):lower()

    if KEYWORDS[query] then
        return true
    end

    for _, entry in PATTERNS do
        if query:match(entry.pattern) then
            return true
        end
    end

    return false
end
local function trim(text)
    return text:match('^%s*(.-)%s*$')
end
local function resolveTerm(text, players)
    local query = text:lower()
    local keyword = KEYWORDS[query]

    if keyword then
        return keyword(players)
    end

    for _, entry in PATTERNS do
        local captured = query:match(entry.pattern)

        if captured then
            return entry.handler(players, captured)
        end
    end

    return playerService:getPlayersByName(text)
end
local function union(first, second)
    local seen = {}
    local list = {}

    for _, player in first do
        if not seen[player] then
            seen[player] = true

            table.insert(list, player)
        end
    end
    for _, player in second do
        if not seen[player] then
            seen[player] = true

            table.insert(list, player)
        end
    end

    return list
end
local function difference(first, second)
    local remove = {}

    for _, player in second do
        remove[player] = true
    end

    return filter(first, function(player)
        return not remove[player]
    end)
end
local function splitOperators(text)
    local items = {}
    local op = '+'
    local buffer = {}

    for index = 1, #text do
        local char = text:sub(index, index)

        if char == '+' or char == '-' then
            table.insert(items, {
                op = op,
                term = trim(table.concat(buffer)),
            })

            buffer = {}
            op = char
        else
            table.insert(buffer, char)
        end
    end

    table.insert(items, {
        op = op,
        term = trim(table.concat(buffer)),
    })

    return items
end
local function resolveChain(text, players)
    local items = splitOperators(text)
    local first = items[1]
    local result = {}

    if first.term ~= '' then
        result = resolveTerm(first.term, players)
    elseif items[2] and items[2].op == '-' then
        result = table.clone(players)
    end

    for index = 2, #items do
        local item = items[index]
        local matches = {}

        if item.term ~= '' then
            matches = resolveTerm(item.term, players)
        end
        if item.op == '+' then
            result = union(result, matches)
        else
            result = difference(result, matches)
        end
    end

    return result
end
local function parts(text)
    local list = {}

    for part in text:gmatch('[^,]+')do
        local value = trim(part)

        if value ~= '' then
            table.insert(list, value)
        end
    end

    return list
end
local function hasOperators(text)
    return text ~= nil and text:find('[,+%-]') ~= nil
end
local function resolvePlayers(text)
    local input = text or 'me'
    local players = robloxServices.Players:GetPlayers()
    local whole = resolveTerm(trim(input), players)

    if #whole > 0 then
        return whole
    end
    if not hasOperators(input) then
        return playerService:getPlayersByName(trim(input))
    end

    local result = {}

    for _, part in parts(input)do
        result = union(result, resolveChain(part, players))
    end

    return result
end

return setmetatable({
    isSelector = isSelector,
    hasOperators = hasOperators,
    parts = parts,
}, {
    __call = function(_, text)
        return resolvePlayers(text)
    end,
})
