AddCSLuaFile()

SWEP.PrintName = "#weapon_adrenaline"
SWEP.Purpose = "#info_adrenaline"

if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/adrenaline" )
end

SWEP.ViewModel = "models/items/v_l4d2adren.mdl"
SWEP.WorldModel = "models/items/w_l4d2adren.mdl"
SWEP.UseHands = true
SWEP.ViewModelFOV = 56
SWEP.HoldType = "slam"

SWEP.BounceWeaponIcon	= false 
SWEP.Spawnable = true

SWEP.Gifted = true

SWEP.Slot = 2
SWEP.SlotPos = 1
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false
SWEP.Weight = 30

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Ammo = "none"
SWEP.Primary.Automatic = false
SWEP.Primary.Sound = Sound(")weapons/adren/adrenuse.wav")
SWEP.Primary.Delay = 0.2

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

local trail_clr = Color(0, 169, 255, 200)
function SWEP:PrimaryAttack()
	if self:Clip1() <= 0 then return end

	local owner = self:GetOwner()
	if not IsValid(owner) then return end

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	
	if IsFirstTimePredicted() then
		owner:SetAnimation(PLAYER_ATTACK1)
		self:EmitSound(self.Primary.Sound)
	end

	self:SetNextPrimaryFire(CurTime() + 1)
	self:SetClip1(self:Clip1() - 1)

	if SERVER then
		local heal = math.random(4,7)
		local armor = 15
		
		timer.Simple(0.59, function()
			if not IsValid(self) then return end
			
			if IsValid(owner) and IsValid(self) then
		
				for i = 1, heal do
					timer.Simple(0 + i/1.5, function()
						if IsValid(owner) and owner:Health() < 100 then
							owner:SetHealth(owner:Health() + 1)
						end
					end) 
				end
				
				for i = 1, armor do
					timer.Simple(0 + i/15, function()
						if IsValid(owner) and owner:Armor() < 100 then
							owner:SetArmor(owner:Armor() + 1)
						end
					end) 
				end
				
				owner:SetWalkSpeed(owner:GetWalkSpeed() * 1.25)
				owner:SetRunSpeed(owner:GetRunSpeed() * 1.35)
				owner:SetCrouchedWalkSpeed(owner:GetCrouchedWalkSpeed() * 1.4)
				
				local trail = owner._adrenTrail or util.SpriteTrail(owner, owner:LookupAttachment( "chest" ), trail_clr, true, 32, 0, 1, 1 / ( ( 32 + 0 ) * 0.5 ), "trails/physbeam")
				
				owner._adrenTrail = trail
			end
		end)
		
		local timerName = "adren_trail_remove" .. owner:EntIndex()
		
		if timer.Exists(timerName) then
			timer.Remove(timerName)
		end
		
		timer.Simple(8, function()
			if IsValid(owner) and not owner:GetPillCostume():IsValid() then
				owner:SetWalkSpeed(owner:GetWalkSpeed() / 1.25)
				owner:SetRunSpeed(owner:GetRunSpeed() / 1.35)
				owner:SetCrouchedWalkSpeed(owner:GetCrouchedWalkSpeed() / 1.4)
			end
		end)
		
		timer.Create(timerName, 8, 1, function()
			if IsValid(owner) then
				local trail = owner._adrenTrail
				
				if IsValid(trail) then
					trail:Remove()
					owner._adrenTrail = nil
				end
			end
		end)
	
		timer.Simple(1, function()
			if IsValid(self) then
				self:Remove()
			end
		end)
	end
end

if SERVER then
	local function trailremover(ply)
		local trail = ply._adrenTrail
		
		if IsValid(trail) then
			trail:Remove()
			ply._adrenTrail = nil
		end
	end

	hook.Add("PlayerDeath", "adren_notrail_death", trailremover)
	hook.Add("PlayerDisconnect", "adren_notrail_death", trailremover)
end

-- спиздил с дефибриллятора
function SWEP:SecondaryAttack()

	local owner = self:GetOwner()
    
	owner:LagCompensation( true )
	
	local tr = util.TraceLine( {
	start = owner:GetShootPos(),
	endpos = owner:GetShootPos() + owner:GetAimVector() * 65,
	filter = owner,
	mask = MASK_SHOT_HULL,
	} )
	
	if !IsValid( tr.Entity ) then
		tr = util.TraceHull( {
		start = owner:GetShootPos() + owner:GetAimVector() * 10,
		endpos = owner:GetShootPos() + owner:GetAimVector() * 65,
		filter = owner,
		mins = Vector( -20, -20, -12 ),
		maxs = Vector( 20, 20, 12 ),
		mask = MASK_SHOT_HULL,
		} )
	end
	
	local vm = owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "melee" ) )
	--owner:SetAnimation( PLAYER_ATTACK1 )
	
	if SERVER then
		local force = owner:GetAimVector() * 500
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker(owner)
		dmginfo:SetInflictor(self)
		dmginfo:SetDamagePosition(tr.HitPos)
		dmginfo:SetDamageType(DMG_SLASH) 
		dmginfo:SetDamage(5)
			
		if tr.Hit and (tr.Entity:IsPlayer() || tr.Entity:IsNPC() || tr.Entity:GetClass() == "prop_ragdoll") then
			owner:EmitSound( ")player/survivor/hit/rifle_swing_hit_infected" .. math.random(7, 12) .. ".wav")
			dmginfo:SetDamageForce(force)
			SuppressHostEvents( NULL )
			tr.Entity:TakeDamageInfo( dmginfo )
			SuppressHostEvents( owner )
			tr.Entity:SetVelocity(Vector(force.x,force.y,10))
		elseif tr.Hit then
			owner:EmitSound( ")player/survivor/hit/rifle_swing_hit_world.wav")
			if IsValid(tr.Entity) then
				dmginfo:SetDamageForce(force/100)
				SuppressHostEvents( NULL )
				tr.Entity:TakeDamageInfo( dmginfo )
				SuppressHostEvents( owner )
			end
		else
			owner:EmitSound( ")weapons/bat/bat_swing_miss" .. math.random(1, 2) .. ".wav")
		end
	else -- CLIENT
		owner:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, true )
	end
	
	self:SetNextSecondaryFire( CurTime() + self.Primary.Delay + 0.7 )
	
	self.Idle = 0
	self.IdleTimer = CurTime() + owner:GetViewModel():SequenceDuration()
	
	owner:LagCompensation( false )
end

function SWEP:Reload()
    return
end
