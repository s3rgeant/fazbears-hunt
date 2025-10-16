AddCSLuaFile()

SWEP.PrintName = "#weapon_medkit"

SWEP.Slot = 2
SWEP.SlotPos = 2

if CLIENT then
	SWEP.DrawWeaponInfoBox	= false
	SWEP.BounceWeaponIcon	= false 
end

SWEP.Spawnable = true

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
SWEP.DenyCooldown = 1
SWEP.HealAmount = 10
SWEP.HealRange = 64

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
    if ent:IsPlayer() and ent:IsSurvivor() or ent:IsNPC() then
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

    self:SetClip1(ammo - healamount)
    ent:SetHealth(health + healamount)

    self:HealSuccess()
    return true
end

function SWEP:HealSuccess()
    self:EmitSound(self.HealSound)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

    local owner = self:GetOwner()
    if IsValid(owner) then owner:SetAnimation(PLAYER_ATTACK1) end

    local curtime = CurTime()
    self:SetNextIdle(curtime + self:SequenceDuration())
    self:SetNextPrimaryFire(curtime + self.HealCooldown)
    self:SetNextSecondaryFire(curtime + self.HealCooldown)
	
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
            if v ~= ply and v:IsSurvivor() and v:Alive() and v:Health() > 0 then
			
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

    hook.Add("PreDrawHalos", "MedkitHealAura", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "weapon_fh_medkit" then return end

        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity:IsSurvivor() and ply:GetPos():Distance(tr.Entity:GetPos()) <= wep.HealRange then
            halo.Add({tr.Entity}, Color(0, 255, 0), 2, 2, 2, true, false)
        end
    end)
	
	function SWEP:CustomAmmoDisplay()

		local display = self.AmmoDisplay
		display.PrimaryClip = self:Clip1()

		return display

	end
end
