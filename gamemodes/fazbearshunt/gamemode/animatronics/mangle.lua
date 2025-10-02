AddCSLuaFile()

pills.packStart("FH MANGLE", "FH MANGLE", "icon16/pill.png")

local man_speed = {
	[1] = {66, 475, 70, 250},
	[2] = {66, 485, 70, 252},
	[3] = {66, 495, 70, 254},
	[4] = {66, 505, 70, 256}
}

pills.register("pill_mangle",{
	printName="Mangle",
	model="models/ufmp/fnaf2/toys/themangle.mdl",
	bodyGroups={0},
	modelScale="1.3",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			jump="jump",
			glide="glide",
			scare="scare",
			hook_wall="hook_wall_start",
			hook_wall_loop="hook_wall",
			hook_ceiling="hook_ceiling",
			land="land",
			land_hard="land_hard",
		},
	},
	moveSpeed={
		walk=man_speed[1][1],
		run=man_speed[1][2],
		ducked=man_speed[1][3],
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee="fnaf2/xscream2.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 70),
		dist = 120
    },
	hull=Vector(32,32,76),
	duckBy=60,
	
	bloodType=BLOOD_COLOR_MECH,

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			if !IsValid(target) then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
			
			if ply:GetNWBool("_MangleHooked") or ply:GetNWBool("_MangleHookReady") then return end
			
			performJumpscare(ply, ent, target, 1.6, "mangle", 70)
		end
    },
	 
	attack2_sh={
		mode="trigger",
		func = function(ply,ent)
			local eyeAng = ply:EyeAngles()
		
			local velocityPower = 600
			local addVelocity = Vector(0,0,0)
			if !ply:GetNWBool("_MangleHooked") then
				if !ply:OnGround() or ply:Crouching() then return end
				if eyeAng.p > -10 then return end
			else
				velocityPower = 800
				if eyeAng.p > 40 then
					velocityPower = 1300
				end
			end
			
			if ply:GetNWBool("_MangleHookReady") then return end
			
			if SERVER then
				ent:SetUseForceAngles(false)
				ent.anim = nil
				
				ent:PillAnim("jump",false)
				ent:PillSound("jump",false)
				
				timer.Simple(2, function()
					if ply:IsStuck() then
						ply:Unstuck()
					end
				end)
			end
			
			ply:SetViewOffset(Vector(0,0,70))
			
			if eyeAng.p > -24 then
				addVelocity = Vector(0,0,200)
			end
			
			ply:SetVelocity( (ply:EyeAngles():Forward() * velocityPower) + addVelocity )
			
			ply:SetNWBool("_MangleHooked", false)
			ply:SetNWBool("_MangleHookReady", true)
			
			ply:SetMoveType(MOVETYPE_WALK)
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		
		local longerStun = ply:GetNWString("_MangleHookReady") and ply:GetNWString("_MangleLastHookType") == ""
		
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -180 then
			ent:PillAnim(!longerStun and "land" or "land_hard",true)
		end
	end,
	
	startFunction=function(ply,ent)
		local jiggle_balls = {"bip_pelvisWiresL", "bip_armWires1R", "bip_bodyEndoHandPart", "bip_tail", "bip_bottomHeadWires"}
		
		for k, v in pairs( jiggle_balls ) do
			local boneid = ent:LookupBone(v)
			
			if boneid then
				ent:ManipulateBoneJiggle(boneid, 1)
			end
		end
		
		--[[
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
			
			chaseCheck(ply, 'mangle')
		end)
		]]--
	end,

	noFallDamage=true,
	hideHud = true,

	noragdoll=true,
	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})

hook.Add("KeyPress", "mangle_unhook", function(ply, key)
	if ( key == IN_JUMP ) then
		if ply:IsAnimatronic() then 
			local ent = pills.getMappedEnt(ply)
		
			if IsValid(ent) then
				if ply:GetNWBool("_MangleHooked") then 
					ply:SetNWBool("_MangleHooked", false)
					ply:SetNWBool("_MangleHookReady", false)
					ply:SetMoveType(MOVETYPE_WALK)
					
					ply:SetViewOffset(Vector(0,0,70))
					
					ent:SetUseForceAngles(false)
					ent.anim = nil
					return
				end
			end
		end
	end
end)

local function tierDown(ply)
	if IsValid(ply) then
		local curTier = ply._MangleTier or 0
		
		if ply._MangleTier == 0 then return end
		
		ply._MangleTier = math.max(curTier - 1, 0)
		
		mangleChangeSpeed(ply, ply._MangleTier)
	end
end

local function mangleChangeSpeed(ply, tier)
	local ent = pills.getMappedEnt(ply)
	
	local desiredspeed = man_speed[tier + 1]
	
	if IsValid(ent) then
		ent:SetSpeed(unpack(desiredspeed))
		
		timer.Simple(180, function()
			if IsValid(ent) and IsValid(ply) then
				tierDown(ply)
			end
		end)
	end
