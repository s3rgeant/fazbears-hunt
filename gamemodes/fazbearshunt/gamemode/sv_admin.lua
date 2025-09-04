util.AddNetworkString("OpenAdminPanel")
util.AddNetworkString("AdminAction")

util.AddNetworkString("fh_net_scarysound")
util.AddNetworkString("fh_change_notprefered")

function GiveAnimatronic(ply, killer)
	if killer == nil or killer == "" then return end
	
	if !ply:Alive() then
		--RevivePlayer(ply)
		ply:UnSpectate()
		ply:Spawn()
	end
	giveKiller(ply, killer, true)
	ply:ReturnToSpawn()
end

function RevivePlayer(ply)
	setupPlayerVars(ply)
	ply.lobbyFreeze = false
	
	if isGameOn then
		survivors[ply] = true
	end
	
	for k,v in pairs(usedKillers) do
		if usedKillers[k] == ply then
			usedKillers[k] = nil
		end
	end
	
	if ply:Team() == 2701 or animatronics[ply] or IsValid(pills.getMappedEnt(ply)) then
		pills.restore(ply:Nick(), true)
		animatronics[ply] = nil
	end
	ply:SetTeam(TEAM_UNASSIGNED)
    ply:Spawn()
end

function highlightSelected(targets, owner)
	if !isGameOn or table.IsEmpty(survivors) or table.IsEmpty(animatronics) then return end
	local affectedNicknames = {}
	local affected = {}
	
	for _,v in player.Iterator() do
		if survivors[v] and !table.HasValue(affectedPlayers,v) then
			local isAffected = table.HasValue(targets, v)
			highlight.NotifyTarget(v, nil, isAffected )
			
			if isAffected then
				table.insert(affectedNicknames, v:Nick())
				table.insert(affected, v)
			end
		end
	end
	
	if table.IsEmpty(affectedNicknames) then return end
		
	for ply, _ in pairs(animatronics) do
		net.Start("ToggleHighlightSound")
		net.WriteBool(true)
		net.Send(ply)
		
		highlight.Add(ply, affected)
	end
		
	if team.NumPlayers(TEAM_SPECTATOR) > 0 then
		net.Start('NotifySpectators')
		net.WriteTable(affectedNicknames)
		net.WriteEntity(owner or player.GetAll()[1])
		net.Send( team.GetPlayers(TEAM_SPECTATOR) )
	end
	
    LogEvent("(*АДМИН*) Подсвечено "..table.Count(targets).." игроков.")
end

function KillPlayer(ply)
	if ply:Alive() then
		if animatronics[ply] then
			animatronics[ply] = nil
		end
		if survivors[ply] then
			survivors[ply] = nil
		end
		
		ply:Kill()
		ply:SetTeam(TEAM_SPECTATOR)
		
        LogEvent("(*АДМИН*) - Убит игрок **"..ply:Nick().."**")
		
		if !roundEnding and isGameOn then
			animatronicsVictory_check(ply)
		end
	end
end

function StartRound()
	if !isGameOn then
		registerNewRound()
        LogEvent("(*АДМИН*) - ⌛️ Таймер раунда начат. Количество игроков: "..player.GetCount())
	end
end

if ULib then

	local cl_cvar_pickup = "cl_pickupplayers"
	
	local function playerPickup( ply, ent )
		local access, tag = ULib.ucl.query( ply, "ulx physgunplayer" )
		if ent:GetClass() == "player" and access and not ent.NoNoclip and not ent.frozen and ply:GetInfoNum( cl_cvar_pickup, 1 ) == 1 then
			-- Extra restrictions! UCL wasn't designed to handle this sort of thing so we're putting it in by hand...
			local restrictions = {}
			ULib.cmds.PlayerArg.processRestrictions( restrictions, ply, {}, tag and ULib.splitArgs( tag )[ 1 ] )
			if restrictions.restrictedTargets == false or (restrictions.restrictedTargets and not table.HasValue( restrictions.restrictedTargets, ent )) then
				return
			end

			ent:SetMoveType( MOVETYPE_NONE ) -- So they don't bounce
			return true
		end
	end
	hook.Add( "PhysgunPickup", "ulxPlayerPickup", playerPickup, HOOK_HIGH ) -- Allow admins to move players. Call before the prop protection hook.
	
end

