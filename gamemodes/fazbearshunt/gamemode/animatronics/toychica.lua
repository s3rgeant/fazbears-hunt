AddCSLuaFile()

if SERVER then
	util.AddNetworkString( "ObsessorTierOneSetup" )
	util.AddNetworkString( "ObsessorTierTwoSetup" )
	util.AddNetworkString( "ObsessorTierThreeSetup" )
	util.AddNetworkString( "ObsessorShitDown" )
	
	util.AddNetworkString( "remove_tchica_bar" )
	
	util.AddNetworkString( "cancel_obsosi_toychica" )
	util.AddNetworkString( "addaffected_obs_toychica" )
	util.AddNetworkString( "remove_obsos_toychica" )
	
	util.PrecacheModel("models/ufmp/fnaf2/toys/toychica.mdl")
end
sound.Add({
	name = 			"toychica.run",
	channel = 		CHAN_STATIC,
	level = 		90,
	volume = 		1.0,
	sound = 			{"footsteps/toy_step1.mp3"
						,"footsteps/toy_step2.mp3"
						,"footsteps/toy_step3.mp3"}
})

local dr_alpha = 0
local dr_y = 0
	
local myself

local function DrawHoldingNickname()
	if SERVER then return end
	
	myself = myself or LocalPlayer()
	
	local ply = myself:GetNWEntity("tchica_hold_target")
	
	if IsValid(ply) then
		dr_alpha = Lerp(FrameTime() * 4, dr_alpha, 255)
		dr_y = Lerp(FrameTime() * 4, dr_y, 6)
		
		local ownerName = ply:Nick()
		local screenPos = (ply:EyePos() + Vector(0,0,dr_y)):ToScreen()

		draw.SimpleText(ownerName, "timerFontBelow", screenPos.x, screenPos.y, Color(255, 255, 255, dr_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		return
	end
	dr_alpha = 0
	dr_y = 0
end

local obsessors = {}

local toychicas = {}

local tchicaObsessors = {}

local chicaHolders = {}
local chicasHoldings = {}

function toychica_GetTargetValueByTier(tier)
	return (tier == 0 and 0) or (tier == 1 and 25) or (tier == 2 and 60) or 100
end

hook.Add("PillApply", "toychica_members_apply", function(ply, ent)
	if ent.formTable and ent.formTable.name and ent.formTable.name == "pill_toychica" then
		toychicas[ply] = true
		
		if CLIENT and ply == LocalPlayer() then
			hook.Add("HUDPaint", "tchica_hold_nickname", DrawHoldingNickname)
		end
	end
end)

hook.Add("PillRestore", "toychica_members_restore", function(ply, ent)
	toychicas[ply] = nil
		
	if CLIENT and ply == LocalPlayer() then
		hook.Remove("HUDPaint", "tchica_hold_nickname")
	end
end)

local function chicaTierChange(ply, tier)
	SetGlobal2Int("_TChicaObsessorCount", tier)
	
	if IsValid(ply) and ply:IsAnimatronic() then
		if tier >= math.min(math.max(1, table.Count(survivors)), 2) then
			ply:SprintEnable()
		else
			ply:SprintDisable()
		end
	end
	
	print("[toy_chica] Obsessor Count SET to " .. tier)
end

local function obsessorTierUp(ply, tier, tchica)
	if tier == 0 then
		net.Start("ObsessorShitDown")
		net.Send(ply)
		ply:SetNW2Int("_ObsessorValue", 0)
	elseif tier == 1 then
		net.Start("ObsessorTierOneSetup")
		net.Send(ply)
	elseif tier == 2 then
		net.Start("ObsessorTierTwoSetup")
		net.Send(ply)
	elseif tier == 3 then
		net.Start("ObsessorTierThreeSetup")
		net.Send(ply)
		
		if tchica then
			net.Start("addaffected_obs_toychica")
			net.WriteEntity(ply)
			net.Send(tchica)
		end
	end
	
	ply:SetNW2Int("_ObsessorTier", tier)
end

local function chicaRestore(ply)
	for target, data in pairs(obsessors) do
		if data.tchica == ply then
			net.Start("ObsessorShitDown")
			net.Send(target)
			
			if not IsValid(target) then
				obsessors[target] = nil
				return
			end
			obsessorTierUp(target, 0)
			
			obsessors[target] = nil
			
			target:SetNW2Int("_ObsessorValue", 0)
		end
	end
	tchicaObsessors[ply] = nil
	
	chicaTierChange(nil, 0)
	
	net.Start("cancel_obsosi_toychica")
	net.Send(ply)
end

if !timer.Exists("obsessors_check") then
    timer.Create("obsessors_check", 8, 0, function()
		if !table.IsEmpty(obsessors) then
			--print(math.min(math.max(1, table.Count(survivors)), 3))
			if GetGlobal2Int("_TChicaObsessorCount") < math.min(math.max(1, table.Count(survivors)), 3) then return end
		
			local plysNearObsos = {}
			
			for ply, data in pairs(obsessors) do
				if data.tier ~= 3 then continue end
				candidates = ents.FindInSphere(ply:GetPos(), 420)
				for _, target in ipairs(candidates) do
					if not target:IsPlayer() then continue end
					if not target:Alive() then continue end
					if not target:IsSurvivor() then continue end
					if target:IsInvisible() then continue end
					if target == ply then continue end
					if plysNearObsos[target] then continue end

					local tr = util.TraceLine({
						start = target:EyePos(),
						endpos = ply:EyePos(),
						filter = {target, ply},
						mask = MASK_SHOT
					})

					if tr.Hit and tr.Entity ~= ply then
						continue
					end
					
					table.insert(plysNearObsos, target)
				end
			end
			
			if !table.IsEmpty(plysNearObsos) then
				for ply, _ in pairs(animatronics) do
					highlight.Add(ply, plysNearObsos, 5, Color(255,0,255))
				end
			end
		end
	end)
end

timer.Pause("obsessors_check")

hook.Add("fh_poststartgame", "obsessor_handling", function()
    timer.UnPause("obsessors_check")
end)

hook.Add("fh_postendgame", "obsessor_handling", function()
    timer.Pause("obsessors_check")
end)
	
local function obsessorFallOffTimer(ply)
	local timerName = "FallOff_Obsessor" .. ply:EntIndex()
	
	if timer.Exists(timerName) then
		timer.Adjust(timerName, 60)
		return
	end
	
	timer.Create(timerName, 60, 0, function()
		if !IsValid(ply) or !ply:Alive() or !obsessors[ply] then return end
		
		local curTier = obsessors[ply].tier
		
		if curTier >= 3 then return end
		
		if curTier > 0 then
			obsessors[ply].tier = curTier - 1
			obsessorTierUp(ply, curTier - 1, obsessors[ply].tchica)
			
			local value_to_tier = curTier-1 == 0 and 0 or curTier-1 == 1 and 25 or 60
			obsessors[ply].value = value_to_tier
			
			ply:SetNW2Int("_ObsessorValue", value_to_tier)
			
			print("[toy_chica]", ply, 'Downed a tier. Tier: ', curTier-1, value_to_tier)
			
			if curTier-1 <= 0 then
				timer.Remove(timerName)
			end
		end
	end)
end

local function gainObsession(target, num, ply)
	if !obsessors[target] then
		obsessors[target] = {
			tier = 0,
			value = num,
			tchica = ply,
		}
		return
	end
	
	if tchicaObsessors[ply] and tchicaObsessors[ply][target] then return end
	
	local obs_tier = obsessors[target].tier
	local obs_value = obsessors[target].value
	
	local new_value = obs_value + num
	local value_to_tier = obs_tier == 0 and 25 or obs_tier == 1 and 60 or 100
	
	if obs_tier < 3 then
		if new_value >= value_to_tier then
			if obs_tier + 1 == 3 then
				if GetGlobal2Int("_TChicaObsessorCount") >= 3 then
					return
				end
			end
			obsessors[target].tier = obs_tier + 1
			obsessorTierUp(target, obs_tier + 1, ply)
			--print("[toy_chica] Player " .. target:Nick() .. " TIER UP --> ", obsessors[target].tier )
		end
		obsessors[target].value = new_value
		
		obsessorFallOffTimer(target)
	end
	
	target:SetNW2Int("_ObsessorValue", new_value)
			
	if obsessors[target].tier == 3 then -- ТАРГЕТ СТАНОВИТСЯ ОБСЕСОЛКОЙ
		if !tchicaObsessors[ply] then
			tchicaObsessors[ply] = {}
		end
		tchicaObsessors[ply][target] = true
		
		chicaTierChange(ply, table.Count(tchicaObsessors[ply]) )
		
		print("[toy_chica] Player " .. target:Nick() .. " became a obssesor!")
		return
	end
	
	--print("[toy_chica] Player " .. target:Nick() .. " gained obsession: ", obsessors[target].value .. " / " .. value_to_tier )
end

local function noMoreObsessor(ply)
	if chicasHoldings[ply] then
		releaseTarget(ply)
	end

	if !obsessors[ply] then return end
	
	local toychica = obsessors[ply].tchica
	
	if IsValid(toychica) then
		if tchicaObsessors[toychica] then
			tchicaObsessors[toychica][ply] = nil
			
			local tier = table.Count( tchicaObsessors[toychica] )
			timer.Simple(0, function()
				if IsValid(toychica) then	chicaTierChange( toychica, tier )	end
			end)
		end
		
		if obsessors[ply].tier >= 3 then
			net.Start("remove_obsos_toychica")
			net.WriteEntity(ply)
			net.Send(toychica)
		end
		net.Start("remove_tchica_bar")
		net.WriteInt(ply:UserID(), 12)
		net.Send(toychica)
	end
	
	obsessors[ply] = nil
	
	obsessorTierUp(ply, 0)
	
	local timerName = "FallOff_Obsessor" .. ply:EntIndex()
	
	if timer.Exists(timerName) then
		timer.Adjust(timerName, 1, 1, function() end)
		timer.Remove(timerName)
	end
end

hook.Add("PlayerSpawn", "tchica_spawn_noobs", noMoreObsessor)
hook.Add("PlayerDisconnected", "tchica_disconnect", noMoreObsessor)
hook.Add("PostPlayerDeath", "tchica_death", noMoreObsessor)
hook.Add("PillApply", "tchica_pill", noMoreObsessor)

local function chicaObsessionCheck(ply, ent)
	if isGameOn and !roundActive then return end

	-- УДЕРЖАНИЕ
	local dumbass = chicaHolders[ply]
	if IsValid(dumbass) then
		gainObsession(dumbass, 7, ply)
	end
	
	--LOS
	-- ОНО НЕ РАБОТАЕТ ВНЕ РАУНДА ПОТОМУ ЧТО ИГРОКИ НЕ ВНОСЯТСЯ В ТАБЛИЦУ SURVIVORS ПРИ СПАВНЕ
	local hasLos = {}
	for target, _ in pairs(survivors) do
		if !IsValid(target) then continue end
		if not target:Alive() then continue end
		if target == ply then continue end
		if target == dumbass then continue end
		if target == chicaHolders[ply] then continue end
		
		local pos = target:GetPos()
		local targetEyePos = target:EyePos()
		local distance = ply:GetPos():Distance(pos)

		if distance > 2000 then continue end

		local targetEyePos = target:EyePos()
		local targetForward = target:EyeAngles():Forward()
		local dirToPly = (ply:EyePos() - targetEyePos):GetNormalized()

		local dot = targetForward:Dot(dirToPly)
		if dot < 0.5 then continue end

		local tr = util.TraceLine({
			start = targetEyePos,
			endpos = ply:EyePos(),
			filter = {target, ply},
			mask = MASK_SHOT
		})

		if tr.Hit and tr.Entity ~= ply then
			continue
		end
		
		local gain = math.Round( math.Clamp(2500 / distance, 1, 5), 1)
		gainObsession(target, gain, ply)

		hasLos[target] = true
	end
	
	-- БЛИЗОСТЬ
	candidates = ents.FindInSphere(ply:GetPos(), 420)
	for _, target in ipairs(candidates) do
		if not target:IsPlayer() then continue end
		if not target:Alive() then continue end
		if not target:IsSurvivor() then continue end
		if target == ply then continue end
		if target == dumbass then continue end
		if hasLos[target] then continue end
		if target == chicaHolders[ply] then continue end
		
		local pos = target:GetPos()
		local distance = ply:GetPos():Distance(pos)

		local tr = util.TraceLine({
			start = target:EyePos(),
			endpos = ply:EyePos(),
			filter = {target, ply},
			mask = MASK_SHOT
		})

		if tr.Hit and tr.Entity ~= ply then
			continue
		end
		
		local gain = math.Round( math.Clamp(420 / distance, 1, 3), 1)
		gainObsession(target, gain, ply)
	end
end

local tchica_default_movement = {220, 475, 70, 250} -- обычное передвижение
local tchica_hold_movement = {65, 65, 65, 250} -- держит кого-то

pills.register("pill_toychica",{
	printName="Toy Chica",
	model="models/ufmp/fnaf2/toys/toychica.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			
			jump="jump",
			glide="glide",
			
			hold="hold",
			holdwalk="holdwalk",
			
			crouch="crouch",
			crouch_walk="crouchmove",
			stun="stun",
		},
		gestures={
			land="land",
			
			damaged1="damaged1",
			damaged2="damaged2",
			damaged3="damaged3",
			
			melee="attack",
		},
	},
	moveSpeed={
		walk=220,
		run=475,
		ducked=70,
	},
	modelScale="1.3",
	bodyGroups={["Cupcake"] = 1},
	sounds={
		--jump="jump.mp3",
		--land="land.mp3",
		melee=")fnaf2/xscream2.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 76),
		dist = 120
    },
	hull=Vector(32,32,78),
	duckBy=54,
	bloodType=BLOOD_COLOR_MECH,
	
	viewmodel={
		weapon="v_toychica"
	},
	
    jumpPower=255,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	muteSteps = true,

	noFallDamage=true,
	
	startFunction=function(ply,ent)
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
			
			chaseCheck(ply, 'tchica')
		end)
		
		ply:SetJumpBoost(0)
		ply:SprintDisable()
		
		timer.Create("ObsessionCheck"..ply:EntIndex(), 1, 0, function()
			if !IsValid(ent) then
				if timer.Exists( "ObsessionCheck"..ply:EntIndex()) then
					timer.Remove("ObsessionCheck"..ply:EntIndex())
				end
				return
			end
			
			chicaObsessionCheck(ply,ent)
		end)
	end,

	restore=function(ply, ent)
		if CLIENT then 
			removeTChicaALLBARS()
			return 
		end
		chicaRestore(ply)
		
		ply:SetJumpBoost( getScaledJumpBoost() )
		ply:SprintEnable()
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			AnimatronicBreakProp(ply, ent)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if cooldown.Exists(ply, 'hold') then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 75)
			
			if !IsValid(target) then return end
			
			holdPlayer(ply,ent,target)
		end
	},
	
	land=function(ply,ent)
		if ply:WaterLevel() < 2 then
			ent:PillGesture('land', 1, 1, 0, 0.7)
			return
		end
		
		landTripCheck(ply, ent, "tchica")
	end,
	
	noragdoll=true,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

