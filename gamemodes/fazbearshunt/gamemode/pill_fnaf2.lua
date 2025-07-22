AddCSLuaFile()
include( "animatronics/wgfreddy.lua" )
include( "animatronics/foxy.lua" )

if SERVER then
	util.AddNetworkString("JumpscareLight")
	util.AddNetworkString("SetKillerAngle")
	
	util.AddNetworkString("fh_net_killer_change")
	
	util.AddNetworkString("fh_adv_sound_play")
	util.AddNetworkString("fh_ui_sound_play")
	util.AddNetworkString("fh_pos_sound_play")
	util.AddNetworkString("fh_ent_sound_play")
	util.AddNetworkString("fh_sound_stop")
	
	util.AddNetworkString("fh_addaffected_stalk")
	
	util.AddNetworkString("fh_play_voiceline")
	
	util.AddNetworkString("fh_draw_hl_overlay")
	util.AddNetworkString("fh_nodraw_hl_overlay")
	
	util.AddNetworkString("fh_start_yoursmine_view")
	util.AddNetworkString("fh_stop_yoursmine_view")
	
	util.AddNetworkString("fh_play_sound")
	
	util.AddNetworkString("fh_wgfreddy_target_outworld_start")
	util.AddNetworkString("fh_wgfreddy_target_outworld_end")
	
	util.AddNetworkString("fh_wgfreddy_selecting_halo")
	util.AddNetworkString("fh_wgfreddy_stop_selection_halo")
	util.AddNetworkString("fh_wgfreddy_outworld_start")
	util.AddNetworkString("fh_wgfreddy_outworld_stop")
	
	util.AddNetworkString("fh_net_wgfreddy_scarysound")
	
	util.AddNetworkString("cl_target_wgfreddy_scared")
	
	util.AddNetworkString("fh_dontdraw_player")
	util.AddNetworkString("fh_dontdraw_anim")
	
	util.AddNetworkString("fh_draw_player")
	util.AddNetworkString("fh_draw_anim")
	
	util.AddNetworkString("fh_stalker_freddy_halo_start")
	util.AddNetworkString("fh_stalker_freddy_halo_stop")
	
	util.PrecacheModel("models/speps/pill/oldfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldbonnie.mdl")
	util.PrecacheModel("models/speps/pill/oldchica.mdl")
	util.PrecacheModel("models/speps/pill/oldfoxy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddyhead.mdl")
	util.PrecacheModel("models/speps/pill/endo02.mdl")
end

pcall(require,"pills")

local cupcakes = {} 

shadow_freddyability = CreateConVar( "fuppr_sfreddy_noclip", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Noclip." )

pills.packStart("FUPPR 2 WE","FUPPR 2 WE","icon/fnafur2we.png")


local stalker
local stalkTarget

local wfreddy_default_movement = {150, 490, 65, 250} -- обычное передвижение
local wfreddy_stalk_movement = {150, 600, 70, 255} -- сталкер дохуя

pills.register("pill_wfreddy2",{
	printName="Withered Freddy",
	model="models/speps/pill/oldfreddy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special",
			scare="scare",
			jump="jump",
			glide="air",
			land="land",
			stalk="stalk",
			stun="stun",
			doorbreak="doorbreak",
		},
	},
	moveSpeed={
		walk=wfreddy_default_movement[1],
		run=wfreddy_default_movement[2],
		ducked=wfreddy_default_movement[3],
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.mp3",
		land="land.mp3",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_freddy",
		skin=0
	},
	
	animEvent=function(ply,ent,event)
		if util.GetAnimEventNameByID( event ) == "FREDDY_DOOR_BREAK" then
			ply:EmitSound("physics/metal/metal_sheet_impact_hard8.wav")
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
				
				chaseCheck(ply, 'freddy')
			end)
		end
	end,

	noFallDamage=true,
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			
			if stalkTarget and target ~= stalkTarget then return end
			
			playVoiceline('freddy', "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 50)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		end
    },
	
	attack2 = {
		mode = "trigger",
		func = function(ply, ent)
		
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			local target = fh_random_stalk_target(ply)
	
			if !IsValid(target) or !ply:OnGround() then return end
	
			if timer.Exists("fh_stalking" .. ply:EntIndex()) or ply == stalker then return end
			
			local fh_stalking_timer = 'fh_stalking' .. ply:EntIndex()
	
			timer.Create(fh_stalking_timer, 1, 0, function()
				if !IsValid(ent) or !IsValid(ply) then
					timer.Remove(fh_stalking_timer)
				end
			end)
	
			local lastPosition = target:GetPos()
			local movementTime = 0
	
			smoothLookAt(ply, target)
			ent:PillAnim("stalk", true)
			ply:SetFOV(60, 8)
	
			if math.random(1, 10) > 4 then playVoiceline('freddy', 'focus', ply, 0.1) end
	
			net.Start('fh_adv_sound_play')
			net.WriteString('freddy_stalking.wav')
			net.Send(ply)
	
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_VM_DEPLOY", 10)
			end
			
			net.Start('fh_ent_sound_play')
			net.WritePlayer(ply)
			net.WriteString('freddy_stalking_others.wav')
			net.SendOmit(ply)
	
			timer.Create("stalk_check" .. ent:EntIndex(), 1, 11, function()
	
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 8 then
					target:SetDSP(22)
				end
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 6 then
					target:SetDSP(25)
				end
	
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 1 then
					timer.Remove("SmoothLookAt_" .. ply:EntIndex())
					timer.Remove("stalk_check" .. ent:EntIndex())
					ply:SetFOV(0, 1)
					successStalk(ply, ent, target)
					return
				end
	
				local currentPosition = target:GetPos()
	
				if not target:Crouching() then
					local distance = currentPosition:Distance(lastPosition)
					if distance > 5 then
						movementTime = movementTime + 1
						if movementTime >= 5 then
							ent:PillAnim("idle")
							timer.Remove("SmoothLookAt_" .. ply:EntIndex())
							timer.Remove("stalk_check" .. ent:EntIndex())
							timer.Adjust('fh_stalking' .. ply:EntIndex(), 40, 1)
							ply:SetFOV(0, 1)
							net.Start('fh_sound_stop')
							net.WriteString('freddy_stalking.wav')
							net.Send(ply)
	
							net.Start('fh_sound_stop')
							net.WriteString('freddy_stalking_others.wav')
							net.Broadcast()
	
							ent:EmitSound('freddy_cancelled.wav')
		
							if math.random(1, 10) > 4 then playVoiceline('freddy', 'negative', ply, 0.1) end
	
							local wep = ply:GetActiveWeapon()
							if IsValid(wep) and wep:GetClass() == "v_freddy" then
								wep:PlayCustomAnimation("ACT_IDLE", 0)
							end
	
							if IsValid(target) then
								target:SetDSP(1)
								stats.Add(target, "evaded_blind_rage", 1)
							end
	
							net.Start("fh_net_killer_change")
							net.WriteString("stalk")
							net.WriteFloat(40)
							net.Send(ply)
							return
						end
					end
				end
	
				lastPosition = currentPosition
			end)
		end
	}, 

	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply ~= stalker then
			highlight.ByDistance(ply, ent)
		end
	end,
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -200 and ent.anim != 'stalk' then
			ent:PillAnim("land",true)
			return
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline('freddy', 'trip', ply, 0.1)
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
		ent:PillSound("jump",false)
	end,
	restore=function(ply,ent,formtable)
		timer.Remove("SmoothLookAt_"..ply:EntIndex())
		timer.Remove("stalk_check"..ent:EntIndex())
		stalker = nil
		stalkerEnt = nil
		
		timer.Remove("fh_stalking"..ply:EntIndex())
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
	end
})

