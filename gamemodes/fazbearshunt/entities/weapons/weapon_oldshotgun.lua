AddCSLuaFile()

if CLIENT then
    SWEP.BounceWeaponIcon = false
    killicon.Add( "weapon_oldshotgun", "vgui/killicons/weapon_shotgun", Color( 255, 0, 0, 255 ) )
end

sound.Add({
    name = "Weapon.Swing",
    channel = CHAN_ITEM,
    volume = 0.7,
    pitch = {95, 105},
    soundlevel = SNDLVL_NORM,
    sound = ")player/survivor/swing/Swish_WeaponSwing_Swipe5.wav"
})
sound.Add({
    name = "Weapon.HitWorld",
    channel = CHAN_STATIC,
    volume = 1.0,
    pitch = {95, 105},
    soundlevel = SNDLVL_90dB,
    sound = ")player/survivor/hit/rifle_swing_hit_world.wav"
})
sound.Add({
    name = "Weapon.HitInfected",
    channel = CHAN_STATIC,
    volume = 0.8,
    soundlevel = SNDLVL_70dB,
    sound = ")player/survivor/hit/rifle_swing_hit_infected7.wav"
})

SWEP.PrintName = "#weapon_oldshotgun"
SWEP.Purpose = "#info_oldshotgun"
SWEP.Spawnable = true
SWEP.Gifted = true

SWEP.ViewModelFOV = 60
SWEP.ViewModel = "models/fh/weapons/v_pumpshotgun.mdl"
SWEP.WorldModel = "models/fh/weapons/w_shotgun.mdl"
SWEP.ViewModelFlip = false

SWEP.SwayScale = 0.5
SWEP.BobScale = 0.5
SWEP.m_WeaponDeploySpeed = 1

SWEP.Weight = 20

SWEP.Slot = 3
SWEP.SlotPos = 0

SWEP.UseHands = true
SWEP.FiresUnderwater = false
SWEP.CSMuzzleFlashes = 1

SWEP.Primary.Sound = Sound( "Shotgun.Fire" )
SWEP.Primary.ClipSize = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.MaxAmmo = 56
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "Buckshot"
SWEP.Primary.Damage = 5
SWEP.Primary.Recoil = 4
SWEP.Primary.Spread = 10
SWEP.Primary.NumberofShots = 10
SWEP.Primary.Delay = 0.71
SWEP.Primary.Force = 2

SWEP.Secondary.Sound = Sound( "Weapon.Swing" )
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Damage = 10
SWEP.Secondary.Delay = 0.73
SWEP.Secondary.Force = 1

if SERVER then
    resource.AddFile( "materials/weapons/pumpshotgun.vmt" )
else
    SWEP.WepSelectIcon = surface.GetTextureID( "weapons/pumpshotgun" )
    SWEP.BounceWeaponIcon = false
end

-- Регистрация NetworkVar'ов
function SWEP:SetupDataTables()
    self:NetworkVar( "Int",   0, "ShotgunReload" )    -- 0: не перезаряжается, 1: начало, 2: дозарядка
    self:NetworkVar( "Float", 0, "ShotgunReloadTimer" )
    self:NetworkVar( "Float", 1, "IdleTimer" )
    self:NetworkVar( "Int",   1, "IsIdle" )           -- 0: нужно играть idle, 1: уже сыгран
end

function SWEP:Initialize()
    self:SetHoldType( "shotgun" )
end

