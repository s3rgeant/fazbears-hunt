SWEP.PrintName = "Foxy SWEP"

if CLIENT then
	local vfov = CreateClientConVar('fh_foxy_fov', 100, true, false, 'Fov of Foxy')
	SWEP.ViewModelFOV = vfov:GetFloat() or 100
    
    cvars.AddChangeCallback("fh_foxy_fov", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 100
		end
    end)

end

SWEP.ViewModel = "models/speps/vm/oldfoxy.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.m_WeaponDeploySpeed = 0.5
SWEP.CurAnim = 'idle'
SWEP.PreviousOnGround = true
SWEP.HoldAnim = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

SWEP.HitDelay = 1	-- через сколько удар будет произвёден насильно после замаха, если ты долго держишь лкм

SWEP.IsCharging = false -- переменная для отслеживания удержания ЛКМ
SWEP.ChargeStartTime = 0 -- время начала удержания ЛКМ

SWEP.HitSize = {
	Min = Vector( -24, -24, -16 ),
	Max = Vector( 24, 24, 16 )
}

SWEP.Sensitivity = 1

local LAND_ANIM_DELAY = 0.2

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
end

function SWEP:Deploy()
	self.CurAnim = "deploy"
    return true
end

function SWEP:AdjustMouseSensitivity()
    return 1 / self.Sensitivity
end

function SWEP:Holster()
    return true
end

function SWEP:PrimaryAttack()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	local ct = CurTime()
	
	if !ply:GetNWBool("isBlightRushing") then return end
	
	ply.blightRushStart = ct + 1.5
	
	self.Sensitivity = 3
	
	if !IsValid(ent) then return end
	
	if self.IsCharging or ply.tasered then return end
	
	if ply:IsFrozen() or timer.Exists('FOXY_cantKill'..ply:EntIndex()) then return end
	
	if SERVER then
		--ent:PillGesture('swing', 2, 1, 0.1, 0.3)
	end
	
	self:PlayCustomAnimation("ACT_SPECIAL_ATTACK1", 2)
	
	self:SetPlaybackRate(1)
	
    self.IsCharging = true
    self.ChargeStartTime = ct
	
	self:SetNextMeleeAttack( ct + self.HitDelay )
end

function SWEP:SecondaryAttack()
    return true
end

function SWEP:DealDamage()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	self:PlayCustomAnimation("ACT_SPECIAL_ATTACK2", 0.6)
	
	self:SetPlaybackRate(1)
	
	timer.Create('FOXY_cantKill'..ply:EntIndex(), 2, 1, function() end)
	
	self.Sensitivity = 1
	
	if SERVER then
	
		timer.Simple(0.15, function()
			if !IsValid(ent) then return end
			--ent:PillStopGesture('swing')
		end)
	
		ent:PillGesture('attack', 2, 1, 0.1, 0.7)
		
		net.Start("fh_net_killer_change")
		net.WriteString("kill")
		net.WriteFloat(2)
		net.Send(ply)
		
		EndRush(ply)
		
		foxyStun(ply)

		timer.Simple(5, function()
			if IsValid(ply) then
				receiveTokensBack(ply)
			end
		end)
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
		return 
	end
	
	if target:IsPlayer() and target:IsSurvivor() then
	
		local edata = EffectData()
		edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
		util.Effect("BloodImpact", edata)
		
	end
	
	if CLIENT then return end
	
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
	
	if class != "cakemine" then
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker( ply )
		dmginfo:SetInflictor( self )
		dmginfo:SetDamage( 25 )
		
		if target:IsPlayer() then
			StartBleeding(target, ply)
			timer.Simple(5, function()
				if IsValid(ply) then
					StopBleeding(ply)
				end
			end)
		end
	
		SuppressHostEvents( NULL )
		target:TakeDamageInfo( dmginfo )
		SuppressHostEvents( ply )
	end
	
	ply:LagCompensation(false)
	
	if target:IsNPC() then
		target:TakeDamage(99999, ply)
		return 
	end
	
	if (target:IsPlayer() and target:IsSurvivor()) or target:IsNPC() then
		ply:EmitSound("fnaf3/spr_punch_hit.wav")
	end