-- сталк
function fh_random_stalk_target(ignore)
    local candidates = {}
    for _, ply in player.Iterator() do
        if IsValid(ply) and ply:Alive() and ply:Team() != TEAM_SPECTATOR and ply ~= ignore and ply:Team() != 2701 and !outworld_victims[ply] then
            local speed = ply:GetVelocity():Length()
            if speed < 70 then
                table.insert(candidates, ply)
            end
        end
    end

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    else
        return nil -- Нет подходящих игроков
    end
end


function smoothLookAt(anim, targetPlayer)
    if not IsValid(anim) or not IsValid(targetPlayer) then return end

    timer.Create("SmoothLookAt_" .. anim:EntIndex(), 0.01, 0, function()
        if not IsValid(anim) or not IsValid(targetPlayer) or !targetPlayer:Alive() then
            timer.Remove("SmoothLookAt_" .. anim:EntIndex())
            return
        end

        local currentAngle = anim:EyeAngles()

        local targetPos = targetPlayer:GetPos()
        local direction = (targetPos - anim:GetPos()):GetNormalized()

        local targetAngle = direction:Angle()

        local newAngle = LerpAngle(0.05, currentAngle, targetAngle)

        anim:SetEyeAngles(newAngle)
    end)
end

local stalkerEnt
function successStalk(ply, ent, target)
	if IsValid(target) and target:Alive() and ply:Team() != TEAM_SPECTATOR then
	
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_freddy" then
			wep.run_string = "ragerun"
			wep.run_act = ACT_RUN_AIM
		end
		
		ply:SendLua("wfreddy_stalker_door_halo_ON()")
			
		stalker = ply
		stalkerEnt = ent
		stalkTarget = target
		
		ent:SetSpeed(unpack(wfreddy_stalk_movement))
		ent:ReplaceAnimation("run", "srun")
		
		table.insert(affectedPlayers, target)
		
		net.Start('fh_addaffected_stalk')
		net.WriteEntity(target)
		net.Send(ply)
		
		target:SetDSP(1)
			
		for _, ply in ipairs(team.GetPlayers(TEAM_UNASSIGNED)) do
			if ply ~= target then
				net.Start("fh_play_sound")
				net.WriteString('freddy_rage_warning.wav')
				net.Send(ply)
			end
		end
		
		net.Start('fh_ent_sound_play')
		net.WritePlayer(ply)
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
			
		net.Start("fh_play_sound")
		net.WriteString('freddy_target_stalked.wav')
		net.Send(target)
			
		timer.Simple(2, function()
			if target:Alive() and target:Team() != TEAM_SPECTATOR then
				net.Start("fh_adv_sound_play")
				net.WriteString('freddy_targeted_ambience.wav')
				net.Send(target)
			end
		end)
			
		net.Start("fh_draw_hl_overlay")
		net.WriteBool(false)
		net.Send(target)
		
		net.Start('fh_net_display')
		net.WriteString('fazhunt.freddy.foundrun')
		net.WriteString('fazhunt.freddy.found')
		net.WriteFloat(-1)
		net.WriteFloat(6)
		net.Send(target)
	end
end

function noMoreStalk(ply)
	local ent = stalkerEnt
		
	ply:SendLua("wfreddy_stalker_door_halo_OFF()")
	
	ent:SetSpeed(unpack(wfreddy_default_movement))
	ent:ReplaceAnimation("run", "run")
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "v_freddy" then
		wep.run_string = "run"
		wep.run_act = ACT_VM_SPRINT_IDLE
	end
	
	stalker = nil
	stalkTarget = nil
	stalkerEnt = nil
	
	timer.Adjust('fh_stalking'..ply:EntIndex(), 80, 1)
			
	net.Start("fh_net_killer_change")
	net.WriteString("stalk")
	net.WriteFloat(80)
	net.Send(ply)
		
	net.Start('fh_sound_stop')
	net.WriteString('freddy_raged2_looped.wav')
	net.Broadcast()
end




--bonnie

