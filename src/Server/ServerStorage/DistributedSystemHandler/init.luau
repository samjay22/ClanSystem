--!strict
local MemoryStoreService : MemoryStoreService = game:GetService("MemoryStoreService")
local RunService : RunService = game:GetService("RunService")

local ServerCache : MemoryStoreSortedMap = MemoryStoreService:GetSortedMap("ServerCache") -- in memory cache to keep track of live servers

local _ActiveDelegates : {{Delegate : (self : {NextProcess : number}) -> (), NextProcess : number}} = {}
local DistributedSystemHandler = {
    IsLeader = false
}

--function to add a server to the cache
function DistributedSystemHandler.AddServer()
    --Get server frame rate with job id
    ServerCache:SetAsync(1 / RunService.Heartbeat:Wait() .. "-" .. game.JobId, true)
end

function DistributedSystemHandler.RegisterOperation(delegate)
    table.insert(_ActiveDelegates, {Delegate = delegate, NextProcess = 0})
end


RunService.Heartbeat:Connect(function()
    if not DistributedSystemHandler.IsLeader then
        return
    end
    
    for _, delegate in ipairs(_ActiveDelegates) do
        if os.time() >= delegate.NextProcess then
            delegate.Delegate(delegate)
        end
    end
end)


return DistributedSystemHandler
