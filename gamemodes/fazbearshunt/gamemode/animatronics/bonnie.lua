AddCSLuaFile()

local model_prefix = IsHalloween() and "phantom" or "old"

if SERVER then
	
	util.AddNetworkString("fh_start_yoursmine_view")
	util.AddNetworkString("fh_stop_yoursmine_view")
	
	util.PrecacheModel("models/speps/pill/" .. model_prefix .. "bonnie.mdl")
end

local bonnie_cmd = {}
hook.Add("StartCommand", "bonnie_cmd_copying", function(ply, cmd)
	if ply:GetNWBool("_yoursmine_target") then
		cmd:RemoveKey(IN_DUCK)
	end
end)

function VaultingExists(ply)
	return (ply.GetMantleEndPos and ply.GetMantle and ply.GetMantleLerp
	and ply.SetMantleEndPos and ply.SetMantle and ply.SetMantleLerp) ~= nil
end

if CLIENT then
	hook.Add("InputMouseApply", "yoursmine_victim_nomouse", function(cmd, x, y, ang)
		if LocalPlayer():GetNWBool("_yoursmine_target") then
			return true
		end
	end)
end

local bonnies_targets = {}
local bonnies_controlled = {}
pills.register("pill_wbonnie2",{
	printName="Withered Bonnie",
	model="models/speps/pill/" .. model_prefix .. "bonnie.mdl",
		
	options=function() return {
		["default"] = {
			bodyGroups = math.random(1,1000) == 2 and { [0] = 1 } or { [0] = 0 }
		},
		["halloween"] = {
			bodyGroups = { [0] = 1 },
		},
		["christmas"] = {
			bodyGroups = { [1] = 1 },
		},
	} end,
	option=IsHalloween() and "halloween" or IsChristmas() and "christmas" or "default",
	
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
			
			melee="melee",
			negative="negative",
			positive="positive",
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
		melee="fnaf2/xscream2.wav",
		jump="jump.mp3",
		land="land.mp3",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 80),
		dist = 120
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_bonnie",
		skin=IsHalloween() and 1 or 0
	},
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,

    jumpPower=250,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "bonnie")
	end,
	
	onRemove=function(ent, ft, ply)
		if CLIENT then return end
		cooldown.Set(ply, "yoursmine", 1)
		
		YoursMine_ForceStop(ply)
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 120, ply, 36)
			
			local success = performJumpscare(ply, ent, target, 1.6, "bonnie", 52, "v_bonnie")
			
			if !IsValid(target) or !success then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
			
			timer.Simple(1.5, function()
				if !IsValid(target) or !success then return end
			
				local armor = target:IsPlayer() and target:Armor() or 0
			
				target:SetLocalVelocity(ply:GetForward() * 600) -- чтоб он нахуй улетел
				target:TakeDamage(target:Health() + armor, ply)
			end)
		end
    },

	taunt=function(ply,ent,act)
		if !ent.NextAct or ent.NextAct and CurTime() > ent.NextAct then
			local wep = ply:GetActiveWeapon()
			if act == ACT_GMOD_GESTURE_DISAGREE and !ply.fh_target_player then
				if !ply:OnGround() then return end

				local dur = ent:PillGesture('negative', 2, 1, 0.1, 0.5)
				if IsValid(wep) then wep:HandleAnimation("negative", 1.6) end
				
				ent.NextAct = CurTime() + dur
			elseif act == ACT_GMOD_GESTURE_AGREE and !ply.fh_target_player then
				if !ply:OnGround() then return end

				local dur = ent:PillGesture('positive', 2, 1, 0.1, 0.5)
				if IsValid(wep) then wep:HandleAnimation("positive", 1.6) end
				
				ent.NextAct = CurTime() + dur
			end
		end
	end,
	
	land=function(ply,ent)
		if ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 and ent.anim ~= 'ability' then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
		
		landTripCheck(ply, ent, "bonnie")
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,

	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

