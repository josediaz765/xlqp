local band, lshift, rshift = bit32.band, bit32.lshift, bit32.rshift
local MIN_MATCH = 4
local MIN_LENGTH = 13
local MIN_TRAILING_LITERALS = 5
local MISS_COUNTER_BITS = 6
local HASH_SHIFT = 32 - 16
local MAX_DISTANCE = 0xffff
local COMPRESSION_GROWTH = 1 + 1 / 255
local BUFFER_SIZE_PADDING = 16
local DEFAULT_BUFFER_SIZE = 512 * 1024 ^ 1
local DEFAULT_MAX_BUFFER_SIZE = 2 ^ 31
local LIT_COUNT_BITS = 4
local LIT_COUNT_MASK = lshift(1, LIT_COUNT_BITS) - 1
local MATCH_LEN_BITS = 4
local MATCH_LEN_MASK = lshift(1, MATCH_LEN_BITS) - 1

local function checkType(value, typ, argNum, funcName)
    local actual = typeof(value)

    assert(actual == typ, `bad argument #{argNum} to '{funcName}' ({typ} expected, got {actual})`)
end
local function checkData(data, dataStart, dataLen, funcName)
    checkType(data, 'buffer', 1, funcName)
    checkType(dataStart, 'number', 2, funcName)
    checkType(dataLen, 'number', 3, funcName)
    assert(dataStart >= 0, 'dataStart cannot be negative')
    assert(dataLen >= 0, 'dataLen cannot be negative')
    assert(dataStart + dataLen <= buffer.len(data), 'data range not in buffer')
end
local function checkAcceleration(acceleration, argNum, funcName)
    acceleration = acceleration or 1

    checkType(acceleration, 'number', argNum, funcName)
    assert(acceleration >= 1 and acceleration % 1 == 0, 'acceleration must be an integer >= 1')

    return acceleration
end
local function compressBuffer(data, dataStart, dataLen, acceleration)
    checkData(data, dataStart, dataLen, 'compressBuffer')

    acceleration = checkAcceleration(acceleration, 4, 'compressBuffer')

    local hashTable = {}
    local out, outNext = buffer.create(math.ceil(dataLen * COMPRESSION_GROWTH) + BUFFER_SIZE_PADDING), 0
    local pos = dataStart
    local nextUnencodedPos = pos

    if dataLen >= MIN_LENGTH then
        local stepAndMissCounterInit = lshift(acceleration, MISS_COUNTER_BITS)
        local stepAndMissCounter = stepAndMissCounterInit

        while pos + MIN_MATCH < dataLen - MIN_TRAILING_LITERALS do
            local sequence = buffer.readu32(data, pos)
            local hash = rshift(sequence * 2654435761, HASH_SHIFT)
            local matchPos = hashTable[hash]

            hashTable[hash] = pos

            if not matchPos or pos - matchPos > MAX_DISTANCE or buffer.readu32(data, matchPos) ~= sequence then
                pos = pos + rshift(stepAndMissCounter, MISS_COUNTER_BITS)
                stepAndMissCounter = stepAndMissCounter + 1

                continue
            end

            stepAndMissCounter = stepAndMissCounterInit

            local literalCount = pos - nextUnencodedPos
            local matchOffset = pos - matchPos

            while literalCount > 0 and matchPos > 0 and buffer.readu8(data, pos - 1) == buffer.readu8(data, matchPos - 1) do
                literalCount = literalCount - 1
                pos = pos - 1
                matchPos = matchPos - 1
            end

            pos = pos + MIN_MATCH
            matchPos = matchPos + MIN_MATCH

            local matchLength = pos

            while pos < dataLen - MIN_TRAILING_LITERALS and buffer.readu8(data, pos) == buffer.readu8(data, matchPos) do
                pos = pos + 1
                matchPos = matchPos + 1
            end

            matchLength = pos - matchLength

            local literalCountHalf = (literalCount < LIT_COUNT_MASK) and literalCount or LIT_COUNT_MASK
            local matchLenHalf = (matchLength < MATCH_LEN_MASK) and matchLength or MATCH_LEN_MASK
            local token = lshift(literalCountHalf, MATCH_LEN_BITS) + matchLenHalf

            buffer.writeu8(out, outNext, token)

            outNext = outNext + 1

            local remaining = literalCount - LIT_COUNT_MASK

            while remaining >= 0xff do
                buffer.writeu8(out, outNext, 0xff)

                outNext = outNext + 1
                remaining = remaining - 0xff
            end

            if remaining >= 0 then
                buffer.writeu8(out, outNext, remaining)

                outNext = outNext + 1
            end

            buffer.copy(out, outNext, data, nextUnencodedPos, literalCount)

            outNext = outNext + literalCount

            buffer.writeu16(out, outNext, matchOffset)

            outNext = outNext + 2
            remaining = matchLength - MATCH_LEN_MASK

            while remaining >= 0xff do
                buffer.writeu8(out, outNext, 0xff)

                outNext = outNext + 1
                remaining = remaining - 0xff
            end

            if remaining >= 0 then
                buffer.writeu8(out, outNext, remaining)

                outNext = outNext + 1
            end

            nextUnencodedPos = pos
        end
    end

    local literalCount = dataLen - nextUnencodedPos
    local token = lshift((literalCount < LIT_COUNT_MASK) and literalCount or LIT_COUNT_MASK, MATCH_LEN_BITS)

    buffer.writeu8(out, outNext, token)

    outNext = outNext + 1

    local remaining = literalCount - LIT_COUNT_MASK

    while remaining >= 0xff do
        buffer.writeu8(out, outNext, 0xff)

        outNext = outNext + 1
        remaining = remaining - 0xff
    end

    if remaining >= 0 then
        buffer.writeu8(out, outNext, remaining)

        outNext = outNext + 1
    end

    buffer.copy(out, outNext, data, nextUnencodedPos)

    outNext = outNext + (dataLen - nextUnencodedPos)

    return out, outNext
