--!strict
local ClientNetwork = require(game.ReplicatedStorage.ClientNetwork)

game.ReplicatedStorage.API.OnClientEvent:Connect(function(responseId : string, ...)
    ClientNetwork.HandleResponse(responseId, ...)
end)