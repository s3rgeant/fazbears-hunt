AddCSLuaFile()

if SERVER then
	util.AddNetworkString("fh_addaffected_springtrap")
	
	-- спиртап
	util.AddNetworkString("pt_request")
	util.AddNetworkString("st_request_get")
	util.AddNetworkString("pt_request_complete")
	
	util.AddNetworkString("fh_sel_menu_close")
	
	util.AddNetworkString("dead_pt_request_start")
	util.AddNetworkString("dead_pt_request_stop")
	
	util.AddNetworkString("fh_plushalert_inrange")
	util.AddNetworkString("fh_plushalert_outrange")
	
	util.PrecacheModel("models/tettris/FNaF/SD/springtrap_clown.mdl")
	util.PrecacheModel("models/UFMP/FNAF3/Springtrap.mdl")
	util.PrecacheModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
end

pcall(require,"pk_pills")

pk_pills.packStart("FH FNAF3", "FH FNAF3", "icon16/pill.png")

hook.Add( "PostCleanupMap", "fh_pill_fnaf2_reset", function( name )
	
	if IsValid(pt_request_springtrap_ply) then
		net.Start("fh_sel_menu_close")
		net.Send(pt_request_springtrap_ply)
		
		pt_request_springtrap_ply = nil
	end
	
	--spring_rage_target = nil
	
	dead_pt_request_start = nil
	request_plushtrap = nil
	
	spring_enraged = false
end)

-- CLOWN

pk_pills.register("pill_clown",{
	printName="Clown",
	bodyGroups={0},
	modelScale="1.2",
	model="models/tettris/FNaF/SD/springtrap_clown.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			hit="hit",
			land="land",
			jump="jump",
			glide="glide",
			dance="dance",
			crouch="crouch",
			crouch_walk="crouchmove",
			stun="stun",
		},
	},
	moveSpeed={
		walk=110,
		run=420,
		ducked=70,
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		loop_dance="kloun_ebanat.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_clown"
	},
	
	animEvent=function(ply,ent,event)
		if util.GetAnimEventNameByID( event ) == "CLOWN_HIDE_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(0,0,0) )
			end
		elseif util.GetAnimEventNameByID( event ) == "CLOWN_SHOW_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(1,1,1) )
			end
		end
	end,

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	moveMod=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
			timer.Create("CheckConditions"..ply:EntIndex(), 2, 0, function()
				if !IsValid(ent) then
					if timer.Exists( "CheckConditions"..ply:EntIndex()) then
						timer.Remove("CheckConditions"..ply:EntIndex())
					end
					if timer.Exists( "ChaseCheck"..ply:EntIndex()) then
						timer.Remove("ChaseCheck"..ply:EntIndex())
					end
					return
				end
				
				chaseCheck(ply, 'clown')
			end)
		end
	end,

	noFallDamage=true,
	hideHud = true,
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if ply.tasered then return end
			if ent.anim != 'dance' then
				ent:PillLoopSound('dance', 0.6)
				ent:PillAnim("dance", true)
				ent.ignoreFreeze = true
			else
				ent.anim = nil
				ent:PillLoopStop('dance')
			end
		end
	},
	animStopped=function(ply,ent, name)
		if name == 'dance' then
			ent:PillLoopStop('dance')
		end
	end,

	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		HighlightPlayers(ply, ent)
	end,
	
	land=function(ply,ent)
		ent.anim = nil
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
			ent:PillGesture('land', 1, 2, 0.1, 0.3, 0.06)
			ent:PillLoopStop('dance')
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})





	-- SPRINGTRAP
	
	
local plushtrap_summon_cd = 120
	
local spring_rage = {}
local spring_rage_total = 0
local spring_enraged = false

local pt_request_springtrap_ply = nil
local request_plushtrap = nil

local spring_default_movement = {210, 500, 45, 250} -- обычное передвижение
local spring_rage_movement = {210, 600, 70, 255} -- дохуя скромник

