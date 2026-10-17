local chatSender = require('../../systems/chatSender')
local resolvePlayers = require('../../systems/resolvePlayers')
local SPAM = 'spam'
local PM_PREFIX = 'pmspam:'

local function say(self, title, message)
    local success, reason = chatSender.send(message)

    if not success then
        self:notify(title, reason)
    end

    return success
end
local function stopSpam(self)
    local garbage = self:collectGarbage(SPAM)

    if garbage then
        garbage.running = false
    end
end
local function startSpam(self, message)
    stopSpam(self)

    local garbage = self:createGarbage(SPAM)

    garbage.running = true

    task.spawn(function()
        while garbage.running do
            if not say(self, 'Spam', message) then
                garbage.running = false

                break
            end

            task.wait(self.privateEnv.spamSpeed or 1)
        end

        if self:getGarbage(SPAM) == garbage then
            self:collectGarbage(SPAM)
        end
    end)
end
local function pmName(player)
    return PM_PREFIX .. player.Name
end
local function stopPmSpam(self, name)
    local garbage = self:collectGarbage(name)

    if garbage then
        garbage.running = false
    end
end
local function startPmSpam(self, player, message)
    local name = pmName(player)

    stopPmSpam(self, name)

    local garbage = self:createGarbage(name)

    garbage.running = true

    task.spawn(function()
        while garbage.running and player.Parent == self.players do
            if not say(self, 'PM Spam', `/w {player.Name} {message}`) then
                garbage.running = false

                break
            end

            task.wait(self.privateEnv.spamSpeed or 1)
        end

        if self:getGarbage(name) == garbage then
            self:collectGarbage(name)
        end
    end)
end
local function everyPmName(self)
    local names = {}

    for name in pairs(self.garbages)do
        if name:sub(1, #PM_PREFIX) == PM_PREFIX then
            table.insert(names, name)
        end
    end

    return names
end
local function pmTargets(self, text)
    local names = {}

    for _, player in resolvePlayers(text)do
        table.insert(names, pmName(player))
    end

    if not resolvePlayers.isSelector(text) then
        local wanted = text:lower()

        for _, name in everyPmName(self)do
            local playerName = name:sub(#PM_PREFIX + 1):lower()

            if playerName:sub(1, #wanted) == wanted then
                table.insert(names, name)
            end
        end
    end

    return names
end

return {
    {
        action = 'chat|say',
        description = 'Makes you chat a string (possible mute bypass)',
        args = {
            kind = 'string',
            name = 'your message',
        },
        run = function(self, args)
            local message = args:nextValue()

            if not message then
                return
            end

            say(self, 'Chat', message)
        end,
    },
    {
        action = 'spam',
        description = 'Makes you spam the chat',
        args = {
            kind = 'string',
            name = 'your message',
        },
        run = function(self, args)
            local message = args:nextValue()

            if not message then
                return
            end

            startSpam(self, message)
        end,
    },
    {
        action = 'unspam|nospam',
        description = 'Turns off spam',
        run = function(self)
            stopSpam(self)
        end,
    },
    {
        action = 'whisper|pm',
        description = 
[[Makes you whisper a string to someone (possible mute bypass)]],
        args = {
            {
                kind = 'player',
            },
            {
                kind = 'string',
                name = 'your message',
            },
        },
        run = function(self, args)
            local targets = resolvePlayers(args:nextValue())
            local message = args:nextValue()

            if not message then
                return
            end

            for _, player in targets do
                if player ~= self.localPlayer then
                    say(self, 'Whisper', `/w {player.Name} {message}`)
                end
            end
        end,
    },
    {
        action = 'pmspam',
        description = 'Makes you spam a players whispers',
        args = {
            {
                kind = 'player',
            },
            {
                kind = 'string',
                name = 'your message',
            },
        },
        run = function(self, args)
            local targets = resolvePlayers(args:nextValue())
            local message = args:nextValue()

            if not message then
                return
            end

            for _, player in targets do
                if player ~= self.localPlayer then
                    startPmSpam(self, player, message)
                end
            end
        end,
    },
    {
        action = 'unpmspam|nopmspam',
        description = 'Turns off pm spam (no player: turns it off for everyone)',
        args = {
            kind = 'player',
            optional = true,
        },
        run = function(self, args)
            local text = args:nextValue()
            local names = if text then pmTargets(self, text)else everyPmName(self)

            for _, name in names do
                stopPmSpam(self, name)
            end
        end,
    },
    {
        action = 'spamspeed|spamdelay',
        description = 'How quickly you spam (default is 1)',
        args = {
            kind = 'number',
            name = 'delay',
            optional = true,
        },
        run = function(self, args)
            self.privateEnv.spamSpeed = math.max(args:nextValue() or 1, 0)
        end,
    },
}
