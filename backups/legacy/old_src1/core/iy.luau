local logger = require('../utils/logger')

if require('../config/isLoaded') then
    logger:fail('is already loaded')

    return nil
end

logger:log('loading IY Remake...')
logger:log('is mobile:', require('../config/isMobile'))
logger:log('current version:', require('../config/iy').version)
logger:log('is remake version:', require('../config/iy').isRemakeVersion)
require('./cleanup')
require('./storage')
require('./checkVersion')
require('./init')

return require('../ui/iy')
