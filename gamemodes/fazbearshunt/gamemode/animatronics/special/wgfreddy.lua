AddCSLuaFile()

wgfreddy_targets = {}
outworld_victims = {}
outworld_victims_count = {}
local sfreddy_noclip_movement = {500, 600, 500, 250} -- это на случай если - fuppr_sfreddy_noclip 0

hook.Add( "PostCleanupMap", "wgfreddy_cleanup", function( name )
	table.Empty(outworld_victims)
	table.Empty(outworld_victims_count)
	table.Empty(wgfreddy_targets)
end)

function getOutworldVictims()
	return outworld_victims
end

function PlayerInOutworld(ply)
	return outworld_victims[ply] ~= nil or wgfreddy_targets[ply] ~= nil
end

include("wgoldenfreddy_head.lua")

if SERVER then
	util.AddNetworkString("fh_wgfreddy_target_outworld_start")
	util.AddNetworkString("fh_wgfreddy_target_outworld_end")
	
	util.AddNetworkString("fh_wgfreddy_selecting_halo")
	util.AddNetworkString("fh_wgfreddy_outworld_start")
	util.AddNetworkString("fh_wgfreddy_outworld_stop")
	
	util.AddNetworkString("fh_net_wgfreddy_scarysound")
	
	util.AddNetworkString("cl_target_wgfreddy_scared")
	util.AddNetworkString("wgfreddy_second_ambience")
	util.AddNetworkString("wgfreddy_plushie_hint")
	
	util.PrecacheModel("models/speps/pill/oldgoldenfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddyhead.mdl")
end

function GoldensBullshit_Start(ply, ent, timerName, sex)
	timer.Remove(timerName)
	
	GiveKillerSilent(ply, "fh_wgfreddyhead", true)
	
	local rf = RecipientFilter()
	rf:AddAllPlayers()
	rf:RemovePlayer(ply)
	
	local ent = ply:GetPillCostume()
	ent.RageSound = CreateSound(ent, ")fnaf2/gfreddy/gfreddy_enraged.wav", rf)
	ent.RageSound:PlayEx(0, 100)
	ent.RageSound:ChangeVolume(1, 3)
	
	net.Start("fh_gfreddyhead_jumpscare") net.Send(rf)
end

local function WGFreddyRoundCheck(ply, ent, timerName)
	if roundEnding or not roundActive then return end

	if fh.timer.Exists() and fh.timer.GetTimeLeft() < 120 then
		GoldensBullshit_Start(ply, ent, timerName, "2minutes")
		return
	end
	
	if table.Count(survivors) == 1 then
		GoldensBullshit_Start(ply, ent, timerName, "lastsurvivor")
		return
	end
	
	if table.Count(animatronics) == 1 then
		GoldensBullshit_Start(ply, ent, timerName, "lastgolden")
		return
	end
end

local gfreddy_movement = {130, 130, 0, 0}

--golden freddy

