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

SWEP.Spawnable = true
SWEP.AdminOnly = false
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
SWEP.ViewModel	= "models/realistic_police/taser/c_taser.mdl"
SWEP.ViewModelFOV = 60
SWEP.WorldModel = "models/realistic_police/taser/w_taser.mdl"

SWEP.MinHitbox = Vector(-20,-20,-12)
SWEP.MaxHitbox = Vector(20,20,12)

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

local has_tasered_vl = {"pill_wfreddy2", "pill_wbonnie2", "pill_wchica2", "pill_wfoxy2", "pill_endo02", "pill_clown", "pill_plushtrap"}

function SWEP:PrimaryAttack()

    local owner = self:GetOwner()
    if !IsValid(owner) then return end
	local vm = owner:GetViewModel()
	
	local wait = 60
	local max_anims = 10 -- на всякий случай чтобы не перегрузить сервер, в любом случае аниматроников обычно немного
	
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "fire" ) )
	
	owner:LagCompensation(true)

    local shootPos = owner:GetShootPos()
    local aimDir = owner:GetAimVector()
    local endPos = shootPos + aimDir * 600

    local tr = util.TraceLine({
		start = shootPos,
		endpos = endPos,
		filter = function(ent)
			return ent ~= owner and (ent:IsPlayer() and ent:Team() != owner:Team())
		end
	})
	
	for _, anim in ipairs( team.GetPlayers(2701) ) do
		local distance, nearest, linedist = util.DistanceToLine( shootPos, tr.HitPos, anim:GetPos() )
		
		if distance > 100 then continue end
		
		local trah = util.TraceLine({
			start = nearest,
			endpos = anim:GetPos(),
			filter = function(ent)
				return ent ~= owner and !ent:IsPlayer()
			end
		})
		
		if trah.Hit then continue end
		
		if anim:Alive() and !anim.tasered and !anim.lobbyFreeze then
		
			wait = 90
			
			TaseAnimatronic(anim)
			
			max_anims = max_anims - 1
			
			if max_anims == 0 then break end
		end
	end
	
	debugoverlay.Box(tr.HitPos, self.MinHitbox, self.MaxHitbox, 3, Color(255, 0, 0, 200))

    self:EmitSound('weapons/tasergun/shoot.mp3')
    local hitPos = tr.HitPos or endPos

    local fx = EffectData()
    fx:SetOrigin(hitPos + Vector(0, 0, 5))
	fx:SetStart(hitPos)
	util.Effect("cball_explode", fx)

	owner:LagCompensation(false)
	self.Weapon:SetClip1( 0 )
	
	if SERVER and wait == 90 then
		stats.Add(owner, "tasered", 1)
	end
	
	self:SetNextPrimaryFire(CurTime() + wait)
	timer.Create("taser" .. owner:EntIndex(), wait / 100, 100, function()
		if IsValid(self) then
			self.Weapon:SetClip1( self.Weapon:Clip1() + 1 )
		end
	end)
end

function SWEP:SecondaryAttack()
end

net.Receive("StunEffect_Shake", function()
    local ply = LocalPlayer()
    util.ScreenShake(ply:GetPos(), 15, 5, 5, 500)
end)

function TaseAnimatronic(ent)
	if hook.Run("FH_HandleTaserHit", ent) == false then return end

	local puppet = pills.getMappedEnt(ent)
	
	if !IsValid(puppet) then return end
	
	local formtbl = puppet.formTable
	local movespeed = formtbl.moveSpeed
	
	if !formtbl or !movespeed then return end
	
	if SERVER then
		ent.tasered = true
		ent:DropToFloor()
		
		if IsValid(puppet) then
			if formtbl.name == "pill_springtrap" then
				ent:SetWalkSpeed(60)
				ent:SetRunSpeed(60)
				ent:SetSlowWalkSpeed(60)
				timer.Simple(5, function()
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
				timer.Simple(5, function()
					if IsValid(ent) then
						ent:Freeze(false) 
						ent.tasered = false
					end
				end)
				
				if ent.jumpscaring then
					local poorguy = ent.jumpscaring
					
					poorguy:Freeze(false)
					poorguy.jumpscared = nil
					
					ent.jumpscaring = nil
				end
				
				timer.Remove("FH_JumpscareKill_" .. ent:EntIndex())
			end
		end
	
		net.Start("StunEffect_Shake")
		net.Send(ent)
	
		ent:ScreenFade(SCREENFADE.IN, Color(255, 255, 255, 128), 2, 2)
		
		if IsValid(puppet) then
			if formtbl.name == "pill_springtrap" then
				puppet:PillGesture('stun', 3, 1, 0, 0.3)
			else
				puppet:PillAnim("stun", true)
				if table.HasValue(has_tasered_vl, formtbl.name) then
					playVoiceline(killers.getAll()[formtbl.name].name, 'tasered', ent, 0.05)
				end
			end
			if formtbl == "pill_endo02" then
				endoRelease(ent)
			end
			puppet:EmitSound('weapons/tasergun/active_stun.mp3')
		end
	end
	
	if !IsValid(puppet) then
		puppet = ent
	end
	
	local fx = EffectData()
	fx:SetOrigin(ent:GetPos() + Vector(0, 0, 40))
	fx:SetStart(ent:GetPos())
	fx:SetMagnitude(10)
	fx:SetEntity(puppet)
	util.Effect("teslaHitBoxes", fx)
	
	hook.Run("SuccessTaserHit", ent, formtbl.name)
end

hook.Add( "PlayerShouldTakeDamage", "fh_tasered_cant_deal_damage", function( ply, attacker )
	if attacker.tasered then
		return false
	end
end )