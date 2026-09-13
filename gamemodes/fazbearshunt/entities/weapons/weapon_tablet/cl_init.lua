include("shared.lua")
include("cl_screen.lua")

SWEP.BobScale = 0.3
SWEP.SwayScale = 0.2

SWEP.CalcMinimalViewModelView = Vector(4,0,-8)
SWEP.Gifted = true

local minVec = Vector(4,0,-8)
function SWEP:CalcMinimalViewModelView()
	local seq = self:GetSequence()
	local focus = (self:GetSequenceName(seq):match("look_in") == "look_in")
	local ft = FrameTime() * 3

	minVec[1] = Lerp(ft, minVec[1], focus and 0 or 4)
	minVec[2] = Lerp(ft, minVec[2], focus and 0 or 0)
	minVec[3] = Lerp(ft, minVec[3], focus and 0 or -6)
	return minVec
end