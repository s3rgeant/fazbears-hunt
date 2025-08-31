fh = fh or {}

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

AddCSLuaFile( "interface/cl_admin.lua" )
AddCSLuaFile( "interface/cl_anim_selector.lua" )
AddCSLuaFile( "interface/cl_hud.lua" )
AddCSLuaFile( "interface/cl_optionmenu.lua" )
AddCSLuaFile( "interface/cl_playerlist.lua" )
AddCSLuaFile( "interface/cl_spechud.lua" )
AddCSLuaFile( "interface/cl_timer.lua" )

AddCSLuaFile( "cl_flashlight.lua" )
AddCSLuaFile( "cl_halo.lua" )
AddCSLuaFile( "cl_horror.lua" )
AddCSLuaFile( "cl_sound.lua" )

AddCSLuaFile( "animsoundf2.lua" )
AddCSLuaFile( "voicelines.lua" )

include( "sv_admin.lua" )
include( "sv_halo.lua" )
include( "sv_spectate.lua" )
include( "sv_nostuck.lua" )
include( "sv_ragdolls.lua" )
include( "sv_logs.lua" )
include( "sv_stats.lua" )
include( "sv_cooldown.lua" )

include( "mount/push.lua" )

include( "mount/proximity.lua" )
AddCSLuaFile( "mount/proximity.lua" )

--include( "terror_radius.lua" )
--AddCSLuaFile( "terror_radius.lua" )

include( "pill_fnaf2.lua" )
include( "pill_fnaf3.lua" )

util.AddNetworkString("KillerPicked")
util.AddNetworkString("ApplyKiller")
util.AddNetworkString("RemoveKiller")

util.AddNetworkString("nv_off")

util.AddNetworkString("fh_initpostentity")

util.AddNetworkString("fh_hl_teammates")
util.AddNetworkString("fh_uhl_teammates")

util.AddNetworkString("fh_net_display")

util.AddNetworkString("fh_update_list")

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

local function GetPlyID(ply)
    if not IsValid(ply) then return nil end
    return ply:SteamID64()
end

local function WasKillerRecently(ply)
    local id = GetPlyID(ply)
    return id and lastKillers[id] ~= nil
end

local function RemoveKillerID(id)
    lastKillers[id] = nil
end

lobbyDuration = 120
local gameDuration = 600
setupGameDuration = 60

curMaxKillers = 1

local animatronics_win_count = 0
local survivors_win_count = 0

local roundCount = 0

roundActive = false -- когда аниматроники разморожены и идёт раунд
isGameOn = false -- начинается прямо под регистрацию раунда и заканчивается после 5 секунд конца раунда
roundEnding = false -- концовка раунда

--[[
	0 - обыкновенный раунд
	1 - спрингтрап
]]--
local roundType = 0

animatronics = {}
survivors = {}

usedKillers = {}

function assignKillers()
    local players = player.GetAll()
    local totalPlayers = #players
	local curKillers = {}

    if totalPlayers >= 64 then
        curMaxKillers = 5
    elseif totalPlayers >= 32 then
        curMaxKillers = 4
    elseif totalPlayers >= 20 then
        curMaxKillers = 3
    elseif totalPlayers >= 10 then
        curMaxKillers = 2
    elseif totalPlayers >= 1 then
        curMaxKillers = 1
    end
	
    local availableKillers = table.GetKeys(killers.getAllPreferables(curMaxKillers > 1))
	
    for i = 1, curMaxKillers do
		players = fh.GetEarnedKillers(players)
		
		local chosenPlayer = fh.randomChoice(players)
		table.RemoveByValue(players, chosenPlayer)
		
		animatronics[chosenPlayer] = true
		survivors[chosenPlayer] = nil
		
		chosenPlayer:SetTeam(2701)
		chosenPlayer:ReturnToSpawn()
		
		curKillers[chosenPlayer] = true
		
		if chosenPlayer:IsBot() then
			giveRandomKiller(chosenPlayer, true)
		end
    end
	
	for v, _ in pairs(curKillers) do
		local id = GetPlyID(v)
        if id and not lastKillers[id] then
            lastKillers[id] = 0
        end
	
		net.Start("fh_let_killers_choose")
		net.WriteTable(availableKillers)
		net.Send(v)
	end
	freezeAnimatronics()