hook.Add( "fh_animatronic_post_break_prop", "fh_toychica_punch", function( ply, ent, tr )
	local target = tr.Entity
	
	if ent and ent:GetPillName() == "pill_toychica" then
		if target:IsPlayer() and tchicaObsessors[ply] and (tchicaObsessors[ply][target] or GetGlobal2Int("_TChicaObsessorCount") == math.min(math.max(1, table.Count(survivors)), 3)) then
			local wep = ply:GetActiveWeapon()

			ply:EmitSound("bonnie_punch.mp3")
			
			local dmginfo = DamageInfo()
			dmginfo:SetAttacker( ply )
			dmginfo:SetInflictor( IsValid(wep) and wep or ply )
			dmginfo:SetDamage( 25 )

			SuppressHostEvents( NULL )
			target:TakeDamageInfo( dmginfo )
			SuppressHostEvents( ply )
			if IsValid(wep) then
				wep:HandleAnimation("attack", 0.8)
			end
			
			if not target:Alive() then
				playVoiceline("tchica", "kill", ply, .5)
			end
			
			ent:PillGesture('melee', 2, 1, 0.1, 0.7)
			
			local edata = EffectData()
			edata:SetOrigin(tr.HitPos)
			edata:SetEntity(target)
			util.Effect("BloodImpact", edata, true, true)
			
			ply._breakPropAsAnimTime = CurTime() + 1.1
		end
	end
end)
	
