function EFFECT:Init( data )

    local Pos = data:GetOrigin()
	local Norm = data:GetNormal()
	local ply = data:GetEntity()
	local Mag = data:GetMagnitude()
	local emitter = ParticleEmitter( Pos )

	for i = 1, 160 do
		local spawnPos = Pos + VectorRand() * math.Rand(0, 15) + Vector(0, 0, 40)
		local p = emitter:Add("particles/crucifix", spawnPos)
		local vel = VectorRand() * math.Rand(200, 250) + Vector(0, 0, math.Rand(100, 160))
		p:SetVelocity(vel + ply:GetVelocity())
		p:SetGravity(Vector(0, 0, -300))
		p:SetAirResistance(25)
		p:SetDieTime(math.Rand(.6, 2.5))
		p:SetStartAlpha(255)
		p:SetEndAlpha(0)
		local size = math.Rand(1, 2)
		p:SetStartSize(size)
		p:SetEndSize(size * 0.7)
		p:SetRoll(math.Rand(0, 360))
		p:SetRollDelta(math.Rand(-180, 180))
		p:SetColor(255, 255, 255)
		p:SetCollide(true)
		p:SetBounce(0.25)
		p:SetLighting(false)
	end
	
	local light = DynamicLight(ply:EntIndex())
	if light then
		light.pos = ply:LocalToWorld(ply:OBBCenter())
		light.r = 255
		light.g = 210
		light.b = 0
		light.brightness = 2
		light.Decay = 100
		light.Size = 256
		light.DieTime = CurTime() + 2
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end


function EFFECT:Render()
end