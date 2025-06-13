AddCSLuaFile()

if SERVER then
	util.AddNetworkString( "DefibrilatorMelee_NW" )
    util.AddNetworkString("DefibrilatorEffect")
else -- CLIENT
	SWEP.DrawWeaponInfoBox	= false
	SWEP.BounceWeaponIcon	= false 

	SWEP.WepSelectIcon = surface.GetTextureID("vgui/achievements/hl2_beat_game") 

	language.Add("weapon_defibrilator", "Defibrilator")
	
	net.Receive( "DefibrilatorMelee_NW", function()
		local ply = net.ReadEntity()
		if IsValid( ply ) and ply:IsPlayer() and ply:Alive() then
			ply:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, ACT_HL2MP_GESTURE_RANGE_ATTACK_KNIFE, true )
		end
	end )
end

SWEP.PrintName = "Defibrilator"
SWEP.Spawnable = true

SWEP.ViewModelFOV = 75
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

function SWEP:Think()
	if self.Owner:KeyDown(IN_ATTACK) then
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
        if !IsValid(self.ReviveTarget) or !self.Owner:KeyDown(IN_ATTACK) or self.Owner:GetPos():Distance(self.ReviveTarget:GetPos()) > 77 then
            self.Reviving = false
            self.ReviveStartTime = 0
            self.ReviveTarget = nil
            self.OldPos = nil

            if self.ReviveSound then
                self.ReviveSound:Stop()
            end

            self.Owner:EmitSound("HL2Player.UseDeny")

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

                self.Owner:EmitSound("defibl/charged.wav", 75, 100)
                self:SetClip1(100)

                local ply = v:GetCreator()
                if IsValid(ply) then
                    ply.BeingRevived = true
                    ply:Spawn()
                    ply:SetPos(oldpos)
					ply:SetTeam(TEAM_UNASSIGNED)
					
					if !survivors[ply] then
						survivors[ply] = true
					end
					
					LogEvent("☦️ Игрок **" .. self.Owner:Nick() .. "** возродил **" .. ply:Nick() .. "** дефибриллятором")

                    timer.Simple(1 / 100, function()
                        if IsValid(ply) and IsStuckInWall(ply) then
                            ply:SetPos(FindSafePosition(ply, self.Owner))
                        end
                    end)
					
					hook.Run("fh_defibrillator_spawn", ply)
                end

                v:Remove()

                timer.Simple(0.5, function()
                    if IsValid(self) and IsValid(self.Owner) then
                        self.Owner:StripWeapon(self:GetClass())
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

    local tr = util.TraceLine({
        start = self.Owner:GetShootPos(),
        endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 60,
        filter = self.Owner,
        mask = MASK_SHOT_HULL,
    })

    if not IsValid(tr.Entity) then
        tr = util.TraceHull({
            start = self.Owner:GetShootPos(),
            endpos = self.Owner:GetShootPos() + self.Owner:GetAimVector() * 60,
            filter = self.Owner,
            mins = Vector(-20, -20, 0),
            maxs = Vector(20, 20, 0),
            mask = MASK_SHOT_HULL,
        })
    end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay + 0.2)

    if IsValid(tr.Entity) then
        for k, v in pairs(ents.FindInSphere(self.Owner:GetShootPos(), 70)) do
            if v:GetClass() == 'prop_ragdoll' then
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
					self.ReviveSound = CreateSound(self.Owner, "defibl/defibrillator_use_start.wav")
				end
				self.ReviveSound:Play()
	
				self.Owner:ViewPunch(Angle(-10, 0, 0))
				self:SetClip1(10)
	
				return
            end
        end
        self.Owner:EmitSound("HL2Player.UseDeny")
    else
        self.Owner:EmitSound("HL2Player.UseDeny")
    end

    self.Owner:SetAnimation(PLAYER_ATTACK1)
    self.Idle = 0
    self.IdleTimer = CurTime() + self.Owner:GetViewModel():SequenceDuration()
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
		dmginfo:SetDamage(25)
			
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
	ply.LastDeathTime = CurTime()
	
	if IsValid( ply:GetActiveWeapon() ) then
		ply.ReviveActiveWeapon = ply:GetActiveWeapon():GetClass()
	end
	
	ply.ReviveWeapons = {}
	for k, v in pairs( ply:GetWeapons() ) do
		table.insert( ply.ReviveWeapons, v:GetClass() )
	end
	
	ply.RevivePos = ply:GetPos()
	
	ply.ReviveAng = ply:EyeAngles()
	
	ply.RevivalPreviousAmmo = {}
	for k, v in pairs( ply:GetWeapons() ) do
		local primary = v:GetPrimaryAmmoType()
		local secondary = v:GetSecondaryAmmoType()
		
		local newPrimary = math.floor( ply:GetAmmoCount( primary ) * 0.5 )
		local newSecondary = math.floor( ply:GetAmmoCount( secondary ) * 0.5 )
		
		ply.RevivalPreviousAmmo[primary] = newPrimary
		ply.RevivalPreviousAmmo[secondary] = newSecondary
	end
end

hook.Add( "PlayerSilentDeath", "Defibl_Revive", function( ply )
	SetDefibAttributes(ply)
end)

hook.Add( "DoPlayerDeath", "Defibl_Revive", function( ply )
	SetDefibAttributes(ply)
end)

