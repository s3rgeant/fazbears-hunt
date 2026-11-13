SWEP.PrintName = "Toy Chica SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_toychica", "Toy Chica", 100)
end

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(4,0,-6)

SWEP.ViewModel = "models/ufmp/fnaf2/toys/vm/toychica.mdl"

function SWEP:SetupAnimations()
	self:AddAnimation("draw")
	self:AddAnimation("attack")
	self:AddAnimation("interrupt")
end

if CLIENT then
    local crouchFactor = 0

    function SWEP:CalcViewModelView(ViewModel, OldEyePos, OldEyeAng, EyePos, EyeAng)
        local ply = self:GetOwner()
        local ent = ply:GetPillCostume()
        if not IsValid(ply) then return EyePos, EyeAng end
        if not IsValid(ent) then return EyePos, EyeAng end
		
        local target = (self:GetSequenceName(self:GetSequence()):match("hold") == "hold") and 1 or 0
        crouchFactor = Lerp(FrameTime() * 5, crouchFactor, target)

        local newPitch = Lerp(crouchFactor, EyeAng.p, 15)
        EyeAng.p = newPitch
		
		local pillAngleY = ent:GetAngles().y
		
		while EyeAng.y > 180 do
			EyeAng.y = EyeAng.y - 360
		end
		while EyeAng.y < -180 do
			EyeAng.y = EyeAng.y + 360
		end
		
		while pillAngleY > 180 do
			pillAngleY = pillAngleY - 360
		end
		while pillAngleY < -180 do
			pillAngleY = pillAngleY + 360
		end

        local newYaw = Lerp(crouchFactor, EyeAng.y, pillAngleY)
        EyeAng.y = newYaw

        return EyePos, EyeAng
    end
end