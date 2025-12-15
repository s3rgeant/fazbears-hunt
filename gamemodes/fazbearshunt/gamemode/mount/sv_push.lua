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

local PushSound_pills = {
	"physics/metal/metal_solid_impact_hard1.wav",
	"physics/metal/metal_solid_impact_hard4.wav",
	"physics/metal/metal_solid_impact_hard5.wav",
	"physics/metal/metal_solid_impact_soft1.wav",
	"physics/metal/metal_solid_impact_soft2.wav",
	"physics/metal/metal_solid_impact_soft3.wav",
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

hook.Add( "PlayerSpawn", "reset_push_onspawn", function(ply)
	ply._PushBlocked = nil
	ply._PushImmune = nil
end)

hook.Add("KeyPress", "PushInteraction", function(ply, key)
	if ply:IsPushBlocked() then return end

	if key == IN_USE and not push[ply:UserID()] then

		local handler = hook.Run("HandlePushLagCompensation", ply)
		
		if handler ~= false then
			ply:LagCompensation(true)
		end
		
		local ent = ply:GetEyeTrace().Entity
		if IsValid(ply) and IsValid(ent) then
			if ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR and ent:IsPlayer() and not ent:IsPushImmune() then
				local allowed = hook.Run("ShouldPlayerPush", ply, ent)

				if allowed ~= false then
					local pushSounds = ent:IsAnimatronic() and PushSound_pills or PushSound
					
					if ply:GetPos():Distance(ent:GetPos()) <= 100 then
						if ent:Alive() and ent:GetMoveType() == MOVETYPE_WALK and not ent:IsFlagSet(FL_FROZEN) then
							local power = hook.Run("PlayerPush", ply, ent)
							
							ply:EmitSound(pushSounds[math.random(#pushSounds)], 100, 100)
							local velAng = ply:EyeAngles():Forward()
							velAng.z = math.Clamp(velAng.z, -0.1, 0.2)

							ent:SetVelocity(velAng * ( power or (ent:IsAnimatronic() and !ply:IsAnimatronic() and 250 or 450)))
							ent:ViewPunch(Angle(math.random(-25, 25), math.random(-25, 25), 0))
							
							push[ply:UserID()] = true
							timer.Simple(0.20, function()
								if IsValid(ply) then
									push[ply:UserID()] = false
								end
							end)
						end
					end
				end
			end
		end
	
		ply:LagCompensation(false)
	end
end)

hook.Add("PlayerDeath", "PushDeath", function(ply)
	ply:SetPushBlocked(false)
	ply:SetPushImmune(false)
end)