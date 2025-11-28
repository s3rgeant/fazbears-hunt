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

SWEP.ViewModel = "models/ufmp/fnaf2/toys/vm/themangle.mdl"

SWEP.JumpHold = 0.3
SWEP.LandHold = 0.4

function SWEP:SetupAnimations()
	self:AddAnimation("attack")
end

function SWEP:HandleGroundAnim()
	local ply = self.Owner
	
	return ply:GetNWBool("_MangleHooked")
end

local lastmangle_CL_viewoffset = nil
function SWEP:CalcViewModelView( vm, oldpos, oldangles, pos, angles )
	local ply = self.Owner
	if !lastmangle_CL_viewoffset then
		lastmangle_CL_viewoffset = ply:GetCurrentViewOffset()
	end
	
	local plypos = ply:GetPos()
	
	lastmangle_CL_viewoffset = LerpVector(FrameTime() * 10, lastmangle_CL_viewoffset, ply:GetCurrentViewOffset())

	return plypos + lastmangle_CL_viewoffset, angles
end