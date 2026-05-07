SWEP.PrintName = "Plushtrap SWEP"

SWEP.Base = "v_base"


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
SWEP.m_WeaponDeploySpeed = 0.6
SWEP.SwayScale = 0.5

SWEP.HitSize = {
	Min = Vector( -18, -18, -12 ),
	Max = Vector( 18, 18, 12 )
}

SWEP._ArmCounter = 0
SWEP.NextArmHit = util.SharedRandom( "PT_Arm", 1, 2, 0 )

function SWEP:SetupAnimations()
	self:AddAnimation("attack1")
	self:AddAnimation("attack2")
end

function SWEP:PrimaryAttack()
    local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then return end
	
	if ply:IsFrozen() then return end
	
	local name = (math.Round( self.NextArmHit ) == 1) and "attack1" or "attack2"
	
	if IsFirstTimePredicted() then
		self:HandleAnimation(name, 0.5)
		
		self._ArmCounter = self._ArmCounter + 1
		self.NextArmHit = util.SharedRandom( "PT_Arm", 1, 2, self._ArmCounter )
	end
	
	self:DealDamage()
end

function SWEP:DealDamage()
    local ply = self:GetOwner()
	local ent = pills.getMappedEnt(ply)
	if !IsValid(ent) then return end
	local now = CurTime()
	
	self:SetNextPrimaryFire(now + 1)
	self:SetLastAttack(now)
	
	if SERVER then
		ent:PillGesture('bite'.. (math.random(2) == 1 and "1" or "2"), 2, 1, 0.1, 0.3)
		
		cooldown.Set(ply, "attack", 1)
		cooldown.Send(ply, "attack")
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
		if SERVER then
			ply:EmitSound("fnaf3/plushtrap/plu_attack_miss.mp3")
		end
		return 
	end
	
	if target:IsPlayer() and target:IsSurvivor() then
        local edata = EffectData()
        edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
        util.Effect("BloodImpact", edata, true, true)
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
	dmginfo:SetDamage( class == "prop_physics" and 22 or 12 )
	
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

    if target:IsPlayer() and !target:IsAnimatronic() or target:IsNPC() then
        ply:EmitSound("fnaf3/plushtrap/plu_attack_hit.mp3")
    end
end

function SWEP:AlwaysRunning( )
	return true
end

if CLIENT then
	local red = Color(255,0,0)
	local function getPlushtrapAffected(ply, rule)
		local target = ply:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() then ply = target end
		local wep = ply:GetActiveWeapon()
		local out = {}
		
		if IsValid(wep) and wep:GetClass() == "v_plushtrap" then
			for _, ent in pairs(team.GetPlayers( TEAM_SURVIVOR )) do
				if !ent:Alive() or ent:GetNoDraw() or ent:IsInvisible() then continue end
				if ent ~= ply and ent:GetPos():Distance(ply:GetPos()) <= plushtrap_visionrange:GetInt() then
					local entry = OUTLINE.NormalizeEntry(rule, {
						ent = ent,
						outline_color = red,
						fill_color = red
					})

					if entry then
						out[#out + 1] = entry
					end
				end
			end
		end
		return (#out > 0) and out or nil
	end

	OUTLINE.RegisterRule("plushtrap_higlight", {
		priority = 100,
		render_max_dist = 9000,

		outline_color = red,
		outline_width = 3,
		outline_min_dist = 1000,
		outline_max_dist = 2200,

		fill_color = red,
		fill_min_dist = 1000,
		fill_max_dist = 2000,

		collect = getPlushtrapAffected
	})
			
	hook.Add("HUDPaint", "fh_pt_draw_affected", function()
		local ply = LocalPlayer()
		local target = ply:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() then ply = target end
		local wep = ply:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "v_plushtrap" then
			local nearPlayers = {}
			
			for _, ent in pairs(team.GetPlayers( TEAM_SURVIVOR )) do
				if !ent:Alive() or ent:GetNoDraw() or ent:IsInvisible() then continue end
				if ent ~= ply and ent:GetPos():Distance(ply:GetPos()) <= plushtrap_visionrange:GetInt() then
					nearPlayers[ent] = true
				end
			end
	
			cam.Start3D()
				for v, _ in pairs(nearPlayers) do
					if v ~= LocalPlayer() and v:IsValid() and v:Health() > 0 then
						local pos = v:GetPos()
						if pos:ToScreen().visible then
							v:DrawModel()
						end
					end
				end
			cam.End3D()
			if IsValid(wep) and wep:GetClass() == "v_plushtrap" then
				draw_orbs(nearPlayers)
			end
		end
	end)
end