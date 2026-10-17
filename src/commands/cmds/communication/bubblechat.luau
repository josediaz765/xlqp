local rbxServices = require('../../../framework/services/rbxServices')
local chatSender = require('../../systems/chatSender')

local function setBubbleChat(enabled)
    if chatSender.isLegacy() then
        rbxServices.Chat.BubbleChatEnabled = enabled
    else
        rbxServices.TextChatService.BubbleChatConfiguration.Enabled = enabled
    end
end

return {
    {
        action = 'bubblechat',
        description = 'Enables bubble chat for your client (CLIENT)',
        client = true,
        run = function()
            setBubbleChat(true)
        end,
    },
    {
        action = 'unbubblechat|nobubblechat',
        description = 'Disables bubble chat for your client (CLIENT)',
        client = true,
        run = function()
            setBubbleChat(false)
        end,
    },
}
