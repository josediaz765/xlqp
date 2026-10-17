local gitCfg = require('./github')

return {
    discord = 'https://discord.gg/dFpeqN4UHk',
    github = `https://github.com/{gitCfg.owner}/{gitCfg.repository}`,
}
