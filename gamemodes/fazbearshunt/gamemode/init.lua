fh = fh or {}

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include( "shared.lua" )

pcall(require,"pills")

local function recursive_include(path)
	local files, folders = file.Find(path .. "*", "LUA")
	
	for _, file_name in ipairs(files) do
		local full_path = path .. file_name
	
		if !file_name:EndsWith(".lua") then continue end
	
		if file_name:StartWith("sv_") then
			include(full_path)
	
		elseif file_name:StartWith("sh_") then
			AddCSLuaFile(full_path)
			include(full_path)
	
		elseif file_name:StartWith("cl_") then
			AddCSLuaFile(full_path)
		end
	end
end
AddCSLuaFile("halo_module.lua")

recursive_include("fazbearshunt/gamemode/utils/")
recursive_include("fazbearshunt/gamemode/")
recursive_include("fazbearshunt/gamemode/interface/")
recursive_include("fazbearshunt/gamemode/mount/")
recursive_include("fazbearshunt/gamemode/events/")

util.AddNetworkString("KillerPicked")
util.AddNetworkString("ApplyKillerCompanion")
util.AddNetworkString("RemoveKillerCompanion")

util.AddNetworkString("nv_off")

util.AddNetworkString("fh_initpostentity")

util.AddNetworkString("fh_net_display")

util.AddNetworkString("fh_update_list")

util.AddNetworkString("fh_start_lobby_timer")
util.AddNetworkString("fh_start_game_timer")
util.AddNetworkString("fh_pause_game_timer")
util.AddNetworkString("fh_timer_cutback")
util.AddNetworkString("ResetTimer")

util.AddNetworkString( "DeadHUDEnable" )
util.AddNetworkString( "DeadHUDDisable" )

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

LastKillers = LastKillers or {}

local function GetPlyID(ply)
    if not IsValid(ply) then return nil end
    return tostring(ply:SteamID64())
end

function LK_ToKey(id)
    return "sid_" .. tostring(id)
end

local function FromKey(key)
    return tostring(key):gsub("^sid_", "")
end

hook.Add("Initialize", "FH_LoadLastKillers", function()
    local raw = cookie.GetString("fh_lastkillers", "")
    if raw and raw ~= "" then
        local ok, data = pcall(util.JSONToTable, raw)
        if ok and istable(data) then
            local fixed = {}
            for k, v in pairs(data) do
                fixed[tostring(k)] = tonumber(v) or 0
            end
            LastKillers = fixed
            print("[FH] Загружена таблица LastKillers (" .. table.Count(fixed) .. " записей)")
        end
    end
end)

local function SaveLastKillers()
    local json = util.TableToJSON(LastKillers)
    cookie.Set("fh_lastkillers", json)
end

local lobbyDuration = 120
local gameDuration = 600
local setupGameDuration = 60

local curMaxKillers = 1

local roundCount = 0

roundActive = roundActive or false -- когда аниматроники разморожены и идёт раунд
isGameOn = isGameOn or false -- начинается прямо под регистрацию раунда и заканчивается после 5 секунд конца раунда
roundEnding = roundEnding or false -- концовка раунда

roundPaused = roundPaused or false -- раунд в паузе?

--[[
	0 - обыкновенный раунд
	1 - спрингтрап
	2 - бонни-тэг
	3 - bear5
]]--
local roundType = roundType or 0

animatronics = animatronics or {}
survivors = survivors or {}

usedKillers = {}

forceAnimSelectTime = forceAnimSelectTime or 0
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
	
	if totalPlayers == 0 or !players then return end
	
    local availableKillers = table.GetKeys(killers.getAllPreferables(curMaxKillers > 1))
	
    for i = 1, curMaxKillers do
		local killers = fh.GetEarnedKillers(players)
		
		local chosenPlayer = killers[1]
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
	
	forceAnimSelectTime = CurTime() + 60
	
	for v, _ in pairs(curKillers) do
		net.Start("fh_let_killers_choose")
		net.WriteTable(availableKillers)
		net.Send(v)
	end
end

