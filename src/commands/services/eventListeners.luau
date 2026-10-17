local robloxServices = require('../../framework/services/rbxServices')
local connectionService = require('../../framework/services/connectionService')
local eventBinds = require('../systems/eventBinds')
local Players = robloxServices.Players
local TextChatService = robloxServices.TextChatService
local eventListeners = {}
local started = false
local legacyChat = false
local playerConnections = {}
local characterConnections = {}

local function connectFor(bucket, player, signal, callback)
    local connection = connectionService:Connect(signal, callback)
    local list = bucket[player] or {}

    bucket[player] = list

    table.insert(list, connection)
end
local function disconnectFor(bucket, player)
    local list = bucket[player]

    bucket[player] = nil

    for _, connection in list or {}do
        connectionService:disconnect(connection)
    end
end
local function watchCharacter(player, character)
    disconnectFor(characterConnections, player)
    task.spawn(function()
        local humanoid = character:WaitForChild('Humanoid', 10)

        if not humanoid or not humanoid:IsA('Humanoid') or player.Character ~= character then
            return
        end

        local lastHealth = humanoid.Health

        connectFor(characterConnections, player, humanoid.HealthChanged, function(
            health
        )
            if health < lastHealth then
                eventBinds.fire('OnDamage', player.Name, health)
            end

            lastHealth = health
        end)
        connectFor(characterConnections, player, humanoid.Died, function()
            eventBinds.fire('OnDied', player.Name)

            local creator = humanoid:FindFirstChild('creator')
            local killer = if creator and creator:IsA('ObjectValue')then creator.Value else nil

            if killer and killer:IsA('Player') then
                eventBinds.fire('OnKilled', player.Name, killer.Name)
            end
        end)
    end)
end
local function followPlayer(player)
    connectFor(playerConnections, player, player.CharacterAdded, function(
        character
    )
        eventBinds.fire('OnSpawn', player.Name)
        watchCharacter(player, character)
    end)

    if legacyChat then
        connectFor(playerConnections, player, player.Chatted, function(message)
            eventBinds.fire('OnChatted', player.Name, message)
        end)
    end
    if player.Character then
        watchCharacter(player, player.Character)
    end
end
local function onMessageReceived(message)
    local source = message.TextSource

    if not source or message.Status == Enum.TextChatMessageStatus.InvalidTextChannelPermissions then
        return
    end

    local player = Players:GetPlayerByUserId(source.UserId)

    if player then
        eventBinds.fire('OnChatted', player.Name, message.Text)
    end
end
local function onPlayerRemoving(player)
    eventBinds.fire('OnLeave', player.Name)
    disconnectFor(playerConnections, player)
    disconnectFor(characterConnections, player)
end

function eventListeners.start()
    if started then
        return
    end

    started = true
    legacyChat = TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService

    connectionService:Connect(Players.PlayerAdded, function(player)
        eventBinds.fire('OnJoin', player.Name)
        followPlayer(player)
    end)
    connectionService:Connect(Players.PlayerRemoving, onPlayerRemoving)

    if not legacyChat then
        connectionService:Connect(TextChatService.MessageReceived, onMessageReceived)
    end

    for _, player in Players:GetPlayers()do
        followPlayer(player)
    end

    eventBinds.fire('OnExecute')
end

return eventListeners
