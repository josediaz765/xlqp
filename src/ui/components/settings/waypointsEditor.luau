local waypoints = require('../../../commands/systems/waypoints')
local playerService = require('../../../framework/services/playerService')
local config = require('../../../framework/config/ui/settings')
local notifier = require('../../notifier')
local widgets = require('./widgets')
local PANEL = config.panel
local BOX = config.box
local VALUE = config.value
local TEXT = config.pages.waypoints
local lastModeIndex = 1

local function trim(text)
    return text:match('^%s*(.-)%s*$') or ''
end
local function build(page, ctx)
    local modes = TEXT.modes
    local modeIndex = math.clamp(lastModeIndex, 1, #modes)
    local list = widgets.list(page)

    widgets.pageTop(list, TEXT.title, ctx.back)
    widgets.header(list, TEXT.newTitle)

    local nameBox, positionBox, addButton = widgets.formRow(list, TEXT.nameHint, TEXT.positionHint, TEXT.addButton, VALUE.positionWidth)
    local note = widgets.note(list, TEXT.formHint)

    widgets.header(list, TEXT.modeTitle)

    local labels = {}

    for _, mode in modes do
        table.insert(labels, mode.label)
    end

    local selectMode = widgets.choices(list, labels, function(index)
        modeIndex = index
        lastModeIndex = index
    end, #modes)

    selectMode(modeIndex)

    local markersRow = widgets.row(list)

    widgets.label(markersRow, TEXT.markers, BOX.size + 2 * PANEL.padding)

    local _, markersFill = widgets.box(markersRow)
    local listHeader = widgets.header(list, '')
    local waypointsGroup = widgets.group(list)

    widgets.header(list, TEXT.clearTitle)

    local clearGameRow = widgets.row(list)

    widgets.label(clearGameRow, TEXT.clearGame, 0)

    local clearAllRow = widgets.row(list)

    widgets.label(clearAllRow, TEXT.clearAll, 0)

    local renderWaypoints

    local function refuse(message)
        note.Text = message

        notifier:notify(TEXT.notifyTitle, message)
    end
    local function drawMarkersSwitch()
        markersFill.Visible = waypoints.isShown()
    end
    local function goTo(waypoint)
        local mode = modes[modeIndex].mode
        local where = waypoints.format(waypoint.position)

        if not waypoints.go(waypoint, mode) then
            refuse(TEXT.cantGo)

            return
        end

        local message = if mode == 'tween'
            then TEXT.wentTween
            elseif mode == 'walk'
            then TEXT.wentWalk
            else TEXT.went

        note.Text = string.format(message, waypoint.name, where)
    end
    local function askUndo(waypoint)
        notifier:ask(TEXT.undoTitle, string.format(TEXT.undoMessage, waypoint.name, waypoints.format(waypoint.position)), {
            {
                text = TEXT.undo,
                primary = true,
                onTap = function()
                    if waypoints.find(waypoint.name) then
                        notifier:notify(TEXT.notifyTitle, string.format(TEXT.nameTaken, waypoint.name))

                        return
                    end

                    waypoints.save(waypoint.name, waypoint.position)
                    waypoints.refreshMarkers()

                    if waypointsGroup.Parent then
                        note.Text = string.format(TEXT.restored, waypoint.name)

                        renderWaypoints()
                    end
                end,
            },
        }, TEXT.undoTime)
    end
    local function removeWaypoint(waypoint)
        if not waypoints.remove(waypoint.name) then
            return
        end

        waypoints.refreshMarkers()

        note.Text = string.format(TEXT.removed, waypoint.name)

        renderWaypoints()
        askUndo(waypoint)
    end

    function renderWaypoints()
        widgets.clear(waypointsGroup)

        local waypointList = waypoints.list()
        local rows = widgets.list(waypointsGroup)

        listHeader.Text = TEXT.listTitle .. (if#waypointList > 0 then` ({#waypointList})`else'')

        drawMarkersSwitch()

        if #waypointList == 0 then
            widgets.note(rows, TEXT.empty)

            return
        end

        widgets.note(rows, TEXT.listHint)

        for _, waypoint in waypointList do
            local row = widgets.row(rows)
            local delete = widgets.rowButton(row, TEXT.delete, PANEL.padding, VALUE.buttonWidth)

            widgets.label(row, waypoint.name, VALUE.buttonWidth + 2 * PANEL.padding)
            row.Activated:Connect(function()
                goTo(waypoint)
            end)
            delete.Activated:Connect(function()
                removeWaypoint(waypoint)
            end)
        end
    end

    local function addWaypoint()
        local name = trim(nameBox.Text)

        if name == '' then
            refuse(TEXT.missingName)

            return
        end

        local position
        local text = trim(positionBox.Text)

        if text == '' then
            local root = playerService:getRootPart()

            if not root then
                refuse(TEXT.noCharacter)

                return
            end

            position = root.Position
        else
            position = waypoints.parsePosition(text)

            if not position then
                refuse(TEXT.badPosition)

                return
            end
        end

        local replaced = waypoints.save(name, position)

        waypoints.refreshMarkers()

        nameBox.Text = ''
        positionBox.Text = ''
        note.Text = string.format(if replaced then TEXT.updated else TEXT.saved, name, waypoints.format(position))

        renderWaypoints()
    end

    addButton.Activated:Connect(addWaypoint)

    for _, box in {nameBox, positionBox}do
        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                addWaypoint()
            end
        end)
    end

    markersRow.Activated:Connect(function()
        if waypoints.isShown() then
            waypoints.hide()
        elseif waypoints.count() == 0 then
            refuse(TEXT.noMarkers)
        else
            waypoints.show()
        end

        drawMarkersSwitch()
    end)

    local function askClear(everyGame)
        local count = if everyGame then waypoints.countAll()else waypoints.count()

        if count == 0 then
            note.Text = TEXT.nothingToClear

            return
        end

        local message = string.format(if everyGame then TEXT.confirmAll else TEXT.confirmGame, count)

        notifier:ask(TEXT.confirmTitle, message, {
            {
                text = TEXT.confirmCancel,
            },
            {
                text = TEXT.confirmClear,
                primary = true,
                onTap = function()
                    local cleared = if everyGame then waypoints.clearAll()else waypoints.clearPlace()

                    waypoints.hide()

                    if waypointsGroup.Parent then
                        note.Text = string.format(TEXT.cleared, cleared)

                        renderWaypoints()
                    end
                end,
            },
        })
    end

    clearGameRow.Activated:Connect(function()
        askClear(false)
    end)
    clearAllRow.Activated:Connect(function()
        askClear(true)
    end)
    renderWaypoints()
end

return build
