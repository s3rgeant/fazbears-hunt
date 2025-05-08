--[[

	создавая карту в хаммере, ты можешь создать энтити fh_win_camera (даже не смотря на то, что такие
	энтити не существует в самом хаммере), и он (пока нельзя создавать больше одного) будет использоваться
	как камера, которая будет показывать победный танец спрингтрапа.
	:)

]]
AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "point"

function ENT:Initialize()
    if SERVER then
        self.Origin = self:GetPos()

        local backDir = -self:GetForward()
        self.Radius = 150
        local startOffset = backDir * self.Radius

        self.CenterPos = self.Origin
        self:SetPos(self.CenterPos + startOffset)

        self.BaseDir = (self:GetPos() - self.CenterPos):Angle()

        self.CurrentAngleOffset = 0
        self.MaxAngle = 30
        self.Direction = 1
        self.Speed = 10

        self.LerpPos = self:GetPos()
        self.LerpAng = self:GetAngles()
	end
end

function ENT:Think()
    if SERVER then
        local dt = FrameTime()
        self.CurrentAngleOffset = self.CurrentAngleOffset + self.Direction * self.Speed * dt

        if math.abs(self.CurrentAngleOffset) > self.MaxAngle then
            self.CurrentAngleOffset = math.Clamp(self.CurrentAngleOffset, -self.MaxAngle, self.MaxAngle)
            self.Direction = -self.Direction
        end

        -- Новая целевая позиция по дуге
        local newAngle = self.BaseDir + Angle(0, self.CurrentAngleOffset, 0)
        local targetPos = self.CenterPos + newAngle:Forward() * self.Radius

        -- Направление к центру
        local targetDir = (self.CenterPos - targetPos):GetNormalized()
        local targetAng = targetDir:Angle()

        -- Плавное перемещение и поворот
        local lerpSpeedPos = 5 -- чем больше, тем быстрее
        local lerpSpeedAng = 5

        self.LerpPos = LerpVector(lerpSpeedPos * dt, self.LerpPos, targetPos)
        self.LerpAng = LerpAngle(lerpSpeedAng * dt, self.LerpAng, targetAng)

        self:SetPos(self.LerpPos)
        self:SetAngles(self.LerpAng)

        self:NextThink(CurTime())
        return true
    end
end