end

function freezeAnimatronics(duration)
	duration = duration or setupGameDuration
	
	for ply, _ in pairs( animatronics ) do
		ply.lobbyFreeze = true
	end
	
	timer.Create("UnfreezeAnims", duration, 1, function()
		for ply, _ in pairs( animatronics ) do
			ply.lobbyFreeze = false
		end
		roundActive = true
		LogEvent(" ")
        LogEvent("(*АВТО*) - Все аниматроники разморожены, раунд начат.")
		
		hook.Run("fh_poststartgame", roundType, animatronics)
    end)
end

hook.Add('fh_poststartgame', 'enable_scary_sound_fh', function()
	net.Start("fh_net_scarysound")
	net.WriteBool(true)
	net.SendOmit( table.GetKeys( getOutworldVictims() ) )
end)

local function giveKillerShared(ply, killer, force)
	
	local killers_ = killers.getAll()
	
	local killerData
	local command
	
	for k, v in pairs(killers_) do
		if v.name == killer or k == killer then
			killerData = killers_[k]
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

	--RunConsoleCommand("pk_pill_apply", ply:Nick(), command)
	pills.apply(ply:Nick(), command, "user")
	
	animatronics[ply] = true
	survivors[ply] = nil
	
    LogEvent("🤖 Игроку **" .. ply:Nick() .. "** выдан **" .. killerData.name.."**")
	
	if timer.Exists("UnfreezeAnims") then
		ply.lobbyFreeze = true
	end
	
	return killerData
end

function giveKiller(ply, killer, force)
	force = force or false
	
	local killerData = giveKillerShared(ply, killer, force)
	
	if !killerData then return end

    net.Start("KillerPicked")
    net.WriteUInt(1, 8)
    net.WriteString(ply:Nick())
    net.WriteString(killerData.fullname)
    net.WriteColor(killerData.color)
    net.Broadcast()
end

function giveKillerSilent(ply, killer, force)
	force = force or false
	
	giveKillerShared(ply, killer, force)
end

function setupPlayerVars(ply)
	ply:AllowFlashlight(true)
	ply:SetRunSpeed(420)
	ply:SetWalkSpeed(200)
	ply:SetJumpPower(200)
	ply:SetDuckSpeed(0.1)
	ply:SetUnDuckSpeed(0.1)
	ply:SetStepSize(18)
	ply:UnLock()
	ply:SetFOV(0)
	ply:SetViewEntity(ply)
	
	ply:SetJumpBoostMultiplier( GetScaledPlayerValue(7, 18, 0.5, 0.9) )
end

hook.Add("PlayerCanSeePlayersChat", "fh_chat", function(text, teamOnly, listener, speaker)
	if speaker:IsPlayer() and speaker:Team() == TEAM_SPECTATOR or !speaker:Alive() then
		if listener:Team() ~= TEAM_SPECTATOR then
			return false
		end
	end
end)

