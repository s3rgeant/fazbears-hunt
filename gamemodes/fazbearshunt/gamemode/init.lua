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

AddCSLuaFile( "animsoundf2.lua" )
AddCSLuaFile("pill_fnaf2.lua")

include( "sv_admin.lua" )
include( "sv_spectate.lua" )
include( "sv_nostuck.lua" )
include( "sv_ragdolls.lua" )
include( "mount/push.lua" )

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

util.AddNetworkString("StartPostGame")
util.AddNetworkString("StartGame")
util.AddNetworkString("ResetTimer")

util.AddNetworkString( "DeadHUDEnable" )
util.AddNetworkString( "DeadHUDChange" )
util.AddNetworkString( "DeadHUDDisable" )
util.AddNetworkString( "DeadHUDChangeString" )

util.AddNetworkString("AnimatronicsWin")
util.AddNetworkString("SurvivorsWin")


function randomChoice(t)
    return t[math.random(#t)]
end

lastKillers = {}

local playerCount = 1
lobbyDuration = 120
unfreezeAnimatronics = 60
gameDuration = 660

local roundCount = 0

postGameOn = true
isGameOn = false
roundEnding = false

alivePlayers = {}
deadPlayers = {}
animatronics = {}
survivors = {}

function assignKillers()
    local players = player.GetAll()
    local totalPlayers = #players

    local numKillers

    if totalPlayers >= 30 then
        numKillers = 5
    elseif totalPlayers >= 21 then
        numKillers = 4
    elseif totalPlayers >= 15 then
        numKillers = 3
    elseif totalPlayers >= 7 then
        numKillers = 2
    elseif totalPlayers >= 2 then
        numKillers = 1
    else
        PrintMessage(HUD_PRINTTALK, "Недостаточно игроков для выбора убийцы")
        return
    end
	
    local availableKillers = table.GetKeys(killerInfo)
	
	for _, v in pairs(lastKillers) do
		if table.Count(players) >= table.Count(lastKillers) then
			table.RemoveByValue(players, v)
		end
	end
	
    for i = 1, numKillers do
		if table.Count(players) == 0 and table.Count(lastKillers) > 0 then
			players.insert(lastKillers[1])
			table.RemoveByValue(lastKillers, lastKillers[1])
		end
		
		if table.Count(availableKillers) == 0 then
			return
		end
		
		if i == 2 then
			for k, v in pairs(duoKillerInfo) do
				table.insert(availableKillers, k)
			end
		end
			
		local chosenPlayer = randomChoice(players)
		table.RemoveByValue(players, chosenPlayer)
	
		local command = randomChoice(availableKillers)
		local killerData = getAllKillers()[command]
		table.RemoveByValue(availableKillers, command)
	
		RunConsoleCommand("pk_pill_apply", chosenPlayer:Nick(), command)
		
		table.insert(animatronics, chosenPlayer)
		table.RemoveByValue(survivors, chosenPlayer)
		
		net.Start("KillerPicked")
		for i, ply in ipairs(animatronics) do
			if ply == chosenPlayer then
				net.WriteUInt(i, 8)
			end
		end
		net.WriteString(chosenPlayer:Nick())
		net.WriteString(killerData.name)
		net.WriteColor(killerData.color)
		net.Broadcast()
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:Freeze(true)
    end
	
	table.Empty(lastKillers)
	
	for _, v in pairs(animatronics) do
		if !table.HasValue(lastKillers, v) then
			table.insert(lastKillers, v)
		end
	end
	
	timer.Create("UnfrozeAnimatronics", unfreezeAnimatronics, 1, function()
		for _, ply in ipairs( animatronics ) do
			ply.lobbyFreeze = nil
			ply:Freeze(false)
		end
		roundActive = true
    end)
	
end

function giveKiller(player, killer)
	local ply = player
	
	local killers = getAllKillers()
	local killerData
	local command
	
	for k, v in pairs(killers) do
		if v.name == killer then
			killerData = killers[k]
			command = k
		end
	end
	
	if !killerData then return end

	RunConsoleCommand("pk_pill_apply", ply:Nick(), command)
	
	if !table.HasValue(animatronics, ply) then
		table.insert(animatronics, ply)
	end
	if table.HasValue(survivors, ply) then
		table.RemoveByValue(survivors, ply)
	end

    net.Start("KillerPicked")
    net.WriteUInt(1, 8)
    net.WriteString(ply:Nick())
    net.WriteString(killerData.name)
    net.WriteColor(killerData.color)
    net.Broadcast()
	
	ply:Freeze(true)
end

function setupPlayerVars(ply)
	ply:AllowFlashlight(true)
	ply:SetRunSpeed(420)
	ply:SetJumpPower(200)
	ply:SetDuckSpeed(0.1)
	ply:SetUnDuckSpeed(0.1)
	ply:SetStepSize(18)
end

function endGame()
	roundEnding = true
	
    net.Start("ResetTimer")
    net.Broadcast()
	
	if timer.Exists("UnfrozeAnimatronics") then
		timer.Remove("UnfrozeAnimatronics")
	end
	
	if timer.Exists("RandomGifts") then
		timer.Remove("RandomGifts")
	end
	
	timer.Create("endGameWait", 5, 1, function() 
		game.CleanUpMap( false )
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
		
		isGameOn = false
		roundActive = false
		for _, ply in pairs(player.GetAll()) do
			ply:Spawn()
			ply:SetTeam(TEAM_UNASSIGNED)
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
    net.Start("StartPostGame")
	net.WriteFloat(lobbyDuration)
    net.Broadcast()
end

function startGame()
    net.Start("StartGame")
	net.WriteFloat(gameDuration)
	net.WriteInt(roundCount, 32)
    net.Broadcast()
	
	if timer.Exists("endGameWait") then
		timer.Remove("endGameWait")
	end
	
    local randomTime = math.random(110, 165)
    //local randomTime = math.random(30, 31)
    timer.Create("RandomGifts", randomTime, 0, function()
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
    end)
	
	net.Start('fh_adv_sound_play')
	net.WriteString('music/first_minute.wav')
	net.Broadcast()
	
	timer.Create("EndGameTimer", gameDuration, 1, function()
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
	assignKillers()
	
	startGame()
end

function restoreAnimatronics()
	if table.Count(animatronics) == 0 then return end
	
	for _, ply in ipairs(animatronics) do
        RunConsoleCommand("pk_pill_restore", ply:Nick())
	end
	
	for _, ply in ipairs(team.GetPlayers(2701)) do
        RunConsoleCommand("pk_pill_restore", ply:Nick())
	end
end

hook.Add( "Initialize", "fh_init", function()
	RunConsoleCommand('sv_noclipspeed', 2)
end )

hook.Add("PlayerInitialSpawn", "fh_ply_spawn", function(ply)
	setupPlayerVars(ply)
	
    playerCount = playerCount + 1
	
	if isGameOn then
		timer.Simple(1, function()
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

gameevent.Listen( "player_connect_client" )
hook.Add("player_connect_client", "EnoughToStart", function(ply)
    if playerCount >= 2 and not isGameOn and !timer.Exists("GameStartTimer") then
        postGameTimer()

        timer.Create("GameStartTimer", lobbyDuration, 1, function()
            registerNewRound()
        end)
    end
end)

hook.Add("FinishMove", "CanMove", function(ply)
	ply:SetCustomCollisionCheck(true)
	if ply:Team() == 2701 and !roundActive and !postGameOn then
		return true
	end
end)

hook.Add("PlayerDisconnected", "PlayerLeft", function(ply)
    playerCount = playerCount - 1
	
	if table.HasValue(lastKillers, ply) then
		table.RemoveByValue(lastKillers, ply)
	end
	if table.HasValue(survivors, ply) then
		table.RemoveByValue(survivors, ply)
	end
	if table.HasValue(animatronics, ply) then
		table.RemoveByValue(animatronics, ply)
	end
	if table.HasValue(alivePlayers, ply) then
		table.RemoveByValue(alivePlayers, ply)
	end

    if playerCount == 1 and isGameOn then
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
		
		if table.Count(survivors) == 0 and !roundEnding then
			if timer.Exists("EndGameTimer") then
				timer.Remove("EndGameTimer")
			end
			net.Start("AnimatronicsWin")
			net.WriteString(victim:Nick())
			net.Broadcast()
			
			endGame()
		end
	end
	
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
	
    if IsValid(victim) and victim:IsPlayer() and IsValid(ent) and string.match(ent:GetModel(), "([^/]+)%.mdl$") == 'oldbonnie' then
		local ragdoll = victim:GetRagdollEntity()
        if IsValid(ragdoll) then
            local forward = victim:GetAimVector()

            local impulse = forward * -500

            local phys = ragdoll:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(impulse)
            end
        end
    end
end)

hook.Add( "CreateEntityRagdoll", "fh_ragdoll_handle", function( ply, ragdoll )
	print(ragdoll)
	ragdoll:Remove()
end )

hook.Add( "CanPlayerSuicide", "AllowOwnerSuicide", function( ply )
	if ply:Team() == 2701 then
		return false
	end
end )

hook.Add( "PlayerShouldTakeDamage", "AntiTeamkill", function( ply, attacker )
	if ply:IsPlayer() and attacker:IsPlayer() then
		if IsValid(attacker) and (ply:Team() == attacker:Team() or ply:Team() == 2701 or !roundActive or roundEnding) then
			return false
		end
	end
end )

hook.Add("ShouldCollide", "CustomPlayerCollision", function(ent1, ent2)
    if ent1:GetCollisionGroup() == COLLISION_GROUP_WORLD or ent2:GetCollisionGroup() == COLLISION_GROUP_WORLD then
        return false
    end
    return true
end)

hook.Add("PlayerChangedTeam", "fh_jointeam", function(ply, oldteam, team)
	if team == 2701 then
		if !table.HasValue(animatronics, ply) then
			table.insert(animatronics, ply)
		end
		local ent = pk_pills.getMappedEnt(ply)
		if IsValid(ent) then
			local name = string.match(ent:GetModel(), "([^/]+)%.mdl$")
			
			if name == 'oldfreddy' then name = 'freddy' end
			if name == 'oldbonnie' then name = 'bonnie' end
			if name == 'oldchica' then name = 'chica' end
			if name == 'oldfoxy' then name = 'foxy' end
			if name == 'endo02' then name = 'endo' end
			if name == 'oldgoldenfreddy' then name = 'sfreddy' end
			if name == 'springtrap_clown' then name = 'clown' end
			
			net.Start("ApplyKiller")
			net.WriteString(name)
			net.Send(ply)
			
			timer.Simple(1, function()
				net.Start("fh_hl_teammates")
				net.Broadcast()
			end)
		end
	else
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

hook.Add("PlayerCanSeePlayersChat", "fh_chat_management", function(text, team, list, speak)
	if (speak:IsPlayer() and speak:Team() == TEAM_SPECTATOR) and list:Team() != TEAM_SPECTATOR then
		return false
	end
end)

net.Receive("fh_initpostentity", function(len, ply)
	if timer.Exists('EndGameTimer') then
		local timeLeft = timer.TimeLeft('EndGameTimer')
		
		net.Start('StartGame')
		net.WriteFloat(timeLeft)
		net.WriteInt(roundCount, 32)
		net.Send(ply)
	elseif timer.Exists('GameStartTimer') then
		local timeLeft = timer.TimeLeft('GameStartTimer')
		
		net.Start("StartPostGame")
		net.WriteFloat(timeLeft)
		net.Send(ply)
	end
end)

hook.Add( "PlayerSay", "", function( ply, text, teamChat )
	net.Start("fh_chat_message")
	net.WriteString(ply:Nick())
	net.WriteString(text)
	net.WriteBool(ply:Team() == TEAM_SPECTATOR or !ply:Alive())
	net.WriteColor(teamColors[ply:Team()])
	if !teamChat and ply:Team() != TEAM_SPECTATOR then
		net.WriteBool(false)
		net.Broadcast()
	else
		for _,v in ipairs(team.GetPlayers(ply:Team())) do
			net.WriteBool(true)
			net.Send(v)
		end
	end
	return ""
end )