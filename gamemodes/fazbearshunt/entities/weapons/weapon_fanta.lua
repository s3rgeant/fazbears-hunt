local math_min = math.min
local timer_Create = timer.Create
local timer_Remove = timer.Remove

SWEP.Base = "weapon_base"

SWEP.PrintName = "#weapon_fanta"
SWEP.Purpose = "#info_fanta"

SWEP.BounceWeaponIcon	= false 

SWEP.Slot = 3
SWEP.SlotPos = 2

SWEP.Gifted = true

SWEP.ViewModel = Model("models/johnmason/food/c_coca_cola_can.mdl")
SWEP.WorldModel = Model("models/johnmason/food/w_coca_cola_can.mdl")
SWEP.ViewModelFOV = 54
SWEP.UseHands = true
SWEP.DrawCrosshair = false
SWEP.DrawAmmo = false
SWEP.Spawnable = true

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Skin = 4

SWEP.FlexWeight = 0

SWEP.Consuming = false

if SERVER then
	resource.AddFile( "materials/weapons/fanta.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/fanta" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType("slam")
	self:SetSkin(self.Skin)
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
	
	timer.Simple(2.1, function()
		
		if IsValid(self) and IsValid(self.Owner) then
			self:OnDrink()
		end
	end)

	timer_Create("drink_remove_" .. self:EntIndex(), 4.7, 1, function()
		if not IsValid(self) or not IsValid(self.Owner) then return end

		if SERVER then
			self:Remove()
		end
	end)
end

function SWEP:OnDrink()
	if not SERVER then return end
	local ply = self:GetOwner()
	
	if not IsValid(ply) then return end
	
	local heal = math.random(3,5)
	local armor = 10
	
	for i = 1, heal do
		timer.Simple(0 + i/1, function()
			if IsValid(ply) and ply:Health() < 100 then
				ply:SetHealth(ply:Health() + 1)
			end
		end) 
	end
	
	for i = 1, armor do
		timer.Simple(0 + i/10, function()
			if IsValid(ply) and ply:Armor() < 100 then
				ply:SetArmor(ply:Armor() + 1)
			end
		end) 
	end
	
	ply:SetNW2Bool("FazbearsFantaEffect", true)
	
	timer.Simple(12, function()
		if IsValid(ply) then
			ply:SetNW2Bool("FazbearsFantaEffect", false)
		end
	end)
end

function SWEP:FireAnimationEvent( pos, ang, event, options )
	if event == 5001 then
		self.FlexWeight = 1
	end
end

function SWEP:OnRemove()
	timer_Remove("drink_remove_" .. self:EntIndex())
end

function SWEP:Holster()
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
	if SERVER then return end

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

hook.Add("OnPlayerJump", "fanta_buff", function(ply, speed)
	if ply:GetNW2Bool("FazbearsFantaEffect") then
		local vel = ply:GetAimVector()
		vel.z = math.max(vel.z, 0)
		ply:SetVelocity(vel * 250)
	end
end)