local privateEnv = require('../../framework/environment/private')
local logger = require('../../utils/logger')
local loopService = {
    _callbacks = {},
    _nextId = 0,
}

local function runLoop(self)
    while true do
        task.wait()

        if next(self._callbacks) == nil then
            privateEnv.loopThread = nil

            return
        end

        local now = os.clock()

        for _, data in self._callbacks do
            if now - data.lastCall >= data.cooldown then
                data.lastCall = now

                task.defer(data.func)
            end
        end
    end
end

function loopService:start()
    if privateEnv.loopThread ~= nil then
        return
    end

    privateEnv.loopThread = task.defer(runLoop, self)
end
function loopService:stop()
    local thread = privateEnv.loopThread

    privateEnv.loopThread = nil

    table.clear(self._callbacks)

    if thread ~= nil then
        task.cancel(thread)
    end
end
function loopService:add(callback, cooldown)
    logger:expect(callback, {
        'function',
    }, "'loopService:add' #1")
    logger:expect(cooldown, {
        'number',
        'nil',
    }, "'loopService:add' #2")

    self._nextId += 1

    local id = self._nextId

    self._callbacks[id] = {
        func = callback,
        cooldown = math.max(cooldown or 0, 0),
        lastCall = -math.huge,
    }

    self:start()

    return id
end
function loopService:remove(id)
    logger:expect(id, {
        'number',
    }, "'loopService:remove' #1")

    self._callbacks[id] = nil
end

return loopService