local bonnieSaveStats = {}
function YoursMine_Start(ply, target)
	if ply:IsFrozen() or !ply:OnGround() then return end
	
	if cooldown.Exists(ply, "yoursmine") then return end
	
	if not IsValid(target) then return end
	
	local ent = ply:GetPill()
	--local prev_viewoffset, prev_viewoffset_duck = ply:GetViewOffset(), ply:GetViewOffsetDucked()
	
	if !bonnieSaveStats[ply] then bonnieSaveStats[ply] = {} end
	
	bonnieSaveStats[ply]["prev_viewoffset"] = ply:GetViewOffset()
	bonnieSaveStats[ply]["prev_viewoffset_duck"] = ply:GetViewOffsetDucked()
	
	--local prev_hull, prev_hull2 = ply:GetHull()
	--local prev_hull_duck, prev_hull_duck2 = ply:GetHullDuck()
	--local prev_scale = ply:GetModelScale()
	bonnieSaveStats[ply]["prev_hull"], bonnieSaveStats[ply]["prev_hull2"] = ply:GetHull()
	bonnieSaveStats[ply]["prev_hull_duck"], bonnieSaveStats[ply]["prev_hull_duck2"] = ply:GetHullDuck()
	bonnieSaveStats[ply]["prev_scale"] = ply:GetModelScale()
	
	--local prev_run, prev_walk, prev_duck, prev_jump = ply:GetRunSpeed(), ply:GetWalkSpeed(), ply:GetDuckSpeed(), ply:GetJumpPower()
	bonnieSaveStats[ply]["prev_run"] = ply:GetRunSpeed()
	bonnieSaveStats[ply]["prev_walk"] = ply:GetWalkSpeed()
	bonnieSaveStats[ply]["prev_duck"] = ply:GetDuckSpeed()
	bonnieSaveStats[ply]["prev_jump"] = ply:GetJumpPower()
	bonnieSaveStats[ply]["wasCrouching"] = ply:Crouching()
	
	local wasCrouching = ply:Crouching()
	
	hook.Run("FH_YoursMineStart", ply, ent, target)
	
	ply.fh_target_player = target
	
	bonnies_targets[target] = true
	
	ent:PillAnim('ability', false)
	ent:SetUseForceAngles(true)
	ent:SetForceAngles(ply:GetAngles())
	
	ply:Freeze(true)
	
	cooldown.Set(ply, "yoursmine", 8)
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "v_bonnie" then
		wep:HandleAnimation("deploy", 99999)
		wep.Controlling = true
	end
	
	net.Start("fh_ent_sound_play")
	net.WriteEntity(ent)
	net.WriteString("bonnie_ability_others.wav")
	net.Broadcast()
	
	timer.Simple(1, function()
		hook.Run("FH_YoursMineSpectating", ply, ent, target)
		
		if IsValid(ply) and IsValid(target) then
			ply:Freeze(false)
		
			ent:DetachPlayer()
			
			ply:SetModelScale( target:GetModelScale(), 0 )
			ply:SetViewOffset( target:GetViewOffset() )
			ply:SetViewOffsetDucked( target:GetViewOffsetDucked() )
			ply:SetHull( target:GetHull() )
			ply:SetHullDuck( target:GetHullDuck() )
			
			if target:Crouching() then
				ply:Crouch()
			end
			
			ply:SetRunSpeed( target:GetRunSpeed() )
			ply:SetWalkSpeed( target:GetWalkSpeed() )
			ply:SetDuckSpeed( target:GetDuckSpeed() )
			ply:SetJumpPower( target:GetJumpPower() )
			
			ply:NoPlayerCollide(0.2)
			
			target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
			target:SetSolid(SOLID_NONE)
			
			ply:SetPushBlocked(true)
			ply:SetAudible(false)
			ply:SetOnlyAudibleByTeammates(true)
			
			net.Start("fh_start_yoursmine_view")
			net.WriteEntity(target)
			net.Send(ply)
			
			ply:SetPos(target:GetPos())
			ply:SetAngles(target:GetAngles())
			ply:SetEyeAngles(target:GetAngles())
				
			--ply:SetViewEntity( target )
			
			target:SetNWBool("_yoursmine_target", true)
			target:GodEnable()
			
			bonnies_controlled[target] = ply
		end
	end)
	
	net.Start("fh_ui_sound_play")
	net.WriteString('bonnie_ability_bonnie.wav')
	net.Send(ply)
	
	net.Start("fh_play_sound")
	net.WriteString('bonnie_ability_target.wav')
	net.Send(target)
	
	timer.Simple(8, function()
		YoursMine_ForceStop(ply, target, ent)
	end)
	
	timer.Simple(10.5, function()
		if IsValid(target) then
			target:GodDisable()
			bonnies_targets[target] = nil
		end
	end)
end