pills.register("pill_wgfreddy2",{
	printName="Withered Golden Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",
	bodyGroups={[0] = 1},
	anims={
		default={
			idle="idle",
			crouch="sit",
			walk="walk",
			run="run",
			out="sdpecial",
			inn="tonormal",
			scare="sscare",
			rage="rage",
			stun="sstun",
		},
		gestures={
			melee="melee",
		},
	},

	moveSpeed={
		walk=130,
	--	run=500,
		ducked=0,
	},
	sounds={
		gs="fnaf2/wgfreddy_laugh.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	bloodType=BLOOD_COLOR_MECH,
	
	viewmodel={
		weapon="v_freddy",
		skin=1
	},
	
	muteSteps = true,
	
	cloak={
		max=-1
	},
    jumpPower=0,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,
	
	initialize=function(ply,ent)
		ply:DrawViewModel(false)
		ent:SetSpeed( unpack(sfreddy_noclip_movement) )
		ent:SetMaterial("models/null")
		ent:DrawShadow(false)
		
		ply:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
		ply:CollisionRulesChanged()
		
		ply:SetAudible(false)
		ply:SetPushBlocked(true)
		
		ent.cloaked = true
		
		ply:SetNWBool("wgfreddy_enraged", false)
		
		local tracker = ents.Create("fh_stuck_tracker")
		tracker:SetPos(ply:GetPos())
		tracker:SetOwner(ply)
		tracker:Spawn()
		tracker:Activate()
		
		tracker.TeleportCond = function()
			if not ent.cloaked then return false end
		end
		
		ent.stuck_tracker = tracker
		
		local timerName = ent:EntIndex()
		timer.Create(timerName, 1, 0, function()
			if not IsValid(ply) then timer.Remove(timerName) return end
			if not IsValid(ent) then timer.Remove(timerName) return end
			WGFreddyRoundCheck(ply, ent, timerName)
		end)
	end,
	
	restore=function(ply, ent, ft)
		if CLIENT then
			hook.Remove("PostDrawTranslucentRenderables", "fh_draw_gfreddy_target_text")
			return 
		end
		cancel_outworld(ply)
		
		ply:SetCollisionGroup( COLLISION_GROUP_PLAYER )
		
		ply:SetPushBlocked(false)
		ply:SetPushImmune(false)
		
		ply:SetAudible(true)
		ply:ResetListenPlayer()
		
		if IsValid(ent.stuck_tracker) then
			ent.stuck_tracker:Remove()
		end
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
		if !ply:GetNWBool("wgfreddy_enraged") then return false end
		
		if IsValid(target) and !target:IsInvisible() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if !wgfreddy_targets[ply] then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			if !ply:GetNWBool("wgfreddy_enraged") then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 130, ply, 75)
			
			if target ~= wgfreddy_targets[ply] then
				AnimatronicBreakProp(ply, ent)
				return 
			end

			local jumpscare = performJumpscare(ply, ent, target, 1.6, nil, 50, "v_freddy")
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end
			
			local victim = wgfreddy_targets[ply]
			
			if !victim or cooldown.Exists(ply, 'submerge') then return end
			if ply:GetNWBool("wgfreddy_enraged") then return end
			
			ply:LagCompensation( false )
			
			if !ent.cloaked then
				if !ply:OnGround() and ply:WaterLevel() == 0 then return end
				if !IsValid(ent) then return end
				
				cooldown.Set(ply, 'submerge', 10)
				cooldown.Send(ply, 'submerge')
				
				if fh_can_see_player(victim, ply, 1500) then
					wgfreddy_targets[ply]:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
					
					
					local rf = RecipientFilter()
					rf:AddPlayer(victim)
					rf:AddPlayer(ply)
					
					EmitSound("gfreddy.laugh", ply:GetPos(), nil, nil, nil, nil, nil, nil, nil, rf)
				end
				
				ent:SetSpeed( unpack(sfreddy_noclip_movement) )
				ply:DrawViewModel(false)
						
				ent:SetMaterial("models/null")
				ent:DrawShadow(false)
				
				ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
				ply:CollisionRulesChanged()
				
				ent.cloaked=true
				
			else
				if fh_can_see_player(victim, ply, 1600) then return end
				
				cooldown.Set(ply, 'submerge', 1)
				cooldown.Send(ply, 'submerge')
			
				local trace = util.TraceHull({
					start = ply:GetPos(),
					endpos = ply:GetPos(),
					mins = ply:OBBMins(),
					maxs = ply:OBBMaxs(),
					filter = ply
				})
				
				if trace.Hit then
					net.Start("fh_play_sound")
					net.WriteString('sfreddyerror.wav')
					net.Send(ply)
					return 
				end
				
				ply:DrawViewModel(true)
				ent:SetSpeed( unpack(gfreddy_movement) )
				
				ent:SetMaterial()
				ent:DrawShadow(true)
					
				--ply:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
				ply:CollisionRulesChanged()
							
				ent.cloaked=false
			end
			ply:LagCompensation( true )
			
		end
	},
	
	reload=function(ply,ent)
		if wgfreddy_targets[ply] then return end

		local target = fh_get_wgfreddy_target(ply)
		
		if !IsValid(target) then return end
			
		if !navmesh.IsLoaded() or navmesh.GetNavAreaCount() < 5 then 
			ply:ChatPrint("Refused. No navmesh.")
			return 
		end
		
		if PlayerInOutworld(target) then return end
		
		start_outworld(ply, ent, target)
	end,

	jump=function(ply,ent)
		--ent:PillSound("jump",false)
	end
})

util.PrecacheSound("fnaf2/gfreddy/plushie_hint.mp3")
util.PrecacheSound("fnaf2/gfreddy/plushie_taken.wav")
util.PrecacheSound("fnaf2/gfreddy/plushie_taken_alert.wav")
util.PrecacheSound("fnaf2/gfreddy/gfreddy_target.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_escaped.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_enter.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_ambient_loop.wav")
util.PrecacheSound("fnaf2/gfreddy/outworld_ambient_2.wav")

team.SetUp( 27, "Secret Animatronics", Color(255, 0, 0), true )

local gfreddy_enraged_movement = {130, 560, 130, 250}

hook.Add("fh_startgame", "spawn_wgfreddy", function(roundType)
	if !conVars.fh_goldenfreddy_spawning:GetBool() then return end

	if !navmesh.IsLoaded() or navmesh.GetNavAreaCount() < 5 then
		return
	end
	
	if math.random(1,8) == 1 or GetConVar( "developer" ):GetBool() then
		if roundType == 0 then
			local players = team.GetPlayers(TEAM_SURVIVOR)
			local count = table.Count(players)
			
			if count >= 12 or ( GetConVar( "developer" ):GetBool() and count > 2 ) then
				players = fh.GetEarnedKillers(players)
				
				local chosenPlayer = players[1]
		
				GiveKillerSilent(chosenPlayer, "pill_wgfreddy2", true)
				chosenPlayer:ReturnToSpawn()
			end
		end
	end
end)