pills.register("pill_wbonnie2",{
	printName="Withered Bonnie",
	model="models/speps/pill/oldbonnie.mdl",
	bodyGroups={math.random(1,1000) == 27 and 0 or 10},		-- рофлянка лицо бонни
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special",
			teleport="zombie_leap_mid",
			jump="jump",
			glide="jumpidle",
			land="jumpend",
			scare="scare",
			point="point",
			ability="yoursmine",
			stun="stun",
		},
	},
	moveSpeed={
		walk=90,
		run=485,
		ducked=80,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		jump="jump.mp3",
		land="land.mp3",
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_bonnie"
	},
	
	muteSteps = true,

    jumpPower=250,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
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
				
				chaseCheck(ply, 'bonnie')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			playVoiceline('bonnie', "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.5)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_bonnie" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
			
			timer.Simple(1.5, function()
				if !IsValid(target) then return end
			
				target:SetVelocity(ply:GetForward() * 600) -- чтоб он нахуй улетел
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if ply:IsFrozen() or timer.Exists('fh_yoursmine' .. ply:EntIndex()) or !ply:OnGround() then return end

			local target = fh_random_yoursmine_target(ply)
			
			ply.fh_target_player = target
			
			if not IsValid(target) then return end
			
			ent:PillAnim('ability', true)
			
			timer.Create('fh_yoursmine' .. ply:EntIndex(), 10, 1, function() end)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_bonnie" then
				wep:PlayCustomAnimation("ACT_VM_DEPLOY", 99999)
			end
			
			ent:EmitSound( "bonnie_ability_others.wav" )
			
			timer.Simple(1, function()
				net.Start("fh_start_yoursmine_view")
				net.WriteEntity(target)
				net.Send(ply)
				table.insert(affectedPlayers, target)
			end)
			
			net.Start("fh_play_sound")
			net.WriteString('bonnie_ability_bonnie.wav')
			net.Send(ply)
			
			net.Start("fh_play_sound")
			net.WriteString('bonnie_ability_target.wav')
			net.Send(target)
			
			timer.Simple(8, function()
				if IsValid(ply) then
					net.Start("fh_stop_yoursmine_view")
					net.Send(ply)
					ply:SetFOV(0, 0)
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_bonnie" then
						wep:PlayCustomAnimation("ACT_VM_DRAW", 0.5)
					end
			
					net.Start("fh_net_killer_change")
					net.WriteString("yoursmine")
					net.WriteFloat(55)
					net.Send(ply)
					if table.HasValue(affectedPlayers, target) then
						table.RemoveByValue(affectedPlayers, target)
					end
					
					timer.Adjust('fh_yoursmine'..ply:EntIndex(), 55, 1)
					ply.fh_target_player = nil
				end
			end)
			
			timer.Simple(6, function()
				if IsValid(ply) then
					ply:SetFOV(40, 2)
				end
			end)
			
			--[[
			if !ply:Crouching() then
				ent:PillGesture('point', 1, 1, 0.1, 0.1)
				
				local target = FindNearestPlayer(ent:GetPos(), 600, ply)
				if !IsValid(target) then return end
				
				playVoiceline('bonnie', 'spotted', ply, 1)
			end
			--]]
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			return
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline('bonnie', 'trip', ply, 0.1)
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end,

	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		highlight.ByDistance(ply, ent)
	end,

	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

function fh_random_yoursmine_target(ignore)
    local candidates = {}
    for _, ply in player.Iterator() do
        if IsValid(ply) and (ply:Alive() and ply:Team() != TEAM_SPECTATOR) and ply ~= ignore and ply:Team() != 2701 and !outworld_victims[ply] then
            table.insert(candidates, ply)
        end
    end

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    else
        return nil
    end
end





--chica





pills.register("pill_wchica2",{
	printName="Withered Chica",
	model="models/speps/pill/oldchica.mdl",
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special1",
			teleport="zombie_leap_mid",
			jump="jump",
			glide="air",
			land="land",
			scare="scare",
			stun="stun",
		},
	},
	moveSpeed={
		walk=80,
		run=485,
		ducked=80,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.mp3",
		land="land.mp3",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		deploy="chica_deploycake.wav",
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
    jumpPower=250,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
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
				
				chaseCheck(ply, 'chica')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			playVoiceline('chica', "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 60)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			if table.Count(cupcakes) < conVars.fh_max_cupcakes:GetInt() and not timer.Exists('C_deploycake'..ply:EntIndex()) then
				timer.Create("C_deploycake"..ply:EntIndex(), 15, 1, function() end)
				
				local playerPos = ply:GetPos()
				local spawnPos = playerPos + ply:GetUp() * 10
				local cupcake = ents.Create("cakemine")
				
				ent:PillSound('deploy')
				
				if not IsValid(cupcake) then return end

				if math.random(1, 10) > 4 then playVoiceline('chica', 'plant', ply, 0.1) end
				
				cupcake:SetPos(spawnPos)
				cupcake:SetOwner(ply)
				cupcake:Spawn()
				cupcake:Activate()
				
				table.insert(cupcakes, cupcake:EntIndex())
			
				net.Start("fh_net_killer_change")
				net.WriteString("mine")
				net.WriteFloat(15)
				net.Send(ply)
			
				net.Start("fh_net_killer_change")
				net.WriteString("addmine")
				net.WriteFloat(1)
				net.Send(ply)
			end
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			return
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline('chica', 'trip', ply, 0.1)
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end,
	
	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", false)
	end,
	restore=function(ply,ent)
		killCupcakes(ply)
	end
})










--foxy

local foxy_movement_speed = {150, 490, 70, 400}

function FoxyMovementSpeed()
	return foxy_movement_speed
end

local stunned_foxy_movement_speed = {80, 80, 70, 100}

function StunnedFoxyMovementSpeed()
	return stunned_foxy_movement_speed
end

pills.register("pill_wfoxy2",{
	printName="Withered Foxy",
	model="models/speps/pill/oldfoxy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			jump="jump",
			glide="air",
			run="run",
			cloak="taunt",
			teleport="zombie_leap_mid",
			land="land",
			scare="scare",
			stun="stun",
			chargestun="chargestun",
		},
	},
	moveSpeed={
		walk=150,
		run=490,
		ducked=70,
	},
	sounds={
		gs="fnaf2/xscream2.wav",
		jump="jump.mp3",
		regular_land="land.mp3",
		land_foxy="land_foxy.mp3",
		loop_stare="fnaf2/with_s2_loop2.wav",
		scream="fnaf2/foxyflashed.wav",
		taunt="foxy_laugh.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_foxy"
	},
	
    jumpPower=400,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
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
				
				chaseCheck(ply, 'foxy')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze or ply.blightRushing then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			playVoiceline('foxy', "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 75)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.5)
			end
			
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			foxyRush(ply, ent)
			--[[
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:PlayCustomAnimation("ACT_GMOD_TAUNT_LAUGH", 1.9)
			end
			]]--
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			ent:PillSound("land_foxy",false)
			return
		end
		if ply:WaterLevel() < 1 then
			ent:PillSound("regular_land",false)
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline('foxy', 'trip', ply, 0.1)
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end,

		
	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})










--shadow





--[[
	КД ШЕДОУ МИШКИ
	
	КД на убийство когда вышел из ноуклипа; 	когда вошёл в ноуклип;		когда вышел из него
	
]]
local sfreddy_cooldowns = {1.5, 7, 5}

-- ХОДЬБА, БЕГ, ВПРИСЯДИ, СИЛА ПРЫЖКА
local sfreddy_default_movement = {100, 100, 65, 250} -- обычное передвижение
local sfreddy_noclip_movement = {500, 600, 500, 250} -- это на случай если - fuppr_sfreddy_noclip 0

pills.register("pill_sfreddy2",{
	printName="Shadow Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",

	options=function() return {
		{skin=1}
	} end,
	bodyGroups={12},
	anims={

		default={
			idle="sidle",
			crouch="scrouch",
			crouch_walk="scrouchmove",
			walk="swalk",
			cloak="sdisappear",
			uncloak="sappear",
			jump="sjump",
			glide="sglide",
			scare="sscare",
			stun="sstun",
		},
	},
	moveSpeed={
		walk=sfreddy_default_movement[1],
		run=sfreddy_default_movement[2],
		ducked=sfreddy_default_movement[3],
	},
	sounds={
		jump="sfreddylunge.mp3",
		gs="fnaf2/shfreddy_laugh.wav",
		stare={"fnaf2/garble1.wav",
		"fnaf2/garble2.wav",
		"fnaf2/garble3.wav"},
	//	scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/sxscream.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_freddy",
		skin=2
	},
	
	cloak={
		max=-1
	},
    jumpPower=sfreddy_default_movement[4],
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	muteSteps = true,

	noFallDamage=true,
	hideHud = true,
	
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
				
				if ent.cloaked then return end
				chaseCheck(ply, 'sfreddy')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ent.cloaked or timer.Exists("SF_cantKill"..ply:EntIndex()) then return end
			if ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
				playVoiceline('sfreddy', "kill", ply, 1)
			end)
		end
    },
	 
	attack2={
		mode="trigger",
		func = function(ply,ent)
			
			if timer.Exists('SF_Cloacking'..ply:EntIndex()) or (timer.Exists('SF_Cooldown'..ply:EntIndex())) then return end

			if !ply:KeyDown(IN_USE) then
			
				if ent.cloaked then
			
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
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:PlayCustomAnimation("ACT_VM_DRAW", 0.5)
					end
					
					ply:DrawViewModel(true)
					
					ply:EmitSound("sfreddyout.mp3")
					
					ent.cloaked=false
	
					ent:ToggleCloak()
						
					timer.Remove("ext")
					timer.Create("SF_cantKill"..ply:EntIndex(), sfreddy_cooldowns[1], 1, function() end)
					
					timer.Create("SF_Cooldown"..ply:EntIndex(), sfreddy_cooldowns[3], 1, function() end)
					
					if SERVER then
			
						net.Start("fh_net_killer_change")
						net.WriteString("kill")
						net.WriteFloat(sfreddy_cooldowns[1])
						net.Send(ply)
				
						net.Start("fh_net_killer_change")
						net.WriteString("submerge")
						net.WriteFloat(sfreddy_cooldowns[3])
						net.Send(ply)
						
					end
							
					if shadow_freddyability:GetInt() == 1 then
						ply:SetMoveType( MOVETYPE_WALK )
					end
							
					ply:SetCustomCollisionCheck(true)
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					
					ent:SetSpeed( unpack(sfreddy_default_movement) )
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.2, 1, function()
						if !IsValid(ent) then return end
						
						timer.Simple(0,function()
							ent:PillAnim("uncloak")
							
							ent:SetMaterial()
							
							ent:DrawShadow(true)
						end)
						
					end)
				else
					if !ply:OnGround() and ply:WaterLevel() == 0 then return end
					if !IsValid(ent) then return end
					timer.Create("SF_Cooldown"..ply:EntIndex(), sfreddy_cooldowns[2], 1, function() end)
					
					ply:EmitSound("sfreddyin.mp3")
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:PlayCustomAnimation("ACT_VM_DEPLOY", 99999)
					end
			
					if SERVER then
					
						net.Start("fh_net_killer_change")
						net.WriteString("submerge")
						net.WriteFloat(sfreddy_cooldowns[2])
						net.Send(ply)
						
					end
					
					ent:PillAnim("cloak")
					
					timer.Create( "ext", 0.2, 0, function() 
						if !IsValid(ent) then return end
						if ply:Health() < 1000 then ply:SetHealth(ply:Health()+1) end
						if ent:IsOnFire() then ent:Extinguish() end
						if ply:IsOnFire() then ply:Extinguish() end
					end)
					
					ent.cloaked=true
					ent:ToggleCloak()
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.55, 1, function()
						ply:DrawViewModel(false)
						if !IsValid(ent) then return end
						
						if shadow_freddyability:GetInt() == 0 then
							ent:SetSpeed( unpack(sfreddy_noclip_movement) )
						end
						if shadow_freddyability:GetInt() == 1 then
							ply:SetMoveType( MOVETYPE_NOCLIP )
						end
						
						ent:SetMaterial("models/null")
						ent:DrawShadow(false)
						
						ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
						ply:SetCustomCollisionCheck(true)
					end)
						
				end
			
			end
			
		end
	},
 
	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		if timer.Exists('SF_Cloacking'..ply:EntIndex()) or ent.cloaked then return end
		ent:PillSound("jump",false)
	end
})








