local SLOW_LOAD = 3
local loading = {}

local function fetchScript(self, label, path, chunkName, ...)
    if loading[path] then
        self:notify(label, 'is already loading')
        return
    end

    loading[path] = true
    self:notify(label, 'started loading')

    local finished = false
    local arguments = table.pack(...)

    task.delay(SLOW_LOAD, function()
        if not finished then
            self:notify(label, 'is taking a while to load, still loading...')
        end
    end)

    local trace
    local success, result = xpcall(function()
        local chunk, err = self.fetchService.load(path, chunkName)
        assert(type(chunk) == 'function', err or ('No executable source for ' .. path))
        return chunk(table.unpack(arguments, 1, arguments.n))
    end, function(err)
        trace = debug.traceback(tostring(err), 2)
        return err
    end)

    finished = true
    loading[path] = nil

    if not success then
        if type(self.reportError) == 'function' then
            self:reportError(label, result, trace)
        else
            self:notify(label, 'failed: ' .. tostring(result))
        end
        return
    end

    self:notify(label, 'finished loading')
    return result
end
local function oldConsole(self)
    fetchScript(self, 'Old Console', 'backups/oldconsole.luau', 'iy/oldconsole')
end
local function dexExplorer(self, byMoon)
    if byMoon == true then
        fetchScript(self, 'Dex Explorer', 'backups/explorer.luau', 'iy/explorer')
    else
        fetchScript(self, 'Dex Explorer', 'backups/dexPlusPlus.luau', 'iy/dexPlusPlus')
    end
end
local function emoteMenu(self, args)
    local keycode = args:nextValue()
    local notifyEnabled = args:nextValue()

    fetchScript(self, 'Emote Menu', 'backups/emotes/main.luau', 'iy/7yd7/emotes.luau', {
        notifyFunction = function(options)
            if notifyEnabled ~= false then
                self:notify(options.Title or 'Emote Menu', options.Content or '')
            end
        end,
        isMobile = self.isMobile,
        keycode = keycode,
    })
end
local function cobaltSpy(self)
    fetchScript(self, 'Cobalt', 'backups/cobalt.luau', 'iy/cobalt')
end
local function remoteSpy(self)
    fetchScript(self, 'Remote Spy', 'backups/remotespy/main.luau', 'iy/remotespy')
end
local function audioLogger(self)
    fetchScript(self, 'Audio Logger', 'backups/audiologger.luau', 'iy/audiologger')
end

return {
    {
        action = 'oldconsole',
        description = 'Loads an old-themed Roblox console',
        run = function(self)
            task.spawn(oldConsole, self)
        end,
    },
    {
        action = 'explorer|dex',
        description = 'Opens the dex Explorer',
        args = {
            name = 'load dex by moon',
            kind = 'boolean',
            optional = true,
        },
        run = function(self, args)
            task.spawn(dexExplorer, self, args:nextValue())
        end,
    },
    {
        action = 'emotemenu|7yd7',
        description = 'Opens animations/emotes menu By 7yd7',
        run = function(self, args)
            task.spawn(emoteMenu, self, args)
        end,
        args = {
            {
                kind = 'keycode',
                name = 'open menu',
                optional = true,
            },
            {
                kind = 'boolean',
                name = 'notify',
                optional = true,
            },
        },
    },
    {
        action = 'cobalt|remotespy|rspy|cspy',
        description = 
[[Opens Cobalt to intercept incoming and outgoing network traffic]],
        run = function(self)
            task.spawn(cobaltSpy, self)
        end,
    },
    {
        action = 'simplespy|simplespy|sspy',
        description = 
[[Opens Simple Spy V3 to intercept remote calls from the client to the server]],
        run = function(self)
            task.spawn(remoteSpy, self)
        end,
    },
    {
        action = 'audiologger|alogger',
        description = 'Opens Edges audio logger',
        run = function(self)
            task.spawn(audioLogger, self)
        end,
    },
}
