fh = fh or {}

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

AddCSLuaFile( "cl_admin.lua" )
AddCSLuaFile( "cl_halo.lua" )
AddCSLuaFile( "cl_playerlist.lua" )
AddCSLuaFile( "cl_horror.lua" )
AddCSLuaFile( "cl_hud.lua" )
AddCSLuaFile( "cl_nightvision.lua" )
AddCSLuaFile( "cl_spechud.lua" )
AddCSLuaFile( "cl_sound.lua" )
AddCSLuaFile( "cl_timer.lua" )
AddCSLuaFile( "cl_optionmenu.lua" )

AddCSLuaFile( "animsoundf2.lua" )
AddCSLuaFile( "voicelines.lua" )

include( "sv_admin.lua" )
include( "sv_halo.lua" )
include( "sv_spectate.lua" )
include( "sv_nostuck.lua" )
include( "sv_ragdolls.lua" )
include( "sv_logs.lua" )
include( "stats.lua" )

include( "mount/push.lua" )

include( "mount/proximity.lua" )
AddCSLuaFile( "mount/proximity.lua" )

include( "terror_radius.lua" )
AddCSLuaFile( "terror_radius.lua" )

include( "pill_fnaf2.lua" )
include( "pill_fnaf3.lua" )

util.AddNetworkString("KillerPicked")
util.AddNetworkString("ApplyKiller")
util.AddNetworkString("RemoveKiller")

util.AddNetworkString("nv_off")
util.AddNetworkString("nv_on")

util.AddNetworkString("fh_initpostentity")

util.AddNetworkString("fh_hl_teammates")
util.AddNetworkString("fh_uhl_teammates")

util.AddNetworkString("fh_net_display")

util.AddNetworkString("fh_update_list")

util.AddNetworkString("fh_chat_message")

util.AddNetworkString("fh_start_lobby_timer")
util.AddNetworkString("fh_start_game_timer")
util.AddNetworkString("fh_timer_cutback")
util.AddNetworkString("ResetTimer")

util.AddNetworkString( "DeadHUDEnable" )
util.AddNetworkString( "DeadHUDChange" )
util.AddNetworkString( "DeadHUDDisable" )
util.AddNetworkString( "DeadHUDChangeString" )

util.AddNetworkString("AnimatronicsWin")
util.AddNetworkString("SurvivorsWin")

util.AddNetworkString("fh_let_killers_choose")
util.AddNetworkString("fh_selected_killer")
util.AddNetworkString("fh_update_killer_selector")

util.AddNetworkString("fh_share_notprefered")

util.AddNetworkString("fh_selector_nomore")

util.AddNetworkString("fh_animatronic_left_chatmessage")

