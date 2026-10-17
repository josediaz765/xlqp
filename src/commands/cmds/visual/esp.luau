local EspManager = require('../../systems/espManager')
local resolvePlayers = require('../../systems/resolvePlayers')
local robloxServices = require('../../../framework/services/rbxServices')
local privateEnv = require('../../../framework/environment/private')
local Players = robloxServices.Players
local DEFAULT_TRANSPARENCY = 0.3
local GREEN = Color3.fromRGB(0, 255, 0)
local RED = Color3.fromRGB(255, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local PART_GREEN = Color3.fromRGB(50, 205, 50)

local function characters()
    local list = {}
    local me = Players.LocalPlayer

    for _, player in Players:GetPlayers()do
        if player ~= me and player.Character then
            table.insert(list, player.Character)
        end
    end

    return list
end
local function playerColor(character)
    local player = Players:GetPlayerFromCharacter(character)

    if player then
        return player.TeamColor.Color
    end

    return WHITE
end
local function teamColor(character)
    local player = Players:GetPlayerFromCharacter(character)

    if player and player.TeamColor == Players.LocalPlayer.TeamColor then
        return GREEN
    end

    return RED
end
local function constantColor(color)
    return function()
        return color
    end
end
local function namedParts(names)
    return function()
        local list = {}

        for _, object in workspace:GetDescendants()do
            if object:IsA('BasePart') and names[object.Name:lower()] then
                table.insert(list, object)
            end
        end

        return list
    end
end
local function espText(character, meters, studs)
    local player = Players:GetPlayerFromCharacter(character)
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local health = 0

    if humanoid then
        health = math.floor(humanoid.Health * 10 + 0.5) / 10
    end

    return ('Name: %s | Health: %g | Studs: %d'):format(player and player.Name or character.Name, health, studs)
end
local function stopManager(self, name)
    local garbage = self:collectGarbage(name)

    if garbage and garbage.manager then
        garbage.manager:destroy()
    end
end
local function startManager(self, name, options)
    stopManager(self, name)

    options.tag = name

    local manager = EspManager.new(options)
    local garbage = self:createGarbage(name)

    garbage.manager = manager

    manager:start()
end
local function startEsp(self, color)
    if self:hasGarbage('chams') then
        self:notify('ESP', 'Disable chams (nochams) before using esp')

        return
    end

    startManager(self, 'esp', {
        source = characters,
        color = color,
        showBoxes = true,
        showText = true,
    })
end

local LOCATE_PREFIX = 'locate:'

local function locateName(player)
    return LOCATE_PREFIX .. player.Name
end
local function startLocate(self, player)
    startManager(self, locateName(player), {
        source = function()
            local character = player.Character

            if character then
                return {character}
            end

            return {}
        end,
        color = playerColor,
        showBoxes = true,
        showText = true,
    })
end

return {
    {
        action = 'esp',
        description = 'View all players and their status',
        run = function(self)
            startEsp(self, playerColor)
        end,
    },
    {
        action = 'espteam',
        description = 'ESP but teammates are green and bad guys are red',
        run = function(self)
            startEsp(self, teamColor)
        end,
    },
    {
        action = 'noesp|unesp|unespteam',
        description = 'Removes ESP',
        run = function(self)
            stopManager(self, 'esp')
        end,
    },
    {
        action = 'esptransparency',
        description = 'Changes the transparency of ESP related commands',
        args = {
            kind = 'number',
        },
        run = function(self, args)
            local value = args:nextValue()

            privateEnv.espTransparency = math.clamp(value or DEFAULT_TRANSPARENCY, 0, 1)
        end,
    },
    {
        action = 'partesp',
        description = 'Highlights a part',
        args = {
            kind = 'string',
            name = 'part name',
        },
        run = function(self, args)
            local name = args:nextValue()

            if not name then
                self:notify('partesp', 'Write the name of a part')

                return
            end

            local names = privateEnv.partEspNames or {}

            privateEnv.partEspNames = names
            names[name:lower()] = true

            if not self:hasGarbage('partesp') then
                startManager(self, 'partesp', {
                    source = namedParts(names),
                    color = constantColor(PART_GREEN),
                    showBoxes = true,
                    showText = false,
                    interval = 1,
                })
            end
        end,
    },
    {
        action = 'unpartesp|nopartesp',
        description = 'removes partesp',
        args = {
            kind = 'string',
            name = 'part name',
        },
        run = function(self, args)
            local names = privateEnv.partEspNames or {}

            privateEnv.partEspNames = names

            local name = args:nextValue()

            if name then
                names[name:lower()] = nil
            else
                table.clear(names)
            end
            if next(names) == nil then
                stopManager(self, 'partesp')
            end
        end,
    },
    {
        action = 'chams',
        description = 'ESP but without text in the way',
        run = function(self)
            if self:hasGarbage('esp') then
                self:notify('Chams', 'Disable ESP (noesp) before using chams')

                return
            end

            startManager(self, 'chams', {
                source = characters,
                color = playerColor,
                showBoxes = true,
                showText = false,
            })
        end,
    },
    {
        action = 'nochams|unchams',
        description = 'Removes chams',
        run = function(self)
            stopManager(self, 'chams')
        end,
    },
    {
        action = 'locate',
        description = 'View a single player and their status',
        args = {
            kind = 'player',
        },
        run = function(self, args)
            local text = args:nextValue()

            if not text then
                return
            end

            for _, player in resolvePlayers(text)do
                if player ~= Players.LocalPlayer then
                    startLocate(self, player)
                end
            end
        end,
    },
    {
        action = 'unlocate|nolocate',
        description = 'Removes locate',
        args = {
            kind = 'player',
        },
        run = function(self, args)
            local text = args:nextValue()

            if not text then
                local names = {}

                for name in pairs(self.garbages)do
                    if name:sub(1, #LOCATE_PREFIX) == LOCATE_PREFIX then
                        table.insert(names, name)
                    end
                end
                for _, name in names do
                    stopManager(self, name)
                end

                return
            end

            local names = {}

            for _, player in resolvePlayers(text)do
                table.insert(names, locateName(player))
            end

            if not resolvePlayers.isSelector(text) then
                local wanted = text:lower()

                for name in pairs(self.garbages)do
                    if name:sub(1, #LOCATE_PREFIX) == LOCATE_PREFIX then
                        local playerName = name:sub(#LOCATE_PREFIX + 1):lower()

                        if playerName:sub(1, #wanted) == wanted then
                            table.insert(names, name)
                        end
                    end
                end
            end

            for _, name in names do
                stopManager(self, name)
            end
        end,
    },
}