function YoursMine_ForceStop(ply, target, ent)
	if !bonnieSaveStats[ply] then return end

	target = target or ply.fh_target_player
	ent = ent or ply:GetPill()
	
	hook.Run("FH_YoursMineEnd", ply, ent, target)
			
	if IsValid(target) then
		target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		target:SetSolid(SOLID_BBOX)
		target:NoPlayerCollide(0.2)
		
		bonnie_cmd[target] = nil
		target:SetNWBool("_yoursmine_target", false)
		bonnies_controlled[target] = nil
		
		if IsValid(ply) then
			if VaultingExists(ply) and ply:GetMantle() ~= 0 then
				local endpos = ply:GetMantleEndPos()
				if not endpos then return end
				
				ply:SetMantle(0)
				ply:SetMantleLerp(1)
				ply:SetMoveType(MOVETYPE_WALK)
				
				target:SetPos(endpos)
			end
			if ply:Crouching() then
				target:Crouch()
			end
		end
	end
	
	if IsValid(ply) then
		net.Start("fh_stop_yoursmine_view")
		net.Send(ply)
		
		if IsValid(ent) then
			ply:SetViewOffset( bonnieSaveStats[ply]["prev_viewoffset"] )
			ply:SetViewOffsetDucked( bonnieSaveStats[ply]["prev_viewoffset_duck"] )
			ply:SetHull( bonnieSaveStats[ply]["prev_hull"], bonnieSaveStats[ply]["prev_hull2"] )
			ply:SetHullDuck( bonnieSaveStats[ply]["prev_hull_duck"], bonnieSaveStats[ply]["prev_hull_duck2"] )
			ply:SetModelScale( bonnieSaveStats[ply]["prev_scale"], 0.01 )
			
			ply:SetRunSpeed( bonnieSaveStats[ply]["prev_run"] )
			ply:SetWalkSpeed( bonnieSaveStats[ply]["prev_walk"] )
			ply:SetDuckSpeed( bonnieSaveStats[ply]["prev_duck"] )
			ply:SetJumpPower( bonnieSaveStats[ply]["prev_jump"] )
			
			ply:SetPos(ent:GetPos())
			ply:SetAngles(ent:GetAngles())
			ply:SetEyeAngles(ent:GetAngles())
			
			ent:AttachPlayer()
		end
		
		ply:NoPlayerCollide(0.2)
		
		ply:SetPushBlocked(false)
		ply:SetAudible(true)
		ply:SetOnlyAudibleByTeammates(false)
		
		if bonnieSaveStats["wasCrouching"] then
			ply:Crouch()
		end
		
		bonnieSaveStats[ply] = nil
		
		if ply:IsStuck() then
			ply:Unstuck()
		end

		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_bonnie" then
			wep:HandleAnimation("draw", 0.5)
			wep.Controlling = false
		end
		
		cooldown.Set(ply, "yoursmine", 55)
		cooldown.Send(ply, "yoursmine")
		
		ply.fh_target_player = nil
	end
	
	if IsValid(ent) then
		ent:SetUseForceAngles(false)
	end
end

function fh_random_yoursmine_target(ignore)
    local candidates = {}
    for _, ply in player.Iterator() do
        if IsValid(ply) and ply:IsSurvivor() and !ply:HasGodMode() and ply ~= ignore and !outworld_victims[ply] then
            table.insert(candidates, ply)
        end
    end

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    else
        return nil
    end
end

hook.Add("FH_HandlePlayerGrab", "yoursmine_targets", function(ply, target)
	if bonnies_targets[target] then
		return false
	end
end)

hook.Add("PlayerSpawn", "yoursmine_targets", function(ply)
	if ply.fh_target_player then
		if ply.lastFhMappedEnt then
			pills.mapEnt(ply, ply.lastFhMappedEnt)
		end
		YoursMine_ForceStop(ply)
	end
end)

hook.Add("ShouldPlayerPush", "yoursmine_targets", function(ply, target)
	if target.fh_target_player then
		return false
	end
end)

hook.Add("FH_HandlePlayerHold", "yoursmine_targets", function(ply, target)
	if bonnies_targets[target] then
		return false
	end
end)

hook.Add("PlayerPostThink", "yoursmine_movement_copying", function(ply)
    if bonnies_controlled[ply] then
		local bonnie = bonnies_controlled[ply]
		
		ply:SetPos(bonnie:GetPos())
		ply:SetEyeAngles(bonnie:LocalEyeAngles())
		ply:SetLocalVelocity(bonnie:GetVelocity())
	end
end)

if CLIENT then
	local yoursmine_halors = {}
	
	hook.Add("PostPlayerDraw", "yoursmine_particles", function(ply)
		if ply:GetNWBool("_yoursmine_target") then
			if !yoursmine_halors[ply] then
				yoursmine_halors[ply] = true
			end
		elseif yoursmine_halors[ply] ~= nil then
			if ply:HasGodMode() then
				yoursmine_halors[ply] = false
			else
				yoursmine_halors[ply] = nil
			end
		end
	end)
	
	local yoursmine_clr = Color(0,70,255)
	
	hook.Add( "PreDrawHalos", "yoursmine_helper", function()
		myself = myself or LocalPlayer()
		for ply, controlled in pairs(yoursmine_halors) do
			if myself:IsAnimatronic() and IsValid(ply) and ply:Health() > 0 and not ply:IsInvisible() then
				local pos = ply:GetPos()
				if pos:ToScreen().visible then
					local distance = myself:GetPos():Distance(pos)
					
					if distance < 1200 then
						local blur = distance / 100
						
						halo.Add({ply}, controlled and yoursmine_clr or color_white, blur, blur, 1, true)
					end
				end
			end
		end
	end)
end