function fh.randomChoice(t)
    return t[math.random(#t)]
end

lastKillers = lastKillers or {}

lobbyDuration = 120
gameDuration = 600
setupGameDuration = 60

curMaxKillers = 1

local animatronics_win_count = 0
local survivors_win_count = 0

local roundCount = 0

postGameOn = true -- используется только до начала первого раунда
isGameOn = false -- начинается прямо под регистрацию раунда и заканчивается после 5 секунд конца раунда
roundEnding = false -- концовка раунда

--[[
	0 - обыкновенный раунд
	1 - спрингтрап
]]--
local roundType = 0

alivePlayers = {}
animatronics = {}
survivors = {}

usedKillers = {}

local gifts_can_spawn = true

function assignKillers()
    local players = player.GetAll()
    local totalPlayers = #players

    if totalPlayers >= 48 then
        curMaxKillers = 5
    elseif totalPlayers >= 28 then
        curMaxKillers = 4
    elseif totalPlayers >= 18 then
        curMaxKillers = 3
    elseif totalPlayers >= 8 then
        curMaxKillers = 2
    elseif totalPlayers >= 1 then
        curMaxKillers = 1
    end
	
    local availableKillers = table.GetKeys(getAllPreferables(curMaxKillers > 1))
	
	for k, v in pairs(lastKillers) do
		table.RemoveByValue(players, k)
	end
	
    for i = 1, curMaxKillers do
		players = fh.GetEarnedKillers(players)
		
		local chosenPlayer = fh.randomChoice(players)
		table.RemoveByValue(players, chosenPlayer)
		
		animatronics[chosenPlayer] = true
		survivors[chosenPlayer] = nil
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:Freeze(true)
		chosenPlayer:SetTeam(2701)
		
		chosenPlayer:Spawn()
		
		if chosenPlayer:IsBot() then
			giveRandomKiller(chosenPlayer, true)
		end
    end
	
	for v, _ in pairs(animatronics) do
		if !lastKillers[v] then
			lastKillers[v] = 0
		end
	
		net.Start("fh_let_killers_choose")
		net.WriteTable(availableKillers)
		net.Send(v)
	end
	
	timer.Create("UnfrozeAnimatronics", setupGameDuration, 1, function()
		for ply, _ in pairs( animatronics ) do
			ply.lobbyFreeze = nil
			ply:Freeze(false)
		end
		roundActive = true
		LogEvent(" ")
        LogEvent("(*АВТО*) - Все аниматроники разморожены, раунд начат.")
		
		hook.Run("fh_poststartgame", roundType, animatronics)
    end)
	
end

function giveKiller(player, killer, force)
	force = force or false
	
	local ply = player
	
	local killers = getAllKillers()
	
	local killerData
	local command
	
	for k, v in pairs(killers) do
		if v.name == killer or k == killer then
			killerData = killers[k]
			command = k
		end
	end
	
	if !killerData then return end
	
	if !force then
		if usedKillers[command] then return end
		
		for _, v in pairs(usedKillers) do
			if ply == v then return end
		end
	end
		
	usedKillers[command] = ply

	RunConsoleCommand("pk_pill_apply", ply:Nick(), command)
	
	ply:Spawn()
	
	animatronics[ply] = true
	survivors[ply] = nil
	
    LogEvent("🤖 Игроку **" .. ply:Nick() .. "** выдан **" .. killerData.name.."**")

    net.Start("KillerPicked")
    net.WriteUInt(1, 8)
    net.WriteString(ply:Nick())
    net.WriteString(killerData.fullname)
    net.WriteColor(killerData.color)
    net.Broadcast()
	
	if timer.Exists("UnfrozeAnimatronics") then
		ply.lobbyFreeze = true
		ply:Freeze(true)
	end
end

function setupPlayerVars(ply)
	ply:AllowFlashlight(true)
	ply:SetRunSpeed(420)
	ply:SetJumpPower(200)
	ply:SetDuckSpeed(0.1)
	ply:SetUnDuckSpeed(0.1)
	ply:SetStepSize(18)
	ply:UnLock()
	ply:SetFOV(0)
	ply:SetViewEntity(ply)
	
	ply:SetJumpBoostMultiplier(1)
end

function endGame(killerVictory)
	killerVictory = killerVictory or false

	roundEnding = true
	
	RunConsoleCommand("proximity_enabled", 0)
	
    net.Start("ResetTimer")
    net.Broadcast()
	
	if timer.Exists("UnfrozeAnimatronics") then
		timer.Remove("UnfrozeAnimatronics")
	end
	
	if timer.Exists("RandomGifts") then
		timer.Remove("RandomGifts")
	end
		
	for k,v in pairs(lastKillers) do
		if !IsValid(k) then continue end
		
		lastKillers[k] = v + 1
		
		if lastKillers[k] > 5 then
			table.RemoveByValue(lastKillers, k)
		end
	end
	
	if killerVictory then
		local win_camera = ents.FindByClass("fh_win_camera")[1]
		local win_location = ents.FindByClass("info_killer_win")[1]
		local springtrap_ply = usedKillers["pill_springtrap"]
				
		if IsValid(win_location) and IsValid(win_camera) then
			
			if roundType == 1 and springtrap_ply then
					
				hook.Add("SetupPlayerVisibility", "fh_pvs", function(ply, viewent)
					if !IsValid(win_camera) then
						hook.Remove("SetupPlayerVisibility", "fh_pvs")
						return
					end
					AddOriginToPVS(win_camera:GetPos())
				end)
				
				timer.Simple(0.5, function()
					for _, p in ipairs(player.GetAll()) do
						p:ScreenFade( SCREENFADE.OUT, Color( 0, 0, 0, 255 ), 0.5, 0 )
					end
				end)
				
				timer.Simple(1, function()
					local ent = pills.getMappedEnt(springtrap_ply)
					
					springtrap_ply:SetPos(win_location:GetPos())
					springtrap_ply:SetEyeAngles(win_location:GetAngles())
					springtrap_ply:SetRenderAngles(win_location:GetAngles())
					ent:SetAngles(win_location:GetAngles())
					
					for _, p in ipairs(player.GetAll()) do
						p:SetViewEntity(win_camera)
						p:SetFOV(65, 2)
						
						p:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 255 ), 1, 0 )
						
						--[[
						if p:GetObserverMode() == OBS_MODE_IN_EYE then
							ply:Spectate(OBS_MODE_CHASE)
						end
						]]--
					end
					
					net.Start("fh_play_sound")
					net.WriteString("music/rampage.wav")
					net.Broadcast()
					
					timer.Simple(0.01, function()
						ent:PillAnim("egypt", true)
						springtrap_ply:Lock()
						ent.animLoop = true
						
						-- ну ещё раз на всякий
						springtrap_ply:SetEyeAngles(win_location:GetAngles())
						springtrap_ply:SetRenderAngles(win_location:GetAngles())
						ent:SetAngles(win_location:GetAngles())
					end)
				end)
			end
		end
	end
	
	hook.Run("fh_postendgame", killerVictory, animatronics)
	
	timer.Create("endGameWait", 10, 1, function() 
		game.CleanUpMap( false )
		
		fh_win_coefficient()
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
		
		isGameOn = false
		roundActive = false
		
		table.Empty(usedKillers)
		
		for _, ply in player.Iterator() do
			ply:SetTeam(TEAM_UNASSIGNED)
			ply:Spawn()
			setupPlayerVars(ply)
			if ply:HasWeapon("weapon_taser") then
				ply:StripWeapon("weapon_taser")
			end
		end
		postGameTimer()
		
		restoreAnimatronics()

        timer.Create("GameStartTimer", lobbyDuration, 1, function()
            registerNewRound()
			roundEnding = false
        end)
		
		RunConsoleCommand("proximity_enabled", 1)
		
	end )
