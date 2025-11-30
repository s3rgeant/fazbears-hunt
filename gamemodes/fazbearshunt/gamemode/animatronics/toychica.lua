AddCSLuaFile()

pills.packStart("FH TOY CHICA", "FH TOY CHICA", "icon16/pill.png")

local tchica_default_movement = {220, 475, 220, 250} -- обычное передвижение
local tchica_hold_movement = {65, 475, 65, 250} -- сталкер дохуя

pills.register("pill_toychica",{
	printName="Toy Chica",
	model="models/ufmp/fnaf2/toys/toychica.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			
			jump="jump",
			land="land",
			glide="glide",
			
			hold="hold",
			holdwalk="holdwalk",
		},
	},
	moveSpeed={
		walk=220,
		run=475,
		ducked=220,
	},
	modelScale="1.3",
	bodyGroups={["Cupcake"] = 1},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 80),
		dist = 150
    },
	hull=Vector(32,32,78),
	duckBy=60,
	bloodType=BLOOD_COLOR_MECH,
	
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
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "tchica", 52, "v_endo")
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
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

local chicaHolders = {}
local chicasHoldings = {}

function holdPlayer(ply, ent, target)
	if not IsValid(ply) or not IsValid(target) then return end
	if chicaHolders[ply] == target then return end

	chicaHolders[ply] = target
	chicasHoldings[target] = ply
	
	ply:SetNWBool("tchica_holding", true)
	ent:ReplaceAnimation("idle", "hold")
	ent:ReplaceAnimation("walk", "holdwalk")
	ent:SetSpeed(unpack(tchica_hold_movement))
	ent:SetUseForceAngles(true)
	
	target:SetMoveType(MOVETYPE_NONE)
	target:SetNWBool("tchica_victim", true)
	
	target:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	
	timer.Remove("fh_repeat_unstuck" .. target:EntIndex())
end

function releasePlayer(ply)
	local target = chicaHolders[ply]
	local ent = ply:GetPill()
	
	if IsValid(ent) and ent.formTable and ent.formTable.name == "pill_toychica" then
		ent:ReplaceAnimation("idle", "idle")
		ent:ReplaceAnimation("walk", "walk")
		ent:SetSpeed(unpack(tchica_default_movement))
		ent:SetUseForceAngles(false)
	end
	
	if IsValid(target) then
		chicasHoldings[target] = nil
		target:SetMoveType(MOVETYPE_WALK)
		
		target:RepeatRestoreCollision(0.25)
		
		target:SetNWBool("tchica_victim", false)
		
		timer.Simple(0, function()
			if target:IsStuck() then
				target:SetPos(ply:GetPos())
			end
		end)
	end
	
	ply:SetNWBool("tchica_holding", nil)
	chicaHolders[ply] = nil
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
		filter = { holder, ply }
	})
	
	local finalPos = desiredPos
	if trace.Hit then
		finalPos = trace.HitPos - forward * 5
		finalPos.z = startPos.z
	end
	
	mv:SetOrigin(finalPos)
	
	local ang = (holder:GetPos() - finalPos):Angle()
	ang.p = 0
	ply:SetEyeAngles(ang)
	
	if IsValid(ent) then
		local ang2 = (finalPos - holder:GetPos()):Angle()
		ang2.p = 0
		ent:SetForceAngles(ang2)
	end
end)

hook.Add("StartCommand", "tchica_holder_tick", function(ply, cmd)
    if ply:GetNWBool("tchica_holding") or ply:GetNWBool("tchica_victim") then
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_SPEED)
		cmd:RemoveKey(IN_WALK)
		cmd:RemoveKey(IN_DUCK)
	end
end)

hook.Add( "OnPlayerPhysicsPickup", "tchica_pickup", function( ply, ent )
    if ply:GetNWBool("tchica_holding") or ply:GetNWBool("tchica_victim") then 
		ply:DropObject()
	end
end )

if CLIENT then
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
end