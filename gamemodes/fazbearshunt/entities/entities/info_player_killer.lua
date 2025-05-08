--[[

	создавая карту в хаммере, ты можешь создать энтити info_player_killer (даже не смотря на то, что такие
	энтити не существует в самом хаммере), и они будут использоваться как спавны для аниматроников.
	:)

]]
AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "point"

function ENT:Initialize()
end