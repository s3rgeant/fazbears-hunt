AddCSLuaFile()

resource.AddFile("sound/grab_player.wav")
resource.AddFile("sound/throw_player.wav")

if SERVER then
	util.AddNetworkString("fh_endo_AbilitySelected")
end

endo = endo or {}

local ENDO_PILL = "pill_endo02"

local endoAbilities = {
	["pretense"] = {
		killer = ENDO_PILL,
		
		attack = function(ply,ent)
			if cooldown.Exists(ply, "kill") then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end,
		
		attack2 = nil,
		
		reload = function(ply,ent)
			highlight.ByDistance(ply, ent)
		end,
		
		startFunc = nil,
	}
}

function endo.GetAbilities()
	return endoAbilities
end

function endo.GetSortedAbilities()
	local tab = {}
	for name, data in pairs(endoAbilities) do
		local nData = table.Copy(data)
		nData.ability = name
		tab[#tab + 1] = nData
	end
	return tab
end

function endo.RegisterAbility(abilityName, killer, attack, attack2, reload, startFunc, endFunc)
    assert(abilityName, "[endo] Ability name is required")
    assert(killer, "[endo] Killer name is required")
	
	endoAbilities[abilityName] = {
		killer = killer,
		attack = attack,
		attack2 = attack2,
		reload = reload,
		startFunc = startFunc,
		endFunc = endFunc,
	}
end

local customAnimations = {}
function endo.RegisterAnimations(abilityName, killer, anims)
	local endoData = pills.getPillTable(ENDO_PILL)
	
	for anim, aanim in pairs(anims) do
		customAnimations[anim] = aanim
	end
end

local function endoStopAbility(ply, ent, curAbility)
	local curData = endoAbilities[curAbility]
	
	if curAbility ~= "pretense" then net.Start("fh_AbilitiesRemove") net.WriteString(curAbility) net.Send(ply) end
	
	if curData then
		local endFunc = curData.endFunc
		if endFunc then endFunc(ply, ent) end
	end
end

local function endoPretenseBackTimer(ply, ent, dur)
	local tName = "FH_EndoPretenseBackup" .. ent:EntIndex()
	timer.Create(tName, dur, 1, function()
		if not IsValid(ply) then timer.Remove(tName) return end
		if not IsValid(ent) then timer.Remove(tName) return end
		
		endo.ApplyAbility(ply, ent, "pretense")
	end)
	cooldown.SetSend(ply, "pretense", dur)
end

function endo.ApplyAbility(ply, ent, ability, duration)
	local data = endoAbilities[ability]
	if !data then return end -- Не существует способности

	local pillData = ent.formTable
	if !pillData then return end

	local curAbility = pillData.currentAbility
	
	if curAbility then
		ent:SetNW2String("ENDO_LastAbility", curAbility)
		endoStopAbility(ply, ent, curAbility)
	end
	
	if ability ~= "pretense" then 
		net.Start("fh_AbilitiesAdd") net.WriteString(ability) net.WriteString(data.killer) net.WriteBit(false) net.Send(ply)
	end
	
	local attack = data.attack
	local attack2 = data.attack2
	local reload = data.reload
	
	if data.attack then
		pillData.attack={
			mode="trigger",
			func=function(ply,ent)
				data.attack(ply, ent)
			end
		}
	else
		pillData.attack=nil
	end
	
	if data.attack2 then
		pillData.attack2={
			mode="trigger",
			func=function(ply,ent)
				data.attack2(ply, ent)
			end
		}
	else
		pillData.attack2=nil
	end
	
	pillData.currentAbility = ability
	ent:SetNW2String("ENDO_CurrentAbility", ability)
	
	local startFunc = data.startFunc
	if startFunc then startFunc(ply, ent) end
	
	if duration and duration > 0 then
		endoPretenseBackTimer(ply, ent, duration)
	end
end

net.Receive("fh_endo_AbilitySelected", function(len, ply)
	local ent = ply:GetPillCostume()
	if not IsValid(ent) then return end
	
	local name = ent:GetPillName()
	if name ~= ENDO_PILL then
		MsgC( Color( 255, 0, 0 ), "Suspicous net message received from " .. ply:Nick() .. " (fh_endo_AbilitySelected)", "\n" ) 
		return -- на всякий лол
	end
	
	local ability = net.ReadString()
	if not endoAbilities[ability] then 
		MsgC( Color( 255, 0, 0 ), "Bad ability name received from " .. ply:Nick() .. " (fh_endo_AbilitySelected, " .. ability .. ")", "\n" ) 
		return 
	end
	
	local abilitierName = net.ReadString()
	if abilitierName:len() <= 0 then 
		MsgC( Color( 255, 0, 0 ), "Invalid animatronic name received from " .. ply:Nick() .. " (fh_endo_AbilitySelected, " .. ability .. ")", "\n" ) 
		return 
	end
	
	if ent.formTable.currentAbility == ability then return end
	
	if ent:GetNW2String("ENDO_CurrentAbility", "") == ability then return end
	if ent:GetNW2String("ENDO_LastAbility", "") == ability and ability ~= "pretense" then return end
	
	for _, pill in ipairs( ents.FindByClass("pill_costume") ) do -- я еблан или нет? оцените пожалуйста
		if pill:GetPillName() == abilitierName then
			MsgC( Color( 255, 0, 0 ), "Endo tried pretense as an teammate - " .. ply:Nick() .. " (fh_endo_AbilitySelected, " .. ability .. " - " .. abilitierName .. ")", "\n" ) 
			return 
		end
	end
	
	endo.ApplyAbility(ply, ent, ability, 90)
end)

if SERVER then
	util.PrecacheModel("models/fh/animatronics/thudner_mountroid/endo02.mdl")
end

local endo_default_movement = {120, 485, 160, 250} -- обычное передвижение
local endo_stalk_movement = {120, 600, 75, 260} -- сталкер дохуя

pills.register(ENDO_PILL, {
	printName="Endo02",
	currentAbility = "pretense",
	model="models/fh/animatronics/thudner_mountroid/endo02.mdl",
	type="ply",
	health=10000,
		
	options=function() return {
		["default"] = {
			skin = 1,
		},
		["halloween"] = {
			bodyGroups = { ["Eyes"] = 4 },
			skin = 1,
		},
		["christmas"] = {
			skin = 1,
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
			jump="jump",
			glide="glide",
			land="land",
			scare="scare",
			stun="stun",
		},
		gestures={
			melee="attack",
			
			jammerstun="jammerstun",
			
			damaged1="damaged1",
			damaged2="damaged2",
			damaged3="damaged3",
			
			equip_rightarm="g_equip_rightarm",
		},
	},
	
	moveSpeed={
		walk=120,
		run=485,
		ducked=160,
	},
    jumpPower=250,
	duckBy=66,
	
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee=")fnaf2/xscream2.wav",
	},
    camera = {
        offset = Vector(0, 0, 96),
		dist = 150
    },
	hull=Vector(32,32,86),
	bloodType=BLOOD_COLOR_MECH,
	
	viewmodel={
		weapon="v_endo"
	},
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	talk = {
		jawbone="bip_lowerEndoJaw",
		reversed=false,
		scale=1.5,
	},
	
	muteSteps = true,

	noFallDamage=true,
	
	initialize=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "endo")
		
		if not table.IsEmpty(customAnimations) then
			local anims = ent:Get("anims")
			
			for anim, aanim in pairs(customAnimations) do
				anims.default[anim] = aanim
			end
		end
		
		ent:SetNW2String("ENDO_CurrentAbility", "pretense")
	end,
	
	restore=function(ply, ent)
		cooldown.Set(ply, "pretense", 1)
		if SERVER then
			ply:SprintEnable()
		end
	end,
	
	--[[die=function(ply, ent)
		ragdoll = ents.Create("prop_ragdoll")
		
		ragdoll:SetPos(ply:GetPos())
		ragdoll:SetAngles(ply:GetAngles())
		ragdoll:SetModel(ent:GetModel())
		ragdoll:Spawn()
	
		for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
			local bone = ragdoll:GetPhysicsObjectNum(i)
			
			if bone and bone:IsValid() then
				local bonepos, boneang = ent:GetBonePosition(ragdoll:TranslatePhysBoneToBone(i))
				
				bone:SetPos(bonepos)
				bone:SetAngles(boneang)
				bone:SetVelocity(ent:GetVelocity())
			end
		end
	end,--]]
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func = endoAbilities["pretense"].attack
    },
	
	attack2_sh={
		mode="trigger",
		func = function(ply,ent)
			if CLIENT then
				if cooldown.Exists(ply, "pretense") then return end
				
				if ent:GetNW2String("ENDO_CurrentAbility") ~= "pretense" then return end
				
				if not endo.IsPretenseUIOpen() then
					endo.PretenseOpenUI()
				end
			end
		end
	},
	
	land=function(ply,ent)
		if AreLandConditionsGood(ply, ent) then
			if ent:Func("landCondition", ply, ent) ~= false then 
				ent:PillAnim("land",true)
			end
		end
		
		landTripCheck(ply, ent, "endo")
	end,

	reload = endoAbilities["pretense"].reload,

	onRemove=function(ply, ent)
		endo.releasePlayer(ply)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,
	
	killerAxeAttacker = function(ply, ent, k_axer, tr)
		if ply._endoHoldingPlayer == k_axer then
			endo.releasePlayer(ply, true)

			cooldown.Set(ply, 'grab', 6)
			cooldown.Send(ply, "grab")
		end
	end,
})