end

function postGameTimer()
    net.Start("fh_start_lobby_timer")
	net.WriteFloat(lobbyDuration)
    net.Broadcast()
end

function GM:fh_prestartgame()
end

function GM:fh_poststartgame()
end

function GM:fh_postendgame()
end

function startGame()
	RunConsoleCommand("proximity_enabled", 1)
	
	roundType = math.random(1,10) > 7 and player.GetCount() < 16 and 1 or 0
	local springtrapRound = roundType == 1 and true or false
	
	if timer.Exists("endGameWait") then
		timer.Remove("endGameWait")
	end
	
	if conVars.fh_gifts_spawning:GetBool() then
		doGiftSpawning()
	end
	
	local fh_prestartgame = hook.Run("fh_prestartgame", roundType)
	
	if fh_prestartgame != nil and fh_prestartgame == false then 
		return 
	end
	
	if roundType == 0 then
	
		assignKillers()
		roundType = 0
		
	else
	
		roundType = 1
	
		local players = player.GetAll()
	
		for k, v in pairs(lastKillers) do
			table.RemoveByValue(players, k)
		end
		
		fh.GetEarnedKillers(players)
		
		local chosenPlayer = fh.randomChoice(players)
		
		giveKiller(chosenPlayer, 'pill_springtrap', true)
		
		animatronics[chosenPlayer] = true
		survivors[chosenPlayer] = nil
		
		chosenPlayer:Freeze(true)
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:SetTeam(2701)
		
		chosenPlayer:Spawn()
		
		if !lastKillers[chosenPlayer] then
			lastKillers[chosenPlayer] = 0
		end
		
		timer.Create("fh_unfreeze_springtrap", setupGameDuration, 1, function()
			for ply, _ in pairs( animatronics ) do
				ply.lobbyFreeze = nil
				ply:Freeze(false)
			end
			roundActive = true
			LogEvent(" ")
			LogEvent("(*АВТО*) - Спрингтрап разморожен, раунд начат.")
		
			hook.Run("fh_poststartgame", roundType, animatronics)
		end)
	end
	
	hook.Run("fh_startgame", roundType, springtrapRound)
	
	local random_taser = team.GetPlayers( TEAM_UNASSIGNED )
	local random_taserer = fh.randomChoice( random_taser )
	
	if IsValid(random_taserer) then
		random_taserer:Give("weapon_taser")
		random_taserer:SendLua( "LocalPlayer():ChatPrint(language.GetPhrase('fazhunt.give_taser'))" )
	end
	
    net.Start("fh_start_game_timer")
	net.WriteFloat(gameDuration)
	net.WriteFloat(setupGameDuration)
	net.WriteString("ambient/alarms/warningbell1.wav")
	net.WriteString(tostring(roundCount))
    net.Broadcast()
	
	net.Start('fh_adv_sound_play')
	net.WriteString(!springtrapRound and 'music/first_minute.wav' or 'music/freeze_timer_springtrap.wav')
	net.Broadcast()
	
	timer.Create("EndGameTimer", gameDuration + setupGameDuration, 1, function()
		survivorsWin()
    end)
