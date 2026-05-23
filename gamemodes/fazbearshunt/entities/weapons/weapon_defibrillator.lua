AddCSLuaFile()

if SERVER then
	util.AddNetworkString( "DefibrilatorMelee_NW" )
    util.AddNetworkString("DefibrilatorEffect")
else -- CLIENT
	SWEP.DrawWeaponInfoBox	= false
	SWEP.BounceWeaponIcon	= false 

	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/defibrillator" )
	
	net.Receive( "DefibrilatorMelee_NW", function()
		local ply = net.ReadEntity()
		if IsValid( ply ) and ply:IsPlayer() and ply:Alive() then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, true )
		end
	end )
end

SWEP.PrintName = "#weapon_defibrillator"
SWEP.Spawnable = true

--SWEP.ViewModelFOV = 75
SWEP.ViewModel = "models/weapons/defib/v_defibrillator.mdl"
SWEP.WorldModel = "models/weapons/defib/w_eq_defibrillator.mdl"
SWEP.ViewModelFlip = false
SWEP.BobScale = 1
SWEP.SwayScale = 1
SWEP.UseHands = true

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Weight = 0
SWEP.Slot = 5
SWEP.SlotPos = 10
SWEP.HoldType = "duel"
SWEP.FiresUnderwater = true
SWEP.DrawCrosshair = true
SWEP.DrawAmmo = true
SWEP.CSMuzzleFlashes = 1
SWEP.Base = "weapon_base"
SWEP.ShowViewModel = true
SWEP.ShowWorldModel = false

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 100
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.2

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 1

function SWEP:Initialize()
	self:SetWeaponHoldType( self.HoldType )
	self:SetHoldType( self.HoldType )
	self.Incm = 75
	if !IsValid(self.Owner) then
		self.WorldModel = "models/weapons/defib/w_eq_defibrillator.mdl"
	else
		self.WorldModel = "models/weapons/defib/w_eq_defibrillator_paddles.mdl"
	end
	
	self.Idle = 0
	self.IdleTimer = CurTime() + 1
end

local BeingRevived = {}
function SWEP:Think()
	local owner = self:GetOwner()
	if owner:KeyDown(IN_ATTACK) then
		if self.Incm < 85 then
			self.Incm = self.Incm + 3
			self.ViewModelFOV = self.Incm
		end
	else
		if self.Incm > 75 then
			self.Incm = self.Incm - 3
			self.ViewModelFOV = self.Incm
		end
	end
	
	if self.Idle == 0 and self.IdleTimer <= CurTime() then
		if SERVER then
			self.Weapon:SendWeaponAnim( ACT_VM_IDLE )
		end
		self.Idle = 1
	end
    if self.Reviving then
        if !IsValid(self.ReviveTarget) or (IsValid(self.ReviveTarget) and IsValid(self.ReviveTarget:GetOwner()) and self.ReviveTarget:GetOwner():Alive()) or !owner:KeyDown(IN_ATTACK) or owner:GetPos():Distance(self.ReviveTarget:GetPos()) > 77 then
            self.Reviving = false
            self.ReviveStartTime = 0
            self.ReviveTarget = nil
            self.OldPos = nil

            if self.ReviveSound then
                self.ReviveSound:Stop()
            end

            owner:EmitSound("HL2Player.UseDeny")

            return
        end

        local elapsed = CurTime() - self.ReviveStartTime
        if elapsed >= 5 and IsValid(self.ReviveTarget) then -- оживление
            local oldpos = self.OldPos

			if SERVER then
				local spark = ents.Create("env_spark")
				spark:SetPos(oldpos)
				spark:SetKeyValue("spawnflags", "192")
				spark:SetKeyValue("traillength", "1")
				spark:SetKeyValue("magnitude", "2")
				spark:Spawn()
				spark:Fire("SparkOnce", "", 0.05)
				spark:Fire("kill", "", 0.1)
	
				local FireLight1 = ents.Create("light_dynamic")
				FireLight1:SetKeyValue("brightness", "4")
				FireLight1:SetKeyValue("distance", "160")
				FireLight1:SetPos(oldpos)
				FireLight1:Fire("Color", "60 150 255")
				FireLight1:Spawn()
				FireLight1:Activate()
				FireLight1:Fire("TurnOn", "", 0)
				FireLight1:Fire("Kill", "", 0.07)
				self:DeleteOnRemove(FireLight1)
				
                local v = self.ReviveTarget

                if self.ReviveSound then
                    self.ReviveSound:Stop()
                end

                owner:EmitSound("defibl/charged.wav", 75, 100)
                self:SetClip1(100)

                local ply = v:GetCreator()
                if IsValid(ply) then
					BeingRevived[ply] = true
                    ply:Spawn()
					ply:RemoveRagdoll()
                    ply:SetPos(oldpos)	
					ply:SetTeam(TEAM_SURVIVOR)
					
					if ply.CrouchedBeforeDeath then
						ply:Crouch()
					end
					
					if !survivors[ply] then
						survivors[ply] = true
					end
					
					stats.Add(owner, "revived", 1)

                    timer.Simple(1 / 100, function()
                        if IsValid(ply) and ply:IsStuck() then
                            ply:Unstuck(owner:GetPos())
                        end
                    end)
					
					hook.Run("fh_defibrillator_spawn", ply, owner)
                end

                v:Remove()

                timer.Simple(0.5, function()
                    if IsValid(self) and IsValid(owner) then
                        owner:StripWeapon(self:GetClass())
                    end
                end)
            end

            self.Reviving = false
            self.ReviveStartTime = 0
            self.ReviveTarget = nil
            self.OldPos = nil
        else
			local v = self.ReviveTarget
			
			if !IsValid(v) then return end
			
			local effect2 = EffectData()
			effect2:SetOrigin(v:GetPos())
			effect2:SetStart(v:GetPos())
			effect2:SetMagnitude(1)
			effect2:SetEntity(v)
			util.Effect("teslaHitBoxes",effect2)
			v:EmitSound("Weapon_StunStick.Activate")
        end
    end
