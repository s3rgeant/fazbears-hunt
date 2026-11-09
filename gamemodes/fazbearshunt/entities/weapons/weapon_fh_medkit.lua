AddCSLuaFile()

SWEP.PrintName = "#weapon_medkit"
SWEP.Purpose = "#info_medkit"

SWEP.Slot = 2
SWEP.SlotPos = 2

if CLIENT then
	SWEP.BounceWeaponIcon	= false 
end

SWEP.Spawnable = true

SWEP.Gifted = true

SWEP.ViewModel = Model("models/weapons/c_medkit.mdl")
SWEP.WorldModel = Model("models/weapons/w_medkit.mdl")
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = 50
SWEP.Primary.DefaultClip = SWEP.Primary.ClipSize
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.HoldType = "slam"

SWEP.HealSound = Sound("HealthKit.Touch")
SWEP.DenySound = Sound("WallHealth.Deny")

SWEP.HealCooldown = 1
SWEP.DenyCooldown = .5
SWEP.HealAmount = 10
SWEP.HealRange = 76

if SERVER then
	resource.AddFile( "materials/weapons/medkit.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/medkit" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)

    if CLIENT then
        self.AmmoDisplay = {
            Draw = true,
            PrimaryClip = 0
        }
    end
end

function SWEP:Deploy()
    return true
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle")
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    local dolagcomp = SERVER and owner:IsPlayer()

    if dolagcomp then owner:LagCompensation(true) end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.HealRange,
        filter = owner
    })

    if dolagcomp then owner:LagCompensation(false) end

    self:DoHeal(tr.Entity)
end

function SWEP:SecondaryAttack()
    self:DoHeal(self:GetOwner())
end

function SWEP:CanHeal(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() and ent:IsSurvivor() and !ent:IsInvisible() and !ent:GetNW2Bool("_OUTWORLD_target") or ent:IsNPC() then
        return ent:Health() < ent:GetMaxHealth()
    end
    return false
end

function SWEP:DoHeal(ent)
    if not self:CanHeal(ent) then self:HealFail() return false end

    local ammo = self:Clip1()
    if ammo <= 0 then self:HealFail() return false end

    local health, maxhealth = ent:Health(), ent:GetMaxHealth()
    if health >= maxhealth then self:HealFail() return false end

    local healamount = math.min(maxhealth - health, math.min(self.HealAmount, ammo))

	if IsFirstTimePredicted() then
		self:SetClip1(ammo - healamount)
		ent:SetHealth(health + healamount)
	end

    self:HealSuccess()
    return true
end

function SWEP:HealSuccess()
    local curtime = CurTime()
    self:SetNextIdle(curtime + self:SequenceDuration())
    self:SetNextPrimaryFire(curtime + self.HealCooldown)
    self:SetNextSecondaryFire(curtime + self.HealCooldown)
	
    self:EmitSound(self.HealSound)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

    local owner = self:GetOwner()
    if IsValid(owner) then owner:SetAnimation(PLAYER_ATTACK1) end
	
	if SERVER and self:Clip1() == 0 then
		timer.Simple(0.5, function()
			if IsValid(self) and IsValid(self.Owner) then
				self.Owner:StripWeapon(self:GetClass())
			end
		end)
	end
end

function SWEP:HealFail()
    self:EmitSound(self.DenySound)
    local endtime = CurTime() + self.DenyCooldown
    self:SetNextPrimaryFire(endtime)
    self:SetNextSecondaryFire(endtime)
end

function SWEP:Idle()
    local curtime = CurTime()
    if curtime < self:GetNextIdle() then return false end
    self:SendWeaponAnim(ACT_VM_IDLE)
    self:SetNextIdle(curtime + self:SequenceDuration())
    return true
end

if CLIENT then
    local function DrawHealthInfo()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_fh_medkit" then return end

        for _, v in player.Iterator() do
			if v:IsDormant() then continue end
            if v ~= ply and v:IsSurvivor() and v:Alive() and !v:IsInvisible() and !v:GetNW2Bool("_OUTWORLD_target") and v:Health() > 0 then
			
				local tr = util.QuickTrace( ply:EyePos(), v:WorldSpaceCenter() - ply:EyePos(), {ply, v} )
				
				if tr.Hit then continue end
			
                local pos = v:EyePos() + Vector(0, 0, 10)
                local screen = pos:ToScreen()
                local hp = v:Health()
                local color = Color(0, 255, 0)
                if hp < 95 and hp > 65 then
                    color = Color(255, 255, 0)
                elseif hp <= 65 and hp >= 25 then
                    color = Color(255, 165, 0)
                elseif hp < 25 then
                    color = Color(255, 0, 0)
                end

                draw.SimpleText(hp, "timerFontBelow", screen.x, screen.y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end
    hook.Add("HUDPaint", "MedkitHealthInfo", DrawHealthInfo)

	local MEDKIT_COLOR    = Color(0, 255, 0, 255)
	local function getMedkitTargets(ply, rule)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_fh_medkit" then return end

        local tr = ply:GetEyeTrace()
		
		local ent = tr.Entity
			
		if not IsValid(ent) then return nil end
		if ent:IsDormant() then return nil end
		if not ent:IsPlayer() then return nil end
		if not ent:IsSurvivor() then return nil end
		if ent:GetNW2Bool("_OUTWORLD_target") then return nil end
		if ent:IsInvisible() then return nil end
		if ply:GetPos():Distance(ent:GetPos()) > wep.HealRange then return nil end
		
		local entry = OUTLINE.NormalizeEntry(rule, {
			ent = ent,
			outline_color = MEDKIT_COLOR
		})

		return entry and { entry } or nil
    end
		
	OUTLINE.RegisterRule("medkit_target", {
		priority = 140,
		render_max_dist = 128,

		outline_color = MEDKIT_COLOR,
		outline_width = 2,
		outline_min_dist = 0,
		outline_max_dist = 0,

		fill_color = MEDKIT_COLOR,
		fill_min_dist = 0,
		fill_max_dist = 0,

		mode = OUTLINE_MODE_VISIBLE,
		collect = getMedkitTargets
	})
	
	function SWEP:CustomAmmoDisplay()

		local display = self.AmmoDisplay
		display.PrimaryClip = self:Clip1()

		return display

	end
end