end

SWEP.run_string = "run"
SWEP.run_act = ACT_VM_SPRINT_IDLE
function SWEP:Think()
	local curtime = CurTime()
	
	if self.IsCharging and not self.Owner:KeyDown(IN_ATTACK) then
        self.IsCharging = false
        self:SetNextMeleeAttack(0)
        self:DealDamage()
        return
    end

	if self.IsCharging then
		local ply = self.Owner
		local forward = ply:GetAimVector()
		local startPos = ply:GetShootPos()
		local endPos = startPos + forward * 60

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

		if IsValid(hitEnt) and hitEnt:IsPlayer() and hitEnt:IsSurvivor() then
			self.IsCharging = false
			self:SetNextMeleeAttack(0)
			self:DealDamage()
			return
		end
	end

	local meleetime = self:GetNextMeleeAttack()
	if ( meleetime > 0 and curtime > meleetime ) then
        self.IsCharging = false
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end
	
    if SERVER then
        local ply = self.Owner
        local speed = ply:GetAbsVelocity():Length()
        local onGround = ply:OnGround()
        local runSpeed = ply:GetRunSpeed()
        local walkSpeed = ply:GetWalkSpeed()
        local crouchSpeed = ply:GetCrouchedWalkSpeed()
		
        if self.HoldAnim > 0 and CurTime() < self.HoldAnim then
			return self.BaseClass.Think and self.BaseClass.Think(self)
        end
        
        if (onGround and ply:WaterLevel() <= 1) and not self.PreviousOnGround then
            if self.CurAnim ~= 'land' then
                self.Weapon:SendWeaponAnim(ACT_LAND)
                self.CurAnim = 'land'
				self.HoldAnim = CurTime() + LAND_ANIM_DELAY
				return
            end
        elseif not onGround and self.PreviousOnGround then
            if self.CurAnim ~= 'jump' then
                self.Weapon:SendWeaponAnim(ACT_JUMP)
                self.CurAnim = 'jump'
            end
        end
        
        self.PreviousOnGround = onGround

        if (onGround and ply:WaterLevel() <= 1) and walkSpeed > 10 then
            if speed >= runSpeed * 0.9 and walkSpeed != runSpeed then
                if self.CurAnim ~= self.run_string then
                    self.Weapon:SendWeaponAnim(self.run_act)
                    self.CurAnim = self.run_string
                end
            elseif speed >= walkSpeed * 0.9 and speed > 5 or ply:Crouching() and speed >= crouchSpeed then
                if self.CurAnim ~= 'walk' then
                    self.Weapon:SendWeaponAnim(ACT_WALK)
                    self.CurAnim = 'walk'
                end
            elseif speed <= walkSpeed * 0.5 and self.CurAnim ~= 'idle' and self.CurAnim != 'land' then
                self.Weapon:SendWeaponAnim(ACT_IDLE)
                self.CurAnim = 'idle'
            end
        else
            if ply:GetVelocity().z < 0 or ply:WaterLevel() > 1 then
                if self.CurAnim ~= 'glide' then
                    self.Weapon:SendWeaponAnim(ACT_GLIDE)
                    self.CurAnim = 'glide'
                end
            end
        end
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

function SWEP:PlayCustomAnimation(anim, hold)
    if not self or not IsValid(self) then return end
    
    local animMap = {
        ["ACT_MELEE_ATTACK1"] = ACT_MELEE_ATTACK1,
        ["ACT_GMOD_TAUNT_LAUGH"] = ACT_GMOD_TAUNT_LAUGH,
        ["ACT_SPECIAL_ATTACK1"] = ACT_SPECIAL_ATTACK1,
        ["ACT_SPECIAL_ATTACK2"] = ACT_SPECIAL_ATTACK2,
    }
    
    local act = animMap[anim]
    if act then
        self:SendWeaponAnim(act)
        self.CurAnim = anim
		self.HoldAnim = CurTime() + hold
    else
        print("Хуй его знает: ", anim)
    end
end