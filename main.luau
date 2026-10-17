local resources = require("./src/framework/resources")
local host = (getgenv and getgenv()) or getfenv()
local root = __XLQP_ROOT or host.XLQP_ROOT or "xlqp"
local baseUrl = __XLQP_BASE_URL or host.XLQP_BASE_URL or "https://raw.githubusercontent.com/josediaz765/xlqp/main/"
local localMode = __XLQP_LOCAL
local cacheSuffix = __XLQP_CACHE_SUFFIX or ""
if localMode == nil then localMode = host.XLQP_LOCAL == true end
if baseUrl:sub(-1) ~= "/" then baseUrl ..= "/" end

resources.configure(function(continuation)
    local reader = if localMode then "readfile(" .. string.format("%q", root .. "/loader.luau") .. ")"
        else "game:HttpGet(" .. string.format("%q", baseUrl .. "loader.luau" .. cacheSuffix) .. ")"
    return "getgenv().XLQP_ROOT=" .. string.format("%q", root)
        .. "\ngetgenv().XLQP_BASE_URL=" .. string.format("%q", baseUrl)
        .. "\ngetgenv().XLQP_LOCAL=" .. tostring(localMode)
        .. "\nreturn assert(loadstring(" .. reader .. ", " .. string.format("%q", "XLQP/loader") .. "))("
        .. (if continuation then string.format("%q", continuation) else "nil") .. ")"
end)

return require("./src/core"):boot()
