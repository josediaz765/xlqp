local keyboardService = require('../../../framework/services/keyboardService')

local function clearListener(self)
    local garbage = self:collectGarbage('hideiy')

    if garbage and garbage.connection then
        garbage.connection:Disconnect()
    end
end
local function listenForShowKeys(self, interface)
    clearListener(self)

    local garbage = self:registerGarbage('hideiy')

    garbage.connection = keyboardService:onBindingPressed('prefix', function()
        if interface.mainFrame.Visible then
            return
        end

        interface:showCommandBar()
    end)
end
local function hideWindow(self)
    local interface = self.infiniteYield

    if not interface or not interface.mainFrame then
        self:notify('IY', 'the main window is not created yet')

        return
    end
    if not interface.mainFrame.Visible then
        self:notify('IY', 'already hidden')

        return
    end

    interface:hideWindow()
    listenForShowKeys(self, interface)

    local prefixName = keyboardService:getBindingName('prefix')

    self:notify('IY', `hidden. Press {prefixName} or tap the IY button to type a command`)
end
local function showWindow(self)
    clearListener(self)

    local interface = self.infiniteYield

    if interface then
        interface:showWindow()
    end
end

return {
    {
        action = 'hideiy|hideinterface',
        description = 'Hides the main IY GUI',
        run = function(self)
            hideWindow(self)
        end,
    },
    {
        action = 'showiy|unhideiy|unhideinterface',
        description = 'Shows IY again',
        run = function(self)
            showWindow(self)
        end,
    },
}