pk_pills.register("pill_springtrap",{
	printName="Springtrap",
	bodyGroups={0},
	modelScale="0.85",
	model="models/UFMP/FNAF3/Springtrap.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			land="land",
			jump="jump",
			glide="glide",
			summon="summon",
			swing="preattack",
			attack="attack",
			turnleft="turnleft",
			turnright="turnright",
			crouch="crouchidle",
			crouch_walk="crouch",
			egypt="egypt",
			stun="stun",
		},
	},
	moveSpeed={
		walk=spring_default_movement[1],
		run=spring_default_movement[2],
		ducked=spring_default_movement[3],
	},
	sounds={
		jump="fnaf3/sprjump.mp3",
		land="fnaf3/sprland.mp3",
		loop_breathing="springtrap.breath",
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 88),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_springtrap"
	},

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	startFunction=function(ply,ent)
		ent:PillLoopSound('breathing', 0.6)
	end,

	noFallDamage=true,
	hideHud = true,
	
	--[[
	startFunction=function(ply,ent)
	end,
	--]]
	
	restore=function(ply,ent)
		table.Empty(spring_rage)
		spring_rage_total = 0
		
		timer.Remove("pt_kill_timer" .. ply:EntIndex())
	end,
	
	moveMod=function(ply,ent,mv)
		if IsValid(ent) then
			if CLIENT then return end
			
			local timerName = "CheckConditions" .. ply:EntIndex()
			if timer.Exists( timerName ) then return end
	
			timer.Create( timerName , 1, 0, function()
				if !IsValid(ent) or !IsValid(ply) then
					timer.Remove( timerName )
					return
				end
				
				if spring_enraged then return end
				
				if !timer.Exists( "EndGameTimer" ) then return end
				
				if !ply:IsSprinting() or ply:GetVelocity():LengthSqr() < ply:GetRunSpeed() then
					return
				end
				
				local fov = ply:GetFOV()
				local eyePos = ply:EyePos()
				local eyeAngles = ply:EyeAngles()
				
				for _, target in ipairs( ents.FindInSphere( ply:GetPos(), 1800 ) ) do
					if target ~= ply and target:IsPlayer() and target:Alive() and target:Team() != TEAM_SPECTATOR and target:Team() != 2701 then
				
						if target:Crouching() or target:GetVelocity():LengthSqr() < target:GetCrouchedWalkSpeed() then
							return
						end
						
						local targetPos = target:EyePos()
						local direction = (targetPos - eyePos):GetNormalized()
						local angleToTarget = direction:Angle()
						local angleDiff = math.abs(math.AngleDifference(eyeAngles.yaw, angleToTarget.yaw))
						
						if angleDiff < fov / 2 then
							local add = (request_plushtrap or timer.Exists("pt_kill_timer" .. ply:EntIndex())) and 0.5 or 1
							
							if spring_rage[target] == nil then
								spring_rage[target] = 1
							else
								spring_rage[target] = spring_rage[target] + add
							end
							
							spring_rage_total = spring_rage_total + add
							
							if spring_rage_total >= 60 then
							
								local val = 0
								local loh
								
								for k,v in pairs(spring_rage) do
									if IsValid(k) and v > val and k:Alive() and k:Team() != TEAM_SPECTATOR and k:Team() != 2701 then
										val = v
										loh = k
									end
								end
								
								if IsValid(loh) then
									successRage(ply, ent, target)
								end
							end
							break
						end
					end
				end
			end)
		end
	end,
	
	attack2={
		mode="trigger",
		func=function(ply,ent)
			if !timer.Exists( "EndGameTimer" ) then return end
			
			if ply.lobbyFreeze != nil and ply.lobbyFreeze or ply.tasered then return end
		
			if !ply:OnGround() or IsValid(pt_request_springtrap_ply) or IsValid(request_plushtrap) then return end
	
			if timer.Exists("fh_pt_summon" .. ply:EntIndex()) or timer.Exists("pt_waiting" .. ply:EntIndex()) then return end
			
			local spectators = team.GetPlayers(TEAM_SPECTATOR)
			
			if navmesh.GetNavAreaCount() == 0 then
				if table.Count(spectators) > 0 then
					ply:ChatPrint("Невозможно заспавнить плюштрапа, кидаем запрос наблюдателям.")
					
					net.Start("fh_net_killer_change")
					net.WriteString("summon")
					net.WriteFloat(plushtrap_summon_cd)
					net.Send(ply)
			
					for _,v in ipairs( spectators ) do
						net.Start("dead_pt_request_start")
						net.Send(v)
					end
			
					pt_request_springtrap_ply = ply
	
					timer.Create('fh_pt_summon' .. ply:EntIndex(), plushtrap_summon_cd, 1, function() 
					end)
					
					timer.Create("pt_kill_timer" .. ply:EntIndex(), 60, 1, function()
						if !IsValid(request_plushtrap) then
							pt_request_springtrap_ply = nil
							
							spectators = team.GetPlayers(TEAM_SPECTATOR)
							
							if table.Count(spectators) > 0 then
								for _,v in ipairs( spectators ) do
									net.Start("dead_pt_request_stop")
									net.Send(v)
								end
							end
							
						end
					end)
				else
					ply:ChatPrint("Невозможно заспавнить плюштрапа.")
				end
				return
			end
			
			if table.Count(spectators) > 0 then
				for _,v in ipairs( spectators ) do
					net.Start("dead_pt_request_start")
					net.Send(v)
				end
			end
			
			pt_request_springtrap_ply = ply
	
			net.Start("fh_net_killer_change")
			net.WriteString("summon")
			net.WriteFloat(plushtrap_summon_cd)
			net.Send(ply)
	
			timer.Create('fh_pt_summon' .. ply:EntIndex(), plushtrap_summon_cd, 1, function() 
			end)
			
			local plushtrap = ents.Create("plushtrap")
			if not IsValid(plushtrap) then return end
			
			plushtrap:SetPos(ply:GetPos())
			plushtrap:SetOwner(ply)
			plushtrap:Spawn()
			plushtrap:Activate()
			
			timer.Create("pt_kill_timer" .. ply:EntIndex(), 60, 1, function()
				if IsValid(plushtrap) then
					plushtrap:Remove()
				end
				kill_plushtrap(request_plushtrap)
							
				spectators = team.GetPlayers(TEAM_SPECTATOR)
				
				if table.Count(spectators) > 0 then
					for _,v in ipairs( spectators ) do
						net.Start("dead_pt_request_stop")
						net.Send(v)
					end
				end
							
				pt_request_springtrap_ply = nil
				if IsValid(ply) then
					ply:ChatPrint('Плюштрап сдох ебать')
				end
			end)
			
			ent:PillAnim("summon", true)
		end
    },

	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		HighlightPlayers(ply, ent)
	end,
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze or ply.tasered then return end
		
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			return
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,
	
	restore=function(ply,ent, formtable)
	
		local speed = formtable.moveSpeed or {}
		
		speed.walk = spring_default_movement[1]
		speed.run = spring_default_movement[2]
		speed.ducked = spring_default_movement[3]
		formtable.jumpPower = spring_default_movement[4]
	end
})

