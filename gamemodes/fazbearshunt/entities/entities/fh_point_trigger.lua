AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "point"

ENT.Mins = Vector(-10, -10, -5)
ENT.Maxs = Vector(10, 10, 15)

function ENT:Initialize()
	if SERVER then
		self:SetTrigger(true)
	end
	
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionBounds(self.Mins, self.Maxs)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
	self:UseTriggerBounds(true, 24)
end

function ENT:Touch(ent)
end