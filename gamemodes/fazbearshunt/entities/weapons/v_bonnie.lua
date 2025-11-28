SWEP.PrintName = "Bonnie SWEP"

SWEP.Base = "v_base"

if CLIENT then
	local vfov = CreateClientConVar('cl_fov_bonnie', 95, true, false, 'Fov of Bonnie')
	SWEP.ViewModelFOV = vfov:GetFloat() or 95
    
    cvars.AddChangeCallback("cl_fov_bonnie", function(name, old_value, new_value)
		local wep = LocalPlayer():GetActiveWeapon()
		if IsValid(wep) and string.StartWith(wep:GetClass(), "v_") then
			wep.ViewModelFOV = tonumber(new_value) or 95
		end
	end)
end

SWEP.ViewModel = "models/speps/vm/oldbonnie.mdl"
SWEP.m_WeaponDeploySpeed = 0.7

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("deploy")
	self:AddAnimation("draw")
	self:AddAnimation("attack")
end

if CLIENT then
    local crouchFactor = 0

    function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
        local ply = self.Owner
        if not IsValid(ply) then return EyePos, EyeAng end
		
        local target = (ply:Crouching() and ply:OnGround()) and 1 or 0
        crouchFactor = Lerp(FrameTime() * 5, crouchFactor, target)

        local newPitch = Lerp(crouchFactor, EyeAng.p, 0)
        EyeAng.p = newPitch

        return EyePos, EyeAng
    end
end