local playersHoldingRightClick = {}
local grabbedPlayers = {}

local grabbed_stat = {}

function endo.grabNeareastPlayer(ply, ent)
    local target = FindNearestPlayer(ply:EyePos(), 125, ply, 50)
	
	if !grabbed_stat[ply] then
		grabbed_stat[ply] = {}
	end

    if IsValid(target) and (target:IsPlayer() and !target:IsFrozen() or target:IsNPC()) then
		if hook.Run("FH_HandlePlayerGrab", ply, target) == false then return end
		
		if !grabbed_stat[ply][target] then
			grabbed_stat[ply][target] = true
			stats.Add(ply, "grabbed", 1)
		end
		
		ply:EmitSound("grab_player.wav")
		
		if ent:GetPillName() == "pill_endo02" then
			if math.random(1,10) > 2 then
				playVoiceline("endo", 'grab', ply, 0.2)
			end
		end
		timer.Remove("fh_repeat_unstuck" .. target:EntIndex())
		
        target:SetMoveType(MOVETYPE_NONE)
        target:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		
		target:SetNWEntity("MyEndoGrabber", ply)

        grabbedPlayers[target] = true

        playersHoldingRightClick[ply] = target
		ply._endoHoldingPlayer = target
		ply:StopZooming()
		ply:SetCanZoom(false)

        timer.Create("UpdateCameraAndPosition" .. ply:EntIndex(), 0.01, 0, function()
			if !IsValid(ply) or !ply:KeyDown(IN_ATTACK2) then
				timer.Remove("UpdateCameraAndPosition" .. ply:EntIndex())
				return
			end
		
			if IsValid(target) then
				local eyePos = ply:EyePos()
				target:SetEyeAngles((eyePos - target:EyePos()):Angle())
				
				local vectorOffset = 50
				
				if ply:Crouching() then vectorOffset = 5 end
		
				local offset = (ply:EyeAngles():Forward() * 50)
				local newPos = ((ply:GetPos() + ply:EyePos()) / 2) + offset
		
				local traceData = {}
				traceData.start = ply:EyePos()
				traceData.endpos = newPos
				traceData.filter = {ply, target}
		
				local trace = util.TraceEntity(traceData, target)
		
				if trace.Hit then
					local safeDistance = trace.Fraction * 50
					offset = (Vector(0, 0, vectorOffset)) + (ply:EyeAngles():Forward() * safeDistance)
					newPos = ply:GetPos() + offset
				end
				debugoverlay.Line(traceData.start, traceData.endpos, 0.05, Color(255, 0, 0), true)
				--debugoverlay.Box( newPos, traceData.mins, traceData.maxs, 0.05, Color( 255, 255, 255, 20 ) )
		
				target:SetPos(newPos)
			end
		end)
    end
