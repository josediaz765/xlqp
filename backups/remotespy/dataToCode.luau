local assert, type, typeof, rawset, getmetatable, tostring = assert, type, typeof, rawset, getmetatable, tostring
local print, warn, pack, unpack, next = print, warn, table.pack, unpack, next
local IsSharedFrozen, SharedSize = SharedTable.isFrozen, SharedTable.size
local bufftostring, fromstring, readu8 = buffer.tostring, buffer.fromstring, buffer.readu8
local isfrozen, concat = table.isfrozen, table.concat
local FindService = game.FindService
local info = debug.info
local IsClient = game:GetService('RunService'):IsClient()
local Players = game:GetService('Players')
local inf, neginf = math.huge, -math.huge
local DefaultMethods = {}
local Methods = setmetatable({}, {__index = DefaultMethods})
local Class = {
    Methods = Methods,
    __tostringUnsupported = false,
    __Serializeinf = false,
}
local Keywords = {
    ['local'] = '"local"',
    ['function'] = '"function"',
    ['and'] = '"and"',
    ['break'] = '"break"',
    ['not'] = '"not"',
    ['or'] = '"or"',
    ['else'] = '"else"',
    ['elseif'] = '"elseif"',
    ['if'] = '"if"',
    ['then'] = '"then"',
    ['until'] = '"until"',
    ['repeat'] = '"repeat"',
    ['while'] = '"while"',
    ['do'] = '"do"',
    ['for'] = '"for"',
    ['in'] = '"in"',
    ['end'] = '"end"',
    ['return'] = '"return"',
    ['true'] = '"true"',
    ['false'] = '"false"',
    ['nil'] = '"nil"',
}
local islclosure = islclosure or function(Function)
    return info(Function, 'l') ~= -1
end
local DefaultVectors, DefaultCFrames = {}, {}

do
    local function ExtractTypes(From, Path, DataType, Storage)
        local Storage = Storage or setmetatable({}, {
            __mode = 'k',
        })

        for i, v in next, From do
            if typeof(v) == DataType and not Storage[v] and type(i) == 'string' and not Keywords[i] and not i:match('[a-Z_][a-Z_0-9]') then
                Storage[v] = Path .. '.' .. i
            end
        end

        return Storage
    end

    ExtractTypes(vector, 'vector', 'Vector3', DefaultVectors)
    ExtractTypes(Vector3, 'Vector3', 'Vector3', DefaultVectors)
    ExtractTypes(CFrame, 'CFrame', 'CFrame', DefaultCFrames)

    Class.DefaultTypes = {
        Vector3 = DefaultVectors,
        CFrame = DefaultCFrames,
    }
end

local function Serialize(DataStructure, format, indents, CyclicList, InComment)
    local DataHandler = Methods[typeof(DataStructure)]

    return DataHandler and DataHandler(DataStructure, format, indents, CyclicList, InComment) or 'nil --[' .. (not InComment and '' or '=') .. '[ Unsupported Data Type | ' .. typeof(DataStructure) .. (not Class.__tostringUnsupported and '' or ' | ' .. tostring(DataStructure)) .. ' ]' .. (not InComment and '' or '=') .. ']'
end
local function ValidateSharedTableIndex(Index)
    local IsKeyword = type(Index) == 'number' and Index or Keywords[Index]

    if not IsKeyword then
        if Index ~= '' then
            local IndexBuffer = fromstring(Index)
            local FirstByte = readu8(IndexBuffer, 0)

            if FirstByte >= 97 and FirstByte <= 122 or FirstByte >= 65 and FirstByte <= 90 or FirstByte == 95 then
                for i = 1, #Index - 1 do
                    local Byte = readu8(IndexBuffer, i)

                    if not ((Byte >= 97 and Byte <= 122) or (Byte >= 65 and Byte <= 90) or Byte == 95 or (Byte >= 48 and Byte <= 57)) then
                        return '[' .. Methods.string(Index) .. '] = '
                    end
                end

                return Index .. ' = '
            end

            return '[' .. Methods.string(Index) .. '] = '
        end

        return '[""] = '
    end

    return '[' .. IsKeyword .. '] = '
end
local function ValidateIndex(Index)
    local IndexType = type(Index)
    local IsNumber = IndexType == 'number'

    if IsNumber or IndexType == 'string' then
        local IsKeyword = IsNumber and Index or Keywords[Index]

        if not IsKeyword then
            if Index ~= '' then
                local IndexBuffer = fromstring(Index)
                local FirstByte = readu8(IndexBuffer, 0)

                if FirstByte >= 97 and FirstByte <= 122 or FirstByte >= 65 and FirstByte <= 90 or FirstByte == 95 then
                    for i = 1, #Index - 1 do
                        local Byte = readu8(IndexBuffer, i)

                        if not ((Byte >= 97 and Byte <= 122) or (Byte >= 65 and Byte <= 90) or Byte == 95 or (Byte >= 48 and Byte <= 57)) then
                            return '[' .. Methods.string(Index) .. '] = '
                        end
                    end

                    return Index .. ' = '
                end

                return '[' .. Methods.string(Index) .. '] = '
            end

            return '[""] = '
        end

        return '[' .. IsKeyword .. '] = '
    end

    return '[' .. (IndexType ~= 'table' and Serialize(Index, false, '') or '"<Table> (table: ' .. (getmetatable(Index) == nil and tostring(Index):sub(8) or '@metatable') .. ')"') .. '] = '