function endGame(killerVictory)
	killerVictory = killerVictory or false

	roundEnding = true
	
	RunConsoleCommand("proximity_enabled", 0)
	
    net.Start("ResetTimer")
    net.Broadcast()
	
	if timer.Exists("UnfreezeAnims") then
		timer.Remove("UnfreezeAnims")
	end
	
	if timer.Exists("RandomGifts") then
		timer.Remove("RandomGifts")
	end
		
	for id, v in pairs(lastKillers) do
        local ply = player.GetBySteamID64(id)
        if IsValid(ply) then
            lastKillers[id] = v + 1
            if lastKillers[id] > 5 then
                RemoveKillerID(id)
            end
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
					for _, p in player.Iterator() do
						p:ScreenFade( SCREENFADE.OUT, Color( 0, 0, 0, 255 ), 0.5, 0 )
					end
				end)
				
				timer.Simple(1, function()
					local ent = pills.getMappedEnt(springtrap_ply)
					
					springtrap_ply:SetPos(win_location:GetPos())
					springtrap_ply:SetEyeAngles(win_location:GetAngles())
					springtrap_ply:SetRenderAngles(win_location:GetAngles())
					ent:SetAngles(win_location:GetAngles())
					
					for _, p in player.Iterator() do
						p:SetViewEntity(win_camera)
						p:SetFOV(65, 2)
						
						p:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 255 ), 1, 0 )
					end
					
					net.Start("fh_play_sound")
					net.WriteString("#music/rampage.wav")
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

function getScaledJumpBoost()
	local count = player.GetCount()
	
	if count < 8 then
		return 0.3
	elseif count < 18 then
		return 0.6
	end
	return 0.8
end

function GM:fh_prestartgame()
end

function GM:fh_poststartgame()
end

function GM:fh_postendgame()
end

function startGame(forceid)
	RunConsoleCommand("proximity_enabled", 1)
	
	if timer.Exists("endGameWait") then
		timer.Remove("endGameWait")
	end
	
	if conVars.fh_gifts_spawning:GetBool() then
		doGiftSpawning()
	end
	
	local fh_prestartgame = hook.Run("fh_prestartgame")
	
	if fh_prestartgame != nil and fh_prestartgame == false then 
		return 
	end
	
	fh.SelectRoundType(forceid or nil)
	
	local fh_startgame = hook.Run("fh_startgame", roundType)
	
	if fh_startgame != nil and fh_startgame == false then 
		return 
	end
	
	for _, ply in player.Iterator() do
		ply:SetJumpBoostMultiplier( getScaledJumpBoost() )
	end
	
    net.Start("fh_start_game_timer")
	net.WriteFloat( fh.GetGameDuration() )
	net.WriteFloat(setupGameDuration)
	net.WriteString("ambient/alarms/warningbell1.wav")
	net.WriteString(tostring(roundCount))
    net.Broadcast()
	
	net.Start('fh_adv_sound_play')
	net.WriteString( "#"..fh.GetRoundMusic( fh.GetRoundType() ) )
	net.WriteString( "timer_music" )
	net.Broadcast()
	
	timer.Create("EndGameTimer", fh.GetGameDuration() + setupGameDuration, 1, function()
		survivorsWin()
    end)
end

function RandomTaser()
	local random_taser = team.GetPlayers( TEAM_UNASSIGNED )
	local random_taserer = fh.randomChoice( random_taser )
	
	if IsValid(random_taserer) then
		random_taserer:Give("weapon_taser")
		random_taserer:SendLua( "LocalPlayer():ChatPrint(language.GetPhrase('fazhunt.give_taser'))" )
	end
end

function resetGameTimer()
    net.Start("ResetTimer")
    net.Broadcast()
end

function registerNewRound(forceid)
	if timer.Exists("GameStartTimer") then
		timer.Remove("GameStartTimer")
	end
	roundCount = roundCount + 1
	
	isGameOn = true
	roundEnding = false
	table.Empty(survivors)
	table.Empty(animatronics)
	table.Empty(usedKillers)
    for _, ply in player.Iterator() do
        ply:Spawn()
		survivors[ply] = true
    end
	LogEvent(" ")
	
	restoreAnimatronics()
	startGame(forceid)
end

function restoreAnimatronics()
	if !table.IsEmpty(animatronics) then
		for ply, _ in pairs(animatronics) do
			pills.restore(ply:Nick(), true)
		end
	end
	
	local animteam = team.GetPlayers(2701)
	if !table.IsEmpty(animteam) then
		for _, ply in pairs(animteam) do
			pills.restore(ply:Nick(), true)
		end
	end
