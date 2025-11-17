// Yeeted that from Mighty Foot Engaged :^)

function EFFECT:Init( data )

    local Pos = data:GetOrigin()
	local Norm = data:GetNormal()
	local Mag = data:GetMagnitude()
	local vOffset = data:GetOrigin()
	local emitter = ParticleEmitter( vOffset )
    local SurfaceColor = render.GetSurfaceColor( Pos - Norm * 16, Pos - Norm * 16 - Vector(0,0,32) ) * 255
	
	SurfaceColor.r = math.Clamp( SurfaceColor.r + 100, 0, 255 )
	SurfaceColor.g = math.Clamp( SurfaceColor.g + 100, 0, 255 )
	SurfaceColor.b = math.Clamp( SurfaceColor.b + 100, 0, 255 )

	for i = 1,10 do
		local particle = emitter:Add( "particle/particle_smokegrenade", Pos - Norm * 8 + (Vector(math.Rand(-Norm.y, Norm.y), math.Rand(-Norm.x, Norm.x), Norm.z) * 20) )
		debugoverlay.Cross(particle:GetPos(), 16, 2)
		particle:SetVelocity( -Norm * Mag + VectorRand() * 10)
		particle:SetAirResistance( 150 )
		particle:SetGravity( Vector(0, 0, 0) )
		particle:SetDieTime( math.Rand( 1, 2 ) )
		particle:SetStartAlpha( math.Rand( 100, 150 ) )
		particle:SetEndAlpha( 0 )
		particle:SetStartSize( math.Rand( 10, 15 ) )
		particle:SetEndSize( math.Rand( 20, 30 ) )
		particle:SetRoll( math.Rand( 180, 480 ) )
		particle:SetRollDelta( math.Rand( -1, 1 ) )
		particle:SetColor( SurfaceColor.r, SurfaceColor.g, SurfaceColor.b )
		particle:SetLighting(true)
		particle:SetCollide(true)
		particle:SetBounce(0.45)
	end

	emitter:Finish()
end

function EFFECT:Think()
	return false
end


function EFFECT:Render()
end