hook.Add("Think", "fh_disallow_killers_choose", function()
	if forceAnimSelectTime > 0 and CurTime() >= forceAnimSelectTime and isGameOn then
		for ply, _ in pairs(animatronics) do
			if IsValid(ply) and not IsValid(ply:GetPill()) then
				giveRandomKiller(ply, true)
			end
		end
		forceAnimSelectTime = 0
	end
end)

function freezeAnimatronics(duration)
	duration = duration or setupGameDuration
	
	for ply, _ in pairs( animatronics ) do
		ply.lobbyFreeze = true
	end
	
	timer.Create("UnfreezeAnims", duration, 1, function()
		for ply, _ in pairs( animatronics ) do
			ply.lobbyFreeze = false
		end
		SetGlobal2Bool("roundActive", true)
		roundActive = true
		modifiers.Start()
		
		hook.Run("fh_poststartgame", roundType, animatronics)
    end)
end

hook.Add("fh_poststartgame", "gifts_spawning", function()
	if conVars.fh_gifts_spawning:GetBool() then
		doGiftSpawning()
	end
end)

hook.Add("ShouldPlayerPush", "fh_push_management", function(pusher, victim)
	if victim.lobbyFreeze then
		return false
	end
end)

local function giveKillerShared(ply, killer, force)
	
	local killers_ = killers.getAll()
	
	local killerData = {}
	local killerName
	
	for k, v in pairs(killers_) do
		if v.name == killer or k == killer then
			killerData = killers_[k]
			killerName = k
			break
		end
	end
	
	if !killerName then
		killerName = killer
	end
	
	if !force then
		if usedKillers[killerName] then return end
		
		for _, v in pairs(usedKillers) do
			if ply == v then return end
		end
	end
		
	usedKillers[killerName] = ply

	pills.apply(ply:Nick(), killerName, "user")
	
	animatronics[ply] = true
	survivors[ply] = nil
	
	if timer.Exists("UnfreezeAnims") then
		ply.lobbyFreeze = true
	end
	
	if !killerData then
		print(ply:Nick() .. " is " .. killerName.." now.")
	elseif killerData.name then
		print(ply:Nick() .. " is " .. killerData.name.." now.")
	else
		print(ply:Nick() .. " is " .. killer.." now.")
	end
	
	killerData.ogName = killerName
	
	return killerData
end

function giveKiller(ply, killer, force, tpSpawn)
	force = force or false
	
	local killerData = giveKillerShared(ply, killer, force)
	
	if !killerData then return end
	
	if tpSpawn then
		local curSpawn
		
		local animSpawns = fhspawns.GetSpawnsFor(killerData.ogName)
		
		if animSpawns then
			table.Shuffle(animSpawns)
			
			for ent, _ in pairs(animSpawns) do
				curSpawn = ent
				break
			end
		end
		timer.Simple(0, function()
			if IsValid(curSpawn) and IsValid(ply) then
				ply:SetPos(curSpawn:GetPos())
				ply:SetEyeAngles(curSpawn:GetAngles())
			end
		end)
	end

    net.Start("KillerPicked")
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
	local class = baseclass.Get("player_sandbox")

	ply:AllowFlashlight(true)
	ply:SetRunSpeed(class.RunSpeed)
	ply:SetWalkSpeed(class.WalkSpeed)
	ply:SetJumpPower(200)
	ply:SetDuckSpeed(0.1)
	ply:SetUnDuckSpeed(0.1)
	ply:SetStepSize(18)
	ply:UnLock()
	ply:SetFOV(0, 0, game.GetWorld())
	ply:SetViewEntity(ply)

	ply:SetViewOffset(Vector(0, 0, 64))
	ply:SetViewOffsetDucked(Vector(0, 0, 28))
	
	ply:SetJumpBoost( 0.5 )
end

hook.Add("PlayerCanSeePlayersChat", "fh_chat", function(text, teamOnly, listener, speaker)
	if isGameOn and !roundEnding then
		if speaker:IsPlayer() and speaker:Team() == TEAM_SPECTATOR or !speaker:Alive() then
			if listener:Team() ~= TEAM_SPECTATOR then
				return false
			end
		end
	end
end)

