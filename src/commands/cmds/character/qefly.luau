return {
    action = 'qefly|flyqe',
    description = 
[[Enables or disables the up and down keys for fly (set them in Settings > Command Settings)]],
    args = {
        kind = 'boolean',
        optional = true,
    },
    run = function(self, args)
        self.privateEnv.qeFly = args:nextValue() ~= false
    end,
}
