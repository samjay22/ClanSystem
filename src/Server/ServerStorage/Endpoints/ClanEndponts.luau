--!strict
local ClanSystem = require(game.ServerStorage.ClanSystem)

local Endpoints = {}
export type Endpoints = typeof(Endpoints)

function Endpoints.CreateClan(name : string, tag : string, description : string, creator : Player, imageId : number?)
    ClanSystem.CreateClan(name, tag, description, creator, imageId)
end

return Endpoints