end

function resetGameTimer()
    net.Start("ResetTimer")
    net.Broadcast()
end

function registerNewRound()
	if timer.Exists("GameStartTimer") then
		timer.Remove("GameStartTimer")
	end
	roundCount = roundCount + 1
	
	postGameOn = false
	isGameOn = true
	roundEnding = false
	table.Empty(alivePlayers)
	table.Empty(survivors)
	table.Empty(animatronics)
    for _, ply in player.Iterator() do
        ply:Spawn()
		survivors[ply] = true
    end
	LogEvent(" ")
	
	restoreAnimatronics()
	startGame()
end

function restoreAnimatronics()
	if !table.IsEmpty(animatronics) then
		for ply, _ in pairs(animatronics) do
			RunConsoleCommand("pk_pill_restore", ply:Nick())
		end
	end
	
	if !table.IsEmpty(team.GetPlayers(2701)) then
		for ply, _ in pairs(team.GetPlayers(2701)) do
			RunConsoleCommand("pk_pill_restore", ply:Nick())
		end
	end
end

function doGiftSpawning()
	if timer.Exists('RandomGifts') then return end
	local random_num1 = 110
	local random_num2 = 160
	timer.Create("RandomGifts", fh_random_time(random_num1, random_num2), 0, function()
		fh_spawnGifts()
		timer.Adjust("RandomGifts", fh_random_time(random_num1, random_num2), nil, nil)
	end)
end

function fh_spawnGifts()
	for ply, _ in pairs(survivors) do
		if math.random(1, 100) <= 77 and (ply:Alive() and ply:Team() != TEAM_SPECTATOR) then
			timer.Simple(math.random(1, 12), function()
				if !IsValid(ply) or ply:Team() == TEAM_SPECTATOR or !ply:Alive() then return end
				local gift = ents.Create("fh_gift")
				gift:SetPos(ply:GetPos() + Vector(0, 0, 10))
				gift:SetOwner(ply)
				gift:Spawn()
			end)
		end
	end
end

function disableGiftSpawning()
	game.ConsoleCommand("fh_gifts_spawning 0\n")
	
	if timer.Exists("RandomGifts") then
		timer.Remove("RandomGifts")
	end
end

function fh_random_time(num1, num2)
	return math.random(num1, num2)
end

hook.Add( "Initialize", "fh_init", function()
	RunConsoleCommand('sv_noclipspeed', 2)
	RunConsoleCommand('mp_show_voice_icons', 0)
	
	table.Empty(lastKillers)
	
	-- выделенный сервер не включает таймер. пробую делать вот так
	postGameOn = true
	isGameOn = false
	roundEnding = false
	
	if timer.Exists("GameStartTimer") then
		timer.Remove("GameStartTimer")
	end
end )