hook.Add("PillSound", "gf_pillsound_management", function(ply, ent, name)
	if !table.IsEmpty(wgfreddy_targets) then
		for gfreddy, victim in pairs( wgfreddy_targets ) do
			if IsValid(victim) and IsValid(gfreddy) then -- на всякий случень
				if ply ~= outworld_victims[victim] and ply ~= wgfreddy_targets[gfreddy] then
					local rf = RecipientFilter()
					rf:AddPlayer(victim)
					rf:AddPlayer(gfreddy)
					
					return rf
				end
			end
		end
	end
end)

hook.Add("FH_PlayerShouldJumpscare", "wgfreddy_target_jumpscare", function(ply, ent, target)
	if ent.formTable and ent.formTable.name ~= "pill_wgfreddy2" then
		if outworld_victims[target] then 
			return false
		end
	end
end)

hook.Add( "PlayerShouldTaunt", "gfreddy_taunt", function( ply, act )
	if outworld_victims[ply] then
		return false
	end
end )

hook.Add("PlayerShouldTakeDamage", "gf_nodamage", function(ply, attacker)
	if fh.GetActiveUsedKiller("pill_wgfreddy2") == ply then
		return false
	end
	
	if outworld_victims[ply] and (attacker ~= outworld_victims[ply] and attacker ~= game.GetWorld()) then
		return false
	end
end)

hook.Add("FH_HandleTaserHit", "gf_notaser", function(ply)
	if wgfreddy_targets[ply] then
		return false
	end
end)

hook.Add("FH_HandleBlindRageTarget", "gf_noblindrage", function(ply, target)
	if outworld_victims[target] then
		return false
	end
end)

hook.Add("ShouldCollide", "gf_collide", function(ent1, ent2)
	if ent1:IsPlayer() and ent2:IsPlayer() then
		if ent1:GetNW2Bool("_OUTWORLD_target") and !ent2:GetNW2Bool("_OUTWORLD_gfreddy")  then
			return false
		elseif ent2:GetNW2Bool("_OUTWORLD_target") and !ent1:GetNW2Bool("_OUTWORLD_gfreddy") then
			return false
		end
		
		if ent1:GetNW2Bool("_OUTWORLD_gfreddy") and !ent2:GetNW2Bool("_OUTWORLD_target")  then
			return false
		elseif ent2:GetNW2Bool("_OUTWORLD_gfreddy") and !ent1:GetNW2Bool("_OUTWORLD_target") then
			return false
		end
	end
end)

hook.Add("FH_HandlePlayerGrab", "gf_victim_nograb", function(endo, ply)
	if outworld_victims[ply] then
		return false
	end
end)

hook.Add("FH_HandlePlayerHold", "gf_victim_nohold", function(tchica, ply)
	if outworld_victims[ply] then
		return false
	end
end)

local function gfreddy_death_handle(victim, inflictor, attacker)
	if wgfreddy_targets[victim] then
		cancel_outworld(victim)
	end
	if outworld_victims[victim] then
		cancel_outworld(victim)
	end
end

hook.Add("PlayerDeath", "gf_world_death", gfreddy_death_handle)
hook.Add("PlayerSilentDeath", "gf_world_silentdeath", gfreddy_death_handle)

if SERVER then
	hook.Add("PillServerApply", "gf_joinpill", function(ply, name)
		if name == "pill_wgfreddy2" then
			ply:SetTeam(27)
		end
	end)
end

