util.AddNetworkString("OpenAdminPanel")
util.AddNetworkString("AdminAction")

util.AddNetworkString("fh_net_scarysound")

function GiveAnimatronic(ply, killer)
	if killer == nil or killer == "" then return end
	
	RevivePlayer(ply)
	giveKiller(ply, killer, true)
	ply:SetTeam(2701)
	ply:Spawn()
end

function RevivePlayer(ply)
	ply:SetTeam(TEAM_UNASSIGNED)
    ply:Spawn()
	setupPlayerVars(ply)
	
	if isGameOn then
		if !table.HasValue(survivors, ply) then
			table.insert(survivors, ply)
		end
	end
	
	for k,v in pairs(usedKillers) do
		if usedKillers[k] == ply then
			usedKillers[k] = nil
		end
	end
	
	if ply:Team() == 2701 or table.HasValue(animatronics, ply) or IsValid(pk_pills.getMappedEnt(ply)) then
		RunConsoleCommand("pk_pill_restore", ply:Nick())
		if table.HasValue(animatronics, ply) then
			table.RemoveByValue(animatronics, ply)
		end
	end
	
	if !table.HasValue(alivePlayers, ply) then
		table.insert(alivePlayers, ply)
	end
end

function highlightSelected(targets)
	if !isGameOn or table.Count(survivors) == 0 or table.Count(animatronics) == 0 then return end
	local affectedNicknames = {}
	
	for _,v in ipairs(targets) do
		if table.HasValue(survivors, v) then
			net.Start("PlayHighlightSounds")
			net.WriteBool(table.HasValue(targets, v))
			net.Send(v)
			table.insert(affectedNicknames, v:Nick())
			
			table.insert(affectedPlayers, v)
		end
	end
	
	if table.Count(affectedNicknames) == 0 then return end
		
	for _, ply in pairs(animatronics) do
		net.Start("AddAffectedPlayers")
		net.WriteTable(survivors)
		net.Send(ply)
		
		net.Start("ToggleHighlightSound")
		net.WriteBool(true)
		net.Send(ply)
	end
		
	if table.Count(team.GetPlayers(TEAM_SPECTATOR)) > 0 then
		net.Start('NotifySpectators')
		net.WriteTable(affectedNicknames)
		net.WriteEntity(player.GetAll()[1])
		net.Broadcast()
	end
	
    LogEvent("(*АДМИН*) Подсвечено "..table.Count(targets).." игроков.")
end

function KillPlayer(ply)
	if ply:Alive() then
		if table.HasValue(alivePlayers, ply) then
			table.RemoveByValue(alivePlayers, ply)
		end
		if table.HasValue(animatronics, ply) then
			table.RemoveByValue(animatronics, ply)
		end
		if table.HasValue(survivors, ply) then
			table.RemoveByValue(survivors, ply)
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
	if !isGameOn and roundEnding or postGameOn then
		registerNewRound()
        LogEvent("(*АДМИН*) - ⌛️ Таймер раунда начат. Количество игроков: "..table.Count(alivePlayers))
	end
end

function HighlightAll()
	if table.Count(survivors) > 0 and table.Count(animatronics) > 0 then
		local affectedNicknames = {}
		
		for _, ply in pairs(animatronics) do
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

function EndRound()
	if !roundEnding and isGameOn then
		endGame(true)
		net.Start('fh_sound_stop')
		net.WriteString(roundType == 0 and 'music/first_minute.wav' or 'music/freeze_timer_springtrap.wav')
		net.Broadcast()
		
		net.Start('fh_net_scarysound')
		net.WriteBool(false)
		net.Broadcast()
		
		for _,v in ipairs(animatronics) do
			v.lobbyFreeze = nil
		end
		LogEvent(" ")
        LogEvent("(*АДМИН*) - Раунд закончил *АДМИН*.")
	end
end

function EndPostRound()
	if !roundEnding and isGameOn then
		roundActive = true
		net.Start('fh_sound_stop')
		net.WriteString(roundType == 0 and 'music/first_minute.wav' or 'music/freeze_timer_springtrap.wav')
		net.Broadcast()
		
		net.Start('fh_net_scarysound')
		net.WriteBool(true)
		net.Broadcast()
		
		for _,v in ipairs(animatronics) do
			v.lobbyFreeze = nil
		end
		LogEvent(" ")
        LogEvent("(*АДМИН*) - Все аниматроники разморожены, раунд начат.")
	end
end

function EndLobbyTimer()
	if timer.Exists("GameStartTimer") then
		timer.Remove("GameStartTimer")
		
		net.Start("ResetTimer")
		net.Broadcast()
	end
end

function SetHighlightDelay(value)
	game.ConsoleCommand("halo_cooldown "..value.."\n")
end

function SetHighlightDuration(value)
	game.ConsoleCommand("halo_time "..value.."\n")
end

