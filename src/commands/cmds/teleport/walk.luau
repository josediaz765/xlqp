local function stopTpWalk(self)
    local garbage = self:collectGarbage('tpwalk')

    if garbage then
        garbage.connection:Disconnect()
    end
end
local function getWallwalk(self)
    local cached = self.privateEnv.wallwalkSetEnabled

    if cached then
        return cached
    end

    local success, setEnabled = pcall(function()
        local chunk, err = self.fetchService.load('backups/wallwalker.luau', 'iy/wallwalker')
        assert(type(chunk) == 'function', err or 'Wallwalk source is unavailable')
        local controller = chunk()
        assert(type(controller) == 'function', 'Wallwalk did not return a controller')
        return controller
    end)

    if not success then
        self:notify('Wallwalk', 'could not load: ' .. tostring(setEnabled))

        return
    end

    self.privateEnv.wallwalkSetEnabled = setEnabled

    return setEnabled
end

return {
    {
        action = 'tpwalk|teleportwalk',
        description = 'Teleports you to your move direction',
        args = {
            {
                kind = 'number',
                name = 'distance',
                optional = true,
            },
            {
                kind = 'boolean',
                name = 'stack distance',
                optional = true,
            },
        },
        run = function(self, args)
            stopTpWalk(self)

            local speed = args:nextValue() or 1
            local stack = args:nextValue()

            if stack then
                self.privateEnv.tpwalkStack = (self.privateEnv.tpwalkStack or 0) + speed
            end

            local character = self.playerService:getCharacter()
            local humanoid = self.playerService:getHumanoid()

            if not (character and humanoid) then
                return
            end

            local garbage = self:createGarbage('tpwalk')

            garbage.connection = self:connect(self.runService.Heartbeat, function(
                delta
            )
                if not (character.Parent and humanoid.Parent) then
                    stopTpWalk(self)

                    return
                end

                local direction = humanoid.MoveDirection

                if direction.Magnitude > 0 then
                    local total = speed + (self.privateEnv.tpwalkStack or 0)

                    character:TranslateBy(direction * total * delta * 10)
                end
            end)
        end,
    },
    {
        action = 'untpwalk|unteleportwalk',
        description = 'Undoes tpwalk / teleportwalk',
        run = function(self)
            self.privateEnv.tpwalkStack = 0

            stopTpWalk(self)
        end,
    },
    {
        action = 'wallwalk|walkonwalls',
        description = 'Walk on walls',
        run = function(self)
            local previous = self:collectGarbage('wallwalk')

            if previous and previous.active then
                previous.stop()
                self:notify('Wallwalk', 'disabled')

                return
            end

            local setEnabled = getWallwalk(self)

            if not setEnabled then
                return
            end

            local ok, err = pcall(setEnabled, true)

            if not ok then
                self:notify('Wallwalk', `could not start: {tostring(err)}`)

                return
            end

            local garbage = self:createGarbage('wallwalk')

            garbage.active = true
            garbage.stop = function()
                garbage.active = false

                pcall(setEnabled, false)
            end

            self:notify('Wallwalk', 'walk on any surface; run wallwalk again to turn it off')
        end,
    },
    {
        action = 'unwallwalk|nowallwalk',
        description = 'Turns off wallwalk',
        run = function(self)
            local previous = self:collectGarbage('wallwalk')
            local wasOn = previous ~= nil and previous.active == true

            if previous and previous.stop then
                previous.stop()
            end

            self:notify('Wallwalk', if wasOn then'disabled'else'it is not running')
        end,
    },
}
