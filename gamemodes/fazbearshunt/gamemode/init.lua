AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

AddCSLuaFile( "cl_admin.lua" )
AddCSLuaFile( "cl_halo.lua" )
AddCSLuaFile( "cl_playerlist.lua" )
AddCSLuaFile( "cl_hud.lua" )
AddCSLuaFile( "cl_nightvision.lua" )
AddCSLuaFile( "cl_spechud.lua" )
AddCSLuaFile( "cl_horror.lua" )
AddCSLuaFile( "cl_timer.lua" )
AddCSLuaFile( "cl_optionmenu.lua" )

AddCSLuaFile( "animsoundf2.lua" )
AddCSLuaFile("pill_fnaf2.lua")

include( "sv_admin.lua" )
include( "sv_spectate.lua" )
include( "sv_nostuck.lua" )
include( "sv_ragdolls.lua" )
include( "sv_logs.lua" )

include( "mount/push.lua" )

include( "mount/proximity.lua" )
AddCSLuaFile( "mount/proximity.lua" )

include( "pill_fnaf2.lua" )

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

util.AddNetworkString("fh_selector_nomore")


function randomChoice(t)
    return t[math.random(#t)]
end

lastKillers = {}

lobbyDuration = 120
gameDuration = 600
setupGameDuration = 60

curMaxKillers = 1

local animatronics_win_count = 0
local survivors_win_count = 0

roundCount = 0

postGameOn = true -- используется только до начала первого раунда
isGameOn = false -- начинается прямо под регистрацию раунда и заканчивается после 5 секунд конца раунда
roundEnding = false -- концовка раунда

--[[
	0 - обыкновенный раунд
	1 - спрингтрап
]]--
roundType = 0

alivePlayers = {}
animatronics = {}
survivors = {}

usedKillers = {}

local gifts_can_spawn = true

function assignKillers()
    local players = player.GetAll()
    local totalPlayers = #players

    if totalPlayers >= 40 then
        curMaxKillers = 5
    elseif totalPlayers >= 24 then
        curMaxKillers = 4
    elseif totalPlayers >= 16 then
        curMaxKillers = 3
    elseif totalPlayers >= 8 then
        curMaxKillers = 2
    elseif totalPlayers >= 1 then
        curMaxKillers = 1
    end
	
    local availableKillers = table.GetKeys(killerInfo)
		
	if curMaxKillers > 1 then
		for k, v in pairs(duoKillerInfo) do
			table.insert(availableKillers, k)
		end
	end
	
	for k, v in pairs(lastKillers) do
		table.RemoveByValue(players, k)
	end
	
    for i = 1, curMaxKillers do
		if table.Count(players) == 0 and table.Count(lastKillers) > 0 then
			local chosenLastKiller = nil
			local high = 0
			
			for k,v in pairs(lastKillers) do
				if v >= high then
					chosenLastKiller = k
					high = v
				end
			end
			table.insert(players, chosenLastKiller)
			--table.RemoveByValue(lastKillers, chosenLastKiller)
			
			lastKillers[chosenLastKiller] = 0
		end
			
		local chosenPlayer = randomChoice(players)
		table.RemoveByValue(players, chosenPlayer)
		
		table.insert(animatronics, chosenPlayer)
		table.RemoveByValue(survivors, chosenPlayer)
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:SetTeam(2701)
		
		chosenPlayer:Spawn()
		
		if chosenPlayer:IsBot() then
			giveRandomKiller(chosenPlayer, true)
		end
    end
	
	for _, v in pairs(animatronics) do
		if !table.HasValue(lastKillers, v) then
			lastKillers[v] = 0
		end
	
		net.Start("fh_let_killers_choose")
		net.WriteTable(availableKillers)
		net.Send(v)
	end
	
	timer.Create("UnfrozeAnimatronics", setupGameDuration, 1, function()
		for _, ply in ipairs( animatronics ) do
			ply.lobbyFreeze = nil
		end
		roundActive = true
		LogEvent(" ")
        LogEvent("(*АВТО*) - Все аниматроники разморожены, раунд начат.")
    end)
	
end

function giveKiller(player, killer, force)
	force = force or false
	
	local ply = player
	
	local killers = getAllKillers()
	
	for k,v in pairs(springtrapInfo) do
		killers[k] = v
	end
	
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
	
	if !table.HasValue(animatronics, ply) then
		table.insert(animatronics, ply)
	end
	if table.HasValue(survivors, ply) then
		table.RemoveByValue(survivors, ply)
	end
	
    LogEvent("🤖 Игроку **" .. ply:Nick() .. "** выдан **" .. killerData.name.."**")

    net.Start("KillerPicked")
    net.WriteUInt(1, 8)
    net.WriteString(ply:Nick())
    net.WriteString(killerData.name)
    net.WriteColor(killerData.color)
    net.Broadcast()
	
	if timer.Exists("UnfrozeAnimatronics") then
		ply.lobbyFreeze = true
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
					
			hook.Add("SetupPlayerVisibility", "fh_pvs", function(ply, viewent)
				if !IsValid(win_camera) then
					hook.Remove("SetupPlayerVisibility", "fh_pvs")
					return
				end
				AddOriginToPVS(win_camera:GetPos())
			end)
			
			timer.Simple(0.5, function()
				if table.Count(team.GetPlayers(2701)) == 1 and springtrap_ply then
					for _, p in ipairs(player.GetAll()) do
						p:ScreenFade( SCREENFADE.OUT, Color( 0, 0, 0, 255 ), 0.5, 0 )
					end
				end
			end)
			
			timer.Simple(1, function()
				if table.Count(team.GetPlayers(2701)) == 1 and springtrap_ply then
					local ent = pk_pills.getMappedEnt(springtrap_ply)
					
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
				end
			end)
		end
	end
	
	timer.Create("endGameWait", 10, 1, function() 
		game.CleanUpMap( false )
		
		fh_win_coefficient()
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
		
		isGameOn = false
		roundActive = false
		
		table.Empty(usedKillers)
		
		for _, ply in pairs(player.GetAll()) do
			ply:SetTeam(TEAM_UNASSIGNED)
			ply:Spawn()
			setupPlayerVars(ply)
		end
		postGameTimer()
		
		restoreAnimatronics()

        timer.Create("GameStartTimer", lobbyDuration, 1, function()
            registerNewRound()
			roundEnding = false
        end)
		
	end )
end

function postGameTimer()
    net.Start("fh_start_lobby_timer")
	net.WriteFloat(lobbyDuration)
    net.Broadcast()
end

function startGame()
	local springtrapRound = math.random(1,10) > 3 and table.Count(player.GetAll()) < 16 and true or false
	
	if !springtrapRound then
	
		assignKillers()
		roundType = 0
		
	else
	
		roundType = 1
	
		local players = player.GetAll()
	
		for k, v in pairs(lastKillers) do
			table.RemoveByValue(players, k)
		end
		
		if table.Count(players) == 0 and table.Count(lastKillers) > 0 then
			local chosenLastKiller = nil
			local high = 0
			
			for k,v in pairs(lastKillers) do
				if v >= high then
					chosenLastKiller = k
					high = v
				end
			end
			table.insert(players, chosenLastKiller)
			table.RemoveByValue(lastKillers, chosenLastKiller)
		end
		
		local chosenPlayer = randomChoice(players)
		
		giveKiller(chosenPlayer, 'pill_springtrap', true)
		
		table.insert(animatronics, chosenPlayer)
		table.RemoveByValue(survivors, chosenPlayer)
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:SetTeam(2701)
		
		chosenPlayer:Spawn()
		
		if !table.HasValue(lastKillers, chosenPlayer) then
			lastKillers[chosenPlayer] = 0
		end
		
		timer.Create("fh_unfreeze_springtrap", setupGameDuration, 1, function()
			for _, ply in ipairs( animatronics ) do
				ply.lobbyFreeze = nil
			end
			roundActive = true
			LogEvent(" ")
			LogEvent("(*АВТО*) - Спрингтрап разморожен, раунд начат.")
		end)
	end
	
    net.Start("fh_start_game_timer")
	net.WriteFloat(gameDuration)
	net.WriteFloat(setupGameDuration)
	net.WriteInt(roundCount, 32)
    net.Broadcast()
	
	if timer.Exists("endGameWait") then
		timer.Remove("endGameWait")
	end
	
	if conVars.fh_gifts_spawning:GetBool() then
		doGiftSpawning()
	end
	
	net.Start('fh_adv_sound_play')
	net.WriteString(!springtrapRound and 'music/first_minute.wav' or 'music/freeze_timer_springtrap.wav')
	net.Broadcast()
	
	timer.Create("EndGameTimer", gameDuration + setupGameDuration, 1, function()
		local plys = {}
		for _, ply in pairs(survivors) do
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
	
	RunConsoleCommand("proximity_enabled", 1)
	
	postGameOn = false
	isGameOn = true
	roundEnding = false
	alivePlayers = {}
	survivors = {}
	animatronics = {}
    for _, ply in pairs(player.GetAll()) do
        ply:Spawn()
		table.insert(survivors, ply)
    end
	LogEvent(" ")
	
	startGame()
end

function restoreAnimatronics()
	if table.Count(animatronics) > 0 then
		for _, ply in ipairs(animatronics) do
			RunConsoleCommand("pk_pill_restore", ply:Nick())
		end
	end
	
	if table.Count(team.GetPlayers(2701)) > 0 then
		for _, ply in ipairs(team.GetPlayers(2701)) do
			RunConsoleCommand("pk_pill_restore", ply:Nick())
		end
	end
end

function doGiftSpawning()
	if timer.Exists('RandomGifts') then return end
	local random_num1 = 110
	local random_num2 = 165
	timer.Create("RandomGifts", fh_random_time(random_num1, random_num2), 0, function()
		fh_spawnGifts()
		timer.Adjust("RandomGifts", fh_random_time(random_num1, random_num2), nil, nil)
	end)
end

function fh_spawnGifts()
	for _, ply in ipairs(team.GetPlayers(TEAM_UNASSIGNED)) do
		if math.random(1, 100) <= 77 and (ply:Alive() and ply:Team() != TEAM_SPECTATOR) then
			timer.Simple(math.random(1, 12), function()
				if (!ply:Alive() or ply:Team() == TEAM_SPECTATOR) then return end
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
	return math.random(110, 165)
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
	
		if table.HasValue(survivors, ply) then
			table.RemoveByValue(survivors, ply)
		end
	
		if table.HasValue(alivePlayers, ply) then
			table.RemoveByValue(alivePlayers, ply)
		end
	end
end)

hook.Add( "AllowPlayerPickup", "fh_allow_pickup", function( ply, ent )
    return ply:Team() != TEAM_SPECTATOR
end )

hook.Add("FinishMove", "CanMove", function(ply)
	ply:SetCustomCollisionCheck(true)
	if (ply:Team() == 2701 or table.HasValue(animatronics, ply)) and !roundActive and isGameOn then
		return true
	end
end)

hook.Add("PlayerDisconnected", "PlayerLeft", function(ply)
	if table.HasValue(lastKillers, ply) then
		table.RemoveByValue(lastKillers, ply)
	end
	if table.HasValue(survivors, ply) then
		table.RemoveByValue(survivors, ply)
	end
	if table.HasValue(animatronics, ply) then
		table.RemoveByValue(animatronics, ply)
		if isGameOn then
			PrintMessage(HUD_PRINTTALK, "Аниматроник " .. ply:Nick() .. " вышел из игры.")
		end
	end
	if table.HasValue(alivePlayers, ply) then
		table.RemoveByValue(alivePlayers, ply)
	end
	
	animatronicsLeft_check()
	
    if #player.GetAll() == 1 and isGameOn then
        resetGameTimer()
        if timer.Exists("GameStartTimer") then
            timer.Remove("GameStartTimer")
        end
        if timer.Exists("EndGameTimer") then
            timer.Remove("EndGameTimer")
        end
    end
end)

hook.Add( "PlayerNoClip", "DisallowNoclip", function( ply, desiredNoClipState )
	if ply:IsAdmin() and ply:Team() != 2701 then
		return true
	end
end )

hook.Add("PlayerSpawn", "fh_spawn", function(ply)
	player_manager.SetPlayerClass( ply, "player_sandbox" )
	ply:SetShouldServerRagdoll(true)
	
	ply:SendLua( 'if !system.HasFocus() then system.FlashWindow() end' )
	
	if !table.HasValue(alivePlayers, ply) then
		table.insert(alivePlayers, ply)
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
	if table.HasValue(survivors, victim) then
		table.RemoveByValue(survivors, victim)
		
		if attacker:IsPlayer() and victim != attacker then
			LogEvent("☠️ Игрок **" .. attacker:Nick() .. "** убил **" .. victim:Nick().."**")
		else
			LogEvent("☠️ **"..victim:Nick() .. "** просто умер. ( " .. tostring(attacker).." )")
		end
		
		animatronicsVictory_check(victim)
	end
	if table.HasValue(animatronics, victim) then
		table.RemoveByValue(animatronics, victim)
	end
	
	animatronicsDied_check()
	
	if isGameOn then
		victim:Spectate(OBS_MODE_CHASE)
		if attacker:IsPlayer() then 
			victim:SpectateEntity(attacker)
		end
		victim:SetTeam(TEAM_SPECTATOR)
		
		net.Start('DeadHUDEnable')
		net.Send(victim)
	end
	
    local ent = pk_pills.getMappedEnt(attacker)
	
	if IsValid(victim:GetRagdollEntity()) then
		victim:GetRagdollEntity():Remove()
	end
	
	--[[
    if IsValid(victim) and victim:IsPlayer() and IsValid(ent) and string.match(ent:GetModel(), "([^/]+)%.mdl$") == 'oldbonnie' then
		local ragdoll = victim.DeathRagdoll
        if IsValid(ragdoll) then
            local forward = victim:GetAimVector()

            local impulse = forward * 50000

            local phys = ragdoll:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(impulse)
            end
        end
    end
	]]--
end)

function fh_get_plytable_nicknames(tbl)
	local ret_tbl = {}
	for _, ply in pairs(tbl) do
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
	if table.Count(survivors) == 0 and !roundEnding then
	
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
	if table.Count(animatronics) == 0 and isGameOn and !roundEnding then
		local plys = {}
		for _, ply in pairs(survivors) do
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
	if table.Count(animatronics) == 0 and isGameOn and !roundEnding then
		local plys = {}
		for _, ply in pairs(survivors) do
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

hook.Add( "CreateEntityRagdoll", "fh_ragdoll_handle", function( ply, ragdoll )
	ragdoll:Remove()
end )

hook.Add( "CanPlayerSuicide", "AllowOwnerSuicide", function( ply )
	if ply:Team() == 2701 then
		return false
	end
end )

hook.Add( "PlayerShouldTakeDamage", "AntiTeamkill", function( ply, attacker )
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

hook.Add("ShouldCollide", "CustomPlayerCollision", function(ent1, ent2)
    if ent1:GetCollisionGroup() == COLLISION_GROUP_WORLD 
	or ent2:GetCollisionGroup() == COLLISION_GROUP_WORLD 
	or (ent1:GetCollisionGroup() == COLLISION_GROUP_DEBRIS and ent1:IsPlayer()) -- s freddy
	or (ent1:GetCollisionGroup() == COLLISION_GROUP_PASSABLE_DOOR and ent1:IsPlayer() and ent2:IsPlayer())
	or (ent2:GetCollisionGroup() == COLLISION_GROUP_PASSABLE_DOOR and ent2:IsPlayer() and ent1:IsPlayer())
	then
        return false
    end
    return true
end)

hook.Add("PillApply", "fh_joinpill", function(ply, name)
	if !table.HasValue(animatronics, ply) then
		table.insert(animatronics, ply)
	end
	
	if table.HasValue(survivors, ply) then
		table.RemoveByValue(survivors, ply)
	end
	
	timer.Simple(1, function()
		net.Start("fh_hl_teammates")
		net.Broadcast()
	end)
		
	if !killerData[name] then return end
	
	name = killerData[name].name
	
	net.Start("ApplyKiller")
	net.WriteString(name)
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

hook.Add("Think", "UpdateObserverPosition", function()
    for _, ply in ipairs(team.GetPlayers(TEAM_SPECTATOR)) do
        if IsValid(ply:GetObserverTarget()) and ply:GetObserverMode() != OBS_MODE_ROAMING then
            ply:SetPos(ply:GetObserverTarget():GetPos())
        end
    end
end)

net.Receive("fh_selected_killer", function(len, ply)
	local killer = net.ReadString()
	
	if !usedKillers[killer] then
		giveKiller(ply, killer)
		
		for _, v in pairs(animatronics) do
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
    local availableKillers = table.GetKeys(killerInfo)
		
	if curMaxKillers > 1 then
		for k, v in pairs(duoKillerInfo) do
			table.insert(availableKillers, k)
		end
	end
	
	for k, v in pairs(usedKillers) do
		if table.HasValue(availableKillers, k) then
			table.RemoveByValue(availableKillers, k)
		end
	end
	
	local killer = randomChoice(availableKillers)
	
	giveKiller(ply, killer)
	
	if update then
		for _, v in pairs(animatronics) do
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
		net.WriteInt(roundCount, 32)
		net.Send(ply)
	elseif timer.Exists('GameStartTimer') then
		local timeLeft = timer.TimeLeft('GameStartTimer')
		
		net.Start("fh_start_lobby_timer")
		net.WriteFloat(timeLeft)
		net.Send(ply)
	end
	if #player.GetAll() >= 2 and not isGameOn and !timer.Exists("GameStartTimer") then
		postGameTimer()
	
		timer.Create("GameStartTimer", lobbyDuration, 1, function()
			registerNewRound()
			LogEvent(" ")
			LogEvent("(*АВТО*) - ⌛️ Таймер раунда начат. Количество игроков: "..table.Count(alivePlayers))
		end)
		
		lobbyDuration = 30
	end
end)

hook.Add( "PlayerSay", "fh_chat_messages", function( ply, text, teamChat )
	net.Start("fh_chat_message")
	net.WriteString(ply:Nick())
	net.WriteString(text)
	net.WriteBool(ply:Team() == TEAM_SPECTATOR or !ply:Alive())
	net.WriteColor(teamColors[ply:Team()])
	
	net.WriteBool(teamChat)
	net.WriteFloat(ply:Team())
	net.Broadcast()
	
	return ""
end )
