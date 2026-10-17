local function applyWalkSpeed(humanoid, speed)
    humanoid.WalkSpeed = speed
end
local function applyJumpPower(humanoid, power)
    if humanoid.UseJumpPower then
        humanoid.JumpPower = power
    else
        humanoid.JumpHeight = power
    end
end
local function stopLoop(self, garbageName)
    local garbage = self:collectGarbage(garbageName)

    if garbage and garbage.connections then
        for _, connection in garbage.connections do
            connection:Disconnect()
        end
    end
end
local function startLoop(self, garbageName, property, apply, value)
    stopLoop(self, garbageName)

    local garbage = self:createGarbage(garbageName)

    garbage.connections = {}

    local function watch(humanoid)
        apply(humanoid, value)
        table.insert(garbage.connections, self:connect(humanoid:GetPropertyChangedSignal(property), function(
        )
            apply(humanoid, value)
        end))
    end

    local humanoid = self.playerService:getHumanoid()

    if humanoid then
        watch(humanoid)
    end

    table.insert(garbage.connections, self:connect(self.localPlayer.CharacterAdded, function(
        character
    )
        watch(character:WaitForChild('Humanoid'))
    end))
end

return {
    {
        action = 'loopspeed|loopws',
        description = 
[[Keeps your walk speed set, even after respawning (default is 16)]],
        args = {
            kind = 'number',
            name = 'walk speed',
            optional = true,
        },
        run = function(self, args)
            startLoop(self, 'loopspeed', 'WalkSpeed', applyWalkSpeed, args:nextValue() or 16)
        end,
    },
    {
        action = 'unloopspeed|unloopws',
        description = 'Stops the walk speed loop',
        run = function(self)
            stopLoop(self, 'loopspeed')
        end,
    },
    {
        action = 'loopjumppower|loopjp|loopjpower',
        description = 
[[Keeps your jump power set, even after respawning (default is 50)]],
        args = {
            kind = 'number',
            name = 'jump power',
            optional = true,
        },
        run = function(self, args)
            startLoop(self, 'loopjumppower', 'JumpPower', applyJumpPower, args:nextValue() or 50)
        end,
    },
    {
        action = 'unloopjumppower|unloopjp|unloopjpower',
        description = 'Stops the jump power loop',
        run = function(self)
            stopLoop(self, 'loopjumppower')
        end,
    },
}
