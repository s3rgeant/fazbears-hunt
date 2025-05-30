AddCSLuaFile()

if SERVER then
	util.AddNetworkString("JumpscareLight")
	util.AddNetworkString("SetKillerAngle")
	
	util.AddNetworkString("fh_net_killer_change")
	
	util.AddNetworkString("fh_adv_sound_play")
	util.AddNetworkString("fh_ent_sound_play")
	util.AddNetworkString("fh_sound_stop")
	
	util.AddNetworkString("fh_addaffected_stalk")
	util.AddNetworkString("fh_addaffected_springtrap")
	
	util.AddNetworkString("fh_play_voiceline")
	
	util.AddNetworkString("fh_draw_hl_overlay")
	util.AddNetworkString("fh_nodraw_hl_overlay")
	
	util.AddNetworkString("fh_start_yoursmine_view")
	util.AddNetworkString("fh_stop_yoursmine_view")
	
	util.AddNetworkString("fh_play_sound")
	
	
	-- спиртап
	util.AddNetworkString("pt_request")
	util.AddNetworkString("st_request_get")
	util.AddNetworkString("pt_request_complete")
	
	util.AddNetworkString("fh_sel_menu_close")
	
	util.AddNetworkString("dead_pt_request_start")
	util.AddNetworkString("dead_pt_request_stop")
	
	util.AddNetworkString("fh_plushalert_inrange")
	util.AddNetworkString("fh_plushalert_outrange")
	
	util.AddNetworkString("PlayHighlightSounds")
	util.AddNetworkString("AddAffectedPlayers")
	util.AddNetworkString("RemoveAffectedPlayer")
	util.AddNetworkString("ToggleHighlightSound")
	util.AddNetworkString("NotifySpectators")
	
	util.PrecacheModel("models/speps/pill/oldfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldbonnie.mdl")
	util.PrecacheModel("models/speps/pill/oldchica.mdl")
	util.PrecacheModel("models/speps/pill/oldfoxy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddy.mdl")
	util.PrecacheModel("models/speps/pill/oldgoldenfreddyhead.mdl")
	util.PrecacheModel("models/speps/pill/endo02.mdl")
	util.PrecacheModel("models/tettris/FNaF/SD/springtrap_clown.mdl")
	util.PrecacheModel("models/UFMP/FNAF3/Springtrap.mdl")
	util.PrecacheModel("models/tetTris/FNaF/HW/Plushtrap.mdl")
end

pcall(require,"pk_pills")

local haloUsers = {}

local cupcakes = {} 

