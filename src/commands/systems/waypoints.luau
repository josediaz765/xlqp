local waypointsData = require('../../storage/data/waypoints')
local privateEnv = require('../../framework/environment/private')
local playerService = require('../../framework/services/playerService')
local stringifier = require('../../utils/stringifier')
local SHOWN_GARBAGE = 'showingWaypoints'
local garbages = privateEnv.iyGarbages or {}

privateEnv.iyGarbages = garbages

local waypoints = {}

local function placeKey()
    return tostring(game.PlaceId)
end
local function getPlace(create)
    if create then
        return waypointsData:register(placeKey(), {})
    end

    local place = waypointsData:getValue(placeKey())

    return if type(place) == 'table'then place else nil
end
local function countEntries(place)
    local count = 0

    if type(place) == 'table' then
        for _ in place do
            count += 1
        end
    end

    return count
end
local function readPosition(coords)
    if type(coords) ~= 'string' then
        return nil
    end

    local success, position = pcall(stringifier.unstringify, stringifier, coords, 'Vector3')

    if success and typeof(position) == 'Vector3' then
        return position
    end

    return nil
end

function waypoints.list()
    local list = {}

    for name, coords in getPlace() or {}do
        local position = readPosition(coords)

        if position then
            table.insert(list, {
                name = name,
                position = position,
            })
        end
    end

    table.sort(list, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    return list
end
function waypoints.find(name)
    local lowered = name:lower()

    for _, waypoint in waypoints.list()do
        if waypoint.name:lower() == lowered then
            return waypoint
        end
    end

    return nil
end
function waypoints.count()
    return countEntries(getPlace())
end
function waypoints.countAll()
    local total = 0

    for _, place in waypointsData:getData()do
        total += countEntries(place)
    end

    return total
end
function waypoints.save(name, position)
    local place = (getPlace(true))
    local lowered = name:lower()
    local replaced = false

    for storedName in place do
        if storedName:lower() == lowered then
            place[storedName] = nil
            replaced = true
        end
    end

    place[name] = (stringifier:stringify(position))

    waypointsData:save()

    return replaced
end
function waypoints.remove(name)
    local place = getPlace()
    local lowered = name:lower()
    local removed = false

    if type(place) == 'table' then
        for storedName in place do
            if storedName:lower() == lowered then
                place[storedName] = nil
                removed = true
            end
        end
    end
    if removed then
        waypointsData:save()
    end

    return removed
end
function waypoints.clearPlace()
    local count = waypoints.count()

    waypointsData:setValue(placeKey(), nil)
    waypointsData:save()

    return count
end
function waypoints.clearAll()
    local total = 0

    for key, place in waypointsData:getData()do
        total += countEntries(place)

        waypointsData:setValue(key, nil)
    end

    waypointsData:save()

    return total
end
function waypoints.format(position)
    return `({math.round(position.X)}, {math.round(position.Y)}, {math.round(position.Z)})`
end
function waypoints.parsePosition(text)
    local numbers = {}

    for piece in text:gmatch('[^%s,;]+')do
        local number = tonumber(piece)

        if number == nil or number ~= number or math.abs(number) == math.huge then
            return nil
        end

        table.insert(numbers, number)
    end

    if #numbers ~= 3 then
        return nil
    end

    return Vector3.new(numbers[1], numbers[2], numbers[3])
end
function waypoints.go(waypoint, mode, speed)
    if mode == 'tween' then
        speed = if typeof(speed) == 'number'then speed else nil

        local tween = playerService:tweenTeleportTo({
            target = CFrame.new(waypoint.position),
            speed = speed or privateEnv.tweenSpeed,
        })

        return tween ~= nil
    end
    if mode == 'walk' then
        local humanoid = playerService:unseat()

        if not humanoid then
            return false
        end

        humanoid:MoveTo(waypoint.position)

        return true
    end

    return playerService:teleportTo(CFrame.new(waypoint.position))
end
function waypoints.isShown()
    return garbages[SHOWN_GARBAGE] ~= nil
end
function waypoints.hide()
    local markers = garbages[SHOWN_GARBAGE]

    if markers == nil then
        return false
    end

    garbages[SHOWN_GARBAGE] = nil

    for _, marker in markers do
        marker:Destroy()
    end

    return true
end

local function createMarker(waypoint)
    local part = Instance.new('Part')

    part.Size = Vector3.new(5, 5, 5)
    part.CFrame = CFrame.new(waypoint.position)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Parent = workspace

    local box = Instance.new('BoxHandleAdornment')

    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = part.Size
    box.Parent = part

    local billboard = Instance.new('BillboardGui')

    billboard.Adornee = part
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(160, 30)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.Parent = part

    local label = Instance.new('TextLabel')

    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = waypoint.name
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeTransparency = 0
    label.TextScaled = true
    label.Parent = billboard

    return part
end

function waypoints.show()
    waypoints.hide()

    local markers = {}
    local list = waypoints.list()

    for _, waypoint in list do
        table.insert(markers, createMarker(waypoint))
    end

    garbages[SHOWN_GARBAGE] = markers

    return #list
end
function waypoints.refreshMarkers()
    if waypoints.isShown() then
        waypoints.show()
    end
end

return waypoints
