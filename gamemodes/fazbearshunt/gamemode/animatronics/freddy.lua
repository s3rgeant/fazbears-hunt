AddCSLuaFile()
local model_prefix = IsHalloween() and "phantom" or "old"

if SERVER then
	util.AddNetworkString("fh_stalker_freddy_halo_start")
	util.AddNetworkString("fh_stalker_freddy_halo_stop")
	
	util.AddNetworkString("fh_addaffected_stalk")
	util.AddNetworkString("freddy_cancel_target")
	
	util.AddNetworkString("notify_freddys_victim")
	util.AddNetworkString("notify_freddys_victim_norage")
	
	util.PrecacheModel("models/speps/pill/" .. model_prefix .. "freddy.mdl")
end
npc_blindrage = CreateConVar( "fh_blindrage_npcs", "0", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Should Withered Freddy be able to use Blind Rage on npcs?" )

local stalkers = {}
local stalkTargets = {}

local wfreddy_default_movement = {150, 490, 70, 250} -- обычное передвижение
local wfreddy_stalk_movement = {150, 600, 75, 255} -- сталкер дохуя

pills.register("pill_wfreddy2",{
	printName="Withered Freddy",
	model="models/speps/pill/" .. model_prefix .. "freddy.mdl",
	options=function() return {
		["default"] = {
			bodyGroups = {[0] = 1},
		},
		["halloween"] = {
			skin=2,
		},
		["christmas"] = {
			bodyGroups = {
				[0] = 1,
				[1] = 1,
			},
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
			scare="scare",
			jump="jump",
			glide="air",
			land="land",
			stalk="stalk",
			stun="stun",
			doorbreak="doorbreak",
			melee="melee",
		},
	},
	moveSpeed={
		walk=wfreddy_default_movement[1],
		run=wfreddy_default_movement[2],
		ducked=wfreddy_default_movement[3],
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee="fnaf2/xscream2.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_freddy",
		skin=IsHalloween() and 3 or 0
	},
	
	animEvent=function(ply,ent,event)
		if event == "FREDDY_DOOR_BREAK" then
			ply:EmitSound("physics/metal/metal_sheet_impact_hard8.wav")
		end
	end,

    jumpPower=250,
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "freddy")
	end,

	noFallDamage=true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 75)
			
			if stalkers[ply] and !stalkTargets[target] then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "freddy", 50, "v_freddy")
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	
	attack2 = {
		mode = "trigger",
		func = function(ply, ent)
			if !ply:OnGround() then return end
			
			startBlindRage(ply, ent)
		end
	}, 

	reload=function(ply,ent)
		if !stalkers[ply] then
			highlight.ByDistance(ply, ent)
		end
	end,
	
	land=function(ply,ent)
		if ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 and ent.anim != 'stalk' then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
		landTripCheck(ply, ent, "freddy")
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,
	onRemove=function(ent,formtable, ply)
		if CLIENT then return end
		
		noMoreStalk(ply)
	
		timer.Remove("SmoothLookAt_"..ply:EntIndex())
		timer.Remove("stalk_check"..ent:EntIndex())
		cooldown.Set(ply, "stalk", 1)
		
		net.Start('fh_sound_stop')
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
		
		ply:SendLua("wfreddy_stalker_door_halo_OFF()")
	end
})

