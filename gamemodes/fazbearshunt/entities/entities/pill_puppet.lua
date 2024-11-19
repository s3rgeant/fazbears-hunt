ENT.Base = "base_anim"
ENT.Type = "ai"
ENT.AutomaticFrameAdvance	= true

function ENT:Initialize()
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    self:Draw()
end