AddCSLuaFile()

SWEP.PrintName      = "GFreddy Head SWEP"

SWEP.WorldModel				= "";

SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = true

SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = false
SWEP.Primary.Ammo           = "none"

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = false
SWEP.Secondary.Ammo         = "none"

local MAX_SPEED = 1100
local WALL_MARGIN   = 8
local WALL_NORMAL_Z = 0.7

local SND_HIT       = "physics/body/body_medium_impact_hard1.wav"

function SWEP:SetupDataTables()
    self:NetworkVar("Bool",  0, "Dashing")
    self:NetworkVar("Float", 0, "DashSpeed")
    self:NetworkVar("Float", 1, "DashEnd")
end

function SWEP:Initialize()
    self:SetDashing(false)
    self:SetDashSpeed(0)
    self:SetDashEnd(0)
end

function SWEP:StopDash(ply)
    self:SetDashing(false)
    self:SetDashSpeed(0)
    self:SetDashEnd(0)
	self:StopSounds(ply)
end

function SWEP:Deploy()
	local owner = self:GetOwner()
    self:StopDash(owner)
	self:SetNextSecondaryFire(0)
    return true
end

function SWEP:StartSounds(ply)
	if CLIENT then return end
	
	local ent = ply:GetPillCostume()
	
	if not ent:IsValid() then return end
	
	ent:SetNWBool("RecklessRam", true)
	
	if ent.HeadRamSound then
		ent.HeadRamSound:Stop()
		ent.HeadRamSound = nil
	end
	if not ent.HeadRamSound then
		local rf = RecipientFilter()
		rf:AddAllPlayers()
		
		ent.HeadRamSound = CreateSound(ent, "gfreddy_head.ram", rf)
	end
	ent.HeadRamSound:PlayEx(0, 95)
	ent.HeadRamSound:ChangeVolume(1, 1)
	ent.HeadRamSound:ChangePitch(108, 10)
	ent.HeadRamSound:SetSoundLevel(0)
end

function SWEP:StopSounds(ply)
	if CLIENT then return end
	
	if not ply or not ply:IsValid() then return end
	if not ply:IsPlayer() then return end
	
	local ent = ply:GetPillCostume()
	
	if not ent:IsValid() then return end
	
	ent:SetNWBool("RecklessRam", false)
	
	if ent.HeadRamSound then
		if ent.HeadRamSound:IsPlaying() then
			ent.HeadRamSound:FadeOut( .5 )
		end
	end
end

function SWEP:Holster()
	local owner = self:GetOwner()
    self:StopDash(owner)
    return true
end

function SWEP:OnDrop(ply)
    self:StopDash(ply)
end

function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack() end
function SWEP:Reload() end

function SWEP:DashMove(ply, mv)
	if not ply:Alive() or ply:GetMoveType() ~= MOVETYPE_WALK then
		if self:GetDashing() then self:StopDash(ply) end
		return
	end
	
	local ct = CurTime()
	
	if self:GetDashing() and ct >= self:GetDashEnd() then
		self:StopDash(ply)	
		cooldown.SetSend(ply, "recklessram", 35)
		self:SetNextSecondaryFire(CurTime() + 35)
	end
	
	local dt  = FrameTime()
	local vel = mv:GetVelocity()

	local ang = mv:GetAngles()
	ang.p, ang.r = 0, 0
	local dir = ang:Forward()

	if not self:GetDashing() then
		if not mv:KeyPressed(IN_ATTACK2) or self:GetNextSecondaryFire() > ct then return end

		self:SetDashEnd(ct + 8)
		self:SetDashing(true)
		self:SetDashSpeed(vel:Dot(dir))
		ply:ViewPunch( Angle( -5, 0, 0 ) )
	
		self:StartSounds(ply)

		if IsFirstTimePredicted() then
			self:EmitSound("fnaf2/gfreddy/ram_start.mp3", 70, 100, 0.6)
		end
	end

	self:SetDashSpeed(MAX_SPEED)
	local speed = self:GetDashSpeed()

	local mins, maxs
	if ply:Crouching() then
		mins, maxs = ply:GetHullDuck()
	else
		mins, maxs = ply:GetHull()
	end

	local origin = mv:GetOrigin()
	local tr = util.TraceHull({
		start  = origin,
		endpos = origin + dir * (speed * dt + WALL_MARGIN),
		mins   = Vector(mins.x, mins.y, 18), -- step height
		maxs   = maxs,
		filter = ply,
		collisiongroup = COLLISION_GROUP_PASSABLE_DOOR
	})

	if tr.Hit and (tr.StartSolid or math.abs(tr.HitNormal.z) < WALL_NORMAL_Z) then
		if not tr.Entity:IsPlayer() and not tr.Entity:IsRagdoll() then
			local normal = Vector(tr.HitNormal.x, tr.HitNormal.y, 0)
			if tr.StartSolid or normal:LengthSqr() < 0.001 then
				normal = -dir
			else
				normal:Normalize()
			end
		
			if SERVER then
				local eye = origin + Vector(0, 0, maxs.z * 0.6)
				local st = util.TraceLine({
					start  = eye,
					endpos = eye + dir * (maxs.x + WALL_MARGIN + 24),
					filter = ply,
					mask   = MASK_PLAYERSOLID,
				})
		
				local ed = EffectData()
				if st.Hit then
					ed:SetOrigin(st.HitPos + Vector(0,0,60))
					ed:SetNormal(st.HitNormal)
					ed:SetSurfaceProp(st.SurfaceProps)
					ed:SetMaterialIndex(st.MatType)
				else
					ed:SetOrigin(tr.HitPos + dir * maxs.x)
					ed:SetNormal(normal)
					ed:SetSurfaceProp(tr.SurfaceProps)
					ed:SetMaterialIndex(tr.MatType)
				end
				ed:SetScale(math.Clamp(speed / MAX_SPEED, 0.4, 1.5))
		
				util.Effect("wallbreak", ed, true, true)
				util.ScreenShake(ed:GetOrigin(), 5, 5, 0.4, 600)
				ply:ViewPunch( (tr.HitNormal:Angle() * .2) + Angle(8, 0, 0) )
			end
			
			self:EmitSound("physics/concrete/boulder_impact_hard4.wav", 70, math.random(90,110), 1)
		
			mv:SetVelocity(normal * 450)
			self:StopDash(ply)
	
			cooldown.SetSend(ply, "recklessram", 30)
			self:SetNextSecondaryFire(CurTime() + 30)
			return
		end
	end

	mv:SetVelocity(Vector(dir.x * speed, dir.y * speed, vel.z))
end

function SWEP:DrawWorldModel()
end

function SWEP:PreDrawViewModel()
	return true
end

hook.Add("SetupMove", "weapon_dash_SetupMove", function(ply, mv, cmd)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or wep:GetClass() ~= "v_gfreddyhead" or not wep.DashMove then return end
    wep:DashMove(ply, mv)
end)

if CLIENT then
    function SWEP:TranslateFOV(fov)
        local target = (self:GetDashSpeed() / MAX_SPEED) * 18
        self.FovAdd = Lerp(math.min(FrameTime() * 8, 1), self.FovAdd or 0, target)
        return fov + self.FovAdd
    end
end