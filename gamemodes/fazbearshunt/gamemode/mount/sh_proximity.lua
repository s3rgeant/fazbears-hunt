local proximityEnabled = CreateConVar("proximity_enabled", 1, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Switches between global and proximity voice chat.", 0, 1)
local maxDistance = CreateConVar("proximity_radius", 3000, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Radius, in which players can hear each other.")
local muteVolume = CreateConVar("proximity_mute", 0.3, { FCVAR_ARCHIVE,FCVAR_REPLICATED }, "Volume of players/sounds, when they're behind the walls. (0-1)", 0, 1)

local muteSpecs = CreateConVar("proximity_hear_spectators", 1, { FCVAR_ARCHIVE,FCVAR_CLIENTDLL,FCVAR_USERINFO }, "Should local player hear other spectators? (0-1)", 0, 1)

if SERVER then
	local PLAYER = FindMetaTable("Player")

	function PLAYER:SetAudible(state)
		self.fh_audible = state and true or false
	end

	function PLAYER:GetAudible()
		if self.fh_audible == nil then
			return true
		end
		return self.fh_audible
	end

	-- чтобы слушать только одного игрока (за золотого фредди например слышать только жертву)
	function PLAYER:ForceListenPlayer(talker)
		if not IsValid(talker) or not talker:IsPlayer() then return end
		self.fh_force_listen = talker
	end

	function PLAYER:ResetListenPlayer()
		self.fh_force_listen = nil
	end
	
	hook.Add( "PlayerSpawn", "reset_proximity_onspawn", function(ply)
		ply.fh_force_listen = nil
		ply.fh_audible = nil
	end)
	
	hook.Add("PlayerCanHearPlayersVoice", "fh_proximity_sv", function(listener, talker)
		if not IsValid(listener) or not IsValid(talker) then return false, false end
		
		local list_team = listener:Team()
		local talker_team = talker:Team()

		if IsValid(listener.fh_force_listen) then
			if listener.fh_force_listen == talker then
				return true, true
			else
				return false, false
			end
		end

		if not talker:GetAudible() then
			return false, false
		end

		local maxDistance = GetConVar("proximity_radius"):GetInt()
		local proximityEnabled = GetConVar("proximity_enabled"):GetInt()

		-- наблюдатель не хочет слышать других наблюдателей
		if list_team == TEAM_SPECTATOR and talker_team == TEAM_SPECTATOR and listener:GetInfoNum("proximity_hear_spectators", 1) == 0 then
			return false, false
		end

		if proximityEnabled == 0 then
			return true, false
		end
		
		-- чтобы наблюдателей не слышать
		if list_team ~= TEAM_SPECTATOR and talker_team == TEAM_SPECTATOR then
			return false, false
		end

		-- наблюдатели и аниматроники слышат себя не в 3д
		if (list_team == 2701 and talker_team == 2701) 
		or (list_team == TEAM_SPECTATOR and talker_team == TEAM_SPECTATOR) then
			return true, false
		end

		local ply = listener
		if IsValid(listener:GetObserverTarget()) then ply = listener:GetObserverTarget() end
		if IsValid(listener.fh_target_player) then ply = listener.fh_target_player end

		local distance = ply:GetPos():Distance(talker:GetPos())
		if distance > maxDistance then return false, true end

		return true, true
	end)
else

	local function UpdateVoiceDSP(listener, talker)
		if not IsValid(listener) or not IsValid(talker) or listener == talker then return end
		
		if !proximityEnabled:GetBool() then
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
	
	if !timer.Exists("FH_UpdateVoiceChat") then
		timer.Create("FH_UpdateVoiceChat", 0.25, 0, function()
			local listener = LocalPlayer()

			if !IsValid(listener) then return end
		
			for _, talker in player.Iterator() do
				if IsValid(talker) and ShouldProcessVoice(listener, talker) then
					UpdateVoiceDSP(listener, talker)
				end
			end
		end)
	end
	
	hook.Add("PlayerEndVoice", "ClientVoiceFilterEnd", function(ply)
		ply:SetVoiceVolumeScale(1)
	end)
	
	hook.Add("PlayerStartVoice", "ClientVoiceFilterStart", function(ply)
		if IsValid(ply) and (ply:Team() == TEAM_SPECTATOR or ply:Team() == 2701 and LocalPlayer():Team() == 2701) then
			ply:SetVoiceVolumeScale(1)
		end
	end)
end