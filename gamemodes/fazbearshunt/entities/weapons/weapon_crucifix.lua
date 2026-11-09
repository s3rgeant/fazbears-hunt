
AddCSLuaFile()

SWEP.PrintName = "#weapon_crucifix"
SWEP.Purpose = "#info_crucifix"

SWEP.Slot = 2
SWEP.SlotPos = 0

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_crucifix.mdl" )
--SWEP.WorldModel = Model( "models/weapons/w_bonmask.mdl" )
SWEP.ViewModelFOV = 80
SWEP.UseHands = true

SWEP.Gifted = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.LerpFOV = 0

if SERVER then
	resource.AddFile( "materials/weapons/crucifix.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/crucifix" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType( "normal" )
end

function SWEP:SetupDataTables()
	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Bool", "BlockSwap" )
	self:NetworkVar( "Bool", "Active" )
	self:NetworkVar( "Bool", "Defended" )
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
	if self:GetDefended() then return end
	
	local owner = self:GetOwner()
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
	owner:GodEnable()
	owner:GodEffects()
	self:SetDefended(true)
	
	timer.Simple(2, function()
		if IsValid(owner) then
			owner:GodDisable()
		end
	end)
	
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
				
				local attacker = dmginfo:GetAttacker()
				local inflictor = dmginfo:GetInflictor()
				
				-- ОТКИД ПРОПА ОТ ИГРОКА
				if IsValid(inflictor) and not inflictor:IsPlayer() then 
					local phys = inflictor:GetPhysicsObject()
					
					if IsValid(phys) then
						phys:SetVelocity(-phys:GetVelocity())
					end
				end
				
				if IsValid(attacker) and attacker:IsPlayer() then 
					local dir = (attacker:GetPos() - target:GetPos())
					dir:Normalize()
					dir.z = 0
					attacker:SetVelocity(dir * 1500)
					
					local v = attacker
			
					local fx = EffectData()
					fx:SetOrigin(v:GetPos())
					fx:SetStart(v:GetPos())
					fx:SetMagnitude(10)
					fx:SetEntity(v)
					util.Effect("teslaHitBoxes",fx, true, true)
			
					attacker.SpeedSlowEnd = CurTime() + 1
					
					local ent = attacker:GetPillCostume()
					
					if IsValid(ent) then
						ent:Func("crucifixStun")
					end
					
					target:ScreenFade( SCREENFADE.IN, Color( 255, 210, 25, 25 ), .8, 0 )
				end
				
				if dmginfo:IsFallDamage() then
					-- 
				elseif dmginfo:IsDamageType(DMG_DROWN) then
					target:SetHealth(target:Health() + 35)
				elseif dmginfo:IsExplosionDamage() then
					target:SetDSP(1)
				end
			end
		end
	end
end )

hook.Add("FH_PlayerShouldJumpscare", "crucifix_save", function(ply, ent, target)
	if target:IsPlayer() then
		local wep = target:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_crucifix" then
			if not wep.GetActive or not wep:GetActive() then return end
		
			local dir = (ply:GetPos() - target:GetPos())
			dir:Normalize()
			dir.z = 0
			ply:SetVelocity(dir * 1500)
			
			ply:SetSpeedSlowdown(1.5)
			
			wep:Defend()
			target:ScreenFade( SCREENFADE.IN, Color( 255, 210, 25, 25 ), .8, 0 )
			ply:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 50 ), .8, 0 )
			
			ent:Func("crucifixStun")
			return false
		end
	end
end)

local meta = FindMetaTable("Player")

local sparkSounds = {
	"ambient/energy/spark1.wav",
	"ambient/energy/spark2.wav",
	"ambient/energy/spark3.wav",
	"ambient/energy/spark4.wav",
}

if meta then
	function meta:GodEffects()
		local timerName = self:EntIndex() .. "_FHGodEffects"
		timer.Create(timerName, .5, 0, function()
			if not IsValid(self) then timer.Remove(timerName) end
			if not self:HasGodMode() then timer.Remove(timerName) end
			
			self:EmitSound("ambient/energy/spark"..math.random(4)..".wav")
			
			local pos = self:GetPos()
			
			local effect2 = EffectData()
			effect2:SetOrigin(pos)
			effect2:SetStart(pos)
			effect2:SetMagnitude(1)
			effect2:SetEntity(self)
			util.Effect("teslaHitBoxes", effect2)
		end)
	end
end

local meta = FindMetaTable("Entity")

if meta then
	function meta:GodEffects(repeats)
		local timerName = self:EntIndex() .. "_FHGodEffects"
		timer.Create(timerName, .5, repeats, function()
			if not IsValid(self) then timer.Remove(timerName) end
			
			self:EmitSound("ambient/energy/spark"..math.random(4)..".wav")
			
			local pos = self:GetPos()
			
			local effect2 = EffectData()
			effect2:SetOrigin(pos)
			effect2:SetStart(pos)
			effect2:SetMagnitude(5)
			effect2:SetEntity(self)
			util.Effect("teslaHitBoxes", effect2)
		end)
	end
end