function startBlindRage(ply, ent)
	if cooldown.Exists(ply, "stalk") then return false end

	if ply._isStalkingActive or stalkers[ply] then return false end
	
	local target = fh_random_stalk_target(ply)

	if !IsValid(target) then 
		net.Start("fh_play_sound")
		net.WriteString('ability_failed.wav')
		net.Send(ply)
		
		cooldown.Set(ply, "stalk", 1)
		cooldown.Send(ply, "stalk")
		return false
	end
	
	hook.Run("FH_BlindRageStart", ply, ent, target)

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
		wep:HandleAnimation("deploy", 10)
	end
	
	net.Start('fh_ent_sound_play')
	net.WriteEntity(ply)
	net.WriteString('freddy_stalking_others.wav')
	net.SendOmit(ply)

	local stalkTimerName = "stalk_check" .. ent:EntIndex()
	ply._isStalkingActive = true

	timer.Create(stalkTimerName, 1, 11, function()
		if !IsValid(ply) or !IsValid(ent) or !IsValid(target) or !target:Alive() then
			timer.Remove(stalkTimerName)
			if IsValid(ply) then
				ply._isStalkingActive = nil
				ply:SetFOV(0, 1)

				net.Start("fh_sound_stop")
				net.WriteString("freddy_stalking.wav")
				net.Send(ply)

				net.Start("fh_sound_stop")
				net.WriteString("freddy_stalking_others.wav")
				net.Broadcast()

				ent:EmitSound("freddy_cancelled.wav")

				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep:GetClass() == "v_freddy" then
					wep:HandleAnimation("idle", 0.1)
				end
				ent:PillAnim("idle")
				
				cooldown.Set(ply, "stalk", 15)
				cooldown.Send(ply, "stalk")
					
				hook.Run("FH_BlindRageFailed", ply, ent, target)
			end
			return
		end

		if not ply._isStalkingActive then return end

		if timer.RepsLeft(stalkTimerName) == 8 and target:IsPlayer() then
			target:SetDSP(22)
		end
		if timer.RepsLeft(stalkTimerName) == 6 and target:IsPlayer() then
			target:SetDSP(25)
		end

		if timer.RepsLeft(stalkTimerName) == 1 then
			if ply._isStalkingActive and !stalkTargets[target] then
				ply._isStalkingActive = nil

				timer.Remove("SmoothLookAt_" .. ply:EntIndex())
				timer.Remove(stalkTimerName)
				ply:SetFOV(0, 1)

				successStalk(ply, ent, target)
				return 
			end
		end

		local currentPosition = target:GetPos()
		if target:IsPlayer() and !target:Crouching() or target:IsNPC() and !target:IsCrouching() then
			local distance = currentPosition:Distance(lastPosition)
			if distance > 5 then
				movementTime = movementTime + 1
				if movementTime >= 5 then
					if not ply._isStalkingActive then return end
					ply._isStalkingActive = nil

					ent:PillAnim("idle")
					timer.Remove("SmoothLookAt_" .. ply:EntIndex())
					timer.Remove(stalkTimerName)
					ply:SetFOV(0, 1)

					net.Start("fh_sound_stop")
					net.WriteString("freddy_stalking.wav")
					net.Send(ply)

					net.Start("fh_sound_stop")
					net.WriteString("freddy_stalking_others.wav")
					net.Broadcast()

					ent:EmitSound("freddy_cancelled.wav")

					if math.random(1, 10) > 4 then
						playVoiceline("freddy", "negative", ply, 0.1)
					end

					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:HandleAnimation("idle", 0.1)
					end

					if IsValid(target) and target:IsPlayer() then
						target:SetDSP(1)
						stats.Add(target, "evaded_blind_rage", 1)
					end

					cooldown.Set(ply, "stalk", 40)
					cooldown.Send(ply, "stalk")
					
					hook.Run("FH_BlindRageFailed", ply, ent, target)
					return
				end
			end
		end

		lastPosition = currentPosition
	end)
end

-- сталк
function fh_random_stalk_target(ignore)
    local candidates = {}
	
	local iterator = npc_blindrage:GetBool() and select( 2, ents.Iterator() ) or select( 2, player.Iterator() )
	
    for _, ply in ipairs(iterator) do
        if IsValid(ply) and ply:Alive() and (ply:IsPlayer() and ply:IsSurvivor() and !ply:HasGodMode() or ply:Health() > 0 and ply:IsNPC()) and ply ~= ignore and !outworld_victims[ply] then
			local handler = hook.Run("FH_HandleBlindRageTarget", ignore, ply)
			
			if handler == false then
				continue
			end
			
			if stalkTargets[ply] then continue end
			
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

function successStalk(ply, ent, target)
	if IsValid(target) and target:Alive() and (target:IsPlayer() and target:IsSurvivor() or target:IsNPC()) then
	
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_freddy" then
			wep:AddAnimation("run", ACT_RUN_AIM)
		end
		
		ply:SendLua("wfreddy_stalker_door_halo_ON()")
		
		stalkers[ply] = target
		stalkTargets[target] = ply
		
		target:SetNW2Entity("_BlindRageFreddy", ply)
		
		ent:SetSpeed(unpack(wfreddy_stalk_movement))
		ent:ReplaceAnimation("run", "srun")
		
		net.Start('fh_addaffected_stalk')
		net.WriteEntity(target)
		net.Send(ply)
		
		if target:IsPlayer() then
			target:SetDSP(1)
			
			net.Start("notify_freddys_victim")
			net.Send(target)
		end
			
		net.Start("fh_play_sound")
		net.WriteString('freddy_rage_warning.wav')
		net.SendOmit({ply, target})
		
		net.Start('fh_ent_sound_play')
		net.WriteEntity(ply)
		net.WriteString('freddy_raged2_looped.wav')
		net.Broadcast()
		
		hook.Run("FH_BlindRageSuccess", ply, ent, target)
	end