hook.Add("SetupPlayerVisibility", "toychica_halo_visibility", function(ply, viewent)
	if toychicas[ply] and tchicaObsessors[ply] then 
		for player, _ in pairs(tchicaObsessors[ply]) do
			if IsValid(player) and player ~= ply then
				if viewent:IsValid() and !viewent:TestPVS( player ) then
					AddOriginToPVS(player:GetPos())
				end
			end
		end
	end
end)

function holdPlayer(ply, ent, target)
	if not IsValid(ply) or not IsValid(target) then return end
	if chicaHolders[ply] == target then return end
	
	if hook.Run("FH_HandlePlayerHold", ply, target) == false then return end
	
	playVoiceline("tchica", 'grab', ply)

	chicaHolders[ply] = target
	chicasHoldings[target] = ply
		
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "v_toychica" then
		wep:AddAnimation("walk", ACT_WALK_AIM)
		wep:AddAnimation("idle", ACT_IDLE_AIM_STIMULATED)
	end
	
	ply:SetNWBool("tchica_holding", true)
	ply:SetNWEntity("tchica_hold_target", target)
	ent:ReplaceAnimation("idle", "hold")
	ent:ReplaceAnimation("walk", "holdwalk")
	ent:SetSpeed(unpack(tchica_hold_movement))
	ent:SetUseForceAngles(true)
	
	target:SendLua( "INTERACT_Hint( 5 )" )
	
	target:SetMoveType(MOVETYPE_NONE)
	target:SetNWBool("tchica_victim", true)
	
	target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	
	timer.Remove("fh_repeat_unstuck" .. target:EntIndex())
