AddCSLuaFile()
ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

function ENT:Initialize()
    self:SetModel("models/humans/group01/male_mori_helper.mdl")
	self:SetAngles(Angle(0, 0, 0))
	self:ResetSequence("test01")
	self:SetCycle(0)
	self:SetNoDraw(true)
	self:SetPlaybackRate(1)
	
	if CLIENT then
        local owner = self:GetOwner()
        if not IsValid(owner) then return end
        if owner ~= LocalPlayer() then return end
		
        self.EndTime = CurTime() + 5

        local attachIndex = self:LookupAttachment("camera")
        if not attachIndex or attachIndex <= 0 then
            print("[MORI] Аттачмент 'camera' не найден у mori_helper.")
            return
        end

        self.MoriAttachIndex = attachIndex
        self.MoriViewHook = "fh_mori_camera_view_" .. self:EntIndex()

        hook.Add("CalcView", self.MoriViewHook, function(ply, pos, ang, fov)
            if ply ~= LocalPlayer() then return end
            if not IsValid(self) then
                hook.Remove("CalcView", self.MoriViewHook)
                return
            end

            local att = self:GetAttachment(self.MoriAttachIndex)
            if not att then return end

            return {
                origin = att.Pos,
                angles = att.Ang,
                fov = fov
            }
        end)
	end
end

function ENT:Think()
	if CLIENT then
        local owner = self:GetOwner()
        if not IsValid(self) or not IsValid(owner) or owner ~= LocalPlayer() then
            if self.MoriViewHook then
                hook.Remove("CalcView", self.MoriViewHook)
                self.MoriViewHook = nil
            end
            return
        end

        if self.EndTime and CurTime() > self.EndTime then
            if self.MoriViewHook then
                hook.Remove("CalcView", self.MoriViewHook)
                self.MoriViewHook = nil
            end
        end
	end

	self:NextThink( CurTime() )

	return true
end

if CLIENT then
    function ENT:OnRemove()
        if self.MoriViewHook then
            hook.Remove("CalcView", self.MoriViewHook)
            self.MoriViewHook = nil
        end
    end
end