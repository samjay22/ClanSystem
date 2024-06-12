--!strict
local ClientNetwork = require(game.ReplicatedStorage.ClientNetwork)

game.ReplicatedStorage.API.OnClientEvent:Connect(function(endpoint : string, ...)
    ClientNetwork.ProcessRequest(endpoint, ...)
end)