--endo

pills.register("pill_endo02",{
	printName="Endo02",
	model="models/speps/pill/endo02.mdl",
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="movecrouch",
			walk="walk",
			run="run",
			cloak="special",
			teleport="zombie_leap_mid",
			g_hold="scare",
			jump="jump",
			glide="air",
			land="land",
			scare="scare",
			stun="stun",
		},
	},
	moveSpeed={
		walk=120,
		run=475,
		ducked=200,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.mp3",
		land="land.mp3",
	//	scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_endo"
	},
	
    jumpPower=255,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	muteSteps = true,

	noFallDamage=true,
	hideHud = true,
	
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
				
				chaseCheck(ply, "endo")
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			playVoiceline("endo", "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_endo" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Create("FH_JumpscareKill_" .. ply:EntIndex(), 1.6, 1, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if timer.Exists("grabCooldown"..ply:EntIndex()) then return end
			takePlayer(ply,ent)
			
			//ent:PillGesture('hold')
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			return
		end
		
		if ply:WaterLevel() > 0 then return end
		if !fh_get_nearest_props(ply:GetPos(), 50) then return end
		
		if ent.landTimes != nil then
			ent.landTimes = 1 + ent.landTimes
			if ent.landTimes == 5 then
				playVoiceline("endo", 'trip', ply, 0.1)
			end
		else
			ent.landTimes = 1
		end
		timer.Simple(3,function()
			if ent.landTimes == 0 or !IsValid(ent) then return end
			ent.landTimes = ent.landTimes - 1
		end)
	end,

	
	noragdoll=true,

	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		highlight.ByDistance(ply, ent)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
	
})