function SWEP:Deploy()
    self:SetHoldType( "shotgun" )
    self:SendWeaponAnim( ACT_VM_DRAW )
    
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        self:SetNextPrimaryFire( CurTime() + vm:SequenceDuration() )
        self:SetNextSecondaryFire( CurTime() + vm:SequenceDuration() )
        self:SetIdleTimer( CurTime() + vm:SequenceDuration() )
    end

    self:SetShotgunReload( 0 )
    self:SetShotgunReloadTimer( CurTime() )
    self:SetIsIdle( 1 )

    timer.Simple( 0.1, function()
        if IsValid( self ) then 
            self:EmitSound( ")weapons/shotgun/gunother/shotgun_pump_1.wav" ) 
        end
    end)
    
    return true
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    local iftp = IsFirstTimePredicted()
    
    if iftp then 
        if self:GetShotgunReload() ~= 0 then return end
        
        if (self:Clip1() <= 0 and self:Ammo1() <= 0) or (not self.FiresUnderwater and owner:WaterLevel() == 3) then
            self:EmitSound( "Default.ClipEmpty_Rifle" )
            self:SetNextPrimaryFire( CurTime() + 0.2 )
            return
        end
    end
    
    if self:Clip1() <= 0 and self:Ammo1() > 0 then
        self:Reload()
        return
    end
    
    if self:Clip1() <= 0 then return end
    if not self.FiresUnderwater and owner:WaterLevel() == 3 then return end

    owner:LagCompensation( true )
    local bullet = {
        Attacker = owner,
        Inflictor = self,
        Num = self.Primary.NumberofShots,
        Src = owner:GetShootPos(),
        Dir = owner:GetAimVector(),
        Spread = Vector( 0.01 * self.Primary.Spread, 0.01 * self.Primary.Spread, 0 ),
        Tracer = 1,
        Force = self.Primary.Force,
        Damage = self.Primary.Damage,
        AmmoType = self.Primary.Ammo
    }
    
    if CLIENT and iftp then
        local light = DynamicLight( self:EntIndex() )
        if light then
            light.pos = owner:EyePos() + owner:GetForward() * 100
            light.r = 180
            light.g = 120
            light.b = 0
            light.brightness = 2
            light.Decay = 1000
            light.Size = 150
            light.DieTime = CurTime() + 0.2
        end
    end
    
    self:EmitSound( self.Primary.Sound )
    if iftp then 
        owner:SetAnimation( PLAYER_ATTACK1 )
        owner:FireBullets( bullet )
        owner:MuzzleFlash()
        owner:ViewPunchReset()
    end
    
    owner:ViewPunch( Angle( -1 * self.Primary.Recoil, 0, 0 ) )
    owner:LagCompensation( false )
    
    self:TakePrimaryAmmo( 1 )
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
    self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
    self:SetIsIdle( 0 )
    self:SetIdleTimer( CurTime() + 1.1 )
    self:SetShotgunReloadTimer( CurTime() + 0.8 )
    
    if self:Clip1() <= 0 and self:Ammo1() <= 0 then
        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK_SILENCED )
        self:SetIdleTimer( CurTime() + 5 )
        self:SetShotgunReloadTimer( CurTime() + 5 )
        
        timer.Simple( 1.1, function()
            if SERVER and IsValid( self ) then self:Remove() end
        end)
        return
    else
        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    end
    
    timer.Simple( 0.15, function() 
        if IsValid( self ) then
            self:EmitSound( ")weapons/shotgun/gunother/shotgun_pump_1.wav", nil, nil, 0.3, CHAN_AUTO )
        end
    end)
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if self:GetShotgunReload() ~= 0 then return end
    
    local curtime = CurTime()
    self:SetShotgunReloadTimer( curtime + 0.5 )
    
    self:EmitSound( self.Secondary.Sound )
    owner:LagCompensation( true )
    
    local tr = util.TraceLine( {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 75,
        filter = owner,
        mask = MASK_SHOT_HULL,
    } )
    
    if not IsValid( tr.Entity ) then
        tr = util.TraceHull( {
            start = owner:GetShootPos(),
            endpos = owner:GetShootPos() + owner:GetAimVector() * 75,
            filter = owner,
            mins = Vector( -16, -16, 0 ),
            maxs = Vector( 16, 16, 0 ),
            mask = MASK_SHOT_HULL,
        } )
    end
    
    local target = tr.Entity
    if SERVER and tr.Hit and not ( IsValid( target ) and ( target:IsNPC() or target:IsPlayer() or target:Health() > 0 ) ) then
        owner:EmitSound( "Weapon.HitWorld" )
    end
    
    if SERVER and IsValid( target ) then
        local dmginfo = DamageInfo()
        dmginfo:SetAttacker( IsValid( owner ) and owner or self )
        dmginfo:SetInflictor( self )
        dmginfo:SetDamage( self.Secondary.Damage )
        dmginfo:SetDamageForce( owner:GetForward() * self.Secondary.Force )
        target:TakeDamageInfo( dmginfo )
        
        if tr.Hit then
            if target:IsNPC() or target:IsPlayer() or target:Health() > 0 then
                local pill = target:IsPlayer() and target:GetPillCostume() or nil
                if IsValid( pill ) and not pill:IsInvisible() and not pill.cloaked then
                    owner:EmitSound( "Weapon.HitWorld" )
                else
                    owner:EmitSound( "Weapon.HitInfected" )
                end
            else
                owner:EmitSound( "Weapon.HitWorld" )
            end
        end
    end
    
    owner:LagCompensation( false )
    self:SendWeaponAnim( ACT_VM_SECONDARYATTACK )
    owner:DoAnimationEvent( ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND )
    self:SetNextPrimaryFire( curtime + self.Secondary.Delay )
    self:SetNextSecondaryFire( curtime + self.Secondary.Delay )
    self:SetIsIdle( 0 )
    self:SetIdleTimer( curtime + owner:GetViewModel():SequenceDuration() )