shadow_freddyability = CreateConVar( "fuppr_sfreddy_noclip", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Noclip." )

pk_pills.packStart("FUPPR 2 WE","FUPPR 2 WE","icon/fnafur2we.png")


local stalker
local stalkTarget

hook.Add( "PostCleanupMap", "fh_pill_reset", function( name )
	stalker = nil
	stalkTarget = nil
	
	table.Empty(haloUsers)
	
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

local wfreddy_default_movement = {150, 490, 65, 250} -- обычное передвижение
local wfreddy_stalk_movement = {150, 600, 70, 255} -- сталкер дохуя

pk_pills.register("pill_wfreddy2",{
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
		weapon="v_freddy",
		skin=0
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
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 50)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2 = {
		mode = "trigger",
		func = function(ply, ent)
		
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			local target = fh_random_stalk_target(ply)
	
			if not IsValid(target) or not ply:OnGround() then return end
	
			if timer.Exists("fh_stalking" .. ply:EntIndex()) or ply == stalker then return end
	
			timer.Create('fh_stalking' .. ply:EntIndex(), 1, 0, function() end)
	
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
	
			local recipients = {}
			for _, v in ipairs(player.GetAll()) do
				if v ~= ply then
					table.insert(recipients, v)
				end
			end
			
			net.Start('fh_ent_sound_play')
			net.WritePlayer(ply)
			net.WriteString('freddy_stalking_others.wav')
			net.Send(recipients)
	
			timer.Create("stalk_check" .. ent:EntIndex(), 1, 11, function()
	
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 8 then
					target:SetDSP(22)
				end
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 6 then
					target:SetDSP(25)
				end
	
				if timer.RepsLeft("stalk_check" .. ent:EntIndex()) == 1 then
					ent:PillAnim("idle")
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
							end
	
							net.Start("fh_net_killer_change")
							net.WriteString("Stalk")
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
			HighlightPlayers(ply, ent)
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
		
		formtable.anims.default.run = 'run'
		
		local speed = formtable.moveSpeed or {}
		
		speed.walk = wfreddy_default_movement[1]
		speed.run = wfreddy_default_movement[2]
		speed.ducked = wfreddy_default_movement[3]
		formtable.jumpPower = wfreddy_default_movement[4]
		
		timer.Remove("fh_stalking"..ply:EntIndex())
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
	end
})

-- сталк
function fh_random_stalk_target(ignore)
    local candidates = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply:Team() != TEAM_SPECTATOR and ply ~= ignore and ply:Team() != 2701 then
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
			
		stalker = ply
		stalkerEnt = ent
		stalkTarget = target
		
		ent:SetSpeed(wfreddy_stalk_movement[1], wfreddy_stalk_movement[2], wfreddy_stalk_movement[3], wfreddy_stalk_movement[4])
		ent.formTable.anims.default.run = 'srun'
		
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
		net.WriteString('БЕГИ')
		net.WriteString('Ты недостаточно двигался, и теперь фредди знает где ты.')
		net.WriteFloat(6)
		net.Send(target)
	end
end

function noMoreStalk(ply)
	local ent = stalkerEnt
	
	ent:SetSpeed(wfreddy_default_movement[1], wfreddy_default_movement[2], wfreddy_default_movement[3], wfreddy_default_movement[4])
	ent.formTable.anims.default.run = 'run'
	
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
	net.WriteString("Stalk")
	net.WriteFloat(80)
	net.Send(ply)
		
	net.Start('fh_sound_stop')
	net.WriteString('freddy_raged2_looped.wav')
	net.Broadcast()
end




--bonnie

pk_pills.register("pill_wbonnie2",{
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
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		jump="jump.mp3",
		land="land.mp3",
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
	
	moveFunction=function(ply,ent)
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
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.5)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_bonnie" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				
				target:UnLock()
				ply:UnLock()
				target:SetVelocity(ply:GetForward() * 600) -- чтоб он нахуй улетел
				target:TakeDamage(99999, ply)
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
					net.WriteString("Yoursmine")
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
		HighlightPlayers(ply, ent)
	end,

	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

function fh_random_yoursmine_target(ignore)
    local candidates = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and (ply:Alive() and ply:Team() != TEAM_SPECTATOR) and ply ~= ignore and ply:Team() != 2701 then
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





pk_pills.register("pill_wchica2",{
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
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		deploy="chica_deploycake.wav",
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
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
	
	moveFunction=function(ply,ent)
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
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 60)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
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
				net.WriteString("Mine")
				net.WriteFloat(15)
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
		HighlightPlayers(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", false)
	end,
	restore=function(ply,ent)
		killCupcakes(ply)
	end
})










--foxy








pk_pills.register("pill_wfoxy2",{
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
		},
	},
	moveSpeed={
		walk=150,
		run=527,
		ducked=70,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/xscream2.wav",
		jump="jump.mp3",
		land="land_foxy.mp3",
		loop_stare="fnaf2/with_s2_loop2.wav",
		scream="fnaf2/foxyflashed.wav",
		taunt="foxy_laugh.wav",
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
	
	moveFunction=function(ply,ent)
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
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			playVoiceline('foxy', "kill", ply, 2)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 75)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.5)
			end
			
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			ent:PillSound("taunt",false)
			ent:PillAnim("cloak", true)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:PlayCustomAnimation("ACT_GMOD_TAUNT_LAUGH", 1.9)
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
		HighlightPlayers(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})











--goldy












pk_pills.register("pill_wgfreddy2",{
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
			teleport="zombie_leap_mid",
			scare="sscare",
		},
	},

	moveSpeed={
		walk=130,
		run=500,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/wgfreddy_laugh.wav",
		scream="fnaf2/bonniescream.wav",
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
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply.lobbyFreeze then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then return end
			
			ent:PillSound("melee",false)
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end

//			ent:PillAnim("cloak",true)

			timer.Simple(0,function()
				if !IsValid(ent) then return end
				ent:ToggleCloak()
			end)
/*
			if ent.cloaked then
				ent.cloaked=nil

				timer.Simple(1,function()
					if !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial()
					ent:DrawShadow(true)
				end)
			else
				ent.cloaked=true

				timer.Simple(0.88,function()
					if !IsValid(ent) or !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial("Models/effects/vol_light001")
					ent:DrawShadow(false)
				end)
			end*/
		end
	},
	
	noragdoll=true,
	reload=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		HighlightPlayers(ply, ent)
	end,

	jump=function(ply,ent)
		//ent:PillSound("gs")
	end
})





































