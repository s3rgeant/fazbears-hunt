ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Cupcake Mine"
ENT.Author = "sergeant"
ENT.Category = "FazbearsHunt"
ENT.Spawnable = false
ENT.AdminSpawnable = true

function ENT:Initialize()
	self:SetModel("models/team vr/cupcake.mdl")
	self:SetModelScale(0.4, 0)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	--self:SetColor(Color(255, 255, 255, 100))
	self:SetRenderMode( RENDERMODE_TRANSCOLOR )
	
	local phys = self:GetPhysicsObject()
	
	if phys:IsValid() then
		phys:Wake()
	end
	
	self:SetHealth(10)
	
	timer.Create("CheckPlayersTimer_" .. self:EntIndex(), 0.5, 0, function()
		if !IsValid(self) then return end
		--self:CheckForPlayers()
	end)
end