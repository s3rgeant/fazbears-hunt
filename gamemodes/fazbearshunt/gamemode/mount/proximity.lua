local canSpec = CreateConVar("proximity_deadtalk", 0, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Can dead people talk? Huh?", 0, 1)
local proximityEnabled = CreateConVar("proximity_enabled", 1, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Switches between global and proximity voice chat.", 0, 1)
local maxDistance = CreateConVar("proximity_radius", 3000, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Radius, in which players can hear each other.")
local muteVolume = CreateConVar("proximity_mute", 0.3, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Volume of players/sounds, when they're behind the walls. (0-1)", 0, 1)

local muteSpecs = CreateConVar("proximity_hear_spectators", 1, { FCVAR_ARCHIVE,FCVAR_CLIENTDLL,FCVAR_USERINFO }, "Should local player hear other spectators? (0-1)", 0, 1)

if SERVER then

	fh_cant_hear = {}
	
	hook.Add( "PlayerCanHearPlayersVoice", "fh_proximity_sv", function(listener, talker)
		local canSpec = GetConVar("proximity_deadtalk"):GetInt()
		local maxDistance = GetConVar("proximity_radius"):GetInt()
		local proximityEnabled = GetConVar("proximity_enabled"):GetInt()
		
		if (listener:Team() == TEAM_SPECTATOR and talker:Team() == TEAM_SPECTATOR and listener:GetInfoNum( "proximity_hear_spectators", 1 ) == 0)
			or fh_cant_hear[listener] then
			return false, false 
		end
		
		if (listener:Team() == 2701 and talker:Team() == 2701) or listener:Team() == TEAM_SPECTATOR and talker:Team() == TEAM_SPECTATOR then
			return true, false
		end
		
		if (!talker:Alive() or talker:Team() == TEAM_SPECTATOR) then
			if canSpec == 0 then
				return false, false
			else
				return true, false
			end
		end
	
		if proximityEnabled == 0 then
			return true, false
		end
		
		local ply = listener
		if IsValid(listener:GetObserverTarget()) then ply = listener:GetObserverTarget() end
		if IsValid(listener.fh_target_player) then ply = listener.fh_target_player end
		
		local distance = ply:GetPos():Distance(talker:GetPos())
	
		if distance > maxDistance then
			return false, false
		end
	
		return true, true
	end)

else

	local function UpdateVoiceDSP(listener, talker)
		if not IsValid(listener) or not IsValid(talker) or listener == talker then return end
		
		if not proximityEnabled:GetBool() then
			talker:SetVoiceVolumeScale(1)
			return
		end
		
		local ply = listener
		if IsValid(listener:GetObserverTarget()) then ply = listener:GetObserverTarget() end
		if IsValid(listener.fh_target_player) then ply = listener.fh_target_player end
	
		local distance = ply:GetPos():Distance(talker:GetPos())
	
		if distance > maxDistance:GetInt() then return end
	
		local trace = util.TraceLine({
			start = ply:EyePos(),
			endpos = talker:EyePos(),
			filter = function(ent)
				return ent != ply and ent != talker and not ent:IsPlayer() and not ent:IsNPC() and ent:GetClass() != "prop_physics"
			end
		})
	
		local volume = 1
		local mute = muteVolume:GetFloat()
		
		if distance < 200 then
			mute = math.min(mute * 2, 1)
		end
		if talker:WaterLevel() == 3 then
			mute = math.max(mute / 2, 0)
		end
		if (trace.Hit and (trace.MatType or 0) != 71) or talker:WaterLevel() == 3 then
			volume = (((distance / maxDistance:GetInt()) * -1) + 1) * mute
		else
			volume = (((distance / maxDistance:GetInt()) * -1) + 1)
		end
		
		talker:SetVoiceVolumeScale(volume)
	end
	
	local function ShouldProcessVoice(listener, talker)
		local team1 = listener:Team()
		local team2 = talker:Team()
	
		local bothInSameBlockedTeam =
			(team1 == 2701 and team2 == 2701) or
			(team1 == TEAM_SPECTATOR and team2 == TEAM_SPECTATOR)
	
		return talker ~= listener
			and IsValid(talker)
			and talker:IsSpeaking()
			and !talker:IsMuted()
			and !bothInSameBlockedTeam
	end
	
	hook.Add("Think", "ClientVoiceFilterThink", function()
		local listener = LocalPlayer()
		if not IsValid(listener) then return end
	
		for _, talker in player.Iterator() do
			if IsValid(talker) and ShouldProcessVoice(listener, talker) then
				UpdateVoiceDSP(listener, talker)
			end
		end
	end)
	
	hook.Add("PlayerEndVoice", "ClientVoiceFilterEnd", function(ply)
		ply:SetVoiceVolumeScale(1)
	end)
	
	hook.Add("PlayerStartVoice", "ClientVoiceFilterStart", function(ply)
		if IsValid(ply) and (ply:Team() == TEAM_SPECTATOR or ply:Team() == 2701 and LocalPlayer():Team() == 2701) then
			ply:SetVoiceVolumeScale(1)
		end
	end)

end