SWEP.PrintName = "Springtrap SWEP"

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
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.m_WeaponDeploySpeed = 0.6
SWEP.CurAnim = 'idle'
SWEP.PreviousOnGround = true
SWEP.HoldAnim = 0

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = true

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

SWEP.HitDelay = 1.4	-- через сколько удар будет произвёден насильно после замаха, если ты долго держишь лкм

SWEP.Arm = "LEFT"

SWEP.IsCharging = false -- переменная для отслеживания удержания ЛКМ
SWEP.ChargeStartTime = 0 -- время начала удержания ЛКМ

SWEP.HitSize = {
	Min = Vector( -24, -24, -16 ),
	Max = Vector( 24, 24, 16 )
}

local LAND_ANIM_DELAY = 0.2

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextMeleeAttack")
    self:NetworkVar("Int",   1, "AttackArm") -- 1 = LEFT, 2 = RIGHT
end

function SWEP:Deploy()
    self.CurAnim = "deploy"
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:PrimaryAttack()
    local ply = self.Owner
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
    if self.IsCharging or ply.tasered then return end
    if ply:IsFrozen() or timer.Exists('ST_cantKill'..ply:EntIndex()) then return end

    if SERVER then
		if !ply:Crouching() then
			ent:PillGesture('swing', 2, 1, 0.1, 0.3)
		end
        ply:EmitSound("fnaf3/pre-hit.mp3")

        -- сервер решает руку
        local arm = (math.random(1,2))
        self:SetAttackArm(arm)
    end

    -- у клиента рука берётся только из сетевой переменной
    local arm = self:GetAttackArm()
    if arm <= 0 then arm = 1 end
    local armName = (arm == 1) and "LEFT" or "RIGHT"

    if IsFirstTimePredicted() then
        self:PlayCustomAnimation("ACT_VM_HIT" .. armName, 2)
    end

    self.IsCharging = true
    self.ChargeStartTime = CurTime()
    self:SetNextMeleeAttack(CurTime() + self.HitDelay)
end

function SWEP:SecondaryAttack()
    return true
end

function SWEP:DealDamage()
    local ply = self.Owner
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end

    local arm = self:GetAttackArm()
    local armName = (arm == 1) and "LEFT" or "RIGHT"

    if IsFirstTimePredicted() then
        self:PlayCustomAnimation("ACT_VM_HIT" .. armName .. "2", 0.6)
    end

    timer.Create('ST_cantKill'..ply:EntIndex(), 1.5, 1, function() end)

    if SERVER then
        timer.Simple(0.15, function()
            if IsValid(ent) then
                ent:PillStopGesture('swing')
            end
        end)
		
		if !ply:Crouching() then
			ent:PillGesture('attack', 2, 1, 0.1, 0.7)
		end

        net.Start("fh_net_killer_change")
        net.WriteString("attack")
        net.WriteFloat(2)
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
    end

    local target = tr.Entity
    if not IsValid(target) then
        ply:LagCompensation(false)
        ply:EmitSound("fnaf3/hit-miss.mp3")
        return
    end

    if target:IsPlayer() and target:IsSurvivor() then
        local edata = EffectData()
        edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
        util.Effect("BloodImpact", edata, true, true)
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
    dmginfo:SetDamage(60)

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
        ply:EmitSound("fnaf3/hit.mp3")
    end
end

function SWEP:Think()
	local curtime = CurTime()
	
	if self.IsCharging and not self.Owner:KeyDown(IN_ATTACK) then
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
            if speed >= runSpeed * 0.9 then
                if self.CurAnim ~= 'run' then
                    self.Weapon:SendWeaponAnim(ACT_VM_SPRINT_IDLE)
                    self.CurAnim = 'run'
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
                if self.CurAnim ~= 'glide' and self.CurAnim ~= 'ACT_MELEE_ATTACK1' then
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
        ["ACT_VM_HITLEFT"] = ACT_VM_HITLEFT,
        ["ACT_VM_HITRIGHT"] = ACT_VM_HITRIGHT,
        ["ACT_VM_HITLEFT2"] = ACT_VM_HITLEFT2,
        ["ACT_VM_HITRIGHT2"] = ACT_VM_HITRIGHT2,
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