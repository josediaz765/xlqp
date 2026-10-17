local createService = require('../../services/createService')
local assetsService = require('../../services/assetsService')
local themeService = require('../../services/themeService')
local keyboardService = require('../../../framework/services/keyboardService')
local config = require('../../../framework/config/ui/settings')
local PANEL = config.panel
local ROW = config.row
local BOX = config.box
local VALUE = config.value
local TEXT = config.textSizes
local BADGE = config.badge
local widgets = {}

local function paintRow(row, stripe, hovered)
    themeService:updateObjectProperties(row, {
        BackgroundColor3 = if hovered then'Colors.Buttons.Holding'else'Colors.Buttons.Default',
    })

    row.BackgroundTransparency = if hovered then 0 else stripe
end

function widgets.page(holder, name, position)
    return createService.new('ScrollingFrame', name, holder, {
        Active = true,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ElasticBehavior = Enum.ElasticBehavior.Never,
        Position = position,
        ScrollBarThickness = PANEL.scrollBarThickness,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Size = UDim2.fromScale(1, 1),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
            ScrollBarImageColor3 = 'Colors.ScrollBar.Thumb',
        },
        createService.new('UIPadding', {
            PaddingLeft = UDim.new(0, PANEL.padding),
            PaddingRight = UDim.new(0, PANEL.padding),
            PaddingTop = UDim.new(0, PANEL.padding),
            PaddingBottom = UDim.new(0, PANEL.padding),
        }),
        createService.new('UIListLayout', {
            Padding = UDim.new(0, PANEL.rowGap),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
end

local function forgetTree(root)
    themeService:removeObject(root)

    for _, descendant in root:GetDescendants()do
        themeService:removeObject(descendant)
    end
end

function widgets.clear(parent)
    for _, child in parent:GetChildren()do
        if not (child:IsA('UIListLayout') or child:IsA('UIPadding')) then
            forgetTree(child)
            child:Destroy()
        end
    end
end
function widgets.list(parent)
    return {
        parent = parent,
        order = 0,
        index = 0,
    }
end
function widgets.group(list)
    list.order += 1

    return createService.new('Frame', 'Group', list.parent, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, 0),
        createService.new('UIListLayout', {
            Padding = UDim.new(0, PANEL.rowGap),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
end
function widgets.header(list, title)
    list.order += 1

    list.index = 0

    return createService.new('TextLabel', 'Header', list.parent, {
        BackgroundTransparency = 1,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, PANEL.headerHeight),
        Text = title,
        TextSize = TEXT.header,
        TextXAlignment = Enum.TextXAlignment.Left,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Darker',
        },
    })
end
function widgets.row(list)
    list.order += 1
    list.index += 1

    local stripe = if list.index % 2 == 1 then PANEL.stripeTransparency else 1
    local row = createService.new('TextButton', 'Option', list.parent, {
        AutoButtonColor = false,
        BackgroundTransparency = stripe,
        BorderSizePixel = 0,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, PANEL.rowHeight),
        Text = '',
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
    })

    row.MouseEnter:Connect(function()
        paintRow(row, stripe, true)
    end)
    row.MouseLeave:Connect(function()
        paintRow(row, stripe, false)
    end)

    return row
end
function widgets.pageTop(list, title, onBack)
    local back = widgets.row(list)

    back.Name = 'BackRow'

    widgets.icon(back, config.pages.backIcon)
    widgets.label(back, config.pages.back, 0)
    back.Activated:Connect(onBack)

    if title then
        widgets.header(list, title)
    end
end
function widgets.label(row, text, rightSpace, color)
    return createService.new('TextLabel', 'Label', row, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(ROW.labelInset, 0),
        Size = UDim2.new(1, -(ROW.labelInset + rightSpace), 1, 0),
        Text = text,
        TextSize = TEXT.label,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        ThemeTag = {
            Font = 'Font.Normal',
            TextColor3 = color or 'Colors.Text.Default',
        },
    })
end
function widgets.icon(row, iconName)
    local icon = createService.new('ImageLabel', 'Icon', row, {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, ROW.iconInset, 0.5, 0),
        Size = UDim2.fromOffset(ROW.iconSize, ROW.iconSize),
        ThemeTag = {
            ImageColor3 = 'Colors.Icons',
        },
    })

    assetsService:loadImage(icon, iconName)

    return icon
end
function widgets.chevron(row)
    local icon = createService.new('ImageLabel', 'Chevron', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -PANEL.padding, 0.5, 0),
        Rotation = 180,
        Size = UDim2.fromOffset(ROW.chevronSize, ROW.chevronSize),
        ThemeTag = {
            ImageColor3 = 'Colors.Text.Darker',
        },
    })

    assetsService:loadImage(icon, config.pages.backIcon)

    return icon
