
AddCSLuaFile()

SWEP.PrintName = "#weapon_killmask"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = Model( "models/fh/items/v_springbonnie_mask.mdl" )
SWEP.WorldModel = Model( "models/fh/items/w_springbonnie_mask_hand.mdl" )
SWEP.ViewModelFOV = 75
SWEP.UseHands = true
SWEP.DrawCrosshair = false

SWEP.Primary.ClipSize = 15
SWEP.Primary.DefaultClip = SWEP.Primary.ClipSize
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.HoldType = "slam"

if SERVER then
	--resource.AddFile( "materials/weapons/bonnie_mask.vmt" )
else
	--SWEP.WepSelectIcon = surface.GetTextureID( "weapons/bonnie_mask" )
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
	if self:GetBlockSwap() then
		return false
	end
	
	return true

end

function SWEP:PrimaryAttack()
	if CLIENT then return end
	if self:GetBlockSwap() then return end
    self:SetNextIdle(0)
	
	local animCount = team.NumPlayers(2701)
	
	if fh.GetActiveUsedKiller("pill_plushtrap") then
		animCount = math.max(animCount - 1, 1)
	end

	if animCount == 1 then
		self:GetOwner():SendLua('LocalPlayer():ChatPrint(language.GetPhrase("weapon_killmask.nearby"))')
		return
	end
	
	self:SendWeaponAnim(ACT_VM_RELEASE)
	
	self:GetOwner():DoAnimationEvent( ACT_GMOD_GESTURE_ITEM_PLACE )
	
	self:SetBlockSwap(true)
	
	timer.Simple(1.2, function()
		if IsValid(self) and IsValid(self.Owner) then
			self:SpringLock()
			self:CallOnClient("SpringLock")
		end
	end)
end


local dropWeaponry = {
	["weapon_crowbar"] = true,
	["weapon_pistol"] = true,
	["weapon_mask"] = true,
	["weapon_adrenaline"] = true,
--	["weapon_defibrillator"] = true,
	["weapon_fanta"] = true,
	["weapon_fh_medkit"] = true,
}

function SWEP:SpringLock()
	local ply = self.Owner
	
	ply:SetNW2Bool("KillerMaskEquiped", true)

	self:SetHoldType( "normal" )
	
	self:EmitSound("weapons/AudioEvent_K06_Status_Start.mp3")
	
	if CLIENT then
		surface.PlaySound("weapons/killermask_equip.wav")
		
		timer.Simple(8.5, function()
			if !IsValid(ply) or !ply:Alive() then return end
			ply:ScreenFade( SCREENFADE.OUT, Color( 255, 0, 0, 255 ), 0.1, 4 )
			util.ScreenShake( Vector(0, 0, 0), 2, 40, 1, 2 )
			timer.Simple(3.8, function()
				if !IsValid(ply) or !ply:Alive() then return end
				ply:ScreenFade( SCREENFADE.IN, Color( 255, 0, 0, 255 ), 5, 0.5 )
			end)
		end)
	end
	
	if SERVER then
		timer.Simple(8.5, function()
			if !IsValid(ply) or !ply:Alive() then return end
			local edata = EffectData()
			edata:SetOrigin(ply:EyePos())
			edata:SetEntity(ply)
			util.Effect("BloodImpact", edata, true, true)
			
			local rf = RecipientFilter()
			rf:AddAllPlayers()
			rf:RemovePlayer(ply)
			
			self:EmitSound("weapons/springlock.mp3", 65, 100, 0.2, CHAN_AUTO, 0, 1, rf)
			
			--ply:StripWeapon("weapon_killmask")
			
			ply:SetDSP(25)
			ply:Freeze(true)
			ply:SetNW2Bool("KillerObsessed", true)
			ply:SetGFreddyImmune(true)
			
			ply:AllowFlashlight(false)
		end)
	
		timer.Simple(11, function()
			if !IsValid(ply) or !ply:Alive() then return end
			for _, wep in ipairs( ply:GetWeapons() ) do
				if !dropWeaponry[wep:GetClass()] then continue end
				ply:DropWeapon( wep, nil, Vector(0,0,0) )
			end
			ply:StripWeapons()
			
			ply:SetSuppressPickupNotices(true)
			ply:Give("weapon_killer_axe")
			ply:SetSuppressPickupNotices(false)
		end)
	
		timer.Simple(13, function()
			if !IsValid(ply) or !ply:Alive() then return end
	
			ply:Freeze(false)
			ply:SetRunSpeed(475)
			ply:SetRunSpeed(475)
			ply:SetCrouchedWalkSpeed( 0.5 )
			ply:SetJumpBoostMultiplier(0.4)
			ply:AllowFlashlight(true)
		end)
	end
end

hook.Add( "PlayerCanPickupWeapon", "no_mask_puckup", function( ply, weapon )
    if ply:HasWeapon("weapon_killer_axe") then
		return false
	end
end )

function SWEP:SecondaryAttack()
	return
end

function SWEP:Reload()
	return
end

function SWEP:Think()
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_VM_IDLE)
        self:SetNextIdle(0)
    end
end

if SERVER then return end

local model = ClientsideModel( "models/fh/items/w_springbonnie_mask.mdl" )
model:SetNoDraw( true )

hook.Add("PostPlayerDraw", "fh_draw_killmask", function(ply)
	if not IsValid(ply) or not ply:Alive() then return end
	if not ply:GetNW2Bool("KillerMaskEquiped") then return end

	if not IsValid(model) then return end

	local boneID = ply:LookupBone("ValveBiped.Bip01_Head1")
	or ply:LookupBone("ValveBiped.forward")
	or ply:LookupBone("ValveBiped.Bip01_Neck1") 
	or ply:LookupBone("ValveBiped.Bip01_Spine4")
	or ply:LookupBone("ValveBiped.Bip01_Spine2")
	or ply:LookupBone("ValveBiped.Bip01_Spine1")
	or ply:LookupBone("ValveBiped.Bip01_Spine")
	or ply:LookupBone("ValveBiped.Bip01_Pelvis")
	
	if not boneID then return end

	local bonePos, boneAng = ply:GetBonePosition(boneID)
	if not bonePos or not boneAng then return end

	local pos = bonePos
	local ang = boneAng

	ang:RotateAroundAxis(ang:Right(), -90)
	ang:RotateAroundAxis(ang:Up(), -90)

	pos = pos + ang:Forward() * 0 + ang:Up() * -5 + ang:Right() * 0

	model:SetModelScale(1, 0)
	model:SetRenderOrigin(pos)
	model:SetRenderAngles(ang)
	model:SetupBones()
	model:DrawModel()
	model:SetRenderOrigin()
	model:SetRenderAngles()
end)

function SWEP:DrawWorldModel( flags )
	local ply = self.Owner
	if !ply:GetNW2Bool("KillerMaskEquiped") then
		self:DrawModel( flags )
	end
end