local privateEnv = require('../framework/environment/private')
local logger = require('../utils/logger')
local cleanup = {}

local function stopRunning(garbage)
    if type(garbage) ~= 'table' then
        return
    end
    if type(garbage.stop) == 'function' then
        pcall(garbage.stop)
    end
    if garbage.running ~= nil then
        garbage.running = false
    end
    if typeof(garbage.thread) == 'thread' then
        pcall(task.cancel, garbage.thread)
    end
end

function cleanup:init()
    if privateEnv.screenGui then
        privateEnv.screenGui:Destroy()
        logger:log('destroyed old interface')
    end
    if privateEnv.connectionService then
        privateEnv.connectionService:cleanup()

        privateEnv.connectionService = nil

        logger:log('cleaned old connections')
    end

    for _, garbage in privateEnv.iyGarbages or {}do
        stopRunning(garbage)
    end

    logger:log('finished cleanup!')
end

return cleanup
