SWEP.PrintName = "Freddy SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_freddy", "Freddy", 100)
end

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-8)

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("attack")
	self:AddAnimation("holster")
	self:AddAnimation("draw")
end

-- крутотень
--[[
function SWEP:GetViewModelPosition( pos, ang )
	local ply = self:GetOwner()
	
	local right = ply:EyeAngles():Right()
	
	local vel = ply:GetVelocity()
	local moveY = right:Dot(vel)
	
	ang = ang + Angle(0,moveY*-0.1,0)
	return pos, ang
end
]]--