function kill_plushtrap(ply)
	if IsValid(ply) then
		ply:Kill()
		ply:SetTeam(TEAM_SPECTATOR)
		ply:ChatPrint('Ваше время за плюштрапа вышло.')
	
		if IsValid(ply.DeathRagdoll) then
			ply.DeathRagdoll:Remove()
		end
		
		request_plushtrap = nil
	end
	
	net.Start("fh_plushalert_outrange")
	net.Broadcast()
end

local spring_rage_target = nil
function successRage(ply, ent, target)
	spring_enraged = true
	spring_rage_target = target
	
	ent:SetSpeed(spring_rage_movement[1], 
	spring_rage_movement[2], 
	spring_rage_movement[3], 
	spring_rage_movement[4])
	
	ply:ChatPrint(target:Nick() .. " - стал твоим таргетом!")
	
	table.insert(affectedPlayers, target)
	
	net.Start('fh_addaffected_springtrap')
	net.WriteEntity(target)
	net.Send(ply)
	
	net.Start("fh_draw_hl_overlay")
	net.WriteBool(false)
	net.Send(target)
	
	net.Start("PlayHighlightSounds")
	net.WriteBool(true)
	net.WriteBool(true)
	net.Send(target)
	
	spring_rage_total = 0
	table.Empty(spring_rage)
	
	timer.Create("fh_springtrap_rage_timer".. ply:EntIndex(), 90, 1, function()
		spring_enraged = false
		if !IsValid(ply) then return end
		if !IsValid(ent) then return end
		noMoreRage(ply, ent)
	end)
end

