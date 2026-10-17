local continuation = ...
local STARTUP_REVISION = "ee11e593fd882a83bd0a793af420844ff5c66a810737485a0a26410a79baf736"
local host = (getgenv and getgenv()) or getfenv()
local root = host.XLQP_ROOT or "xlqp"
local baseUrl = host.XLQP_BASE_URL or "https://raw.githubusercontent.com/josediaz765/xlqp/main/"
local localMode = host.XLQP_LOCAL == true
local nativeLoad = loadstring
local nativeRead = readfile
local cache = {}
local cacheSuffix = "?xlqp=" .. STARTUP_REVISION
local knownFiles

if baseUrl:sub(-1) ~= "/" then baseUrl ..= "/" end

if not localMode then
    local shared = host.__XLQP_STARTUP_CACHE
    if type(shared) ~= "table" then
        shared = {}
        host.__XLQP_STARTUP_CACHE = shared
    end
    local cacheKey = baseUrl .. STARTUP_REVISION
    local startup = shared[cacheKey]
    if type(startup) ~= "table" then
        local path = "runtime/startup-" .. STARTUP_REVISION:sub(1, 16) .. ".luau"
        local chunk, err = nativeLoad(game:HttpGet(baseUrl .. path), "XLQP/startup")
        assert(chunk, err)
        local payload = chunk()
        assert(type(payload) == "table" and payload.revision == STARTUP_REVISION and type(payload.files) == "table", "XLQP startup payload is invalid")
        startup = payload.files
        shared[cacheKey] = startup
    end
    cache = table.clone(startup)
end

local function readRepositoryFile(path)
    path = path:gsub("\\", "/")
    if path:sub(1, #root + 1) == root .. "/" then
        path = path:sub(#root + 2)
    end
    if cache[path] ~= nil then return cache[path] end
    if knownFiles and not knownFiles[path] then
        error("XLQP module path is not indexed: " .. path, 2)
    end
    local source
    if localMode then
        assert(type(nativeRead) == "function", "XLQP local mode requires readfile")
        source = nativeRead(root .. "/" .. path)
    else
        local encodedPath = path:gsub("[^%w%-%._~/]", function(character)
            return string.format("%%%02X", string.byte(character))
        end)
        source = game:HttpGet(baseUrl .. encodedPath .. cacheSuffix)
    end
    assert(type(source) == "string", "XLQP file did not return source: " .. path)
    cache[path] = source
    return source
end

local environment = setmetatable({
    __XLQP_READ = readRepositoryFile,
    __XLQP_ROOT = root,
    __XLQP_BASE_URL = baseUrl,
    __XLQP_LOCAL = localMode,
    __XLQP_CACHE_SUFFIX = cacheSuffix,
}, {__index = getfenv()})

local function compile(source, name)
    local chunk, err = nativeLoad(source, name)
    if chunk then setfenv(chunk, environment) end
    return chunk, err
end

rawset(environment, "loadstring", compile)
local index = assert(compile(readRepositoryFile("src/framework/resourcesIndex.luau"), "XLQP/file-index"))()
knownFiles = {
    ["src/framework/resourcesIndex.luau"] = true,
    ["src/framework/resources.luau"] = true,
    ["loader.luau"] = true,
}
for _, path in index.files do knownFiles[path] = true end
local bundle = assert(compile(readRepositoryFile("rbxBundle.luau"), "XLQP/modules"))()
local require = bundle.new(root).require
local result = require("./main")
if continuation then
    return assert(require("./src/framework/resources").compile(continuation, "XLQP/teleport"))()
end
return result
