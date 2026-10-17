return {
    bindings = {
        prefix = {
            label = 'Prefix',
            settingKey = 'keybinds.prefix',
            default = 'Semicolon',
            also = {
                'RightControl',
            },
            group = 'interface',
        },
        flyUp = {
            label = 'Up',
            settingKey = 'keybinds.flyUp',
            default = 'E',
            group = 'fly',
        },
        flyDown = {
            label = 'Down',
            settingKey = 'keybinds.flyDown',
            default = 'Q',
            group = 'fly',
        },
        floatUp = {
            label = 'Up',
            settingKey = 'keybinds.floatUp',
            default = 'E',
            group = 'float',
        },
        floatDown = {
            label = 'Down',
            settingKey = 'keybinds.floatDown',
            default = 'Q',
            group = 'float',
        },
        freecamBoost = {
            label = 'Boost (held)',
            settingKey = 'keybinds.freecamBoost',
            default = 'LeftControl',
            group = 'freecam',
        },
    },
    groups = {
        {
            key = 'fly',
            title = 'Fly',
        },
        {
            key = 'float',
            title = 'Float',
        },
        {
            key = 'freecam',
            title = 'Freecam',
        },
    },
}
