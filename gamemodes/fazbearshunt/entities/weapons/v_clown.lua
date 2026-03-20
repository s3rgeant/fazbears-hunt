SWEP.PrintName = "Clown SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_clown', 110, true, false, 'Fov of Clown')
	SWEP.ViewModelFOV = vfov:GetFloat() or 110
    
    cvars.AddChangeCallback("cl_fov_clown", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 110
		end
    end)

end

SWEP.ViewModel = "models/tetTris/vm/springtrap_clown.mdl"
SWEP.m_WeaponDeploySpeed = 0.6

SWEP.HitDelay = 0.8	-- через сколько после замаха надо удар сделать

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("hit")
end

function SWEP:PrimaryAttack()
	local ply = self.Owner
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) or ply.tasered then return end
	
	if ply:IsFrozen() then return end
	
	local now = CurTime()
	
	self:SetNextPrimaryFire(now + 2)
	self:SetLastAttack(now)
	
	if SERVER then
		if !ply:Crouching() then
			ent:PillGesture('hit', 2, 1, 0.1, 0.3)
		end
	
		net.Start("fh_cooldown_receive")
		net.WriteString("attack")
		net.WriteFloat(2)
		net.Send(ply)
		ply:EmitSound("hammer_ready.wav")
	end
	
	self:HandleAnimation("hit", 1.6)
	
	self:SetNextMeleeAttack( CurTime() + self.HitDelay )
end

local clown_boost = CreateConVar( "fh_clown_hit_boost", 4, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." )

function SWEP:DealDamage()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if SERVER then
		ply:LagCompensation(true)
	end
	
	local trace = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + (ply:GetForward() * 100),
		filter = ply,ent
	})
	
	debugoverlay.Line(ply:EyePos(), trace.HitPos, 2, Color(255, 0, 0), true)
	
	local hitpos = trace.HitPos
	
	local targets = fh_get_nearest_players(hitpos, 100, ply) or (trace.Entity:IsPlayer() and trace.Entity:Team() ~= 2701) and {trace.Entity}
	
	local props = fh_get_nearest_props(hitpos, 100)
	
	--util.BlastDamage( self, ply, hitpos, 100, 40 )
	
	if SERVER and props then
		local dmgInfo = DamageInfo()
		dmgInfo:SetDamage(150)
		dmgInfo:SetAttacker(IsValid(ply) and ply or game.GetWorld())
		dmgInfo:SetInflictor(self)
		
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
		effectdata:SetStart(trace.HitPos)
		effectdata:SetScale(120)
		util.Effect("ThumperDust", effectdata, true, true)
		
		if targets then
			ply:EmitSound("hammer_hit_success.wav")
		else
			ply:EmitSound("hammer_hit.wav")
		end
	
		ply:SetVelocity(ply:GetForward() * -100 * clown_boost:GetFloat())
	end
		
	if CLIENT then return end
	
	if SERVER then
		ply:LagCompensation(false)
	end
	
	if !targets then return end
	
	for _, target in ipairs(targets) do
		local best_damage = 36
		local min_damage = math.random(30,32)
		
		local distance = target:GetPos():Distance(hitpos)

		local dmginfo = DamageInfo()
		dmginfo:SetAttacker(ply)
		dmginfo:SetInflictor(self)
		dmginfo:SetDamage(distance < 90 and best_damage or min_damage)

		SuppressHostEvents(NULL)
		target:TakeDamageInfo(dmginfo)
		SuppressHostEvents(ply)
	
		target:SetVelocity(target:GetUp() * 249) -- чтоб он нахуй улетел
	end
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