end

local remberPushes = {}
hook.Add("PlayerPush", "toychica_pushing", function(ply, target)
    if chicaHolders[target] and ply:IsSurvivor() then
		if !remberPushes[target] then
			remberPushes[target] = 1
			return 0
		end
		
		local dumbass = chicasHoldings[ply] or false
		
		remberPushes[target] = remberPushes[target] + (dumbass and 1 or 4)
		
		if remberPushes[target] >= 20 then
			releasePlayer(target, 8)
			remberPushes[target] = 0
			playVoiceline("tchica", 'release', target, 0.1)
			return 450
		end
		return 0
	end
end)

function releaseTarget(target, cd)
	if not chicasHoldings[target] then return end
	local ply = chicasHoldings[target]
	
	releasePlayer(ply, cd)
end

function releasePlayer(ply, cd)
	local target = chicaHolders[ply]
	local ent = ply:GetPill()
	
	if chicaHolders[ply] and IsValid(ent) and ent.formTable and ent.formTable.name == "pill_toychica" then
		ent:ReplaceAnimation("idle", "idle")
		ent:ReplaceAnimation("walk", "walk")
		ent:SetSpeed(unpack(tchica_default_movement))
		ent:SetUseForceAngles(false)
		
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_toychica" then
			wep:AddAnimation("walk", ACT_WALK)
			wep:AddAnimation("idle", ACT_IDLE)
			
			wep:HandleAnimation("interrupt", 0.5)
		end
	
		if not cd or cd > 0 then
			cooldown.Set(ply, 'hold', cd or 4)
			cooldown.Send(ply, "hold")
		end
	
		ply:SetNWBool("tchica_holding", false)
		ply:SetNWEntity("tchica_hold_target", NULL)
		chicaHolders[ply] = nil
		
		remberPushes[ply] = 0
	end
	
	if IsValid(target) then
		chicasHoldings[target] = nil
		target:SetMoveType(MOVETYPE_WALK)
		
		target:RepeatRestoreCollision(0.25)
		
		target:SetNWBool("tchica_victim", false)
	
		target:SendLua( "RemoveINTERACT_Hint()" )
		
		timer.Simple(0, function()
			if target:IsStuck() then
				target:SetPos(ply:GetPos())
			end
		end)
	end