function endRound(killerVictory, duration)
	killerVictory = killerVictory or false
	duration = duration or 10

	roundEnding = true
	SetGlobal2Bool("roundEnding", true)
	
	RunConsoleCommand("proximity_enabled", 0)
	
	fh.timer.RemoveTimer()
	
	timer.Remove("UnfreezeAnims")
	timer.Remove("RandomGifts")
	
	modifiers.End()
	
	hook.Run("fh_postendgame", killerVictory, animatronics)
	
	timer.Create("endGameWait", duration, 1, function() 
		endGame()
	end)
end

function endGame()
	SetGlobal2Bool("gameOn", false)
	isGameOn = false
	SetGlobal2Bool("roundActive", false)
	roundActive = false
	SetGlobal2Bool("roundPaused", false)
	roundPaused = false
	
	modifiers.DeactivateAll()
	
	forceAnimSelectTime = 0
	table.Empty(usedKillers)
	
	for _, ply in player.Iterator() do
		ply:SetTeam(TEAM_SURVIVOR)
		if ply:GetPill() then
			pills.restore(ply:Nick(), true)
		end
		ply:Spawn()
		setupPlayerVars(ply)
		if ply:HasWeapon("weapon_taser") then
			ply:StripWeapon("weapon_taser")
		end
		
		timer.Simple(0, function()
			if IsValid(ply) then
				ply:NoPlayerCollide(0.25)
			end
		end)
	end
	game.CleanUpMap( false )
	
	fh.timer.StartDefaultTimer(lobbyDuration, function()
		registerNewRound()
		roundEnding = false
		SetGlobal2Bool("roundEnding", false)
	end)
	
	RunConsoleCommand("proximity_enabled", 1)
end

function getScaledJumpBoost()
	local count = player.GetCount()
	
	if count < 8 then
		return 0.4
	elseif count < 18 then
		return 0.5
	end
	return 0.7
end

function GM:fh_prestartgame()
end

function GM:fh_poststartgame()
end

function GM:fh_postendgame()
end

function startGame(forceid)
	local _, players = player.Iterator()
	local fh_fast_roundrestart = conVars.fh_fast_roundrestart

	RunConsoleCommand("proximity_enabled", 1)
	lobbyDuration = fh_fast_roundrestart:GetBool() and 5 or 30
	
	if timer.Exists("endGameWait") then
		timer.Remove("endGameWait")
	end
	
	for _, ply in ipairs(players) do
		ply:SetTeam(TEAM_SURVIVOR)
		timer.Simple(0, function()
			if IsValid(ply) then
				ply:NoPlayerCollide(0.25)
			end
		end)
	end
	
	local fh_prestartgame = hook.Run("fh_prestartgame")
	
	if fh_prestartgame ~= nil and fh_prestartgame == false then 
		return 
	end
	
	local roundType = fh.SelectRoundType(forceid or nil)
	
	local fh_startgame = hook.Run("fh_startgame", roundType, animatronics)
	
	if fh_startgame ~= nil and fh_startgame == false then 
		return 
	end
	
	for _, ply in ipairs(players) do
		ply:SetJumpBoost( getScaledJumpBoost() )
	end
	
	fh.timer.StartGameTimer(
		fh.GetGameDuration(), 
		setupGameDuration, 
		"ambient/alarms/warningbell1.wav", 
		tostring(roundCount), 
		survivorsWin
	)
	
	net.Start('fh_adv_sound_play')
	net.WriteString( "#"..fh.GetRoundMusic( fh.GetRoundType() ) )
	net.WriteString( "timer_music" )
	net.Broadcast()
	
	modifiers.Setup(roundType)
	modifiers.Startup()
end

function registerNewRound(forceid)
	roundCount = roundCount + 1
	
	SetGlobal2Bool("gameOn", true)
	isGameOn = true
	SetGlobal2Bool("roundEnding", false)
	roundEnding = false
	table.Empty(survivors)
	table.Empty(animatronics)
	table.Empty(usedKillers)
    for _, ply in player.Iterator() do
        ply:Spawn()
		ply:SetTeam(TEAM_SURVIVOR)
		ply:RemoveRagdoll()
		survivors[ply] = true

		if ply:GetPill() then
			pills.restore(ply:Nick(), true)
		end
    end
	
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
	pills.restore(ply:Nick(), true)
	animatronics[ply] = nil
	survivors[ply] = true
	ply:SetTeam(TEAM_SURVIVOR)