end

function restoreAnimatronic(ply)
	RunConsoleCommand("pk_pill_restore", ply:Nick())
	animatronics[ply] = nil
	survivors[ply] = true
end

function GetGiftSpawnInterval()
	local def1 = 65
	local def2 = 80
	
	local count = team.NumPlayers(TEAM_UNASSIGNED) or 1
	
	def1 = def1 + (count * ( 0.15 * count ) )
	def2 = def2 + (count * ( 0.175 * count ) )
	
	if !roundActive and def1 <= 90 then
		def1 = 90
		def2 = 110
	end
	
	return def1, def2
end

function GetGiftSpawnChance()
	local def = 100
	
	local count = math.min(team.NumPlayers(TEAM_UNASSIGNED) or 1, 5)
	
	def = def - math.min(count * 1.2, 75)
	
	return def
end

function doGiftSpawning()
	if timer.Exists('RandomGifts') then return end
	timer.Create("RandomGifts", fh_random_time( GetGiftSpawnInterval() ), 0, function()
		SpawnGifts()
		timer.Adjust("RandomGifts", fh_random_time( GetGiftSpawnInterval() ), nil, nil)
	end)
end

function GM:fh_prespawngifts()
end

function SpawnGifts()
	local fh_prespawngifts = hook.Run("fh_prespawngifts")
	
	if fh_prespawngifts != nil and fh_prespawngifts == false then 
		return 
	end
	
	for ply, _ in pairs(survivors) do
		if math.random(1, 100) <= GetGiftSpawnChance() and (ply:Alive() and ply:Team() != TEAM_SPECTATOR) then
			local fh_ShouldPlayerReceiveGifts = hook.Run("fh_ShouldPlayerReceiveGifts", ply)
			
			if fh_ShouldPlayerReceiveGifts == false then continue end
			
			if ply:GetGiftOwnership() then continue end
			
			timer.Simple(util.SharedRandom( math.random(-100,100), 1, 12 ), function()
				if !IsValid(ply) or !ply:IsSurvivor() then return end
				local gift = ents.Create("fh_gift")
				gift:SetPos(ply:GetPos() + Vector(0, 0, 10))
				gift:SetOwner(ply)
				gift:Spawn()
				
				ply:SetGiftOwnership(true)
			end)
		end
	end
end

concommand.Add( "fh_grant_gift", function( ply, cmd, args )
	timer.Simple(2, function()
		if IsValid(ply) then
			local gift = ents.Create("fh_gift")
			gift:SetPos(ply:GetPos() + Vector(0, 0, 10))
			gift:SetOwner(ply)
			gift:Spawn()
		end
	end)
end )

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
	RunConsoleCommand('sv_defaultdeployspeed', 2)
	
	RunConsoleCommand("proximity_enabled", 1)
	
	-- выделенный сервер не включает таймер. пробую делать вот так
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
			if IsValid(ply) then
				ply:KillSilent()
				
				ply:StripWeapons()
				ply:Spectate(OBS_MODE_CHASE)
				ply:SetTeam(TEAM_SPECTATOR)
			
				net.Start('DeadHUDEnable')
				net.Send(ply)
			end
		end)
	
		survivors[ply] = nil
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
	if (ply:Team() == 2701 or animatronics[ply]) and !roundActive and isGameOn then
		ply:SetVelocity(-ply:GetVelocity())
	end
end)

hook.Add("FinishMove", "fh_canmove", function(ply)
	if (ply:Team() == 2701 or animatronics[ply]) and !roundActive and isGameOn then
		return true
	end
end)

hook.Add( "StartCommand", "fh_cantattack", function( ply, cmd )
	if (ply:Team() == 2701 or animatronics[ply]) and !roundActive and isGameOn then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
		cmd:RemoveKey(IN_JUMP)
	end
end)

