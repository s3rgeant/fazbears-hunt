if SERVER then
	util.AddNetworkString("fh_addaffected_springtrap")
	
	-- спиртап
	util.AddNetworkString("pt_request")
	util.AddNetworkString("st_request_get")
	util.AddNetworkString("pt_request_complete")
	
	util.AddNetworkString("fh_sel_menu_close")
	
	util.AddNetworkString("dead_pt_request_start")
	util.AddNetworkString("client_requset_stop")
	
	util.AddNetworkString("fh_plushalert_inrange")
	util.AddNetworkString("fh_plushalert_outrange")
	
	util.PrecacheModel("models/tettris/FNaF/SD/springtrap_clown.mdl")
	util.PrecacheModel("models/UFMP/FNAF3/Springtrap.mdl")
	util.PrecacheModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
end

pills.packStart("FH FNAF3", "FH FNAF3", "icon16/pill.png")

hook.Add( "PostCleanupMap", "fh_pill_fnaf3_reset", function( name )
	
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

local function chaseVoicelineChecker(ply, ent, name)
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
		
		chaseCheck(ply, name)
	end)
end

-- CLOWN

pills.register("pill_clown",{
	printName="Clown",
	modelScale="1.2",
	model="models/tettris/FNaF/SD/springtrap_clown.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			jump="jump",
			glide="glide",
			dance="dance",
			crouch="crouch",
			crouch_walk="crouchmove",
			stun="stun",
		},
		gestures={
			hit="hit",
			land="land",
		},
	},
	moveSpeed={
		walk=110,
		run=420,
		ducked=70,
	},
    jumpPower=250,
	
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		loop_dance="kloun_ebanat.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_clown"
	},
	bloodType=BLOOD_COLOR_MECH,
	
	animEvent=function(ply,ent,event)
		if event == "CLOWN_HIDE_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(0,0,0) )
			end
		elseif event == "CLOWN_SHOW_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(1,1,1) )
			end
		end
	end,
	
	startFunction=function(ply,ent)
		--ply:SetJumpBoostMultiplier( math.min( getScaledJumpBoost() + 0.1, 1) )
		-- дабы он баннихопил быстрее игроков в любом случае
		
		chaseVoicelineChecker(ply, ent, "clown")
	end,
	
	restore=function(ply,ent)
		ply:SetJumpBoostMultiplier( getScaledJumpBoost() )
	end,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,

	taunt=function(ply,ent,act)
		if !ent.NextAct or ent.NextAct and CurTime() > ent.NextAct then
			if act == ACT_GMOD_TAUNT_DANCE and ent.anim ~= "dance" then
				if !ply:OnGround() then return end

				ent:PillLoopSound('dance', 0.6)
				ent:PillAnim("dance", true)
				ent.ignoreFreeze = true
				
				ent.NextAct = CurTime() + 4.5
				ply:GoPillThirdperson(4.5)
			end
		end
	end,
	
	animStopped=function(ply,ent, name)
		if name == 'dance' then
			ent:PillLoopStop('dance')
		end
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	land=function(ply,ent)
		ent.anim = nil
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
			ent:PillGesture('land', 1, 2, 0.15, 0.3, 0.06)
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

local spring_default_movement = {210, 500, 50, 250} -- обычное передвижение
local spring_rage_movement = {210, 600, 70, 255} -- дохуя скромник

