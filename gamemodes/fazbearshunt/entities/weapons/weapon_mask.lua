
AddCSLuaFile()

SWEP.PrintName = "#weapon_bonniemask"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_bonmask.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_bonmask.mdl" )
SWEP.ViewModelFOV = 75
SWEP.UseHands = true

SWEP.Primary.ClipSize = 15
SWEP.Primary.DefaultClip = SWEP.Primary.ClipSize
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.HoldType = "slam"

SWEP.CurrentFOV = 0
SWEP.LerpFOV = 0

if SERVER then
	resource.AddFile( "materials/weapons/bonnie_mask.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/bonnie_mask" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()

	self:SetHoldType( self.HoldType )

end

function SWEP:SetupDataTables()

	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Bool", false, "BlockSwap" )
end


function SWEP:Holster()

	-- чтоб нельзя было переключаться пока невидимый
	if self:GetBlockSwap() then
		return false
	end
	
	return true

end

function SWEP:PrimaryAttack()
	if self:GetBlockSwap() then return end
    self:SetNextIdle(0)

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	
	self:GetOwner():DoAnimationEvent( ACT_GMOD_GESTURE_ITEM_PLACE )
	
	self:SetBlockSwap(true)
	
	timer.Simple(0.9, function()
		if IsValid(self) and self:GetOwner() then
			self.CurrentFOV = 35
			
			self:Invisivility(self:GetOwner())
		end
	end)
end

function SWEP:SecondaryAttack()
	if self:GetBlockSwap() then return end
	
	self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
	
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        local seq = vm:SelectWeightedSequence(ACT_VM_SECONDARYATTACK)
        local dur = vm:SequenceDuration(seq)

        self:SetNextIdle(CurTime() + dur)
		self:SetNextSecondaryFire(CurTime() + dur)
    end
end

function SWEP:Reload()
end

local colormod_intensity = 0
local colormod_target = 0

if CLIENT then
	hook.Add("RenderScreenspaceEffects", "weapon_bonniemask_blueish", function()
		colormod_intensity = Lerp(FrameTime() * 2, colormod_intensity, colormod_target)

		if colormod_intensity > 0.01 then
			local tab = {
				["$pp_colour_addr"] = 0,
				["$pp_colour_addg"] = .1 * colormod_intensity,
				["$pp_colour_addb"] = .2 * colormod_intensity,
				["$pp_colour_brightness"] = -0.1 * colormod_intensity,
				["$pp_colour_contrast"] = 1 - 0.4 * colormod_intensity,
				["$pp_colour_colour"] = 1 - 0.8 * colormod_intensity,
				["$pp_colour_mulr"] = 0,
				["$pp_colour_mulg"] = 0,
				["$pp_colour_mulb"] = 0.5 * colormod_intensity
			}
			DrawColorModify(tab)
		end
	end)
end

function SWEP:Invisivility(ply)
	--[[
	local wait = 15
	timer.Create("invisibility_ammo" .. ply:EntIndex(), wait / 100, 100, function()
		if IsValid(self) then
			self.Weapon:SetClip1( self.Weapon:Clip1() - 1 )
		end
	end)
	]]--
	if CLIENT then
		surface.PlaySound( "weapons/bonnie_mask_equip.wav" )
		colormod_target = 1
	end
	
	ply.invisible = true
	ply:SetRenderMode(RENDERMODE_TRANSALPHA)
	ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	ply:SetCustomCollisionCheck(true)
	ply:CollisionRulesChanged()
	ply:SetColor(Color(255, 255, 255, 0))
	ply:SetMaterial("models/null")
	ply:DrawShadow(false)

	for _, wep in ipairs(ply:GetWeapons()) do
		if IsValid(wep) then
			wep:SetNoDraw(true)
			wep:DrawShadow(false)
			wep:SetRenderMode(RENDERMODE_NONE)
		end
	end

	timer.Create("fh_invisibility_timer" .. ply:EntIndex(), 15, 1, function()
		--[[
			Я попытался вывести выключение инвиза в отдельную функцию SWEP:StopInvisibility(ply),
			но узнал что если допустим, ты умираешь, то эта функция свепа перестаёт существовать для тебя на клиенте
			и выдаёт ошибку.
		
		]]--
	
		if IsValid(ply) then
			ply:SetColor(Color(255, 255, 255, 255))
			ply:SetMaterial("")
			
			ply:DrawShadow(true)
			ply.invisible = false
			if CLIENT then
				surface.PlaySound( "weapons/bonnie_mask_end.wav" )
				colormod_target = 0
			end

			if IsValid(self) then
				if SERVER then
					self:SendWeaponAnim(ACT_VM_HOLSTER)
				end
				self.CurrentFOV = 0
			end
			
			timer.Simple(1.1, function()
				if SERVER and IsValid(ply) then
					ply:StripWeapon( "weapon_mask" )
				end
			end)

			for _, wep in ipairs(ply:GetWeapons()) do
				if IsValid(wep) then
					wep:SetNoDraw(false)
					wep:DrawShadow(true)
					wep:SetRenderMode(RENDERMODE_NORMAL)
				end
			end

			local function IsStuck(ent)
				if not IsValid(ent) then return false end
		
				local trace = util.TraceEntity({
					start = ent:GetPos(),
					endpos = ent:GetPos(),
					filter = ent,
					mask = MASK_SOLID
				}, ent)
		
				return trace.Hit
			end
			
			timer.Create("fh_gift_collision_reset" .. ply:EntIndex(), 0.5, 0, function()
				if IsValid(ply) and !IsStuck(ply) then
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					ply:SetCustomCollisionCheck(false)
					ply:CollisionRulesChanged()
				end
		
				if !IsValid(ply) or !IsStuck(ply) then
					timer.Remove("fh_gift_collision_reset" .. ply:EntIndex())
				end
			end)
			
		end
	end)
end

function SWEP:Think()
	self.LerpFOV = Lerp(FrameTime() * 5, self.LerpFOV, self.CurrentFOV)
	
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end
end

function SWEP:TranslateFOV( fov )
	return fov - self.LerpFOV
end

hook.Add("fh_createragdoll", "bonnie_mask_onragdoll", function(ply, rag)
	if ply.invisible then
		ent = ents.Create("prop_physics")
		ent:SetModel("models/weapons/w_bonmask.mdl")
		ent:SetPos( rag:GetPos() )
		ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ent:Spawn()
		
		rag:SetMaterial("")
	end
end)