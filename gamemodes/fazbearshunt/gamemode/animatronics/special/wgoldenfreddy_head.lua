AddCSLuaFile()

sound.Add({
	name = 			"gfreddy_head.ram",
	channel = 		CHAN_AUTO,
	level = 		80,
	volume = 		1,
	sound = 			{")fnaf2/gfreddy/head_ram_loop.wav"}
})

local MAX_SPEED = 800
local ACCEL_TIME = 25
local DECEL_TIME = 2.5
local SIDE_MULT = 0.35

local GFreddy_Speeds = {}

-- GFREDDY HEAD

pills.register("fh_wgfreddyhead",{
	printName="Withered Golden Freddy Head",
	model="models/fh/animatronics/UFMP/FNAF2/WGFreddyHead.mdl",
	
	modelScale="4",
	--bodyGroups={[0] = 1},
	
	anims={
		default={
			idle="idle",
			walk="fly",
			glide="fly",
		},
		gestures={
			jump="jump"
		},
	},
	
	moveSpeed={
		walk=140,
		--run=1000,
		--ducked=0,
	},
	sounds={
		scream="fnaf2/bonniescream.wav",
		melee=")fnaf2/xscream2.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 80),
		dist = 150
    },
	bloodType=BLOOD_COLOR_MECH,
	hull=Vector(32,32,86),
	duckBy=60,
	
	muteSteps = true,
	noFallDamage=true,
	
    jumpPower=300,
	--health=0,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch",
	},
	
	initialize=function(ply,ent)
		ent:SetFlexWeight( 0, 1 )
	end,
	
	restore=function(ply,ent)
		GFreddy_Speeds[ent] = nil
	end,
	
	postThink = function(ply, ent, speed)
		ent:SetPoseParameter("move_speed", speed)
	end,
	
	move = function(ply, ent, mv)
		local dt = engine.TickInterval()
	
		local vel = mv:GetVelocity()
		local forward = mv:GetAngles():Forward()
		forward.z = 0
		forward:Normalize()
	
		local right = mv:GetAngles():Right()
		right.z = 0
		right:Normalize()
	
		local forwardMove = mv:GetForwardSpeed()
		local sideMove = mv:GetSideSpeed() * SIDE_MULT
	
		if forwardMove < 0 then
			forwardMove = 0
		end
	
		local accelerating = forwardMove > 0 and not mv:KeyDown(IN_DUCK)
		local horizontalVel = Vector(vel.x, vel.y, 0)
		
		local currentSpeed = GFreddy_Speeds[ent] or horizontalVel:Length()
		local baseSpeed = ply:GetWalkSpeed()
	
		if IsFirstTimePredicted() then
			if accelerating then
				if currentSpeed < baseSpeed then 
					currentSpeed = baseSpeed 
				end
	
				local accel = (MAX_SPEED - baseSpeed) / ACCEL_TIME
				currentSpeed = currentSpeed + accel * dt
				currentSpeed = math.min(currentSpeed, MAX_SPEED)
			else
				local decel = MAX_SPEED / DECEL_TIME
				currentSpeed = math.max(currentSpeed - decel * dt, 0)
			end
			
			GFreddy_Speeds[ent] = currentSpeed
		end
	
		local wishDir = forward * math.max(forwardMove, 0)
		wishDir = wishDir + right * sideMove
	
		if wishDir:LengthSqr() > 0 then
			wishDir:Normalize()
	
			local newVel = wishDir * currentSpeed
			newVel.z = vel.z
	
			mv:SetVelocity(newVel)
		else
			if currentSpeed > 0 and horizontalVel:LengthSqr() > 0 then
				horizontalVel:Normalize()
				mv:SetVelocity(horizontalVel * currentSpeed + Vector(0, 0, vel.z))
			else
				mv:SetVelocity(Vector(0, 0, vel.z))
			end
		end
		
		if SERVER and ply:GetVelocity():Length() > 70 then
			local mins = ply:OBBMins()
			mins.x = mins.x * 2
			mins.y = mins.y * 2
			
			local maxs = ply:OBBMaxs()
			maxs.x = maxs.x * 2
			maxs.y = maxs.y * 2
		
			local startpos = ply:GetPos()
			
			local tr = util.TraceHull( {
				start = startpos,
				endpos = startpos, 
				maxs = maxs,
				mins = mins,
				collisiongroup = ply:GetCollisionGroup(),
				filter = ply,
				ignoreworld=true,
			} )
			
			local target = tr.Entity
			
			if IsValid(target) then 
				if target:IsPlayer() and target:IsSurvivor() and not target:HasGodMode() then
					target:SetLocalVelocity(ply:GetVelocity())
					target:TakeDamage(9999, ply)
					return
				end
			
				local class = target:GetClass()
				if class == "prop_door_rotating" then
					breakBustDoor(ply, target, 90)
					return
				elseif class == "func_door_rotating" or class == "func_door" then
					breakBustFuncDoor(ply, target, 90)
					return
				end
				
				local phys = target:GetPhysicsObject()
				
				if IsValid(phys) then
					SuppressHostEvents( NULL )
					target:TakeDamage(9999, ply)
					SuppressHostEvents( ply )
				end
			end
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 75)
			if !IsValid(target) then return end
			target:TakeDamage(target:Health() + target:Armor(), ply)
			ent:PillSound("melee",false)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end
			
			if cooldown.Exists(ply, "recklessram") then return end
			
			if !navmesh.IsLoaded() or navmesh.GetNavAreaCount() < 5 then 
				ply:ChatPrint("No navmesh!")
				return 
			end
			
			local plyShootPos = ply:GetShootPos()
			local farAwayPos = plyShootPos + ply:GetAimVector() * 10000
			
			local finalSearchPos
			
			local tr = util.TraceLine( {
				start = farAwayPos,
				endpos = farAwayPos,
				mask = MASK_SOLID_BRUSHONLY,
				--ignoreworld = true,
			})
			
			local area = navmesh.GetNearestNavArea( tr.HitPos, nil, 10000 )
			
			if not IsValid(area) then
				if tr.Hit then -- Точка взгляда внутри мира
					local tr = util.TraceLine( {
						start = farAwayPos,
						endpos = farAwayPos + Vector(0,0,500),
						mask = MASK_SOLID_BRUSHONLY,
					})
					
					if tr.Hit then
						local tr = util.TraceLine( {
							start = farAwayPos,
							endpos = plyShootPos,
							mask = MASK_SOLID_BRUSHONLY,
						})
						
						finalSearchPos = tr.HitPos
					else
						local tr = util.TraceLine( {
							start = farAwayPos,
							endpos = plyShootPos,
							mask = MASK_SOLID_BRUSHONLY,
						})
						
						finalSearchPos = tr.HitPos
					end
				else -- Точка взгляда не в мире
					local tr = util.TraceLine( {
						start = farAwayPos,
						endpos = farAwayPos - Vector(0,0,500),
						mask = MASK_SOLID_BRUSHONLY,
					})
					
					if tr.Hit then
						finalSearchPos = tr.HitPos
					end
				end
				
				if not finalSearchPos then
					net.Start("fh_play_sound")
						net.WriteString('ability_failed.wav')
					net.Send(ply)
					
					cooldown.Set(ply, "recklessram", .5)
					cooldown.Send(ply, "recklessram")
					return
				end
				
				area = navmesh.GetNearestNavArea( finalSearchPos, nil, 10000 )
			end
			
			if IsValid(area) then
				local agent = ents.Create("fh_travel_agent")

				if IsValid(agent) then
					agent:Spawn()
					agent:Activate()
					agent:SetPos(ply:GetPos())
					local pathsCount = agent:SetGoalArea(area)

					if pathsCount < 16 then
						agent:Remove()
						
						print('Failed ' .. pathsCount .. " paths only")
						debugoverlay.Axis( area:GetCenter(), Angle(0,0,0), 100, 11, true )

						net.Start("fh_play_sound")
							net.WriteString("ability_failed.wav")
						net.Send(ply)

						cooldown.Set(ply, "recklessram", 1)
						cooldown.Send(ply, "recklessram")

						return
					end
					
					agent:SetOwner(ply)
					ply:SetMoveType(MOVETYPE_NOCLIP)
					
					if ent.HeadRamSound then
						ent.HeadRamSound:Stop()
						ent.HeadRamSound = nil
					end
					if not ent.HeadRamSound then
						local rf = RecipientFilter()
						rf:AddAllPlayers()
						
						ent.HeadRamSound = CreateSound(ent, "gfreddy_head.ram", rf)
					end
					ent.HeadRamSound:PlayEx(0, 95)
					ent.HeadRamSound:ChangeVolume(1, 1)
					ent.HeadRamSound:ChangePitch(108, 10)
					ent.HeadRamSound:SetSoundLevel(0)
					
					local shake = ents.Create("env_shake")
					if IsValid(shake) then

						shake:SetPos(ply:EyePos())
						shake:SetParent(ply) 

						shake:SetKeyValue("amplitude", "16")
						shake:SetKeyValue("radius", "1000")
						shake:SetKeyValue("duration", "30")
						shake:SetKeyValue("frequency", "120")
						shake:SetKeyValue("spawnflags", "0")

						shake:Spawn()
						shake:Activate()
						shake:Fire("StartShake")
						
						ent.Shaky = shake
					end
				end
			else
				net.Start("fh_play_sound")
					net.WriteString('ability_failed.wav')
				net.Send(ply)
				
				cooldown.Set(ply, "recklessram", 1)
				cooldown.Send(ply, "recklessram")
			end
		end
	},
	
	travelAgentEnded=function(ply,ent)
		if ent.HeadRamSound then
			if ent.HeadRamSound:IsPlaying() and ent.HeadRamSound:GetVolume() > 0 then
				ent.HeadRamSound:FadeOut( .5 )
			end
		end
		local shake = ent.Shaky
		if IsValid(shake) then
			shake:Fire("StopShake")
			SafeRemoveEntityDelayed(shake, 1)
		end
		ply:SetMoveType(MOVETYPE_WALK)
		
		if ply:IsStuck() then
			ply:Unstuck()
		end
	end,
	
	jump=function(ply,ent)
		ent:PillGesture("jump", 1, 1)
	end,
})

local GOLDENCLR = Color(255, 210, 0)
killers.Register("fh_wgfreddyhead", "gfreddy_head", "fazhunt.animatronics.gfreddy_head", GOLDENCLR)

killers.SetAbilities("gfreddy_head", {
	{ name = 'recklessram', key = 'RMB' },
})