AddCSLuaFile()

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
	
	util.PrecacheModel("models/UFMP/FNAF3/Springtrap.mdl")
	util.PrecacheModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
end

local SPRINGTRAP_RAGE_HL_COLOR = Color(66,150,0)

local plushtrap_summon_cd = 120
	
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
	
	health=10000,

	modelScale="0.85",
	model="models/UFMP/FNAF3/Springtrap.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			
			jump="jump",
			glide="glide",
			land="land",
			
			summon="summon",
			
			crouch="crouchidle",
			crouch_walk="crouch",
			
			egypt="egypt",
		},
		gestures={
			swing="preattack",
			attack="attack",
			stun="stun",
		},
		speedCap={
			walk=210,
			run=500,
		},
	},
	moveSpeed={
		walk = spring_default_movement[1],
		run = spring_default_movement[2],
		ducked = spring_default_movement[3],
		
		maxwalk = 60,
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
    jumpPower=250,
	
	viewmodel={
		weapon="v_springtrap",
		skin=IsHalloween() and 2 or nil
	},

	noFallDamage=true,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = { xPose="aim_yaw", yPose="aim_pitch" },
	
	initialize=function(ply,ent)
		ent:PillLoopSound('breathing', 0.6)
		ent.Enragies = {}
		
		if IsValid(ent) then
			local timerName = "CheckConditions" .. ply:EntIndex()
			if timer.Exists( timerName ) then return end
	
			timer.Create( timerName , 1, 0, function()
				if !IsValid(ent) or !IsValid(ply) then
					timer.Remove( timerName )
					return
				end
				
				if !isGameOn or roundEnding then return end
				
				if ent:GetNWBool("SpringtrapEnraged") then return end
				
				if !ply:IsSprinting() or ply:GetVelocity():LengthSqr() < ply:GetRunSpeed() * 0.9 then
					return
				end
				
				ent:Func("enrageProgress", ply, ent)
			end)
		end
	end,
	
	enrageProgress=function(ply, ent)
		local eyePos = ply:EyePos()
		local forward = ply:EyeAngles():Forward()
		local fov = 50
		local maxDot = math.cos(math.rad(fov * 0.5))

		ply:LagCompensation(true)
		
		for target, _ in pairs( survivors ) do
			if target == ply then continue end
			if not target:IsPlayer() then continue end
			if not target:IsSurvivor() then continue end
			if not target:Alive() then continue end
			
			local targetPos = target:EyePos()

			local dir = (targetPos - eyePos):GetNormalized()

			if forward:Dot(dir) >= maxDot then
				local tr = util.TraceLine({
					start = eyePos,
					endpos = targetPos,
					mask = MASK_BLOCKLOS_AND_NPCS,
					filter = {ply, target},
				})

				if not tr.Hit then
					local agr = ent.Enragies[target] or 0
					ent.Enragies[target] = agr + 1 -- прибавка секунды агра
					
					local lastTarget = ent.LastEnragie
					if ent.Enragies[lastTarget] and IsValid(lastTarget) and lastTarget:Alive() and lastTarget:IsSurvivor() then
					
						local timerName = "SpringtrapLostEnragie" .. lastTarget:EntIndex()
						
						timer.Create(timerName, 5, 1, function()
							if not IsValid(ent) then return end
							if not IsValid(lastTarget) then return end
							
							ent.Enragies[lastTarget] = nil
						end)
						
					end
					
					if ent.Enragies[target] >= 20 then
						ent:Func("successRage", ply, ent, target)
					end
					
					ent.LastEnragie = target
					break
				end
			end
		end
		
		ply:LagCompensation(false)
	end,
	
	successRage=function(ply, ent, target)
		ent:SetNWBool("SpringtrapEnraged", true)
		spring_rage_target = target
		
		ent:SetSpeed(spring_rage_movement[1], 
		spring_rage_movement[2], 
		spring_rage_movement[3], 
		spring_rage_movement[4])
		
		highlight.Add( ply, {target}, 90, SPRINGTRAP_RAGE_HL_COLOR )
		
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
		
		timer.Create("fh_SpringtrapRage".. ply:EntIndex(), 90, 1, function()
			if !IsValid(ply) then return end
			if !IsValid(ent) then return end
			ent:Func("stopRage", ply, ent)
		end)
		
		hook.Run("FH_SpringtrapEnraged", ply, ent, target)
	end,
	
	stopRage=function(ply, ent)
		ent:SetSpeed(spring_default_movement[1], 
		spring_default_movement[2], 
		spring_default_movement[3], 
		spring_default_movement[4])
		
		ent:SetNWBool("SpringtrapEnraged", false)
		
		if IsValid(spring_rage_target) then
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(spring_rage_target)
			net.Send(ply)
			
			if spring_rage_target:IsSurvivor() then
				net.Start("fh_nodraw_hl_overlay")
				net.Send(spring_rage_target)
			end
		end
	end,
	
	restore=function(ply,ent)
		
	end,
	
	attack2={
		mode="trigger",
		func=function(ply,ent)
			if !isGameOn or roundEnding then return end
		
			if !ply:OnGround() or IsValid(pt_request_springtrap_ply) or IsValid(request_plushtrap) then return end
	
			if cooldown.Exists("summon") then return end
			
			local spectators = team.GetPlayers(TEAM_SPECTATOR)
			local noSpecs = table.Count(spectators) <= 0
			
			if not navmesh.IsLoaded() or navmesh.GetNavAreaCount() == 0 then -- На случай если нет навмеша
				if noSpecs then
					ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushspawn') )" )
					return
				end
				
				ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushunable') )" )
				
				cooldown.Set(ply, "summon", plushtrap_summon_cd)
				cooldown.Send(ply, "summon")
		
				net.Start("dead_pt_request_start")
				net.Send(spectators)
		
				pt_request_springtrap_ply = ply
				
				timer.Create("pt_kill_timer" .. ply:EntIndex(), 60, 1, function()
					if !IsValid(request_plushtrap) then
						pt_request_springtrap_ply = nil
						
						spectators = team.GetPlayers(TEAM_SPECTATOR)
						
						if not table.IsEmpty(spectators) then
							net.Start("client_requset_stop")
							net.Send(spectators)
						end
						
					end
				end)
				return
			end
			
			
			-- НАВМЕШ ЕСТЬ: Спавним ПЛЮШТРАПА, отправляем запрос СПЕКТАТОРАМ
			if not noSpecs then
				net.Start("dead_pt_request_start") net.Send(spectators)
			end
			
			ent:Func("spawnPlustrapBot", ply, ent)
		end
    },
	
	spawnPlustrapBot=function(ply, ent)
		pt_request_springtrap_ply = ply
	
		cooldown.Set(ply, "summon", plushtrap_summon_cd)
		cooldown.Send(ply, "summon")
		
		local plushtrap = ents.Create("plushtrap")
		if not IsValid(plushtrap) then return end
		
		plushtrap:SetPos(ply:GetPos())
		plushtrap:SetOwner(ply)
		plushtrap:Spawn()
		plushtrap:Activate()
		
		ent.BotPlushtrap = plushtrap
		
		net.Start("ApplyKillerCompanion")
		net.WriteString("plushtrap")
		net.WriteColor( Color(130, 119, 48) )
		net.WriteFloat( CurTime() + 60 )
		net.Send(ply)
		
		timer.Create("pt_kill_timer" .. ply:EntIndex(), 60, 1, function()
			if IsValid(plushtrap) then
				plushtrap:Remove()
			end
		
			ent:Func("killPlushtrap", request_plushtrap)
			
			spectators = team.GetPlayers(TEAM_SPECTATOR)
			
			if not table.IsEmpty(spectators) then
				net.Start("client_requset_stop")
				net.Send(spectators)
			end
			
			pt_request_springtrap_ply = nil
			if IsValid(ply) then
				ply:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushdead') )" )

				net.Start("RemoveKillerCompanion")
				net.Send(ply)
			end
		end)
		
		ent:PillAnim("summon", true)
		ply:GoPillThirdperson(1.7)
	end,
	
	killPlustrap = function(ply, ent, plushtrap)
		if IsValid(plushtrap) then
			inventory_backup.SuppressNextSave(plushtrap, true)
			plushtrap:Kill()
			plushtrap:SetTeam(TEAM_SPECTATOR)
			plushtrap:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushtime') )" )
			
			request_plushtrap = nil
		end
		
		net.Start("fh_plushalert_outrange")
		net.Broadcast()
	end,

	land=function(ply,ent)
		if ply.tasered then return end
		
		if IsGoodLandConditions(ply, ent) then
			ent:PillAnim("land",true)
		end
	end,

	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,

	taserStun=function(ply, ent, data)
		ent.anim = nil
		ent:SetFrozen(false)
		
		ent:PillGesture('stun', 3, 1, 0, 0.3)
		
		ply:SetWalkSpeed(60)
		ply:SetRunSpeed(60)
		ply:SetSlowWalkSpeed(60)
		timer.Create(data.timerName, 5, 1, function()
			if IsValid(ply) then
				if IsValid(ent) then
					local movespeed = ent:Get("moveSpeed")
					ply:SetRunSpeed(movespeed.run)
					ply:SetWalkSpeed(movespeed.walk)
					ply:SetSlowWalkSpeed(movespeed.walk)
				end
				ply.tasered = false
			end
		end)
		return true
	end,
})