function noMoreRage(ply, ent)
	ent:SetSpeed(spring_default_movement[1], 
	spring_default_movement[2], 
	spring_default_movement[3], 
	spring_default_movement[4])
	
	if IsValid(spring_rage_target) then
		net.Start("RemoveAffectedPlayer")
		net.WriteEntity(spring_rage_target)
		net.Send(ply)
		
		if spring_rage_target:Alive() and spring_rage_target:Team() != TEAM_SPECTATOR then
			net.Start("fh_nodraw_hl_overlay")
			net.Send(spring_rage_target)
		end
	end
end




--PLUSHTRAP

local pt_speed_normal = {450,200,190}
local pt_speed_slowed = {410,150,0}

pk_pills.register("pill_plushtrap",{
	printName="Plushtrap",
	bodyGroups={0},
	modelScale="1.24",
	model="models/tetTris/FNaF/HW/Plushtrap.mdl",
	anims={
		default={
			idle="idle",
			walk="run",
			run="run",
			crouch="crouchidle",
			crouch_walk="crouch",
			bite1="bite1",
			bite2="bite2",
			summon="summon",
			land="land",
			jump="jump",
			glide="glide",
			stun="stun",
		},
	},
	moveSpeed={
		walk=pt_speed_normal[1],
		ducked=pt_speed_normal[2],
	},
	stepSize=16,
	sounds={
		jump="fnaf3/sprjump.mp3",
		land="fnaf3/sprland.mp3",
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 38),
		dist = 60
    },
	hull=Vector(16,16,48),
	duckBy=16,

    jumpPower=pt_speed_normal[3],
	
	viewmodel={
		weapon="v_plushtrap"
	},
	
	muteSteps = true,
	health=2000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	moveMod=function(ply,ent,mv)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
			timer.Create("CheckConditions"..ply:EntIndex(), 2, 0, function()
				if !IsValid(ent) then
					if timer.Exists( "CheckConditions"..ply:EntIndex()) then
						timer.Remove("CheckConditions"..ply:EntIndex())
					end
					if timer.Exists( "ChaseCheck"..ply:EntIndex()) then
						timer.Remove("ChaseCheck"..ply:EntIndex())
					end
					return
				end
				
				chaseCheck(ply, 'plushtrap')
			end)
		end
	end,
	
	startFunction=function(ply,ent)
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		ply:SetCustomCollisionCheck(true)
		--request_plushtrap = ply
	end,
	
	restore=function(ply,ent, formtable)
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
		ply:SetCustomCollisionCheck(false)
	
		local speed = formtable.moveSpeed or {}
		
		speed.walk = pt_speed_normal[1]
		speed.run = pt_speed_normal[1]
		speed.ducked = pt_speed_normal[2]
		formtable.jumpPower = pt_speed_normal[3]
	end,

	noFallDamage=true,
	hideHud = true,

	noragdoll=true,
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
			ent:PillGesture('land', 1, 1, 0.1, 0.5, 0.1)
			
			ent:SetSpeed(pt_speed_slowed[1], pt_speed_slowed[1], pt_speed_slowed[2], pt_speed_slowed[3])
			
			if timer.Exists("pt_jump_timer" .. ply:EntIndex()) then timer.Remove("pt_jump_timer" .. ply:EntIndex()) end		
			
			timer.Create("pt_jump_timer" .. ply:EntIndex(), 0.6, 1, function()
				if !IsValid(ent) then return end
				ent:SetSpeed(pt_speed_normal[1], pt_speed_normal[1], pt_speed_normal[2], pt_speed_normal[3])
			end)
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline('plushtrap', 'trip', ply, 0.1)
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end,
	jump=function(ply,ent)
		if ent.formTable.jumpPower <= 0 then return end
		ent:PillSound("jump",false)
	end
})

net.Receive("pt_request", function(len, ply)
	if !IsValid(pt_request_springtrap_ply) then
		if !IsValid(request_plushtrap) then
			ply:ChatPrint("Произошла ошибка, ведь, походу, спрингтрапа не существует!")
		else
			ply:ChatPrint("Походу, Спрингтрап уже выбрал игрока!")	
		end
		return
	end
	
	net.Start("st_request_get")
	net.WritePlayer(ply)
	net.Send(pt_request_springtrap_ply)
end)

