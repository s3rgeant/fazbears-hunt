SWEP.PrintName = "Springtrap SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_springtrap', 90, true, false, 'Fov of Springtrap')
	SWEP.ViewModelFOV = vfov:GetFloat() or 90
    
    cvars.AddChangeCallback("cl_fov_springtrap", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 90
		end
    end)

end

SWEP.ViewModel = "models/ufmp/fnaf3/vm/Springtrap.mdl"
SWEP.m_WeaponDeploySpeed = 0.6

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-8)

SWEP.HitDelay = 1.4	-- через сколько удар будет произвёден насильно после замаха, если ты долго держишь лкм

SWEP.Arm = "LEFT"

SWEP.IsCharging = false -- переменная для отслеживания удержания ЛКМ

SWEP.HitSize = {
	Min = Vector( -24, -24, -16 ),
	Max = Vector( 24, 24, 16 )
}
SWEP._ArmCounter = 0
SWEP.NextArmHit = util.SharedRandom( "ST_Arm", 1, 2, 0 )

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextMeleeAttack")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("preattack1")
	self:AddAnimation("preattack2")
	self:AddAnimation("attack1")
	self:AddAnimation("attack2")
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	if not IsValid(ent) then return end
	if self.IsCharging or ply.tasered then return end
	if ply:IsFrozen() then return end
	
	if SERVER then
		if !ply:Crouching() then
			ent:PillGesture('swing', 2, 1, 0.1, 0.3)
		end
		ply:EmitSound("fnaf3/pre-hit.mp3")
	end
	
	local name = (math.Round( self.NextArmHit ) == 1) and "preattack1" or "preattack2"
	
	if IsFirstTimePredicted() then
		self:HandleAnimation(name, 2)
	end
	
	self.IsCharging = true
	self:SetNextMeleeAttack(CurTime() + self.HitDelay)
end

function SWEP:DealDamage(ply, ent)
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	if not IsValid(ent) then return end
	local shootpos = ply:GetShootPos()
	
	local name = (math.Round( self.NextArmHit ) == 1) and "attack1" or "attack2"
	local now = CurTime()
	
	if IsFirstTimePredicted() then
		self:HandleAnimation(name, 0.6)
	
		self:SetLastAttack(now)
		self:SetNextPrimaryFire(now + 1.5)
		
		self._ArmCounter = self._ArmCounter + 1
		self.NextArmHit = util.SharedRandom( "ST_Arm", 1, 2, self._ArmCounter )
	end
	
	if SERVER then
		ent:PillStopGesture('swing', 0.1)
		
		if !ply:Crouching() then
			ent:PillGesture('attack', 2, 1, 0.1, 0.7)
		end
	
		net.Start("fh_cooldown_receive")
		net.WriteString("attack")
		net.WriteFloat(1.5)
		net.Send(ply)
	end
	
	ply:LagCompensation(true)
	
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
		if SERVER then
			ply:EmitSound("fnaf3/hit-miss.mp3")
		end
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
		return
	end
	
	local class = target:GetClass()
	if class == "func_breakable_surf" then
		local localHit = target:WorldToLocal(tr.HitPos)
		
		local mins = target:OBBMins()
		local maxs = target:OBBMaxs()
		local size = maxs - mins
		
		local x, y = 0.5, 0.5

		if size.x <= size.y and size.x <= size.z then
			x = (localHit.y - mins.y) / math.max(size.y, 1)
			y = (localHit.z - mins.z) / math.max(size.z, 1)
		elseif size.y <= size.x and size.y <= size.z then
			x = (localHit.x - mins.x) / math.max(size.x, 1)
			y = (localHit.z - mins.z) / math.max(size.z, 1)
		else
			x = (localHit.x - mins.x) / math.max(size.x, 1)
			y = (localHit.y - mins.y) / math.max(size.y, 1)
		end

		x = math.Clamp(x, 0, 1)
		y = math.Clamp(y, 0, 1)
		
		local shatterStr = string.format("[%.2f %.2f %d]", x, y, 25)
		
		target:Fire("Shatter", shatterStr, 0, ply)
	elseif class == "func_breakable" then
		target:Fire("Break", "", 0, ply)
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
	
	ply:LagCompensation(false)
		
	if GetConVar("bust_doors"):GetBool() then
		if target:GetClass() == "prop_door_rotating" then
			BustRotatingDoor(ply, target)
			sound.Play("Wood_Furniture.Break", tr.HitPos, 100, math.random(95,105), 1)
			sound.Play("Plastic_Box.Break", tr.HitPos, 100, math.random(95,105), 1)
			return true
		elseif target:GetClass() == "func_door_rotating" then
			
			sound.Play("Wood_Furniture.Break", tr.HitPos, 100, math.random(95,105), 1)
			sound.Play("Plastic_Box.Break", tr.HitPos, 100, math.random(95,105), 1)
			BustFuncDoor(ply, target)
			return true
		end
	end
	
	if target:IsPlayer() and !target:IsAnimatronic() or target:IsNPC() then
		ply:EmitSound("fnaf3/hit.mp3")
		
		target:AnimRestartGesture(4, ACT_FLINCH_HEAD, true)
		
		net.Start("AnimRestartGesture")
			net.WriteEntity(target)
			net.WriteInt(4, 4)
			net.WriteInt(ACT_FLINCH_HEAD, 12)
		net.SendPVS(target:GetPos())
		
		if target:GetNW2Bool("KillerObsessed") then
			net.Abort()
			
			self:SetNextPrimaryFire(now + 1)
	
			net.Start("fh_cooldown_receive")
			net.WriteString("attack")
			net.WriteFloat(1)
			net.Send(ply)
		end
	end
end

function SWEP:Think()
	local curtime = CurTime()
	
	if self.IsCharging and not self:GetOwner():KeyDown(IN_ATTACK) then
        self.IsCharging = false
        self:SetNextMeleeAttack(0)
        self:DealDamage()
        return
    end

	local meleetime = self:GetNextMeleeAttack()
	if ( meleetime > 0 and curtime > meleetime ) then
        self.IsCharging = false
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end