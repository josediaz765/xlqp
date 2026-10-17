local function promptRig(self, rigName)
    local humanoid = self.playerService:getHumanoid()

    if not humanoid then
        self:notify('Rig', 'your character is not loaded')

        return
    end

    local avatarEditor = self.robloxServices.AvatarEditorService

    task.spawn(function()
        avatarEditor:PromptSaveAvatar(humanoid.HumanoidDescription, Enum.HumanoidRigType[rigName])

        local result = avatarEditor.PromptSaveAvatarCompleted:Wait()

        if result == Enum.AvatarPromptResult.Success then
            self:run('reset')
        end
    end)
end

return {
    {
        action = 'promptr6',
        description = 'Prompts the game to switch your rig type to R6',
        run = function(self)
            promptRig(self, 'R6')
        end,
    },
    {
        action = 'promptr15',
        description = 'Prompts the game to switch your rig type to R15',
        run = function(self)
            promptRig(self, 'R15')
        end,
    },
}
