local rbxServices = require('../framework/services/rbxServices')
local executorEnv = require('../framework/environment/executor')

local function getCoreGui()
    local coreGui = rbxServices.CoreGui
    local gethui = executorEnv.gethui

    if typeof(gethui) == 'function' then
        local success, folder = pcall(gethui)

        if success and typeof(folder) == 'Instance' then
            coreGui = folder
        end
    end
    if coreGui == rbxServices.CoreGui then
        local robloxGui = coreGui:FindFirstChild('RobloxGui')

        coreGui = if robloxGui ~= nil then robloxGui else coreGui
    end

    return coreGui
end

return getCoreGui()
