local math_min = math.min
local timer_Create = timer.Create
local timer_Remove = timer.Remove

SWEP.Base = "weapon_base"

SWEP.PrintName = "Fanta"

SWEP.DrawWeaponInfoBox	= false
SWEP.BounceWeaponIcon	= false 

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = Model("models/johnmason/food/c_coca_cola_can.mdl")
SWEP.WorldModel = Model("models/johnmason/food/w_coca_cola_can.mdl")
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.HealAmount = 10
SWEP.Skin = 4
SWEP.SubMaterial = "models/johnmason/food/fanta_can"

SWEP.FlexWeight = 0

SWEP.Consuming = false

CreateConVar("consumable_drinks_heal_modifier", 1, FCVAR_ARCHIVE, "Drinks heal multiplier", 0, 200)
CreateConVar("consumable_drinks_armor_modifier", 1, FCVAR_ARCHIVE, "Drinks armor multiplier", 0, 200)

function SWEP:Initialize()
	self:SetHoldType("slam")
	self:SetSkin(self.Skin)
	self:SetSubMaterial(1, self.SubMaterial)
end

function SWEP:PrimaryAttack()
	if self.Opened then return end
	self.Opened = true

	self:SetNextPrimaryFire(CurTime() + 5)
	self:SetNextSecondaryFire(CurTime() + 5)

	if SERVER then
		self.Owner:EmitSound("food/soda_open.wav", 60)
	end

	self:SendWeaponAnim(ACT_VM_RELEASE)
	self.Owner:SetAnimation(PLAYER_ATTACK1)
	
	self.Consuming = true

	timer_Create("drink_remove_" .. self:EntIndex(), 4.7, 1, function()
		if not IsValid(self) or not IsValid(self.Owner) then return end

		-- Эффект напитка
		self:OnDrink()

		if SERVER then
			self.Owner:StripWeapon(self:GetClass())
		end
	end)
end

function SWEP:OnDrink()
	if not (IsValid(self.Owner) and SERVER) then return end

	local ply = self.Owner
	
	ply:SetJumpPower(ply:GetJumpPower() * 2)
	
	timer.Simple(15, function()
		if IsValid(ply) then
			ply:SetJumpPower(math.max(ply:GetJumpPower() / 2, 200))
		end
	end)
end

function SWEP:FireAnimationEvent( pos, ang, event, options )
	if event == 49 then
	self.FlexWeight = 1
	end
end

function SWEP:OnRemove()
	timer_Remove("drink_remove_" .. self:EntIndex())

	if CLIENT and IsValid(self.Owner) and IsValid(self.Owner:GetViewModel()) then
		self.Owner:GetViewModel():SetSubMaterial(1, nil)
	end
end

function SWEP:Holster()
	if CLIENT and IsValid(self.Owner) and IsValid(self.Owner:GetViewModel()) then
		self.Owner:GetViewModel():SetSubMaterial(1, nil)
	end
	if self.Consuming then
		return false
	end
	return true
end

function SWEP:Deploy()
	self.FlexWeight = 0
	self.FlexWeightLerp = 0
	
	local vm = self.Owner:GetViewModel()
	
	if !IsValid(vm) then return end

	local FlexNum = vm:GetFlexNum()
	if ( FlexNum <= 0 ) then return end

	for i = 0, FlexNum do

		self.FlexWeightLerp = Lerp(FrameTime() * 16, self.FlexWeightLerp, self.FlexWeight)
		vm:SetFlexWeight( i, self.FlexWeightLerp )

	end
	return true
end

function SWEP:Reload()
    return
end

function SWEP:SecondaryAttack()
    return
end

SWEP.FlexWeightLerp = 0

function SWEP:Think()
	local vm = self.Owner:GetViewModel()

	local FlexNum = vm:GetFlexNum()
	if ( FlexNum <= 0 ) then return end

	for i = 0, FlexNum do

		self.FlexWeightLerp = Lerp(FrameTime() * 16, self.FlexWeightLerp, self.FlexWeight)
		vm:SetFlexWeight( i, self.FlexWeightLerp )

	end
	vm:SetFlexScale( 1 )
	return true
end