hook.Add( "PlayerLoadout", "Defibl_Revive", function( ply )
	if !IsValid( ply ) then return end
	if !ply.BeingRevived then return end
	
	ply.BeingRevived = nil
	
	if ply.ReviveWeapons ~= nil then
		for k, v in pairs( ply.ReviveWeapons ) do
			ply:Give(v)
		end
	end
	
	if ply.ReviveActiveWeapon ~= nil then
		ply:SelectWeapon( ply.ReviveActiveWeapon )
	end
	
	if ply.RevivalPreviousAmmo ~= nil then
		for k, v in pairs( ply.RevivalPreviousAmmo ) do
			ply:GiveAmmo( v, k, true )
		end
	end
	
	return true
end)

if SERVER then
	hook.Add( "OnEntityCreated", "Defibl_Revive", function( ent )
		if ent:IsNPC() then
			timer.Simple(0, function() if IsValid(ent) then
				if IsValid(ent:GetActiveWeapon()) then -- because this returns nothing if called when npc is dead
					ent.DefiblReviveEntWep = ent:GetActiveWeapon():GetClass()
				end
			end
			end)
		end
		
		if ent:GetClass() == "prop_ragdoll" then
			timer.Simple(0, function() if IsValid(ent) then
				ent.DefiblReviveEnt = ent.EntityClass -- DrGBase
				ent.DefiblReviveEntHP = 0 -- we can't get the Nextbot entity
			end
			end)
		end
	end)

	hook.Add( "CreateEntityRagdoll", "Defibl_Revive", function( owner,ent )
		if IsValid(ent) and IsValid(owner) and (owner:IsNPC() or (owner.Type == "nextbot" and !owner:GetClass():find("drg")) or (owner:IsPlayer() and !owner:Alive())) then
			local hp = owner:GetMaxHealth()
			local mdl = owner:GetModel()
			local name = owner:GetName()
			local wepclass = owner.DefiblReviveEntWep -- given to us by create hook
			
			if owner:IsPlayer() then
				ent.DefiblReviveEnt = owner:EntIndex()
			else
				local npc = owner:GetClass()
				ent.DefiblReviveEnt = npc -- VJ

				timer.Simple(0, function() if IsValid(ent) then -- for Keep Corpses
					ent.DefiblReviveEnt = npc
					ent.DefiblReviveEntHP = hp
					ent.DefiblReviveEntMDL = mdl
					ent.DefiblReviveEntName = name
					ent.DefiblReviveEntWep = wepclass
				end
				end)
			end
			ent.DefiblReviveEntHP = hp
			ent.DefiblReviveEntMDL = mdl
			ent.DefiblReviveEntName = name
			ent.DefiblReviveEntWep = wepclass
		end
	end )
else -- CLIENT
    hook.Add("PreDrawHalos", "DefibrillatorHighlightCorpses", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()

        if IsValid(wep) and wep:GetClass() == "weapon_defibrilator" then
            local corpses = {}

            for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
                if ent:GetPos():Distance(ply:GetPos()) <= 3064 then
                    table.insert(corpses, ent)
                end
            end

            halo.Add(corpses, Color(255, 0, 0), 1, 1, 2, true, true)
        end
    end)

	hook.Add("HUDPaint", "DefibDrawNames", function()
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
	
		if IsValid(wep) and wep:GetClass() == "weapon_defibrilator" then
			for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
				if ent:GetPos():Distance(ply:GetPos()) <= 377 then
					local ownerName = IsValid(ent:GetOwner()) and ent:GetOwner():Nick() or "???"
					local screenPos = ent:GetPos():ToScreen() -- Позиция для отображения
	
					draw.SimpleText(ownerName, "timerFontBelow", screenPos.x, screenPos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
	end)
end

function IsStuckInWall(player)
    local trace = util.TraceEntity({
        start = player:GetPos(),
        endpos = player:GetPos(),
        filter = player,
    }, player)
    return trace.Hit
end

function FindSafePosition(player, reviver)
    local startPos = player:GetPos()
    local startPosR = reviver:GetPos()
    local maxDistance = 100
    local stepSize = 10

    for radius = stepSize, maxDistance, stepSize do
        for angle = 0, 360, 15 do
            local offsetX = math.cos(math.rad(angle)) * radius
            local offsetY = math.sin(math.rad(angle)) * radius
            local testPos = startPos + Vector(offsetX, offsetY, 0)
            local testPosR = startPosR + Vector(offsetX, offsetY, 0)

            local trace = util.TraceHull({
                start = testPos,
                endpos = testPos,
                mins = player:OBBMins(),
                maxs = player:OBBMaxs(),
                filter = player,
				mask = MASK_ALL,
            })

            if not trace.Hit then
				debugoverlay.Line(startPos, testPos, 5, Color(255, 0, 0), true)
                return testPos
            end

            local trace = util.TraceHull({
                start = testPosR,
                endpos = testPosR,
                mins = player:OBBMins(),
                maxs = player:OBBMaxs(),
                filter = player,
				mask = MASK_ALL,
            })

            if not trace.Hit then
				debugoverlay.Line(startPos, testPos, 5, Color(0, 255, 0), true)
                return testPosR
            end
        end
    end

    return startPos
end