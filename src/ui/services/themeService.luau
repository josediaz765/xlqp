local themes = require('../themes')
local themeConfig = require('../../framework/config/ui/themes')
local settingsData = require('../../storage/data/settings')
local logger = require('../../utils/logger')
local tools = require('../../utils/tools')
local themeService = {
    objects = {},
    selectedTheme = nil,
    selectedKey = nil,
}
local PRIMARY_PREFIX = 'themePrimary.'

function themeService:isUsable(theme)
    return theme ~= nil and theme.Colors ~= nil and theme.Font ~= nil
end
function themeService:getThemes()
    local list = {}

    for key, theme in themes do
        table.insert(list, {
            key = key,
            name = theme.DisplayName,
            theme = theme,
            usable = self:isUsable(theme),
        })
    end

    table.sort(list, function(a, b)
        return a.name < b.name
    end)

    return list
end
function themeService:getPrimaryOptions()
    return themeConfig.options
end

local function findOption(key)
    for _, option in themeConfig.options do
        if option.key == key then
            return option
        end
    end

    return nil
end

function themeService:getPrimaryKey(themeName)
    local saved = settingsData:getValue(PRIMARY_PREFIX .. themeName:lower())

    if type(saved) == 'string' and findOption(saved) then
        return saved
    end

    return themeConfig.defaultKey
end
function themeService:getPrimaryColor(theme, primaryKey)
    local option = findOption(primaryKey)

    if option and option.color then
        return option.color
    end

    return theme.Colors.Primary
end

local function withPrimary(theme, primaryKey)
    local option = findOption(primaryKey)

    if not option or option.color == nil then
        return theme
    end

    local colors = table.clone(theme.Colors)

    colors.Primary = option.color
    colors.OnPrimary = option.color:Lerp(Color3.new(0, 0, 0), themeConfig.darken)

    local copy = table.clone(theme)

    copy.Colors = colors

    return copy
end

function themeService:selectTheme(themeName)
    logger:expect(themeName, {
        'string',
    }, "'themeService:selectTheme' #1")

    local key = themeName:lower()
    local theme = themes[key]

    if not theme then
        logger:error(`'{themeName}' isn't a valid theme`)

        return
    end

    self.selectedKey = key
    self.selectedTheme = if self:isUsable(theme)then withPrimary(theme, self:getPrimaryKey(key))else theme

    self:updateObjects()

    return self
end
function themeService:setPrimary(themeName, primaryKey)
    local key = themeName:lower()

    settingsData:setValue(PRIMARY_PREFIX .. key, primaryKey)
    settingsData:save()

    if self.selectedKey == key then
        self:selectTheme(key)
    end
end
function themeService:updateObject(object)
    self:updateObjectProperties(object, self.objects[object])
end
function themeService:updateObjectProperties(object, properties)
    for property, value in properties do
        object[property] = tools.getDeep(self.selectedTheme, value)
    end
end
function themeService:updateObjects()
    for object, _ in self.objects do
        self:updateObject(object)
    end
end
function themeService:addObject(object, themeTag)
    self.objects[object] = themeTag

    self:updateObject(object)
end
function themeService:removeObject(object)
    self.objects[object] = nil
end
function themeService:init(config)
    logger:expect(config, {
        'table',
    }, "'themeService:init' #1")

    if config.theme ~= nil then
        self:selectTheme(config.theme)
    end
end

return themeService