function HighlightAll()
	if table.Count(survivors) > 0 and table.Count(animatronics) > 0 then
		local affectedNicknames = {}
		
		for ply, _ in pairs(animatronics) do
			net.Start("AddAffectedPlayers")
			net.WriteTable(survivors)
			net.Send(ply)
			
			net.Start("ToggleHighlightSound")
			net.WriteBool(true)
			net.Send(ply)
		end
		
		for _, ply in pairs(survivors) do
			net.Start("PlayHighlightSounds")
			net.WriteBool(true)
			net.Send(ply)
			table.insert(affectedNicknames, ply:Nick())
		end
		
		if table.Count(team.GetPlayers(TEAM_SPECTATOR)) > 0 then
			net.Start('NotifySpectators')
			net.WriteTable(affectedNicknames)
			net.WriteEntity(player.GetAll()[1])
			net.Broadcast()
		end
		
        LogEvent("(*АДМИН*) Все игроки подсвечены.")
	end
end

local function endgame_shared()
	net.Start('fh_sound_stop')
	net.WriteString( "timer_music" )
	net.Broadcast()
	
	timer.Remove("UnfreezeAnims")
	
	for v,_ in pairs(animatronics) do
		v.lobbyFreeze = nil
		v:Freeze(false)
	end
end

function EndRound()
	if !roundEnding and isGameOn then
		endGame(true)
		endgame_shared()
		LogEvent(" ")
        LogEvent("(*АДМИН*) - Раунд закончил *АДМИН*.")
		
		net.Start('fh_net_scarysound')
		net.WriteBool(false)
		net.SendOmit( table.GetKeys( getOutworldVictims() ) )
	end
end

function EndPostRound()
	if !roundActive and !roundEnding and isGameOn then
		roundActive = true
		endgame_shared()
	
		net.Start('fh_net_scarysound')
		net.WriteBool(true)
		net.SendOmit( table.GetKeys( getOutworldVictims() ) )
		
		local vremya = fh.GetGameDuration()
		
		if fh.GetRoundType() < 2 then
			net.Start("fh_timer_cutback")
			net.WriteFloat(vremya)
			net.WriteString("round/time_cutback.mp3")
			net.Broadcast()
			
			timer.Adjust("EndGameTimer", vremya)
		end
		
		hook.Run("fh_poststartgame", roundType, animatronics)
		
		LogEvent(" ")
        LogEvent("(*АДМИН*) - Все аниматроники разморожены, раунд начат.")
	end
end

function EndLobbyTimer()
	if timer.Exists("GameStartTimer") then
		timer.Adjust("GameStartTimer", 1, 1, function() end)
		timer.Remove("GameStartTimer")
		
		net.Start("ResetTimer")
		net.Broadcast()
	end
end

function setConvarValue(n, value)
	game.ConsoleCommand(n.." "..value.."\n")
end

