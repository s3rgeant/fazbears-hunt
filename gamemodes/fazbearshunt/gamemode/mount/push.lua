if (CLIENT) then return end

local PushSound = {
	"physics/body/body_medium_impact_hard1.wav",
	"physics/body/body_medium_impact_hard2.wav",
	"physics/body/body_medium_impact_hard3.wav",
	"physics/body/body_medium_impact_hard5.wav",
	"physics/body/body_medium_impact_hard6.wav",
	"physics/body/body_medium_impact_soft5.wav",
	"physics/body/body_medium_impact_soft6.wav",
	"physics/body/body_medium_impact_soft7.wav",
}

local push = {}
	
hook.Add( "KeyPress", "ussy ussy ur a pussy", function( ply, key )
if key == IN_USE and !(push[ply:UserID()]) then
local ent = ply:GetEyeTrace().Entity
	if ply and ply:IsValid() and ent and ent:IsValid() then
			if ply:IsPlayer() and ply:Team() != TEAM_SPECTATOR and ent:IsPlayer() then
				if ply:GetPos():Distance( ent:GetPos() ) <= 100 then
					if ent:Alive() and ent:GetMoveType() == MOVETYPE_WALK then
						ply:EmitSound( PushSound[math.random(#PushSound)], 100, 100 )
						local velAng = ply:EyeAngles():Forward()
						ent:SetVelocity( velAng * 500 )
						ent:ViewPunch( Angle( math.random( -30, 30 ), math.random( -30, 30 ), 0 ) )
						push[ply:UserID()] = true
						timer.Simple( 0.1, function() push[ply:UserID()] = false end )
					end	
				end
			end
		end	
	end
end)
//print("This server is running Push Mod by Mr Ibizza/Renard/Jordie.")