local function fh_can_see_player(observer, target, radius)
    if not IsValid(observer) or not IsValid(target) then return false end

    if radius then
        local distance = observer:GetPos():Distance(target:GetPos())
        if distance > radius then
            return false
        end
    end

    local function can_see_pos(pos)
        local traceData = {
            start = observer:EyePos(),
            endpos = pos,
            filter = function(ent)
                return ent ~= observer
            end,
            mask = MASK_VISIBLE
        }

        local trace = util.TraceLine(traceData)
        if trace.Fraction == 1 or (IsValid(trace.Entity) and trace.Entity:GetPos():Distance(pos) < 5) then
            local dirToTarget = (pos - observer:GetPos()):GetNormalized()
            local viewDot = observer:GetAimVector():Dot(dirToTarget)
            return viewDot > 0.5
        end

        return false
    end

    if can_see_pos(target:EyePos()) then
        return true
    end

    local mapped = pills and pills.getMappedEnt and pills.getMappedEnt(target)
    if IsValid(mapped) and mapped:GetBoneCount() > 0 then
        for boneIndex = 0, mapped:GetBoneCount() - 1 do
            local bonePos = mapped:GetBonePosition(boneIndex)
            if bonePos and can_see_pos(bonePos) then
                return true
            end
        end
    end

    return false
end

wgfreddy_targets = {}
outworld_victims = {}
outworld_victims_count = {}

function getOutworldVictims()
	return outworld_victims
end

local gfreddy_movement = {130, 130, 0, 0}

--golden freddy

pills.register("pill_wgfreddy2",{
	printName="Withered Golden Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="sit",
			walk="walk",
			run="run",
			out="sdpecial",
			inn="tonormal",
			scare="sscare",
		},
	},

	moveSpeed={
		walk=130,
	--	run=500,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/wgfreddy_laugh.wav",
		scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
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
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
	startFunction=function(ply,ent)
		ply:DrawViewModel(false)
		ent:SetSpeed( unpack(sfreddy_noclip_movement) )
		ent:SetMaterial("models/null")
		ent:DrawShadow(false)
		
		ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
		ply:SetCustomCollisionCheck(true)
		ply:CollisionRulesChanged()
		
		ent.cloaked = true
		
		net.Start("fh_wgfreddy_selecting_halo")
		net.Send(ply)
	end,
	
	restore=function(ply,ent, formtable)
		cancel_outworld(ply)
		
		net.Start("fh_wgfreddy_stop_selection_halo")
		net.Send(ply)
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze then return end
			
			if !wgfreddy_targets[ply] then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) or target ~= wgfreddy_targets[ply] then return end
			
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(target:Health() + target:Armor(), ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.5, function()
				ply:Freeze( false )
				if !IsValid(target) then return end
				target:Freeze( false )
				target:TakeDamage(target:Health() + target:Armor(), ply)
			end)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end
			
			if !wgfreddy_targets[ply] then return end
			
			if !ent.cloaked then
				if !ply:OnGround() and ply:WaterLevel() == 0 then return end
				if !IsValid(ent) then return end
				
				if fh_can_see_player(wgfreddy_targets[ply], ply, 1500) then
					wgfreddy_targets[ply]:ScreenFade(SCREENFADE.IN, Color(0,0,0), 1, 0.5)
					
					EmitSound("gfreddy.laugh", ply:GetPos())
				end
				
				ent:SetSpeed( unpack(sfreddy_noclip_movement) )
				ply:DrawViewModel(false)
						
				ent:SetMaterial("models/null")
				ent:DrawShadow(false)
				
				ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
				ply:SetCustomCollisionCheck(true)
				ply:CollisionRulesChanged()
				
				ent.cloaked=true
				
			else
				if fh_can_see_player(wgfreddy_targets[ply], ply, 1600) then return end
			
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
					
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER_MOVEMENT)
				ply:SetCustomCollisionCheck(true)
				ply:CollisionRulesChanged()
							
				ent.cloaked=false
			end
			
		end
	},
	
	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		
		if wgfreddy_targets[ply] then return end

		local target = fh_get_wgfreddy_target(ply)
		
		if !IsValid(target) then return end
		
		start_outworld(ply, target)
	end,

	jump=function(ply,ent)
		--ent:PillSound("jump",false)
	end
})



-- GFREDDY HEAD

pills.register("pill_wgfreddyhead2",{
	printName="Withered Golden Freddy Head",
	model="models/speps/pill/oldgoldenfreddyhead.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			walk="walk",
			out="special",
			inn="tohead",
			run="run",
			teleport="zombie_leap_mid",
		},
	},
	modelScale="2.5",
	moveSpeed={
		walk=300,
		run=1000,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs={"fnaf2/wgfreddy_glitchsound.wav",
		"fnaf2/wgfreddy_glitchsound2.wav"},
		scream="fnaf2/bonniescream.wav",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(24,24,86),
	duckBy=60,
	
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
	canAim=function(ply,ent)
		return ent.active
	end,
	
	noFallDamage=true,	
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			target:TakeDamage(target:Health() + target:Armor(), ply)
			ent:PillSound("melee",false)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end
		end
	},

	
	noragdoll=true,
	reload=function(ply,ent)
	end,
	

	flashlight=function(ply,ent)
		if !ply:OnGround() then return end

		timer.Simple(.1,function()
			if !IsValid(ent) then return end
			local tracein={}
			tracein.maxs=Vector(16,16,72)
			tracein.mins=Vector(-16,-16,0)
			tracein.start=ply:EyePos()
			tracein.endpos=ply:EyePos()+ply:EyeAngles():Forward()*9999
			tracein.filter = {ply,ent}

			local traceout= util.TraceHull(tracein)
			ply:SetPos(traceout.HitPos)
			ent:PillSound("teleport")
		end)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("gs",false)
	end
})
	

