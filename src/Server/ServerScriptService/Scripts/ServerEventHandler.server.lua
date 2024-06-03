--!strict
local MemoryStoreService : MemoryStoreService = game:GetService("MemoryStoreService")

-- in memory queue to keep track of clan activities, prevents two actions from happening at once
local ClientActionQueue : MemoryStoreQueue = MemoryStoreService:GetQueue("ClientActionQueue") 
local ClanCache : MemoryStoreSortedMap = MemoryStoreService:GetSortedMap("ClanCache") -- in memory cache across servers, quick updates

--Add this server
local systemHandler = require(game.ServerStorage.DistributedSystemHandler)
local Methods = require(game.ServerStorage.Utility.Methods)

--Treat this server as a distributed system
systemHandler.AddServer()


--This deals with the leauge update data
systemHandler.RegisterOperation(function(self)
    while true do
        local exclusiveLowerBound = nil
		local items = ClanCache:GetRangeAsync(Enum.SortDirection.Ascending, 100, exclusiveLowerBound)

		for _, item in ipairs(items) do
			print(item.key)
			print(item.sortKey)
            print(item.value)
		end

		-- if the call returned less than a hundred items it means we've reached the end of the map
		if #items < 100 then
			break
		end

		-- the last retrieved key is the exclusive lower bound for the next iteration
		exclusiveLowerBound = {}
		exclusiveLowerBound["key"] = items[#items].key
		exclusiveLowerBound["sortKey"] = items[#items].sortKey

        task.wait()
	end

    self.NextProcess = os.time() + (60)
end)

systemHandler.RegisterOperation(function(self)
	local servers = ServerCache:GetRangeAsync(Enum.SortDirection.Descending, 5, 1)
	if servers then
		local leader = servers[1]
		systemHandler.IsLeader = game.JobId == string.split(leader, "-")[2]
	end

	self.NextProcess = os.time() + (60)
end)