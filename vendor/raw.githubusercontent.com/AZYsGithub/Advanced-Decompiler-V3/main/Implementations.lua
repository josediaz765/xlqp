local _ENV = (getgenv or getfenv)()
local Implementations = {}

function Implementations.toBoolean(n)
    return n ~= 0
end
function Implementations.toEscapedString(s)
    if type(s) == 'string' then
        local hasQuotationMarks = string.find(s, '"') ~= nil
        local hasApostrophes = string.find(s, "'") ~= nil

        if hasQuotationMarks and hasApostrophes then
            return '[[' .. s .. ']]'
        elseif hasQuotationMarks and not hasApostrophes then
            return "'" .. s .. "'"
        end

        return '"' .. s .. '"'
    end

    return tostring(s)
end
function Implementations.formatIndexString(s)
    if type(s) == 'string' then
        local validDirectPattern = '^[%a_][%w_]*$'

        if string.find(s, validDirectPattern) then
            return `.{s}`
        end

        return `["{s}"]`
    end

    return tostring(s)
end
function Implementations.padLeft(x, char, padding)
    return string.rep(char, padding - #tostring(x)) .. x
end
function Implementations.padRight(x, char, padding)
    return x .. string.rep(char, padding - #tostring(x))
end
function Implementations.isGlobal(s)
    return _ENV[s] ~= nil
end

return Implementations