end

function RandomTaser()
	-- для золотого фредди скипаем первый тик
	timer.Simple(0, function()
		local random_taser = team.GetPlayers( TEAM_SURVIVOR )
		local random_taserer = fh.randomChoice( random_taser )
		
		if IsValid(random_taserer) then
			random_taserer:Give("weapon_taser")
			random_taserer:SendLua( "LocalPlayer():ChatPrint(language.GetPhrase('fazhunt.give_taser'))" )
		end
	end)
end

local sub_timer = 0
function doGiftSpawning()
	if timer.Exists('RandomGifts') then return end
	timer.Create("RandomGifts", 120, 0, function()
		SpawnGifts()
		timer.Adjust("RandomGifts", 120 - sub_timer)
		sub_timer = 0
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
		if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
			local FH_ShouldPlayerReceiveGifts = hook.Run("FH_ShouldPlayerReceiveGifts", ply)
			
			if FH_ShouldPlayerReceiveGifts == false then continue end
			
			if ply:GetGiftOwnership() then continue end
			
			timer.Simple(math.random(10,100) / 10, function()
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

concommand.Add( "fh_grant_gift_bots", function( ply, cmd, args )
	timer.Simple(2, function()
		for _, ply in player.Iterator() do
			if !ply:IsBot() then continue end
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
	
	-- stupid :pray:
	RunConsoleCommand("sv_playermodel_selector_force", 0)
	
	-- выделенный сервер не включает таймер. пробую делать вот так
	isGameOn = false
	roundEnding = false
	
	fh.timer.RemoveTimerNB()
end )

hook.Add("PlayerInitialSpawn", "fh_ply_spawn", function(ply)
	setupPlayerVars(ply)
	
	ply:SetCustomCollisionCheck( true )
	
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
	
	ply:SetTeam(TEAM_SURVIVOR) -- это чё бля?
end)

hook.Add( "AllowPlayerPickup", "fh_allow_pickup", function( ply, ent )
    return ply:Team() != TEAM_SPECTATOR
end )

hook.Add("SetupMove", "fh_lock_position", function(ply, mv, cmd)
	if ply:IsAnimatronic() and !roundActive and isGameOn then
		mv:SetVelocity(Vector(0,0,0))
		mv:SetOrigin(ply:GetPos())
	end
end)

hook.Add("FinishMove", "fh_canmove", function(ply)
	if ply:IsAnimatronic() and !roundActive and isGameOn then
		ply:SetLocalVelocity(Vector(0,0,0))
		return true
	end
end)

hook.Add( "StartCommand", "fh_cantattack", function( ply, cmd )
	if ply:IsAnimatronic() and !roundActive and isGameOn then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
		cmd:RemoveKey(IN_RELOAD)
		cmd:RemoveKey(IN_JUMP)
	end
end)

hook.Add( "PlayerCanPickupWeapon", "no_double_pickup", function( ply, weapon )
    if ply:HasWeapon( weapon:GetClass() ) then
		return false
	end
end)

hook.Add("PlayerDisconnected", "fh_playerleft", function(ply)
	survivors[ply] = nil
	if animatronics[ply] then
		animatronics[ply] = nil
		if isGameOn and !roundEnding then
			local str = ply:Nick()
			local ent = ply:GetPill()
			if IsValid(ent) then
				if ent.formTable.printName then
					str = str .. " ( " .. ent.formTable.printName .. " )"
				end
			end
			net.Start("fh_animatronic_left_chatmessage")
			net.WriteString(str)
			net.Broadcast()
		end
	end
	
	winConditions(ply)
	
    if player.GetCount() == 1 and isGameOn then
        fh.timer.RemoveTimer()
    end
end)

hook.Add( "PlayerNoClip", "fh_noclip", function( ply, desiredNoClipState )
	if ply:IsAdmin() and ply:Team() ~= 2701 or ply:IsSuperAdmin() then
		return true
	end
end )

function GM:PlayerSetModel( pl )
	player_manager.RunClass( pl, "SetModel" )
end

local ENTITY_SetClass = FindMetaTable("Entity").SetClass
local PLAYER = FindMetaTable("Player")

function PLAYER:ReturnToSpawn()
	if not IsValid(self) or not self:IsPlayer() then return end

	local spawnPoint = hook.Run("PlayerSelectSpawn", self)

	self:SetPos(spawnPoint:GetPos())
	self:SetEyeAngles(spawnPoint:GetAngles())
end

function FixSetModel()
	PLAYER.SetModel = ENTITY_SetClass
end

hook.Add("PlayerSpawn", "fh_spawn", function( ply, transiton )
	player_manager.SetPlayerClass( ply, "player_sandbox" )
	ply:SetShouldServerRagdoll(true)

	if not IsValid(ply:GetPill()) then
		ply:SetMaterial("")
		ply:DrawShadow(true)
	end
	
	ply:SendLua( 'if !system.HasFocus() then system.FlashWindow() end' )
	
	if not isGameOn then
		ply:SetTeam(TEAM_SURVIVOR)
	end
	timer.Simple(0, function()
		ply:NoPlayerCollide(0.25)
	end)
	
	net.Start('DeadHUDDisable') net.Send(ply)
	net.Start('nv_off') net.Send(ply)
end)

if PLAYER then
	function PLAYER:RemoveRagdoll()
		if IsValid(self.DeathRagdoll) then
			self.DeathRagdoll:Remove()
		end
	end
end

hook.Add("PostPlayerDeath", "fh_killmask_outworld", function()
	if isGameOn and !roundEnding and table.Count(survivors) == 1 and table.Count(animatronics) == 1 then
		local goldenfreddy = fh.GetActiveUsedKiller("pill_wgfreddy2")
		local lastsurvivor
		
		if not IsValid(goldenfreddy) then return end

		for ply, _ in pairs(survivors) do
			if IsValid(ply) then
				lastsurvivor = ply
			end
		end
		
		if not lastsurvivor then return end

		if !lastsurvivor:GetNW2Bool("KillerObsessed") then return end

		if IsValid(goldenfreddy:GetPill()) then
			start_outworld_battle(goldenfreddy, goldenfreddy:GetPill(), lastsurvivor)
		end
	end
end)

hook.Add("EntityTakeDamage", "fh_anti_animatronic_death", function(target, dmginfo)
	if conVars.fh_respawn_dead_animatronics:GetBool() then
		if IsValid(target) and target:IsPlayer() and target:IsAnimatronic() then
			
			if hook.Run("fh_should_animatronic_respawn", target, dmginfo) == false then return end

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

	local attacker = dmginfo:GetAttacker()
	
	if IsValid(attacker) and (attacker:IsPlayer() and attacker:IsAnimatronic() or not attacker:IsPlayer()) then
		local ent = target
		local phys = ent:GetPhysicsObject()
		if ent.PropHealth and IsValid(phys) and phys:IsMotionEnabled() then
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

hook.Add("PlayerDroppedWeapon", "fh_drop_weapon", function(owner, wep)
	if owner:IsPlayer() then
		wep:SetVar("cantpickup", true)
		
		timer.Simple(0.5, function()
			if IsValid(wep) then
				wep:SetVar("cantpickup", false)
			end
		end)
	end
end)

hook.Add( "PlayerCanPickupWeapon", "fh_pickup_weapon", function( ply, weapon )
    if weapon:GetVar("cantpickup") then
		return false
	end
end )

hook.Add("OnEntityCreated", "fh_any_prop_isbreakable", function(ent)
	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if string.StartsWith(ent:GetClass(), "prop_physics") or ent:GetClass():find("func_physbox") then
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

hook.Add("EntityTakeDamage", "fh_no_grenade_teamkill", function(ent, dmginfo)
	local attacker = dmginfo:GetAttacker()
	local inflictor = dmginfo:GetInflictor()
	
	if !ent:IsPlayer() and IsValid(ent:GetPhysicsObject()) and IsValid(attacker) and IsValid(inflictor) then
		if attacker:IsPlayer() and inflictor:GetClass() == "npc_grenade_frag" then
			ent._ImpulseOwner = attacker
			
			local timerName = "reset_impulse_owner" .. ent:EntIndex()
			
			if timer.Exists(timerName) then
				timer.Remove(timerName)
			end
			
			timer.Create(timerName, 2, 1, function()
				if IsValid(ent) and ent._ImpulseOwner then
					ent._ImpulseOwner = nil
				end
			end)
		end
	end
	
	if attacker == ent then
		if dmginfo:IsExplosionDamage() then
			dmginfo:ScaleDamage(0.25)
		end
	end
	
	if attacker._ImpulseOwner then
		dmginfo:SetAttacker(attacker._ImpulseOwner)
	end
end)

hook.Add("OnEntityCreated", "farz_remember", function(ent)
	if ent:GetClass() == "env_fog_controller" then
		timer.Simple(1, function()
			local farz = ent:GetInternalVariable("farz")
			
			if farz <= 0 then farz = 6000 end
			
			SetGlobal2Float("FarZ", farz)
		end)
	end
end)

hook.Add("PlayerDroppedWeapon", "fh_drop_glow", function(owner, wep)
	wep:AddEffects( EF_ITEM_BLINK )
end)

local function fh_death_hook(victim)
	if survivors[victim] then
		survivors[victim] = nil
		
		if timer.Exists("RandomGifts") then
			local timertime = timer.TimeLeft("RandomGifts")
			if timertime >= 5 then
				timer.Adjust("RandomGifts", math.max(timertime - 5, 1))
			end
		end
		
		local animCount = table.Count(animatronics)
		
		if fh.GetActiveUsedKiller("pill_plushtrap") then
			animCount = math.max(animCount - 1, 1)
		end
		
		if isGameOn and !roundEnding then 
			if table.Count(survivors) == 1 then
				hook.Run("FH_LastManStanding")
				if roundType == 0 and animCount >= 2 and fh.timer.GetTimeLeft() >= 200 then
					fh.timer.CutBack(180, "round/time_cutback.mp3")
				end
			end
		end
	end
	animatronics[victim] = nil
end

hook.Add("PlayerDeath", "fh_deaths", fh_death_hook)
hook.Add("PlayerSilentDeath", "fh_deaths_silent", fh_death_hook)
hook.Add("PostPlayerDeath", "fh_deaths_post", function(victim)
	winConditions(victim)
	
	if isGameOn then
		victim:Spectate(OBS_MODE_CHASE)
		victim:SetTeam(TEAM_SPECTATOR)
		
		net.Start('DeadHUDEnable')
		net.Send(victim)
	end
end)

local animatronics_win_count = 0
local survivors_win_count = 0
function fh_win_coefficient()
    local totalWins = survivors_win_count + animatronics_win_count
    if totalWins == 0 then return end

    local survivorsPercentage = math.Round((survivors_win_count / totalWins) * 100)
    local animatronicsPercentage = math.Round((animatronics_win_count / totalWins) * 100)
	
	return totalWins, survivorsPercentage, animatronicsPercentage
end

local function animatronicsVictory(ply)
	local nickname = IsValid(ply) and ply:Nick() or "?"
	local timeleft = fh.timer.GetTimeLeft()

	net.Start("AnimatronicsWin")
	net.WriteString(nickname)
	net.WriteInt(fh.GetGameDuration() - timeleft, 16)
	net.Broadcast()
	
	endRound(true)
	
	animatronics_win_count = animatronics_win_count + 1
end

function survivorsWin()
	local plys = {}
	for ply, _ in pairs(survivors) do
		if not ply:IsValid() then return end
		table.insert(plys, ply:Nick())
	end
	
	net.Start('fh_net_scarysound')
	net.WriteBool(false)
	net.Broadcast()
	
	net.Start("SurvivorsWin")
	net.WriteTable(plys)
	net.Broadcast()
		
	survivors_win_count = survivors_win_count + 1
		
	endRound()
end

function winConditions(ply)
	if isGameOn and !roundEnding then
		if table.IsEmpty(survivors) then
			animatronicsVictory(ply)
			return
		end
		if table.IsEmpty(animatronics) then
			survivorsWin()
			return
		end
	end
end

-- нахуя оно создаёт второй НЕВИДИМЫЙ регдолл?
hook.Add( "CreateEntityRagdoll", "fh_ragdoll_bullshit", function( ply, rag )
	if ply:IsPlayer() then
		rag:Remove()
	end
end )

hook.Add( "CanPlayerSuicide", "fh_suicide", function( ply )
	if ply:IsAnimatronic() or ply.jumpscared then
		return false
	end
	if fh.timer.Exists() and fh.timer.GetTimeLeft() > fh.GetGameDuration() then
		return false
	end
end )

hook.Add( "PlayerShouldTakeDamage", "fh_shouldtakedamage", function( ply, attacker )
	if ply:IsPlayer() and attacker:IsPlayer() then
	
		local custom_cond = hook.Run("CustomPlayerTakeDamageConditions", ply, attacker)
		
		if custom_cond ~= nil then
			return custom_cond
		end
	
		if IsValid(attacker) and attacker ~= ply and 
			(ply:IsSurvivor() == attacker:IsSurvivor() or 
			ply:IsAnimatronic() and attacker:IsAnimatronic() and !conVars.fh_animatronic_ff:GetBool() or
			ply:IsAnimatronic() and conVars.fh_animatronic_immortal:GetBool()
			or attacker:Team() == TEAM_SPECTATOR 
			or !roundActive or roundEnding)
		then
			return false
		end
	end
end )

hook.Add("PillApply", "fh_joinpill", function(ply, ent)
	animatronics[ply] = true
	survivors[ply] = nil
end)

hook.Add("PillRestore", "fh_restorepill", function(ply, ent)
	if usedKillers[ent.formTable.name] then
		usedKillers[ent.formTable.name] = nil
	end
end)

hook.Add("GravGunPunt", "fh_gravgun_punt", function(ply,ent)
	timer.Simple(0, function()
		if !IsValid(ent) then return end
		
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocity(ply:GetAimVector() * 99999)
		end
	end)
end)

function GM:GetFallDamage( ply, speed )
	local damage = ( speed - 526.5 ) * ( 100 / 396 )
	local hasArmor = ply:Armor() > 0
	if hasArmor then
		ply:SetArmor(0)
	end
	return math.min( damage, hasArmor and 90 or 100 )
end

net.Receive("fh_selected_killer", function(len, ply)
	local killer = net.ReadString()
	
	if !usedKillers[killer] then
		giveKiller(ply, killer, nil, true)
		
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
	
	giveKiller(ply, killer, nil, true)
	
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
	if isGameOn then
		fh.timer.Send(ply)
	elseif fh.timer.Exists() then
		fh.timer.LobbySend(ply)
	end
	if player.GetCount() >= 2 and not isGameOn and !fh.timer.Exists() then
		fh.timer.StartDefaultTimer(lobbyDuration, registerNewRound)
	end
	
	net.Start("fh_share_notprefered")
	net.WriteTable(killers.getAllPreferables(true))
	net.Send(ply)
end)

local tm = nil
hook.Add("Tick", "fh_tick", function()
	for _, ply in player.Iterator() do
		tm = ply:Team()
		if tm == TEAM_SURVIVOR and ply:Alive() then
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

function FindSuitableVictoryPos(forwardCheck, backCheck)
	local win_location = ents.FindByClass("info_killer_win")[1]
	local win_camera = ents.FindByClass("fh_win_camera")[1]
	
	forwardCheck = forwardCheck or 150
	backCheck = backCheck or 10
	
	if win_location and win_camera then
		return win_location, win_camera
	end
	
	if !win_location then
		spawns = ents.FindByClass("info_player_start")
		spawns = updateSpawnList(spawns)
		
		for _, spawn in ipairs(spawns) do
			local pos = spawn:GetPos()
			local forward = spawn:GetForward()
			local backward = -spawn:GetForward()
			local up = spawn:GetUp()
			
			local tr = util.TraceLine( {
				start = pos,
				endpos = pos + (forward * forwardCheck) + (up * 60),
				filter = self
			} )
			
			local tr_back = util.TraceLine( {
				start = pos,
				endpos = pos + (backward * backCheck) + (up * 60),
				filter = self
			} )
			
			if !tr.Hit and !tr_back.Hit then
				win_location = spawn
			
				--debugoverlay.Box( tr.HitPos, Vector(-5,-5,-5), Vector(5,5,5), 25, Color( 255, 25, 25, 20 ) )
				--debugoverlay.Box( tr_back.HitPos, Vector(-5,-5,-5), Vector(5,5,5), 25, Color( 25, 25, 255, 20 ) )
				--debugoverlay.Box( pos, Vector(-5,-5,-5), Vector(5,5,5), 25, Color( 255, 255, 255, 25 ) )
				break
			end
		end
	end
	
	if !win_camera and win_location then
		local pos = win_location:GetPos()
		local ang = win_location:GetAngles()
		ang.p = ang.p + 180
	
		local ent = ents.Create("fh_win_camera")
		ent:SetPos(pos + Vector(0,0,70))
		ent:SetAngles(ang)
		ent:Spawn()
		
		--debugoverlay.Box( pos + Vector(0,0,70), Vector(-5,-5,-5), Vector(5,5,5), 8, Color( 25, 255, 25, 20 ) )
		win_camera = ent
	end
		
	return win_location, win_camera
end

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

hook.Add("fh_startgame", "FH_UpdateLastKillers", function(roundType, anims)
    for ply, _ in pairs(anims) do
        if IsValid(ply) then
			local id = GetPlyID(ply)
			local key = LK_ToKey(id)
			if id then
				LastKillers[key] = 0
			end
		end
	end

	for k,v in pairs(LastKillers) do
		LastKillers[k] = v + 1

		if LastKillers[k] > 15 then
			LastKillers[k] = nil
		end
	end

    SaveLastKillers()
end)

function fh.GetEarnedKillers(players)
	if not istable(players) then return {} end
	
	local data = {}
	local opt_out_people = {}
	
	for _, ply in ipairs(players) do
		if IsValid(ply) then
			if ply:GetInfoNum("fh_opt_out_anim", 0) == 1 then
				table.insert(opt_out_people, ply)
				table.RemoveByValue(players, ply)
			end
		end
	end
	
	if table.IsEmpty(players) then
		for _, ply in ipairs(opt_out_people) do
			table.insert(players, ply)
		end
	end
	
	for _, ply in ipairs(players) do
		if IsValid(ply) then
			
			local id = GetPlyID(ply)
			local key = LK_ToKey(id)
			local val = LastKillers[key]
			val = tonumber(val)
	
			table.insert(data, {
				ply = ply,
				val = val
			})
		end
	end
	
	table.sort(data, function(a, b)
		local va, vb = a.val, b.val
	
		if va == nil and vb == nil then
			return false
		elseif va == nil then
			return true
		elseif vb == nil then
			return false
		else
			return math.abs(va - 15) < math.abs(vb - 15)
		end
	end)
	
	local result = {}
	for _, d in ipairs(data) do
		table.insert(result, d.ply)
	end
	
	return result
end

local round_music = {
	[0] = "music/first_minute.wav"
}

if IsChristmas() then
	round_music[0] = "music/christmas_timer.wav"
end

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
	
	if fh.RoundTypes[id] then 
		print("[FH] Failed to register new round type with ID: " .. id .. ". Such ID is already in use!")
		return nil
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
	
	return id, name
end

function fh.SetRoundTypeBlocked(id, block)
	if !fh.RoundTypes[id] then return end
	if !isbool(block) then return end
	
	fh.RoundTypes[id].blocked = block
end

local forceAuto = {
	"fh_force_roundtype 0",
	"fh_force_roundtype 1",
	"fh_force_roundtype 2",
	"fh_force_roundtype 3",
}

concommand.Add( "fh_force_roundtype", function( ply, cmd, args )
	if !ply:IsSuperAdmin() then return end
	local round = tonumber(args[1]) or 0
	registerNewRound(round)
end,

function( cmd, args )
	return forceAuto
	
end)

function fh.SelectRoundType(forcedID)
    local selected
    local playerCount = player.GetCount()

    if forcedID then
        selected = fh.RoundTypes[forcedID]
		
		if selected.blocked then
			print("Forcing a round type that is blocked!")
		end
    else
        local pool = {}
        for id, data in pairs(fh.RoundTypes) do
			if data.blocked then continue end
		
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
		return selected.id
    else
        ErrorNoHalt("[fh] Couldn't select round type!\n")
		return -1
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

include( "rounds/springtrap.lua" )
include( "rounds/bonnie_tag.lua" )
include( "rounds/bear5.lua" )
include( "rounds/custom_round.lua" )