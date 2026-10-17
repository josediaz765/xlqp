local index = require('./resourcesIndex')
local repositoryRoot = __XLQP_ROOT or ((getgenv and getgenv()) or getfenv()).XLQP_ROOT or "xlqp"
local readRepositoryFile = __XLQP_READ or function(path) return readfile(repositoryRoot .. "/" .. path) end
local entries = {}
local aliases = index.aliases
local host = (getgenv and getgenv()) or getfenv()
local rawLoad = loadstring
local rawHttp = game and game.HttpGet
local rawRequest = request or http_request or (syn and syn.request) or (http and http.request)
local rawQueue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
local sourceFactory
local resources = {
    entries = entries,
    scripts = index.scripts,
    files = index.files,
}

local function canonical(key)
    key = key:gsub('\\', '/'):gsub('^/', '')
    key = key:gsub('^https://github.com/([^/]+/[^/]+)/raw/', 'https://raw.githubusercontent.com/%1/')

    return key:gsub('/refs/heads/', '/')
end

function resources.lookup(key)
    key = canonical(key)

    local localPath = key:match(
[[^https://raw%.githubusercontent%.com/tlredz/iy%-remake/[^/]+/(.+)$]])

    if localPath and index.files[localPath] ~= nil then
        key = localPath
    end

    key = aliases[key] or key

    local endpoint = key:match('^[^?#]+') or key

    if endpoint:match('%-Full%-API%-Dump%.json$') then
        key = 'snapshot/full-api'
    elseif endpoint:match('%-API%-Dump%.json$') then
        key = 'snapshot/api'
    elseif endpoint:match('^https?://setup%.[^/]+/version$') then
        key = 'snapshot/version'
    elseif key:match('^https://clientsettingscdn?%.roblox%.com/') or key:match('^https://clientsettings%.roblox%.com/') then
        key = 'snapshot/client-version'
    end

    local cached = entries[key]

    if cached ~= nil then
        return cached
    end

    local path = index.files[key]

    if not path then
        return nil
    end

    local data = readRepositoryFile(path)

    entries[key] = data

    return data
end

local function liveService(url)
    local domain = url:match('^https?://([^/:]+)')

    return domain and (domain == 'roblox.com' or domain:sub(-11) == '.roblox.com' or domain == 'roproxy.com' or domain:sub(
-12) == '.roproxy.com' or domain == '127.0.0.1' or domain == 'localhost' or domain == 'api.plusgiant5.com')
end

function resources.httpGet(self, url, ...)
    local value = resources.lookup(url)

    if value ~= nil then
        return value
    end
    if liveService(url) and rawHttp then
        return rawHttp(self, url, ...)
    end

    error('Embedded resource missing: ' .. tostring(url), 2)
end
function resources.request(options)
    local url = options.Url or options.URL or options.url

    if string.upper(options.Method or 'GET') == 'GET' then
        local value = resources.lookup(url)

        if value ~= nil then
            return {
                Success = true,
                StatusCode = 200,
                Status = 200,
                StatusMessage = 'OK',
                Body = value,
                Headers = {},
            }
        end
    end
    if liveService(url) and rawRequest then
        return rawRequest(options)
    end

    error('Embedded resource missing: ' .. tostring(url), 2)
end
function resources.configure(factory)
    sourceFactory = factory
end
function resources.source(continuation)
    assert(sourceFactory, 'XLQP loader is not initialized')

    return sourceFactory(continuation)
end
function resources.queue(source)
    assert(rawQueue, 'Teleport queue is unavailable')

    return rawQueue(resources.source(source))
end
function resources.compile(source, name)
    local chunk, err = rawLoad(source, name)

    if not chunk then
        return nil, err
    end

    local environment = setmetatable({
        __XLQP_HTTP = resources.httpGet,
        __XLQP_REQUEST = resources.request,
        __XLQP_QUEUE = resources.queue,
        loadstring = resources.compile,
    }, {
        __index = getfenv(chunk),
        __newindex = host,
    })

    setfenv(chunk, environment)

    return chunk
end
function resources.load(path, name)
    local source = resources.lookup(path)

    if source == nil then
        return nil, 'Embedded resource missing: ' .. tostring(path)
    end

    return resources.compile(source, name or path)
end

return resources
