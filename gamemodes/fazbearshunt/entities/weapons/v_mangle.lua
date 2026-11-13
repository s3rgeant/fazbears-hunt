SWEP.PrintName = "Mangle SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_mangle", "Mangle", 95)
end

SWEP.ViewModel = "models/fh/animatronics/ufmp/fnaf2/vm/themangle.mdl"

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(2,0,-10)

SWEP.JumpHold = 0.3
SWEP.LandHold = 0.4

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("attack")
	self:AddAnimation("bite")
end

function SWEP:HandleGroundAnim()
	local ply = self:GetOwner()
	
	return ply:GetNWBool("_MangleHooked")
end

-- не, не нахуй. и так нормально выглядит.
--function SWEP:GetViewModelPosition( pos, ang )