end

SWEP.Reviving = false
SWEP.ReviveStartTime = 0
SWEP.ReviveTarget = nil
SWEP.ReviveSound = nil
function SWEP:PrimaryAttack()
	if self.Reviving then return end
	
	local owner = self:GetOwner()
	
	local tr = util.TraceLine({
		start = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * 60,
		filter = owner,
		mask = MASK_SHOT_HULL,
	})
	
	if not IsValid(tr.Entity) then
		tr = util.TraceHull({
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * 60,
			filter = owner,
			mins = Vector(-20, -20, 0),
			maxs = Vector(20, 20, 0),
			mask = MASK_SHOT_HULL,
		})
	end
	
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay + 0.2)
	
	if IsValid(tr.Entity) then
		for k, v in pairs(ents.FindInSphere(owner:GetShootPos(), 70)) do
			if v:GetClass() == 'prop_ragdoll' and IsValid(v:GetOwner()) and !v:GetOwner():Alive() then
				self.Reviving = true
				self.ReviveStartTime = CurTime()
				self.ReviveTarget = v
				self.OldPos = v:GetPos()
	
				if CLIENT then
					return
				end
				
				local spark = ents.Create("env_spark")
				spark:SetPos(v:GetPos())
				spark:SetKeyValue("spawnflags", "192")
				spark:SetKeyValue("traillength", "1")
				spark:SetKeyValue("magnitude", "2")
				spark:Spawn()
				spark:Fire("SparkOnce", "", 0.05)
				spark:Fire("kill", "", 0.1)
	
				if not self.ReviveSound then
					self.ReviveSound = CreateSound(owner, "defibl/defibrillator_use_start.wav")
				end
				self.ReviveSound:Play()
	
				owner:ViewPunch(Angle(-10, 0, 0))
				self:SetClip1(10)
	
				return
			end
			hook.Run("DefibrillatorUse", self, owner, v)
		end
		owner:EmitSound("HL2Player.UseDeny")
	else
		owner:EmitSound("HL2Player.UseDeny")
	end
	
	owner:SetAnimation(PLAYER_ATTACK1)
	self.Idle = 0
	self.IdleTimer = CurTime() + owner:GetViewModel():SequenceDuration()
end

function SWEP:SecondaryAttack()
	self.Owner:LagCompensation( true )
	
	local tr = util.TraceLine( {
	start = self.Owner:GetShootPos(),
	endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 65,
	filter = self.Owner,
	mask = MASK_SHOT_HULL,
	} )
	
	if !IsValid( tr.Entity ) then
		tr = util.TraceHull( {
		start = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 10,
		endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 65,
		filter = self.Owner,
		mins = Vector( -20, -20, -12 ),
		maxs = Vector( 20, 20, 12 ),
		mask = MASK_SHOT_HULL,
		} )
	end
	
	local vm = self.Owner:GetViewModel()
	vm:SendViewModelMatchingSequence( vm:LookupSequence( "melee" ) )
	--self.Owner:SetAnimation( PLAYER_ATTACK1 )
	
	if SERVER then
		local force = self.Owner:GetAimVector() * 500
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker(self.Owner)
		dmginfo:SetInflictor(self)
		dmginfo:SetDamagePosition(tr.HitPos)
		dmginfo:SetDamageType(DMG_SLASH) 
		dmginfo:SetDamage(5)
			
		if tr.Hit and (tr.Entity:IsPlayer() || tr.Entity:IsNPC() || tr.Entity:GetClass() == "prop_ragdoll") then
			self.Owner:EmitSound( "player/survivor/hit/rifle_swing_hit_infected" .. math.random(7, 12) .. ".wav")
			dmginfo:SetDamageForce(force)
			SuppressHostEvents( NULL )
			tr.Entity:TakeDamageInfo( dmginfo )
			SuppressHostEvents( self.Owner )
			tr.Entity:SetVelocity(Vector(force.x,force.y,10))
		elseif tr.Hit then
			self.Owner:EmitSound( "player/survivor/hit/rifle_swing_hit_world.wav")
			if IsValid(tr.Entity) then
				dmginfo:SetDamageForce(force/100)
				SuppressHostEvents( NULL )
				tr.Entity:TakeDamageInfo( dmginfo )
				SuppressHostEvents( self.Owner )
			end
		else
			self.Owner:EmitSound( "weapons/bat/bat_swing_miss" .. math.random(1, 2) .. ".wav")
		end
		net.Start( "DefibrilatorMelee_NW" )
		net.WriteEntity( self.Owner )
		net.Broadcast()
	else -- CLIENT
		self.Owner:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, true )
	end
	
	self:SetNextSecondaryFire( CurTime() + self.Primary.Delay + 0.7 )
	
	self.Idle = 0
	self.IdleTimer = CurTime() + self.Owner:GetViewModel():SequenceDuration()
	
	self.Owner:LagCompensation( false )
