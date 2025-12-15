SWEP.PrintName = "Bearling SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_bearling', 110, true, false, 'Fov of Bearling5')
	SWEP.ViewModelFOV = vfov:GetFloat() or 110
    
    cvars.AddChangeCallback("cl_fov_bearling", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 110
		end
    end)
end

SWEP.ViewModel = "models/fh/animatronics/vm/bear5.mdl"
SWEP.Secondary.Automatic = true

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
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("attack1")
	self:AddAnimation("attack2")
	self:AddAnimation("crit")
	self:AddAnimation("swag")
end

function SWEP:PrimaryAttack()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() then return end
	
	local name = (math.Round( self.NextArmHit ) == 1) and "attack1" or "attack2"
	
	if IsFirstTimePredicted() then
		self:HandleAnimation(name, 0.5, true)
		
		self._ArmCounter = self._ArmCounter + 1
		self.NextArmHit = util.SharedRandom( "BL5_Arm", 1, 2, self._ArmCounter )
	end
	local now = CurTime()
	
	self:SetNextPrimaryFire(now + self.AttackDelay)
	self:SetNextSecondaryFire(now + self.AttackDelay)
	self:SetNextMeleeAttack( now + self.HitDelay )
	
	self:SetLastAttack(now)
end

function SWEP:SecondaryAttack()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() then return end
	
	if IsFirstTimePredicted() then
		self:HandleAnimation("crit", 0.5, true)
	end
	local now = CurTime()
	
	self:SetNextPrimaryFire(now + self.CritAttackDelay)
	self:SetNextSecondaryFire(now + self.CritAttackDelay)
	self:SetNextMeleeAttack( now + self.CritHitDelay )
	
	self:SetLastAttack(now)
end

function SWEP:DealDamage()
    local ply = self.Owner
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
	
	if SERVER then
		ent:PillGesture('attack', 2, 1, 0.1, 0.3)
		
		net.Start("fh_net_killer_change")
		net.WriteString("attack")
		net.WriteFloat(self.AttackDelay)
		net.Send(ply)
	end

    ply:LagCompensation(true)

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
        filter = ply,
        mask = MASK_SHOT_HULL
    })

    if not IsValid(tr.Entity) then
        tr = util.TraceHull({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
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
        edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
        util.Effect("BloodImpact", edata, true, true)

		local edata = EffectData()
		edata:SetOrigin(target:WorldSpaceCenter())
		edata:SetNormal(ply:GetAngles():Forward())
		edata:SetMagnitude(3)
		edata:SetScale(10)
		edata:SetColor(0)
		edata:SetFlags(3)
		util.Effect('bloodspray', edata, true, true)
    end

    if CLIENT then
        ply:LagCompensation(false)
        return
    end

    local class = target:GetClass()
    if class == "func_breakable" or class == "func_breakable_surf" then
        target:Fire("Shatter", "0", 0)
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

    local dmginfo = DamageInfo()
    dmginfo:SetAttacker(ply)
    dmginfo:SetInflictor(self)
    dmginfo:SetDamage(2)

    SuppressHostEvents(NULL)
    target:TakeDamageInfo(dmginfo)
    SuppressHostEvents(ply)

    local effectData = EffectData()
    effectData:SetOrigin(tr.HitPos)
    effectData:SetStart(ply:GetShootPos())
    effectData:SetEntity(tr.Entity or ply)
    effectData:SetNormal(tr.HitNormal)
    effectData:SetSurfaceProp(tr.SurfaceProps or 0)
    effectData:SetDamageType(DMG_CLUB)
    effectData:SetHitBox(tr.HitBox or 0)
    effectData:SetScale(1)
    util.Effect("Impact_GMOD", effectData, true, true)

    ply:LagCompensation(false)
	
    if target:IsPlayer() and !target:IsAnimatronic() or target:IsNPC() then
        ply:EmitSound("bear/bear_knife_hit" .. math.random(1,3) .. ".mp3")
    end
			
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