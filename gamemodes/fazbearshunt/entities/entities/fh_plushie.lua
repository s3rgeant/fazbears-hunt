DEFINE_BASECLASS("base_anim")

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Freddy Plush"
ENT.Author = "sergeant"

if SERVER then
    AddCSLuaFile()

    function ENT:Initialize()
		self:SetModel("models/RobGamings/ChuizaProductions/FNAF1/Plush/FreddyPlush.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 32))
		self:SetSkin(2)
		self:DrawShadow(false)
		
		self:SetAngles(Angle(0, math.random(0,359),0))
    end
end

if CLIENT then
	local drawMe = false
	
	function fh_cl_draw_plushies()
		drawMe = true
	end
	
	function fh_cl_dontdraw_plushies()
		drawMe = false
	end
	
    function ENT:Draw()
		if drawMe then
			self:DrawModel() 
		end
    end

    function ENT:Initialize()
		hook.Add("PreDrawHalos", "fh_plushie_halo" .. self:EntIndex(), function()
			if not IsValid(self) then 
				hook.Remove("PreDrawHalos", "fh_plushie_halo" .. self:EntIndex() )
				return
			end
			
			local ply = LocalPlayer()
			if !IsValid(ply) or !drawMe then return end
	
			local viewDir = ply:GetAimVector()
			local eyePos = ply:EyePos()
	
			local targets = {}

			local toEnt = (self:GetPos() - eyePos)
			local distSqr = toEnt:LengthSqr()
			if distSqr > (200 * 100) then return end

			local dirToEnt = toEnt:GetNormalized()
			local dot = viewDir:Dot(dirToEnt)

			if dot >= 0.9848 then
				table.insert(targets, self)
			end
	
			if #targets > 0 then
				halo.Add(targets, Color(255, 255, 255), 1, 1, 1, true, false)
			end
		end)
    end
	
	function ENT:OnRemove()
		hook.Remove("PreDrawHalos", "fh_plushie_halo" .. self:EntIndex())
	end
end