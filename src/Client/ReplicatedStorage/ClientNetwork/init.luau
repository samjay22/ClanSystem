--!strict
local HttpService : HttpService = game:GetService("HttpService")
local RunService : RunService = game:GetService("RunService")

local Methods = require(game.ReplicatedStorage.Utility.Methods)
local Endponts = require(game.ReplicatedStorage.ClientNetwork.ClientEndpoints)

local ClientNetwork = {}
--Table that keeps track of pending network requests to be processed.
local _responseHandlers = {}
local _responseCallbacks = {} -- table to keep track of outbound requests awaitng response

--Async network traffic is much better than non async
function ClientNetwork.HandleResponse(responseId : string, ...)
    table.insert(_responseHandlers, {responseId, {...}})
end

--Simple fire server, no response expected
function ClientNetwork.FireSever(endpoint: string, ...)
    game.ReplicatedStorage.API:FireServer(endpoint, ...)
end

--Post request, response expected
--eg ClientNetwork.PostAsync("CreateClan", function(data) print(data) end, ...)
function ClientNetwork.PostAsync(endpoint : string, callback : (any...) -> (any...), ...)
    local requestID : string = HttpService:GenerateGUID(false)
    --reg9ster the callback for response from server
    _responseCallbacks[requestID] = callback
    game.ReplicatedStorage.API:FireServer(endpoint, ...)
end

local function ProcessResponses()
    local response = table.remove(_responseHandlers)
    if not response then return end

    local responseId = response[1]
    local responseArgs = response[2]

    --indirect relationship here, either handle response via endpoints manager or by direct callback
    local callback = _responseCallbacks[responseId] or Endponts[responseId]
    if callback then
        Methods.SafeCall(callback, unpack(responseArgs))
        
        --cleanup
        _responseCallbacks[responseId] = nil
    end
end
RunService.RenderStepped:Connect(ProcessResponses)

return ClientNetwork