SWEP.PrintName = "Clown SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_clown", "Clown", 110)
end

SWEP.ViewModel = "models/tetTris/vm/springtrap_clown.mdl"
SWEP.m_WeaponDeploySpeed = 0.6

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(10,4,-10)

SWEP.HitDelay = 0.8	-- через сколько после замаха надо удар сделать

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
    return self.BaseClass.SetupDataTables and self.BaseClass.SetupDataTables(self)
end

function SWEP:SetupAnimations()
	self:AddAnimation("hit")
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()
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
	
	self:HandleAnimation("hit", 1.6, -1)
	
	self:SetNextMeleeAttack( CurTime() + self.HitDelay )
end

local clown_boost = CreateConVar( "fh_clown_hit_boost", 4, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Time for halo to dissolve." )

local clownVP = Angle(4,0,0)
function SWEP:DealDamage()
	local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if SERVER then
		ply:LagCompensation(true)
	end
	
	local tr = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + (ply:GetForward() * 100),
		filter = ply,ent
	})
	
	debugoverlay.Line(ply:EyePos(), tr.HitPos, 2, Color(255, 0, 0), true)
	
	local hitpos = tr.HitPos
	
	local targets = fh_get_nearest_players(hitpos, 100, ply) or (tr.Entity:IsPlayer() and tr.Entity:Team() ~= 2701) and {tr.Entity}
	
	local props = fh_get_nearest_props(hitpos, 100)
	
	ply:ViewPunch( clownVP )
	
	if SERVER and props then
		local dmginfo = DamageInfo()
		dmginfo:SetDamage(150)
		dmginfo:SetAttacker(IsValid(ply) and ply or game.GetWorld())
		dmginfo:SetInflictor(self)
		dmginfo:SetDamagePosition(hitpos)
		
		for _, prop in ipairs(props) do
			SuppressHostEvents( NULL )
			prop:TakeDamageInfo(dmginfo)
			SuppressHostEvents( ply )
			local phys = prop:GetPhysicsObject()
			
			local owner = prop:GetOwner()
			if !IsValid(owner) or IsValid(owner) and !owner:IsAnimatronic() then
				if IsValid(phys) then
					local force = ply:GetAimVector() * 10000 + Vector(0,0,200) * 20
			
					phys:ApplyForceCenter(force)
				end
			end
			
			local class = prop:GetClass()
			if class == "func_breakable_surf" then
				local localHit = prop:WorldToLocal(tr.HitPos)
				
				local mins = prop:OBBMins()
				local maxs = prop:OBBMaxs()
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
				
				local shatterStr = string.format("[%.2f %.2f %d]", x, y, 48)
				
				prop:Fire("Shatter", shatterStr, 0, ply)
			elseif class == "func_breakable" then
				prop:Fire("Break", "", 0, ply)
			end
		end
	end
	
	local tr = util.TraceLine({
		start = hitpos,
		endpos = hitpos - Vector(0, 0, 150),
		filter = ply,ent
	})
	
	if SERVER and (tr.Hit or targets) then
	
		local effectdata = EffectData()
		effectdata:SetOrigin(tr.HitPos)
		effectdata:SetStart(tr.HitPos)
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
		dmginfo:SetDamagePosition(hitpos)
		dmginfo:SetDamage(distance < 90 and best_damage or min_damage)

		SuppressHostEvents(NULL)
		target:TakeDamageInfo(dmginfo)
		SuppressHostEvents(ply)
	
		target:SetVelocity(target:GetUp() * 249) -- чтоб он нахуй улетел
	end
	
	timer.Simple(0, function()
		for _, target in ipairs(targets) do
			if not IsValid(target) then continue end
			
			if not target:Alive() then
				playVoiceline("clown", "kill", ply, .5)
				break
			end
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