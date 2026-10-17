local colors = require('../framework/config/ui/colors').text
local PALETTE = {colors.red, colors.purple, colors.green}
local nameColor = {}

function nameColor.value(name)
    local value = 0
    local length = #name

    for index = 1, length do
        local code = string.byte(name, index)
        local reverseIndex = length - index + 1

        if length % 2 == 1 then
            reverseIndex -= 1
        end
        if reverseIndex % 4 >= 2 then
            code = -code
        end

        value += code
    end

    return value
end
function nameColor.forName(name)
    return PALETTE[nameColor.value(name) % #PALETTE + 1]
end
function nameColor.forPlayer(player, legacy)
    return nameColor.forName(player.Name)
end

return nameColor
