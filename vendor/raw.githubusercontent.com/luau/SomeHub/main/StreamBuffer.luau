local StreamBuffer = {}

StreamBuffer.__index = StreamBuffer

local DEFAULT_CAPACITY = 4096

function StreamBuffer.new(initialCapacity)
    local cap = initialCapacity or DEFAULT_CAPACITY

    return setmetatable({
        buf = buffer.create(cap),
        len = 0,
        cap = cap,
    }, StreamBuffer)
end
function StreamBuffer:reserve(extra)
    local needed = self.len + extra

    if needed <= self.cap then
        return
    end

    local newCap = self.cap

    while newCap < needed do
        newCap *= 2
    end

    local newBuf = buffer.create(newCap)

    buffer.copy(newBuf, 0, self.buf, 0, self.len)

    self.buf = newBuf
    self.cap = newCap
end
function StreamBuffer:allocRegion(size)
    self:reserve(size)

    local base = self.len

    self.len += size

    return base
end
function StreamBuffer:writeu8(v)
    self:reserve(1)
    buffer.writeu8(self.buf, self.len, v)

    self.len += 1
end
function StreamBuffer:writeu16(v)
    self:reserve(2)
    buffer.writeu16(self.buf, self.len, v)

    self.len += 2
end
function StreamBuffer:writei16(v)
    self:reserve(2)
    buffer.writei16(self.buf, self.len, v)

    self.len += 2
end
function StreamBuffer:writeu32(v)
    self:reserve(4)
    buffer.writeu32(self.buf, self.len, v)

    self.len += 4
end
function StreamBuffer:writei32(v)
    self:reserve(4)
    buffer.writei32(self.buf, self.len, v)

    self.len += 4
end
function StreamBuffer:writef32(v)
    self:reserve(4)
    buffer.writef32(self.buf, self.len, v)

    self.len += 4
end
function StreamBuffer:writef64(v)
    self:reserve(8)
    buffer.writef64(self.buf, self.len, v)

    self.len += 8
end
function StreamBuffer:writestring(s)
    local n = #s

    self:reserve(n)
    buffer.writestring(self.buf, self.len, s)

    self.len += n
end
function StreamBuffer:writeLenString(s)
    self:writeu32(#s)
    self:writestring(s)
end
function StreamBuffer:fill(value, count)
    self:reserve(count)
    buffer.fill(self.buf, self.len, value, count)

    self.len += count
end
function StreamBuffer:pokeu8(offset, v)
    buffer.writeu8(self.buf, offset, v)
end
function StreamBuffer:tostring()
    return buffer.readstring(self.buf, 0, self.len)
end

return StreamBuffer