pk_pills.register("pill_wgfreddyhead2",{
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
			target:TakeDamage(99999, ply)
			ent:PillSound("melee",false)
			if target:IsNPC() then
				timer.Simple( 1.5, function()
					if !IsValid(ent) then return end
					target:EmitSound( "legitfreddy/static.wav" )
				end)
			return end
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				target:EmitSound( "legitfreddy/static.wav" )
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end

//			ent:PillAnim("cloak",true)

			timer.Simple(0,function()
				if !IsValid(ent) then return end
				ent:ToggleCloak()
			end)
/*
			if ent.cloaked then
				ent.cloaked=nil

				timer.Simple(1,function()
					if !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial()
					ent:DrawShadow(true)
				end)
			else
				ent.cloaked=true

				timer.Simple(1,function()
					if !IsValid(ent) or !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial("Models/effects/vol_light001")
					ent:DrawShadow(false)
				end)
			end*/
		end
	},

	
	noragdoll=true,
	reload=function(ply,ent)
		ent:PillAnim("out",true)
	
		--[[
		timer.Simple(0.6,function()
			if !IsValid(ent) then return end


			pk_pills.apply(ply,ent.formTable.crab)
			local e = pk_pills.apply(ply,ent.formTable.printName=="Withered Golden Freddy Head" and "pill_wgfreddy2")
			e:PillAnim("inn",true)
			if (attach) then
				ply:SetPos(attach.Pos)
			end
		end)
		]]--
	end,
	

	flashlight=function(ply,ent)
		if !ply:OnGround() then return end
		
	//	ent:PillAnim("teleport",true)

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














--shadow





--[[
	КД ШЕДОУ МИШКИ
	
	КД на убийство когда вышел из ноуклипа; 	когда вошёл в ноуклип;		когда вышел из него
	
]]
local sfreddy_cooldowns = {1.5, 7, 5}

-- ХОДЬБА, БЕГ, ВПРИСЯДИ, СИЛА ПРЫЖКА
local sfreddy_default_movement = {100, 100, 65, 250} -- обычное передвижение
local sfreddy_noclip_movement = {500, 600, 500, 200} -- это на случай если - fuppr_sfreddy_noclip 0

pk_pills.register("pill_sfreddy2",{
	printName="Shadow Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",

options=function() return {
{skin=1}
}end,
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
		melee=pk_pills.helpers.makeList("fnaf2/sxscream.wav",2),
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
	
	moveFunction=function(ply,ent)
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
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_freddy" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				playVoiceline('sfreddy', "kill", ply, 1)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
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
						net.WriteString('sfreddyerror.mp3')
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
						net.WriteString("Kill")
						net.WriteFloat(sfreddy_cooldowns[1])
						net.Send(ply)
				
						net.Start("fh_net_killer_change")
						net.WriteString("Submerge")
						net.WriteFloat(sfreddy_cooldowns[3])
						net.Send(ply)
						
					end
							
					if shadow_freddyability:GetInt() == 1 then
						ply:SetMoveType( MOVETYPE_WALK )
					end
							
					ply:SetCustomCollisionCheck(true)
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					
					ent:SetSpeed(sfreddy_default_movement[1], sfreddy_default_movement[2], sfreddy_default_movement[3], sfreddy_default_movement[4])
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.2, 1, function()
						if !IsValid(ent) then return end
						
						timer.Simple(0,function()
							ent:PillAnim("uncloak")
							
							ent:SetMaterial()
							
							//ply:SetNoDraw( false )
							//ent:SetNoDraw( false )
							
							//ent:SetModel("models/speps/pill/oldgoldenfreddy.mdl")
							ent:DrawShadow(true)
						end)
						
					end)
				else
					if !ply:OnGround() and ply:WaterLevel() == 0 then return end
					if !IsValid(ent) or !IsValid(ent) then return end
					timer.Create("SF_Cooldown"..ply:EntIndex(), sfreddy_cooldowns[2], 1, function() end)
					
					ply:EmitSound("sfreddyin.mp3")
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:PlayCustomAnimation("ACT_VM_DEPLOY", 99999)
					end
			
					if SERVER then
					
						net.Start("fh_net_killer_change")
						net.WriteString("Submerge")
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
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.6, 1, function()
						ply:DrawViewModel(false)
						if !IsValid(ent) then return end
						
						if shadow_freddyability:GetInt() == 0 then
							ent:SetSpeed(sfreddy_noclip_movement[1], sfreddy_noclip_movement[2], sfreddy_noclip_movement[3], sfreddy_noclip_movement[4])
						end
						if shadow_freddyability:GetInt() == 1 then
							ply:SetMoveType( MOVETYPE_NOCLIP )
						end
						
						ent:SetMaterial("models/null")
						//ent:SetModel("models/Items/AR2_Grenade.mdl")
						ent:DrawShadow(false)
						//ply:SetNoDraw( true )
						//ent:SetNoDraw( true )
						
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
		HighlightPlayers(ply, ent)
	end,
	
	jump=function(ply,ent)
		if timer.Exists('SF_Cloacking'..ply:EntIndex()) or ent.cloaked then return end
		ent:PillSound("jump",false)
	end
})