end

if SERVER then
	hook.Add("KeyRelease", "endo_key_release", function(ply, key)
		if key == IN_ATTACK2 then
			ply:LagCompensation(true)
			endo.releasePlayer(ply)
			ply:LagCompensation(false)
		end
	end)
end

function endo.releaseExactPlayer(target)
	local grabber = target:GetNWEntity("MyEndoGrabber")
	if IsValid(grabber) then
		endo.releasePlayer(grabber, true)
	end
end

function endo.releasePlayer(ply, noVoiceline)
	noVoiceline = noVoiceline or false
	local target = playersHoldingRightClick[ply]
	if IsValid(target) then
		if ply:Alive() then
			ply:EmitSound("throw_player.wav")
		end
		if !noVoiceline then
			if math.random(1,10) > 2 then
				playVoiceline("endo", 'throw', ply, 0.1)
			end
		end
	
		target:SetMoveType(MOVETYPE_WALK)
		target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
		grabbedPlayers[target] = nil
		
		target._GrabbedByEndoTime = CurTime()
		target._LastEndo = ply
		
		target:SetNWEntity("MyEndoGrabber", NULL)
		
		local plyPos = ply:GetPos()
		local plyHeight = ply:OBBMaxs().z - ply:OBBMins().z
		local targetHeight = target:OBBMaxs().z - target:OBBMins().z
		local newPos = plyPos + Vector(0, 0, plyHeight - targetHeight)

		local traceData = {}
		traceData.start = target:GetPos()
		traceData.endpos = target:GetPos()
		traceData.filter = {ply, target}

		local trace = util.TraceEntity(traceData, target)

		if trace.Hit then
			target:SetPos(newPos)
		end
	
		local direction = (ply:EyeAngles():Forward() * 50):GetNormalized()
		target:SetVelocity(direction * 800)
	
		ply:NoPlayerCollide(1)
		target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		
		hook.Run("fh_endo_release", ply, target)
		
		timer.Simple(1, function()
			if IsValid(target) then
				if target:IsStuck() then
					target:Unstuck()
				end
			end
		end)
	
		cooldown.Set(ply, 'grab', 3)
		cooldown.Send(ply, "grab")
		ply:SetCanZoom(true)
	
		target:RepeatRestoreCollision(0.5)
	end
	
	playersHoldingRightClick[ply] = nil
	ply._endoHoldingPlayer = nil
	timer.Remove("UpdateCameraAndPosition" .. ply:EntIndex())
