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
    dmgtype = DMG_BLAST,
    tracer = TRACER_NONE,
    plydmg = 0,
    npcdmg = 0,
    force = 500,
    minsplash = 5,
    maxsplash = 10,
    maxcarry = 50
})

if CLIENT then
	SWEP.Icon = surface.GetTextureID("weapons/bananaicon");
end
SWEP.PrintName			= "Banana Peel";
SWEP.Author				= "GHXX";
SWEP.Slot				= 3
SWEP.SlotPos			= 1
SWEP.Icon = "weapons/bananaicon"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("weapons/bananaicon");
end
SWEP.HoldType = "grenade"
SWEP.DrawAmmo = true

SWEP.Spawnable				= true;
SWEP.AdminSpawnable			= false;

SWEP.ViewModel				= "models/weapons/v_banana.mdl";
SWEP.WorldModel				= "models/weapons/w_banana.mdl";

SWEP.Weight					= 25;
SWEP.AutoSwitchTo			= false;
SWEP.AutoSwitchFrom			= false;

SWEP.Primary.ClipSize			= -1
SWEP.Primary.DefaultClip		= 1
SWEP.Primary.Automatic   		= false
SWEP.Primary.Ammo         		= "ammo_banana"
SWEP.Primary.Delay 				= 1

SWEP.Secondary.ClipSize			= 0
SWEP.Secondary.DefaultClip		= 0
SWEP.Secondary.Automatic   		= false
SWEP.Secondary.Ammo         	= "none"

SWEP.Sounds =
{
	Squeeze1 = Sound("weapons/bugbait/bugbait_squeeze1.wav"),
	Squeeze2 = Sound("weapons/bugbait/bugbait_squeeze2.wav"),
	Squeeze3 = Sound("weapons/bugbait/bugbait_squeeze3.wav")
}

function SWEP:Initialize()
	self:SetWeaponHoldType( self.HoldType )
end

function SWEP:PrimaryAttack()
	if SERVER then
	
		local owner = self.Owner
		
		owner:LagCompensation(true)
		
		local Banana = ents.Create("banana_peel");

		Banana.BananaType = 1;
		Banana.Owner = self.Owner;

		Banana:SetPos(owner:GetShootPos() + owner:GetAimVector() * 30);
		Banana:Spawn();
		Banana:Activate();
		
		local Physics = Banana:GetPhysicsObject();

		if IsValid(Physics) then
			Physics:ApplyForceCenter(owner:GetAimVector() * math.Rand(300,350) * Physics:GetMass());

			self.Weapon:SendWeaponAnim(ACT_VM_THROW);

			local function C()

				if IsValid(self.Weapon) then

					self.Weapon:SendWeaponAnim(ACT_VM_DRAW);
				end

			end
			
			timer.Simple(0.1,C);
		end
		owner:LagCompensation(false)
		
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
	self.Weapon:SendWeaponAnim(ACT_VM_DRAW);
	return true;
end

function SWEP:Holster()
	return true;
end