function playVoiceline(character, line, who, when)
	if who:IsSpeaking() then return end

	if ( timer.Exists( "fh_PlayVoiceLine" .. who:SteamID64()) or timer.Exists( "fh_DontVoiceLine" .. who:SteamID64() ) ) then return end
	
	timer.Create("fh_PlayVoiceLine" .. who:SteamID64(), when, 1, function()
	
		if line == "kill" and character != "sfreddy" then
			if #team.GetPlayers(TEAM_UNASSIGNED) == 0 then
				line = "lastkill"
			end		
		end
		
		net.Start("fh_play_voiceline")
		net.WriteString(character)
		net.WriteString(line)
		net.WritePlayer(who)
		net.Broadcast()
		
		timer.Create("fh_DontVoiceLine" .. who:SteamID64(), 5, 1, function() end)
	end)
end

function FindNearestPlayer(origin, radius, ignorePlayer, fov)
    local nearestPlayer = nil
    local nearestDistance = radius

    local useFov = fov and fov > 0
    local candidates = {}

    if useFov and IsValid(ignorePlayer) then
        local dir = ignorePlayer:EyeAngles():Forward()
        candidates = ents.FindInCone(origin, dir, radius, math.cos(math.rad(fov)))
    else
        candidates = ents.FindInSphere(origin, radius)
    end

    for _, ply in ipairs(candidates) do
        if ply ~= ignorePlayer and ply:Health() > 0 and ((ply:IsPlayer() and (ply:Team() != TEAM_SPECTATOR and ply:Team() != 2701)) or ply:IsNPC()) then
            local distance = origin:Distance(ply:GetPos())
            local trace = util.TraceLine({
                start = ignorePlayer:EyePos(),
                endpos = ply:EyePos(),
                filter = function(ent)
                    return ent ~= ignorePlayer and ent ~= ply and not ent:IsPlayer() and not ent:IsNPC() and ent:GetClass() ~= "prop_physics"
                end
            })

            if distance <= nearestDistance and not trace.Hit then
                nearestDistance = distance
                nearestPlayer = ply
            end
        end
    end

    return nearestPlayer
end

function fh_get_nearest_players(origin, radius, ignorePlayer)
    local players = {}

    for _, ply in ipairs( ents.FindInSphere( origin, radius ) ) do
        if ply ~= ignorePlayer and ply:Health() > 0 and ((ply:IsPlayer() and (ply:Team() != TEAM_SPECTATOR and ply:Team() != 2701)) or ply:IsNPC()) then
			local trace = util.TraceLine({
				start = origin,
				endpos = ply:GetPos(),
				filter = function(ent)
				return ent != ignorePlayer and !ent:IsPlayer() and !ent:IsNPC() and ent:GetClass() != "fh_gift"
				end
			})
			if !trace.Hit then
				table.insert(players, ply)
			end
        end
    end

	if !table.IsEmpty(players) then
		return players
	end
	return nil
end

function fh_get_nearest_props(origin, radius)
    local props = {}

    for _, v in ipairs( ents.FindInSphere( origin, radius ) ) do
        if v:GetClass() == 'prop_physics' or v:GetClass() == 'prop_dynamic' or v:GetClass() == 'func_breakable_surf' or v:GetClass() == 'func_breakable' then
			table.insert(props, v)
        end
    end

	if table.Count(props) > 0 then
		return props
	end
	return nil
end

local playersHoldingRightClick = {}
local noClipBlockedPlayers = {}
resource.AddFile("sound/grab_player.wav")
resource.AddFile("sound/throw_player.wav")

function jumpscareEvent(ply, ent, target, dist)
	if CLIENT then return end
	if !IsValid(target) then return end
	
	hook.Run("FH_JumpscareEvent", ply, ent, target, dist)
	
	net.Start("JumpscareLight")
	net.Send(target)
	
	target.jumpscared = true
	ply.jumpscaring = target
	
	target:DropToFloor()
	ply:DropToFloor()
	
	target:Freeze( true )
	ply:Freeze( true )
	
	local target_phys = target:GetPhysicsObject()
	if IsValid(target_phys) then
		target_phys:SetVelocityInstantaneous(Vector(0, 0, 0))
	end
	target:SetVelocity(-target:GetVelocity())
	
	local ply_phys = ply:GetPhysicsObject()
	if IsValid(ply_phys) then
		ply_phys:SetVelocityInstantaneous(Vector(0, 0, 0))
	end
	ply:SetVelocity(-ply:GetVelocity())
	
	util.ScreenShake(target:GetPos(), 5, 5, 2, 500)
	
    local distance = dist or 50

    local attackerPos = ply:GetPos()
    local attackerForward = ply:GetForward()

    local targetPos = attackerPos + attackerForward * distance

    local tr = util.TraceHull({
        start = targetPos,
        endpos = targetPos,
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_PLAYERSOLID,
        filter = { ply, target }
    })

    if tr.Hit then
        local backDistance = distance
        local backPos = attackerPos - attackerForward * backDistance

        local backTr = util.TraceHull({
            start = backPos,
            endpos = backPos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_PLAYERSOLID,
            filter = { ply, target }
        })

        if not backTr.Hit then
            ply:SetPos(backPos)
            attackerPos = backPos
			
            targetPos = attackerPos + attackerForward * distance
        end
    end
	
	target:SetPos(targetPos)

    local direction = (ply:GetPos() - target:GetPos()):Angle()
    target:SetEyeAngles(direction)
	
    local direction = (target:GetPos() - ply:GetPos()):Angle()
	ply:SetEyeAngles(direction)
	
	net.Start("SetKillerAngle")
	net.WriteEntity(ent)
	net.Broadcast()
end

local takenPlayers = {}