end

function endo.isGrabbed(target)
	return grabbedPlayers[target]
end

local function grabbies(ply)
	if endo.isGrabbed(ply) then
		endo.releaseExactPlayer(ply)
	end
end

hook.Add("PlayerSpawn", "endo_release", grabbies)
hook.Add("PlayerDisconnected", "endo_release", grabbies)
hook.Add("PostPlayerDeath", "endo_release", grabbies)
hook.Add("PillApply", "endo_release", grabbies)
	
hook.Add("PlayerNoClip", "endo_targets_noclip_handle", function(ply, desiredState)
	if grabbedPlayers[ply] then
		return false
	end
end)

hook.Add( "PostCleanupMap", "fh_endo_reset", function()
	table.Empty(grabbed_stat)
end)

--[[
	OLD Endo Pickup Stuff :)))

hook.Add("OnPlayerPhysicsDrop", "fh_endo_prop_drop", function(ply, ent, thrown)
	local puppet = pills.getMappedEnt(ply)
	if !IsValid(puppet) then return end
	name = puppet.formTable.name
	
	if name ~= "pill_endo02" then return end
	
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then 
		if thrown then
			local dir = ply:GetAimVector()
			phys:ApplyForceCenter(dir * 20000 * math.min(70, phys:GetMass()))
		else
			ent._lastHoldTime = CurTime()
		end
	end
		
	--ent:SetCollisionGroup(COLLISION_GROUP_NONE)
	ply:SetNW2Entity("HeldEnt", NULL)
end)

hook.Add("PlayerUse", "fh_endo_largeprop_pickup", function(ply, ent)
	local puppet = ply:GetPill()
	if not IsValid(puppet) or puppet.formTable.name ~= "pill_endo02" then return end
	if not IsValid(ent) then return end

	if ent._lastHoldTime and CurTime() < ent._lastHoldTime + 0.5 then return end

	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return end

	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return end
	if not phys:IsMoveable() then return end
	if ent:IsPlayerHolding() then return end
	if ent:GetParent():IsValid() then return end
	if constraint.HasConstraints(ent) then return end

	local mass = phys:GetMass()
	if mass < 35 or mass > 800 then return end

	phys:EnableMotion(true)
	phys:Wake()
	phys:ApplyForceCenter(VectorRand() * 5)

	timer.Simple(0, function()
		if IsValid(ply) and IsValid(ent) and not ent:IsPlayerHolding() then
			ply:PickupObject(ent)
		end
	end)
end)

