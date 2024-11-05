util.AddNetworkString("OpenAdminPanel")
util.AddNetworkString("AdminAction")

function GiveAnimatronic(ply, killer)
	if killer == nil or killer == "" then return end
	
	RevivePlayer(ply)
	giveKiller(ply, killer)
end

function RevivePlayer(ply)
    ply:Spawn()
	setupPlayerVars(ply)
	ply:SetTeam(TEAM_UNASSIGNED)
	
	if isGameOn then
		if !table.HasValue(survivors, ply) then
			table.insert(survivors, ply)
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

function KillPlayer(ply)
	if ply:Alive() then
		ply:Kill()
		if table.HasValue(alivePlayers, ply) then
			table.RemoveByValue(alivePlayers, ply)
		end
		if table.HasValue(animatronics, ply) then
			table.RemoveByValue(animatronics, ply)
		end
		if table.HasValue(survivors, ply) then
			table.RemoveByValue(survivors, ply)
		end
	end
end

function StartRound()
	if !isGameOn and roundEnding or postGameOn then
		registerNewRound()
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
	end
end

function EndRound()
	if !roundEnding and isGameOn then
		endGame()
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

    if action == "give_animatronic" or action == "resurrect" or action == "kill" then
        local numTargets = net.ReadUInt(8)
        local targets = {}
        for i = 1, numTargets do
            local target = net.ReadEntity()
            if IsValid(target) and target:IsPlayer() then
                table.insert(targets, target)
            end
        end
			
		local killer = net.ReadString()
        for _, target in pairs(targets) do
            if action == "give_animatronic" then
                GiveAnimatronic(target, killer)
            elseif action == "resurrect" then
                RevivePlayer(target)
            elseif action == "kill" then
                KillPlayer(target)
            end
        end
    else
		local target = net.ReadEntity()
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
		end
	end
end)