--endo








pk_pills.register("pill_endo02",{
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
	
	moveFunction=function(ply,ent)
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
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_endo" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.6)
			end
		
			timer.Simple( 1.6, function()
				
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
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
		HighlightPlayers(ply, ent)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
	
})
	
	
	
	
	
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
	
	moveFunction=function(ply,ent)
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
	
	--[[
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() or timer.Exists('Cl_cantKill'..ply:EntIndex()) then return end
			ent:PillGesture('hit', 2, 1, 0.1, 0.3)
			
			timer.Create('Cl_cantKill'..ply:EntIndex(), 2, 1, function() end)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(2)
			net.Send(ply)
			ply:EmitSound("hammer_ready.wav")
			
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_clown" then
				wep:PlayCustomAnimation("ACT_MELEE_ATTACK1", 1.1)
			end
			
			timer.Simple( 0.85, function()
				ply.clownAttacking = true
				if !IsValid(ent) then return end
			
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep:GetClass() == "v_clown" then
					wep:PrimaryAttack()
				end
				ply.clownAttacking = nil
			end)
		end
    },
	]]--
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
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
	
	moveFunction=function(ply,ent,mv)
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
			
			if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		
			if !ply:OnGround() or IsValid(pt_request_springtrap_ply) or IsValid(request_plushtrap) then return end
	
			if timer.Exists("fh_pt_summon" .. ply:EntIndex()) or timer.Exists("pt_waiting" .. ply:EntIndex()) then return end
			
			local spectators = team.GetPlayers(TEAM_SPECTATOR)
			
			if navmesh.GetNavAreaCount() == 0 then
				if table.Count(spectators) > 0 then
					ply:ChatPrint("Невозможно заспавнить плюштрапа, кидаем запрос наблюдателям.")
					
					net.Start("fh_net_killer_change")
					net.WriteString("Summon")
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
			net.WriteString("Summon")
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
				ply:ChatPrint('Плюштрап сдох ебать')
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
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
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
		net.WriteString("Summon")
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


local pt_speed_normal = {450,200,190}
local pt_speed_slowed = {410,150,0}

