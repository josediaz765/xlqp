local argColors = require('../framework/config/ui/colors').args
local tools = require('./tools')
local highlight = {}
local symbolChars = tools.charset(':#()[]<>{}-\u{2013}\u{2013}&*$%@')
local WORD_PATTERN = '^[%w_%.]+'
local TAG_PATTERN = '^[%w_]+'

local function isWordChar(char)
    return char ~= '' and string.match(char, '[%w_%.]') ~= nil
end
local function isNumber(word)
    return string.match(word, '^%d+$') ~= nil or string.match(word, '^%d+%.%d+$') ~= nil
end
local function findClosingQuote(text, opening)
    local quote = string.sub(text, opening, opening)
    local position = opening + 1

    while position <= #text do
        local char = string.sub(text, position, position)

        if char == '\\' then
            position += 2
        elseif char == quote then
            return position
        else
            position += 1
        end
    end

    return nil
end
local function split(text)
    local pieces = {}

    local function push(piece, color, bold)
        if piece == '' then
            return
        end

        local last = pieces[#pieces]

        if last and last.color == color and last.bold == bold then
            last.text = last.text .. piece
        else
            table.insert(pieces, {
                text = piece,
                color = color,
                bold = bold,
            })
        end
    end

    local position = 1
    local length = #text

    while position <= length do
        local char = string.sub(text, position, position)
        local previous = if position > 1 then string.sub(text, position - 1, position - 1)else''

        if (char == '@' or char == '#') and not isWordChar(previous) then
            local _, tagEnd = string.find(text, TAG_PATTERN, position + 1)

            if tagEnd then
                push(string.sub(text, position, tagEnd), argColors.tag, true)

                position = tagEnd + 1

                continue
            end
        end
        if (char == '"' or char == "'") and not isWordChar(previous) then
            local closing = findClosingQuote(text, position)

            if closing then
                push(string.sub(text, position, closing), argColors.string, false)

                position = closing + 1

                continue
            end
        end
        if isWordChar(char) then
            local _, wordEnd = string.find(text, WORD_PATTERN, position)
            local word = string.sub(text, position, wordEnd)

            push(word, if isNumber(word)then argColors.number else nil, false)

            position = wordEnd + 1
        else
            push(char, if symbolChars[char]then argColors.symbol else nil, false)

            position += 1
        end
    end

    return pieces
end

function highlight:apply(value)
    local parts = {}

    for _, piece in split(tostring(value))do
        local text = tools.escapeRichText(piece.text)

        if piece.color then
            text = tools.colorFromRGB(text, piece.color)
        end
        if piece.bold then
            text = `<b>{text}</b>`
        end

        table.insert(parts, text)
    end

    return table.concat(parts)
end

return highlight