function fh_spawnPlushies(ply)
	if CLIENT then return end
	if !IsValid(ply) then return -1 end
	
	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then
		print("[fh_plushie] Нет nav-меша.")
		return -2
	end

	local origin = ply:GetPos()
	local minDistFromPlayer = 1000
	local maxDistFromPlayerStrict = 2700
	local maxDistFromPlayerLoose = 2400
	local sameFloorDist = 140
	local sameFloorDistMax = 450
	local minSpacing = 1600
	local plushCount = 4
	local placed = 0
	local usedPositions = {}
	
	local function spawnPlushAt(pos)
		local ent = ents.Create("fh_plushie")
		if IsValid(ent) then
			ent:Spawn()
            ent:SetPos(pos)
			ent:SetOwner(ply)
			table.insert(usedPositions, pos)
			placed = placed + 1
		end
	end
	
	local function isFarFromOthers(pos, minimumSpacing)
		minimumSpacing = minimumSpacing or minSpacing
		for _, used in ipairs(usedPositions) do
			if used:DistToSqr(pos) < minimumSpacing^2 then
				return false
			end
		end
		return true
	end
	
	table.Shuffle(areas)
	
	for _, area in ipairs(areas) do
		if placed >= plushCount then break end
		if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
		local pos = area:GetCenter()
		local distSqr = origin:DistToSqr(pos)
		
		if distSqr >= minDistFromPlayer^2 and distSqr <= maxDistFromPlayerStrict^2 and isFarFromOthers(pos) and math.abs(origin.z - pos.z) < sameFloorDist then
			spawnPlushAt(pos)
		end
	end
	
	if placed < plushCount then
		for _, area in ipairs(areas) do
			if placed >= plushCount then break end
			if area:HasAttributes(NAV_MESH_CROUCH) or area:HasAttributes(NAV_MESH_AVOID) or area:IsUnderwater() then continue end
	
			local pos = area:GetCenter()
			if origin:DistToSqr(pos) <= maxDistFromPlayerLoose^2 and isFarFromOthers(pos, 800) and math.abs(origin.z - pos.z) < sameFloorDistMax then
				spawnPlushAt(pos)
			end
		end
	end
	
	if placed < plushCount then
		print("[fh_plushie] Не удалось заспавнить "..plushCount.." плюшки. Заспавнено: " .. placed)
		if placed < 3 and placed > 0 then
			outworld_victims_count[ply] = (outworld_victims_count[ply] or 0) + (3 - placed)
		end
	else
		print("[fh_plushie] Успешно заспавнены "..plushCount.." плюшки.")
	end
	return placed
end

function killPlushies(ply)
	for _, ent in ipairs( ents.FindByClass("fh_plushie") ) do
		if ent:GetOwner() == ply then
			ent:Remove()
		end
	end
end

function pickupPlushie(ply, ent)
	ent:Remove()

	outworld_victims_count[ply] = (outworld_victims_count[ply] or 0) + 1

	if outworld_victims_count[ply] == 3 then
		cancel_outworld(ply)
	else
		net.Start("fh_ui_sound_play")
		net.WriteString("fnaf2/gfreddy/plushie_taken.wav")
		net.Send(ply)
		
		ply._LastGFPlushie = CurTime()
		
		PauseDamage(ply, 10)
		
		net.Start("fh_ui_sound_play")
		net.WriteString("fnaf2/gfreddy/plushie_taken_alert.wav")
		net.Send(outworld_victims[ply])
	end
end

hook.Add("KeyPress", "fh_plushie_use_check", function(ply, key)
	if key ~= IN_USE then return end
	if !outworld_victims[ply] then return end

	local eyePos = ply:EyePos()
	local viewDir = ply:GetAimVector()

	for _, ent in ipairs(ents.FindByClass("fh_plushie")) do
		if !IsValid(ent) then continue end

		local toEnt = ent:GetPos() - eyePos
		local distSqr = toEnt:LengthSqr()
		if distSqr > (200 * 200) then continue end

		local dirToEnt = toEnt:GetNormalized()
		local dot = viewDir:Dot(dirToEnt)

		if dot >= 0.9848 then -- примерно 10 градусов угол
			pickupPlushie(ply, ent)

			break
		end
	end
end)

if SERVER then
	hook.Add( "CanPlayerSuicide", "fh_gfreddy_suicide", function( ply )
		if outworld_victims[ply] then
			return false
		end
	end )
	
	hook.Add("PlayerCanSeePlayersChat", "fh_gfreddy_chat", function(text, teamOnly, listener, speaker)
		if isGameOn and !roundEnding then
			if speaker:IsPlayer() and IsValid(speaker:GetPill()) and speaker:GetPill():GetPillName() == "pill_wgfreddy2" then
				return false
			end
			
			if outworld_victims[speaker] and listener ~= outworld_victims[speaker] then
				return false
			end
		end
	end)
end

function fh_get_wgfreddy_target(ply)
	local eyePos = ply:EyePos()
	local aimDir = ply:GetAimVector()
	
	local closestPlayer = nil
	local closestDist = math.huge
	local maxDistToLine = 50
	local maxRadius = 300
	
	for _, target in player.Iterator() do
		if target == ply or not IsValid(target) or !target:Alive() or target:Team() ~= TEAM_SURVIVOR or target == stalkTarget then continue end
		
		if target:GetGFreddyImmune() then continue end
	
		local targetPos = target:GetPos() + Vector(0, 0, 40)
		local toTarget = targetPos - eyePos
		local projLength = toTarget:Dot(aimDir)
		local closestPoint = eyePos + aimDir * projLength
	
		local distToLine = targetPos:Distance(closestPoint)
		local distToPlayer = ply:GetPos():Distance(target:GetPos())
	
		if distToLine <= maxDistToLine and distToPlayer <= maxRadius then
			if distToLine < closestDist then
				closestDist = distToLine
				closestPlayer = target
			end
		end
	end
	return closestPlayer
end