hook.Add("PlayerInitialSpawn", "fh_ply_spawn", function(ply)
	setupPlayerVars(ply)
	
	if isGameOn then
		timer.Simple(0, function()
			ply:KillSilent()
			
			ply:StripWeapons()
			ply:Spectate(OBS_MODE_CHASE)
			ply:SetTeam(TEAM_SPECTATOR)
		
			net.Start('DeadHUDEnable')
			net.Send(ply)
		end)
	
		survivors[ply] = nil
		alivePlayers[ply] = nil
	end
end)

hook.Add( "AllowPlayerPickup", "fh_allow_pickup", function( ply, ent )
    return ply:Team() != TEAM_SPECTATOR
end )

hook.Add("SetupMove", "fh_lock_position", function(ply, mv, cmd)
	if (ply:Team() == 2701 or animatronics[ply]) and !roundActive and isGameOn then
		mv:SetVelocity(vector_origin)
		mv:SetOrigin(ply:GetPos())
	end
end)
hook.Add("PlayerPostThink", "fh_zero_physics", function(ply)
	if (ply:Team() == 2701 or animatronics[ply]) and not roundActive and isGameOn then
		ply:SetVelocity(-ply:GetVelocity())
	end
end)

hook.Add("FinishMove", "fh_canmove", function(ply)
	if (ply:Team() == 2701 or animatronics[ply]) and !roundActive and isGameOn then
		return true
	end
end)

hook.Add("PlayerDisconnected", "fh_playerleft", function(ply)
	survivors[ply] = nil
	if animatronics[ply] then
		animatronics[ply] = nil
		if isGameOn and !roundEnding then
			net.Start("fh_animatronic_left_chatmessage")
			net.WriteString(ply:Nick())
			net.Broadcast()
		end
	end
	alivePlayers[ply] = nil
	
	animatronicsLeft_check()
	
    if player.GetCount() == 1 and isGameOn then
        resetGameTimer()
        if timer.Exists("GameStartTimer") then
            timer.Remove("GameStartTimer")
        end
        if timer.Exists("EndGameTimer") then
            timer.Remove("EndGameTimer")
        end
    end
end)

hook.Add( "PlayerNoClip", "fh_noclip", function( ply, desiredNoClipState )
	if ply:IsAdmin() and ply:Team() != 2701 then
		return true
	end
end )

hook.Add("PlayerSpawn", "fh_spawn", function(ply)
	player_manager.SetPlayerClass( ply, "player_sandbox" )
	ply:SetShouldServerRagdoll(true)
	
	ply:SendLua( 'if !system.HasFocus() then system.FlashWindow() end' )
	
	if !alivePlayers[ply] then
		alivePlayers[ply] = true
		ply:SetTeam(TEAM_UNASSIGNED)
	end
	net.Start('DeadHUDDisable')
	net.Send(ply)
	
	net.Start('nv_off')
	net.Send(ply)
	
	if IsValid(ply.DeathRagdoll) then
		ply.DeathRagdoll:Remove()
	end
end)

hook.Add("PlayerDeath", "fh_deaths", function( victim, inflictor, attacker )
	if survivors[victim] then
		survivors[victim] = nil
		
		if attacker:IsPlayer() and victim != attacker then
			LogEvent("☠️ Игрок **" .. attacker:Nick() .. "** убил **" .. victim:Nick().."**")
		else
			LogEvent("☠️ **"..victim:Nick() .. "** просто умер. ( " .. tostring(attacker).." )")
		end
		
		if isGameOn and !roundEnding and table.Count(survivors) == 1 and table.Count(animatronics) >= 2 and timer.TimeLeft("EndGameTimer") >= 200 then
			net.Start("fh_timer_cutback")
			net.WriteFloat(180)
			net.WriteString("round/time_cutback.mp3")
			net.Broadcast()
			
			timer.Adjust("EndGameTimer", 180)
		end
		
		animatronicsVictory_check(victim)
	end
	animatronics[victim] = nil
	alivePlayers[victim] = nil
	
	animatronicsDied_check()
	
	if isGameOn then
		victim:Spectate(OBS_MODE_CHASE)
		victim:SetTeam(TEAM_SPECTATOR)
		
		net.Start('DeadHUDEnable')
		net.Send(victim)
	end
	
    local ent = pills.getMappedEnt(attacker)
	
	if IsValid(victim:GetRagdollEntity()) then
		victim:GetRagdollEntity():Remove()
	end
end)

