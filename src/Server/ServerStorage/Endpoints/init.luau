--!strict
local Methods = require(game.ReplicatedStorage.Utility.Methods)

local RunService : RunService = game:GetService("RunService")

local _processQueue : {Callback : () -> (), Args : {any}}  = {}
local _endpoints = {}

local Endpoints = {}
export type IEndpoints = typeof(Endpoints)
for _, mod in next, game.ServerStorage.Endpoints:GetChildren() do
    _endpoints[mod.Name] = (function()
        local functions = {}
        for i, v in next, require(mod) do
            functions[i] = v
        end

        return functions
    end)
end

function Endpoints.QueueNewRequest(requestEndpoint : string, ...)
    if not _endpoints[requestEndpoint] then error(`{requestEndpoint} does not exists.`) end

    --Correct pattern to deal with requests
    table.insert(_processQueue, {
        Args = {...},
        Callback = _endpoints[requestEndpoint]
    })
end

--keep track of the retries
local RetryMetadata = {}
local function ProcessRequest(dt : number)
    local first = table.remove(_processQueue)
    if first then
        local msg, okay = Methods.SafeCall(first.Callback, unpack(first.Args))
        --There was an issue
        if not okay and (not RetryMetadata[first] or RetryMetadata[first] <= 3) then
            warn(msg)
            --Reprocess later
            RetryMetadata[first] = RetryMetadata[first] and RetryMetadata[first] + 1 or 1
            table.insert(_processQueue, first)
        end
    end
end
RunService.Heartbeat:Connect(ProcessRequest)

return Endpoints