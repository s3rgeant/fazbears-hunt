AddCSLuaFile()
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

function ENT:Initialize()
    self:SetModel("models/humans/group01/male_07.mdl")
	self:SetAngles(Angle(0, 0, 0))
	self:ResetSequence("test01")
	self:SetCycle(0)
	self:SetNoDraw(true)
	self:SetPlaybackRate(1)
end

function ENT:Think()
	self:NextThink( CurTime() )

	return true
end