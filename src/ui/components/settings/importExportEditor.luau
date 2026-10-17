local themeService = require('../../services/themeService')
local notifier = require('../../notifier')
local widgets = require('./widgets')
local frameworkSettings = require('../../../framework/settings')
local executorEnv = require('../../../framework/environment/executor')
local config = require('../../../framework/config/ui/settings')
local datas = require('../../../storage')
local json = require('../../../utils/json')
local TEXT = config.pages.importExport
local PARTS = {
    'settings',
    'aliases',
    'eventBinds',
    'waypoints',
}

local function exportText()
    local data = {
        version = frameworkSettings.version,
    }

    for _, name in PARTS do
        data[name] = datas[name]:getData()
    end

    return json.encode(data, 'export') or ''
end
local function isUsableTheme(name)
    if type(name) ~= 'string' then
        return false
    end

    for _, entry in themeService:getThemes()do
        if entry.key == name:lower() and entry.usable then
            return true
        end
    end

    return false
end
local function importText(text)
    if text:match('^%s*$') then
        return nil, TEXT.empty
    end

    local data = json.decode(text, 'import')

    if type(data) ~= 'table' then
        return nil, TEXT.notAnExport
    end

    local imported = {}

    for _, name in PARTS do
        if type(data[name]) == 'table' then
            datas[name]:replaceData(data[name])
            table.insert(imported, name)
        end
    end

    if #imported == 0 then
        return nil, TEXT.notAnExport
    end

    local selected = datas.settings:getValue(config.keys.theme)

    if isUsableTheme(selected) then
        themeService:selectTheme(selected)
    end

    return imported
end
local function build(page, ctx)
    local list = widgets.list(page)

    widgets.pageTop(list, TEXT.title, ctx.back)
    widgets.header(list, TEXT.exportTitle)

    local exportRow = widgets.row(list)

    widgets.label(exportRow, TEXT.exportRow, 0)
    widgets.note(list, TEXT.exportHint)
    widgets.header(list, TEXT.importTitle)

    local box = widgets.textBox(list, TEXT.placeholder)

    box.MultiLine = true
    box.TextWrapped = true
    box.TextYAlignment = Enum.TextYAlignment.Top
    box.Size = UDim2.new(1, 0, 0, 96)

    local importRow = widgets.row(list)

    widgets.label(importRow, TEXT.importRow, 0)
    widgets.note(list, TEXT.importHint)
    widgets.note(list, TEXT.restartNote)
    exportRow.Activated:Connect(function()
        local text = exportText()

        if executorEnv.setclipboard then
            executorEnv.setclipboard(text)
            notifier:notify(TEXT.notifyTitle, TEXT.copied)
        else
            box.Text = text

            notifier:notify(TEXT.notifyTitle, TEXT.copyFailed)
        end
    end)
    importRow.Activated:Connect(function()
        local imported, reason = importText(box.Text)

        if imported then
            box.Text = ''

            notifier:notify(TEXT.notifyTitle, string.format(TEXT.imported, table.concat(imported, ', ')))
        else
            notifier:notify(TEXT.notifyTitle, reason or TEXT.notAnExport)
        end
    end)
end

return build
