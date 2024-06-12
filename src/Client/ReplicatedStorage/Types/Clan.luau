--!strict

export type ClanRank = {
    Id: number,
    Name: string,
    Permissions: {string},
}

export type ClanRankData = {
    UserId: number,
    RankId: number,
}

--Runtime object
export type Clan = {
    Id: string,
    Name: string,
    ClanTag : string,
    Image : number, -- group id
    Description: string,
    Owner: number,
    LimitTOMembers : number,
    ClanClosed : boolean,

    Members: {number}, --list that contains user ids of users who are members of the clan
    JoinRequests: {number},     --list that contains user ids of users who have requested to join the clan
    BannedUsers: {number},      --list that contains user ids of users who are banned from the clan
    RankDataForMembers : {ClanRankData}, -- we need to keep track of this for quick access
    --May be used for future features
    CreatedAt: number,
    UpdatedAt: number,
}

--clan permission
return {
    
}