end

function noMoreStalk(ply)
	local ent = ply:GetPill()
	
	ply:SendLua("wfreddy_stalker_door_halo_OFF()")
	
	if IsValid(ent) then
		ent:SetSpeed(unpack(wfreddy_default_movement))
		ent:ReplaceAnimation("run", "run")
	end
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "v_freddy" then
		wep:AddAnimation("run", nil, "run")
	end
	
	local hisTarget = stalkers[ply]
	
	stalkers[ply] = nil
	if IsValid(hisTarget) then
		hisTarget:SetNW2Entity("_BlindRageFreddy", NULL)
		
		net.Start("notify_freddys_victim_norage")
		net.Send(hisTarget)
		
		stalkTargets[hisTarget] = nil
	end

	cooldown.Set(ply, "stalk", 80)
	cooldown.Send(ply, "stalk")
	
	net.Start("freddy_cancel_target")
	net.Send(ply)
		
	net.Start('fh_sound_stop')
	net.WriteString('freddy_raged2_looped.wav')
	net.Broadcast()
end

local doors = {}
hook.Add("PlayerUse", "AccurateBlockedDoorUse", function(ply, ent)
    local tr = ply:GetEyeTrace()
	local ent = tr.Entity
    if !IsValid(ent) then return end
	
    local hitNormal = tr.HitNormal
	
	if ply._cantBreakDoors or ply:Crouching() or !ply:OnGround() then return end
	
	if !stalkers[ply] then return end
	
	local puppet = pills.getMappedEnt(ply)
	if !IsValid(puppet) then return end
	
	if puppet.formTable.name ~= "pill_wfreddy2" then return end

    local class = ent:GetClass()
	
    local isDoor = class == "func_door" or class == "func_door_rotating" or class == "prop_door_rotating"
    if not isDoor then return end

	if ent:HasSpawnFlags(8192) or ent:HasSpawnFlags(256) then return end
	
    local state = ent:GetInternalVariable("m_toggle_state")
    if state ~= 1 then return end
	
	puppet:PillAnim("doorbreak", true)
	ply._cantBreakDoors = true

    timer.Simple(1.1, function()
        if IsValid(ent) then
            ent:Fire("Open", "", 0)
			doors[ent] = true
			
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
			if doors[ent] then
				ent:Fire("Close", "", 0)
			end
			doors[ent] = false
			ply._cantBreakDoors = false
        end
    end)

    return false
end)

hook.Add( "AcceptInput", "fh_door_input", function( ent, name, activator, caller, data )
	local class = ent:GetClass()
	if class == "func_door" or class == "func_door_rotating" or class == "prop_door_rotating" then
		if doors[ent] and activator:IsPlayer() then
			if IsValid(caller) then
				caller:EmitSound("buttons/button10.wav")
			end
			return true
		end
		
		if doors[ent] and !activator:IsPlayer() and !caller:IsPlayer() and IsValid(activator) then
			doors[ent] = false
		end
	end
end )

