SWEP.PrintName = "Plushtrap SWEP"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_plushtrap', 100, true, false, 'Fov of Plushtrap')
	SWEP.ViewModelFOV = vfov:GetFloat() or 100
    
    cvars.AddChangeCallback("cl_fov_plushtrap", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 100
		end
    end)

end

SWEP.ViewModel = "models/tetTris/vm/Plushtrap.mdl"
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

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Ammo = "none"

SWEP.HitSize = {
	Min = Vector( -18, -18, -12 ),
	Max = Vector( 18, 18, 12 )
}

local LAND_ANIM_DELAY = 0.2

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
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() or timer.Exists('PT_cantKill'..ply:EntIndex()) then return end
	
	local name = (math.random(1,2) == 1) and "LEFT" or "RIGHT"
	
	if SERVER then
		self:PlayCustomAnimation("ACT_VM_HIT" .. name, 0.5)
	end
	
	self:DealDamage()
end

function SWEP:SecondaryAttack()
    return true
end

function SWEP:DealDamage()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	timer.Create('PT_cantKill'..ply:EntIndex(), 1.5, 1, function() end)
	
	if SERVER then
	
		ent:PillGesture('bite'.. (math.random(1,2) == 1 and "1" or "2"), 2, 1, 0.1, 0.3)
		
		net.Start("fh_net_killer_change")
		net.WriteString("attack")
		net.WriteFloat(1.5)
		net.Send(ply)
	
	end
		
	ply:LagCompensation(true)
	
	local numLines = 6
	local angleStep = 5
	
	local trace

	local tr = util.TraceLine( {
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
		filter = ply,
		mask = MASK_SHOT_HULL
	} )

	if ( !IsValid( tr.Entity ) ) then
		tr = util.TraceHull( {
			start = ply:GetShootPos(),
			endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
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
		local owner = target:GetOwner()
		if !IsValid(owner) or IsValid(owner) and !owner:IsAnimatronic() then
		
			local phys = target:GetPhysicsObject()
			if IsValid(phys) then
				local dir = ply:GetAimVector()
				phys:ApplyForceCenter(dir * 10000)
			end
		end
	end
	
	local dmginfo = DamageInfo()
	dmginfo:SetAttacker( ply )
	dmginfo:SetInflictor( self )
	dmginfo:SetDamage( class == "prop_physics" and math.random(20,22) or math.random(9,12) )
	
	SuppressHostEvents( NULL )
	target:TakeDamageInfo( dmginfo )
	SuppressHostEvents( ply )
		
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
	
	if target:IsNPC() then
		target:TakeDamage(99999, ply)
		return 
	end
	
	if (target:IsPlayer() and target:IsSurvivor()) or target:IsNPC() then
		ply:EmitSound("fnaf3/spr_punch_hit.wav")
	end
	
	if target:IsPlayer() and !target:Alive() then
		playVoiceline('plushtrap', 'kill', ply, 2)
	end
end

function SWEP:Think()
	local curtime = CurTime()
	
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

        if (onGround and ply:WaterLevel() <= 2) and walkSpeed > 5 then
            if speed >= runSpeed * 0.5 or ply:Crouching() and speed >= crouchSpeed then
                if self.CurAnim ~= 'run' then
                    self.Weapon:SendWeaponAnim(ACT_VM_SPRINT_IDLE)
                    self.CurAnim = 'run'
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

if CLIENT then
	hook.Add( "PreDrawHalos", "pt_halo", function()
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "v_plushtrap" then
			local nearPlayers = {}
			
			for _, ent in pairs(team.GetPlayers( TEAM_UNASSIGNED )) do
				if ent ~= ply and ent:GetPos():Distance(ply:GetPos()) <= 2200 then
					table.insert(nearPlayers, ent)
				end
			end
			halo.Add(nearPlayers, Color(255, 0, 0), 1, 1, 2, true, true)
			
			hook.Add("HUDPaint", "fh_pt_draw_affected", function()
				if IsValid(wep) and wep:GetClass() == "v_plushtrap" then
					draw_orbs(nearPlayers)
				end
			end)
		end
	end)
end