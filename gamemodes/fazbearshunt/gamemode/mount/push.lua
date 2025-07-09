if CLIENT then return end

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

local PLAYER = FindMetaTable("Player")

function PLAYER:SetPushImmune(state)
	if not IsValid(self) then return end
	self._PushImmune = state and true or false
end

function PLAYER:IsPushImmune()
	return self._PushImmune == true
end

function PLAYER:SetPushBlocked(state)
	if not IsValid(self) then return end
	self._PushBlocked = state and true or false
end

function PLAYER:IsPushBlocked()
	return self._PushBlocked == true
end

hook.Add("KeyPress", "PushInteraction", function(ply, key)
	if ply:IsPushBlocked() then return end

	if key == IN_USE and not push[ply:UserID()] then
		local ent = ply:GetEyeTrace().Entity
		if IsValid(ply) and IsValid(ent) then
			if ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR and ent:IsPlayer() and not ent.lobbyFreeze and not ent:IsPushImmune() then
				if ply:GetPos():Distance(ent:GetPos()) <= 100 then
					if ent:Alive() and ent:GetMoveType() == MOVETYPE_WALK and not ent:IsFlagSet(FL_FROZEN) then
						ply:EmitSound(PushSound[math.random(#PushSound)], 100, 100)
						local velAng = ply:EyeAngles():Forward()
						velAng.z = math.Clamp(velAng.z, -0.1, 0.5)

						ent:SetVelocity(velAng * 500)
						ent:ViewPunch(Angle(math.random(-25, 25), math.random(-25, 25), 0))
						push[ply:UserID()] = true
						timer.Simple(0.15, function()
							push[ply:UserID()] = false
						end)
					end
				end
			end
		end
	end
end)