end

function SWEP:Equip()
	self.ViewModelFOV = 75
	self.WorldModel = "models/weapons/defib/w_eq_defibrillator_paddles.mdl"
	self:SetModel("models/weapons/defib/w_eq_defibrillator_paddles.mdl")
	self.Incm = 75
end

function SWEP:Deploy()
	local vm = self.Owner:GetViewModel()
	if IsValid(vm) then
		vm:SendViewModelMatchingSequence( vm:LookupSequence( "deploy" ) )
	end
	
	self.ViewModelFOV = 75
	self.WorldModel = "models/weapons/defib/w_eq_defibrillator_paddles.mdl"
	self:SetModel("models/weapons/defib/w_eq_defibrillator_paddles.mdl")
	self.Incm = 75
	self:EmitSound("defibl/deploy.wav",60)
	self:SendWeaponAnim(ACT_VM_DEPLOY)
	
	self.Idle = 0
	self.IdleTimer = CurTime() + self.Owner:GetViewModel():SequenceDuration()
	
	return true
end

function SWEP:Holster()
	self.Idle = 0
	self.IdleTimer = CurTime()
	return true
end

function SWEP:OnRemove()
	self:Holster()
end

function SWEP:OnDrop()
	self:Holster()
end

local function SetDefibAttributes(ply)
	if IsValid(ply:GetPill()) then return end
	
	ply.LastDeathTime = CurTime()
	ply.CrouchedBeforeDeath = ply:Crouching()
	
	ply.RevivePos = ply:GetPos()
	ply.ReviveAng = ply:EyeAngles()
	
	inventory_backup.SaveCurrentInventory(ply)
end

hook.Add( "PlayerSilentDeath", "Defibl_Revive", SetDefibAttributes)
hook.Add( "DoPlayerDeath", "Defibl_Revive", SetDefibAttributes)

hook.Add( "PlayerLoadout", "Defibl_Revive", function( ply )
	if not BeingRevived[ply] then return end
	
	BeingRevived[ply] = nil
	
	timer.Simple(0, function()
		if IsValid(ply) then
			inventory_backup.LoadBackup(ply)
		end
	end)
	return true
end)

if CLIENT then
	local DEFIB_COLOR = Color(255, 0, 0, 255)
	local function getCorpses(lply, rule)
		local target = lply:GetObserverTarget()
	
        local ply = (IsValid(target) and target:IsPlayer()) and target or lply
        local wep = ply:GetActiveWeapon()
		
		local out = {}

        if IsValid(wep) and wep:GetClass() == "weapon_defibrillator" then
            for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
				if !IsValid(ent:GetOwner()) or (IsValid(ent:GetOwner()) and ent:GetOwner():Alive()) then continue end
				
				local entry = OUTLINE.NormalizeEntry(rule, {
					ent = ent,
					outline_color = DEFIB_COLOR
				})
				
				if entry then
					out[#out + 1] = entry
				end
            end

        end

		return (#out > 0) and out or nil
    end

	OUTLINE.RegisterRule("defib_corpses", {
		priority = 145,
		render_max_dist = 3064,

		outline_color = DEFIB_COLOR,
		outline_width = 3,
		outline_min_dist = 700,
		outline_max_dist = 3064,

		fill_color = DEFIB_COLOR,
		fill_min_dist = 0,
		fill_max_dist = 0,

		mode = OUTLINE_MODE_BOTH,
		collect = getCorpses
	})

	hook.Add("HUDPaint", "DefibDrawNames", function()
		local lply = LocalPlayer()
		local target = lply:GetObserverTarget()
	
        local ply = (IsValid(target) and target:IsPlayer()) and target or lply
        local wep = ply:GetActiveWeapon()
	
		if IsValid(wep) and wep:GetClass() == "weapon_defibrillator" then
			for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
				if !IsValid(ent:GetOwner()) or (IsValid(ent:GetOwner()) and ent:GetOwner():Alive()) then continue end
				
				if ent:GetPos():Distance(ply:GetPos()) <= 377 then
					local ownerName = IsValid(ent:GetOwner()) and ent:GetOwner():Nick() or "???"
					local screenPos = ent:GetPos():ToScreen()
	
					draw.SimpleText(ownerName, "timerFontBelow", screenPos.x, screenPos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
	end)
end