end

function SWEP:Reload()
    local owner = self:GetOwner()
    
    if self:Clip1() < self.Primary.ClipSize and self:Ammo1() > 0 and self:GetShotgunReload() == 0 and self:GetShotgunReloadTimer() <= CurTime() then
        self:EmitSound( ")weapons/shotgun/gunother/shotgun_load_shell_2.wav" )
        
        self:SendWeaponAnim( ACT_VM_RELOAD )
        owner:SetAnimation( PLAYER_RELOAD )
        
        local seqDur = owner:GetViewModel():SequenceDuration()
        self:SetNextPrimaryFire( CurTime() + seqDur )
        self:SetNextSecondaryFire( CurTime() + seqDur )
        
        self:SetShotgunReload( 1 )
        self:SetShotgunReloadTimer( CurTime() + 0.5 )
        self:SetIsIdle( 0 )
        self:SetIdleTimer( CurTime() + 0.6 )
        self:SetClip1( self:Clip1() + 1 )
    end
end

function SWEP:Think()
    local owner = self:GetOwner()
    local curTime = CurTime()
    
    self:StopSound( "Weapon_Shotgun.Special1" )
    
    local reloadState = self:GetShotgunReload()
    local reloadTimer = self:GetShotgunReloadTimer()
    
    if reloadState == 1 and reloadTimer <= curTime then
        owner:RemoveAmmo( 1, self.Primary.Ammo, false )
        
        if self:Clip1() >= self.Primary.ClipSize or self:Ammo1() <= 0 then
            self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_FINISH )
            local vm = owner:GetViewModel()
            local seqDur = IsValid( vm ) and vm:SequenceDuration() or 0.5
		
            self:SetNextPrimaryFire( curTime + seqDur )
            self:SetNextSecondaryFire( curTime + seqDur )
            self:SetShotgunReload( 0 )
            self:SetShotgunReloadTimer( curTime + seqDur )
        else
            self:EmitSound( ")weapons/shotgun/gunother/shotgun_load_shell_2.wav" )
            self:SendWeaponAnim( ACT_VM_RELOAD_IDLE )
            self:SetClip1( self:Clip1() + 1 )
            self:SetShotgunReload( 2 )
            self:SetShotgunReloadTimer( curTime + 0.42 )
        end
        
        self:SetIsIdle( 0 )
        self:SetIdleTimer( curTime + 0.6 )
    end
    
    if reloadState == 2 and reloadTimer <= curTime then
        owner:RemoveAmmo( 1, self.Primary.Ammo, false )
        
        if self:Clip1() >= self.Primary.ClipSize or self:Ammo1() <= 0 then
            self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_FINISH )
            local vm = owner:GetViewModel()
            local seqDur = IsValid( vm ) and vm:SequenceDuration() or 0.5
            
            self:SetNextPrimaryFire( curTime + seqDur )
            self:SetNextSecondaryFire( curTime + seqDur )
            self:SetShotgunReload( 0 )
            self:SetShotgunReloadTimer( curTime + seqDur )
        else
            self:EmitSound( ")weapons/shotgun/gunother/shotgun_load_shell_2.wav" )
            self:SendWeaponAnim( ACT_VM_RELOAD_IDLE )
            self:SetClip1( self:Clip1() + 1 )
            self:SetShotgunReload( 2 )
            self:SetShotgunReloadTimer( curTime + 0.42 )
        end
        
        self:SetIsIdle( 0 )
        self:SetIdleTimer( curTime + 0.7 )
    end
    
    if self:GetIsIdle() == 0 and self:GetIdleTimer() > curTime and self:GetIdleTimer() < curTime + 0.1 then
        self:SendWeaponAnim( ACT_VM_IDLE )
        self:SetIsIdle( 1 )
    end
    
    if self:Ammo1() > self.Primary.MaxAmmo then
        owner:SetAmmo( self.Primary.MaxAmmo, self.Primary.Ammo )
    end