end

function DefaultMethods.Axes(Axes)
    return 'Axes.new(' .. concat({
        Axes.X and 'Enum.Axis.X' or nil,
        Axes.Y and 'Enum.Axis.Y' or nil,
        Axes.Z and 'Enum.Axis.Z' or nil,
    }, ', ') .. ')'
end
function DefaultMethods.BrickColor(Color)
    return 'BrickColor.new(' .. Color.Number .. ')'
end
function DefaultMethods.CFrame(CFrame)
    local Generation = DefaultCFrames[CFrame]

    if not Generation then
        local SerializeNumber = Methods.number
        local x, y, z, R00, R01, R02, R10, R11, R12, R20, R21, R22 = CFrame:GetComponents()

        return 'CFrame.new(' .. SerializeNumber(x) .. ', ' .. SerializeNumber(y) .. ', ' .. SerializeNumber(z) .. ', ' .. SerializeNumber(R00) .. ', ' .. SerializeNumber(R01) .. ', ' .. SerializeNumber(R02) .. ', ' .. SerializeNumber(R10) .. ', ' .. SerializeNumber(R11) .. ', ' .. SerializeNumber(R12) .. ', ' .. SerializeNumber(R20) .. ', ' .. SerializeNumber(R21) .. ', ' .. SerializeNumber(R22) .. ')'
    end

    return Generation
end

