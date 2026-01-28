local math_min = math.min
local timer_Create = timer.Create
local timer_Remove = timer.Remove

SWEP.Base = "weapon_base"

SWEP.PrintName = "#weapon_killer_axe"

SWEP.DrawWeaponInfoBox	= false
SWEP.BounceWeaponIcon	= false 

SWEP.Slot = 0
SWEP.SlotPos = -5

SWEP.ViewModel = Model("models/fh/items/v_killer_axe.mdl")
SWEP.WorldModel = Model("models/weapons/w_killer_axe.mdl")
SWEP.ViewModelFOV = 80
SWEP.UseHands = true
SWEP.DrawCrosshair = true
SWEP.DrawAmmo = false

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Skin = 4

SWEP.HitDelay = 0.35

SWEP.HitSize = {
	Min = Vector( -24, -24, -16 ),
	Max = Vector( 24, 24, 16 )
}

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Float", 0, "NextMeleeAttack" )
end

function SWEP:Holster()
	return false
end

function SWEP:Reload()
    return
end

function SWEP:SecondaryAttack()
    return
end

function SWEP:Deploy()
    self:SetNextIdle(1)
    return
end

function SWEP:Initialize()
	self:SetHoldType("melee2")
	self:SetSkin(self.Skin)
	self:SetSubMaterial(1, self.SubMaterial)
end

function SWEP:PrimaryAttack()

	self:SetNextPrimaryFire(CurTime() + 1)
    self:SetNextIdle(CurTime() + 1)

	self:SendWeaponAnim(ACT_MELEE_ATTACK1)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	
	self.Owner:ViewPunch(Angle(-2,4,0))
	
	self:SetNextMeleeAttack( CurTime() + self.HitDelay )
end

local PushSound_pills = {
	"physics/metal/metal_sheet_impact_hard7.wav",
	"physics/metal/metal_sheet_impact_hard8.wav",
}

