local eventBinds = require('../../../commands/systems/eventBinds')
local config = require('../../../framework/config/ui/settings')
local notifier = require('../../notifier')
local widgets = require('./widgets')
local PANEL = config.panel
local VALUE = config.value
local TEXT = config.pages.eventBinds
local lastEventIndex = 1

local function conditionsOf(bind)
    local conditions = {}

    for _, text in bind.conditions or {}do
        table.insert(conditions, tostring(text))
    end

    return conditions
end
local function describeBind(bind)
    local conditions = conditionsOf(bind)

    if #conditions == 0 then
        return bind.command
    end

    return `{bind.command}  [{table.concat(conditions, ', ')}]`
end
local function describeDelay(delay)
    return `{delay}s`
end
local function readDelay(text)
    local digits = text:gsub('%s', ''):gsub('s$', '')

    return tonumber(digits)
end
local function build(page, ctx)
    local events = eventBinds.events
    local eventIndex = math.clamp(lastEventIndex, 1, #events)
    local conditionBoxes = {}
    local names = {}

    for _, event in events do
        table.insert(names, (event.name:gsub('^On', '')))
    end

    local list = widgets.list(page)

    widgets.pageTop(list, nil, ctx.back)

    local selectEvent, setEventCount
    local renderEvent
    local renderBinds

    selectEvent, setEventCount = widgets.choices(list, names, function(index)
        eventIndex = index
        lastEventIndex = index

        renderEvent()
    end, TEXT.columns)

    local function refreshCounts()
        for index, event in events do
            setEventCount(index, #eventBinds.getBinds(event.name))
        end
    end

    local eventHeader = widgets.header(list, '')
    local conditionsGroup = widgets.group(list)
    local commandBox, delayBox, addButton = widgets.formRow(list, TEXT.commandHint, TEXT.delayHint, TEXT.addButton)
    local note = widgets.note(list, '')
    local listHeader = widgets.header(list, '')
    local bindsGroup = widgets.group(list)

    local function currentEvent()
        return events[eventIndex]
    end
    local function refuse(message)
        note.Text = message

        notifier:notify(TEXT.notifyTitle, message)
    end
    local function askUndo(event, index, bind)
        local message = string.format(TEXT.undoMessage, bind.command, event.name)
        local details = {}
        local conditions = conditionsOf(bind)

        if (bind.delay or 0) > 0 then
            table.insert(details, string.format(TEXT.undoDelay, describeDelay(bind.delay)))
        end
        if #conditions > 0 then
            table.insert(details, `[{table.concat(conditions, ', ')}]`)
        end
        if #details > 0 then
            message ..= '\n' .. table.concat(details, '  ')
        end

        notifier:ask(TEXT.undoTitle, message, {
            {
                text = TEXT.undo,
                primary = true,
                onTap = function()
                    if eventBinds.restore(event.name, index, bind) then
                        if bindsGroup.Parent then
                            note.Text = string.format(TEXT.restored, bind.command)

                            refreshCounts()

                            if currentEvent() == event then
                                renderBinds()
                            end
                        end
                    end
                end,
            },
        }, TEXT.undoTime)
    end
    local function renderConditions()
        widgets.clear(conditionsGroup)

        conditionBoxes = {}

        local conditionList = widgets.list(conditionsGroup)

        for index, condition in currentEvent().conditions do
            local _, box = widgets.inputRow(conditionList, condition.label, TEXT.conditionHints[condition.kind] or '', condition.default)

            conditionBoxes[index] = box
        end
    end

    function renderBinds()
        refreshCounts()
        widgets.clear(bindsGroup)

        local event = currentEvent()
        local rows = widgets.list(bindsGroup)
        local binds = eventBinds.getBinds(event.name)

        listHeader.Text = string.format(TEXT.listTitle, event.name) .. (if#binds > 0 then` ({#binds})`else'')

        if #binds == 0 then
            widgets.note(rows, TEXT.empty)

            return
        end

        widgets.note(rows, TEXT.listHint)

        for index, bind in binds do
            local row = widgets.row(rows)

            widgets.label(row, describeBind(bind), VALUE.delayWidth + 2 * PANEL.padding)

            local delayInput = widgets.valueInput(row, describeDelay(bind.delay or 0), VALUE.delayWidth)

            delayInput.FocusLost:Connect(function()
                if not delayInput.Parent then
                    return
                end

                local delay = readDelay(delayInput.Text)

                if delay == nil or delay < 0 then
                    delayInput.Text = describeDelay(bind.delay or 0)

                    refuse(if delay == nil then TEXT.badDelay else TEXT.negativeDelay)

                    return
                end
                if eventBinds.setDelay(event.name, index, delay) then
                    delayInput.Text = describeDelay(delay)
                    note.Text = string.format(TEXT.delayChanged, bind.command, describeDelay(delay))
                end
            end)
            row.Activated:Connect(function()
                local removed = eventBinds.remove(event.name, index)

                if removed then
                    note.Text = string.format(TEXT.removed, removed.command)

                    renderBinds()
                    askUndo(event, index, removed)
                end
            end)
        end
    end
    function renderEvent()
        eventHeader.Text = string.format(TEXT.header, currentEvent().name, currentEvent().description)
        note.Text = ''

        selectEvent(eventIndex)
        renderConditions()
        renderBinds()
    end

    local function addBind()
        local delay = if delayBox.Text == ''then 0 else readDelay(delayBox.Text)

        if delay == nil then
            refuse(TEXT.badDelay)

            return
        end
        if delay < 0 then
            refuse(TEXT.negativeDelay)

            return
        end

        local conditions = {}

        for index, box in conditionBoxes do
            conditions[index] = box.Text
        end

        local event = currentEvent()
        local added, reason = eventBinds.add(event.name, commandBox.Text, delay, conditions)

        if added then
            commandBox.Text = ''

            renderBinds()

            note.Text = string.format(TEXT.added, event.name)
        else
            refuse(reason or TEXT.notAdded)
        end
    end

    addButton.Activated:Connect(addBind)

    for _, box in {commandBox, delayBox}do
        box.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                addBind()
            end
        end)
    end

    renderEvent()
end

return build
