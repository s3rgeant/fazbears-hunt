AddCSLuaFile()

function SWEP:Melee(ply, ent)
	self:PreMelee(ply, ent)
	
	ply:LagCompensation(true)
	
	local shootpos = ply:GetShootPos()
	
	local tr = util.TraceLine({
		start = shootpos,
		endpos = shootpos + ply:GetAimVector() * 110,
		filter = ply,
		mask = MASK_SHOT_HULL
	})
	
	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = shootpos,
			endpos = shootpos + ply:GetAimVector() * 110,
			filter = ply,
			mins = self.HitSize.Min,
			maxs = self.HitSize.Max,
			mask = MASK_SHOT_HULL
		})
	end
	
	local target = tr.Entity
	if not IsValid(target) then
		ply:LagCompensation(false)
		self:MeleeNoTarget(ply, ent, tr)
		return
	end
	
	if target:IsPlayer() and target:IsSurvivor() then
		local edata = EffectData()
		edata:SetOrigin(target:NearestPoint(tr.HitPos))
		edata:SetEntity(target)
		util.Effect("BloodImpact", edata, true, true)
	end
	
	if CLIENT then
		ply:LagCompensation(false)
		self:PostMelee(ply, ent, target, tr, dmginfo)
		return
	end
	
	local class = target:GetClass()
	if class == "func_breakable" or class == "func_breakable_surf" then
		target:Fire("Shatter", "0", 0)
	end
	
	if target:GetMoveType() == MOVETYPE_VPHYSICS then
		local owner = target:GetOwner()
		if (not IsValid(owner)) or (IsValid(owner) and owner:IsPlayer() and !owner:IsAnimatronic()) then
			local phys = target:GetPhysicsObject()
			if IsValid(phys) then
				local dir = ply:GetAimVector()
				phys:ApplyForceCenter(dir * 10000)
			end
		end
	end
	
	local dmginfo = DamageInfo()
	dmginfo:SetAttacker(ply)
	dmginfo:SetInflictor(self)
	dmginfo:SetDamage(target:IsPlayer() and 60 or 160)
	
	SuppressHostEvents(NULL)
	target:TakeDamageInfo(dmginfo)
	SuppressHostEvents(ply)
	
	local effectData = EffectData()
	effectData:SetOrigin(tr.HitPos)
	effectData:SetStart(shootpos)
	effectData:SetEntity(tr.Entity or ply)
	effectData:SetNormal(tr.HitNormal)
	effectData:SetSurfaceProp(tr.SurfaceProps or 0)
	effectData:SetDamageType(DMG_CLUB)
	effectData:SetHitBox(tr.HitBox or 0)
	effectData:SetScale(1)
	util.Effect("Impact_GMOD", effectData, true, true)
	
	self:PostMelee(ply, ent, target, tr, dmginfo)
end