function fh_get_plytable_nicknames(tbl)
	tbl = tlb or {}
	local ret_tbl = {}
	for ply, _ in pairs(tbl) do
		table.insert(ret_tbl, ply:Nick())
	end
	
	return ret_tbl
end

function fh_win_coefficient()
    local totalWins = survivors_win_count + animatronics_win_count
    if totalWins == 0 then return end

    local survivorsPercentage = math.Round((survivors_win_count / totalWins) * 100)
    local animatronicsPercentage = math.Round((animatronics_win_count / totalWins) * 100)

    local message = "Коэффициент побед: Выжившие (" .. survivorsPercentage .. "%) / Аниматроники (" .. animatronicsPercentage .. "%)"
	local log_embed_table = {survivorsPercentage, animatronicsPercentage, totalWins, animatronics_win_count, survivors_win_count}
	LogEmbedEvent(message, "stats", log_embed_table)
end

function animatronicsVictory_check(last_ply)
	if table.IsEmpty(survivors) and !roundEnding then
	
		net.Start("AnimatronicsWin")
		net.WriteString(last_ply:Nick())
		net.Broadcast()
		
		endGame(true)
		
		LogEvent(" ")
		
		local log_embed_table = { last_ply:Nick(), formatTime((gameDuration + setupGameDuration) - (timer.TimeLeft("EndGameTimer") or 0)), fh_get_plytable_nicknames(animatronics) }
		
		timer.Simple(1, function()
			LogEmbedEvent("Победа аниматроников.", "anims_win", log_embed_table)
		end)
		animatronics_win_count = animatronics_win_count + 1
		
		if timer.Exists("EndGameTimer") then
			timer.Remove("EndGameTimer")
		end
	
	end
end

function animatronicsDied_check()
	if table.IsEmpty(animatronics) and isGameOn and !roundEnding then
		local plys = {}
		for ply, _ in pairs(survivors) do
			table.insert(plys, ply:Nick())
		end
		
		net.Start('fh_net_scarysound')
		net.WriteBool(false)
		net.Broadcast()
		
		net.Start("SurvivorsWin")
		net.WriteTable(plys)
		net.Broadcast()
		
		LogEvent(" ")
		
		local log_embed_table = { fh_get_plytable_nicknames(survivors), {'Сдохли.'} }
		
		timer.Simple(1, function()
			LogEmbedEvent("Все аниматроники умерли. Победа выживших.", "survs_win", log_embed_table)
		end)
			
		survivors_win_count = survivors_win_count + 1
			
		endGame()
	end
end

function animatronicsLeft_check()
	if table.IsEmpty(animatronics) and isGameOn and !roundEnding then
		local plys = {}
		for ply, _ in pairs(survivors) do
			table.insert(plys, ply:Nick())
		end
		
		net.Start('fh_net_scarysound')
		net.WriteBool(false)
		net.Broadcast()
		
		net.Start("SurvivorsWin")
		net.WriteTable(plys)
		net.Broadcast()
		
		LogEvent(" ")
		
		local log_embed_table = { fh_get_plytable_nicknames(survivors), {'все ливнули.'} }
		
		timer.Simple(1, function()
			LogEmbedEvent("Все аниматроники вышли из игры. Победа выживших.", "survs_win", log_embed_table)
		end)
			
		survivors_win_count = survivors_win_count + 1
			
		endGame()
	end
end

