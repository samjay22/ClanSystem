--!strict
local Players : Players = game:GetService("Players")
local DataStoreService : DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService : MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService : HttpService = game:GetService("HttpService")

local ClanStore : DataStore = DataStoreService:GetDataStore("ClanStore")

-- in memory queue to keep track of clan activities, prevents two actions from happening at once
local ClientActionQueue : MemoryStoreQueue = MemoryStoreService:GetQueue("ClientActionQueue") 
local ClanCache : MemoryStoreSortedMap = MemoryStoreService:GetSortedMap("ClanCache") -- in memory cache across servers, quick updates -- in memory cache across servers, quick updates

local ClanType = require(game.ReplicatedStorage.Types.Clan)
local ClanRankData = require(game.ServerStorage.ClanSystem.ClanRanks)
local Methods = require(game.ReplicatedStorage.Utility.Methods)

local ClanSystem = {}
export type ClanSystem = typeof(ClanSystem)

local function UpdateClanEvent(clan)
    for _, userId in next, clan.Members do
        local player : Player? = Players:GetPlayerByUserId(userId)
        if player then
            --notify the user
            game.ReplicatedStorage.API:FireClient(player, "UpdateClan", clan)
        end

        task.wait()
    end
end

local function getMemberRankId(clanId : string, userId : number) : number
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)
    
    for _, rankData in next, clan.RankDataForMembers do
        if rankData.UserId == userId then
            return rankData.RankId
        end
    end

    return 0
end

local SafeCall = Methods.SafeCall
function ClanSystem.CreateClan(name : string, tag : string, description : string, creator : Player, imageId : number) : ClanType.Clan
    local clanId : string = HttpService:GenerateGUID(false)
    local clan : ClanType.Clan = {
        ClanClosed = false,
        JoinRequests = {},
        BannedUsers = {},
        Image = imageId,
        ClanTag = tag,
        Id = clanId,
        Name = name,
        Tag = tag,
        Description = description,
        Owner = creator.UserId,
        ImageId = imageId,

        Members = {creator.UserId},
        Requests = {},
        Banned = {},
        RankDataForMembers = {
            {UserId = creator.UserId, RankId = 1}
        },

        LimitTOMembers = 3,
        CreatedAt = os.time(),
        UpdatedAt = os.time()
    }

    SafeCall(function()
    --save in long term storage
        ClanStore:UpdateAsync(clanId, function(oldData)
            local data = {}
            for key, value in pairs(clan) do
                data[string.sub(key, 1, 2)] = value
            end

            return data
        end)    
    end)

    SafeCall(function()
        --in place cache for quick retreval
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan -- no compression, just store the whole object
        end, 24 * 60 * 60) -- 24 hours
    end)

    return clan
end

function ClanSystem.GetClanById(id : string) : ClanType.Clan
    --If we have the clan in cache, return it
    local clan : ClanType.Clan? = SafeCall(function()
        local cachedClan = ClanCache:GetAsync(id)
        if cachedClan then
            return cachedClan
        end

        return nil
    end)

    --looks like we don't have the clan in cache, let's fetch it from long term storage
    if not clan then
        clan = SafeCall(function()
            local data = ClanStore:GetAsync(id)
            if data then
                local clan : ClanType.Clan = {
                    Id = id,
                    Name = data.Na,
                    ClanTag = data.Ta,
                    Description = data.De,
                    Owner = data.Ow,
                    Image = data.Im,
                    BannedUsers = data.Ba,
                    JoinRequests = data.Jo,
                    ImageId = data.Im,
                    Members = data.Me,
                    Requests = data.Re,
                    Banned = data.Ba,
                    CreatedAt = data.Ca,
                    UpdatedAt = data.Up,
                    ClanClosed = data.Cl,
                    LimitTOMembers = data.Li,
                    RankDataForMembers = data.Ra,
                }

                data = clan
            end

            return data
        end)

        --store the clan in cache
        if clan then
            SafeCall(function()
                ClanCache:UpdateAsync(id, function(oldData)
                    return clan
                end, 24 * 60 * 60) -- 24 hours
            end)
        end
    end

    return clan or error("Clan not found")
