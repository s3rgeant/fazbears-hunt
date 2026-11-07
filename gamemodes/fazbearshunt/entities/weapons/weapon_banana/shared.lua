//----------------------------------
//-----Banana Bomb-------
// ------------Updated by GHXX---------
//-----------Made by schnul44----
//----------------------------------
AddCSLuaFile()

if SERVER then
	resource.AddFile("weapons/bananaicon")
end
	
game.AddAmmoType({
    name = "ammo_banana",
})

if CLIENT then
	SWEP.Icon = surface.GetTextureID("weapons/bananaicon");
end
SWEP.PrintName			= "#banana_peel"
SWEP.Purpose			= "#info_banana_peel"
SWEP.Author				= "GHXX"
SWEP.Slot				= 3
SWEP.SlotPos			= 1
SWEP.Icon = "weapons/bananaicon"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("weapons/bananaicon")
end
SWEP.HoldType = "grenade"

SWEP.Gifted = true

SWEP.Spawnable				= true
SWEP.AdminSpawnable			= false

SWEP.UseHands = true
SWEP.ViewModel				= "models/weapons/v_banana.mdl"
SWEP.WorldModel				= "models/weapons/w_banana.mdl"

SWEP.Weight					= 25
SWEP.AutoSwitchTo			= false
SWEP.AutoSwitchFrom			= false

SWEP.Primary.ClipSize			= -1
SWEP.Primary.DefaultClip		= 1
SWEP.Primary.Automatic   		= false
SWEP.Primary.Ammo         		= "ammo_banana"
SWEP.Primary.Delay 				= 1

SWEP.Secondary.ClipSize			= -1
SWEP.Secondary.DefaultClip		= -1
SWEP.Secondary.Automatic   		= false
SWEP.Secondary.Ammo         	= "none"

function SWEP:Initialize()
	self:SetWeaponHoldType( self.HoldType )
end

function SWEP:PrimaryAttack()

	local owner = self:GetOwner()
	owner:SetAnimation(PLAYER_ATTACK1)
	
	if SERVER then
		
		local Banana = ents.Create("banana_peel")
		Banana:SetOwner(owner)
		owner:LagCompensation(true)
		local pos = owner:GetShootPos()
		Banana:SetPos(pos + owner:GetAimVector() * 25)
		Banana:Spawn()
		Banana:Activate()
		
		local phys = Banana:GetPhysicsObject()
		if IsValid(phys) then
			phys:ApplyForceCenter(owner:GetAimVector() * math.Rand(300,350) * phys:GetMass())
		end
		owner:LagCompensation(false)

		self:SendWeaponAnim(ACT_VM_THROW)
		
		timer.Simple(0.2,function()
			if IsValid(self) then
				self:SendWeaponAnim(ACT_VM_DRAW)
			end
		end)
		
		self:TakePrimaryAmmo(1)
		self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
		
		if self:Clip1() <= 0 and self:Ammo1() <= 0 then
			owner:StripWeapon(self:GetClass())
		end
	end
end

function SWEP:SecondaryAttack()
	return false;
end

function SWEP:Deploy()
	self.Weapon:SendWeaponAnim(ACT_VM_DRAW)
	return true;
end

function SWEP:Holster()
	return true;
end