--PLUSHTRAP
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
	startFunction=function(ply,ent)
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		--request_plushtrap = ply
	end,
	
	restore=function(ply,ent, formtable)
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
	
		local speed = formtable.moveSpeed or {}
		
		speed.walk = pt_speed_normal[1]
		speed.run = pt_speed_normal[1]
		speed.ducked = pt_speed_normal[2]
		formtable.jumpPower = pt_speed_normal[3]
	end,

	noFallDamage=true,
	hideHud = true,
	
	--[[
	attack={
		mode="trigger",
		func=function(ply,ent)
		
		end
    },
	]]--

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
	end,
	jump=function(ply,ent)
		if ent.formTable.jumpPower <= 0 then return end
		ent:PillSound("jump",false)
	end
})

function playVoiceline(character, line, who, when)
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

	if table.Count(players) > 0 then
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
	
	net.Start("JumpscareLight")
	net.Send(target)
	
	target.jumpscared = true
	
	target:Lock()
	ply:Lock()
	
	target:SetVelocity(Vector(0, 0, 0))
	ply:SetVelocity(Vector(0, 0, 0))
	
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

function takePlayer(ply, ent)
	if ply:Team() == TEAM_SPECTATOR or ply:Health() == 0 then return end

    local nearestPlayer = FindNearestPlayer(ply:EyePos(), 125, ply)

    if nearestPlayer and nearestPlayer:IsPlayer() and !nearestPlayer:IsFrozen() then
		ply:EmitSound("grab_player.wav")
        nearestPlayer:SetMoveType(MOVETYPE_NONE)
        nearestPlayer:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        noClipBlockedPlayers[nearestPlayer] = true

        playersHoldingRightClick[ply] = nearestPlayer

        timer.Create("UpdateCameraAndPosition" .. ply:UserID(), 0.01, 0, function()
			if not IsValid(ply) or not ply:KeyDown(IN_ATTACK2) then
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
		
				local trace = util.TraceEntity(traceData, ent)
		
				if trace.Hit then
					-- Если игрок оказался внутри препятствия, уменьшаем расстояние
					local safeDistance = trace.Fraction * 50  -- Безопасная дистанция, где нет коллизии
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
        local target = playersHoldingRightClick[ply]
        if IsValid(target) then
            ply:EmitSound("throw_player.wav")
            playVoiceline("endo", 'throw', ply, 0.1)

            target:SetMoveType(MOVETYPE_WALK)
            target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            noClipBlockedPlayers[target] = nil

            local direction = (ply:EyeAngles():Forward() * 50):GetNormalized()
            target:SetVelocity(direction * 600)

            ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
            target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
			
			hook.Run("fh_endo_release", ply, target)

            timer.Create("grabCooldown" .. ply:EntIndex(), 1, 1, function() end)

            net.Start("fh_net_killer_change")
            net.WriteString("Grab")
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
end)


affectedPlayers = {}