function survivorsWin()
	local plys = {}
	for ply, _ in pairs(survivors) do
		table.insert(plys, ply:Nick())
	end
	
	net.Start('fh_net_scarysound')
	net.WriteBool(false)
	net.Broadcast()
	
	net.Start("SurvivorsWin")
	net.WriteTable(plys)
	net.Broadcast()
	
	LogEvent(" ")
	
	local log_embed_table = { fh_get_plytable_nicknames(survivors), fh_get_plytable_nicknames(animatronics) }
	
	timer.Simple(1, function()
		LogEmbedEvent("Победа выживших.", "survs_win", log_embed_table)
	end)
		
	survivors_win_count = survivors_win_count + 1
		
	endGame()
end

hook.Add( "CreateEntityRagdoll", "fh_ragdoll_handle", function( ply, ragdoll )
	ragdoll:Remove()
end )

hook.Add( "CanPlayerSuicide", "fh_suicide", function( ply )
	if ply:Team() == 2701 or ply.jumpscared then
		return false
	end
	if timer.TimeLeft( "EndGameTimer" ) > gameDuration then
		return false
	end
end )

hook.Add( "PlayerShouldTaunt", "fh_allow_taunt", function( ply )
	if ply:Team() == 2701 then
		return false
	end
end )

hook.Add( "PlayerShouldTakeDamage", "fh_shouldtakedamage", function( ply, attacker )
	if ply:IsPlayer() and attacker:IsPlayer() then
	
		if IsValid(attacker) and 
		(ply:Team() == attacker:Team() or 
		ply:Team() == 2701 and conVars.fh_animatronic_immortal:GetBool()
		or attacker:Team() == TEAM_SPECTATOR 
		or !roundActive or roundEnding) then
		
			return false
		end
	end
end )

hook.Add("PillApply", "fh_joinpill", function(ply, name)
	animatronics[ply] = true
	survivors[ply] = nil
	
	timer.Simple(1, function()
		net.Start("fh_hl_teammates")
		net.Broadcast()
	end)
		
	if !killerData[name] then return end
	
	local killer = killerData[name]
	
	name = killer.name
	local color = killer.color
	
	net.Start("ApplyKiller")
	net.WriteString(name)
	net.WriteColor(color)
	net.Send(ply)
end)

hook.Add("PlayerChangedTeam", "fh_jointeam", function(ply, oldteam, team)
	if team != 2701 then
		net.Start("RemoveKiller")
		net.Send(ply)
		
		net.Start("fh_uhl_teammates")
		net.Send(ply)
	end
end)

hook.Add("SetupPlayerVisibility", "fh_spec_pvs", function(ply)
    if ply:Team() == TEAM_SPECTATOR then
        local target = ply:GetObserverTarget()
        if IsValid(target) then
            AddOriginToPVS(target:GetPos())
        end
    end
end)

net.Receive("fh_selected_killer", function(len, ply)
	local killer = net.ReadString()
	
	if !usedKillers[killer] then
		giveKiller(ply, killer)
		
		for v, _ in pairs(animatronics) do
			net.Start("fh_update_killer_selector")
			net.WritePlayer(ply)
			net.WriteString(killer)
			net.Send(v)
		end
	end
end)

net.Receive("fh_selector_nomore", function(len, ply)
	giveRandomKiller(ply)
end)

function giveRandomKiller(ply, update)
	update = update or false
	
    local availableKillers = table.GetKeys(getAllPreferables(curMaxKillers > 1))
	
	for k, v in pairs(usedKillers) do
		if table.HasValue(availableKillers, k) then
			table.RemoveByValue(availableKillers, k)
		end
	end
	
	local killer = fh.randomChoice(availableKillers)
	
	giveKiller(ply, killer)
	
	if update then
		for v, _ in pairs(animatronics) do
			timer.Simple(0, function()
				net.Start("fh_update_killer_selector")
				net.WritePlayer(ply)
				net.WriteString(killer)
				net.Send(v)
			end)
		end
	end
end

