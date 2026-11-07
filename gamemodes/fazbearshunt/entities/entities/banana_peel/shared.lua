AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "#banana_peel"
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
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
	if SERVER then
		self:SetTrigger(true)
	end
	
	self:SetHealth(10)

	local phys = self:GetPhysicsObject()
	if phys:IsValid() then
		phys:Wake()
		phys:SetDamping(0, 9999)
	end
	
    self.SpawnTime = CurTime()
end

ENT.NoRagdollPills = {
	["pill_wgfreddy2"] = true,
}
	
if SERVER then
	local zeroveloc = Vector(0,0,0)
	local function createAnimatronicRagdoll(self, ply)
		local pill = pills.getMappedEnt(ply)
						
		if not IsValid(pill) then return NULL end
		
		local pillName = pill:GetPillName()
		if self.NoRagdollPills[pillName] then return NULL end
		
		local ragdoll = ents.Create("prop_ragdoll")
		if not IsValid(ragdoll) then return NULL end
		
		ragdoll:SetModel(pill:GetModel())
		ragdoll:SetPos(pill:GetPos())
		ragdoll:SetAngles(pill:GetAngles())
		ragdoll:SetSkin(pill:GetSkin())
		ragdoll:SetColor(pill:GetColor())
		ragdoll:SetRenderMode(pill:GetRenderMode())
		ragdoll:SetMaterial(pill:GetMaterial() or "")
		ragdoll:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		ragdoll:SetOwner(ply)

		if pill.GetBodyGroups then
			for _, bodygroup in ipairs(pill:GetBodyGroups()) do
				ragdoll:SetBodygroup(bodygroup.id, pill:GetBodygroup(bodygroup.id))
			end
		end
		ragdoll:Spawn()
		ragdoll:Activate()

		if not IsValid(ragdoll:GetPhysicsObject()) then ragdoll:Remove() return NULL end
		
		ragdoll.ShouldNotCollide = function(ent, ent2)
			if ent:GetClass() == ent2:GetClass() then return true end
			if ent2:IsPlayer() then return true end
		end
		
		local plyvel = ply:GetVelocity()
		
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local bone = ragdoll:GetPhysicsObjectNum(i)
			
			if bone and bone:IsValid() then
				local bonepos, boneang = pill:GetBonePosition(pill:TranslatePhysBoneToBone(i))
				
				if bonepos then bone:SetPos(bonepos) end
				if boneang then bone:SetAngles(boneang) end
				bone:SetVelocity(plyvel)
			end
		end
		
		playVoiceline(killers.GetName(pillName), "trip", ply)
		
		-- ПРЯЧЕМ ИГРОКА НАХУЙ
		
		pill:SetMaterial("models/invisible")
		pill:SetNoDraw(true)
		ply:SetNotSolid(true)
		ply:SetMoveType(MOVETYPE_NONE)
		pill:DrawShadow(false)
		
		local wep = ply:GetViewModel() if IsValid(wep) then wep:SetNoDraw(true) end
		
		local hookname = "fh_banana_ragdoll_camera" .. ply:EntIndex()
		
		hook.Add("Think", hookname, function()
			if not IsValid(ragdoll) then hook.Remove("Think", hookname) return end
			if not IsValid(ply) then hook.Remove("Think", hookname) return end
			if not IsValid(pill) then hook.Remove("Think", hookname) return end
			
			ply:SetPos(ragdoll:GetPos())
		end)
		
		timer.Simple(3, function()
			hook.Remove("Think", hookname)
			if IsValid(ragdoll) then
				if IsValid(ply) then
					ply:SetPos(ragdoll:GetPos())
					if ply:IsStuck() then
						ply:Unstuck()
					end
				end
				ragdoll:Remove()
			end
			
			if not IsValid(ply) then return end
			ply:SetNWBool("banana_slipped", nil)
			ply:SetNotSolid(false)
			ply:NoPlayerCollide(1)
			ply:SetLocalVelocity(zeroveloc)
		
			local wep = ply:GetViewModel() if IsValid(wep) then wep:SetNoDraw(false) end
			
			ply:SetMoveType(MOVETYPE_WALK)
			
			if not IsValid(pill) then return end
			pill:SetMaterial("")
			pill:DrawShadow(true)
			pill:SetNoDraw(false)
		end)
	end

	function ENT:SlipPlayer(ent)
		if ent:IsNPC() or ent:IsPlayer() and (!ent:GetPill() or ent:GetPill() and !ent:GetPill().cloaked) and ent:Alive() then
			ent:EmitSound("slip_start.wav")
			local phys = self:GetPhysicsObject()
			if IsValid(phys) then
				phys:ApplyForceCenter((-ent:GetVelocity() + -ent:GetForward()) * 5)
			end

			ent:SetNWBool("banana_slipped", true)
			ent:SetNWFloat("banana_slipped_time", CurTime())
			ent._LastBanana = self

			if ent:IsPlayer() then
				stats.Add(ent, "slipped_on_banana", 1)
				for i = 1, 20 do
					timer.Simple(0 + i/450, function()
						ent:SetEyeAngles(ent:EyeAngles() + Angle(-1,0,0))
					end) 
				end
				
				if conVars.fh_banana_ragdollize:GetBool() then
					if ent:IsSprinting() and pills.hasMappedEnt(ent) then
						createAnimatronicRagdoll(self, ent)
					end
				end
				
				timer.Simple(0.1, function()
					if ent:OnGround() and ent:GetNWBool("banana_slipped", false) then
						ent:SetNWBool("banana_slipped", nil)
						ent:TakeDamage(math.random(1,2), self, self)
						ent:EmitSound("slip_end.wav")
					end
				end)
			end
			ent:SetLocalVelocity(Vector(math.random(-300,300),math.random(-300,300),300))
		end 
	end
	
	function ENT:StartTouch(v)
		local curtime = CurTime()
		if v:IsPlayer() and v:GetMoveType() ~= MOVETYPE_NOCLIP and !v:GetNWBool("banana_slipped", false) and curtime - v:GetNWFloat("banana_slipped_time", 0) > 0.2 then
			if curtime - self.SpawnTime <= 0.1 and v == self:GetOwner() then return end
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
	
	hook.Add("OnPlayerHitGround", "IsBananaSlipped", function(v, inwater)
		if v:GetNWBool("banana_slipped", false) then
			v:SetNWBool("banana_slipped", nil)
			if not inwater then
				v:TakeDamage(math.random(1,2), v._LastBanana, v._LastBanana)
				v:EmitSound("slip_end.wav")
			end
		end
	end)
	
	hook.Add("OnPillHitGround", "IsBananaSlipped", function(v, ent, inwater)
		if v:GetNWBool("banana_slipped", false) then
			v:SetNWBool("banana_slipped", nil)
			if not inwater then
				v:TakeDamage(math.random(1,2), v._LastBanana, v._LastBanana)
				v:EmitSound("slip_end.wav")
			end
		end
	end)
	
	function ENT:OnTakeDamage(dmginfo)
		local attacker = dmginfo:GetAttacker()
		local owner = self:GetOwner()
		
		if attacker:IsPlayer() and attacker:IsSurvivor() and attacker ~= owner then return 0 end
		
		local wep = dmginfo:GetInflictor()
		local pos = self:GetPos()
		
		if wep:IsValid() and wep:IsWeapon() and wep:GetClass() == "v_clown" then
			local posd = dmginfo:GetDamagePosition()
			local dist = pos:Distance(posd)
			
			dmginfo:SetDamage(166 / dist)
		end

		self:TakePhysicsDamage(dmginfo)
		
		local health = self:Health()
		health = health - dmginfo:GetDamage()
		self:SetHealth(health)
		
		self:EmitSound(")physics/flesh/flesh_squishy_impact_hard" .. math.random(3) .. ".wav")

		if health <= 1 then
			local effectdata = EffectData()
			effectdata:SetStart( pos )
			effectdata:SetOrigin( pos )
			effectdata:SetScale( 1 )
			util.Effect( "GlassImpact", effectdata )
			
			self:Remove()
		end
	end
	
	function ENT:FHGravGunPunt()
		return false
	end
end

function ENT:DragHandle(wep, ent, dragger)
	return false
end