if SERVER then

	function HighlightPlayers(ply, ent)
		local totalPlayers = {}
		if !table.HasValue(haloUsers, ply) then -- чел не под кулдауном? разрешай
			table.insert(haloUsers, ply)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Highlight")
			net.WriteFloat(conVars.halo_cooldown:GetFloat())
			net.Send(ply)
			
			timer.Simple(conVars.halo_cooldown:GetFloat(), function()
				table.RemoveByValue(haloUsers, ply)
			end)
		
			local affectedNicknames = {}
			for _, player in ipairs(player:GetAll()) do
				if player ~= ply and player:IsPlayer() and player:Health() > 0 and (player:Team() != TEAM_SPECTATOR and player:Team() != 2701) and player:IsValid() then
					local distance = ply:GetPos():Distance(player:GetPos())
					
					net.Start("PlayHighlightSounds") -- всем остальным кидаем звук прикольный
					net.WriteBool(distance <= conVars.halo_radius:GetInt())
					net.WriteBool(ent.formTable.name == "pill_springtrap")
					net.Send(player)
					
					if (distance <= conVars.halo_radius:GetInt()) then -- передаём чуваку кто подсвечивается в радиусе
						table.insert(affectedPlayers, player)
						table.insert(totalPlayers, player)
						table.insert(affectedNicknames, player:Nick())
						timer.Simple(conVars.halo_time:GetFloat(), function()
							table.RemoveByValue(affectedPlayers, player)
						end)
					end
				end
			end
		
			//ply:ChatPrint(table.concat(affectedNicknames, ', '))
					
			if table.Count(totalPlayers) > 0 then
				net.Start("AddAffectedPlayers")
				net.WriteTable(totalPlayers)
				net.Send(ply)
				if table.Count(team.GetPlayers(TEAM_SPECTATOR)) > 0 then
					net.Start('NotifySpectators')
					net.WriteTable(affectedNicknames)
					net.WriteEntity(ply)
					net.Broadcast()
				end
			end
						
			net.Start("ToggleHighlightSound") -- включаем чуваку звук что он дофига крутой со спермой под губой
			net.WriteBool(table.Count(totalPlayers) > 0)
			net.Send(ply)
		end
	end
	
	net.Receive("AddServerAffectedPlayers", function(len, ply)
		local players = net.ReadTable()
		for _, player in ipairs(players) do
			table.insert(affectedNicknames, player)
		end
	end)

	local plushtrap_vision_range = 2200
	hook.Add("SetupPlayerVisibility", "SetupVisibilityForAffectedPlayers", function(ply, viewent)
		if table.Count(affectedPlayers) > 0 then
			for _, player in ipairs(affectedPlayers) do
				if IsValid(player) then
					AddOriginToPVS(player:GetPos())
				end
			end
		end
		if !conVars.fh_less_steps:GetBool() then
			if table.Count(team.GetPlayers(2701)) > 0 then
				for _, player in ipairs(team.GetPlayers(2701)) do
					AddOriginToPVS(player:GetPos())
				end
			end
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

	hook.Add("PlayerSpawn", "fh_spawn_pill", function(ply)
		if ply == request_plushtrap then
			request_plushtrap = nil
		end
	end)

	hook.Add( "PlayerDeath", "fh_pill_death_check", function( victim, inflictor, attacker )
		if victim.jumpscared then
			victim.jumpscared = nil
		end
		if victim == stalkTarget then
			net.Start('fh_sound_stop')
			net.WriteString('freddy_targeted_ambience.wav')
			net.Send(victim)
			if IsValid(attacker) and attacker:IsPlayer() then
				if IsValid(stalker) then
					noMoreStalk(stalker)
				end
			end
		end
		if victim == request_plushtrap then
			request_plushtrap = nil
		end
		if table.HasValue(affectedPlayers, victim) then
			table.RemoveByValue(affectedPlayers, victim)
			
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(victim)
			net.Broadcast()
			
			net.Start('fh_nodraw_hl_overlay')
			net.Send(victim)
		end
	end)
	

	hook.Add( "PlayerDisconnected", "fh_pill_disconnect", function( ply )
		if ply == stalkTarget then
			net.Start('fh_sound_stop')
			net.WriteString('freddy_targeted_ambience.wav')
			net.Send(victim)
			if IsValid(stalker) then
				noMoreStalk(stalker)
			end
		end
		if ply == request_plushtrap then
			request_plushtrap = nil
		end
		if table.HasValue(affectedPlayers, ply) then
			table.RemoveByValue(affectedPlayers, ply)
			
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(ply)
			net.Broadcast()
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
	
	hook.Add("EntityRemoved", "RemoveKilledCupcake", function(ent)
		if table.HasValue(cupcakes, ent:EntIndex()) then
			table.RemoveByValue(cupcakes, ent:EntIndex())
		end
	end)
	
	hook.Add("OnPlayerPhysicsDrop", "fh_endo_prop_drop", function(ply, ent, thrown)
		local puppet = pk_pills.getMappedEnt(ply)
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
	if ply:IsSprinting() and ply:GetVelocity():LengthSqr() > ply:GetRunSpeed() then
		local target = FindNearestPlayer(ply:GetPos(), 750, ply)
		
		if !IsValid(target) then return end
		if target:IsNPC() then return end
		
		if target:IsSprinting() and target:GetVelocity():LengthSqr() > target:GetWalkSpeed() then
	
			if timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
			playVoiceline(name, 'chase', ply, 1)
			
			timer.Create("ChaseCheck"..ply:EntIndex(), 15, 1, function() end) -- шобы войслайны не играли очень часто
			
		end
	end
end
