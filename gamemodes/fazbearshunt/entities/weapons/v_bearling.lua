SWEP.PrintName = "Bearling SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_bearling", "Bearling5", 110)
end

SWEP.ViewModel = "models/fh/animatronics/vm/bear5.mdl"
SWEP.Secondary.Automatic = true

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(8,0,-12)

SWEP.HitDelay = 0.1
SWEP.CritHitDelay = 0.4
SWEP.SwayScale = 0.5
SWEP.BobScale = 2

SWEP.HitSize = {
	Min = Vector( -18, -18, -24 ),
	Max = Vector( 18, 18, 16 )
}

SWEP._ArmCounter = 0
SWEP.NextArmHit = util.SharedRandom( "BL5_Arm", 1, 2, 0 )

SWEP.AttackDelay = 0.45
SWEP.CritAttackDelay = 1

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextMeleeAttack")
	self:NetworkVar("Int", 0, "NextArm")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("attack1")
	self:AddAnimation("attack2")
	self:AddAnimation("crit")
	self:AddAnimation("swag")
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() then return end
	
	
	local now = CurTime()
	self:SetNextArm((math.floor(now) % 2))
	
	local name = self:GetNextArm() == 0 and "attack1" or "attack2"
	self:HandleAnimation(name, 0.5, true)
	
	self:SetNextPrimaryFire(now + self.AttackDelay)
	self:SetNextSecondaryFire(now + self.AttackDelay)
	self:SetNextMeleeAttack( now + self.HitDelay )

	self:SetLastAttack(now)
end

function SWEP:SecondaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() then return end
	
	if IsFirstTimePredicted() then
		self:HandleAnimation("crit", 0.5, true)
	end
	local now = CurTime()
	
	if SERVER then
		self:SetNextPrimaryFire(now + self.CritAttackDelay)
		self:SetNextSecondaryFire(now + self.CritAttackDelay)
		self:SetNextMeleeAttack( now + self.CritHitDelay )
	
		self:SetLastAttack(now)
	end
end

function SWEP:DealDamage()
	local ply = self:GetOwner()
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
	local shootpos = ply:GetShootPos()
	
	if SERVER then
		ent:PillGesture('attack', 2, 1, 0.1, 0.3)
		
		net.Start("fh_cooldown_receive")
		net.WriteString("attack")
		net.WriteFloat(self.AttackDelay)
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
		debugoverlay.Box( tr.HitPos, self.HitSize.Min, self.HitSize.Max, 1, Color( 255, 255, 255, 20 ) )
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
		edata:SetNormal(ply:GetAngles():Forward())
		edata:SetMagnitude(3)
		edata:SetScale(7)
		edata:SetColor(0)
		edata:SetFlags(3)
		util.Effect('bloodspray', edata, true, true)
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
		
		local shatterStr = string.format("[%.2f %.2f %d]", x, y, 14)
		
		target:Fire("Shatter", shatterStr, 0, ply)
	elseif class == "func_breakable" then
		target:Fire("Break", "", 0, ply)
	end

    if target:GetMoveType() == MOVETYPE_VPHYSICS then
        local owner = target:GetOwner()
        if (not IsValid(owner)) or (IsValid(owner) and not owner:IsAnimatronic()) then
            local phys = target:GetPhysicsObject()
            if IsValid(phys) then
                local dir = ply:GetAimVector()
                phys:ApplyForceCenter(dir * 10000)
            end
        end
    end
	
    if target:IsPlayer() and !target:IsAnimatronic() or target:IsNPC() then
        ply:EmitSound("bear/bear_knife_hit" .. math.random(1,3) .. ".mp3")
    end

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(ply)
    dmginfo:SetInflictor(self)
	dmginfo:SetDamagePosition(tr.HitPos)
    dmginfo:SetDamage(target:IsPlayer() and 2 or 10)

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
			
	timer.Simple(0, function()
		if IsValid(target) and target:IsPlayer() and !target:Alive() then
			bearScream(ply,ent)
		end
	end)
end

function SWEP:Think()
	local curtime = CurTime()

	local meleetime = self:GetNextMeleeAttack()

	if ( meleetime > 0 and curtime > meleetime ) then
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

function SWEP:AlwaysRunning( )
	return true
end