
AddCSLuaFile()

SWEP.PrintName = "#weapon_crucifix"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 2
SWEP.SlotPos = 0

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_crucifix.mdl" )
--SWEP.WorldModel = Model( "models/weapons/w_bonmask.mdl" )
SWEP.ViewModelFOV = 80
SWEP.UseHands = true

SWEP.Primary.ClipSize = 15
SWEP.Primary.DefaultClip = SWEP.Primary.ClipSize
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.HoldType = ""

SWEP.LerpFOV = 0

if SERVER then
	--resource.AddFile( "materials/weapons/bonnie_mask.vmt" )
else
	--SWEP.WepSelectIcon = surface.GetTextureID( "weapons/bonnie_mask" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType( "normal" )
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Bool", "BlockSwap" )
	self:NetworkVar( "Bool", "Active" )
	--self:NetworkVar( "Entity", "LastUser" )
end


function SWEP:Holster()

	-- чтоб нельзя было переключаться пока под защитой
	if self:GetActive() then
		return false
	end
	
	return true
end

function SWEP:PrimaryAttack()
	if self:GetActive() then return end
    self:SetNextIdle(0)

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:SetActive(true)
	
	timer.Create("CrucifixRemove" .. self:EntIndex(), 1.2, 1, function()
		if SERVER and IsValid(self) and IsValid(self:GetOwner()) then
			self:Remove()
		end
	end)
end

function SWEP:Defend()
	local owner = self:GetOwner()
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
	owner:EmitSound("weapons/crucifix_defend.mp3")
	
	local ed = EffectData()
		ed:SetOrigin( owner:GetPos() )
		ed:SetEntity( owner )
	util.Effect( "crucifix", ed, true, true )
	
	timer.Adjust("CrucifixRemove" .. self:EntIndex(), 1)
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:DrawWorldModel()
end

function SWEP:Think()
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end
end

hook.Add( "EntityTakeDamage", "crucifix_damage", function( target, dmginfo )
	if target:IsPlayer() then
		local wep = target:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_crucifix" then
			if not wep.GetActive or not wep:GetActive() then return end
			
			local hp = target:Health()
			local damage = dmginfo:GetDamage()
			
			-- ВОТ ТУТ ХУЙНЯ
			if damage >= hp then
			
				dmginfo:SetDamage(math.max(hp - 10, 0))
				wep:Defend()
				target:ScreenFade( SCREENFADE.IN, Color( 255, 210, 25, 25 ), .8, 0 )
				
				if dmginfo:IsFallDamage() then
					-- 
				elseif dmginfo:IsExplosionDamage() then
					target:SetDSP(1)
				end
			end
		end
	end
end )