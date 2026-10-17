local function uniqueName(places, baseName)
    local taken = {}

    for name in places do
        taken[name:lower()] = true
    end

    if not taken[baseName:lower()] then
        return baseName
    end

    local number = 1

    while taken[baseName:lower() .. number] do
        number += 1
    end

    return baseName .. number
end
local function saveWaypoint(self, part)
    local waypoints = self.storage.waypoints
    local places = waypoints:register(tostring(game.PlaceId), {})
    local name = uniqueName(places, part.Name)

    places[name] = self:stringify(part.Position)

    waypoints:save()

    return name
end

return {
    {
        action = 'partname|partpath',
        description = 
[[Opens a window: click a part to see its path & name, then Select Part saves it as a waypoint]],
        run = function(self)
            self.infiniteYield:openPartPath(function(part)
                local name = saveWaypoint(self, part)

                self:notify('Modified Waypoints', 'Created waypoint: ' .. name)
            end)
        end,
    },
}
