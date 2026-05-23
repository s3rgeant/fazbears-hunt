AddCSLuaFile()

endo = endo or {}

local playersHoldingRightClick = {}
local grabbedPlayers = {}
resource.AddFile("sound/grab_player.wav")
resource.AddFile("sound/throw_player.wav")

if SERVER then
	util.PrecacheModel("models/mountroid/thudner/hw withered pack/endo02.mdl")
end

local endo_default_movement = {120, 485, 160, 250} -- обычное передвижение
local endo_stalk_movement = {120, 600, 75, 260} -- сталкер дохуя

local function endoRageChanges(ply, ent, target)
	ent:SetSpeed(unpack(endo_stalk_movement))
end

local function norageChanges(ply, ent, target)
	if IsValid(ent) then
		ent:SetSpeed(unpack(endo_default_movement))
	end
end

pills.register("pill_endo02",{
	printName="Endo02",
	model="models/mountroid/thudner/hw withered pack/endo02.mdl",
	type="ply",
	health=10000,
		
	options=function() return {
		["default"] = {
			bodyGroups = { ["Ears"] = 1 },
			skin = 1,
		},
		["halloween"] = {
			bodyGroups = { ["Ears"] = 1, ["Eyes"] = 4 },
			skin = 1,
		},
		["christmas"] = {
			bodyGroups = { ["Ears"] = 1 },
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
		melee="fnaf2/xscream2.wav",
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
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "endo")
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "endo", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if cooldown.Exists(ply, 'grab') then return end
			endo.grabNeareastPlayer(ply,ent)
		end
	},
	
	land=function(ply,ent)
		if ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
		
		landTripCheck(ply, ent, "endo")
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,

	onRemove=function(ent,formTable,ply)
		endo.releasePlayer(ply)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

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
		
		if ent.formTable.name == "pill_endo02" then
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
	
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
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
		ply:RepeatRestoreCollision(0.5)
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

local endoAbilities = {}
function endo.registerAbility(abilityName, killer, func, startFunc)
    assert(abilityName, "[endo] Ability name is required")
    assert(killer, "[endo] Killer name is required")
    assert(func, "[endo] Ability function is required")
	
	endoAbilities[abilityName] = {
		killer = killer,
		func = func,
		startFunc = startFunc,
	}
end
	
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
]]--
--[[
]]--
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
--[[ ]]--

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