pills.register("pill_springtrap",{
	printName="Springtrap",
	options=function() return {
		["default"] = {
			-- скин без ничего
		},
		["halloween"] = {
			skin=2,
			bodyGroups = { [24] = 1 },
		},
		["christmas"] = {
			bodyGroups = { [25] = 1 },
		},
	} end,
	option=IsHalloween() and "halloween" or IsChristmas() and "christmas" or "default",

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
			
			turnleft="turnleft",
			turnright="turnright",
			
			crouch="crouchidle",
			crouch_walk="crouch",
			
			egypt="egypt",
			stun="stun",
		},
		gestures={
			swing="preattack",
			attack="attack",
		},
		speedCap={
			run=500,
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
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 88),
		dist = 120
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_springtrap",
		skin=IsHalloween() and 2 or nil
	},

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	startFunction=function(ply,ent)
		ent:PillLoopSound('breathing', 0.6)
		
		if IsValid(ent) then
			local timerName = "CheckConditions" .. ply:EntIndex()
			if timer.Exists( timerName ) then return end
	
			timer.Create( timerName , 1, 0, function()
				if !IsValid(ent) or !IsValid(ply) then
					timer.Remove( timerName )
					spring_rage_total = 0
					return
				end
				
				if spring_enraged then return end
				
				if !isGameOn then return end
				
				if !ply:IsSprinting() or ply:GetVelocity():LengthSqr() < ply:GetRunSpeed() then
					return
				end
				
				local fov = ply:GetFOV()
				local eyePos = ply:EyePos()
				local eyeAngles = ply:EyeAngles()
				
				for _, target in ipairs( ents.FindInSphere( ply:GetPos(), 1800 ) ) do
					if target ~= ply and target:IsPlayer() and target:IsSurvivor() then
				
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
				
							print(ply:Nick() .. " is playing Springtrap. His rage progress: ( " ..spring_rage_total .. " / 45 )")
							
							if spring_rage_total >= 45 then
							
								local val = 0
								local loh
								
								for k,v in pairs(spring_rage) do
									if IsValid(k) and v > val and k:IsSurvivor() then
										val = v
										loh = k
									end
								end
								
								if IsValid(loh) then
									successRage(ply, ent, loh)
								else
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

	noFallDamage=true,
	
	restore=function(ply,ent)
		table.Empty(spring_rage)
		spring_rage_total = 0
		
		timer.Remove("pt_kill_timer" .. ply:EntIndex())
	end,
	
	attack2={
		mode="trigger",
		func=function(ply,ent)
			if !isGameOn then return end
		
			if !ply:OnGround() or IsValid(pt_request_springtrap_ply) or IsValid(request_plushtrap) then return end
	
			if timer.Exists("fh_pt_summon" .. ply:EntIndex()) or timer.Exists("pt_waiting" .. ply:EntIndex()) then return end
			
			local spectators = team.GetPlayers(TEAM_SPECTATOR)
			
			if navmesh.GetNavAreaCount() == 0 then
				if table.Count(spectators) > 0 then
					ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushunable') )" )
					
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
									net.Start("client_requset_stop")
									net.Send(v)
								end
							end
							
						end
					end)
				else
					ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushspawn') )" )
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
	
			cooldown.Set(ply, "summon", plushtrap_summon_cd)
			cooldown.Send(ply, "summon")
	
			timer.Create('fh_pt_summon' .. ply:EntIndex(), plushtrap_summon_cd, 1, function() 
			end)
			
			local plushtrap = ents.Create("plushtrap")
			if not IsValid(plushtrap) then return end
			
			plushtrap:SetPos(ply:GetPos())
			plushtrap:SetOwner(ply)
			plushtrap:Spawn()
			plushtrap:Activate()
	
			--[[
			net.Start("fh_net_killer_change")
			net.WriteString("plushtrap")
			net.WriteFloat(60)
			net.Send(ply)
			]]--
			
			net.Start("ApplyKillerCompanion")
			net.WriteString("plushtrap")
			net.WriteColor( Color(130, 119, 48) )
			net.WriteFloat( CurTime() + 60 )
			net.Send(ply)
			
			timer.Create("pt_kill_timer" .. ply:EntIndex(), 60, 1, function()
				if IsValid(plushtrap) then
					plushtrap:Remove()
				end
			
				net.Start("RemoveKillerCompanion")
				net.Send(ply)
			
				kill_plushtrap(request_plushtrap)
							
				spectators = team.GetPlayers(TEAM_SPECTATOR)
				
				if table.Count(spectators) > 0 then
					for _,v in ipairs( spectators ) do
						net.Start("client_requset_stop")
						net.Send(v)
					end
				end
							
				pt_request_springtrap_ply = nil
				if IsValid(ply) then
					ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushdead') )" )
				end
			end)
			
			ent:PillAnim("summon", true)
			ply:GoPillThirdperson(1.7)
		end
    },

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	land=function(ply,ent)
		if ply.tasered then return end
		
		if ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,
})

function kill_plushtrap(ply)
	if IsValid(ply) then
		ply:Kill()
		ply:SetTeam(TEAM_SPECTATOR)
		ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushtime') )" )
		
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
	
	highlight.Add( ply, {target}, 90, Color(66,150,0) )
	
	net.Start('fh_addaffected_springtrap')
	net.WriteEntity(target)
	net.Send(ply)
	
	net.Start("fh_draw_hl_overlay")
	net.WriteBool(false)
	net.Send(target)
	
	net.Start("fh_play_sound")
	net.WriteString("fnaf3/spr_enraged.wav")
	net.Send(ply)
	
	net.Start("fh_play_sound")
	net.WriteString("fnaf3/spr_rage_affected.wav")
	net.Send(target)
	
	net.Start("fh_draw_hl_overlay_timed")
	net.WriteBool(true)
	net.WriteFloat(90)
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
		
		if spring_rage_target:IsSurvivor() then
			net.Start("fh_nodraw_hl_overlay")
			net.Send(spring_rage_target)
		end
	end
end


plushtrap_visionrange = CreateConVar( "fh_plushtrap_highlight_range", "2200", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Distance, on which plushtrap will highlight everyone for himself." )

--PLUSHTRAP

local pt_speed_normal = {450,200,210}
local pt_speed_slowed = {410,150,0}

pills.register("pill_plushtrap",{
	printName="Plushtrap",
	modelScale="1.24",
	model="models/tetTris/FNaF/HW/Plushtrap.mdl",
	anims={
		default={
			idle="idle",
			walk="run",
			run="run",
			crouch="crouchidle",
			crouch_walk="crouch",
			summon="summon",
			land="land",
			jump="jump",
			glide="glide",
			stun="stun",
		},
		gestures={
			bite1="bite1",
			bite2="bite2",
		},
	},
	moveSpeed={
		walk=pt_speed_normal[1],
		ducked=pt_speed_normal[2],
	},
	stepSize=16,
	sounds={
		jump="fnaf3/plushtrap/plu_jump.mp3",
		land="fnaf3/plushtrap/plu_land.mp3",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 38),
		dist = 60
    },
	hull=Vector(24,24,48),
	duckBy=16,

    jumpPower=pt_speed_normal[3],
	
	viewmodel={
		weapon="v_plushtrap"
	},
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,
	health=2000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	startFunction=function(ply,ent)
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		--request_plushtrap = ply
		chaseVoicelineChecker(ply, ent, "plushtrap")
	end,
	
	restore=function(ply,ent, formtable)
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
	end,

	noFallDamage=true,
	
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
		
		landTripCheck(ply, ent, "plushtrap")
	end,
	jump=function(ply,ent)
		if ent.formTable.jumpPower <= 0 then return end
		ent:PillSound("jump",false)
	end
})

