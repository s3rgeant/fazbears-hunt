if SERVER then
	util.AddNetworkString("InitializeMusic")
	util.AddNetworkString("SetMusicVolume")
	util.AddNetworkString("StopMusic")

	local terrorRadiusFar = 2500
	local terrorRadiusApproaching = 1400
	local terrorRadiusClose = 800

	local viewAngleThreshold = 50

	local isChasing = {}
	local chaseTimers = {}

	local currentKillers = {}
	local stealthKillers = {}

	local activeMusic = {}
	local globalVolumeMultiplier = 0.5

	local currentTheme = "default"
	local availableThemes = {}
	local musicFiles = {}

	local playerVolumeCVar = CreateConVar("tr_volume", "50", FCVAR_USERINFO, "Глобальная громкость музыки для игрока (0-100).")
	local playerHearCVar = CreateConVar("tr_hear", "1", FCVAR_USERINFO, "Предпочтение включения террора (1 - включено, 0 - отключено).")

	local function getPlayerVolume(ply)
		local volume = tonumber(ply:GetInfo("tr_volume"))
		if volume and volume >= 0 and volume <= 100 then
			return volume / 100
		end
		return 0.5
	end

	local function getPlayerHearPreference(ply)
		local hearPreference = tonumber(ply:GetInfo("tr_hear"))
		return hearPreference == 1
	end

	local function loadThemes()
		availableThemes = {}
		local files, directories = file.Find("sound/music/chase/*", "GAME")

		for _, dir in ipairs(directories) do
			local requiredFiles = {
				"far.wav",
				"approaching.wav",
				"near.wav",
				"chase.wav"
			}

			local foundAll = true
			for _, reqFile in ipairs(requiredFiles) do
				if not file.Exists("sound/music/chase/" .. dir .. "/" .. reqFile, "GAME") then
					foundAll = false
					break
				end
			end

			if foundAll then
				table.insert(availableThemes, dir)
			end
		end

		if #availableThemes == 0 then
			print("Не найдено ни одной доступной темы в папке sound/music/chase/")
		end
	end

	local function setCurrentTheme(themeName)
		if table.HasValue(availableThemes, themeName) then
			currentTheme = themeName
			musicFiles = {
				killer_far = "music/chase/" .. currentTheme .. "/far.wav",
				killer_approaching = "music/chase/" .. currentTheme .. "/approaching.wav",
				killer_close = "music/chase/" .. currentTheme .. "/near.wav",
				chase = "music/chase/" .. currentTheme .. "/chase.wav"
			}
			for _, ply in player.Iterator() do
				if activeMusic[ply] then
					for musicType, _ in pairs(activeMusic[ply]) do
						net.Start("StopMusic")
						net.WriteString(musicType)
						net.Send(ply)
					end
					activeMusic[ply] = nil
				end
				if ply:Team() ~= TEAM_SPECTATOR then
					initializeMusic(ply)
				end
			end
		else
			print("Тема " .. themeName .. " не найдена.")
		end
	end

	loadThemes()
	if #availableThemes > 0 then
		setCurrentTheme(availableThemes[1])
	end

	local function setMusicVolume(ply, musicType, volume)
		if not getPlayerHearPreference(ply) then
			volume = 0
		else
			volume = volume * getPlayerVolume(ply)
		end
		volume = volume * globalVolumeMultiplier
		net.Start("SetMusicVolume")
		net.WriteString(musicType)
		net.WriteFloat(volume)
		net.Send(ply)
	end

	function initializeMusic(ply)
		if not activeMusic[ply] then
			activeMusic[ply] = {}
		end
		for musicType, filePath in pairs(musicFiles) do
			if not activeMusic[ply][musicType] then
				net.Start("InitializeMusic")
				net.WriteString(musicType)
				net.WriteString(filePath)
				net.Send(ply)
				local initialVolume = 0
				setMusicVolume(ply, musicType, initialVolume)
				activeMusic[ply][musicType] = musicType
			end
		end
	end

	local function isKillerLookingAt(ply, killer)
		local directionToPlayer = (ply:GetPos() - killer:GetPos()):GetNormalized()
		local killerViewDirection = killer:GetAimVector()
		local angleBetween = math.deg(math.acos(directionToPlayer:Dot(killerViewDirection)))
		return angleBetween <= viewAngleThreshold and killer:Visible(ply)
	end

	local function isPlayerMoving(ply)
		return ply:GetVelocity():Length() > 5
	end
	
	local function isStealthKiller(ply)
		return table.HasValue(stealthKillers, ply)
	end

	local function isPlayerRunning(ply)
		return ply:GetVelocity():Length() > ply:GetRunSpeed() * 0.9
	end

	local function updateTerrorRadiusMusic(ply, killer, killerChasing)
		if !IsValid(ply) or !IsValid(killer) then return end
		local distance = ply:GetPos():Distance(killer:GetPos())
		if ply:Team() ~= TEAM_SPECTATOR then
			initializeMusic(ply)
		end
		local killerInNoclip = (killer:GetMoveType() == MOVETYPE_NOCLIP)
		if ply:Team() == TEAM_SPECTATOR then
			for musicType, _ in pairs(musicFiles) do
				setMusicVolume(ply, musicType, 0)
			end
			return
		end
		if ply == killer then
			if killerChasing and not killerInNoclip then
				if isStealthKiller(killer) and not isPlayerRunning(killer) then return end
				setMusicVolume(ply, "chase", 1)
			else
				setMusicVolume(ply, "chase", 0)
			end
			return
		end
		if killerInNoclip and distance < terrorRadiusFar then
			setMusicVolume(ply, "chase", 0)
			setMusicVolume(ply, "killer_far", 1)
			setMusicVolume(ply, "killer_approaching", 0)
			setMusicVolume(ply, "killer_close", 0)
			return
		end
		if isChasing[ply] and isPlayerRunning(killer) then
			setMusicVolume(ply, "chase", 1)
			setMusicVolume(ply, "killer_far", 0)
			setMusicVolume(ply, "killer_approaching", 0)
			setMusicVolume(ply, "killer_close", 0)
		else
			local musicTracks = {"chase", "killer_far", "killer_approaching", "killer_close"}
			for _, track in ipairs(musicTracks) do
				setMusicVolume(ply, track, 0)
			end
			if distance <= terrorRadiusFar and distance > terrorRadiusApproaching then
				if isStealthKiller(killer) and not isPlayerRunning(killer) then return end
				setMusicVolume(ply, "killer_far", 1)
			elseif distance <= terrorRadiusApproaching and distance > terrorRadiusClose then
				if isStealthKiller(killer) and not isPlayerRunning(killer) then return end
				setMusicVolume(ply, "killer_approaching", 1)
			elseif distance <= terrorRadiusClose then
				if isStealthKiller(killer) and not isPlayerRunning(killer) then return end
				setMusicVolume(ply, "killer_close", 1)
			end
		end
	end

	local function updateTerrorRadiusMusicMulti(ply)
		local killers = currentKillers
		if #killers == 0 then
			for musicType, _ in pairs(musicFiles) do
				setMusicVolume(ply, musicType, 0)
			end
			return
		end
		local nearestKiller = nil
		local minDistance = math.huge
		for _, killer in ipairs(killers) do
			local dist = ply:GetPos():Distance(killer:GetPos())
			if dist < minDistance then
				minDistance = dist
				nearestKiller = killer
			end
		end
		if nearestKiller then
			checkChase(ply, nearestKiller)
			updateTerrorRadiusMusic(ply, nearestKiller, isChasing[ply])
		end
	end

	function checkChase(ply, killer)
		local distance = ply:GetPos():Distance(killer:GetPos())
		local killerMoving = isPlayerMoving(killer)
		local playerMoving = isPlayerMoving(ply)
		if distance < terrorRadiusClose and isKillerLookingAt(ply, killer) and killerMoving and playerMoving then
			isChasing[ply] = true
			if chaseTimers[ply] then
				timer.Remove(chaseTimers[ply])
				chaseTimers[ply] = nil
			end
		elseif isChasing[ply] then
			if not chaseTimers[ply] then
				chaseTimers[ply] = "ChaseEndTimer_" .. ply:EntIndex()
				timer.Create(chaseTimers[ply], 5, 1, function()
					isChasing[ply] = false
				end)
			end
		end
	end

	local function shouldActivateTerrorRadius()
		return team.NumPlayers(2701) > 0
	end

	hook.Add("Think", "UpdateTerrorRadiusForTeamsMulti", function()
		if not shouldActivateTerrorRadius() then return end
		for _, ply in player.Iterator() do
			if ply:Team() ~= 2701 and ply:Team() ~= TEAM_SPECTATOR then
				updateTerrorRadiusMusicMulti(ply)
			end
		end
		for _, killer in ipairs(currentKillers) do
			local killerChasing = false
			for _, ply in player.Iterator() do
				if ply ~= killer and ply:Team() ~= 2701 and ply:Team() ~= TEAM_SPECTATOR then
					if isChasing[ply] then
						killerChasing = true
						break
					end
				end
			end
			updateTerrorRadiusMusic(killer, killer, killerChasing)
		end
	end)

	local animatronicThemes = {
		["pill_wfoxy2"] = "legion",
		["pill_endo02"] = "oni",
		["pill_wbonnie2"] = "tank",
		["pill_wfreddy2"] = "default",
		["pill_wchica2"] = "koreanon",
		["pill_sfreddy2"] = "pyramid",
		["pill_clown"] = "myers",
		["pill_springtrap"] = "springtrap",
		["pill_plushtrap"] = "springtrap"
	}

	local function setAnimatronicTheme(killer)
		if not IsValid(killer) then return end
		local ent = pills.getMappedEnt(killer)
		if not IsValid(ent) then return end
		local modelName = ent.formTable.name
		local theme = animatronicThemes[modelName] or "default"
		if modelName == "pill_springtrap" then 
			table.insert(stealthKillers, killer)
		end
		setCurrentTheme(theme)
	end

	hook.Add("fh_poststartgame", "fh_setup_terror_radius", function(roundType, animatronics)
		currentKillers = {}
		stealthKillers = {}
		if table.Count(animatronics) == 1 then
			for ply, _ in pairs(animatronics) do
				setAnimatronicTheme(ply)
				table.insert(currentKillers, ply)
			end
		elseif table.Count(animatronics) > 1 then
			for ply, _ in pairs(animatronics) do
				table.insert(currentKillers, ply)
			end
			setCurrentTheme("default")
		end
	end)
	
	hook.Add("PlayerChangedTeam", "fh_terror_stop_changeteam", function(ply, oldTeam, newTeam)
		if table.HasValue(currentKillers, ply) and newTeam ~= 2701 then
			for i, killer in ipairs(currentKillers) do
				if killer == ply then
					table.remove(currentKillers, i)
					break
				end
			end

			for _, p in player.Iterator() do
				if activeMusic[p] then
					for musicType, _ in pairs(activeMusic[p]) do
						net.Start("StopMusic")
						net.WriteString(musicType)
						net.Send(p)
					end
					activeMusic[p] = nil
				end
			end
		end
		if not table.HasValue(currentKillers, ply) and newTeam == 2701 and roundActive and !roundEnding then
			table.insert(currentKillers, ply)
			setAnimatronicTheme(ply)
		end
	end)
	
	hook.Add("PlayerDeath", "StopTerrorMusicOnDeath", function(victim, inflictor, attacker)
		if not IsValid(victim) then return end

		if activeMusic[victim] then
			for musicType, _ in pairs(activeMusic[victim]) do
				net.Start("StopMusic")
				net.WriteString(musicType)
				net.Send(victim)
			end
			activeMusic[victim] = nil
		end

		isChasing[victim] = false

		if chaseTimers[victim] then
			timer.Remove(chaseTimers[victim])
			chaseTimers[victim] = nil
		end
	end)
end

if CLIENT then
	local activeMusic = {}
	
	net.Receive("InitializeMusic", function()
		local musicType = net.ReadString()
		local filePath = net.ReadString()
	
		if activeMusic[musicType] then
			activeMusic[musicType]:Stop()
		end
	
		activeMusic[musicType] = CreateSound(LocalPlayer(), filePath)
		activeMusic[musicType]:SetSoundLevel(0)
		activeMusic[musicType]:PlayEx(0, 100)
	end)
	
	net.Receive("SetMusicVolume", function()
		local musicType = net.ReadString()
		local volume = net.ReadFloat()
	
		if activeMusic[musicType] then
			activeMusic[musicType]:ChangeVolume(volume, 0.1)
		end
	end)
	
	net.Receive("StopMusic", function()
		local musicType = net.ReadString()
	
		if activeMusic[musicType] then
			activeMusic[musicType]:Stop()
			activeMusic[musicType] = nil
		end
	end)
end