end

local function RankIdToRank(id) : ClanType.ClanRank?
    local foundRank : ClanType.ClanRank? = nil
    for _, rank in ipairs(ClanRankData) do
        if rank.Id == id then
            foundRank = rank
            break
        end
    end

    return foundRank or error("Rank not found")
end

local function RankNameToId(rankName : string) : number
    local foundRankId : number? = nil
    for _, rank in ipairs(ClanRankData) do
        if rank.Name == rankName then
            foundRankId = rank.Id
            break
        end
    end

    return foundRankId or error("Rank not found")
end

function ClanSystem.BanUser(clanId : string, requestedUserId : number, userToBanId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they ban?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "Ban") then
        table.insert(clan.BannedUsers, userToBanId)
        table.remove(clan.Members, table.find(clan.Members, userToBanId))
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.PromoteUser(clanId : string, requestedUserId : number, userToRankId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "Promote") then
        local rankId : number = getMemberRankId(clanId, userToRankId)

        --if they are already the highest rank, don't do anything
        for _, rankData in next, clan.RankDataForMembers do
            if rankData.UserId == userToRankId then
                rankData.RankId = rankId - 1 > 0 and rankId - 1 or 1
                break
            end
        end
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.DemoteUser(clanId : string, requestedUserId : number, userToRankId : number, newRole : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "Demote") then
        local rankId : number = getMemberRankId(clanId, userToRankId)

        --if they are already the highest rank, don't do anything
        for _, rankData in next, clan.RankDataForMembers do
            if rankData.UserId == userToRankId then
                rankData.RankId = rankId - 1 > 0 and rankId - 1 or 1
                break
            end
        end
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.RankUser(clanId : string, requestedUserId : number, userToRankId : number, newRole : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "ChangeRank") then
        --if they are already the highest rank, don't do anything
        for _, rankData in next, clan.RankDataForMembers do
            if rankData.UserId == userToRankId then
                rankData.RankId = RankNameToId(newRole)
                break
            end
        end
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 60 * 60 * 24)
    end)
end

function ClanSystem.ChangeTag(clanId : string, requestedUserId : number, newTag : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change tag?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "ChangeTag") then
        clan.ClanTag = newTag
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.ChangeDescription(clanId : string, requestedUserId : number, newDescription : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change description?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "ChangeDescription") then
        clan.Description = newDescription
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.ChangeImage(clanId : string, requestedUserId : number, newImageId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change image?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "ChangeImage") then
        clan.Image = newImageId
    end
    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.ChangeLimit(clanId : string, requestedUserId : number, newLimit : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change limit?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "ChangeLimit") then
        clan.LimitTOMembers = #clan.Members > newLimit and newLimit > 3 and newLimit or clan.LimitTOMembers
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)
end

function ClanSystem.CloseClan(clanId : string, requestedUserId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they close clan?
    local userRole : ClanType.ClanRank = RankIdToRank(getMemberRankId(clanId, requestedUserId)) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "CloseClan") then
        clan.ClanClosed = true
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end, 24 * 60 * 60)
    end)

    ClanStore:UpdateAsync(clanId, function(oldData)
        return nil
    end)
end

function ClanSystem.AdmitUser(clanId : string, requestedUserId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they admit?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId) :: ClanType.ClanRank
    if table.find(userRole.Permissions, "Admit") then
        table.insert(clan.Members, requestedUserId)
        table.remove(clan.JoinRequests, table.find(clan.JoinRequests, requestedUserId))

        table.insert(clan.RankDataForMembers, {UserId = requestedUserId, RankId = 4})

        UpdateClanEvent(clan)

        SafeCall(function()
            ClanCache:UpdateAsync(clanId, function(oldData)
                return clan
            end, 24 * 60 * 60)
        end)
    end
end

return ClanSystem