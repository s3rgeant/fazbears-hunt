SWEP.PrintName = "Foxy SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_foxy", "Foxy", 100)
end

SWEP.ViewModel = "models/speps/vm/oldfoxy.mdl"
SWEP.m_WeaponDeploySpeed = 0.5
SWEP.LandHold = 0.2
SWEP.JumpHold = 0.5

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-8)

SWEP.HitDelay = 1	-- через сколько удар будет произвёден насильно после замаха, если ты долго держишь лкм

SWEP.ChargeStartTime = 0 -- время начала удержания ЛКМ

SWEP.HitSize = {
	Min = Vector( -24, -24, -32 ),
	Max = Vector( 24, 24, 16 )
}

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
	self:NetworkVar( "Bool", "Charging" )
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("holster")
	self:AddAnimation("draw")
	self:AddAnimation("preattack")
	self:AddAnimation("attack")
	self:AddAnimation("laugh")
end

function SWEP:Initialize()
	local owner = self:GetOwner()
	if not IsValid(owner) then return end
	
	local ent = owner:GetPillCostume()
	if not IsValid(ent) then return end
	
	if ent:GetPillName() == "pill_endo02" then
		self.ViewModelFOV = GetConVar("cl_fov_endo"):GetFloat() or 100
	end
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	local ct = CurTime()
	
	if not ply.GetFoxyRushing or !ply:GetFoxyRushing() then return end
	
	ply:SetFoxyRushEnd(ct + 1)
	
	if !IsValid(ent) then return end
	
	if self:GetCharging() or ply.tasered then return end
	
	if ply:IsFrozen() then return end
	
	if SERVER then
		--ent:PillGesture('swing', 2, 1, 0.1, 0.3)
	end
	
	self:HandleAnimation("preattack", 2)
	
	self:SetPlaybackRate(1)
	
    self:SetCharging( true )
    self.ChargeStartTime = ct
	
	self:SetNextMeleeAttack( ct + self.HitDelay )
end

function SWEP:SecondaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if not IsValid(ent) then return end
	FoxyCharge(ply, ent)
end

function SWEP:DealDamage()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	local now = CurTime()
	
    if IsFirstTimePredicted() then
		self:HandleAnimation("attack", 0.6)
    end
	
	self:SetPlaybackRate(1)
	
	self:SetNextPrimaryFire(now + 2)
	self:SetLastAttack(now)
	
	if SERVER then
		ent:PillGesture('melee', 2, 1, 0.1, 0.7)
		
		cooldown.Set(ply, "kill", 2)
		cooldown.Send(ply, "kill")
		
		foxy.EndCharge(ply)
		
		foxy.Stun(ply)

		timer.Simple(5, function()
			if IsValid(ply) then
				receiveTokensBack(ply, ent)
			end
		end)
	end
	
	if CLIENT then
		RemoveRMBHint()
	end
		
	ply:LagCompensation(true)

	local tr = util.TraceLine( {
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
		filter = ply,
		mask = MASK_SHOT_HULL
	} )

	if ( !IsValid( tr.Entity ) ) then
		tr = util.TraceHull( {
			start = ply:GetShootPos(),
			endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
			filter = ply,
			mins = self.HitSize.Min,
			maxs = self.HitSize.Max,
			mask = MASK_SHOT_HULL
		} )
		debugoverlay.Box(tr.HitPos, self.HitSize.Min, self.HitSize.Max, 5, Color(255, 0, 0))
	end
	debugoverlay.Line(ply:EyePos(), tr.HitPos, 5, Color(255, 0, 0), true)
	
	local target = tr.Entity
	
	if !IsValid(target) then 
		ply:LagCompensation(false)
		if SERVER then
			playVoiceline('foxy', 'miss', ply, 0.8)
		end
		return 
	end
	
	if target:IsPlayer() and target:IsSurvivor() then
	
		local edata = EffectData()
		edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
		util.Effect("BloodImpact", edata)
		
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
		local phys = target:GetPhysicsObject()
		if IsValid(phys) then
			local dir = ply:GetAimVector()
			phys:ApplyForceCenter(dir * 10000)
		end
	end
	
	local dmginfo = DamageInfo()
	dmginfo:SetAttacker( ply )
	dmginfo:SetInflictor( self )
	dmginfo:SetDamage( 55 )

	SuppressHostEvents( NULL )
	target:TakeDamageInfo( dmginfo )
	SuppressHostEvents( ply )
	
	if target:IsPlayer() then
		StartBleeding(target, ply)
		timer.Simple(5, function()
			if IsValid(target) then
				StopBleeding(target)
			end
		end)
	end
	
	ply:LagCompensation(false)
	
	if target:IsNPC() then
		target:TakeDamage(99999, ply)
		return 
	end
	
	if (target:IsPlayer() and target:IsSurvivor()) or target:IsNPC() then
		ply:EmitSound(")fnaf3/spr_punch_hit.wav")
	end
end

SWEP.run_string = "run"
SWEP.run_act = ACT_VM_SPRINT_IDLE
function SWEP:Think()
	local ply = self:GetOwner()
	local curtime = CurTime()
	
	if self:GetCharging() and not ply:KeyDown(IN_ATTACK) then
        self:SetCharging(false)
        self:SetNextMeleeAttack(0)
        self:DealDamage()
        return
    end

	if self:GetCharging() then
		ply:LagCompensation(true)
		
		local forward = ply:GetAimVector()
		local startPos = ply:GetShootPos()
		local endPos = startPos + forward * 90 -- немного меньше расстояние, чтобы не было фейковых попаданий

		local mins = Vector(-10, -10, -10)
		local maxs = Vector(10, 10, 10)

		local tr = util.TraceHull({
			start = startPos,
			endpos = endPos,
			filter = ply,
			mins = mins,
			maxs = maxs,
			mask = MASK_SHOT_HULL
		})

		local hitEnt = tr.Entity
		
		ply:LagCompensation(false)

		if IsValid(hitEnt) and hitEnt:IsPlayer() and hitEnt:IsSurvivor() then
			self:SetCharging(false)
			self:SetNextMeleeAttack(0)
			self:DealDamage()
			return
		end
	end

	local meleetime = self:GetNextMeleeAttack()
	if ( meleetime > 0 and curtime > meleetime ) then
        self:SetCharging(false)
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

if CLIENT then
    local crouchFactor = 0

    function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
        local ply = self.Owner
        if not IsValid(ply) then return EyePos, EyeAng end
		
        local target = (self:GetSequenceName(self:GetSequence()):match("crouch") == "crouch") and 1 or 0
        crouchFactor = Lerp(FrameTime() * 5, crouchFactor, target)

        local newPitch = Lerp(crouchFactor, EyeAng.p, 0)
        EyeAng.p = newPitch

        return EyePos, EyeAng
    end
end