end

local function tierUp(ply)
	if IsValid(ply) then
		local curTier = ply._MangleTier or 0
		
		if ply._MangleTier == 3 then return end
		
		ply._MangleTier = math.min(curTier + 1, 3)
		
		mangleChangeSpeed(ply, ply._MangleTier)
		
		ply:SendLua('surface.PlaySound("littlereward.wav")')
	end
end

local function MangleHookUpCheck(ply, mv)
	local velocity = ply:GetVelocity()

	local eyeDir = ply:EyeAngles():Forward()

	local speedDir = velocity:GetNormalized()

	local traceDist = 20
	
	local startPos = ply:EyePos()
	local endPos = startPos + (speedDir * traceDist) + (eyeDir * traceDist)
	
	local tr = util.TraceLine( {
		start = startPos,
		endpos = endPos,
		filter = ply
	} )
	tr.startPos = startPos
	tr.endPos = endPos
	
	--debugoverlay.Line( startPos, endPos )
	
	return tr
end

local function MangleKillCheck(ply, mv)
    local velocity = ply:GetVelocity()
    if velocity:Length() == 0 then return nil end

    local speedDir = velocity:GetNormalized()
    local traceDist = 200

    local startPos = ply:GetPos() + ply:OBBCenter()
    local endPos = startPos + speedDir * traceDist

    local trLine = util.TraceLine({
        start = startPos,
        endpos = endPos,
        filter = ply
    })

    debugoverlay.Line(startPos, endPos, 1, Color(255,0,0))

    if trLine.Hit then
        local mins = Vector(-20, -20, 0)
        local maxs = Vector(20, 20, 32)
        local len = 64
        local endPosition = startPos + speedDir * len

        local trHull = util.TraceHull({
            start = startPos,
            endpos = endPosition,
            mins = mins,
            maxs = maxs,
            filter = ply
        })

        debugoverlay.Box(endPosition, mins, maxs, 1, Color(0,255,0))

        return trHull
    end

    return nil
end

hook.Add("FinishMove", "mangle_hook_ready", function( ply, mv )

	if ply:GetNWBool("_MangleHookReady") then
		local hooktype = ply:GetNWString("_MangleLastHookType")
		if SERVER and hooktype == "ceiling" then
			if ply:GetGroundEntity():IsPlayer() and ply:GetGroundEntity():IsSurvivor() then
				local victim = ply:GetGroundEntity()
				victim:TakeDamage(100, ply)

				local edata = EffectData()
				edata:SetOrigin(victim:GetPos() + victim:GetCurrentViewOffset())
				edata:SetEntity(victim)
				util.Effect("BloodImpact", edata)
				
				victim:EmitSound("physics\body\body_medium_break3.wav")
				
				tierUp(ply)
			end
		end
	
		if ply:OnGround() then
			ply:SetNWBool("_MangleHookReady", false)
			ply:SetNWString("_MangleLastHookType", "")
			return
		end
		
		local tr = MangleHookUpCheck(ply, mv)
		
		if !tr.HitSky and tr.Hit and tr.Entity == game.GetWorld() and tr.HitNormal.z <= 0 then
			local ent = pills.getMappedEnt(ply)
			if SERVER then
				
				--print(tr.HitNormal.z)
				
				-- ЗАЦЕП НА СТЕНУ
				if tr.HitNormal.z >= -0.2 then
				
					local trace = { start = ply:GetPos(), endpos = ply:GetPos() + -tr.HitNormal * 50, filter = ply }
					local trr = util.TraceLine( trace, ply ) 
					if ( !trr.Hit or tr.Entity ~= game.GetWorld() ) then
					
						debugoverlay.Line( ply:GetPos(), ply:GetPos() + -tr.HitNormal * 50 )
						debugoverlay.Box( ply:GetPos() + -tr.HitNormal * 50, Vector(12,12,12), Vector(-12,-12,-12), 2, Color(255,0,0) )
						return
					end
					
					local newpos = tr.HitPos + -ply:GetViewOffset() + tr.HitNormal * 28
				
					local trace2 = { start = newpos, endpos = newpos, filter = ply }
					local trr2 = util.TraceEntity( trace2, ply ) 
					if ( trr2.Hit ) then
						return
					end
				
					ent:SetUseForceAngles(true)
					if IsValid(ent) then
						ent:PillAnim("hook_wall")
						ent.animLoop = true
					end
					
					ply:SetNWString("_MangleLastHookType", "wall")
					
					mv:SetOrigin( tr.HitPos + -ply:GetViewOffset() + tr.HitNormal * 28 )
					
				else -- ЗАЦЕП НА ПОТОЛОК
					if ply:GetNWString("_MangleLastHookType", "wall") == "ceiling" then
						return
					end
					if IsValid(ent) then
						ent:PillAnim("hook_ceiling")
						ent.animLoop = true
					end
					ply:SetNWString("_MangleLastHookType", "ceiling")
					
					local trace = { start = ply:GetPos(), endpos = ply:GetPos() + Vector(0,0,80), filter = ply }
					local trr = util.TraceEntity( trace, ply ) 
					if ( trr.Hit ) then
						mv:SetOrigin( trr.HitPos + trr.HitNormal * 4 )
					else
						mv:SetOrigin( tr.HitPos + -ply:GetViewOffset() + tr.HitNormal * 7 )
					end
				end
				
				ply:EmitSound("grab_player.wav")
				ply:SetNWBool("_MangleHookReady", false)
				
				ply:SetViewOffset(Vector(0,0,24))
				
				local forceangle = tr.HitNormal:Angle()
				forceangle.p = -forceangle.p
				
				ent:SetForceAngles(forceangle)
			
				ply:SetNWBool("_MangleHooked", true)
			end
			ply:SetMoveType(MOVETYPE_NONE)
			return
		end
		
		if SERVER and hooktype ~= "" then
			ply:LagCompensation(true)
			local tr = MangleKillCheck(ply, mv)
			
			if !tr then 
				ply:LagCompensation(false)
				return 
			end
		
			if tr.Entity and tr.Entity:IsPlayer() and tr.Entity:IsSurvivor() then
				local victim = tr.Entity
				
				victim:TakeDamage(hooktype == "ceiling" and 100 or 75, ply)

				local edata = EffectData()
				edata:SetOrigin(tr.HitPos)
				edata:SetEntity(victim)
				util.Effect("BloodImpact", edata)
				
				victim:EmitSound("physics\body\body_medium_break3.wav")
				
				tierUp(ply)
				
				ply:SetNWBool("_MangleHookReady", false)
				ply:SetNWString("_MangleLastHookType", "")
				
				ply:LagCompensation(false)
				return
			end
			ply:LagCompensation(false)
		end
	end
end)