hook.Add("FuncDoorBust", "fh_blindrage_doorbust", function(ply, door)
	local puppet = pills.getMappedEnt(ply)
	if not IsValid(puppet) then return end
	local name = puppet.formTable.name

	if name == "pill_wfreddy2" and stalkers[ply] then
		breakBustDoor(ply, door)
	end
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

		if ent:HasSpawnFlags(8192) or ent:HasSpawnFlags(256) then return end

		halo.Add({ent}, Color(255, 255, 255), 2, 2, 1, true, true)
	end
	
	function wfreddy_stalker_door_halo_ON()
		hook.Add("PreDrawHalos", "fh_highlight_breakdoor_stalker", halo_breakable_doors)
	end
	
	function wfreddy_stalker_door_halo_OFF()
		hook.Remove("PreDrawHalos", "fh_highlight_breakdoor_stalker")
	end

	local target
	function fh_addpermanent_affected_freddy(ply)
		addAffected(ply, nil, nil, true)
		target = ply
		toggleShadows(false)
	end

	function toggleShadows(bool)
		if bool then
			for _, ply in player.Iterator() do
				player_renderer.Draw(ply)
			end
		else
			for _, ply in player.Iterator() do
				if ply ~= target and ply:Team() != 2701 then
					player_renderer.NoDraw(ply)
				end
			end
		end
	end

	net.Receive("fh_addaffected_stalk", function()
		fh_addpermanent_affected_freddy(net.ReadEntity())
	end)

	net.Receive("freddy_cancel_target", function()
		if target then
			removeAffected(target, true)
			
			target = nil
		end
		toggleShadows(true)
	end)

	net.Receive("notify_freddys_victim", function()
		surface.PlaySound("freddy_target_stalked.wav")
		drawHighlightTimer(false)
		
		fh_change_display(language.GetPhrase('fazhunt.freddy.foundrun'), language.GetPhrase('fazhunt.freddy.found'), 6)
	end)

	net.Receive("notify_freddys_victim_norage", function()
		hook.Remove("HUDPaint", "fh_hl_overlay_draw")
	end)
	
	hook.Add("FH_HandleKillerTerrorRadius", "freddy_enraged", function(killer, theme)
		local myself = LocalPlayer()
		if IsValid(myself:GetNW2Entity("_BlindRageFreddy")) and killer ~= myself:GetNW2Entity("_BlindRageFreddy") then
			return false
		end
	end)
	
	hook.Add("FH_HandleKillerTerrorLayers", "freddy_enraged", function(killer, theme, layer)
		local myself = LocalPlayer()
		if IsValid(myself:GetNW2Entity("_BlindRageFreddy")) and killer == myself:GetNW2Entity("_BlindRageFreddy") then
			if layer == "second_layer" then
				return "approaching_rage", false
			elseif layer == "third_layer" then
				return "near_rage", false
			end
		end
	end)
	
	hook.Add("FH_HandlePostTerrorRadius", "freddy_enraged", function(theme, layer)
		local myself = LocalPlayer()
		local my_freddy = myself:GetNW2Entity("_BlindRageFreddy")
		if IsValid(my_freddy) and !theme and !layer then
			local theme = terror_radius.getPlayerTheme(my_freddy)
			
			return theme, "first_layer"
		end
	end)
	
	hook.Add("PostCleanupMap", "freddy_cleanup", function()
		target = nil
		toggleShadows(true)
	end)
end

if SERVER then
	local function blindrage_death_handle(victim, inflictor, attacker)
		if stalkTargets[victim] then
			noMoreStalk( stalkTargets[victim] )
			
			if stalkers[attacker] then
				stats.Add(attacker, "killed_using_blind_rage", 1)
			end
			
		elseif stalkers[victim] then
			noMoreStalk( victim )
		end
	end

	hook.Add( "PlayerDeath", "blindrage_death", blindrage_death_handle)
	hook.Add( "PlayerSilentDeath", "blindrage_silentdeath", blindrage_death_handle)
	
	hook.Add( "OnNPCKilled", "npc_death_blindrage", function( npc, attacker, inflictor )
		if stalkTargets[npc] then
			noMoreStalk(stalkTargets[npc])
		end
	end)
	
	hook.Add("FH_OutworldStart", "cancel_freddy_rage", function(wgfreddy, victim)
		if stalkTargets[victim] then
			noMoreStalk(stalkTargets[victim])
		end
	end)
	
	hook.Add( "PlayerDisconnected", "freddy_blindgrage_disconnect", function( ply )
		if stalkTargets[ply] then
			if stalkers[ stalkTargets[ply] ] then
				stats.Add(stalkTargets[ply], "killed_using_blind_rage", 1) -- а ибо нехуй
			end
			
			noMoreStalk( stalkTargets[ply] )
		elseif stalkers[ply] then
			noMoreStalk( ply )
		end
	end)
	
	hook.Add("SetupPlayerVisibility", "freddy_halo_visibility", function(ply, viewent)
		if stalkers[ply] then 
			local player = stalkers[ply]
			if IsValid(player) and player ~= ply then
				if viewent:IsValid() and !viewent:TestPVS( player ) then
					AddOriginToPVS(player:GetPos())
				end
			end
		end
	end)
end

hook.Add( "PostCleanupMap", "blindrage_reset", function( )
	table.Empty(stalkTargets)
	table.Empty(stalkers)
end)