local PLAYER = FindMetaTable("Player")
if PLAYER then
	function PLAYER:SetGFreddyImmune(bool)
		self:SetNWBool("GFreddyImmune", bool)
	end
	
	function PLAYER:GetGFreddyImmune()
		return self:GetNWBool("GFreddyImmune", false)
	end
end

local function cancel_outworld_target(ply)
	if isGameOn and !roundEnding then
		net.Start("fh_net_scarysound")
		net.WriteBool(true)
		net.Send(ply)
	end
	
	inventory_backup.SuppressNextSave(ply)

	ply:SetJumpBoost(getScaledJumpBoost())
	ply:SetRunSpeed(420)
	ply:SetWalkSpeed(200)
	ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
	ply:CollisionRulesChanged()
	ply:SetDSP(1)
	ply:SetFOV(0, 0, game.GetWorld())
	
	ply:SetPushImmune(false)
	ply:SetPushBlocked(false)
	
	ply:SetAudible(true)
	ply:SetDeaf(false)
	
	ply:SetGFreddyImmune(true)
	
	for _, enemy in ipairs( ents.FindInSphere( ply:GetPos(), 350 ) ) do
		if not enemy:IsPlayer() or not enemy:Alive() or enemy:IsSurvivor() then continue end
		
		if enemy:IsAnimatronic() then -- находим первого попавшего анимона и даруем бессмертие жертве
			
			ply:GodEnable()
			ply:SetRunSpeed(500)
			
			timer.Simple(8, function()
				if IsValid(ply) then
					ply:GodDisable()
					ply:SetRunSpeed(420)
				end
			end)
			
			break
		end
	end

	net.Start("fh_wgfreddy_target_outworld_end")
	net.Send(ply)

	net.Start("fh_adv_sound_play")
	net.WriteString("fnaf2/gfreddy/outworld_escaped.wav")
	net.Send(ply)
end

hook.Add("PlayerSpawn", "wgfreddy_spawn", function(ply)
	ply:SetGFreddyImmune(false)
	
	if wgfreddy_targets[ply] or outworld_victims[ply] then
		cancel_outworld(ply)
	end
end)
hook.Add("PlayerCanPickupWeapon", "wgfreddy_pickup", function(ply)
	if wgfreddy_targets[ply] or outworld_victims[ply] then
		return false
	end
end)

local sfreddy_noclip_movement = {500, 600, 500, 250}
local function cancel_outworld_wgfreddy(ply)
	ply:ResetListenPlayer()
	
	net.Start("fh_wgfreddy_outworld_stop")
	net.Send(ply)
	
	local wasRaged = ply:GetNWBool("wgfreddy_enraged")
	
	if wasRaged then
		ply:SetNWBool("wgfreddy_enraged", false)
	end

	local ent = pills.getMappedEnt(ply)
	if !IsValid(ent) or !ply:Alive() then return end
	
	if wasRaged then
		ent.anim = nil
	end
		
	net.Start("fh_wgfreddy_selecting_halo")
	net.Send(ply)

	if not ent.cloaked then
		ent:SetSpeed(unpack(sfreddy_noclip_movement))
		ply:DrawViewModel(false)

		ent:SetMaterial("models/null")
		ent:DrawShadow(false)
		
		ply:SetPushImmune(false)

		ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		ply:CollisionRulesChanged()

		ent.cloaked = true
	end
end

local function stopPrevent_outworld(wgfreddy, target)
	for _, ply in player.Iterator() do
		if ply ~= target and ply ~= wgfreddy then
			RecursiveSetPreventTransmit(ply, target, true)
			RecursiveSetPreventTransmit(ply, wgfreddy, true)
			
			if ply:Alive() and ply:Team() ~= TEAM_SPECTATOR then
				RecursiveSetPreventTransmit(target, ply, true) 
				RecursiveSetPreventTransmit(wgfreddy, ply, true)
			end
		end
	end
end

local function startTransmit_outworld(wgfreddy, target)
	for _, ply in player.Iterator() do
		if IsValid(target) then
			RecursiveSetPreventTransmit(ply, target, false)
		end
		if IsValid(wgfreddy) then
			RecursiveSetPreventTransmit(ply, wgfreddy, false)
		end
		if ply ~= target and ply ~= wgfreddy then
			RecursiveSetPreventTransmit(target, ply, false) 
			RecursiveSetPreventTransmit(wgfreddy, ply, false)
		end
	end
end

hook.Add( "WeaponEquip", "gfreddy_weaponequip", function( weapon, ply )
	timer.Simple(0, function()
		if not table.IsEmpty(outworld_victims) then
			for victim, gfreddy in pairs(outworld_victims) do
				RecursiveSetPreventTransmit(ply, victim, true) 
				RecursiveSetPreventTransmit(ply, gfreddy, true)
			end
		end
	end)
end )