net.Receive("pt_request", function(len, ply)
	if !IsValid(pt_request_springtrap_ply) then
		if !IsValid(request_plushtrap) then
			ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plusherror') )" )
		else
			ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushchoosed') )" )
		end
		return
	end
	
	net.Start("st_request_get")
	net.WritePlayer(ply)
	net.Send(pt_request_springtrap_ply)
end)

concommand.Add( "dev_spawn_plushtrap", function( ply, cmd, args )
	if !ply:IsSuperAdmin() then return end
	
	local ent = pills.getMappedEnt(ply)
	
	if !IsValid(ent) then
		print("dev_spawn_plushtrap - has failed! You should be an animatronic.")
		return
	end

	local nick1 = tostring(args[1])
	
	local plushtrap = nil
	
	for _, player in player.Iterator() do
		local nickname = player:Nick():lower()
	
		if !IsValid(plushtrap) and nickname:match( nick1:lower() ) then
			plushtrap = player
			
			break
		end
	end
	
	if IsValid(plushtrap) then
		plushtrap_request_complete(ply, plushtrap)
		return
	end
	
	print("dev_spawn_plushtrap - has failed! Maybe the nickname was wrong.")
end )

function plushtrap_request_complete(springtrap, ply)
	if IsValid(request_plushtrap) or !IsValid(pt_request_springtrap_ply) then return end
	
	if ply:Alive() then return end -- на а хули?
	
	if timer.Exists("pt_waiting" .. springtrap:EntIndex()) then
		timer.Remove("pt_waiting" .. springtrap:EntIndex())
	end
	
	if !isGameOn then return end
	
	ply:Spawn()
	setupPlayerVars(ply)
	ply:SetTeam(TEAM_SURVIVOR)
	
	local pt_lastpos = nil
	local pt_lastangle = nil
	local pt_found = false
	
	if IsValid(pt_request_springtrap_ply) then
		pt_lastpos = pt_request_springtrap_ply:GetPos()
	end
	
	for k,v in ipairs(ents.FindByClass("plushtrap")) do
		pt_lastpos = v:GetPos()
		pt_lastangle = v:GetAngles()
		v:Remove()
		pt_found = true
		break
	end
	
	giveKillerSilent(ply, "pill_plushtrap", true)
	
	timer.Simple(1, function()
		if timer.Exists("pt_kill_timer" .. springtrap:EntIndex()) then
			net.Start("fh_net_killer_change")
			net.WriteString("lifetime")
			net.WriteFloat( timer.TimeLeft("pt_kill_timer" .. springtrap:EntIndex()) )
			net.Send(ply)
		end
	end)
	
	if pt_lastpos ~= nil then
		ply:SetPos(pt_lastpos)
	end
	if pt_lastangle ~= nil then
		ply:SetEyeAngles(pt_lastangle)
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
			springtrap:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushdead') )" )
		end)
	end
	
	spectators = team.GetPlayers(TEAM_SPECTATOR)
	
	if !table.IsEmpty(spectators) then
		for _,v in ipairs( spectators ) do
			net.Start("client_requset_stop")
			net.Send(v)
		end
	end
	
	pt_request_springtrap_ply = nil
	
end

net.Receive("pt_request_complete", function(len, springtrap)
	local ply = net.ReadPlayer()
	plushtrap_request_complete(springtrap, ply)
end)

if SERVER then
	hook.Add("SetupPlayerVisibility", "fh_pill_fnaf3_visibility", function(ply, viewent)
		if IsValid(request_plushtrap) then
			for _, ent in pairs(team.GetPlayers( TEAM_SURVIVOR )) do
				if ent:GetPos():Distance(request_plushtrap:GetPos()) <= plushtrap_visionrange:GetInt() then
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
	
	local nextPingTime = 0
	hook.Add("Think", "fh_plushalert_range_check", function()
		if !IsValid(request_plushtrap) then return end
		
		local curTime = CurTime()
	
		if not nextPingTime or curTime >= nextPingTime then
			for _, ply in player.Iterator() do
				if !IsValid(ply) or !ply:IsSurvivor() or ply == request_plushtrap then continue end
	
				nextPingTime = curTime + 3
	
				local distance = ply:GetPos():Distance(request_plushtrap:GetPos())
				if distance <= plushtrap_visionrange:GetInt() then
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