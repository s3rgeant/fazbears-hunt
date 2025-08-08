AddCSLuaFile()
ENT.Type = "anim"

function ENT:Initialize()
    self:AddCallback("BuildBonePositions", self.BoneItUp)

    if SERVER then
        self:AddEffects(bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL)) --fastcull seems to fix laggy bullshit garbage
    end

    self:GetParent():SetSubMaterial(0, "models/null")
end

local function isFingerBone(name)
    return name and (
        name:find("Finger") or
        name:find("finger") or
        name:find("ValveBiped.Bip01_L_Finger") or
        name:find("ValveBiped.Bip01_R_Finger")
    )
end

function ENT:BoneItUp(boneCount)
    for i = 0, boneCount - 1 do
        local boneName = self:GetBoneName(i)
        if not isFingerBone(boneName) then continue end

        local matrix = Matrix()
        self:SetBoneMatrix(i, matrix)
    end
end