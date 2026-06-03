playerObservers = playerObservers or {}

local meta = FindMetaTable("Player")

function meta:GetObservers()
    return playerObservers[self] or {}
end

function meta:GetObserverCount()
    if not playerObservers[self] then return 0 end
    return #playerObservers[self]
end

local function AddObserver(target, ply)
    if not IsValid(target) then return end
    playerObservers[target] = playerObservers[target] or {}
    table.insert(playerObservers[target], ply)
end

local function RemoveObserver(target, ply)
    if not IsValid(target) then return end
    local t = playerObservers[target]
    if not t then return end
    for i, v in ipairs(t) do
        if v == ply then
            table.remove(t, i)
            break
        end
    end
end

local function UpdatePlayerObserver(ply, newTarget)
    local old = ply._lastObsTarget
    if old == newTarget then return end

    if IsValid(old) then
        RemoveObserver(old, ply)
    end

    if IsValid(newTarget) then
        AddObserver(newTarget, ply)
    end

    ply._lastObsTarget = newTarget
end

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
	UpdatePlayerObserver(ply, players[num])
end

hook.Add('PlayerDeathThink', 'fh_block_respawn', function(ply)
	if isGameOn then
		local obstarget = ply:GetObserverTarget()
		if ply:GetObserverMode() ~= OBS_MODE_ROAMING and IsValid(obstarget) then
			ply:SetPos(obstarget:EyePos())
		end
		return false
	end
end)

hook.Add('fh_createragdoll', 'fh_spectate_ragdoll', function(player, ragdoll)
	if IsValid(ragdoll) then
		if player:GetObserverCount() > 0 then
			for _, v in ipairs(player:GetObservers()) do
				if v:GetObserverTarget() == player and v:GetObserverMode() ~= OBS_MODE_ROAMING then
					v:SpectateEntity(ragdoll)
					v:Spectate(OBS_MODE_CHASE)
				end
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
			
			local obsTarget = ply:GetObserverTarget()
			if ply:GetObserverMode() ~= OBS_MODE_ROAMING and IsValid(obsTarget) and obsTarget:IsPlayer() and not obsTarget:Alive() and IsValid(obsTarget.DeathRagdoll) then
				ply:SpectateEntity(obsTarget.DeathRagdoll)
			end
			
			UpdatePlayerObserver(ply, obsTarget)
		elseif ( key == IN_ATTACK ) then
			cyclePlayers(ply, 1)
		elseif ( key == IN_ATTACK2 ) then
			cyclePlayers(ply, -1)
		end
	end
end )

hook.Add("PlayerSpawn", "obs_clear_spawn", function(ply)
    if IsValid(ply._lastObsTarget) then
        RemoveObserver(ply._lastObsTarget, ply)
    end
    ply._lastObsTarget = nil
end)

hook.Add("PlayerDisconnected", "obs_clear_disconnect", function(ply)
    if IsValid(ply._lastObsTarget) then
        RemoveObserver(ply._lastObsTarget, ply)
    end
end)

hook.Add("PlayerDeath", "obs_clear_death", function(ply)
    if IsValid(ply._lastObsTarget) then
        RemoveObserver(ply._lastObsTarget, ply)
    end
    ply._lastObsTarget = nil
end)

hook.Add("DoPlayerDeath", "obs_death", function(ply)
    if ply:GetPill() and ply:GetObserverCount() > 0 then
		for _, target in ipairs(ply:GetObservers()) do
			target:UnSpectate()
			target:Spectate(OBS_MODE_ROAMING)
		end
	end
end)