do
    local DefaultCatalogSearchParams = CatalogSearchParams.new()

    function DefaultMethods.CatalogSearchParams(Params, format, indents)
        if DefaultCatalogSearchParams ~= Params then
            local formatspace = format and '\n' .. indents or ' '
            local SerializeString = Methods.string
            local SearchKeyword = Params.SearchKeyword
            local MinPrice = Params.MinPrice
            local MaxPrice = Params.MaxPrice
            local SortType = Params.SortType
            local SortAggregation = Params.SortAggregation
            local CategoryFilter = Params.CategoryFilter
            local SalesTypeFilter = Params.SalesTypeFilter
            local BundleTypes = Params.BundleTypes
            local AssetTypes = Params.AssetTypes
            local CreatorName = Params.CreatorName
            local CreatorType = Params.CreatorType
            local CreatorId = Params.CreatorId
            local Limit = Params.Limit

            return '(function(Param : CatalogSearchParams)' .. formatspace .. (SearchKeyword ~= '' and '\tParam.SearchKeyword = ' .. SerializeString(SearchKeyword) .. formatspace or '') .. (MinPrice ~= 0 and '\tParam.MinPrice = ' .. MinPrice .. formatspace or '') .. (MaxPrice ~= 2147483647 and '\tParam.MaxPrice = ' .. MaxPrice .. formatspace or '') .. (SortType ~= Enum.CatalogSortType.Relevance and '\tParam.SortType = Enum.CatalogSortType.' .. SortType.Name .. formatspace or '') .. (SortAggregation ~= Enum.CatalogSortAggregation.AllTime and '\tParam.SortAggregation = Enum.CatalogSortAggregation.' .. SortAggregation.Name .. formatspace or '') .. (CategoryFilter ~= Enum.CatalogCategoryFilter.None and '\tParam.CategoryFilter = Enum.CatalogCategoryFilter.' .. CategoryFilter.Name .. formatspace or '') .. (SalesTypeFilter ~= Enum.SalesTypeFilter.All and '\tParam.SalesTypeFilter = Enum.SalesTypeFilter.' .. SalesTypeFilter.Name .. formatspace or '') .. (#BundleTypes > 0 and '\tParam.BundleTypes = ' .. Methods.table(BundleTypes, false, '') .. formatspace or '') .. (#AssetTypes > 0 and '\tParam.AssetTypes = ' .. Methods.table(AssetTypes, false, '') .. formatspace or '') .. (Params.IncludeOffSale and '\tParams.IncludeOffSale = true' .. formatspace or '') .. (CreatorName ~= '' and '\tParams.CreatorName = ' .. SerializeString(CreatorName) .. formatspace or '') .. (CreatorType ~= Enum.CreatorTypeFilter.All and '\tParam.CreatorType = Enum.CreatorTypeFilter.' .. CreatorType.Name .. formatspace or '') .. (CreatorId ~= 0 and '\tParams.CreatorId = ' .. CreatorId .. formatspace or '') .. (Limit ~= 30 and '\tParams.Limit = ' .. Limit .. formatspace or '') .. '\treturn Params' .. formatspace .. 'end)(CatalogSearchParams.new())'
        end

        return 'CatalogSearchParams.new()'
    end
end

function DefaultMethods.Color3(Color)
    local SerializeNumber = Methods.number

    return 'Color3.new(' .. SerializeNumber(Color.R) .. ', ' .. SerializeNumber(Color.G) .. ', ' .. SerializeNumber(Color.B) .. ')'
end
function DefaultMethods.ColorSequence(Sequence)
    local SerializeColorSequenceKeypoint = Methods.ColorSequenceKeypoint
    local Keypoints = Sequence.Keypoints
    local Size = #Keypoints
    local Serialized = ''

    for i = 1, Size - 1 do
        Serialized ..= SerializeColorSequenceKeypoint(Keypoints[i]) .. ', '
    end

    return 'ColorSequence.new({' .. Serialized .. SerializeColorSequenceKeypoint(Keypoints[Size]) .. '})'
end
function DefaultMethods.ColorSequenceKeypoint(KeyPoint)
    return 'ColorSequenceKeypoint.new(' .. Methods.number(KeyPoint.Time) .. ', ' .. Methods.Color3(KeyPoint.Value) .. ')'
end
function DefaultMethods.Content(content)
    local Uri = content.Uri

    return Uri and 'Content.fromUri(' .. Uri .. ')' or 'Content.none'
end
function DefaultMethods.DateTime(Date)
    return 'DateTime.fromUnixTimestampMillis(' .. Date.UnixTimestampMillis .. ')'
end
function DefaultMethods.DockWidgetPluginGuiInfo(Dock)
    local ArgumentFunction = tostring(Dock):gmatch(':([%w%-]+)')

    return 'DockWidgetPluginGuiInfo.new(Enum.InitialDockState.' .. ArgumentFunction() .. ', ' .. (ArgumentFunction() == '1' and 'true' or 'false') .. ', ' .. (ArgumentFunction() == '1' and 'true' or 'false') .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ', ' .. ArgumentFunction() .. ')'
end
function DefaultMethods.Enum(Enum)
    return 'Enums.' .. tostring(Enum)
end

do
    local Enums = {}

    for i, v in Enum:GetEnums()do
        Enums[v] = 'Enum.' .. tostring(v)
    end

    function DefaultMethods.EnumItem(Item)
        return Enums[Item.EnumType] .. '.' .. Item.Name
    end
end

function DefaultMethods.Enums()
    return 'Enums'
end
function DefaultMethods.Faces(Faces)
    return 'Faces.new(' .. concat({
        Faces.Top and 'Enum.NormalId.Top' or nil,
        Faces.Bottom and 'Enum.NormalId.Bottom' or nil,
        Faces.Left and 'Enum.NormalId.Left' or nil,
        Faces.Right and 'Enum.NormalId.Right' or nil,
        Faces.Back and 'Enum.NormalId.Back' or nil,
        Faces.Front and 'Enum.NormalId.Front' or nil,
    }, ', ') .. ')'
end
function DefaultMethods.FloatCurveKey(CurveKey)
    local SerializeNumber = Methods.number

    return 'FloatCurveKey.new(' .. SerializeNumber(CurveKey.Time) .. ', ' .. SerializeNumber(CurveKey.Value) .. ', Enum.KeyInterpolationMode.' .. CurveKey.Interpolation.Name .. ')'
end
function DefaultMethods.Font(Font)
    return 'Font.new(' .. Methods.string(Font.Family) .. ', Enum.FontWeight.' .. Font.Weight.Name .. ', Enum.FontStyle.' .. Font.Style.Name .. ')'
end

do
    local Services = {
        Workspace = 'workspace',
        Lighting = 'game.lighting',
        GlobalSettings = 'settings()',
        Stats = 'stats()',
        UserSettings = 'UserSettings()',
        PluginManagerInterface = 'PluginManager()',
        DebuggerManager = 'DebuggerManager()',
    }

    if IsClient then
        local LocalPlayer = Players.LocalPlayer

        if not LocalPlayer then
            Players:GetPropertyChangedSignal('LocalPlayer'):Once(function()
                LocalPlayer = Players.LocalPlayer
            end)
        end

        function DefaultMethods.Instance(obj)
            local ObjectParent = obj.Parent
            local ObjectClassName = obj.ClassName

            if ObjectParent then
                local ObjectName = Methods.string(obj.Name)

                if ObjectClassName ~= 'Model' and ObjectClassName ~= 'Player' then
                    local IsService, Output = pcall(FindService, game, ObjectClassName)

                    return (not IsService or not Output) and Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')' or Services[ObjectClassName] or 'game:GetService("' .. ObjectClassName .. '")'
                elseif ObjectClassName == 'Model' then
                    local Player = Players:GetPlayerFromCharacter(obj)

                    return not Player and Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')' or 'game:GetService("Players")' .. (Player == LocalPlayer and '.LocalPlayer.Character' or ':WaitForChild(' .. ObjectName .. ').Character')
                end

                return 'game:GetService("Players")' .. (obj == LocalPlayer and '.LocalPlayer' or ':WaitForChild(' .. ObjectName .. ')')
            end

            return ObjectClassName == 'DataModel' and 'game' or 'Instance.new("' .. ObjectClassName .. '", nil)'
        end
    else
        function DefaultMethods.Instance(obj)
            local ObjectParent = obj.Parent
            local ObjectClassName = obj.ClassName

            if ObjectParent then
                local ObjectName = Methods.string(obj.Name)

                if ObjectClassName ~= 'Model' and ObjectClassName ~= 'Player' then
                    local IsService, Output = pcall(FindService, game, ObjectClassName)

                    return (not IsService or not Output) and Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')' or Services[ObjectClassName] or 'game:GetService("' .. ObjectClassName .. '")'
                elseif ObjectClassName == 'Model' then
                    local Player = Players:GetPlayerFromCharacter(obj)

                    return not Player and Methods.Instance(ObjectParent) .. ':WaitForChild(' .. ObjectName .. ')' or 'game:GetService("Players"):WaitForChild(' .. ObjectName .. ').Character'
                end

                return 'game:GetService("Players"):WaitForChild(' .. ObjectName .. ')'
            end

            return ObjectClassName == 'DataModel' and 'game' or 'Instance.new("' .. ObjectClassName .. '", nil)'
        end
    end

    Class.Services = Services
end

function DefaultMethods.NumberRange(Range)
    local SerializeNumber = Methods.number

    return 'NumberRange.new(' .. SerializeNumber(Range.Min) .. ', ' .. SerializeNumber(Range.Max) .. ')'
end
function DefaultMethods.NumberSequence(Sequence)
    local SerializeNumberSequenceKeypoint = Methods.NumberSequenceKeypoint
    local Keypoints = Sequence.Keypoints
    local Size = #Keypoints
    local Serialized = ''

    for i = 1, Size - 1 do
        Serialized ..= SerializeNumberSequenceKeypoint(Keypoints[i]) .. ', '
    end

    return 'NumberSequence.new({' .. Serialized .. SerializeNumberSequenceKeypoint(Keypoints[Size]) .. '})'
end

do
    local DefaultOverlapParams = OverlapParams.new()

    function DefaultMethods.OverlapParams(Params, format, indents)
        if DefaultOverlapParams ~= Params then
            local formatspace = format and '\n' .. indents or ' '
            local FilterDescendantsInstances = Params.FilterDescendantsInstances
            local FilterType = Params.FilterType
            local CollisionGroup = Params.CollisionGroup

            return '(function(Param : OverlapParams)' .. formatspace .. (#FilterDescendantsInstances > 0 and '\tParam.FilterDescendantsInstances = ' .. Methods.table(FilterDescendantsInstances, false, '') .. formatspace or '') .. (FilterType ~= Enum.RaycastFilterType.Exclude and '\tParam.FilterType = Enum.RaycastFilterType.' .. FilterType.Name .. formatspace or '') .. (CollisionGroup ~= 'Default' and '\tParam.CollisionGroup = ' .. Methods.string(CollisionGroup) .. formatspace or '') .. (Params.RespectCanCollide and '\tParam.RespectCanCollide = true' .. formatspace or '') .. (Params.BruteForceAllSlow and '\tParam.BruteForceAllSlow = true' .. formatspace or '') .. '\treturn Params' .. formatspace .. 'end)(OverlapParams.new())'
        end

        return 'OverlapParams.new()'
    end
end

function DefaultMethods.NumberSequenceKeypoint(Keypoint)
    local SerializeNumber = Methods.number

    return 'NumberSequenceKeypoint.new(' .. SerializeNumber(Keypoint.Time) .. ', ' .. SerializeNumber(Keypoint.Value) .. ', ' .. SerializeNumber(Keypoint.Envelope) .. ')'
end
function DefaultMethods.PathWaypoint(Waypoint)
    return 'PathWaypoint.new(' .. Methods.Vector3(Waypoint.Position) .. ', Enum.PathWaypointAction.' .. Waypoint.Action.Name .. ', ' .. Methods.string(Waypoint.Label) .. ')'
end

do
    local function nanToString(int)
        return int == int and int or '0/0'
    end

    function DefaultMethods.PhysicalProperties(Properties)
        return 'PhysicalProperties.new(' .. (nanToString(Properties.Density)) .. ', ' .. nanToString(Properties.Friction) .. ', ' .. nanToString(Properties.Elasticity) .. ', ' .. nanToString(Properties.FrictionWeight) .. ', ' .. nanToString(Properties.ElasticityWeight) .. ')'
    end
end

function DefaultMethods.RBXScriptConnection(Connection, _, _, _, InComment)
    local CommentSeperator = not InComment and '' or '='

    return '(nil --[' .. CommentSeperator .. '[ RBXScriptConnection | IsConnected: ' .. (Connection.Connected and 'true' or 'false') .. ' ]' .. CommentSeperator .. '])'
end

do
    local Signals = {
        GraphicsQualityChangeRequest = 'game.GraphicsQualityChangeRequest',
        AllowedGearTypeChanged = 'game.AllowedGearTypeChanged',
        ScreenshotSavedToAlbum = 'game.ScreenshotSavedToAlbum',
        UniverseMetadataLoaded = 'game.UniverseMetadataLoaded',
        ScreenshotReady = 'game.ScreenshotReady',
        ServiceRemoving = 'game.ServiceRemoving',
        ServiceAdded = 'game.ServiceAdded',
        ItemChanged = 'game.ItemChanged',
        CloseLate = 'game.CloseLate',
        Loaded = 'game.Loaded',
        Close = 'game.Close',
        RobloxGuiFocusedChanged = 'game:GetService("RunService").RobloxGuiFocusedChanged',
        PostSimulation = 'game:GetService("RunService").PostSimulation',
        RenderStepped = 'game:GetService("RunService").RenderStepped',
        PreSimulation = 'game:GetService("RunService").PreSimulation',
        PreAnimation = 'game:GetService("RunService").PreAnimation',
        PreRender = 'game:GetService("RunService").PreRender',
        Heartbeat = 'game:GetService("RunService").Heartbeat',
        Stepped = 'game:GetService("RunService").Stepped',
    }

    function DefaultMethods.RBXScriptSignal(Signal, _, _, _, InComment)
        local CommentSeperator = not InComment and '' or '='
        local SignalName = tostring(Signal):match('Signal (%a+)')

        return Signals[SignalName] or '(nil --[' .. CommentSeperator .. '[ RBXScriptSignal | ' .. SignalName .. ' is not supported ]' .. CommentSeperator .. '])'
    end

    Class.Signals = Signals
end

function DefaultMethods.Random(_, _, _, _, InComment)
    local CommentSeperator = not InComment and '' or '='

    return 'Random.new(--[' .. CommentSeperator .. '[ <Seed> ]' .. CommentSeperator .. '])'
end
function DefaultMethods.Ray(Ray)
    local SerializeVector3 = Methods.Vector3

    return 'Ray.new(' .. SerializeVector3(Ray.Origin) .. ', ' .. SerializeVector3(Ray.Direction) .. ')'
end

do
    local DefaultRaycastParams = RaycastParams.new()

    function DefaultMethods.RaycastParams(Params, format, indents)
        if DefaultRaycastParams ~= Params then
            local formatspace = format and '\n' .. indents or ' '
            local FilterDescendantsInstances = Params.FilterDescendantsInstances
            local FilterType = Params.FilterType
            local CollisionGroup = Params.CollisionGroup

            return '(function(Param : RaycastParams)' .. formatspace .. (#FilterDescendantsInstances > 0 and '\tParam.FilterDescendantsInstances = ' .. Methods.table(FilterDescendantsInstances, false, '') .. formatspace or '') .. (FilterType ~= Enum.RaycastFilterType.Exclude and '\tParam.FilterType = Enum.RaycastFilterType.' .. FilterType.Name .. formatspace or '') .. (Params.IgnoreWater and '\tParam.IgnoreWater = true' .. formatspace or '') .. (CollisionGroup ~= 'Default' and '\tParam.CollisionGroup = ' .. Methods.string(CollisionGroup) .. formatspace or '') .. (Params.RespectCanCollide and '\tParam.RespectCanCollide = true' .. formatspace or '') .. (Params.BruteForceAllSlow and '\tParam.BruteForceAllSlow = true' .. formatspace or '') .. '\treturn Params' .. formatspace .. 'end)(RaycastParams.new())'
        end

        return 'RaycastParams.new()'
    end
end

function DefaultMethods.Rect(Rect)
    local SerializeVector2 = Methods.Vector2

    return 'Rect.new(' .. SerializeVector2(Rect.Min) .. ', ' .. SerializeVector2(Rect.Max) .. ')'
end
function DefaultMethods.Region3(Region)
    local SerializeVector3 = Methods.Vector3
    local Center = Region.CFrame.Position
    local Size = Region.Size / 2

    return 'Region3.new(' .. SerializeVector3(Center - Size) .. ', ' .. SerializeVector3(Center + Size) .. ')'
end
function DefaultMethods.Region3int16(Region)
    local SerializeVector3int16 = Methods.Vector3int16

    return 'Region3int16.new(' .. SerializeVector3int16(Region.Min) .. ', ' .. SerializeVector3int16(Region.Max) .. ')'
end
function DefaultMethods.RotationCurveKey(Curve)
    return 'RotationCurveKey.new(' .. Methods.number(Curve.Time) .. ', ' .. Methods.CFrame(Curve.Value) .. ', Enum.KeyInterpolationMode.' .. Curve.Interpolation.Name .. ')'
end
function DefaultMethods.SharedTable(Shared, format, indents, _, InComment)
    local isreadonly = IsSharedFrozen(Shared)

    if SharedSize(Shared) ~= 0 then
        local stackindent = indents .. (format and '\t' or '')
        local CurrentIndex = 1
        local Serialized = {}

        for i, v in Shared do
            Serialized[CurrentIndex] = (CurrentIndex ~= i and ValidateSharedTableIndex(i) or '') .. Serialize(v, format, stackindent, nil, InComment)

            CurrentIndex += 1
        end

        local formatspace = format and '\n' or ''
        local Contents = formatspace .. stackindent .. concat(Serialized, (format and ',\n' or ', ') .. stackindent) .. formatspace .. indents

        return not isreadonly and 'SharedTable.new({' .. Contents .. '})' or 'SharedTable.cloneAndFreeze(SharedTable.new({' .. Contents .. '}))'
    end

    return not isreadonly and 'SharedTable.new()' or 'SharedTable.cloneAndFreeze(SharedTable.new())'
end
function DefaultMethods.TweenInfo(Info)
    return 'TweenInfo.new(' .. Methods.number(Info.Time) .. ', Enum.EasingStyle.' .. Info.EasingStyle.Name .. ', Enum.EasingDirection.' .. Info.EasingDirection.Name .. ', ' .. Info.RepeatCount .. ', ' .. (Info.Reverses and 'true' or 'false') .. ', ' .. Methods.number(Info.DelayTime) .. ')'
end
function DefaultMethods.UDim(UDim)
    return 'UDim.new(' .. Methods.number(UDim.Scale) .. ', ' .. UDim.Offset .. ')'
end
function DefaultMethods.UDim2(UDim2)
    local SerializeNumber = Methods.number
    local Width = UDim2.X
    local Height = UDim2.Y

    return 'UDim2.new(' .. SerializeNumber(Width.Scale) .. ', ' .. Width.Offset .. ', ' .. SerializeNumber(Height.Scale) .. ', ' .. Height.Offset .. ')'
end
function DefaultMethods.Vector2(Vector)
    local SerializeNumber = Methods.number

    return 'Vector2.new(' .. SerializeNumber(Vector.X) .. ', ' .. SerializeNumber(Vector.Y) .. ')'
end
function DefaultMethods.Vector2int16(Vector)
    return 'Vector2int16.new(' .. Vector.X .. ', ' .. Vector.Y .. ')'
end
function DefaultMethods.Vector3(Vector)
    local SerializeNumber = Methods.number

    return DefaultVectors[Vector] or 'vector.create(' .. SerializeNumber(Vector.X) .. ', ' .. SerializeNumber(Vector.Y) .. ', ' .. SerializeNumber(Vector.Z) .. ')'
end
function DefaultMethods.Vector3int16(Vector)
    return 'Vector3int16.new(' .. Vector.X .. ', ' .. Vector.Y .. ', ' .. Vector.Z .. ')'
end
function DefaultMethods.boolean(bool)
    return bool and 'true' or 'false'
end
function DefaultMethods.buffer(buff)
    return 'buffer.fromstring(' .. Methods.string(bufftostring(buff)) .. ')'
end

do
    local GlobalFunctions = {}

    do
        local getrenv = getrenv or (function()
            local env = {
                bit32 = bit32,
                buffer = buffer,
                coroutine = coroutine,
                debug = debug,
                math = math,
                os = os,
                string = string,
                table = table,
                utf8 = utf8,
                Content = Content,
                Axes = Axes,
                AdReward = AdReward,
                BrickColor = BrickColor,
                CatalogSearchParams = CatalogSearchParams,
                CFrame = CFrame,
                Color3 = Color3,
                ColorSequence = ColorSequence,
                ColorSequenceKeypoint = ColorSequenceKeypoint,
                DateTime = DateTime,
                DockWidgetPluginGuiInfo = DockWidgetPluginGuiInfo,
                Faces = Faces,
                FloatCurveKey = FloatCurveKey,
                Font = Font,
                Instance = Instance,
                NumberRange = NumberRange,
                NumberSequence = NumberSequence,
                NumberSequenceKeypoint = NumberSequenceKeypoint,
                OverlapParams = OverlapParams,
                PathWaypoint = PathWaypoint,
                PhysicalProperties = PhysicalProperties,
                Random = Random,
                Ray = Ray,
                RaycastParams = RaycastParams,
                Rect = Rect,
                Region3 = Region3,
                Region3int16 = Region3int16,
                RotationCurveKey = RotationCurveKey,
                SharedTable = SharedTable,
                task = task,
                TweenInfo = TweenInfo,
                UDim = UDim,
                UDim2 = UDim2,
                Vector2 = Vector2,
                Vector2int16 = Vector2int16,
                Vector3 = Vector3,
                vector = vector,
                Vector3int16 = Vector3int16,
                CellId = CellId,
                PluginDrag = PluginDrag,
                SecurityCapabilities = SecurityCapabilities,
                assert = assert,
                error = error,
                getfenv = getfenv,
                getmetatable = getmetatable,
                ipairs = ipairs,
                loadstring = loadstring,
                newproxy = newproxy,
                next = next,
                pairs = pairs,
                pcall = pcall,
                print = print,
                rawequal = rawequal,
                rawget = rawget,
                rawlen = rawlen,
                rawset = rawset,
                select = select,
                setfenv = setfenv,
                setmetatable = setmetatable,
                tonumber = tonumber,
                tostring = tostring,
                unpack = unpack,
                xpcall = xpcall,
                collectgarbage = collectgarbage,
                delay = delay,
                gcinfo = gcinfo,
                PluginManager = PluginManager,
                DebuggerManager = DebuggerManager,
                require = require,
                settings = settings,
                spawn = spawn,
                tick = tick,
                time = time,
                UserSettings = UserSettings,
                wait = wait,
                warn = warn,
                Delay = Delay,
                ElapsedTime = ElapsedTime,
                elapsedTime = elapsedTime,
                printidentity = printidentity,
                Spawn = Spawn,
                Stats = Stats,
                stats = stats,
                Version = Version,
                version = version,
                Wait = Wait,
            }

            return function()
                return env
            end
        end)()
        local Visited = setmetatable({}, {
            __mode = 'k',
        })

        for i, v in getrenv()do
            local ElementType = type(i) == 'string' and type(v)

            if ElementType then
                if ElementType == 'table' then
                    local function LoadLibrary(Path, tbl)
                        if not Visited[tbl] then
                            Visited[tbl] = true

                            for i, v in next, tbl do
                                local Type = type(i) == 'string' and not Keywords[i] and i:match('[A-z_][A-z_0-9]') and type(v)
                                local NewPath = Type and (Type == 'function' or Type == 'table') and Path .. '.' .. i

                                if NewPath then
                                    if Type == 'function' then
                                        GlobalFunctions[v] = NewPath
                                    else
                                        LoadLibrary(NewPath, v)
                                    end
                                end
                            end

                            Visited[tbl] = nil
                        end
                    end

                    LoadLibrary(i, v)
                    table.clear(Visited)
                elseif ElementType == 'function' then
                    GlobalFunctions[v] = i
                end
            end
        end

        Class.GlobalFunctions = GlobalFunctions
    end

    DefaultMethods['function'] = function(
        Function,
        format,
        indents,
        _,
        InComment
    )
        local IsGlobal = GlobalFunctions[Function]

        if not IsGlobal then
            if format then
                local SerializeString = Methods.string
                local CommentSeperator = not InComment and '' or '='
                local tempindents = indents .. '\t\t\t'
                local newlineindent = ',\n' .. tempindents
                local source, line, name, numparams, vargs = info(Function, 'slna')

                return 'function()' .. (line ~= -1 and '' or ' --[' .. CommentSeperator .. '[ CClosure ' .. name .. ' ]' .. CommentSeperator .. ']') .. '\n\t' .. indents .. '--[' .. CommentSeperator .. '[\n\t\t' .. indents .. 'info = {\n' .. tempindents .. 'source = ' .. SerializeString(source) .. newlineindent .. 'line = ' .. line .. newlineindent .. 'what = ' .. (line ~= 
-1 and '"Lua"' or '"C"') .. newlineindent .. 'name = ' .. SerializeString(name) .. newlineindent .. 'numparams = ' .. numparams .. newlineindent .. 'vargs = ' .. (vargs and 'true' or 'false') .. newlineindent .. 'function = ' .. tostring(Function) .. '\n\t\t' .. indents .. '}\n\t' .. indents .. ']' .. CommentSeperator .. ']\n' .. indents .. 'end'
            end

            return islclosure(Function) and 'function() end' or 'function() --[' .. (not InComment and '' or '=') .. '[ CClosure ' .. (info(Function, 'n')) .. ' ]' .. (not InComment and '' or '=') .. '] end'
        end

        return IsGlobal
    end
end

function DefaultMethods.table(tbl, format, indents, CyclicList, InComment)
    local CyclicList = CyclicList or setmetatable({}, {
        __mode = 'k',
    })

    if not CyclicList[tbl] then
        local isreadonly = isfrozen(tbl)
        local Index, Value = next(tbl)

        if Index ~= nil then
            local Indents = indents .. (format and '\t' or '')
            local Ending = (format and ',\n' or ', ')
            local formatspace = format and '\n' or ''
            local Generation = '{' .. formatspace
            local CurrentIndex = 1

            CyclicList[tbl] = true

            repeat
                Generation ..= Indents .. (CurrentIndex ~= Index and ValidateIndex(Index) or '') .. Serialize(Value, format, Indents, CyclicList, InComment)

                Index, Value = next(tbl, Index)

                Generation ..= Index ~= nil and Ending or formatspace .. indents .. '}'
                CurrentIndex += 1
            until Index == nil

            CyclicList[tbl] = nil

            return not isreadonly and Generation or 'table.freeze(' .. Generation .. ')'
        end

        return not isreadonly and '{}' or 'table.freeze({})'
    else
        return '*** cycle table reference detected ***'
    end
end

DefaultMethods['nil'] = function()
    return 'nil'
end

function DefaultMethods.number(num)
    return num ~= inf and num ~= neginf and num == num and tostring(num) or num == inf and (Class.__Serializeinf and 'math.huge' or '1/0') or num == neginf and (Class.__Serializeinf and '-math.huge' or '-1/0') or '0/0'
end

do
    local ByteList = {
        ['\a'] = '\\a',
        ['\b'] = '\\b',
        ['\t'] = '\\t',
        ['\n'] = '\\n',
        ['\v'] = '\\v',
        ['\f'] = '\\f',
        ['\r'] = '\\r',
        ['"'] = '\\"',
        ['\\'] = '\\\\',
    }

    for i = 0, 255 do
        local Character = string.char(i)

        if not ByteList[Character] and (i < 32 or i > 126) then
            ByteList[Character] = ('\\%03d'):format(i)
        end
    end

    function DefaultMethods.string(RawString)
        return '"' .. RawString:gsub('[\0-\31"\\\127-\255]', ByteList) .. '"'
    end
end

function DefaultMethods.thread(thread)
    return 'coroutine.create(function() end)'
end
function DefaultMethods.userdata(userdata)
    return getmetatable(userdata) ~= nil and 'newproxy(true)' or 'newproxy(false)'
end

do
    local SecurityCapabilityEnums = Enum.SecurityCapability:GetEnumItems()

    function DefaultMethods.SecurityCapabilities(
        Capabilities,
        format,
        _,
        _,
        InComment
    )
        local Contains = {}
        local CurrentIndex = 1

        for i, v in SecurityCapabilityEnums do
            if Capabilities:Contains(v) then
                Contains[CurrentIndex] = 'Enum.SecurityCapability.' .. v.Name

                CurrentIndex += 1
            end
        end

        return 'SecurityCapabilities.new(' .. concat(Contains, ', ') .. ')'
    end
end

function DefaultMethods.PluginDrag(Drag)
    local SerializeString = Methods.string

    return 'PluginDrag.new(' .. SerializeString(Drag.Sender) .. ', ' .. SerializeString(Drag.MimeType) .. ', ' .. SerializeString(Drag.Data) .. ', ' .. SerializeString(Drag.MouseIcon) .. ', ' .. SerializeString(Drag.DragIcon) .. ', ' .. Methods.Vector2(Drag.HotSpot) .. ')'
end
function DefaultMethods.CellId(_, _, _, _, InComment)
    local Comment = (InComment and '=' or '')

    return 'CellId.new(--[' .. Comment .. '[ Undocumented ]' .. Comment .. '])'
end

local function Serializevargs(...)
    local tbl = pack(...)
    local GenerationSize = 0

    for i = 1, #tbl do
        local Generation = Serialize(tbl[i], true, '')

        tbl[i] = Generation

        GenerationSize += #Generation

        if GenerationSize > 100000 then
            break
        end
    end

    return unpack(tbl, 1, tbl.n)
end

function Class.Convert(DataStructure, format)
    return Serialize(DataStructure, format, '')
end
function Class.ConvertKnown(DataType, DataStructure, format)
    return Methods[DataType](DataStructure, format, '')
end
function Class.print(...)
    print(Serializevargs(...))
end
function Class.warn(...)
    warn(Serializevargs(...))
end

if type(setclipboard) == 'function' then
    local setclipboard = setclipboard

    function Class.setclipboard(DataStructure, format)
        setclipboard(Serialize(DataStructure, format, ''))
    end
end

return setmetatable(Class, {
    __tostring = 'DataToCode',
})
