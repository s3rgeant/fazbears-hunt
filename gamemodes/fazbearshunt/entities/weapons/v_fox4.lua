SWEP.PrintName = "Fox 4 SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_fox4', 100, true, false, 'Fov of Fox 4')
	SWEP.ViewModelFOV = vfov:GetFloat() or 100
    
    cvars.AddChangeCallback("cl_fov_fox4", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 100
		end
    end)

end

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(6,0,-10)

SWEP.ViewModel = "models/fh/animatronics/vm/fox4.mdl"