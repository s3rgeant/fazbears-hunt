function getPlrs(ply)
	local rf = RecipientFilter()
	rf:AddAllPlayers()
	for _, v in ipairs(rf:GetPlayers()) do
		if v:Team() == TEAM_SPECTATOR or !v:Alive() then rf:RemovePlayer(v) end
	end
	return rf:GetPlayers()
end

local function cyclePlayers(ply, am)	
	if ply:GetObserverMode() == OBS_MODE_CHASE or ply:GetObserverMode() == OBS_MODE_IN_EYE then
		local num = 1
		local players = getPlrs(ply)
		local specindex = table.KeyFromValue(players, ply:GetObserverTarget()) or 1
		//print(ply:GetObserverMode(), specindex, 'нихуя себе?')
		if #players == 0 or !specindex then return false end
		
		if am > 0 then
			if specindex < table.Count(players) then
				num = specindex + am
				//print(ply:Nick()..' спектати вперёд')
			else
				num = 1
			end
		else
			if specindex > 1 then
				num = specindex + am
				//print(ply:Nick()..' спектатит назад')
			else
				num = #players
			end
		end
		ply:SpectateEntity( players[num] )
		
		net.Start('DeadHUDChange')
		net.WriteEntity(players[num])
		net.Send(ply)
	end
end

hook.Add('PlayerDeathThink', 'BlockRespawn', function(ply)
	if isGameOn then
		return false
	end
end)

hook.Add( "KeyPress", "KEY_PRESS_SPECTATOR", function( ply, key )
	if ply:Team() == TEAM_SPECTATOR then
		local players = getPlrs(ply)
		
		if key == IN_JUMP and table.KeyFromValue(players, ply:GetObserverTarget()) then	
			if ply:GetObserverMode() == OBS_MODE_ROAMING then
				ply:Spectate(OBS_MODE_IN_EYE)
				net.Start('DeadHUDChange')
				net.WriteEntity(ply:GetObserverTarget())
				net.Send(ply)
			elseif ply:GetObserverMode() == OBS_MODE_IN_EYE then
				ply:Spectate(OBS_MODE_CHASE)
			elseif ply:GetObserverMode() == OBS_MODE_CHASE then
				ply:Spectate(OBS_MODE_ROAMING)
				net.Start('DeadHUDChangeString')
				net.WriteString('')
				net.Send(ply)
			end
			
		elseif ( key == IN_ATTACK ) then
			cyclePlayers(ply, 1)
		elseif ( key == IN_ATTACK2 ) then
			cyclePlayers(ply, -1)
		end
	end
end )