hook.Add("PostPlayerDeath", "gfreddy_transmit", function(ply)
	if not table.IsEmpty(outworld_victims) then
		for victim, gfreddy in pairs(outworld_victims) do
			RecursiveSetPreventTransmit(victim, ply, false) 
			RecursiveSetPreventTransmit(gfreddy, ply, false)
		end
	end
end)

hook.Add("PlayerSpawn", "gfreddy_transmit", function(ply)
	if not table.IsEmpty(outworld_victims) then
		for victim, gfreddy in pairs(outworld_victims) do
			RecursiveSetPreventTransmit(victim, ply, true) 
			RecursiveSetPreventTransmit(gfreddy, ply, true)
		end
	end
end)

function start_outworld(ply, ent, target)
	local placedPlushies = fh_spawnPlushies(target)
	
	if placedPlushies <= 0 then
		print("[GF] Failed to spawn plushies for Golden Freddy: " .. ply:Nick() .. " and Target: " .. target:Nick())
		print("[GF] Plushie Error Code: " .. placedPlushies)
		return
	end
	
	stopPrevent_outworld(ply, target)

	net.Start("fh_play_sound")
	net.WriteString('fnaf2/gfreddy/gfreddy_target.wav')
	net.Send(ply)
	
	net.Start("fh_wgfreddy_outworld_start") -- для ЗФ
	net.WritePlayer(target)
	net.Send(ply)
	
	ply:ChatPrint(target:Nick() .. " - твоя цель.")
	
	StartDelayedDamage(target)
	
	target:SetNWBool("can_be_gf_scared", true)
	target:SetNWEntity("_WGoldenFreddy", ply)
	
	ply:SetNW2Bool("_OUTWORLD_gfreddy", true)
	target:SetNW2Bool("_OUTWORLD_target", true)
	
	inventory_backup.SaveCurrentInventory(target)
	target:StripWeapons()
	
	inventory_backup.SuppressNextSave(target, true)
	
	ply:SetPushImmune(true)
	target:SetPushImmune(true)
	target:SetPushBlocked(true)
	
	target:SetAudible(false)
	target:SetDeaf(true)
	ply:ForceListenPlayer(target)
	
	--target:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
	target:SetRunSpeed(240)
	target:SetWalkSpeed(120)
	target:SetJumpBoost(0)
	target:SetFOV(75, 0, game.GetWorld())
	
	target._LastGFPlushie = CurTime()
	
	net.Start("fh_net_wgfreddy_scarysound")
	net.WriteBool(true)
	net.Send(target)
	
	local timer_name = "plushie_hint_" .. ply:EntIndex()
	
	timer.Create(timer_name, 20, 0, function()
		if !IsValid(ply) or !IsValid(target) then
			timer.Remove(timer_name)
			return 
		end
	
		local plushies = ents.FindByClass("fh_plushie")
	
		if #plushies == 0 then
			timer.Remove(timer_name)
			return
		end
	
		local allFar = true
		local closestPlushie = nil
		local closestDistance = math.huge
	
		for _, plushie in ipairs(plushies) do
			if not IsValid(plushie) then continue end
	
			local dist = plushie:GetPos():Distance(target:GetPos())
	
			if dist <= 1400 then
				allFar = false
				break
			end
	
			if dist < closestDistance then
				closestDistance = dist
				closestPlushie = plushie
			end
		end
	
		if allFar and IsValid(closestPlushie) then
			net.Start("wgfreddy_plushie_hint")
			net.WriteVector(closestPlushie:GetPos())
			net.Send(target)
		end
	end)
	
	wgfreddy_targets[ply] = target
	outworld_victims[target] = ply
	outworld_victims_count[target] = 0
	
	net.Start("fh_wgfreddy_target_outworld_start")
	net.WritePlayer(ply)
	net.Send(target)
	
	hook.Run("FH_OutworldStart", ply, target)
end

function start_outworld_battle(ply, ent, target)
	
	stopPrevent_outworld(ply, target)
	
	net.Start("fh_play_sound")
	net.WriteString('fnaf2/gfreddy/gfreddy_killermask_enter.wav')
	net.Broadcast()
	
	net.Start("fh_wgfreddy_outworld_start") -- для ЗФ
	net.WritePlayer(target)
	net.Send(ply)
	
	ply:ChatPrint(target:Nick() .. " - твоя цель.")
	
	target:SetNWBool("can_be_gf_scared", true)
	--target:SetNWEntity("_WGoldenFreddy", ply)
	-- надо ли?
	
	ply:SetNWBool("wgfreddy_enraged", true)
	
	ply:SetNW2Bool("_OUTWORLD_gfreddy", true)
	target:SetNW2Bool("_OUTWORLD_target", true)
	
	ply:SetPushImmune(true)
	ply:SetPushBlocked(true)
	target:SetPushImmune(true)
	target:SetPushBlocked(true)
	
	ply:SetAudible(true)
	
	--target:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
	
	ply:DrawViewModel(true)
	if ent.cloaked then
		
		ent:SetMaterial()
		ent:DrawShadow(true)
			
		--ply:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
		ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		ply:CollisionRulesChanged()
					
		ent.cloaked=false
		timer.Simple(0.5, function()
			if IsValid(wgfreddy) and wgfreddy:IsStuck() then
				wgfreddy:Unstuck()
			end
		end)
	end
	
	ent:SetSpeed(unpack(gfreddy_enraged_movement))
	
	wgfreddy_targets[ply] = target
	outworld_victims[target] = ply
	outworld_victims_count[target] = 0
	
	net.Start("fh_wgfreddy_target_outworld_start") -- dlya targeta
	net.WritePlayer(ply)
	net.Send(target)
	
	hook.Run("FH_OutworldStart", ply, target)
