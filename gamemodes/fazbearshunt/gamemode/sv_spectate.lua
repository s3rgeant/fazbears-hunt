function getPlrs(ply)
	local entities = {}

	for _, v in ipairs(player.GetAll()) do
		if v:Team() ~= TEAM_SPECTATOR and v:Alive() then
			table.insert(entities, v)
		end
	end
	for _, ent in ipairs(ents.FindByClass("plushtrap")) do
		table.insert(entities, ent)
	end

	return entities
end

local function cyclePlayers(ply, am)
	local num = 1
	local players = getPlrs(ply)
	local specindex = table.KeyFromValue(players, ply:GetObserverTarget()) or 1
	if #players == 0 or !specindex then return false end
	
	if am > 0 then
		if specindex < table.Count(players) then
			num = specindex + am
		else
			num = 1
			num = 1
		end
	else
		if specindex > 1 then
			num = specindex + am
		else
			num = #players
		end
	end
	ply:SpectateEntity( players[num] )
	if players[num]:IsPlayer() then
		ply:SetupHands( players[num] )
	end
	
	if ply:GetObserverMode() != OBS_MODE_ROAMING then
		net.Start('DeadHUDChange')
		net.WriteEntity(players[num])
		net.Send(ply)
	end
end

hook.Add('PlayerDeathThink', 'fh_block_respawn', function(ply)
	if isGameOn then
		return false
	end
end)

hook.Add('fh_createragdoll', 'fh_spectate_dead', function(player, ragdoll)
	for k, v in ipairs(team.GetPlayers(TEAM_SPECTATOR)) do
		if v:GetObserverTarget() == player and v:GetObserverMode() != OBS_MODE_ROAMING then
			if ragdoll then
				v:SpectateEntity(ragdoll)
				v:Spectate(OBS_MODE_CHASE)
			end
		end
	end
end)

hook.Add( "KeyPress", "KEY_PRESS_SPECTATOR", function( ply, key )
	if ply:Team() == TEAM_SPECTATOR and ply:GetViewEntity() == ply then
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