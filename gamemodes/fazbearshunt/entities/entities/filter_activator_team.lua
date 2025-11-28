AddCSLuaFile()

ENT.Type = "filter"

function ENT:Initialize()
    self.Lists = {}
end

function ENT:KeyValue(key, value)
    key = string.lower(key)
    if key == "filterteam" then
        self.FilterTeam = tonumber(value)
    elseif key == "Negated" or key == "filtermode" then
        self.Negated = tobool(value)
    end
end

function ENT:AttachToEntity(ent)
    ent:SetSaveValue("m_hFilter", self)
    self.Lists[ent] = {}
end

function ENT:PassesFilter(trigger, ent)
    if self.FilterTeam then
        if not ent:IsPlayer() then return false end

        local allow = false
        if self.FilterTeam == 2 and ent.IsSurvivor and ent:IsSurvivor() then
            allow = true
        elseif self.FilterTeam == 3 and ent.IsAnimatronic and ent:IsAnimatronic() then
            allow = true
        end

        if self.Negated then
            return not allow
        else
            return allow
        end
    end

    if self.Lists[trigger] and self.Lists[trigger][ent] ~= nil then
        return not self.Lists[trigger][ent]
    end

    return true
end