hook.Add("SetupPlayerVisibility", "fh_speak_pvs", function(ply, viewent)
	for _, sex in player.Iterator() do
		if sex ~= ply and sex:Alive() and sex:IsSpeaking() then
			AddOriginToPVS(sex:GetPos())
		end
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
	
	if isGameOn then
		animatronicsLeft_check()
	end
	
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
	if ply:IsAdmin() and ply:Team() != 2701 or ply:IsSuperAdmin() then
		return true
	end
end )

function GM:PlayerSetModel( pl )
	player_manager.RunClass( pl, "SetModel" )
end

local PLAYER = FindMetaTable("Player")

if PLAYER then

	function PLAYER:ReturnToSpawn()
		if not IsValid(self) or not self:IsPlayer() then return end

		local spawnPoint = hook.Run("PlayerSelectSpawn", self)

		self:SetPos(spawnPoint:GetPos())
		self:SetEyeAngles(spawnPoint:GetAngles())
	end

end

hook.Add("PlayerSpawn", "fh_spawn", function( ply, transiton )
	player_manager.SetPlayerClass( ply, "player_sandbox" )
	ply:SetShouldServerRagdoll(true)
	
	ply:SendLua( 'if !system.HasFocus() then system.FlashWindow() end' )
	
	--ply:SetTeam(TEAM_UNASSIGNED)
	net.Start('DeadHUDDisable')
	net.Send(ply)
	
	net.Start('nv_off')
	net.Send(ply)
	
	if IsValid(ply.DeathRagdoll) then
		ply.DeathRagdoll:Remove()
	end
end)

hook.Add("EntityTakeDamage", "fh_anti_animatronic_death", function(target, dmginfo)
	if conVars.fh_respawn_dead_animatronics:GetBool() then
		if IsValid(target) and target:IsPlayer() and target:IsAnimatronic() then
			
			if hook.Run("fh_should_animatronic_respawn", target) == false then return end

			local damage = dmginfo:GetDamage()
			local healthAfterDamage = target:Health() - damage

			if healthAfterDamage <= 0 then
				target:SetHealth(target:GetMaxHealth())
				target:ReturnToSpawn()
				
				local ent = pills.getMappedEnt(target)
				
				if IsValid(ent) then
					ent:ResetSpeed(target)
				end
				
				return true
			end
		end
	end
end)

hook.Add("OnEntityCreated", "fh_any_prop_isbreakable", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if string.StartsWith(ent:GetClass(), "prop_physics") then
			if not IsValid(ent) then return end
			if not ent:GetPhysicsObject():IsValid() then return end
			
			local kv = ent:GetKeyValues()
			if kv.health and tonumber(kv.health) and tonumber(kv.health) > 1 then
				return
			end
			
			if not ent.PropHealth then
				local baseHealth = 135
				local phys = ent:GetPhysicsObject()
			
				baseHealth = baseHealth + (phys:GetMass() * 2.2)
			
				ent.PropHealth = baseHealth
			end
		end
	end)
end)