function SetHighlightDistance(value)
	game.ConsoleCommand("halo_radius "..value.."\n")
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
			highlightSelected(targets)
			return
		end
			
        for _, target in pairs(targets) do
            if action == "give_animatronic" then
				local killer = net.ReadString()
                GiveAnimatronic(target, killer)
            elseif action == "resurrect" then
                RevivePlayer(target)
				LogEvent("(*АДМИН*) - Воскрешён игрок "..target:Nick())
            elseif action == "kill" then
                KillPlayer(target)
            end
        end
    else
		--local target = net.ReadEntity()
		if action == "start_round" then
			StartRound()
		elseif action == "highlight_all" then
			HighlightAll()
		elseif action == "end_round" then
			EndRound()
		elseif action == "set_highlight_delay" then
			local value = net.ReadFloat()
			SetHighlightDelay(math.floor(value))
		elseif action == "set_highlight_duration" then
			local value = net.ReadFloat()
			SetHighlightDuration(math.floor(value))
		elseif action == "set_highlight_distance" then
			local value = net.ReadFloat()
			SetHighlightDistance(math.floor(value))
		elseif action == "end_post_round" then
			EndPostRound()
		elseif action == "end_lobby_timer" then
			EndLobbyTimer()
		elseif action == "fh_gifts_spawning" then
			local bool = net.ReadBool()
			if !bool then
				disableGiftSpawning()
			else
				game.ConsoleCommand("fh_gifts_spawning 1\n")
				doGiftSpawning()
			end
		elseif action == "fh_animatronic_immortal" or action == "fuppr_sfreddy_noclip" or action == "fh_less_steps" then
			local bool = net.ReadBool() and 1 or 0
			
			game.ConsoleCommand(action .. " " .. bool .. "\n")
		elseif action == "fh_spawn_gifts" then
			fh_spawnGifts()
		elseif action == "fh_auto_map_hl" then
			local mapInfo = GetMapData()
			
			if !mapInfo then return end
			
			SetHighlightDelay(mapInfo.value1)
			SetHighlightDuration(mapInfo.value2)
			SetHighlightDistance(mapInfo.value3)
		elseif action == "fh_auto_map_save" then
			AddOrUpdateMapData(GetConVar('halo_cooldown'):GetInt(),
			GetConVar('halo_time'):GetInt(),
			GetConVar('halo_radius'):GetInt(),
			game.GetMap())
		end
	end
end)

local filePath = "fh_map_data.txt"

function GetMapData()
    local mapName = game.GetMap()

    if not file.Exists(filePath, "DATA") then
        print("Файл " .. filePath .. " не найден.")
		file.Write(filePath, "")
        return nil
    end

    local data = file.Read(filePath, "DATA")
    if not data then
        print("Не удалось прочитать файл " .. filePath)
        return nil
    end

    local mapData = {}
    for _, line in ipairs(string.Split(data, "\n")) do
        local trimmedLine = string.Trim(line)
        if trimmedLine ~= "" then
            local parts = string.Split(trimmedLine, ",")
            local map = string.Trim(parts[1])

            if map == mapName then
                mapData = {
                    map = map,
                    value1 = tonumber(string.Trim(parts[2])),
                    value2 = tonumber(string.Trim(parts[3])),
                    value3 = tonumber(string.Trim(parts[4]))
                }
                break
            end
        end
    end

    if next(mapData) == nil then
        print("Данные для карты " .. mapName .. " не найдены.")
        return nil
    end

    return mapData
end

function AddOrUpdateMapData(value1, value2, value3, mapName)
    if not file.Exists(filePath, "DATA") then
        file.Write(filePath, "")
    end

    local data = file.Read(filePath, "DATA") or ""
    local lines = string.Split(data, "\n")
    local updated = false
    local newLines = {}

    for _, line in ipairs(lines) do
        local trimmedLine = string.Trim(line)
        if trimmedLine ~= "" then
            local parts = string.Split(trimmedLine, ",")
            local existingMap = string.Trim(parts[1])

            if existingMap == mapName then
                table.insert(newLines, string.format("%s, %d, %d, %d", mapName, value1, value2, value3))
                updated = true
            else
                table.insert(newLines, trimmedLine)
            end
        end
    end

    if not updated then
        table.insert(newLines, string.format("%s, %d, %d, %d", mapName, value1, value2, value3))
    end

    file.Write(filePath, table.concat(newLines, "\n"))
    print("Данные обновлены или добавлены для карты:", mapName)
end

concommand.Add("fh_update_map_data", function(ply, cmd, args)
    if not ply:IsAdmin() then return end

    if #args < 3 then
        print("Использование: update_map_data <value1> <value2> <value3> [mapName]")
        return
    end

    local value1 = tonumber(args[1])
    local value2 = tonumber(args[2])
    local value3 = tonumber(args[3])
    local mapName = args[4] and string.Trim(args[4]) or game.GetMap()

    if not value1 or not value2 or not value3 then
        return
    end

    AddOrUpdateMapData(value1, value2, value3, mapName)
end)