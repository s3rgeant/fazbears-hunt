SWEP.PrintName = "Endo SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_endo", "Endo", 100)
end

SWEP.ViewModel = "models/fh/animatronics/thudner_mountroid/vm/endo02.mdl"
SWEP.m_WeaponDeploySpeed = 1
SWEP.LandHold = 0.2

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-6)

function SWEP:SetupAnimations()
	self:AddAnimation("scare")
	self:AddAnimation("attack")
	self:AddAnimation("holster")
	self:AddAnimation("draw")
end

if CLIENT then
    local crouchFactor = 0

    function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
        local ply = self.Owner
        if not IsValid(ply) then return EyePos, EyeAng end
		
        local target = (self:GetSequenceName(self:GetSequence()):match("crouch") == "crouch") and 1 or 0
        crouchFactor = Lerp(FrameTime() * 5, crouchFactor, target)

        local newPitch = Lerp(crouchFactor, EyeAng.p, 0)
        EyeAng.p = newPitch

        return EyePos, EyeAng
    end
end