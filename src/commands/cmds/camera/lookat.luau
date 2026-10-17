local resolvePlayers = require('../../systems/resolvePlayers')
local DEFAULT_ZOOM = {
    max = 400,
    min = 0.5,
}

return {
    action = 'lookat',
    description = 'Moves your camera view to a player',
    args = {
        kind = 'player',
    },
    run = function(self, args)
        local target = resolvePlayers(args:nextValue())[1]
        local targetHead = target and target.Character and target.Character:FindFirstChild('Head')

        if not targetHead then
            self:notify('Lookat', "the player's character is not loaded")

            return
        end

        local player = self.localPlayer
        local camera = self.playerService:getCamera()

        if player.CameraMaxZoomDistance ~= 0.5 then
            self.privateEnv.lookAtZoom = {
                max = player.CameraMaxZoomDistance,
                min = player.CameraMinZoomDistance,
            }
        end

        local zoom = self.privateEnv.lookAtZoom or DEFAULT_ZOOM

        player.CameraMaxZoomDistance = 0.5
        player.CameraMinZoomDistance = 0.5

        task.wait()

        camera.CFrame = CFrame.new(camera.CFrame.Position, targetHead.Position)

        task.wait(0.1)

        player.CameraMaxZoomDistance = zoom.max
        player.CameraMinZoomDistance = zoom.min
    end,
}
