--!strict
local DataStoreService : DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService : MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService : HttpService = game:GetService("HttpService")

local ClanStore : DataStore = DataStoreService:GetDataStore("ClanStore")

-- in memory queue to keep track of clan activities, prevents two actions from happening at once
local ClientActionQueue : MemoryStoreQueue = MemoryStoreService:GetQueue("ClientActionQueue") 
local ClanCache : MemoryStoreSortedMap = MemoryStoreService:GetSortedMap("ClanCache") -- in memory cache across servers, quick updates -- in memory cache across servers, quick updates

local ClanType = require(game.ReplicatedStorage.Types.Clan)
local ClanRankData = require(game.ServerStorage.ClanSystem.ClanRanks)
local Methods = require(game.ServerStorage.Utility.Methods)

local ClanSystem = {}
export type ClanSystem = typeof(ClanSystem)

local SafeCall = Methods.SafeCall
function ClanSystem.CreateClan(name : string, tag : string, description : string, creator : Player, imageId : number?) : ClanType.Clan
    local clanId : string = HttpService:GenerateGUID(false)
    local clan : ClanType.Clan = {
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
    end)

    --looks like we don't have the clan in cache, let's fetch it from long term storage
    if not clan then
        clan = SafeCall(function()
            local data = ClanStore:GetAsync(id)
            if data then
                local clan : ClanType.Clan = {
                    Id = id,
                    Name = data.Na,
                    Tag = data.Ta,
                    Description = data.De,
                    Owner = data.Ow,
                    ImageId = data.Im,
                    Members = data.Me,
                    Requests = data.Re,
                    Banned = data.Ba,
                    CreatedAt = data.Ca,
                    UpdatedAt = data.Up,
                    ClanClosed = data.Cl,
                    LimitTOMembers = data.Li,
                    RankDataForMembers = data.Ra
                }

                return clan
            end
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
        if rank.name == rankName then
            foundRankId = rank.Id
            break
        end
    end

    return foundRankId or error("Rank not found")
end

function ClanSystem.PromoteUser(clanId : string, requestedUserId : number, userToRankId : number, newRole : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[userToRankId].RankId)
    if table.find(userRole.Permissions, "Promote") then
        clan.RankDataForMembers[requestedUserId].RankId = RankNameToId(newRole)
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.DemoteUser(clanId : string, requestedUserId : number, userToRankId : number, newRole : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[userToRankId].RankId)
    if table.find(userRole.Permissions, "Demote") then
        clan.RankDataForMembers[requestedUserId].RankId = RankNameToId(newRole)
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.RankUser(clanId : string, requestedUserId : number, userToRankId : number, newRole : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they rank?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[userToRankId].RankId)
    if table.find(userRole.Permissions, "ChangeRank") then
        clan.RankDataForMembers[requestedUserId].RankId = RankNameToId(newRole)
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.ChangeTag(clanId : string, requestedUserId : number, newTag : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change tag?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId)
    if table.find(userRole.Permissions, "ChangeTag") then
        clan.Tag = newTag
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.ChangeDescription(clanId : string, requestedUserId : number, newDescription : string)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change description?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId)
    if table.find(userRole.Permissions, "ChangeDescription") then
        clan.Description = newDescription
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.ChangeImage(clanId : string, requestedUserId : number, newImageId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change image?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId)
    if table.find(userRole.Permissions, "ChangeImage") then
        clan.ImageId = newImageId
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.ChangeLimit(clanId : string, requestedUserId : number, newLimit : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they change limit?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId)
    if table.find(userRole.Permissions, "ChangeLimit") then
        clan.LimitTOMembers = #clan.Members > newLimit and newLimit > 3 and newLimit or clan.LimitTOMembers
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
end

function ClanSystem.CloseClan(clanId : string, requestedUserId : number)
    local clan : ClanType.Clan = ClanSystem.GetClanById(clanId)

    --can they close clan?
    local userRole : ClanType.ClanRank = RankIdToRank(clan.RankDataForMembers[requestedUserId].RankId)
    if table.find(userRole.Permissions, "CloseClan") then
        clan.Closed = true
    end

    SafeCall(function()
        ClanCache:UpdateAsync(clanId, function(oldData)
            return clan
        end)
    end)
    
end

return ClanSystem