function takePlayer(ply, ent)
	if ply:Team() == TEAM_SPECTATOR or ply:Health() == 0 then return end

    local nearestPlayer = FindNearestPlayer(ply:EyePos(), 125, ply, 90)
	
	if !takenPlayers[ply] then
		takenPlayers[ply] = {}
	end
	
	local remember_taken = takenPlayers[ply]

    if IsValid(nearestPlayer) and !nearestPlayer:IsFrozen() then
		if !table.HasValue(remember_taken, nearestPlayer) then
			table.insert(remember_taken, nearestPlayer)
			
			takenPlayers[ply] = remember_taken
			stats.Add(ply, "grabbed", 1)
		end
		
		ply:EmitSound("grab_player.wav")
		
		if ent.formTable.name == "pill_endo02" then
			if math.random(1,10) > 2 then
				playVoiceline("endo", 'grab', ply, 0.2)
			end
		end
		
        nearestPlayer:SetMoveType(MOVETYPE_NONE)
        nearestPlayer:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        noClipBlockedPlayers[nearestPlayer] = true

        playersHoldingRightClick[ply] = nearestPlayer

        timer.Create("UpdateCameraAndPosition" .. ply:UserID(), 0.01, 0, function()
			if !IsValid(ply) or !ply:KeyDown(IN_ATTACK2) then
				timer.Remove("UpdateCameraAndPosition" .. ply:UserID())
				return
			end
		
			if IsValid(nearestPlayer) then
				local eyePos = ply:EyePos()
				nearestPlayer:SetEyeAngles((eyePos - nearestPlayer:EyePos()):Angle())
				
				local vectorOffset = 50
				
				if ply:Crouching() then vectorOffset = 5 end
		
				local offset = (ply:EyeAngles():Forward() * 50)
				local newPos = ((ply:GetPos() + ply:EyePos()) / 2) + offset
		
				local traceData = {}
				traceData.start = ply:GetPos()
				traceData.endpos = newPos
				traceData.filter = {ply, nearestPlayer}
		
				local trace = util.TraceEntity(traceData, nearestPlayer)
		
				if trace.Hit then
					local safeDistance = trace.Fraction * 50
					offset = (Vector(0, 0, vectorOffset)) + (ply:EyeAngles():Forward() * safeDistance)
					newPos = ply:GetPos() + offset
				end
				debugoverlay.Line(traceData.start, traceData.endpos, 0.05, Color(255, 0, 0), true)
				--debugoverlay.Box( newPos, traceData.mins, traceData.maxs, 0.05, Color( 255, 255, 255, 20 ) )
		
				nearestPlayer:SetPos(newPos)
			end
		end)
    end
end

hook.Add("KeyRelease", "PlayerRightClickRelease", function(ply, key)
    if key == IN_ATTACK2 then
		endoRelease(ply)
    end
end)

function endoRelease(ply)
	local target = playersHoldingRightClick[ply]
	if IsValid(target) then
		ply:EmitSound("throw_player.wav")
		if math.random(1,10) > 2 then
			playVoiceline("endo", 'throw', ply, 0.1)
		end
	
		target:SetMoveType(MOVETYPE_WALK)
		target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		noClipBlockedPlayers[target] = nil
		
		target._GrabbedByEndoTime = CurTime()
		target._LastEndo = ply
	
		local direction = (ply:EyeAngles():Forward() * 50):GetNormalized()
		target:SetVelocity(direction * 600)
	
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		
		hook.Run("fh_endo_release", ply, target)
	
		timer.Create("grabCooldown" .. ply:EntIndex(), 1, 1, function() end)
	
		net.Start("fh_net_killer_change")
		net.WriteString("grab")
		net.WriteFloat(1)
		net.Send(ply)
	
		local function IsStuck(ent)
			if not IsValid(ent) then return false end
	
			local trace = util.TraceEntity({
				start = ent:GetPos(),
				endpos = ent:GetPos(),
				filter = ent,
				mask = MASK_SOLID
			}, ent)
	
			return trace.Hit
		end
	
		-- чтобы случайно не вернуть коллизию пока он в пропе или ещё гдета
		timer.Create("CheckCollisionReset" .. ply:EntIndex(), 0.5, 0, function()
			if IsValid(ply) and not IsStuck(ply) then
				ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
			if IsValid(target) and not IsStuck(target) and noClipBlockedPlayers[target] == nil then
				target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			end
	
			if (not IsValid(ply) or not IsStuck(ply)) and 
			(not IsValid(target) or not IsStuck(target)) then
				timer.Remove("CheckCollisionReset" .. ply:EntIndex())
			end
		end)
	end
	
	playersHoldingRightClick[ply] = nil
	timer.Remove("UpdateCameraAndPosition" .. ply:UserID())
end

hook.Add("PlayerUse", "AccurateBlockedDoorUse", function(ply, ent)
    if not IsValid(ent) then return end
	
	if ply._cantBreakDoors or ply:Crouching() or !ply:OnGround() then return end
	
	if ply ~= stalker then return end
	
	local puppet = pills.getMappedEnt(ply)
	if !IsValid(puppet) then return end
	
	if puppet.formTable.name ~= "pill_wfreddy2" then return end

    local class = ent:GetClass()
    local isDoor = class == "func_door" or class == "func_door_rotating" or class == "prop_door_rotating"
    if not isDoor then return end

    if ent:HasSpawnFlags(8192) then return end
	
    local state = ent:GetInternalVariable("m_toggle_state")
    if state ~= 1 then return end

    local tr = ply:GetEyeTrace()
    if tr.Entity ~= ent then return end
    local hitNormal = tr.HitNormal
	
	puppet:PillAnim("doorbreak", true)
	ply._cantBreakDoors = true

    timer.Simple(1, function()
        if IsValid(ent) then
            ent:Fire("Open", "", 0)
			
			local effectData = EffectData()
			effectData:SetOrigin(ent:GetPos())
			effectData:SetNormal(hitNormal)
			effectData:SetMagnitude(1)
			effectData:SetScale(1)
			effectData:SetRadius(3)
			util.Effect("ManhackSparks", effectData, true, true)
        end
    end)

    timer.Simple(9, function()
        if IsValid(ent) then
            ent:Fire("Close", "", 0)
			ply._cantBreakDoors = false
        end
    end)

    return false
end)

