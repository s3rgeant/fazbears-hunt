SWEP.PrintName = "Mangle SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_mangle', 95, true, false, 'Fov of Mangle')
	SWEP.ViewModelFOV = vfov:GetFloat() or 95
    
    cvars.AddChangeCallback("cl_fov_mangle", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 95
		end
    end)
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