end
function widgets.rowButton(row, text, rightOffset, width)
    local button = createService.new('TextButton', 'RowButton', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -rightOffset, 0.5, 0),
        Size = UDim2.fromOffset(width, VALUE.height + 4),
        Text = text,
        TextSize = TEXT.value,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })

    button.MouseEnter:Connect(function()
        themeService:updateObjectProperties(button, {
            BackgroundColor3 = 'Colors.Primary',
        })
    end)
    button.MouseLeave:Connect(function()
        themeService:updateObjectProperties(button, {
            BackgroundColor3 = 'Colors.Background',
        })
    end)

    return button
end
function widgets.box(row)
    local box = createService.new('Frame', 'Box', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -PANEL.padding, 0.5, 0),
        Size = UDim2.fromOffset(BOX.size, BOX.size),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, BOX.cornerRadius),
        }),
        createService.new('UIStroke', {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1,
            ThemeTag = {
                Color = 'Colors.Border.Default',
            },
        }),
    })
    local fill = createService.new('Frame', 'Fill', box, {
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(BOX.inset, BOX.inset),
        Size = UDim2.new(1, -2 * BOX.inset, 1, -2 * BOX.inset),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Primary',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, BOX.fillCornerRadius),
        }),
    })

    return box, fill
end
function widgets.value(row, text, width)
    local value = createService.new('Frame', 'Value', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        BorderSizePixel = 0,
        Position = UDim2.new(1, -PANEL.padding, 0.5, 0),
        Size = UDim2.fromOffset(width, VALUE.height),
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })
    local label = createService.new('TextLabel', 'Text', value, {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = text,
        TextSize = TEXT.value,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
    })

    return value, label
end
function widgets.valueInput(row, text, width)
    return createService.new('TextBox', 'ValueInput', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Position = UDim2.new(1, -PANEL.padding, 0.5, 0),
        Size = UDim2.fromOffset(width, VALUE.height),
        Text = text,
        TextSize = TEXT.value,
        TextXAlignment = Enum.TextXAlignment.Center,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })
end
function widgets.keybind(row, bindingName, onChanged)
    local value, text = widgets.value(row, '', VALUE.keybindWidth)
    local cancelWait = nil

    local function refresh()
        local waiting = cancelWait ~= nil

        text.Text = if waiting then'press a key'else keyboardService:getBindingName(bindingName)

        themeService:updateObjectProperties(value, {
            BackgroundColor3 = if waiting then'Colors.Primary'else'Colors.Buttons.Default',
        })
    end
    local function stop()
        if cancelWait then
            local cancel = cancelWait

            cancelWait = nil

            cancel()
        end

        refresh()
    end

    row.Activated:Connect(function()
        if cancelWait then
            stop()

            return
        end

        cancelWait = keyboardService:capture(function(keyCode)
            cancelWait = nil

            keyboardService:setBinding(bindingName, keyCode)
            refresh()

            if onChanged then
                onChanged()
            end
        end, function()
            cancelWait = nil

            refresh()
        end)

        refresh()
    end)
    refresh()

    return refresh, stop
end
function widgets.textBox(list, placeholder)
    list.order += 1

    return createService.new('TextBox', 'Input', list.parent, {
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        LayoutOrder = list.order,
        PlaceholderText = placeholder,
        Size = UDim2.new(1, 0, 0, PANEL.rowHeight),
        Text = '',
        TextSize = TEXT.value,
        TextXAlignment = Enum.TextXAlignment.Left,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Buttons.Default',
            Font = 'Font.MonoSpace',
            PlaceholderColor3 = 'Colors.Text.Darker',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UIPadding', {
            PaddingLeft = UDim.new(0, ROW.labelInset / 2),
            PaddingRight = UDim.new(0, PANEL.padding),
        }),
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })
end

local function countBadge(button)
    return createService.new('TextLabel', 'Badge', button, {
        AnchorPoint = Vector2.new(1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Position = UDim2.new(1, BADGE.overhang, 0, -BADGE.overhang),
        Size = UDim2.fromOffset(0, BADGE.height),
        Text = '',
        TextSize = TEXT.badge,
        Visible = false,
        ZIndex = button.ZIndex + 1,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Primary',
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, BADGE.height / 2),
        }),
        createService.new('UIPadding', {
            PaddingLeft = UDim.new(0, 3),
            PaddingRight = UDim.new(0, 3),
        }),
        createService.new('UIStroke', {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Thickness = 1,
            ThemeTag = {
                Color = 'Colors.Background',
            },
        }),
    })
end

