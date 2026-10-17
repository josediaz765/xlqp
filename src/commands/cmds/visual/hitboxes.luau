local function setHitboxes(self, enabled)
    local ok = pcall(function()
        settings():GetService('RenderSettings').ShowBoundingBoxes = enabled
    end)

    if not ok then
        self:notify('Hitboxes', 'this executor cannot change the hitbox display')
    end
end

return {
    {
        client = true,
        action = 'hitboxes|showhitboxes',
        description = 'Shows player hitboxes (CLIENT)',
        run = function(self)
            setHitboxes(self, true)
        end,
    },
    {
        client = true,
        action = 'unhitboxes|nohitboxes|unshowhitboxes',
        description = 'Hides player hitboxes (CLIENT)',
        run = function(self)
            setHitboxes(self, false)
        end,
    },
}
