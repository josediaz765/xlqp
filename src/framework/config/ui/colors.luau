local red = Color3.fromRGB(255, 85, 102)
local purple = Color3.fromRGB(192, 132, 252)
local green = Color3.fromRGB(74, 222, 128)

return {
    text = {red = red, purple = purple, green = green},
    args = {
        number = purple,
        boolean = purple,
        text = green,
        string = green,
        symbol = red,
        comment = purple,
        others = green,
        warn = purple,
        error = red,
        valid = green,
        tag = purple,
    },
    commands = {undefined = red, client = green, deprecated = purple},
}