plushtrap_visionrange = CreateConVar( "fh_plushtrap_highlight_range", "2200", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Distance, on which plushtrap will highlight everyone for himself." )

--PLUSHTRAP

local plushtrapRiders = {}

local pt_speed_normal = {450,200,210}
local pt_speed_slowed = {410,150,0}

local pt_j_mins = Vector(-2,-2,0)
local pt_j_maxs = Vector(3,3,2)

pills.register("pill_plushtrap",{
	printName="Plushtrap",
	health=2000,
	type="ply",
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
			jump="jump",
			glide="glide",
			stun="stun",
			
			kiss="kiss",
		},
		gestures={
			land="land",
			bite1="bite1",
			bite2="bite2",
		},
	},
	moveSpeed={
		walk=pt_speed_normal[1],
		ducked=pt_speed_normal[2],
	},
	sounds={
		jump="fnaf3/plushtrap/plu_jump.mp3",
		land="fnaf3/plushtrap/plu_land.mp3",
	},
    camera = {
        offset = Vector(0, 0, 38),
		dist = 60
    },
	hull=Vector(24,24,48),
	duckBy=16,
	stepSize=16,

    jumpPower=pt_speed_normal[3],

	noFallDamage=true,
	
	viewmodel = { weapon="v_plushtrap" },
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	initialize=function(ply, ent)
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		chaseVoicelineChecker(ply, ent, "plushtrap")
	end,
	
	restore=function(ply, ent)
		if CLIENT then return end
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
		
		plushtrapRiders[ply] = nil
	end,
	
	moveMod=function(ply,ent,mv,cmd)
		if SERVER then
			if ent.AttackJump then
				local mins = pt_j_mins
				local maxs = pt_j_maxs

				local startpos = ply:GetPos()
				local aimvec = ply:GetAimVector()
				
				local tr = util.TraceHull( {
					start = startpos,
					endpos = startpos + aimvec * 120, 
					maxs = maxs,
					mins = mins,
					filter = ply
				} )
				
				local target = tr.Entity
				
				if tr.Hit and IsValid(target) and target:IsPlayer() and target:IsSurvivor() and !PlayerInOutworld(target) then
					plushtrapRiders[ply] = target
				
					ply:EmitSound("fnaf3/plushtrap/plu_hitched.mp3")
					
					ply:SetLocalVelocity(Vector(0,0,0))
					ply:SetMoveType(MOVETYPE_NONE)
					
					ent:SetNWEntity("KissingTarget", target)
					ent:PillAnim("kiss")
					
					ply:GoPillThirdperson(3)
					
					local vpv = Angle(5,5,15)
					local vpv2 = Angle(5,5,8)
					
					target:ViewPunch(vpv2)
					ply:ViewPunch(vpv)
					
					ent.AttackJump = nil
				end
			elseif plushtrapRiders[ply] then
				local target = plushtrapRiders[ply]
				
				if IsValid(target) then
					mv:SetOrigin(target:GetPos())
					mv:SetVelocity(target:GetVelocity())
					--ply:SetEyeAngles(target:EyeAngles())
				end
				
			end
		end
	end,
	
	postThink=function(ply, ent, speed)
		local target = ent:GetNWEntity("KissingTarget")
		
		if CLIENT then
			if IsValid(target) then
				local angs = target:LocalEyeAngles()
				angs.p = 0
				
				local legBone = target:LookupBone("ValveBiped.Bip01_R_Thigh")
				local pos = target:GetPos() + Vector(10,0,30)
				if legBone then
					pos, angs = target:GetBonePosition(legBone)
				end
				
				ent:SetRenderAngles( angs )
				ent:SetRenderOrigin( pos )
			end
		end
	end,
	
	attack2_sh={
		mode="trigger",
		func=function(ply,ent)
			if not ply:OnGround() then return end
			if cooldown.Exists(ply, "hitch") then return end
		
			local eyeAng = ply:EyeAngles()
			eyeAng.p = math.max(-15, -math.abs(eyeAng.p) )
			
			local vel = ply:GetVelocity()
			
			local frwrd = eyeAng:Forward()
			
			local boost = (frwrd * 200)
			local up = Vector(0,0,260)
			
			ply:SetLocalVelocity(vel + boost + up)
			
			if SERVER then
				timer.Simple(0, function()
					if not IsValid(ent) then return end
					if not ent.AttackJump then return end
					if not IsValid(ply) then return end
					if ply:OnGround() then 
						ent:Func("land", ply, ent)
					end
				end)
				timer.Simple(1, function()
					if not IsValid(ent) then return end
					if not ent.AttackJump then return end
					if not IsValid(ply) then return end
					if ply:OnGround() then 
						cooldown.SetSend(ply, "hitch", 3)
						ent.AttackJump = nil
					end
				end)
			end
			
			ent.AttackJump = true
			
			if SERVER then
				ent:PillSound("jump")
				ent:PillAnim("jump", false)
			end
		end
	},
	
	land=function(ply,ent)
		if ent.AttackJump then
			cooldown.SetSend(ply, "hitch", 3)
		end
		ent.AttackJump = nil
		if IsGoodLandConditions(ply, ent) then
			ent:PillGesture('land', 1, 1, 0.1, 0.5, 0.1)
			
			local timerName = "pt_jump_timer" .. ply:EntIndex()
			
			ent:SetSpeed(pt_speed_slowed[1], pt_speed_slowed[1], pt_speed_slowed[2], pt_speed_slowed[3])
			
			if timer.Exists(timerName) then timer.Remove(timerName) end		
			
			timer.Create(timerName, 0.6, 1, function()
				if !IsValid(ent) then return end
				ent:SetSpeed(pt_speed_normal[1], pt_speed_normal[1], pt_speed_normal[2], pt_speed_normal[3])
			end)
		end
		
		landTripCheck(ply, ent, "plushtrap")
	end,
	
	jump=function(ply,ent)
		if ent.formTable.jumpPower <= 0 then return end
		ent:PillSound("jump",false)
	end,
	
	animEvent=function(ply,ent, name, t, c, type, options)
		if name == "PLUSHTRAP_KISS" then
			local target = ent:GetNWEntity("KissingTarget")
			
			if IsValid(target) then
				local damage = math.min(30, target:Health() - 1)
			
				if damage >= 1 then
					target:TakeDamage(damage, ply)
				end
				
				ply:EmitSound("fnaf3/plushtrap/plu_attack_hit.mp3")
				
				local edata = EffectData()
				edata:SetOrigin( target:NearestPoint( ply:EyePos() ) )
				edata:SetEntity( target )
				util.Effect("BloodImpact", edata, true, true)
				
				target.SpeedSlowEnd = CurTime() + 2.2
				
				net.Start("fh_oldshotgun_slowdown")
					net.WriteFloat(target.SpeedSlowEnd)
				net.Send(target)
				
				timer.Simple(.5, function()
					if not IsValid(ent) or not IsValid(ply) then return end
					
					ent.anim = nil
					ent:SetNWEntity("KissingTarget", NULL)
					ply:SetParent()
					ply:SetMoveType(MOVETYPE_WALK)
				
					ply.SpeedSlowEnd = CurTime() + 1.5
					
					net.Start("fh_oldshotgun_slowdown")
						net.WriteFloat(ply.SpeedSlowEnd)
					net.Send(ply)
					
					local dir = Vector(0,0,0)
					if IsValid(target) then
						dir = target:GetAimVector()
					end
				
					ply:SetLocalVelocity(-dir * 125 + Vector(0,0,300))
					
					plushtrapRiders[ply] = nil
				end)
			else
				ent.anim = nil
				ent:SetNWEntity("KissingTarget", NULL)
				ply:SetParent()
				ply:SetMoveType(MOVETYPE_WALK)
				
				plushtrapRiders[ply] = nil
			end
		end
	end,
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
			cooldown.Set(ply, "lifetime", timer.TimeLeft("pt_kill_timer" .. springtrap:EntIndex()))
			cooldown.Send(ply, "lifetime")
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
		cooldown.Set(ply, "summon", plushtrap_summon_cd)
		cooldown.Send(ply, "summon")
		
		timer.Adjust('fh_pt_summon', plushtrap_summon_cd, nil, nil)
			
		timer.Create("pt_waiting" .. springtrap:EntIndex(), 60, 1, function()
			kill_plushtrap(request_plushtrap)
			pt_request_springtrap_ply = nil
			springtrap:SendLua( "LocalPlayer():ChatPrint( language.GetPhrase('fazhunt.springtrap.plushdead') )" )
		end)
	end
	
	spectators = team.GetPlayers(TEAM_SPECTATOR)
	
	if !table.IsEmpty(spectators) then
		net.Start("client_requset_stop")
		net.Send(spectators)
	end
	
	pt_request_springtrap_ply = nil
end


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