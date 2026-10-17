local ANY = 'any'

return {
    ANY = ANY,
    events = {
        {
            name = 'OnExecute',
            description = 'when IY loads',
            conditions = {},
        },
        {
            name = 'OnJoin',
            description = 'a player joins',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = ANY,
                },
            },
        },
        {
            name = 'OnLeave',
            description = 'a player leaves',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = ANY,
                },
            },
        },
        {
            name = 'OnSpawn',
            description = 'a character spawns',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = 'me',
                },
            },
        },
        {
            name = 'OnDied',
            description = 'a character dies',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = 'me',
                },
            },
        },
        {
            name = 'OnDamage',
            description = 'a character takes damage',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = 'me',
                },
                {
                    kind = 'Number',
                    label = '$2 health at most',
                    default = ANY,
                },
            },
        },
        {
            name = 'OnKilled',
            description = 'a player kills another',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 victim',
                    default = 'me',
                },
                {
                    kind = 'Player',
                    label = '$2 killer',
                    default = ANY,
                },
            },
        },
        {
            name = 'OnChatted',
            description = 'a player chats',
            conditions = {
                {
                    kind = 'Player',
                    label = '$1 player',
                    default = ANY,
                },
                {
                    kind = 'String',
                    label = '$2 message contains',
                    default = ANY,
                },
            },
        },
    },
}
