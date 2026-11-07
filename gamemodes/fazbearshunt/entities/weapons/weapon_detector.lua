
AddCSLuaFile()

SWEP.PrintName = "#weapon_detector"
SWEP.Purpose = "#info_detector"

SWEP.Slot = 3
SWEP.SlotPos = 3

SWEP.Spawnable = true

SWEP.Gifted = true

SWEP.ViewModel = Model( "models/fh/weapons/c_detector.mdl" )
SWEP.WorldModel = Model( "models/fh/weapons/w_detector.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.CalcMinimalViewModelView = Vector(8,0,-4)

SWEP.HoldType = "slam"

if SERVER then
	resource.AddFile( "materials/weapons/detector.vmt" )
else
	SWEP.WepSelectIcon = surface.GetTextureID( "weapons/detector" )
	SWEP.BounceWeaponIcon = false
end

function SWEP:Initialize()
	self:SetHoldType( self.HoldType )
end

function SWEP:SetupDataTables()

	self:NetworkVar( "Float", 1, "NextIdle" )
	self:NetworkVar( "Bool", "BlockSwap" )
	self:NetworkVar( "Bool", "Active" )
	self:NetworkVar( "Entity", "LastUser" )
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
	
	if not self:IsPlaceable() then return end
	
    self:SetNextIdle(CurTime() + 1.2)
	
	local owner = self:GetOwner()

	self:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH)
	
	self:SetBlockSwap(true)
	
	local placed = false
	
	timer.Simple(0.2, function()
		if not IsValid(self) then return end
		
		if self:IsPlaceable() then
			self:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH2)
			self:AttachDetector()
			placed = true
		else
			self:SetNextIdle(CurTime())
		end
	end)
	
	timer.Simple(0.4, function()
		if not IsValid(self) then return end
		if not placed then self:SetBlockSwap(false) return end
		self:SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
		
		if SERVER and self:Ammo1() <= 1 then
			self:Remove()
		end
	end)
	
	timer.Simple(1.2, function()
		if not IsValid(self) then return end
		if not placed then return end
		
		self:SetBlockSwap(false)
	end)
end

function SWEP:Reload()
end

function SWEP:SecondaryAttack()
end

function SWEP:IsPlaceable()
	local ply = self:GetOwner()

	local ignore = {ply}
	local spos = ply:GetShootPos()
	local epos = spos + ply:GetAimVector() * 80
	local tr = util.TraceLine({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID})
	
	return tr.HitWorld
end

function SWEP:AttachDetector()
	if CLIENT then return end

	local ply = self:GetOwner()

	local ignore = {ply}
	local spos = ply:GetShootPos()
	local epos = spos + ply:GetAimVector() * 80
	local tr = util.TraceLine({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID})
	
	if tr.HitWorld then
		local mine = ents.Create("detector")
		if IsValid(mine) then
	
			local tr_ent = util.TraceEntity({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID}, mine)
	
			if tr_ent.HitWorld then
		
				local ang = tr_ent.HitNormal:Angle()
				ang.p = ang.p + 90
		
				mine:SetPos(tr_ent.HitPos + (tr_ent.HitNormal * 3))
				mine:SetAngles(ang)
				mine:SetOwner(ply)
				mine:Spawn()
				return
			end
		end
		mine:Remove()
	end
end

function SWEP:Think()
    if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
        self:SendWeaponAnim(ACT_SLAM_TRIPMINE_IDLE)
        self:SetNextIdle(0)
    end
end