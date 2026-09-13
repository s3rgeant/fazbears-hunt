function EFFECT:Init( data )
    local ply = data:GetEntity()

    if not IsValid(ply) then return end

    local Pos = ply:GetPos()
    local emitter = ParticleEmitter( Pos )
    
    local plyVel = ply:GetVelocity()
    
    local boneCount = ply:GetBoneCount() or 0

    for b = 0, boneCount - 1 do
        local boneName = ply:GetBoneName(b)
        
        if boneName and not string.find(string.lower(boneName), "finger") then
            local bonePos
            local boneMatrix = ply:GetBoneMatrix(b)
            
            if boneMatrix then
                bonePos = boneMatrix:GetTranslation()
            else
                bonePos = ply:GetBonePosition(b)
            end

            if bonePos then
                for i = 1, 20 do
                    local spawnPos = bonePos + (VectorRand() * 3)

                    local p = emitter:Add("particles/masked", spawnPos)
                    
                    if p then
                        local particleVel
						
                        particleVel = (plyVel * math.Rand(.9, 1.1)) + (VectorRand() * 25)

                        p:SetVelocity(particleVel)
                        p:SetGravity(Vector(0, 0, -20)) 
                        p:SetAirResistance(40)
                        
                        p:SetDieTime(math.Rand(0.8, 1.5))
                        
                        p:SetStartAlpha(240)
                        p:SetEndAlpha(0)
                        
                        local size = math.Rand(2, 1.5)
                        p:SetStartSize(size)
                        p:SetEndSize(size * .1)
                        
                        p:SetRoll(math.Rand(0, 360))
                        p:SetRollDelta(math.Rand(-5, 5))
                        
                        p:SetColor(255, 255, 255)
                        
                        p:SetCollide(false)
                        p:SetLighting(true)
                    end
                end
            end
        end
    end

    emitter:Finish()
end

function EFFECT:Think()
    self:NextThink( CurTime() )
    return true
end

function EFFECT:Render()
end