end
local function compressString(str, acceleration)
    checkType(str, 'string', 1, 'compressString')

    acceleration = checkAcceleration(acceleration, 2, 'compressString')

    local buf, len = compressBuffer(buffer.fromstring(str), 0, #str, acceleration)

    return buffer.readstring(buf, 0, len)
end
local function expandBuffer(out, maxLen)
    local curLen = buffer.len(out)

    if curLen >= maxLen then
        return nil, 'maximum decompressed length was exceeded'
    end

    local newLen = math.min(maxLen, curLen * 2)
    local newOut = buffer.create(newLen)

    buffer.copy(newOut, 0, out)

    return newOut, newLen
end
local function decompressBuffer(data, dataStart, dataLen, decompressedLen)
    checkData(data, dataStart, dataLen)

    decompressedLen = decompressedLen or -DEFAULT_MAX_BUFFER_SIZE

    checkType(decompressedLen, 'number', 4, 'decompressBuffer')

    local maxLen = math.abs(decompressedLen)
    local outLen = (decompressedLen >= 0) and decompressedLen or DEFAULT_BUFFER_SIZE
    local out, outNext = buffer.create(outLen), 0
    local pos = 0

    while pos < dataLen do
        local token = buffer.readu8(data, pos)

        pos = pos + 1

        local literalCount = rshift(token, MATCH_LEN_BITS)

        if literalCount == LIT_COUNT_MASK then
            repeat
                local lenPart = buffer.readu8(data, pos)

                pos = pos + 1
                literalCount = literalCount + lenPart
            until lenPart < 0xff
        end

        while outNext + literalCount > outLen do
            out, outLen = assert(expandBuffer(out, maxLen))
        end

        buffer.copy(out, outNext, data, pos, literalCount)

        outNext = outNext + literalCount
        pos = pos + literalCount

        if pos >= dataLen then
            break
        end

        local matchLength = band(token, MATCH_LEN_MASK)
        local matchOffset = buffer.readu16(data, pos)

        pos = pos + 2

        if matchLength == MATCH_LEN_MASK then
            repeat
                local lenPart = buffer.readu8(data, pos)

                pos = pos + 1
                matchLength = matchLength + lenPart
            until lenPart < 0xff
        end

        matchLength = matchLength + MIN_MATCH

        while outNext + matchLength > outLen do
            out, outLen = assert(expandBuffer(out, maxLen))
        end
        while matchLength > matchOffset do
            buffer.copy(out, outNext, out, outNext - matchOffset, matchOffset)

            outNext = outNext + matchOffset
            matchLength = matchLength - matchOffset
        end

        buffer.copy(out, outNext, out, outNext - matchOffset, matchLength)

        outNext = outNext + matchLength
    end

    return out, outNext
end
local function decompressString(str, decompressedLen)
    checkType(str, 'string', 1, 'decompressString')

    decompressedLen = decompressedLen or -DEFAULT_MAX_BUFFER_SIZE

    checkType(decompressedLen, 'number', 4, 'decompressBuffer')

    local buf, len = decompressBuffer(buffer.fromstring(str), 0, #str)

    return buffer.readstring(buf, 0, len)
end

return {
    compressBuffer = compressBuffer,
    compressString = compressString,
    compress = compressString,
    decompressBuffer = decompressBuffer,
    decompressString = decompressString,
    decompress = decompressString,
}
