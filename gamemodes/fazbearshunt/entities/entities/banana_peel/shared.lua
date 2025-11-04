AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Banana Peel"
ENT.Category = "Banana Peel"
ENT.Author = "Froze"

if CLIENT then
	killicon.Add("banana_peel","weapons/banana_killicon",Color(255,255,255));
end

function ENT:Initialize()
	self:SetModel("models/props_farm/scenes/bananana_peel.mdl")
	self:PhysicsInitBox(self:OBBMins(), self:OBBMaxs())
	self:SetCollisionBounds(self:OBBMins(), self:OBBMaxs())
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	if SERVER then
		self:SetTrigger(true)
	end

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
		phys:AddAngleVelocity(-phys:GetAngleVelocity() * 0.9)
		phys:SetDamping(0, 10)
	end
	
    self.SpawnTime = CurTime()
	self.Owner = self.Owner or nil
end
	
if SERVER then
	function ENT:SlipPlayer(ent)
		if ent:IsNPC() or ent:IsPlayer() and (!ent:GetPill() or ent:GetPill() and !ent:GetPill().cloaked) and ent:Alive() then
			ent:EmitSound("slip_start.wav")
			ent:SetLocalVelocity(Vector(math.random(-300,300),math.random(-300,300),300))
			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				phys:ApplyForceCenter((-ent:GetVelocity() + -ent:GetForward()) * 100)
			end

			ent:SetNWBool("banana_slipped", true)
			ent:SetNWFloat("banana_slipped_time", CurTime())

			if ent:IsPlayer() then
				stats.Add(ent, "slipped_on_banana", 1)
				for i = 1, 20 do
					timer.Simple(0 + i/450, function()
						ent:SetEyeAngles(ent:EyeAngles() + Angle(-1,0,0))
					end) 
				end
			end
		end 
	end
	
    function ENT:StartTouch(v)
		if CurTime() - self.SpawnTime > 0.1 and v:IsPlayer() and v:GetMoveType() != MOVETYPE_NOCLIP 
		and !v:GetNWBool("banana_slipped", false) and CurTime() - v:GetNWBool("banana_slipped_time", 0) > 0.2 then
			
			self:SlipPlayer(v) 
		end
	end

    hook.Add("GravGunPickupAllowed", "nobananapickup", function(ply, ent)
        if ent:GetClass() == "banana_peel" then
			return false
		end
	end)

    hook.Add("GravGunPunt", "nobananapunt", function(ply, ent)
        if ent:GetClass() == "banana_peel" then
			return false
		end
	end)

    hook.Add("Think", "IsBananaSlipped", function()
        for _, v in player.Iterator() do
            if (v:IsPlayer()) and v:Alive() and v:OnGround() 
			and v:GetNWBool("banana_slipped", false) and CurTime() - v:GetNWBool("banana_slipped_time", 0) > 0.2 then
                v:SetNWBool("banana_slipped", nil)
				v:TakeDamage(math.random(1,2), self, self)
                v:EmitSound("slip_end.wav") 
            end
        end
	end)
end