if CLIENT then
	local function halo_breakable_doors()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local ent = ply:GetUseEntity()
		if not IsValid(ent) then return end

		local class = ent:GetClass()
		local isDoor = class == "func_door" or class == "func_door_rotating" or class == "prop_door_rotating"
		if not isDoor then return end

		if ent:HasSpawnFlags(8192) then return end

		halo.Add({ent}, Color(255, 255, 255), 2, 2, 1, true, true)
	end
	
	function wfreddy_stalker_door_halo_ON()
		hook.Add("PreDrawHalos", "fh_highlight_breakdoor_stalker", halo_breakable_doors)
	end
	
	function wfreddy_stalker_door_halo_OFF()
		hook.Remove("PreDrawHalos", "fh_highlight_breakdoor_stalker")
	end
end

if SERVER then
	hook.Add("SetupPlayerVisibility", "fh_pill_fnaf2_visibility", function(ply, viewent)
		if !conVars.fh_less_steps:GetBool() then
			if table.Count(team.GetPlayers(2701)) > 0 then
				for _, player in ipairs(team.GetPlayers(2701)) do
					AddOriginToPVS(player:GetPos())
				end
			end
		end
		for k,v in pairs( outworld_victims ) do
			AddOriginToPVS(k:GetPos())
		end
	end)

	hook.Add( "PlayerDeath", "fh_pill_fnaf2_death_check", function( victim, inflictor, attacker )
		if victim.jumpscared then
			victim.jumpscared = nil
			if IsValid(attacker) and attacker:IsPlayer() then
				attacker.jumpscaring = nil
			end
		end
		if attacker == stalker then
			stats.Add(attacker, "killed_using_blind_rage", 1)
		end
		
		if victim == stalkTarget then
			net.Start('fh_sound_stop')
			net.WriteString('freddy_targeted_ambience.wav')
			net.Send(victim)
			if IsValid(stalker) then
				noMoreStalk(stalker)
			end
		end
		
		if wgfreddy_targets[victim] then
			cancel_outworld(victim)
		end
		if outworld_victims[victim] then
			cancel_outworld(victim)
		end
		
		if !table.IsEmpty(wgfreddy_targets) then
			for k,v in pairs( wgfreddy_targets ) do
				local ent = pills.getMappedEnt(k)
				
				if IsValid(ent) then
					net.Start("fh_draw_anim")
					net.WriteEntity(ent)
					net.Send(victim)
				end
				
				net.Start("fh_draw_player")
				net.WritePlayer(v)
				net.Send(victim)
			end
		end
	end)
	
	hook.Add("PlayerSpawn", "fh_pill_gfreddy_spawn_check", function(ply)
		if !table.IsEmpty(wgfreddy_targets) then
			for k,v in pairs( wgfreddy_targets ) do
				local ent = pills.getMappedEnt(k)
				
				if IsValid(ent) then
					net.Start("fh_dontdraw_anim")
					net.WriteEntity(ent)
					net.Send(ply)
				end
				
				net.Start("fh_dontdraw_player")
				net.WritePlayer(v)
				net.Send(ply)
			end
		end
	end)
	
	hook.Add( "PlayerDisconnected", "fh_pill_fnaf2_disconnect", function( ply )
		if ply == stalkTarget then
			if IsValid(stalker) then
				noMoreStalk(stalker)
			end
		end
		if wgfreddy_targets[ply] then
			cancel_outworld(ply)
		end
		if outworld_victims[ply] then
			cancel_outworld(ply)
		end
	end)
	
	function killCupcakes(ply)
		if table.Count(cupcakes) == 0 then return end
		for _, index in pairs(cupcakes) do
			if ents.GetByIndex(index):GetOwner() == ply then
				ents.GetByIndex(index):Remove()
				table.RemoveByValue(cupcakes, 1)
			end
		end
	end
	
	function killPlushies(ply)
		for _, ent in ipairs( ents.FindByClass("fh_plushie") ) do
			if ent.owner == ply then
				ent:Remove()
			end
		end
	end
	
	hook.Add("EntityRemoved", "RemoveKilledCupcake", function(ent)
		if table.HasValue(cupcakes, ent:EntIndex()) then
			table.RemoveByValue(cupcakes, ent:EntIndex())
		end
	end)
	
	hook.Add("OnPlayerPhysicsDrop", "fh_endo_prop_drop", function(ply, ent, thrown)
		local puppet = pills.getMappedEnt(ply)
		if !IsValid(puppet) then return end
		name = puppet.formTable.name
		
		local phys = ent:GetPhysicsObject()
		if IsValid(phys) and thrown and name == "pill_endo02" then
			local dir = ply:GetAimVector()
			phys:ApplyForceCenter(dir * 50000)
		end
	end)

else
	
	net.Receive("fh_play_voiceline", function()
		local character = net.ReadString()
		local line = net.ReadString()
		local who = net.ReadPlayer()
		
		local ent = pills.getMappedEnt(who)
		
		if IsValid(ent) and ent.dontdraw then return end
		
		if IsValid(who) then
			who:EmitSound( character .. "." .. line)
		end
	end)
end
	
hook.Add("PlayerNoClip", "BlockNoClipForHeldPlayer", function(ply, desiredState)
	if noClipBlockedPlayers[ply] then
		return false
	end
end)

function chaseCheck(ply, name)
	if (ply:IsSprinting() or ply:GetWalkSpeed() == ply:GetRunSpeed()) and ply:GetVelocity():LengthSqr() > ply:GetRunSpeed() * 0.9 then
		local target = FindNearestPlayer(ply:GetPos(), 750, ply, 90)
		
		if !IsValid(target) or outworld_victims[target] then return end
		if target:IsNPC() then return end
		
		if target:IsSprinting() and target:GetVelocity():LengthSqr() > target:GetWalkSpeed() then
	
			if timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
			playVoiceline(name, 'chase', ply, 1)
			
			timer.Create("ChaseCheck"..ply:EntIndex(), 15, 1, function() end) -- шобы войслайны не играли очень часто
			
		end
	end
end

hook.Add( "PostCleanupMap", "fh_pill_fnaf2_reset", function( name )
	stalker = nil
	stalkTarget = nil
	
	table.Empty(takenPlayers)
end)