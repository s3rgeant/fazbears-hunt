SWEP.PrintName = "Bear SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_bear", "Bear5", 100)
end

SWEP.ViewModel = "models/speps/vm/oldfreddy.mdl"

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-8)

SWEP.HitDelay = 0.8	-- через сколько удар будет произвёден насильно после замаха, если ты долго держишь лкм
SWEP.ChargeStartTime = 0 -- время начала удержания ЛКМ

SWEP.HitSize = {
	Min = Vector( -18, -18, -24 ),
	Max = Vector( 18, 18, 16 )
}

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextMeleeAttack")
    self:NetworkVar("Bool", false, "IsCharging")
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("run", nil, "bearrun")
	self:AddAnimation("melee")
	self:AddAnimation("premelee")
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	if not IsValid(ent) then return end
	
	if self:GetIsCharging() or ply.tasered then return end
	if ply:IsFrozen() then return end

	if SERVER then
		if !ply:Crouching() then
			ent:PillGesture('swing', 2, 1, 0.1, 0.3)
		end
		ply:EmitSound("fnaf3/pre-hit.mp3")
	end

	self:HandleAnimation("premelee", 2)

	self:SetIsCharging(true)
	self.ChargeStartTime = CurTime()
	self:SetNextMeleeAttack(CurTime() + self.HitDelay)
end

function SWEP:DealDamage()
    local ply = self:GetOwner()
    local ent = pills.getMappedEnt(ply)
    if not IsValid(ent) then return end
	
	local now = CurTime()

	self:HandleAnimation("melee", 0.8)
	self:SetNextPrimaryFire(now + 1.5)
	self:SetLastAttack(now)

    if SERVER then
        timer.Simple(0.05, function()
            if IsValid(ent) then
                ent:PillStopGesture('swing')
            end
        end)
		
		if !ply:Crouching() then
			ent:PillGesture('attack', 2, 1, 0.1, 0.7, 0.02)
		end

        net.Start("fh_cooldown_receive")
        net.WriteString("attack")
        net.WriteFloat(1.5)
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
    dmginfo:SetDamage(90)

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
	
	if target:IsPlayer() then
		target:AnimRestartGesture(4, ACT_FLINCH_STOMACH, true)
		
		net.Start("AnimRestartGesture")
			net.WriteEntity(target)
			net.WriteInt(4, 4)
			net.WriteInt(ACT_FLINCH_STOMACH, 12)
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
			
	timer.Simple(0, function()
		if IsValid(target) and target:IsPlayer() and (!target:Alive() or target:IsAnimatronic()) then
			bearScream(ply,ent)
		end
	end)
end

function SWEP:Think()
	local curtime = CurTime()
	
	if self:GetIsCharging() and not self.Owner:KeyDown(IN_ATTACK) then
        self:SetIsCharging(false)
        self:SetNextMeleeAttack(0)
        self:DealDamage()
        return
    end

	local meleetime = self:GetNextMeleeAttack()
	if ( meleetime > 0 and curtime > meleetime ) then
        self:SetIsCharging(false)
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end