hook.Add("EntityTakeDamage", "fh_anims_only_breakable_props", function(ent, dmginfo)
	local attacker = dmginfo:GetAttacker()
	
	if IsValid(attacker) and attacker:IsPlayer() and attacker:IsAnimatronic() then
		local phys = ent:GetPhysicsObject()
		if ent.PropHealth and phys:IsMotionEnabled() then
			ent.PropHealth = ent.PropHealth - dmginfo:GetDamage()
			if ent.PropHealth <= 0 then
            local effectdata = EffectData()
				effectdata:SetOrigin(ent:LocalToWorld(ent:OBBCenter()))
				effectdata:SetMagnitude(2)
				effectdata:SetScale(1)
				effectdata:SetRadius(2)
				util.Effect("Sparks", effectdata, true, true)
			
				ent:Fire("Break")
			end
		end
	
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
		
		local animCount = table.Count(animatronics)
		
		if fh.GetActiveUsedKiller("pill_plushtrap") then
			animCount = math.max(animCount - 1, 1)
		end
		
		if isGameOn and !roundEnding and table.Count(survivors) == 1 and animCount >= 2 and timer.TimeLeft("EndGameTimer") >= 200 then
			net.Start("fh_timer_cutback")
			net.WriteFloat(180)
			net.WriteString("round/time_cutback.mp3")
			net.Broadcast()
			
			timer.Adjust("EndGameTimer", 180)
		end
		
		animatronicsVictory_check(victim)
	end
	animatronics[victim] = nil
	
	if isGameOn then
		animatronicsDied_check()
		
		victim:Spectate(OBS_MODE_CHASE)
		victim:SetTeam(TEAM_SPECTATOR)
		
		net.Start('DeadHUDEnable')
		net.Send(victim)
	end
	
    --local ent = pills.getMappedEnt(attacker)
	
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
		net.WriteInt(fh.GetGameDuration() - timer.TimeLeft("EndGameTimer"), 16)
		net.Broadcast()
		
		endGame(true)
		
		LogEvent(" ")
		
		local log_embed_table = { last_ply:Nick(), formatTime((fh.GetGameDuration() + setupGameDuration) - (timer.TimeLeft("EndGameTimer") or 0)), fh_get_plytable_nicknames(animatronics) }
		
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
	if timer.Exists("EndGameTimer") and timer.TimeLeft( "EndGameTimer" ) > fh.GetGameDuration() then
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
	
	local killerData = killers.getAll()
		
	if !killerData[name] then return end
	
	local killer = killerData[name]
	
	name = killer.name
	local color = killer.color
	
	net.Start("ApplyKiller")
	net.WriteString(name)
	net.WriteColor(color)
	net.Send(ply)
end)

hook.Add("PillRestore", "fh_restorepill", function(ply)
	net.Start("RemoveKiller")
	net.Send(ply)
	
	net.Start("fh_uhl_teammates")
	net.Send(ply)
end)

hook.Add("SetupPlayerVisibility", "fh_spec_pvs", function(ply)
    if ply:Team() == TEAM_SPECTATOR then
        local target = ply:GetObserverTarget()
        if IsValid(target) then
            AddOriginToPVS(target:GetPos())
        end
    end
end)

hook.Add( "GetFallDamage", "FH_FallDamage", function(ply, speed)
	return math.min(speed / 35, 50)
end )

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
	
    local availableKillers = table.GetKeys(killers.getAllPreferables(curMaxKillers > 1))
	
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
			LogEvent("(*АВТО*) - ⌛️ Таймер раунда начат. Количество игроков: "..player.GetCount())
		end)
		
		lobbyDuration = 30
	end
	
	net.Start("fh_share_notprefered")
	net.WriteTable(killers.getAllPreferables(true))
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

function fh.SetGameDuration(num)
	if num < 1 then num = 1 end
	conVars.fh_round_duration:SetInt(num)
end

function fh.GetGameDuration()
	return conVars.fh_round_duration:GetInt() * 60
end

function fh.GetEarnedKillers(players)
    local toRemove = {}
	for _, ply in ipairs(players) do
		if WasKillerRecently(ply) then
			table.insert(toRemove, ply)
		end
	end
	for _, ply in ipairs(toRemove) do
		table.RemoveByValue(players, ply)
	end
	
    if table.IsEmpty(players) and not table.IsEmpty(lastKillers) then
        local chosenLastKillerID = nil
        local high = 0

        for id, v in pairs(lastKillers) do
            if v >= high then
			
                chosenLastKillerID = id
                high = v
            end
        end

        if chosenLastKillerID then
            local ply = player.GetBySteamID64(chosenLastKillerID)
            if IsValid(ply) then
                table.insert(players, ply)
                lastKillers[chosenLastKillerID] = 0
            end
        end
    end

    if table.IsEmpty(players) then
        players = player.GetAll()
    end

    return players
