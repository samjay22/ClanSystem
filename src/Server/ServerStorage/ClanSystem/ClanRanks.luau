--!strict
local ClanTypes = require(game.ReplicatedStorage.Types.Clan)

return {
    {
        Id = 1,
        Name = "Owner",
        Permissions = {
            "Invite",
            "Kick",
            "Promote",
            "Demote",
            "ChangeRank",
            "ChangeDescription",
            "ChangeTag",
            "ChangeImage",
            "ChangeLimit",
            "ChangeRankOrder",
            "ChangeRankName",
            "Ban",
            "Admit",
        },
    },

    {
        Id = 2,
        Name = "Co-Owner",
        Permissions = {
            "Invite",
            "Kick",
            "Promote",
            "Demote",
            "ChangeRank",
            "ChangeDescription",
            "ChangeTag",
            "ChangeImage",
            "ChangeLimit",
            "ChangeRankOrder",
            "ChangeRankName",
            "Ban",
            "Admit",
        },
    },

    {
        Id = 3,
        Name = "Officer",
        Permissions = {
            "Invite",
            "Kick",
        },
    },

    {
        Id = 4,
        Name = "Member",
        Permissions = {},
    },
} :: {ClanTypes.ClanRank}