net.Receive("pt_request_complete", function(len, springtrap)
	local ply = net.ReadPlayer()
	
	if IsValid(request_plushtrap) then return end
	
	if timer.Exists("pt_waiting" .. springtrap:EntIndex()) then
		timer.Remove("pt_waiting" .. springtrap:EntIndex())
	end
	
	if !timer.Exists( "EndGameTimer" ) then return end
	
	ply:Spawn()
	setupPlayerVars(ply)
	ply:SetTeam(TEAM_UNASSIGNED)
	
	local pt_lastpos = nil
	local pt_found = false
	
	if IsValid(pt_request_springtrap_ply) then
		pt_lastpos = pt_request_springtrap_ply:GetPos()
	end
	
	for k,v in ipairs(ents.FindByClass("plushtrap")) do
		pt_lastpos = v:GetPos()
		v:Remove()
		pt_found = true
		break
	end
	
	RunConsoleCommand("pk_pill_apply", ply:Nick(), "pill_plushtrap")
	
	if pt_lastpos != nil then
		ply:SetPos(pt_lastpos)
	end
	
	request_plushtrap = ply
	
	if !pt_found then -- на случай, если навмешей нет, и пш не заспавнился, мы создаём таймеры, которые не создались.
		net.Start("fh_net_killer_change")
		net.WriteString("summon")
		net.WriteFloat(plushtrap_summon_cd)
		net.Send(springtrap)
		
		timer.Adjust('fh_pt_summon', plushtrap_summon_cd, nil, nil)
			
		timer.Create("pt_waiting" .. springtrap:EntIndex(), 60, 1, function()
			kill_plushtrap(request_plushtrap)
			pt_request_springtrap_ply = nil
			springtrap:ChatPrint('Плюштрап сдох ебать')
		end)
	end
							
	spectators = team.GetPlayers(TEAM_SPECTATOR)
	
	if table.Count(spectators) > 0 then
		for _,v in ipairs( spectators ) do
			net.Start("dead_pt_request_stop")
			net.Send(v)
		end
	end
	
	pt_request_springtrap_ply = nil
end)

if SERVER then
	local plushtrap_vision_range = 2200
	hook.Add("SetupPlayerVisibility", "fh_pill_fnaf3_visibility", function(ply, viewent)
		if !conVars.fh_less_steps:GetBool() then
			for _, ent in ipairs(ents.FindByClass("plushtrap")) do
				AddOriginToPVS(ent:GetPos())
			end
		end
		
		if IsValid(request_plushtrap) then
			for _, ent in pairs(team.GetPlayers( TEAM_UNASSIGNED )) do
				if ent:GetPos():Distance(request_plushtrap:GetPos()) <= plushtrap_vision_range then
					AddOriginToPVS(ent:GetPos())
				end
			end
		end
	end)
	
	hook.Add("PlayerSpawn", "fh_spawn_pill", function(ply)
		if ply == request_plushtrap then
			request_plushtrap = nil
		end
	end)
	
	hook.Add( "PlayerDisconnected", "fh_pill_fnaf3_disconnect", function( ply )
		if ply == request_plushtrap then
			request_plushtrap = nil
		end
	end)

	hook.Add( "PlayerDeath", "fh_pill_fnaf3_death_check", function( victim, inflictor, attacker )
		if IsValid(request_plushtrap) then
			net.Start("fh_plushalert_outrange")
			net.Send(victim)
		end
		if victim == request_plushtrap then
			request_plushtrap = nil
		end
	end)
	
	local nextPingTime = {}
	hook.Add("Think", "fh_plushalert_range_check", function()
		if !IsValid(request_plushtrap) then return end
	
		for _, ply in ipairs(player.GetAll()) do
			if !IsValid(ply) or !ply:IsPlayer() or ply:Team() == TEAM_SPECTATOR or ply:Team() == 2701 or ply == request_plushtrap then continue end
	
			local curTime = CurTime()
			if not nextPingTime[ply] or curTime >= nextPingTime[ply] then
				nextPingTime[ply] = curTime + 3
	
				local distance = ply:GetPos():Distance(request_plushtrap:GetPos())
				if distance <= plushtrap_vision_range then
					net.Start("fh_plushalert_inrange")
					net.Send(ply)
				else
					net.Start("fh_plushalert_outrange")
					net.Send(ply)
				end
			end
		end
	end)
end