net.Receive("fh_initpostentity", function(len, ply)
	if timer.Exists('EndGameTimer') then
		local timeLeft = timer.TimeLeft('EndGameTimer')
		
		net.Start('fh_start_game_timer')
		net.WriteFloat(timeLeft)
		net.WriteFloat(0)
		net.WriteString("")
		net.WriteString(tostring(roundCount))
		net.Send(ply)
	elseif timer.Exists('GameStartTimer') then
		local timeLeft = timer.TimeLeft('GameStartTimer')
		
		net.Start("fh_start_lobby_timer")
		net.WriteFloat(timeLeft)
		net.Send(ply)
	end
	if player.GetCount() >= 2 and not isGameOn and !timer.Exists("GameStartTimer") then
		postGameTimer()
	
		timer.Create("GameStartTimer", lobbyDuration, 1, function()
			registerNewRound()
			LogEvent(" ")
			LogEvent("(*АВТО*) - ⌛️ Таймер раунда начат. Количество игроков: "..table.Count(alivePlayers))
		end)
		
		lobbyDuration = 30
	end
	
	net.Start("fh_share_notprefered")
	net.WriteTable(getAllPreferables(true))
	net.Send(ply)
end)

local tm = nil
hook.Add("Tick", "fh_tick", function()
   for _, ply in player.Iterator() do
      tm = ply:Team()
      if tm == TEAM_UNASSIGNED and ply:Alive() then
         if ply:WaterLevel() == 3 then
            if ply:IsOnFire() then
               ply:Extinguish()
            end

            if ply.drowning then
               if ply.drowning < CurTime() then
                  local dmginfo = DamageInfo()
                  dmginfo:SetDamage(5)
                  dmginfo:SetDamageType(DMG_DROWN)
                  dmginfo:SetAttacker(game.GetWorld())
                  dmginfo:SetInflictor(game.GetWorld())
                  dmginfo:SetDamageForce(Vector(0,0,1))

                  ply:TakeDamageInfo(dmginfo)

                  ply.drowning = CurTime() + 1
               end
            else
               ply.drowning = CurTime() + 8
            end
         else
            ply.drowning = nil
         end

      elseif tm == TEAM_SPEC then
         if ply.propspec then
            PROPSPEC.Recharge(ply)

            if IsValid(ply:GetObserverTarget()) then
               ply:SetPos(ply:GetObserverTarget():GetPos())
            end
         end

         if ply:Alive() then
            self:SpectatorThink(ply)
         end
      end
   end
end)

--[[
concommand.Add( "dada3", function( ply, cmd, args )
	for _, ply in ipairs( player.GetAll() ) do
		ply:AddFlags( FL_ATCONTROLS )
	end
end)

hook.Add("SetupMove", "BlockQSlideForTeam2701", function(ply, mv, cmd)
    if ply:Team() == 2701 and ply:GetSliding() then
        ply:SetSliding(false)
        ply:SetSlidingTime(0)
    end
end)

hook.Add("StartCommand", "BlockQSlideCommand2701", function(ply, cmd)
    if ply:Team() == 2701 and ply:GetSliding() then
        cmd:ClearMovement()
        cmd:RemoveKey(IN_SPEED)
        cmd:RemoveKey(IN_JUMP)
        ply:SetSliding(false)
        ply:SetSlidingTime(0)
    end
end)
]]--

function fh.GetRoundCount()
	return roundCount
end

function fh.SetRoundType(int)
	roundType = int
end

function fh.GetActiveUsedKiller(killer)
	return usedKillers[killer]
end

function fh.GetRoundType()
	return roundType
end

function fh.GetEarnedKillers(players)
	if table.IsEmpty(players) and !table.IsEmpty(lastKillers) then
		local chosenLastKiller = nil
		local high = 0
		
		for k,v in pairs(lastKillers) do
			if !IsValid(k) then continue end
			if v >= high then
				chosenLastKiller = k
				high = v
			end
		end
		table.insert(players, chosenLastKiller)
		lastKillers[chosenLastKiller] = 0
	end
	
	if table.IsEmpty(players) then
		players = player.GetAll()
	end
	
	return players
end

hook.Add( "GetFallDamage", "FH_FallDamage", function(ply, speed)
	return math.min(speed / 35, 50)
end )