function widgets.choices(list, labels, onSelect, columns)
    list.order += 1

    local gap = PANEL.rowGap
    local frame = createService.new('Frame', 'Choices', list.parent, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, 0),
        createService.new('UIGridLayout', {
            CellPadding = UDim2.fromOffset(gap, gap),
            CellSize = UDim2.new(1 / columns, -gap * (columns - 1) / columns - 1, 0, PANEL.rowHeight - 3),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })
    local buttons = {}
    local badges = {}

    local function select(index)
        for position, button in buttons do
            themeService:updateObjectProperties(button, {
                BackgroundColor3 = if position == index then'Colors.Primary'else'Colors.Buttons.Default',
            })
        end
    end

    for index, label in labels do
        local button = createService.new('TextButton', 'Choice', frame, {
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Text = label,
            TextSize = TEXT.value,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ThemeTag = {
                BackgroundColor3 = 'Colors.Buttons.Default',
                Font = 'Font.MonoSpace',
                TextColor3 = 'Colors.Text.Default',
            },
            createService.new('UICorner', {
                CornerRadius = UDim.new(0, VALUE.cornerRadius),
            }),
        })

        buttons[index] = button
        badges[index] = countBadge(button)

        button.Activated:Connect(function()
            select(index)
            onSelect(index)
        end)
    end

    local function setCount(index, count)
        local badge = badges[index]

        if not badge then
            return
        end

        badge.Text = tostring(count)
        badge.Visible = count > 0
    end

    return select, setCount
end
function widgets.inputRow(list, label, placeholder, text)
    local row = widgets.row(list)

    widgets.label(row, label, VALUE.inputWidth + 2 * PANEL.padding)

    local input = createService.new('TextBox', 'Input', row, {
        AnchorPoint = Vector2.new(1, 0.5),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = placeholder,
        Position = UDim2.new(1, -PANEL.padding, 0.5, 0),
        Size = UDim2.fromOffset(VALUE.inputWidth, VALUE.height),
        Text = text or '',
        TextSize = TEXT.value,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Background',
            Font = 'Font.MonoSpace',
            PlaceholderColor3 = 'Colors.Text.Darker',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UIPadding', {
            PaddingLeft = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
        }),
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })

    return row, input
end
function widgets.formRow(list, commandHint, delayHint, addLabel, secondWidth)
    list.order += 1

    local gap = PANEL.rowGap
    local addWidth = VALUE.addWidth
    local delayWidth = secondWidth or VALUE.formDelayWidth
    local holder = createService.new('Frame', 'Form', list.parent, {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, PANEL.rowHeight),
    })

    local function box(name, hint, anchor, position, size)
        return createService.new('TextBox', name, holder, {
            AnchorPoint = anchor,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            PlaceholderText = hint,
            Position = position,
            Size = size,
            Text = '',
            TextSize = TEXT.value,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            ThemeTag = {
                BackgroundColor3 = 'Colors.Buttons.Default',
                Font = 'Font.MonoSpace',
                PlaceholderColor3 = 'Colors.Text.Darker',
                TextColor3 = 'Colors.Text.Default',
            },
            createService.new('UIPadding', {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 4),
            }),
            createService.new('UICorner', {
                CornerRadius = UDim.new(0, VALUE.cornerRadius),
            }),
        })
    end

    local commandBox = box('Command', commandHint, Vector2.zero, UDim2.fromOffset(0, 0), UDim2.new(1, 
-(addWidth + delayWidth + 2 * gap), 1, 0))
    local delayBox = box('Delay', delayHint, Vector2.new(1, 0), UDim2.new(1, -(addWidth + gap), 0, 0), UDim2.new(0, delayWidth, 1, 0))
    local addButton = createService.new('TextButton', 'Add', holder, {
        AnchorPoint = Vector2.new(1, 0),
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, addWidth, 1, 0),
        Text = addLabel,
        TextSize = TEXT.label,
        ThemeTag = {
            BackgroundColor3 = 'Colors.Primary',
            Font = 'Font.Normal',
            TextColor3 = 'Colors.Text.Default',
        },
        createService.new('UICorner', {
            CornerRadius = UDim.new(0, VALUE.cornerRadius),
        }),
    })

    return commandBox, delayBox, addButton
end
function widgets.footer(list, text)
    list.order += 1

    return createService.new('TextLabel', 'Footer', list.parent, {
        BackgroundTransparency = 1,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, PANEL.headerHeight),
        Text = text,
        TextSize = TEXT.footer,
        TextXAlignment = Enum.TextXAlignment.Center,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Darker',
        },
    })
end
function widgets.note(list, text)
    list.order += 1

    return createService.new('TextLabel', 'Note', list.parent, {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = list.order,
        Size = UDim2.new(1, 0, 0, 0),
        Text = text,
        TextSize = TEXT.value,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ThemeTag = {
            Font = 'Font.MonoSpace',
            TextColor3 = 'Colors.Text.Darker',
        },
        createService.new('UIPadding', {
            PaddingLeft = UDim.new(0, ROW.labelInset),
        }),
    })
end

return widgets