end

local first_damage_received = {}

function cancel_outworld(ply)
	local wgfreddy
	local victim
	
	if wgfreddy_targets[ply] then
		wgfreddy = ply
		victim = wgfreddy_targets[ply]
	elseif outworld_victims[ply] then
		victim = ply
		wgfreddy = outworld_victims[ply]
	end
	
	if wgfreddy then
		cancel_outworld_wgfreddy(wgfreddy)
	end
	
	if victim then
		cancel_outworld_target(victim)
		StopDelayedDamage(victim)
		killPlushies(victim)
		victim:SetNWBool("can_be_gf_scared", false)
		victim:SetNWEntity("_WGoldenFreddy", nil)
	end
	
	startTransmit_outworld(wgfreddy, victim)
		
	net.Start('fh_sound_stop')
	net.WriteString('fnaf2/gfreddy/gfreddy_enraged.wav')
	net.Broadcast()
	
	hook.Run("FH_OutworldEnd", wgfreddy, victim)

	if victim then
		outworld_victims[victim] = nil
		first_damage_received[victim] = nil
		victim:SetNW2Bool("_OUTWORLD_target", false)
	
		if victim:Alive() then
			victim:SetSuppressPickupNotices(true)
			inventory_backup.LoadBackup(victim)
			victim:SetSuppressPickupNotices(false)
		end
	end
	if wgfreddy then
		wgfreddy_targets[wgfreddy] = nil
		wgfreddy:SetNW2Bool("_OUTWORLD_gfreddy", false)
	end
end

hook.Add( "SetupPlayerVisibility", "fh_pvs_wgfreddy_target", function( ply, viewEntity )
	for player,v in pairs( outworld_victims ) do
		if IsValid(player) and player ~= ply then
			AddOriginToPVS(player:GetPos())
		end
	end
end )

hook.Add("PlayerDisconnected", "fh_wgfreddy2_disconnect", function(ply)
	if wgfreddy_targets[ply] or outworld_victims[ply] then
		cancel_outworld(ply)
	end
end)


hook.Add("FH_ShouldPlayerReceiveGifts", "no_outworld_gifts", function(ply)
	if outworld_victims[ply] then
		return false
	end
end)

hook.Add("FH_PlayerShouldHearVoiceline", "no_outworld_voicelines", function(ply)
	if outworld_victims[ply] or wgfreddy_targets[ply] then
		return false
	end
end)

local DamageTimers = {}

