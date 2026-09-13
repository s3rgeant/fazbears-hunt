AddCSLuaFile()

SWEP.PrintName = "#weapon_jammer"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 4
SWEP.SlotPos = 0

SWEP.Spawnable = true

SWEP.Gifted = true

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

SWEP.CalcMinimalViewModelView = Vector(8,0,-6)

SWEP.LerpFOV = 0

if SERVER then
	resource.AddFile( "materials/weapons/jammer.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/jammer" )
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
	
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
	owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE)
	
	self:SpawnJammer(owner)
	
	self:SetThrew(true)
	timer.Create("JammerRemove" .. self:EntIndex(), 1.2, 1, function()
		if SERVER and IsValid(self) and IsValid(self:GetOwner()) then
			self:Remove()
		end
	end)
end

local clr = Color(55,55,55,255)
function SWEP:SpawnJammer(owner)
	if SERVER then
		if not IsValid(owner) then return end
		
		owner:LagCompensation(true)
			
		local eyePos = owner:EyePos()
		local aimDir = owner:GetAimVector()

		local spawnPos = eyePos + aimDir * 5
		
		local ent = ents.Create("prop_jammer")
		
		owner:LagCompensation(false)

		ent:SetPos(spawnPos)
		ent:SetAngles(aimDir:Angle())
		ent:Spawn()
		ent:Activate()
		ent:SetOwner(owner)

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocity(aimDir * 1400 + owner:GetVelocity())
			phys:SetAngleVelocity(aimDir * 250)
		end

		owner:EmitSound("WeaponFrag.Throw")
		
		owner:AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE, true)
		
		net.Start("AnimRestartGesture")
			net.WriteEntity(owner)
			net.WriteInt(4, 4)
			net.WriteInt(ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE, 12)
		net.SendPVS(owner:GetPos())
		
		owner:RemoveAmmo(1, "snowball")
	end
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

function SWEP:DrawWorldModel( flags )
	local ply = self:GetOwner()
	if not self:GetThrew() then
		self:DrawModel( flags )
	end
end