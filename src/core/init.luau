require('./cleanup'):init()

local commandsController = require('../commands/controllers/commandsController')
local keepiy = require('../commands/systems/keepiy')
local playerService = require('../framework/services/playerService')
local fetchService = require('../framework/services/fetchService')
local eventListeners = require('../commands/services/eventListeners')
local interface = require('../ui')
local infiniteYield = {}

function infiniteYield:boot()
    self.boot = nil

    commandsController:init({
        infiniteYield = interface,
        playerService = playerService,
        fetchService = fetchService,
    })
    keepiy.start()
    interface:awake()
    eventListeners.start()
end

return infiniteYield