end

function SWEP:FireAnimationEvent( pos, ang, event, options )
    if not self.CSMuzzleFlashes then return end
    
    if event == 21 then
        local data = EffectData()
        data:SetFlags( 0 )
        data:SetEntity( self:GetOwner():GetViewModel() )
        data:SetAttachment( 5 )
        data:SetScale( 2 )

        if self.CSMuzzleX then
            util.Effect( "CS_MuzzleFlash_X", data )
        else
            util.Effect( "CS_MuzzleFlash", data )
        end
    
        return true
    end
end

if SERVER then
	util.AddNetworkString("fh_oldshotgun_slowdown")
	hook.Add( "PostEntityTakeDamage", "fh_oldshotgun_force", function( ply, dmginfo, wasDamageTaken )
		if IsValid(dmginfo:GetWeapon()) and dmginfo:GetWeapon():GetClass() == "weapon_oldshotgun" then
			if ply:IsPlayer() and ply:IsAnimatronic() then
				local ent = ply:GetPillCostume()
				if IsValid(ent) then
					if not ply.oldshotgunShots then ply.oldshotgunShots = 0 end
				
					local scaleForce = ply:OnGround() and .012 or .01
					
					ply:SetVelocity(dmginfo:GetDamageForce() * scaleForce)
					
					ent:PillGesture('damaged' .. math.random(1,3), 1, 1, 0, 0.7)
					
					local damage = dmginfo:GetDamage()
					
					if ply.oldshotgunShots > 0 and damage >= 10 then
						ply.SpeedSlowEnd = CurTime() + ((ply.SpeedSlowEnd or CurTime()) - CurTime()) + (damage / 35)
						
						if ply.SpeedSlowEnd > CurTime() + 6 then -- Как бы сильно не старались, анима кдшит максимум на 10 сек
							ply.SpeedSlowEnd = CurTime() + 6
						end
						
						net.Start("fh_oldshotgun_slowdown")
						net.WriteFloat(ply.SpeedSlowEnd)
						net.Send(ply)
					end
					
					local addup = AngleRand() * .05
					addup.z = 0
					
					ply:SetEyeAngles(ply:EyeAngles() + addup)
					
					ply.oldshotgunShots = ply.oldshotgunShots+1
					timer.Simple(3, function()
						if IsValid(ply) and ply.oldshotgunShots > 0 then
							ply.oldshotgunShots = ply.oldshotgunShots - 1
						end
					end)
					
				end
			end
		end
	end)
	
	local PLAYER = FindMetaTable("Player")
	
	if PLAYER then
		function PLAYER:SetSpeedSlowdown(duration)
			self.SpeedSlowEnd = CurTime() + duration
			
			net.Start("fh_oldshotgun_slowdown")
			net.WriteFloat(self.SpeedSlowEnd)
			net.Send(self)
		end
	end
else
	net.Receive("fh_oldshotgun_slowdown", function()
		local ply = LocalPlayer()
		ply.SpeedSlowEnd = net.ReadFloat()
	end)
end

hook.Add("Move", "fh_oldshotgun_slowdown", function(ply, mv)
    local endTime = ply.SpeedSlowEnd
    if not endTime then return end

    local remain = endTime - CurTime()

    if remain <= 0 then
        ply.SpeedSlowEnd = nil
        return
    end

    local frac = math.max(0, 1 - remain)

    local mul = Lerp(frac, .5, 1)

    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mul)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * mul)
end)