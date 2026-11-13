SWEP.PrintName = "Fox 4 SWEP"

SWEP.Base = "v_base"

if CLIENT then
	CreateVBaseFovHandler(SWEP, "cl_fov_fox4", "Fox4", 100)
end

SWEP.HandleMinViewModel = true
SWEP.CalcMinimalViewModelView = Vector(6,0,-10)

SWEP.ViewModel = "models/fh/animatronics/vm/fox4.mdl"