net.Receive("AdminAction", function(len, ply)
    if not ply:IsAdmin() then return end

    local action = net.ReadString()

    if action == "give_animatronic" or action == "resurrect" or action == "kill" or action == "highlight" then
        local numTargets = net.ReadUInt(8)
        local targets = {}
        for i = 1, numTargets do
            local target = net.ReadEntity()
            if IsValid(target) and target:IsPlayer() then
                table.insert(targets, target)
            end
        end
		
		if action == "highlight" then
			highlightSelected(targets, ply)
			return
		end
		
		local killer = ""
		if action == "give_animatronic" then 
			killer = net.ReadString()
		end
		
        for _, target in pairs(targets) do
            if action == "give_animatronic" then
                GiveAnimatronic(target, killer)
            elseif action == "resurrect" then
                RevivePlayer(target)
				LogEvent("(*АДМИН*) - Воскрешён игрок "..target:Nick())
            elseif action == "kill" then
                KillPlayer(target)
            end
        end
	elseif string.match(action, "playable") then
		local killer = net.ReadString()
		if killer == "" or string.len(killer) < 1 then return end
		
		pill_makePreferable(killer, string.match(action, "add"))
		save_dontPrefer()
	
		net.Start("fh_change_notprefered")
		net.WriteString(killer)
		net.WriteBool(string.match(action, "add"))
		net.Broadcast()
    else
		if action == "start_round" then
			StartRound()
		elseif action == "highlight_all" then
			HighlightAll()
		elseif action == "end_round" then
			EndRound()
		elseif action == "set_highlight_delay" then
			local value = net.ReadFloat()
			setConvarValue("halo_cooldown", math.floor(value))
		elseif action == "set_highlight_duration" then
			local value = net.ReadFloat()
			setConvarValue("halo_time", math.floor(value))
		elseif action == "set_highlight_distance" then
			local value = net.ReadFloat()
			setConvarValue("halo_radius", math.floor(value))
		elseif action == "end_post_round" then
			EndPostRound()
		elseif action == "end_lobby_timer" then
			EndLobbyTimer()
		elseif action == "fh_spawn_gifts" then
			SpawnGifts()
		elseif action == "fh_auto_map_hl" then
			local mapInfo = fh.GetMapData()
			
			if !mapInfo then return end
			
			setConvarValue("halo_cooldown", mapInfo.halo_cooldown)
			setConvarValue("halo_time", mapInfo.halo_time)
			setConvarValue("halo_radius", mapInfo.halo_radius)
			setConvarValue("fh_max_cupcakes", mapInfo.max_cupcakes)
		elseif action == "fh_auto_map_save" then
			AddOrUpdateMapData(
			
				game.GetMap(), 
				{
					halo_cooldown = GetConVar('halo_cooldown'):GetInt(),
					halo_time = GetConVar('halo_time'):GetInt(),
					halo_radius = GetConVar('halo_radius'):GetInt(),
					max_cupcakes = GetConVar('fh_max_cupcakes'):GetInt()
				}
				
			)
		elseif action == "fh_gifts_spawning" then
			local bool = net.ReadBool()
			if !bool then
				disableGiftSpawning()
			else
				game.ConsoleCommand("fh_gifts_spawning 1\n")
				doGiftSpawning()
			end
		elseif action == "fh_max_cupcakes" or action == "fh_round_duration" then
			local num = net.ReadFloat()
			
			game.ConsoleCommand(action .. " " .. math.floor(num) .. "\n")
		else
			local bool = net.ReadBool() and 1 or 0
			
			game.ConsoleCommand(action .. " " .. bool .. "\n")
		end
	end
end)

hook.Add( "Initialize", "fh_init_autohighlight", function()
	if SERVER and conVars.fh_automatic_highlight:GetBool() then
		local mapInfo = fh.GetMapData()
		
		if !mapInfo then return end
		
		setConvarValue("halo_cooldown", mapInfo.halo_cooldown)
		setConvarValue("halo_time", mapInfo.halo_time)
		setConvarValue("halo_radius", mapInfo.halo_radius)
		setConvarValue("fh_max_cupcakes", mapInfo.max_cupcakes)
	end
end)

local filePath = "fh_map_data.json"

function fh.GetMapData(map)
    local mapName = map or game.GetMap()

    if not file.Exists(filePath, "DATA") then
        print("File " .. filePath .. " not found")
        return nil
    end

    local jsonData = file.Read(filePath, "DATA")
    if not jsonData or jsonData == "" then
        print("File is empty or couldn't read: " .. filePath)
        return nil
    end

    local allMapData = util.JSONToTable(jsonData)
    if not allMapData or type(allMapData) ~= "table" then
        print("Error when reading JSON.")
        return nil
    end

    local mapData = allMapData[mapName]
    if not mapData then
        print("Data for map: " .. mapName .. " not found.")
        return nil
    end

    return mapData
end

function fh.GetAllMapData()
    if not file.Exists(filePath, "DATA") then
        print("File " .. filePath .. " not found.")
        return nil
    end

    local jsonData = file.Read(filePath, "DATA")
    if not jsonData or jsonData == "" then
        print("File is empty or couldn't read: " .. filePath)
        return nil
    end

    local allMapData = util.JSONToTable(jsonData)
    if not allMapData or type(allMapData) ~= "table" then
        print("Error when reading JSON.")
        return nil
    end
	
	return allMapData
end

function AddOrUpdateMapData(mapName, dataTable)
    if not istable(dataTable) then
        print("Error: dataTable need to be a Table.")
        return
    end

    mapName = mapName or game.GetMap()

    local allMapData = {}

    if file.Exists(filePath, "DATA") then
        local jsonData = file.Read(filePath, "DATA")
        if jsonData and jsonData ~= "" then
            allMapData = util.JSONToTable(jsonData) or {}
        end
    end

    allMapData[mapName] = dataTable

    local newJson = util.TableToJSON(allMapData, true)
    file.Write(filePath, newJson)

    print("Data for map: '" .. mapName .. "' updated or added.")
end
