SWEP.PrintName = "Clown SWEP"

if CLIENT then
	local vfov = CreateClientConVar('fh_clown_fov', 105, true, false, 'Fov of Clown')
	SWEP.ViewModelFOV = vfov:GetFloat() or 105
    
    cvars.AddChangeCallback("fh_clown_fov", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 105
		end
    end)

end

SWEP.ViewModel = "models/tetTris/vm/springtrap_clown.mdl"
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

SWEP.HitDelay = 0.8	-- через сколько после замаха надо удар сделать

local LAND_ANIM_DELAY = 0.2

function SWEP:SetupDataTables()

	self:NetworkVar( "Float", 0, "NextMeleeAttack" )

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
	
	if !IsValid(ent) or ply.tasered then return end
	
	if ply:IsFrozen() or timer.Exists('Cl_cantKill'..ply:EntIndex()) then return end
	
	timer.Create('Cl_cantKill'..ply:EntIndex(), 2, 1, function() end)
	
	if SERVER then
		ent:PillGesture('hit', 2, 1, 0.1, 0.3)
	
		net.Start("fh_net_killer_change")
		net.WriteString("attack")
		net.WriteFloat(2)
		net.Send(ply)
		ply:EmitSound("hammer_ready.wav")
	end
	
	self:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.1)
	
	self:SetNextMeleeAttack( CurTime() + self.HitDelay )
end

function SWEP:SecondaryAttack()
    return true
end

function SWEP:DealDamage()
	if CLIENT then return end
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
		
	ply:LagCompensation(true)
	
	local trace = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + (ply:GetForward() * 100),
		filter = ply,ent
	})
	
	debugoverlay.Line(ply:EyePos(), trace.HitPos, 2, Color(255, 0, 0), true)
	
	local hitpos = trace.HitPos
	
	local targets = fh_get_nearest_players(hitpos, 100, ply) or (trace.Entity:IsPlayer() and trace.Entity:Team() != 2701) and {trace.Entity}
	local props = fh_get_nearest_props(hitpos, 100)
	
	if props then
		local dmgInfo = DamageInfo()
		dmgInfo:SetDamage(150)
		dmgInfo:SetAttacker(game.GetWorld())
		dmgInfo:SetInflictor(game.GetWorld())
		dmgInfo:SetDamageType(DMG_SLASH)
		
		for k,prop in ipairs(props) do
			SuppressHostEvents( NULL )
			prop:TakeDamageInfo(dmgInfo)
			SuppressHostEvents( ply )
			local phys = prop:GetPhysicsObject()
			
			local owner = prop:GetOwner()
			if !IsValid(owner) or IsValid(owner) and !owner:IsAnimatronic() then
				if IsValid(phys) then
					local force = ply:GetAimVector() * 10000 + Vector(0,0,200) * 20
			
					phys:ApplyForceCenter(force)
				end
			end
		end
	end
	
	local trace = util.TraceLine({
		start = hitpos,
		endpos = hitpos - Vector(0, 0, 150),
		filter = ply,ent
	})
	
	if trace.Hit or targets then
	
		local effectdata = EffectData()
		effectdata:SetOrigin(trace.HitPos)
		effectdata:SetScale(160)
		util.Effect("ThumperDust", effectdata)
		
		if targets then
			ply:EmitSound("hammer_hit_success.wav")
		else
			ply:EmitSound("hammer_hit.wav")
		end
	
	end
	
	ply:LagCompensation(false)
	
	if !targets then return end
	
	for _, target in ipairs(targets) do
		if target:IsNPC() then
			target:TakeDamage(99999, ply, self)
			return 
		end
		
		target:TakeDamage(36, ply, self)
	
		target:SetVelocity(ply:GetUp() * 249) -- чтоб он нахуй улетел
	end
	
	for _, target in ipairs(targets) do
		if !target:Alive() then
			playVoiceline('clown', 'kill', ply, 2)
			break
		end
	end
end

function SWEP:Think()
	local curtime = CurTime()

	local meleetime = self:GetNextMeleeAttack()

	if ( meleetime > 0 and curtime > meleetime ) then

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
        ["ACT_MELEE_ATTACK1"] = ACT_MELEE_ATTACK1,
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