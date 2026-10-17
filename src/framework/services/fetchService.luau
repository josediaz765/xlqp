local resources = require('../resources')
local fetchService = {}

function fetchService.fetch(path)
    return resources.lookup(path)
end
function fetchService.download(name)
    if name == 'compiled.luau' then
        return resources.source()
    end

    return resources.lookup(name)
end
function fetchService.downloadUrl(name)
    return 'embedded://' .. name
end
function fetchService.load(path, name)
    return resources.load(path, name)
end

return fetchService
