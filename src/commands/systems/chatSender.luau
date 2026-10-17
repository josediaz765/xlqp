local rbxServices = require('../../framework/services/rbxServices')
local chatSender = {}

function chatSender.isLegacy()
    return rbxServices.TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
end
function chatSender.send(message)
    message = tostring(message)

    local success, reason = pcall(function()
        if chatSender.isLegacy() then
            rbxServices.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, 'All')
        else
            rbxServices.TextChatService.TextChannels.RBXGeneral:SendAsync(message)
        end
    end)

    return success, if success then nil else tostring(reason)
end

return chatSender
