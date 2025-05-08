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
	
hook.Add("KeyPress", "ussy ussy ur a pussy", function(ply, key)
    if key == IN_USE and not push[ply:UserID()] then
        local ent = ply:GetEyeTrace().Entity
        if ply and IsValid(ply) and ent and IsValid(ent) then
            if ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR and not ent.lobbyFreeze then
                if ply:GetPos():Distance(ent:GetPos()) <= 100 then
                    if ent:IsPlayer() and ent:Alive() and ent:GetMoveType() == MOVETYPE_WALK and not ent:IsFlagSet(FL_FROZEN) then
                        ply:EmitSound(PushSound[math.random(#PushSound)], 100, 100)
                        local velAng = ply:EyeAngles():Forward()
                        velAng.z = math.Clamp(velAng.z, -0.1, 0.5)
						
                        ent:SetVelocity(velAng * 500)
                        ent:ViewPunch(Angle(math.random(-25, 25), math.random(-25, 25), 0))
                        push[ply:UserID()] = true
                        timer.Simple(0.15, function() push[ply:UserID()] = false end)
                    end    
                end
            end
        end    
    end
end)
//print("This server is running Push Mod by Mr Ibizza/Renard/Jordie.")