end

hook.Add("KeyRelease", "toychica_key_release", function(ply, key)
    if key == IN_ATTACK2 then
		ply:LagCompensation(true)
		releasePlayer(ply)
		ply:LagCompensation(false)
    end
end)

hook.Add("SetupMove", "tchica_holding_tick", function(ply, mv, cmd)
	local holder = chicasHoldings[ply]
	if not IsValid(holder) then return end
	
	local ent = holder:GetPill()
	local startPos = holder:GetPos()
	local forward = holder:GetForward()
	
	local maxDist = 48
	
	local desiredPos = startPos + forward * maxDist
	desiredPos.z = startPos.z
	
	local trace = util.TraceHull({
		start = startPos + Vector(0,0, holder:GetStepSize()),
		endpos = desiredPos,
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		filter = function(e)
			return e ~= ply and e ~= holder and !e:IsPlayer()
		end,
	})
	
	local finalPos = desiredPos
	if trace.Hit then
		finalPos = trace.HitPos - forward * 5
		finalPos.z = startPos.z
	end
	
	
	
	if startPos:Distance(trace.HitPos - forward * 5) <= 22 then
		holder:SetVelocity(-forward * 15)
	end
	
	mv:SetOrigin(finalPos)
	
	local ang = (holder:GetPos() - finalPos):Angle()
	ang.p = 0
	ply:SetEyeAngles(ang)
	
	if IsValid(ent) then
		local ang2 = (finalPos - holder:GetPos()):Angle()
		ang2.p = 0
		ent:SetForceAngles(ang2)
		
		ent:SetPoseParameter("hold_far", startPos:Distance(trace.HitPos))
	end
end)

local nextBoostTime = 0
local boostEndTime = 0
local boosting = false

hook.Add("Move", "tchica_obsessor_runbuff", function(ply, mv)
	if GetGlobal2Int("_TChicaObsessorCount") <= 0 then return end
	if not (ply:GetPill() and ply:IsSprinting()) then return end

	local ct = CurTime()

	if not boosting then
		if ct >= nextBoostTime then
			boosting = true
			boostEndTime = ct + 5
			nextBoostTime = boostEndTime + 5
		end
	end

	if boosting then
		if ct < boostEndTime then
			local desired = mv:GetMaxSpeed() * 1.05
			mv:SetMaxSpeed(desired)
			mv:SetMaxClientSpeed(desired)
		else
			boosting = false
		end
	end
end)

hook.Add( "PlayerPostThink", "tchica_obsessor_landbuff", function(ply)
	if SERVER then
		if GetGlobal2Int("_TChicaObsessorCount") >= math.min(math.max(1, table.Count(survivors)), 2) then
			local pill = ply:GetPill()
			if pill and pill.formTable and pill.anim == "land" then
				pill:SetPlaybackRate(1.2)
			end
		end
	end
end )

hook.Add( "FH_HandlePlayerGrab", "tchica_endo_grab", function(ply, target)
	if target:GetNWBool("tchica_victim") then
		return false
	end
end )

hook.Add( "PlayerSpawn", "tchica_spawn", function(ply)
	if ply:GetNWBool("tchica_victim") then ply:SetNWBool("tchica_victim", false) end
	if ply:GetNWBool("tchica_holding") then ply:SetNWBool("tchica_holding", false) end
	ply:SetNWEntity("tchica_hold_target", NULL)
end )

hook.Add("StartCommand", "tchica_holder_tick", function(ply, cmd)
    if ply:GetNWBool("tchica_holding") or ply:GetNWBool("tchica_victim") then
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_SPEED)
		cmd:RemoveKey(IN_WALK)
		cmd:RemoveKey(IN_DUCK)
		if !ply:GetNW2Bool("KillerObsessed") then
			cmd:RemoveKey(IN_ATTACK)
		end
	end
end)

local PushSound_pills = {
	"physics/metal/metal_solid_impact_hard1.wav", "physics/metal/metal_solid_impact_hard4.wav",
	"physics/metal/metal_solid_impact_hard5.wav", "physics/metal/metal_solid_impact_soft1.wav",
	"physics/metal/metal_solid_impact_soft2.wav", "physics/metal/metal_solid_impact_soft3.wav",
}

