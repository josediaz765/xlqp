local keyboardService = require('../../../framework/services/keyboardService')
local keybindsConfig = require('../../../framework/config/services/keybinds')
local config = require('../../../framework/config/ui/settings')
local widgets = require('./widgets')
local PANEL = config.panel
local VALUE = config.value

local function namesIn(group)
    local names = {}

    for name, binding in keybindsConfig.bindings do
        if binding.group == group then
            table.insert(names, name)
        end
    end

    table.sort(names)

    return names
end
local function fixedKeyLines(groups)
    local lines = {}

    for _, group in groups do
        for _, name in namesIn(group)do
            local binding = keybindsConfig.bindings[name]

            for _, keyName in binding.also or {}do
                local keyCode = (Enum.KeyCode)[keyName]

                if keyCode then
                    table.insert(lines, string.format(config.pages.keybinds.alwaysWorks, keyboardService:getKeyName(keyCode), binding.label or name))
                end
            end
        end
    end

    return lines
end
local function makePage(pageConfig)
    return function(page, ctx)
        local list = widgets.list(page)

        widgets.pageTop(list, pageConfig.title, ctx.back)

        local refreshers = {}
        local keys = {}

        for _, group in pageConfig.groups do
            if group.title then
                widgets.header(list, group.title)
            end

            table.insert(keys, group.key)

            for _, name in namesIn(group.key)do
                local binding = keybindsConfig.bindings[name]
                local row = widgets.row(list)

                widgets.label(row, binding.label or name, VALUE.keybindWidth + 2 * PANEL.padding)

                local refresh, stop = widgets.keybind(row, name)

                table.insert(refreshers, refresh)
                table.insert(ctx.stoppers, stop)
            end
        end

        local fixedLines = fixedKeyLines(keys)

        if #fixedLines > 0 then
            widgets.note(list, table.concat(fixedLines, '\n'))
        end

        local reset = widgets.row(list)

        widgets.label(reset, pageConfig.reset, 0)
        reset.Activated:Connect(function()
            for _, stop in ctx.stoppers do
                stop()
            end
            for _, key in keys do
                for _, name in namesIn(key)do
                    keyboardService:resetBinding(name)
                end
            end
            for _, refresh in refreshers do
                refresh()
            end
        end)
    end
end

return {
    interface = makePage({
        title = config.pages.keybinds.title,
        reset = config.pages.keybinds.reset,
        groups = {
            {
                key = 'interface',
            },
        },
    }),
    commands = makePage({
        title = config.pages.commands.title,
        reset = config.pages.commands.reset,
        groups = keybindsConfig.groups,
    }),
}