function StartDelayedDamage(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	
	local steamID = ply:SteamID()
	
	ply._damagePausedUntil = CurTime() + 0
	
	if DamageTimers[steamID] then return end
	
	timer.Simple(10, function()
		if not IsValid(ply) or !outworld_victims[ply] then return end
	
		local timerName = "DamagePlayer_" .. steamID
		DamageTimers[steamID] = timerName
	
		timer.Create(timerName, 2, 0, function()
			if not IsValid(ply) or !outworld_victims[ply] then
				StopDelayedDamage(ply)
				return
			end
	
			if ply._damagePausedUntil and CurTime() < ply._damagePausedUntil then
				return
			end
			
			local playerIsHealthy = ply:Health() > 100 
				or ply:Armor() > 10 
				or (isGameOn and fh.timer.Exists() and fh.timer.GetTimeLeft() < 180)
				or (ply._LastGFPlushie and ply._LastGFPlushie < CurTime() - 60)
				
			local isMoving = ply:GetVelocity():Length() > 10
			
			timer.Adjust(timerName, isMoving and 2 or 1)
			
			local amountDmg = playerIsHealthy and 2 or 1
				
			--print(ply._LastGFPlushie, CurTime(), CurTime() - 60)
	
			local dmg = DamageInfo()
			dmg:SetDamage(amountDmg)
			dmg:SetAttacker(game.GetWorld())
			dmg:SetDamageType(DMG_GENERIC)
			ply:TakeDamageInfo(dmg)
		end)
	end)
end

function PauseDamage(ply, duration)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	ply._damagePausedUntil = CurTime() + duration
end

function StopDelayedDamage(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local steamID = ply:SteamID()
	local timerName = DamageTimers[steamID]

	if timerName then
		timer.Remove(timerName)
		DamageTimers[steamID] = nil
	end

	ply._damagePausedUntil = CurTime() + 999999 -- самый тупой и ебланский фикс одной хуйни
end

if SERVER then
	net.Receive("cl_target_wgfreddy_scared", function( len, ply )
		if outworld_victims[ply] and ply:Alive() then
			local wgfreddy = outworld_victims[ply]
			local victim = wgfreddy_targets[wgfreddy]
			
			if !victim then return end
			
			local damage = math.min(ply:Health() / 2, 20)
		
			if ply:Health() - damage > 0 then
				ply:TakeDamage( damage, wgfreddy, wgfreddy:GetActiveWeapon() )
			end
			
			if !first_damage_received[ply] then
				net.Start("wgfreddy_second_ambience")
				net.Send(ply)
				
				first_damage_received[ply] = true
			end
			
			local ent = pills.getMappedEnt(wgfreddy)
			
			if !IsValid(ent) then return end
			
			if ply:Health() < 30 and !wgfreddy:GetNWBool("wgfreddy_enraged") then
				StopDelayedDamage(ply)
				
				if ent.cloaked then
					ply:DrawViewModel(true)
					
					ent:SetMaterial()
					ent:DrawShadow(true)
						
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					ply:CollisionRulesChanged()
								
					ent.cloaked=false
					timer.Simple(0.5, function()
						if IsValid(wgfreddy) and wgfreddy:IsStuck() then
							wgfreddy:Unstuck()
						end
					end)
				end
				
				wgfreddy:SetNWBool("wgfreddy_enraged", true)
				ent:SetSpeed(unpack(gfreddy_enraged_movement))
				ent:PillAnim("rage",true)
				ply:SetNWBool("can_be_gf_scared", false)
				
				net.Start("fh_ui_sound_play")
				net.WriteString('fnaf2/gfreddy/gfreddy_rage_start.mp3')
				net.Send({ply, wgfreddy})
				
				ply:SetJumpBoost(getScaledJumpBoost())
				ply:SetRunSpeed(420)
				ply:SetWalkSpeed(200)
				
				timer.Simple(10, function()
					if IsValid(ent) and IsValid(ply) and ply:Alive() and IsValid(wgfreddy) and wgfreddy:Alive() then
						if wgfreddy and victim then
							net.Start('fh_ent_sound_play')
							net.WriteEntity(wgfreddy)
							net.WriteString('fnaf2/gfreddy/gfreddy_enraged.wav')
							net.Send({ply, wgfreddy})
						end
					end
				end)
				
				return
			end
			
			if not ent.cloaked then
			
				if fh_can_see_player(victim, wgfreddy, 1500) then
					victim:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
					
					local rf = RecipientFilter()
					rf:AddPlayer(victim)
					rf:AddPlayer(wgfreddy)
					
					EmitSound("gfreddy.laugh", wgfreddy:GetPos(), nil, nil, nil, nil, nil, nil, nil, rf)
				end
				
				cooldown.Set(wgfreddy, 'submerge', 12)
				cooldown.Send(wgfreddy, 'submerge')
				
				ent:SetSpeed(unpack(sfreddy_noclip_movement))
				wgfreddy:DrawViewModel(false)

				ent:SetMaterial("models/null")
				ent:DrawShadow(false)

				wgfreddy:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				wgfreddy:CollisionRulesChanged()

				ent.cloaked = true
			end
			
			net.Start("fh_play_sound")
			net.WriteString("fnaf2/gfreddy/gfreddy_success_scare.wav")
			net.Send(wgfreddy)
			
			PauseDamage(ply, 10)
		end
	end)
end

concommand.Add( "dev_start_outworld", function( ply, cmd, args )
	if CLIENT or !ply:IsSuperAdmin() then return end

	local nick1 = tostring(args[1])
	local nick2 = tostring(args[2])
	
	local gf = nil
	local target = nil
	
	for _, ply in player.Iterator() do
		local nickname = ply:Nick():lower()
	
		if !IsValid(gf) and nickname:match( nick1:lower() ) then
			gf = ply
			
			if IsValid(target) then
				break
			else
				continue
			end
		end
		
		if !IsValid(target) and nickname:match( nick2:lower() ) then
			target = ply
			
			if IsValid(gf) then
				break
			else
				continue
			end
		end
	end
	
	if IsValid(ply) and !IsValid(target) then
		target = ply
	end
	
	if IsValid(gf) and IsValid(target) then
		local ent = pills.getMappedEnt(gf)
		
		if IsValid(ent) then
			start_outworld(gf, ent, target)
			return
		else
			print("dev_start_outworld - has failed! Check if first player is Golden Freddy.")
			return
		end
	end
	
	print("dev_start_outworld - has failed! Maybe the nicknames were wrong.")
end)