hook.Add("OnPlayerPhysicsPickup", "fh_endo_pickup", function(ply, ent)
	local puppet = ply:GetPill()
	if not IsValid(puppet) or puppet.formTable.name ~= "pill_endo02" then return end
	local phys = ent:GetPhysicsObject()
	if !IsValid(phys) then return end
	ply:SetNW2Entity("HeldEnt", ent)
	
	--ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
end)

if CLIENT then
	local lastHeld

	hook.Add("PreDrawEffects", "fh_endo_translucent_heldprop", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local heldEnt = ply:GetNW2Entity("HeldEnt")

		if lastHeld ~= heldEnt then
			if IsValid(lastHeld) then
				lastHeld.RenderOverride = nil
			end

			if IsValid(heldEnt) then
				heldEnt.RenderOverride = function(self)
					if heldEnt:GetRenderGroup() == 8 then
						render.OverrideColorWriteEnable( true, false )
						self:DrawModel()
						render.OverrideColorWriteEnable( false, false )
					end
					render.SetBlend(0.5)
					self:DrawModel()
					render.SetBlend(1)
				end
			end

			lastHeld = heldEnt
		end
	end)
end
]]--

local nullvector = Vector(0,0,0)
local endo_kills = 0
hook.Add( "PlayerDeath", "endo_myaso", function( victim, inflictor, attacker )
	if not IsValid(attacker) or not attacker:IsPlayer() then return end
	
	local ent = attacker:GetPill()
	if not IsValid(ent) or ent:GetPillName() ~= "pill_endo02" then return end
	
	if IsValid(inflictor) and inflictor ~= attacker and IsValid(inflictor:GetPhysicsObject()) then
		endo_kills=endo_kills+1
		timer.Simple(0.4, function()
			endo_kills=endo_kills-1
		end)
		
		if endo_kills == 2 then
			EmitSound( "sniper_railgun_double_kill.wav", nullvector, 0,nil,1,0 )
		end
	end
end)

local function endoRageChanges(ply, ent, target)
	ent:SetSpeed(unpack(endo_stalk_movement))
	ent:ReplaceAnimation("run", "ragerun")
end

local function norageChanges(ply, ent, target)
	if IsValid(ent) then
		ent:SetSpeed(unpack(endo_default_movement))
		ent:ReplaceAnimation("run", "run")
	end
end

