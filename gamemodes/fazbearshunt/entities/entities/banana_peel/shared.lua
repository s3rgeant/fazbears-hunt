AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Banana Peel"
ENT.Category = "Banana Peel"
ENT.Author = "Froze"
ENT.Spawnable = true
ENT.AdminOnly = false

if CLIENT then
	killicon.Add("banana_peel","weapons/banana_killicon",Color(255,255,255));
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_farm/scenes/bananana_peel.mdl")
		self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
		self:SetCollisionBounds(self:OBBMins(), self:OBBMaxs())
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:Wake()
            phys:AddAngleVelocity(-phys:GetAngleVelocity() * 0.9)
            phys:SetDamping(0, 10)
		end
		
		self.Owner = self.Owner or nil
	end
	
	function ENT:SlipPlayer(ent)
		if ent:IsNPC() or ent:IsPlayer() and (ent:Team() != TEAM_SPECTATOR and ent:Alive()) then
			ent:EmitSound("slip_start.wav")
			ent:SetVelocity(Vector(math.Rand(150, 250) * (math.random(2) == 1 and 1 or -1), math.Rand(150, 250) * (math.random(2) == 1 and 1 or -1), 200) + ent:GetUp() * 100)
			local phys = self:GetPhysicsObject()
			phys:ApplyForceCenter((-ent:GetVelocity() + -ent:GetForward()) * 25)
			
			timer.Simple( 0.1, function()
				ent:SetNWBool("banana_slipped", true)
			end)
			if ent:IsPlayer() then
				for i = 1, 45 do
					timer.Simple(0 + i/1000, function()
						ent:SetEyeAngles(ent:EyeAngles() + Angle(-1,0,0))
					end) 
				end
			end
		end 
	end
	
	function ENT:Think()
		local find_ent = ents.FindInSphere(self:GetPos(), 25)
		for k, v in pairs(find_ent) do
			if ( v:IsPlayer() and v:GetMoveType() != MOVETYPE_NOCLIP ) and v:GetNWBool("banana_slipped", false) == false then
				self:SlipPlayer(v) 
			end
		end
	end

    hook.Add("Think", "IsBananaSlipped", function()
        for _, v in player.Iterator() do
            if (v:IsPlayer()) and v:Team() != TEAM_SPECTATOR and v:IsOnGround() and v:GetNWBool("banana_slipped", false) then
                v:SetNWBool("banana_slipped", false)
				v:TakeDamage(math.random(1,2), self, self)
                v:EmitSound("slip_end.wav") 
            end
        end
	end)
end