end

local round_music = {
	[0] = "music/first_minute.wav"
}

function fh.AddRoundMusic(num, music)
	if !round_music[num] then
		round_music[num] = music
	end
end

function fh.GetRoundMusic(num)
	if round_music[num] then
		return round_music[num]
	end
	return round_music[0]
end

fh.AddRoundMusic(1, "music/freeze_timer_springtrap.wav")

fh.RoundTypes = fh.RoundTypes or {}
fh.RoundTypeNameToID = fh.RoundTypeNameToID or {}
fh.RoundTypeIDToName = fh.RoundTypeIDToName or {}
fh.RoundTypeIDCounter = 0

function fh.RegisterRoundType(name, id, func, weight, minPlayers, maxPlayers)
    assert(name, "Round type name is required")
    assert(func, "Round type function is required")

    if isstring(id) then
        id = tonumber(util.CRC(id)) % 100000
    elseif not isnumber(id) then
        fh.RoundTypeIDCounter = fh.RoundTypeIDCounter + 1
        id = fh.RoundTypeIDCounter
    end

    fh.RoundTypes[id] = {
        name = name,
        id = id,
        func = func,
        weight = weight or 1,
        minPlayers = minPlayers,
        maxPlayers = maxPlayers
    }

    fh.RoundTypeNameToID[name] = id
    fh.RoundTypeIDToName[id] = name
end

concommand.Add( "fh_force_roundtype", function( ply, cmd, args )
	if !ply:IsSuperAdmin() then return end
	local round = tonumber(args[1]) or 0
	registerNewRound(round)
end )

function fh.SelectRoundType(forcedID)
    local selected
    local playerCount = player.GetCount()

    if forcedID then
        selected = fh.RoundTypes[forcedID]
    else
        local pool = {}
        for id, data in pairs(fh.RoundTypes) do
            local minOK = not data.minPlayers or playerCount >= data.minPlayers
            local maxOK = not data.maxPlayers or playerCount <= data.maxPlayers

            if minOK and maxOK then
                local entries = math.max(1, data.weight or 1)
                for _ = 1, entries do
                    table.insert(pool, data)
                end
            end
        end

        if #pool == 0 then
            ErrorNoHalt("[fh] what have you done? Seems like there is no round types that support this ( "..playerCount.." ) player count.\n")
            return
        end

        selected = pool[math.random(#pool)]
    end

    if selected then
        fh.SetRoundType(selected.id)
        selected.func()
    else
        ErrorNoHalt("[fh] Couldn't select round type!\n")
    end
end

function fh.GetRoundTypes()
    local types = {}
    for id, _ in pairs(fh.RoundTypes) do
        table.insert(types, id)
    end
    return types
end

function fh.GetRoundTypeByName(name)
    return fh.RoundTypeNameToID[name]
end

function fh.GetRoundTypeNameByNumber(id)
    return fh.RoundTypeIDToName[id]
end

fh.RegisterRoundType("regular", 0, function()
	assignKillers()
	RandomTaser()
	freezeAnimatronics()
end, 100)

fh.RegisterRoundType("springtrap", 1, function()
	local players = player.GetAll()
		
	players = fh.GetEarnedKillers(players)
	
	local chosenPlayer = fh.randomChoice(players)
	
	giveKiller(chosenPlayer, "pill_springtrap", true)
	
	chosenPlayer.lobbyFreeze = true
	chosenPlayer:ReturnToSpawn()
	
	local id = GetPlyID(chosenPlayer)
	if id and not lastKillers[id] then
		lastKillers[id] = 0
	end
	
	RandomTaser()
	
	freezeAnimatronics()
end, 20, 6, 18)

include( "fh_tag.lua" )