hook.Add("FH_AnimatronicsLoaded", "endo02_abilities", function()

	-- FREDDY: Blind Rage
	endo.RegisterAbility("blindrage", "pill_wfreddy2", 
	
		-- attack
		function(ply, ent)
			if cooldown.Exists(ply, "kill") then return end
			if IsValid(ply:GetEntityInUse()) then return end
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end, 
		
		-- attack2
		function(ply, ent)
			if !ply:OnGround() then return end
		
			startBlindRage(ply, ent, endoRageChanges, norageChanges)
		end, 
		
		-- reload
		function(ply, ent)
			if !freddy.GetBlindRageTarget(ply) then
				highlight.ByDistance(ply, ent)
			end
		end, 
		
		-- startFunc
		function(ply, ent)
		
			ent:PillGesture("equip_rightarm", 3, 1, .15, .3)

			ply:SprintDisable()
			
			ent:SetNWInt("RushTokens", FOXY_MAX_RUSH_TOKENS)

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep.HandleAnimation then
				wep:HandleAnimation("holster", 1.2)
			end
			
			timer.Simple(.6, function()
				if not IsValid(ent) then return end
				ent:SetBodygroup(13, 1)
				ply:SprintEnable()
			
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetBodygroup(2, 1)
				end
			end)
			
			ent.formTable.landCondition = function(ply, ent)
				if ent.anim == "stalk" then return false end -- нельзя приземляться во время сталка
			end
		end,
		
		-- endFunc
		function(ply, ent)
			ent.formTable.landCondition = nil
			ent:SetBodygroup(13, 0)
			
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				vm:SetBodygroup(2, 0)
			end
		end
	)
	
	endo.RegisterAnimations("blindrage", "pill_wfreddy2", {
		stalk = "stalk",
	})
	
	endo.RegisterAbility("mine", "pill_wchica2", 
	
		-- attack
		function(ply, ent)
			if cooldown.Exists(ply, "kill") then return end
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end, 
		
		-- attack2
		function(ply, ent)
			ChicaDeployCupcake(ply, ent)
		end, 
		
		-- reload
		function(ply, ent)
			highlight.ByDistance(ply, ent)
		end, 
		
		-- startFunc
		function(ply, ent)
		
			--ent:PillGesture("equip_rightarm", 3, 1, .15, .3)

			ply:SprintDisable()

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep.HandleAnimation then
				wep:HandleAnimation("holster", 1.2)
			end
			
			timer.Simple(.6, function()
				if not IsValid(ent) then return end
				ent:SetBodygroup(16, 1)
				ply:SprintEnable()
			end)
		end,
		
		-- endFunc
		function(ply, ent)
			ent.formTable.landCondition = nil
			ent:SetBodygroup(16, 0)
		end
	)
	
	endo.RegisterAbility("yoursmine", "pill_wbonnie2", 
	
		-- attack
		function(ply, ent)
			if cooldown.Exists(ply, "kill") then return end
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_bonnie")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end, 
		
		-- attack2
		function() end, 
		
		-- reload
		function(ply, ent)
			highlight.ByDistance(ply, ent)
		end, 
		
		-- startFunc
		function(ply, ent)
		
			--ent:PillGesture("equip_rightarm", 3, 1, .15, .3)
			
			local bwep = ents.Create("v_bonnie")
			bwep.ViewModel = "models/fh/animatronics/thudner_mountroid/vm/endo02.mdl"
			bwep:Spawn()
			
			ply:SetSuppressPickupNotices(true)
			ply:PickupWeapon(bwep)
			ply:SelectWeapon("v_bonnie")
			ply:SetSuppressPickupNotices(false)

			ply:SprintDisable()

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep.HandleAnimation then
				wep:HandleAnimation("holster", 1.2)
			end
			
			timer.Simple(.6, function()
				if not IsValid(ent) then return end
				ent:SetBodygroup(15, 1)
				ply:SprintEnable()
			end)
		end,
		
		-- endFunc
		function(ply, ent)
			ent.formTable.landCondition = nil
			ent:SetBodygroup(15, 0)
			
			if ply:HasWeapon("v_endo") then
				ply:SelectWeapon("v_endo")
			end
			ply:StripWeapon("v_bonnie")
		end
	)
	
	endo.RegisterAnimations("yoursmine", "pill_wbonnie2", {
		yoursmine = "yoursmine",
	})
	
	endo.RegisterAbility("submerge", "pill_sfreddy2", 
	
		-- attack
		function(ply, ent)
			if ent.cloaked or cooldown.Exists(ply, 'kill') then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 130, ply, 36)
			
			local jumpscare
			
			--if ply._SF_TouchedFloor_Uncloaked then
				jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			--end
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end, 
		
		-- attack2
		function(...)
			ShadowFreddySubmerge_Toggle(...)
		end, 
		
		-- reload
		function(...)
			highlight.ByDistance(...)
		end, 
		
		-- startFunc
		function(ply, ent)
		
			ent:PillGesture("equip_rightarm", 3, 1, .15, .3)

			ply:SprintDisable()

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep.HandleAnimation then
				wep:HandleAnimation("holster", 1.2)
			end
			
			timer.Simple(.6, function()
				if not IsValid(ent) then return end
				ent:SetBodygroup(18, 1)
				ply:SprintEnable()
			
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetBodygroup(4, 1)
				end
			end)
		end,
		
		-- endFunc
		function(ply, ent)
			ent.formTable.landCondition = nil
			ent:SetBodygroup(18, 0)
			
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				vm:SetBodygroup(4, 0)
			end
			
			if ent.cloaked then
				if ply:IsStuck() then
					ply:Unstuck()
				end
				if ply:IsStuck() then
					if not TeleportToNearestTeammate(ply) then
						ply:ReturnToSpawn()
						if ply:IsStuck() then
							ply:SetPos(ply:GetPos() + Vector(0,0,.01))
						end
						
						if ply:IsStuck() then
							ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
							ply:NoPlayerCollide(0.25)

							local wep = ply:GetActiveWeapon()
							if IsValid(wep) and wep.HandleAnimation then
								wep:HandleAnimation("draw", 0.5)
							end
							
							ply:DrawViewModel(true)
							ply:SetPushBlocked(false)
							ply:EmitSound("sfreddyout.mp3")
							
							ent.cloaked=false
							ent:ToggleCloak()
	
							hook.Run("FH_SFreddySubmergeOut", ply, ent)
								
							timer.Remove("ext" .. ply:EntIndex())
									
							ply:SetMoveType( MOVETYPE_WALK )
							
							ent:SetMaterial()
							ent:DrawShadow(true)
							
							MsgC( Color( 255, 0, 0 ), "Endo somehow got stuck -" .. ply:Nick() .. " (Shadow Freddy Submerge, " .. game.GetMap() .. tostring(ply:GetPos()) ")", "\n" ) 
						end
					end
				end
				ShadowFreddySubmerge_Force(ply, ent)
			end
			ent:SetDefaultSpeed()
		end
	)
	
	endo.RegisterAnimations("yoursmine", "pill_sfreddy2", {
		uncloak="disappear",
		cloak="appear",
	})
	
	endo.RegisterAbility("charge", "pill_wfoxy2", 
	
		-- attack
		function(ply, ent)
			if cooldown.Exists(ply, "kill") then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			if ply:GetNWBool("isBlightRushing") or ply:GetNWBool("isBlightBouncing") or ply:GetNWBool("blightRushing") then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "foxy", 75, "v_foxy")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end, 
		
		-- attack2
		function(...) end, 
		
		-- reload
		function(...)
			highlight.ByDistance(...)
		end, 
		
		-- startFunc
		function(ply, ent)
			player_manager.SetPlayerClass(ply, "player_foxy")
			ply:SetFoxyTokens(FOXY_MAX_RUSH_TOKENS)
		
			ent:PillGesture("equip_rightarm", 3, 1, .15, .3)
			
			local fwep = ents.Create("v_foxy")
			fwep.ViewModel = "models/fh/animatronics/thudner_mountroid/vm/endo02.mdl"
			fwep:Spawn()
			
			ply:SetSuppressPickupNotices(true)
			ply:PickupWeapon(fwep)
			ply:SelectWeapon("v_foxy")
			ply:SetSuppressPickupNotices(false)

			ply:SprintDisable()

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep.HandleAnimation then
				wep:HandleAnimation("holster", 1.2)
			end
			
			timer.Simple(.6, function()
				if not IsValid(ent) then return end
				ent:SetBodygroup(14, 1)
				ent:SetBodygroup(5, 1)
				ply:SprintEnable()
			
				local vm = ply:GetViewModel()
				if IsValid(vm) then
					vm:SetBodygroup(1, 1)
					vm:SetBodygroup(3, 1)
				end
			end)
		end,
		
		-- endFunc
		function(ply, ent)
			player_manager.SetPlayerClass(ply, "player_fh")
			
			ent:SetBodygroup(14, 0)
			ent:SetBodygroup(5, 0)
			
			local vm = ply:GetViewModel()
			if IsValid(vm) then
				vm:SetBodygroup(1, 0)
				vm:SetBodygroup(3, 0)
			end
			
			if ply:HasWeapon("v_endo") then
				ply:SelectWeapon("v_endo")
			end
			ply:StripWeapon("v_foxy")
		end
	)
end)

if CLIENT then
	hook.Add("FH_HandleKillerTerrorLayers", "endo_sfreddy_handle", function(myself, killer, theme, layer, ent)
		if ent and ent:IsValid() and ent:GetNW2String("ENDO_CurrentAbility") == "submerge" then
			if killer:GetMoveType() == MOVETYPE_NOCLIP then
				return "first_layer"
			end
		end
	end)
end