hook.Add("SetupMove", "mangle_hooked", function(ply, mv, cmd)
	if ply:GetNWBool("_MangleHooked") then
		cmd:ClearMovement()
		mv:SetVelocity(Vector(0,0,0))
		return true
	end
end)

hook.Add("StartCommand", "mangle_hooked_command", function(ply, cmd)
	if ply:GetNWBool("_MangleHooked") then
		cmd:ClearMovement()
		cmd:RemoveKey( IN_DUCK )
		cmd:RemoveKey( IN_ATTACK )
	end
	
	if ply:GetNWBool("_MangleHookReady") then
		cmd:RemoveKey( IN_DUCK )
		cmd:RemoveKey( IN_ATTACK )
		cmd:AddKey( IN_SPEED )
	end
end)

local lastmangle_CL_viewoffset = nil
local frametime_add = 1
local fov_plus = 0

hook.Add( "CalcView", "mangle_caclview", function( ply, pos, angles, fov )

	local ent = pills.getMappedEnt(ply)
	
	if IsValid(ent) and ent.formTable.name == "pill_mangle" then	
		if !lastmangle_CL_viewoffset then
			lastmangle_CL_viewoffset = ply:GetCurrentViewOffset()
		end
		
		local plypos = ply:GetPos()
		
		frametime_add = math.Clamp(frametime_add, 0, 1)
		
		lastmangle_CL_viewoffset = LerpVector(FrameTime() * 10, lastmangle_CL_viewoffset, ply:GetCurrentViewOffset())
		
		if ply:GetNWBool("_MangleHookReady") then
			fov_plus = Lerp(FrameTime() * 10, fov_plus, math.Clamp(math.abs(ply:GetVelocity().z) / 20, 0, 30))
		else
			fov_plus = Lerp(FrameTime() * 10, fov_plus, 0)
		end
		--lastmangle_CL_viewoffset.y = pos.y
		--lastmangle_CL_viewoffset.x = pos.x

		local view = {
			origin = plypos + lastmangle_CL_viewoffset,
			angles = angles,
			fov = fov + fov_plus
		}

		return view
	end
end )

hook.Add("PlayerDeath", "mangle_deathhook", function(ply)

	ply:SetNWBool("_MangleHooked", false)
	ply:SetNWBool("_MangleHookReady", false)
	ply:SetNWString("_MangleLastHookType", "")
end)

hook.Add("PlayerSpawn", "mangle_spawnhook", function(ply)

	ply:SetNWBool("_MangleHooked", false)
	ply:SetNWBool("_MangleHookReady", false)
	ply:SetNWString("_MangleLastHookType", "")
end)