function SWEP:DealDamage()
	local ply = self.Owner

	if !IsValid( ply:GetNWEntity("MyEndoGrabber") ) then
		ply:LagCompensation(true)
	end
		
	self.Owner:ViewPunch(Angle(1,-3,0))

	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * 85,
		filter = ply,
		mask = MASK_SHOT_HULL
	})

	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = ply:GetShootPos(),
			endpos = ply:GetShootPos() + ply:GetAimVector() * 85,
			filter = ply,
			mins = self.HitSize.Min,
			maxs = self.HitSize.Max,
			mask = MASK_SHOT_HULL
		})
	end

	local target = tr.Entity
	if not IsValid(target) then
		ply:LagCompensation(false)
		return
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
		
	local targetIsAnimatronic = (target:IsPlayer() and target:IsAnimatronic())
	local targetIsSurv = (target:IsPlayer() and target:IsSurvivor())
	local ent = pills.getMappedEnt(target)
	local animsCount = team.NumPlayers( TEAM_PILLS )
		
	if targetIsAnimatronic and IsValid(ent) and ent.cloaked then 
		ply:LagCompensation(false)
		return 
	end
		
	-- мы увеличиваем урон по аниматроникам если их больше одного
	local damage = targetIsAnimatronic and math.random(550, 600) + math.max(1, animsCount-1)*15 or math.random(20,30)
		
	if targetIsAnimatronic then
		target:EmitSound(PushSound_pills[math.random(#PushSound_pills)])
		
		local fx = EffectData()
		fx:SetOrigin(tr.HitPos)
		fx:SetStart(tr.HitPos)
		util.Effect("cball_explode", fx, true, true)
		
		if ent.formTable.name == "pill_endo02" then
			if target._endoHoldingPlayer == ply then
				endoRelease(target, true)
	
				cooldown.Set(target, 'grab', 6)
				cooldown.Send(ply, "grab")
			end
		end
	end
	
	if targetIsSurv then
		ply:EmitSound("weapons/axe/melee_axe_0" .. math.random(1,3) .. ".wav", 45, 100, 0.7, CHAN_AUTO )
		
		local edata = EffectData()
		edata:SetOrigin(tr.HitPos)
		edata:SetEntity(target)
		util.Effect("BloodImpact", edata, true, true)
	else
		ply:EmitSound("weapons/axe/axe_impact_world" .. math.random(1,2) .. ".wav", 45, 100, 0.4, CHAN_AUTO )
	end

	local dmginfo = DamageInfo()
	dmginfo:SetAttacker(ply)
	dmginfo:SetInflictor(self)
	dmginfo:SetDamage(damage)

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

	if target:IsNPC() then
		target:TakeDamage(99999, ply)
		return
	end
end

function SWEP:Think()
	local curtime = CurTime()

	local meleetime = self:GetNextMeleeAttack()

	if ( meleetime > 0 and curtime > meleetime ) then
		self:DealDamage()
		self:SetNextMeleeAttack( 0 )
	end
	
    if self:GetNextIdle() > 0 and curtime >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end

    return self.BaseClass.Think and self.BaseClass.Think(self)
end

local BOB_INTENSITY = 0.7
local BOB_SPEED = 6
local BOB_SMOOTH = 8
local MAX_WALK_SPEED = 220
local BLEND_SPEED = 3
local RUN_YAW_FACTOR = 4

function SWEP:CalcView(ply, pos, ang, fov)
	if not IsValid(ply) then return pos, ang, fov end
	if ply:GetActiveWeapon() ~= self then return pos, ang, fov end

	local vel = ply:GetVelocity()
	local vel2d = Vector(vel.x, vel.y, 0)
	local speed = vel2d:Length()

	local targetBlend = math.Clamp(speed / MAX_WALK_SPEED, 0, 1)
	self.BobBlend = self.BobBlend or 0
	self.BobBlend = Lerp(FrameTime() * BLEND_SPEED, self.BobBlend, targetBlend)

	self.BobTime = (self.BobTime or 0) + FrameTime() * ((speed > 5) and (speed / MAX_WALK_SPEED * BOB_SPEED) or 0.35)

	local sinUp = math.sin(self.BobTime)
	local sinSide = math.sin(self.BobTime * 0.5)

	local pitchOffset = sinUp * 1.1 * BOB_INTENSITY * self.BobBlend
	local yawOffset = sinSide * 0.6 * BOB_INTENSITY * self.BobBlend
	local rollOffset = -sinSide * 0.7 * BOB_INTENSITY * self.BobBlend

	local eyeAng = ply:EyeAngles()
	local right = eyeAng:Right()
	right.z = 0
	right:Normalize()

	local sideDot = 0
	if speed > 1 then
		sideDot = vel2d:Dot(right) / math.max(speed, 1)
	end

	local runYawAdd = sideDot * RUN_YAW_FACTOR * self.BobBlend

	local targetBob = Angle(pitchOffset, yawOffset, rollOffset + runYawAdd)

	self.LastBob = self.LastBob or Angle(0, 0, 0)
	local bobAng = LerpAngle(FrameTime() * BOB_SMOOTH, self.LastBob, targetBob)
	self.LastBob = bobAng

	local newAng = ang + bobAng

	return pos, newAng, fov
end

local vignette = Material("vgui/madvignette.png")
SWEP.Alpha = 0
function SWEP:DrawHUD()
	if vignette:IsError() then return end
	
	self.Alpha = Lerp(FrameTime(), self.Alpha, 255)
	
    surface.SetDrawColor(255, 255, 255, self.Alpha)
    surface.SetMaterial(vignette)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

hook.Add("fh_should_animatronic_respawn", "fh_no_escape_from_axe", function(ply, dmginfo)
	local attacker = dmginfo:GetAttacker()
	
	if IsValid(attacker) and attacker:IsPlayer() and IsValid(attacker:GetActiveWeapon()) and attacker:GetActiveWeapon():GetClass() == "weapon_killer_axe" then
		return false
	end
end)

if CLIENT then
	hook.Add( "PreDrawHalos", "kilaxe_halo", function()
		local owner = LocalPlayer()
		local target = owner:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() then owner = target end
		local wep = owner:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "weapon_killer_axe" then
			local nearPlayers = {}
			
			for _, ply in player.Iterator() do
				if !ply:Alive() or ply:GetNoDraw() then continue end
				if ply ~= owner and ply:GetPos():Distance(owner:GetPos()) <= 2600 then
					local ent = pills.getMappedEnt(ply)

					if IsValid(ent) and ent.formTable.name == "pill_wgfreddy2" and !owner:GetNW2Bool("_OUTWORLD_target") then continue end
					
					if !IsValid(ent) then ent = ply end
					nearPlayers[ent] = ent
				end
			end
			halo.Add(nearPlayers, Color(255, 0, 0), 1, 1, 2, true, true)
		end
	end)
	
	local red = Color(255,0,0,255)
			
	hook.Add("HUDPaint", "fh_kilaxe_draw_affected", function()
		local owner = LocalPlayer()
		local target = owner:GetObserverTarget()
		if IsValid(target) and target:IsPlayer() then owner = target end
		local wep = owner:GetActiveWeapon()

		if IsValid(wep) and wep:GetClass() == "weapon_killer_axe" then
			local nearPlayers = {}
			
			for _, ply in player.Iterator() do
				if !ply:Alive() or ply:GetNoDraw() then continue end
				if ply ~= owner and ply:GetPos():Distance(owner:GetPos()) <= 2600 then
					local ent = pills.getMappedEnt(ply)

					if IsValid(ent) and ent.formTable.name == "pill_wgfreddy2" and !owner:GetNW2Bool("_OUTWORLD_target") then continue end
					
					if !IsValid(ent) then ent = ply end
					nearPlayers[ent] = red
				end
			end
			draw_orbs(nearPlayers)
		end
	end)
	
	hook.Add( "RenderScreenspaceEffects", "MotionBlurEffect", function()
		local owner = LocalPlayer()
		local wep = owner:GetActiveWeapon()
		
		if IsValid(wep) and wep:GetClass() == "weapon_killer_axe" then

			DrawMotionBlur( 0.05, 0.35, 0.0 )

		end
	end)
end

hook.Add( "CustomPlayerTakeDamageConditions", "fh_axe_shouldtakedamage", function( ply, attacker )
	if IsValid(attacker) and attacker:IsPlayer() and IsValid(attacker:GetActiveWeapon()) and attacker:GetActiveWeapon():GetClass() == "weapon_killer_axe" then
		return true
	end
	if  IsValid(attacker) and attacker:IsPlayer() and attacker:IsAnimatronic() and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_killer_axe" then
		return true
	end
end)

hook.Add( "FH_PlayerShouldJumpscare", "fh_axe_owner_no_jumpscare", function( ply, ent, target )
	if ply:IsAnimatronic() and IsValid(target) and target:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

hook.Add( "fh_animatronic_post_break_prop", "fh_anims_fight_axe_owner", function( ply, ent, tr )
	local target = tr.Entity
	
	if target:IsPlayer() and target:GetNW2Bool("KillerObsessed") then
		local wep = ply:GetActiveWeapon()

		ply:EmitSound("bonnie_punch.mp3")
		
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker( ply )
		dmginfo:SetInflictor( IsValid(wep) and wep or ply )
		dmginfo:SetDamage( math.random(4,6) )

		SuppressHostEvents( NULL )
		target:TakeDamageInfo( dmginfo )
		SuppressHostEvents( ply )
		if IsValid(wep) then
			wep:HandleAnimation("attack", 0.8)
		end
		
		ent:PillGesture('melee', 2, 1, 0.1, 0.7)
		
        local edata = EffectData()
        edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
        util.Effect("BloodImpact", edata, true, true)
		
		ply._breakPropAsAnimTime = CurTime() + 0.8
	end
end)

hook.Add( "SetupPlayerVisibility", "fh_axe_visibility", function( ply, viewent )
	for _, sex in player.Iterator() do
		if sex ~= ply and (sex:GetNW2Bool("KillerObsessed") or ply:GetNW2Bool("KillerObsessed"))then
			AddOriginToPVS(sex:GetPos())
		end
	end
end)

hook.Add( "PlayerSpawn", "fh_axe_anim_spawn", function( ply )
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(0)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
	
	if ply:HasWeapon("weapon_killer_axe") then
		ply:StripWeapon("weapon_killer_axe")
	end
end)

hook.Add("PillApply", "fh_axe_joinpill", function(ply, name)
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(0)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
end)

hook.Add("FH_HandleGiftPickup", "fh_axe_giftpickup", function(gift, ply)
	if ply:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

hook.Add("FH_ShouldPlayerReceiveGifts", "fh_axe_giftpickup", function(ply)
	if ply:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

hook.Add( "PlayerDeath", "fh_axe_anim_death", function( ply, inflictor, attacker )
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(0)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
	
	if IsValid(attacker) and attacker:IsPlayer() and IsValid(inflictor) and inflictor:GetClass() == "weapon_killer_axe" then
		if ply:IsAnimatronic() then
			local effectdata = EffectData()
			effectdata:SetOrigin(ply:GetPos())
			effectdata:SetScale(1)
			util.Effect("Explosion", effectdata, true, true)
			
			for i = 1, 40 do
				timer.Simple(0 + i/25, function()
					if IsValid(attacker) and attacker:Health() < 100 then
						attacker:SetHealth(attacker:Health() + 1)
					end
				end) 
			end
		else
			for i = 1, 8 do
				timer.Simple(0 + i/8, function()
					if IsValid(attacker) and attacker:Health() < 100 then
						attacker:SetHealth(attacker:Health() + 1)
					end
				end) 
			end
		end
		hook.Run("KillerAxeKilled", attacker, ply)
	end
end)

hook.Add( "EntityTakeDamage", "EntityDamageExample", function( target, dmginfo )
	if target:IsPlayer() and target:GetNW2Bool("KillerObsessed") then
		dmginfo:SetDamage( math.min(dmginfo:GetDamage(), math.random(4,6) ) )
	end
	if target:IsPlayer() and target:IsSurvivor() and IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker():GetNW2Bool("KillerObsessed") then
		dmginfo:SetDamage( math.min(dmginfo:GetDamage(), 30) )
	end
end )