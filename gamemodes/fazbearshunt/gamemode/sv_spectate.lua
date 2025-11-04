function getPlrs(ply)
	local entities = {}

	for _, v in player.Iterator() do
		if v:Team() ~= TEAM_SPECTATOR and v:Alive() then
			table.insert(entities, v)
		end
	end
	
	table.sort(entities, function(a, b)
        return a:Team() < b:Team()
    end)
	
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
end

--[[
hook.Add("SetupPlayerVisibility", "fh_spec_pvs", function(ply)
    if ply:Team() == TEAM_SPECTATOR then
        local target = ply:GetObserverTarget()
        if IsValid(target) then
            AddOriginToPVS(target:GetPos())
        end
    end
end)
--]]

hook.Add('PlayerDeathThink', 'fh_block_respawn', function(ply)
	if isGameOn then
		local obstarget = ply:GetObserverTarget()
		if ply:GetObserverMode() != OBS_MODE_ROAMING and IsValid(obstarget) then
			ply:SetPos(obstarget:EyePos())
		end
		return false
	end
end)

hook.Add('fh_createragdoll', 'fh_spectate_ragdoll', function(player, ragdoll)
	for _, v in ipairs(team.GetPlayers(TEAM_SPECTATOR)) do
		if v:GetObserverTarget() == player and v:GetObserverMode() ~= OBS_MODE_ROAMING then
			if ragdoll then
				v:SpectateEntity(ragdoll)
				v:Spectate(OBS_MODE_CHASE)
			end
		end
	end
end)

hook.Add( "KeyPress", "KEY_PRESS_SPECTATOR", function( ply, key )
	if ply:Team() == TEAM_SPECTATOR and ply:GetViewEntity() == ply then
		
		if key == IN_JUMP and IsValid( ply:GetObserverTarget() ) then	
			if ply:GetObserverMode() == OBS_MODE_ROAMING then
				ply:Spectate(OBS_MODE_IN_EYE)
			elseif ply:GetObserverMode() == OBS_MODE_IN_EYE then
				ply:Spectate(OBS_MODE_CHASE)
			elseif ply:GetObserverMode() == OBS_MODE_CHASE then
				ply:Spectate(OBS_MODE_ROAMING)
			end
			
		elseif ( key == IN_ATTACK ) then
			cyclePlayers(ply, 1)
		elseif ( key == IN_ATTACK2 ) then
			cyclePlayers(ply, -1)
		end
	end
end )