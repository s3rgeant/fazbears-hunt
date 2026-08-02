AddCSLuaFile()

SWEP.PrintName = "#weapon_jammer"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 0

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/fh/weapons/c_jammer.mdl" )
SWEP.WorldModel = Model( "models/fh/weapons/w_jammer.mdl" )
SWEP.ViewModelFOV = 90
SWEP.UseHands = true

SWEP.Primary.ClipSize = 15
SWEP.Primary.DefaultClip = SWEP.Primary.ClipSize
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.LerpFOV = 0

if SERVER then
	--resource.AddFile( "materials/weapons/bonnie_mask.vmt" )
else
	--SWEP.WepSelectIcon = surface.GetTextureID( "weapons/bonnie_mask" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType( "slam" )
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Float", 2, "NextThrow" )
	self:NetworkVar( "Bool", "BlockSwap" )
	self:NetworkVar( "Bool", "Aim" )
	self:NetworkVar( "Bool", "Threw" )
	--self:NetworkVar( "Entity", "LastUser" )
end


function SWEP:Holster()

	-- чтоб нельзя было переключаться пока под защитой
	if self:GetAim() then
		return false
	end
	
	return true
end

function SWEP:PrimaryAttack()
	if self:GetAim() then return end
    self:SetNextIdle(0)
    self:SetNextThrow(CurTime() + 0.3)

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:SetAim(true)
	
	self:SetHoldType( "grenade" )
end

function SWEP:Throw()
	local owner = self:GetOwner()
	self:SetHoldType( "normal" )
	
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
	owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE)
	
	self:SetThrew(true)
	timer.Create("JammerRemove" .. self:EntIndex(), 1.2, 1, function()
		if SERVER and IsValid(self) and IsValid(self:GetOwner()) then
			self:Remove()
		end
	end)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Think()
	local owner = self:GetOwner()
    if SERVER and self:GetAim() and not self:GetThrew() and not owner:KeyDown(IN_ATTACK) and CurTime() >= self:GetNextThrow() then
        self:Throw()
    end
	
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end
end