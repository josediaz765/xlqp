local placement = {}

function placement.compute(window, screen, stack, gap)
    local left = window.x.scale * screen.width + window.x.offset
    local right = left + window.width
    local roomRight = screen.width - right - gap
    local roomLeft = left - gap
    local onRight

    if roomRight >= stack.width then
        onRight = true
    elseif roomLeft >= stack.width then
        onRight = false
    else
        onRight = roomRight >= roomLeft
    end

    local x

    if onRight then
        x = {
            scale = window.x.scale,
            offset = window.x.offset + window.width + gap,
        }
    else
        x = {
            scale = window.x.scale,
            offset = window.x.offset - gap,
        }
    end

    local top = window.y.scale * screen.height + window.y.offset
    local bottom = top + window.height
    local visibleCenter = (math.max(top, 0) + math.min(bottom, screen.height)) / 2
    local growsUp = visibleCenter > screen.height / 2
    local y, anchorY, room

    if growsUp then
        if bottom >= screen.height then
            y = {
                scale = 1,
                offset = 0,
            }
        else
            y = {
                scale = window.y.scale,
                offset = window.y.offset + window.height,
            }
        end

        anchorY = 1
        room = math.min(bottom, screen.height)
    else
        if top < 0 then
            y = {
                scale = 0,
                offset = 0,
            }
        else
            y = {
                scale = window.y.scale,
                offset = window.y.offset,
            }
        end

        anchorY = 0
        room = screen.height - math.max(top, 0)
    end

    return {
        x = x,
        y = y,
        anchorX = if onRight then 0 else 1,
        anchorY = anchorY,
        room = math.max(room, 0),
    }
end

return placement