local push = {}
hook.Add("KeyPress", "toychica_push", function(ply, key)
	if !ply:GetNWBool("tchica_victim") then return end

	if key == IN_USE and not push[ply:UserID()] then
		
		local ent = chicasHoldings[ply]
		if IsValid(ply) and IsValid(ent) then
			if ply:IsPlayer() and ply:Team() ~= TEAM_SPECTATOR and ent:IsPlayer() then
				
				if ent:Alive() and ent:GetMoveType() == MOVETYPE_WALK and not ent:IsFlagSet(FL_FROZEN) then
					hook.Run("PlayerPush", ply, ent)
					
					ply:EmitSound(PushSound_pills[math.random(#PushSound_pills)], 100, 100)

					ent:ViewPunch(Angle(math.random(-4, 4), math.random(-4, 4), 0))
					
					push[ply:UserID()] = true
					timer.Simple(0.20, function()
						if IsValid(ply) then
							push[ply:UserID()] = false
						end
					end)
				end
			end
		end
	end
end)

hook.Add("PlayerPush", "toychica_push", function(ply, target)
	if IsValid(target:GetPill()) then
		if target:GetPill():GetPillName() == "pill_toychica" then
			target:GetPill():PillGesture('damaged' .. math.random(1,3), 1, 1, 0, 0.7)
		end
	end
end)

hook.Add( "ShouldPlayerPush", "tchica_push", function( ply, ent )
    if ply:GetNWBool("tchica_victim") then 
		return false
	end
end )

hook.Add( "OnPlayerPhysicsPickup", "tchica_pickup", function( ply, ent )
    if ply:GetNWBool("tchica_holding") or ply:GetNWBool("tchica_victim") then 
		ply:DropObject()
	end
end )

hook.Add("fh_prestartgame", "toychica_prestart", function()
	table.Empty(obsessors)
	table.Empty(tchicaObsessors)
	table.Empty(chicaHolders)
	table.Empty(chicasHoldings)
	table.Empty(remberPushes)
end)

hook.Add( "PostCleanupMap", "toychica_map_cleanup", function()
	table.Empty(obsessors)
	table.Empty(tchicaObsessors)
	table.Empty(chicaHolders)
	table.Empty(chicasHoldings)
	table.Empty(remberPushes)
end)

if CLIENT then
	terror_radius.addTheme("pill_toychica", "default")
	
	local KindaObsessor = false
	hook.Add("FH_HandleKillerTerrorRadius", "toychica_handle", function(myself, killer, theme, ent)
		if IsValid(ent) and ent:GetPillName() == "pill_toychica" then
			if !KindaObsessor then
				return false
			end
		end
	end)
	
	local SecondTierObsessor = false
	hook.Add("FH_HandleKillerTerrorLayers", "toychica_handle", function(myself, killer, theme, layer, ent)
		if IsValid(ent) and ent:GetPillName() == "pill_toychica" then
			if !SecondTierObsessor and KindaObsessor and (layer == "first_layer" or layer == "second_layer") then
				return layer, true
			end
		end
	end)
	
	hook.Add("FH_HandleMineTerrorRadius", "toychica_handle", function(me, ply, theme, ent)
		if IsValid(ent) and ent:GetPillName() == "pill_toychica" then
			if !me:IsSprinting() then
				return false
			end
		end
	end)
	
	local ThirdTierObsessor = false
	
	local YAW_LIMIT_DPS = 150
    local lastAng
    hook.Add("StartCommand", "limit_mouse_tchica", function(ply, cmd)
		if ply:GetNWBool("tchica_holding") then
			local ang = cmd:GetViewAngles()

			if not lastAng then
				lastAng = Angle(ang.p, ang.y, ang.r)
				return
			end

			local maxDelta = YAW_LIMIT_DPS * RealFrameTime()

			local dy = math.AngleDifference(ang.y, lastAng.y)

			if dy > maxDelta then dy = maxDelta
			elseif dy < -maxDelta then dy = -maxDelta end

			ang.y = lastAng.y + dy
			cmd:SetViewAngles(ang)

			lastAng.y = ang.y
			lastAng.p = ang.p
			lastAng.r = 0
			return
		end
		lastAng = nil
    end)
	
	local defaultFog = nil
	local active = false

	local startTime = 0

	local targetFog = {
		color = Vector(255, 120, 180),
		start = 0,
		endd = 3000,
		density = 0.2
	}

	net.Receive("ObsessorTierOneSetup", function()
		local fs, fe = render.GetFogDistances()
		local d = render.GetFogMaxDensity()
		local r, g, b = render.GetFogColor()
		
		--if fs == 0 then fs = 10000 end
		if fe == 0 then fe = 10000 end

		defaultFog = {
			color = Vector(r, g, b),
			start = fs,
			endd = fe,
			density = d
		}

		startTime = CurTime()
		active = true
		
		KindaObsessor = true
		SecondTierObsessor = false
		ThirdTierObsessor = false
	end)

	net.Receive("ObsessorTierTwoSetup", function()
		SecondTierObsessor = true
		ThirdTierObsessor = false
	end)

	net.Receive("ObsessorTierThreeSetup", function()
		ThirdTierObsessor = true
		
		for ply, _ in pairs(toychicas) do
			if IsValid(ply) and ply:Alive() and ply:GetPill() then
				local ent = ply:GetPill()
				
				if IsValid(ent) then
					ent:SetBodygroup(1, 1)
				end
			end
		end
	end)

	hook.Add("NotifyShouldTransmit", "fh_toychica_clyuve", function(entity, trans)
		if ThirdTierObsessor and entity:IsPlayer() and trans and toychicas[entity] then
			local ent = entity:GetPill()
			
			if IsValid(ent) then
				ent:SetBodygroup(1, 1)
			end
		end
	end)

	local riseTime = 6
	local holdTime = 2 
	local fallTime = 6

	local function smoothstep(t)
		return t * t * t * (t * (t * 6 - 15) + 10)
	end

	hook.Add("SetupWorldFog", "ObsessorFogPulsing", function()
		if not active or not defaultFog then return end

		local total = riseTime + holdTime + fallTime
		local t = (CurTime() - startTime) % total
		local k

		if t < riseTime then
			k = smoothstep(t / riseTime)

		elseif t < riseTime + holdTime then
			k = 1
		else
			local tt = (t - (riseTime + holdTime)) / fallTime
			k = 1 - smoothstep(tt)
		end

		local from = defaultFog
		local to = targetFog

		local r = Lerp(k, from.color.x, to.color.x)
		local g = Lerp(k, from.color.y, to.color.y)
		local b = Lerp(k, from.color.z, to.color.z)
		local s = Lerp(k, from.start,    to.start)
		local e = Lerp(k, from.endd,     to.endd)
		local d = Lerp(k, from.density,  to.density)

		render.FogMode(MATERIAL_FOG_LINEAR)
		render.FogStart(s)
		render.FogEnd(e)
		render.FogColor(r, g, b)
		render.FogMaxDensity(d)

		return true
	end)

	net.Receive("ObsessorShitDown", function()
		active = false
		SecondTierObsessor = false
		KindaObsessor = false
	end)
	
	-- партиклы хуяртиклы
	local PARTICLE_TEXTURE = "particles/heart"
	local PARTICLES_PER_TICK = 2
	local nextParticleTimes = {}
	hook.Add("PostPlayerDraw", "lovetaste_particles", function(ply)
		if ply:GetNW2Int("_ObsessorTier") <= 0 then return end
		
		if !nextParticleTimes[ply] then nextParticleTimes[ply] = 0 end
	
		if CurTime() < nextParticleTimes[ply] then return end

		local tier = ply:GetNW2Int("_ObsessorTier")
		if tier <= 2 then
			nextParticleTimes[ply] = CurTime() + (2 / tier)
		else
			nextParticleTimes[ply] = CurTime() + 0.25
		end

		local emitter = ParticleEmitter(ply:GetPos(), false)
		if not emitter then return end

		for i = 1, PARTICLES_PER_TICK do
			local pos = ply:EyePos() + Vector(math.Rand(-2,2),math.Rand(-2,2),-5)

			local particle = emitter:Add(PARTICLE_TEXTURE, pos)
			if particle then
				local upVelocity = Vector(0, 0, math.Rand(25, 20))
				local sideVelocity = ply:GetForward() * math.Rand(-12, 12)

				particle:SetVelocity(upVelocity + sideVelocity + (ply:GetVelocity() * 0.2))
				particle:SetLifeTime(0)
				particle:SetDieTime(math.Rand(0.5, 1))
				particle:SetStartAlpha(math.Rand(140, 200))
				particle:SetEndAlpha(0)
				particle:SetStartSize(math.Rand(2, 3))
				particle:SetEndSize(math.Rand(6, 8))
				particle:SetRoll(math.Rand(-0.1, 0.1))
				--particle:SetRollDelta(math.Rand(-0.1, 0.1))
				particle:SetColor(255, 255, 255)
				particle:SetAirResistance(25)
			end
		end

		emitter:Finish()
	end)

	local obsosi = {}
	net.Receive("addaffected_obs_toychica", function()
		local ply = net.ReadEntity()
		addAffected(ply, nil, Color(255,0,255), true)
		obsosi[ply] = true
	end)
	
	net.Receive("remove_obsos_toychica", function()
		local ply = net.ReadEntity()
		removeAffected(ply, true)
		obsosi[ply] = nil
	end)
	
	net.Receive("cancel_obsosi_toychica", function()
		for ply, _ in pairs(obsosi) do
			removeAffected(ply, true)
		end
		table.Empty(obsosi)
	end)

	hook.Add( "PostCleanupMap", "toychica_client_cleanup", function()
		table.Empty(obsosi)
		active = false
		SecondTierObsessor = false
		ThirdTierObsessor = false
		KindaObsessor = false
		
		removeTChicaALLBARS()
	end)

	local panels = {}
	local bg = Material("vgui/animatronics_hud/abilities/toy_chica/background.png")
	local avatar_frame = Material("vgui/animatronics_hud/abilities/toy_chica/avatar.png")
	local heart_full = Material("vgui/animatronics_hud/abilities/toy_chica/heart_full.png")
	local heart_mid = Material("vgui/animatronics_hud/abilities/toy_chica/heart_mid.png")
	local heart_low = Material("vgui/animatronics_hud/abilities/toy_chica/heart_low.png")

	surface.CreateFont("tchica_victim_nick", { 
		font = "Share Tech Mono", 
		size = 18 --[[* uiScale ]], 
		extended = true, 
		weight = 400, 
		antialias = true, 
		bold = true 
	})

	local colorWhite = Color(255,201,53,255)
	local colorPink = Color(255,0,255,255)
	local hearts_x = 24
	local panel_y = 0
	local panel_x = 32

	function createTChicaPlayerBar(ply)
		if !ply then return end
		
		if panels[ply:UserID()] then return end
		
		local nickname = ply:Nick()

		local panel = vgui.Create("DFrame")
		panel:SetSize(220, 58)
		panel:SetTitle("")
		panel:ShowCloseButton(false)
		panel:SetDraggable(false)
		panel:Center()
		panel:SetPos(panel_x, panel:GetY() - panel_y)
		
		panel.Paint = function(self, w, h)
			myself = myself or LocalPlayer()
			local hold_target = myself:GetNWEntity("tchica_hold_target", nil)
			
			local alpha = (hold_target and hold_target == ply or !IsValid(hold_target)) and 255 or 140
			local color = colorWhite:Copy()
			color.a = alpha
			local colorP = colorPink:Copy()
			colorP.a = alpha
			
			surface.SetDrawColor(color)
			surface.SetMaterial(bg)
			surface.DrawTexturedRect(0, 0, w, h)
			
			surface.SetDrawColor(color)
			surface.SetMaterial(avatar_frame)
			surface.DrawTexturedRect(13, 7, 44, 44)
				
			draw.SimpleText(
				nickname,
				"tchica_victim_nick",
				71,
				7,
				color,
				TEXT_ALIGN_LEFT,
				TEXT_ALIGN_TOP
			)
			
			if IsValid(ply) then
				local ply_tier = ply:GetNW2Int("_ObsessorTier")
				local ply_value = ply:GetNW2Int("_ObsessorValue")
				local usedMid = false

				for i = 0, 2 do
					local mate

					if i < ply_tier then
						mate = heart_full
					elseif not usedMid and toychica_GetTargetValueByTier(ply_tier + 1) >= ply_value and toychica_GetTargetValueByTier(ply_tier) < ply_value - 10 then
						mate = heart_mid
						usedMid = true
					else
						mate = heart_low
					end

					surface.SetDrawColor(color)
					surface.SetMaterial(mate)
					surface.DrawTexturedRect(71 + i * 24, 35, 18, 16)
				end
			end
		end

		local avatar = vgui.Create( "AvatarImage", panel )
		avatar:SetSize( 44, 44 )
		avatar:SetPos( 13, 7 )
		avatar:SetPlayer( ply, 44 )
		
		avatar.PaintOver = function(self, w, h)
			surface.SetDrawColor(colorWhite)
			surface.SetMaterial(avatar_frame)
			surface.DrawTexturedRect(0, 0, w, h)
		end
		
		panels[ply:UserID()] = panel
		
		panel_y = panel_y + 70
	end
	
	function removeTChicaPlayerBar(index)
		local panel = panels[index]
		
		if panel then
			panel:Remove()
		end
		
		panels[index] = nil
		panel_y = 0
		
		if !table.IsEmpty(panels) then
			for _, p in pairs(panels) do
				p:Center()
				p:SetPos(panel_x, p:GetY() - panel_y)
		
				panel_y = panel_y + 70
			end
		end
	end
	
	function removeTChicaALLBARS()
		if !table.IsEmpty(panels) then
			for _, p in pairs(panels) do
				p:Remove()
		
				panel_y = 0
			end
		
			table.Empty(panels)
		end
	end
	
	net.Receive("remove_tchica_bar", function()
		local index = net.ReadInt(12)
		removeTChicaPlayerBar(index)
	end)
	
	local chicasObsoses = {}

	hook.Add("EntityNetworkedVarChanged","toychica_obsessor", function(ply, name, old, new)
		if !IsValid(myself) and IsValid(LocalPlayer()) then
			myself = myself or LocalPlayer()
		end
		if IsValid(myself) and ply:IsPlayer() then
			if name == "_ObsessorTier" then
				local ent = pills.getMappedEnt(myself)
				if IsValid(ent) then 
					if ent:GetPillName() == "pill_toychica" then
						if new > 0 then
							createTChicaPlayerBar(ply)
						else
							removeTChicaPlayerBar(ply:UserID())
						end
					else
						if new >= 3 then
							chicasObsoses[ply] = true
						else
							chicasObsoses[ply] = nil
						end
					end
				end
			end
		end
	end)
	
	hook.Add( "PreDrawHalos", "fh_toychica_obsos_helper", function()
		myself = myself or LocalPlayer()
		for ply, _ in pairs(chicasObsoses) do
			if myself:IsAnimatronic() and IsValid(ply) and ply:Health() > 0 and not ply:IsInvisible() then
				local pos = ply:GetPos()
				if pos:ToScreen().visible then
					local distance = myself:GetPos():Distance(pos)
					
					if distance < 800 then
						local blur = distance / 100
						
						halo.Add({ply}, colorPink, blur, blur, 1, true)
					end
				end
			end
		end
	end)

	hook.Add("PillApply", "toychica_removeobs", function(ply, ent)
		if ply == LocalPlayer() then
			removeTChicaALLBARS()
		end
	end)
end