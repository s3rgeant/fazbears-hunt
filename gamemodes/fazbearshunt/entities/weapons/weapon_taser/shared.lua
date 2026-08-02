AddCSLuaFile()
	
game.AddAmmoType( {
	name = "TASER_AMMO",
	dmgtype = DMG_SHOCK, 
	tracer = TRACER_LINE_AND_WHIZ,
	plydmg = 0, -- This can either be a number or a ConVar name.
	npcdmg = 0, -- Ditto.
	force = 2000,
	maxcarry = 1, -- Ditto.
	minsplash = 10,
	maxsplash = 5
} )

SWEP.PrintName = "#weapon_taser"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/taser" )
end
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = true
SWEP.Slot = 1
SWEP.SlotPos = 2

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "TASER_AMMO"

SWEP.Secondary.ClipSize = 0
SWEP.Secondary.DefaultClip = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.UseHands = true
SWEP.ViewModel	= "models/fh/weapons/c_taser.mdl"
SWEP.ViewModelFOV = 70
SWEP.WorldModel = "models/realistic_police/taser/w_taser.mdl"

function SWEP:Initialize()
    self:SetHoldType("pistol")
	self.Weapon:SetClip1( 100 )
end

function SWEP:Holster()
	return true
end

if SERVER then
    util.AddNetworkString("StunEffect_Shake")
end

local mins = Vector(-10,-10,-10)
local maxs = Vector(10,10,10)
function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if !IsValid(owner) then return end
	
	if self:Clip1() < 100 then return end
	
	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	
	owner:LagCompensation(true)

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()
    local endPos = shootPos + aimDir * 600

    local tr = util.TraceLine({
		start = shootPos,
		endpos = endPos,
		filter = function(ent)
			return ent ~= owner and (ent:IsPlayer() and ent:Team() ~= owner:Team())
		end
	})
	
	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = shootPos,
			endpos = endPos,
			mins = mins,
			maxs = maxs,
			mask = MASK_SHOT_HULL,
			filter = function(ent)
				return ent ~= owner and (ent:IsPlayer() and ent:Team() ~= owner:Team())
			end
		})
	end
	
	local target = tr.Entity
	
	local wait = 25
	if SERVER then
		if target:IsPlayer() and target:IsAnimatronic() then
			if target:Alive() and not target.tasered and not target.lobbyFreeze then
				wait = 65
				TaseAnimatronic(target)
				stats.Add(owner, "tasered", 1)
			end
		end
		
		timer.Create("taser" .. owner:EntIndex(), wait / 100, 100, function()
			if IsValid(self) and self:Clip1() < 100 then
				self:SetClip1( self:Clip1() + 1 )
			end
		end)
	end

    self:EmitSound('weapons/tasergun/shoot.mp3')
    local hitPos = tr.HitPos or endPos

    local fx = EffectData()
    fx:SetOrigin(hitPos + Vector(0, 0, 5))
	fx:SetStart(hitPos)
	util.Effect("cball_explode", fx)

	owner:LagCompensation(false)
	self:SetClip1( 0 )
	
	owner:SetAnimation(PLAYER_ATTACK1)
	
	if CLIENT then
		local dlight = DynamicLight( owner:EntIndex() )
		if ( dlight ) then
			dlight.pos = tr.HitPos
			dlight.r = 255
			dlight.g = 255
			dlight.b = 255
			dlight.brightness = 2
			dlight.decay = 450
			dlight.size = 256
			dlight.dietime = CurTime() + 3
		end
	end
	
	self:SetNextPrimaryFire(CurTime() + wait)
end

function SWEP:SecondaryAttack()
end

local red = Color(255,0,0,255)
local green = Color(0,255,0,255)

function SWEP:PostDrawViewModel(vm, weapon, ply)
	local bone = vm:LookupBone("t.base")
	if not bone then return end
	
	local pos, ang = vm:GetBonePosition(bone)
	if not pos then return end

	ang:RotateAroundAxis(ang:Right(), 90)
	ang:RotateAroundAxis(ang:Up(), 90)
	ang:RotateAroundAxis(-ang:Right(), 90)
	
	local progress = math.max( 3, self:Clip1() )
	local targetColor = progress < 100 and red or green

	cam.Start3D2D(pos + ang:Up() * -0.7 + ang:Forward() * 2.46, ang, 0.02)
		surface.SetDrawColor(targetColor)
		surface.DrawRect(25, 20, 15, -progress /2.38)
	cam.End3D2D()
end

net.Receive("StunEffect_Shake", function()
    local ply = LocalPlayer()
    util.ScreenShake(ply:GetPos(), 15, 5, 5, 500)
end)

function TaseAnimatronic(ent)
	local puppet = pills.getMappedEnt(ent)
	
	if !IsValid(puppet) then return end
	
	if hook.Run("FH_HandleTaserHit", ent, puppet) == false then return end
	
	local formtbl = puppet.formTable
	local movespeed = formtbl.moveSpeed
	
	if !formtbl or !movespeed then return end
	
	if SERVER then
		ent.tasered = true
		ent:DropToFloor()
		
		if IsValid(puppet) then
			local stunTimer = "TaserStun" .. ent:EntIndex()
			if formtbl.name == "pill_springtrap" then
				puppet:PillGesture('stun', 3, 1, 0, 0.3)
				
				ent:SetWalkSpeed(60)
				ent:SetRunSpeed(60)
				ent:SetSlowWalkSpeed(60)
				timer.Create(stunTimer, 5, 1, function()
					if IsValid(ent) then
						if IsValid(puppet) then
							ent:SetRunSpeed(movespeed.run)
							ent:SetWalkSpeed(movespeed.walk)
							ent:SetSlowWalkSpeed(movespeed.walk)
						end
						ent.tasered = false
					end
				end)
			else
				ent:Freeze(true)
				timer.Create(stunTimer, 5, 1, function()
					if IsValid(ent) then
						ent:Freeze(false) 
						ent.tasered = false
					end
				end)
				playVoiceline(killers.GetName(formtbl.name), 'tasered', ent, 0.05)
				
				if ent.jumpscaring then
					local poorguy = ent.jumpscaring
					
					poorguy:Freeze(false)
					poorguy:SetJumpscared(false)
					
					ent.jumpscaring = nil
				end
				
				if formtbl == "pill_endo02" then
					endoRelease(ent)
				end
				
				puppet:PillAnim("stun", true)
				puppet:SetUseForceAngles(false)
				timer.Remove("FH_JumpscareKill_" .. ent:EntIndex())
			end
			puppet:EmitSound('weapons/tasergun/active_stun.mp3')
		end
	
		net.Start("StunEffect_Shake")
		net.Send(ent)
	
		ent:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 128), 2, 2)
	end
	
	if !IsValid(puppet) then
		puppet = ent
	end
	
	local fx = EffectData()
	fx:SetOrigin(ent:GetPos() + Vector(0, 0, 40))
	fx:SetStart(ent:GetPos())
	fx:SetMagnitude(10)
	fx:SetEntity(puppet)
	util.Effect("teslaHitBoxes", fx, true, true)
	
	hook.Run("SuccessTaserHit", ent, puppet)
end

hook.Add( "PlayerShouldTakeDamage", "fh_tasered_cant_deal_damage", function( ply, attacker )
	if attacker.tasered then
		return false
	end
end )

hook.Add( "DoPlayerDeath", "fh_taser_drop", function( ply, attacker )
	if ply:HasWeapon("weapon_taser") then
		ply:DropWeapon(ply:GetWeapon("weapon_taser"))
		ply:SetActiveWeapon(nil)
	end
end )