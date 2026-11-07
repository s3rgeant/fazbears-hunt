AddCSLuaFile()

sound.Add({
	name = 			"gfreddy_head.ram",
	channel = 		CHAN_AUTO,
	level = 		80,
	volume = 		1,
	sound = 			{")fnaf2/gfreddy/head_ram_loop.wav"}
})

local ACCEL_TIME = 2
local DECEL_TIME = 1

local GFreddy_Speeds = {}

local MODEL_PATH = "models/fh/animatronics/UFMP/FNAF2/WGFreddyHead.mdl"

if SERVER then
	util.PrecacheModel(MODEL_PATH)
	
	util.AddNetworkString("fh_gfreddyhead_jumpscare")
end

-- GFREDDY HEAD

pills.register("fh_wgfreddyhead",{
	printName="Withered Golden Freddy Head",
	model=MODEL_PATH,
	
	modelScale="4",
	--bodyGroups={[0] = 1},
	
	anims={
		default={
			idle="idle",
			walk="fly",
			glide="fly",
			appear="appear",
		},
		gestures={
			jump="jump"
		},
	},
	
	viewmodel={
		weapon="v_gfreddyhead"
	},
	
	moveSpeed={
		walk=140,
		run=200,
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
	renderHull=Vector(48,48,110),
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
		ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
		ent:SetFlexWeight( 0, 1 )
		ent:ResetSequence("appear")
		ent:PillAnim("appear", true)
		
		ent:EmitSound("fnaf2/gfreddy/ground_appear.mp3")
		
		ply:GoPillThirdperson(1.7)
		
		if isGameOn and not roundEnding then
			if fh.timer.Exists() then
				local timeLeft = fh.timer.GetTimeLeft()
				
				local maxSpeedTime = math.max(30, timeLeft - 40)
				
				local tName = "GHeadSpeedUp" .. ent:EntIndex()
				timer.Create(tName, maxSpeedTime / 7, 7, function()
					if not IsValid(ent) then timer.Remove(tName) return end
					if not IsValid(ply) then timer.Remove(tName) return end
					
					local curSpeed = ply:GetRunSpeed()
					nextSpeed = math.min( curSpeed + 100, 800 )
					ply:SetRunSpeed(nextSpeed)
					ent.formTable.moveSpeed["run"] = nextSpeed
				end)
			end
		end
	end,
	
	restore=function(ply,ent)
		GFreddy_Speeds[ent] = nil
		
		if IsValid(ent.RageSound) then
			ent.RageSound:Stop()
			ent.RageSound = nil
		end
		
		if IsValid(ent.HeadRamSound) then
			ent.HeadRamSound:Stop()
			ent.HeadRamSound = nil
		end
		
		if CLIENT then return end
		ply:SetCollisionGroup(COLLISION_GROUP_NONE)
	end,
	
	postThink = function(ply, ent, speed)
		if SERVER then
			ent:SetPoseParameter("move_speed", Lerp(0.1, ent:GetPoseParameter("move_speed"), speed))
		end
		if CLIENT then
			if ent:GetNWBool("RecklessRam") then
				local myself = LocalPlayer()
				
				if not IsValid(myself) then return end
				
				local gfreddyPos = ent:GetPos()
				if ply == myself then
					util.ScreenShake( gfreddyPos, 5, 15, FrameTime() * 2, 1500 )
					return
				end
				
				local distance = myself:GetPos():Distance(gfreddyPos) * .05
				util.ScreenShake( gfreddyPos, 500 / distance, 15, FrameTime() * 2, 1500 )
				return
			end
			
			local sName = ent:GetSequenceName(ent:GetSequence())
			
			if sName == "appear" then
				local normal = ent:GetUp()
				local position = normal:Dot( ent:GetPos() )
				ent:SetRenderClipPlaneEnabled( true )
				ent:SetRenderClipPlane( normal, position )
			else
				ent:SetRenderClipPlaneEnabled( false )
			end
		end
	end,
	
	startCommand = function(ply, ent, cmd)
		if ply:GetMoveType() == MOVETYPE_LADDER then return end
		cmd:RemoveKey(IN_LEFT)
		cmd:RemoveKey(IN_RIGHT)
		cmd:RemoveKey(IN_SPEED)
		cmd:RemoveKey(IN_FORWARD)
	end,

	move = function(ply, ent, mv)
		if SERVER and mv:GetVelocity():Length() > 10 then
			local mins = ply:OBBMins()
			mins.x = mins.x * 2
			mins.y = mins.y * 2

			local maxs = ply:OBBMaxs()
			maxs.x = maxs.x * 2
			maxs.y = maxs.y * 2

			local startpos = ply:GetPos()

			local tr = util.TraceHull({
				start = startpos,
				endpos = startpos,
				maxs = maxs,
				mins = mins,
				filter = ply,
				ignoreworld = true
			})

			local target = tr.Entity

			if IsValid(target) then
				if target:IsPlayer() and target:IsSurvivor() and not target:HasGodMode() then
					local dmginfo = DamageInfo()
					dmginfo:SetAttacker(ply)
					dmginfo:SetDamage(9999)

					if target:PassesDamageFilter(dmginfo) then target:SetLocalVelocity(ply:GetVelocity()) end
					target:TakeDamageInfo(dmginfo)
					return
				end

				local class = target:GetClass()

				if class == "prop_door_rotating" then
					breakBustDoor(ply, target, 90)
					return
				elseif class == "func_door_rotating" or class == "func_door" then
					if ent:HasSpawnFlags(8192) or ent:HasSpawnFlags(256) then return end
					breakBustFuncDoor(ply, target, 90)
					return
				end

				local phys = target:GetPhysicsObject()

				if IsValid(phys) then
					SuppressHostEvents(NULL)
					target:TakeDamage(9999, ply)
					SuppressHostEvents(ply)
				end
			end
		end
		
		local wep = ply:GetActiveWeapon()
		
		if IsValid(wep) and wep.GetDashing and wep:GetDashing() then
			return
		end
	
		if ply:GetMoveType() ~= MOVETYPE_LADDER then
			local dt = engine.TickInterval()
			local ang = mv:GetAngles()
			local vel = mv:GetVelocity()

			local forward = ang:Forward()
			forward.z = 0
			forward:Normalize()

			local pressingBack = mv:KeyDown(IN_BACK) and not ent:GetFrozen()
			local maxSpeed = ply:GetRunSpeed()
			local minBackSpeed = 200

			local currentSpeed = GFreddy_Speeds[ent] or 0
			local targetSpeed = pressingBack and minBackSpeed or maxSpeed
			local accelTime = pressingBack and DECEL_TIME or ACCEL_TIME

			local speedChange = math.abs(targetSpeed - currentSpeed) / math.max(accelTime, dt) * dt
			currentSpeed = math.Approach(currentSpeed, targetSpeed, speedChange)

			GFreddy_Speeds[ent] = currentSpeed

			local newVel = forward * currentSpeed
			newVel.z = vel.z

			mv:SetVelocity(newVel)
		end
	end,
	
	jump=function(ply,ent)
		ent:PillGesture("jump", 1, 1)
	end,
})

local GOLDENCLR = Color(226, 160, 0)
killers.Register("fh_wgfreddyhead", "gfreddy_head", "fazhunt.animatronics.gfreddy_head", GOLDENCLR)

killers.SetAbilities("gfreddy_head", {
	{ name = 'recklessram', key = 'RMB' },
})

hook.Add("FH_ShouldSBabySnitchEntity", "wgoldenfreddy_head", function(target)
	local ent = target:GetPillCostume()
	
	if ent.GetPillName and ent:GetPillName() == "fh_wgfreddyhead" then
		return false
	end
end)

if SERVER then return end

local currentRender = nil

local ent = ClientsideModel(MODEL_PATH, RENDERGROUP_VIEWMODEL)
ent:SetNoDraw(true)

local mat_Grayscale = Material( "effects/shaders/merc_grayscale" )

local function BlendGlobalOutworldEffects()
	mat_Grayscale:SetFloat("$c0_x", 0 )
	mat_Grayscale:SetFloat("$c0_y", 1 )
	hook.Add("RenderScreenspaceEffects", "merc_grayscale_hook", function()
		local ft = FrameTime() * .5
	
		render.UpdateScreenEffectTexture()
		mat_Grayscale:SetFloat("$c0_x", Lerp(ft, mat_Grayscale:GetFloat("$c0_x"), -.8) )
		mat_Grayscale:SetFloat("$c0_y", Lerp(ft, mat_Grayscale:GetFloat("$c0_y"), .5) )
		render.SetMaterial(mat_Grayscale)
		render.DrawScreenQuad()
	end)
	
	local PARTICLE_TEXTURE = "particles/smokinweed"
	local RADIUS = 1200
	local PARTICLE_INTERVAL = 0.03
	local PARTICLES_PER_TICK = 2
	local nextParticleTime = 0
	
	local ply = LocalPlayer()
	hook.Add("Think", "GroundDustParticlesDense", function()
		if not IsValid(ply) then return end
		if CurTime() < nextParticleTime then return end

		nextParticleTime = CurTime() + PARTICLE_INTERVAL

		local emitter = ParticleEmitter(ply:GetPos(), false)
		if not emitter then return end

		for i = 1, PARTICLES_PER_TICK do
			local angle = math.Rand(0, 2 * math.pi)
			local distance = math.Rand(50, RADIUS)
			local offset = Vector(math.cos(angle), math.sin(angle), 0) * distance

			local traceData = {
				start = ply:GetPos() + offset + Vector(0, 0, 100),
				endpos = ply:GetPos() + offset - Vector(0, 0, 200),
				mask = MASK_SOLID_BRUSHONLY
			}
			local tr = util.TraceLine(traceData)
			if not tr.Hit then continue end

			local pos = tr.HitPos + Vector(0, 0, 2)

			local particle = emitter:Add(PARTICLE_TEXTURE, pos)
			if particle then
				local upVelocity = Vector(0, 0, math.Rand(10, 20))
				local sideVelocity = ply:GetRight() * math.Rand(5, 10)

				particle:SetVelocity(upVelocity + sideVelocity)
				particle:SetLifeTime(0)
				particle:SetDieTime(math.Rand(2, 3))
				particle:SetStartAlpha(math.Rand(80, 120))
				particle:SetEndAlpha(0)
				particle:SetStartSize(math.Rand(1, 6))
				particle:SetEndSize(math.Rand(6, 12))
				particle:SetRoll(math.Rand(0, 360))
				particle:SetRollDelta(math.Rand(-0.3, 0.3))
				particle:SetColor(170, 170, 170)
				particle:SetAirResistance(25)
			end
		end

		emitter:Finish()
	end)
end

local function RemoveGlobalOutworldEffects()
	hook.Remove("RenderScreenspaceEffects", "merc_grayscale_hook")
end

net.Receive("fh_gfreddyhead_jumpscare", function()
	if IsValid(currentRender) then
		currentRender:Remove()
		currentRender = nil
	end

	if not IsValid(ent) then return end
	
	local seq = ent:LookupSequence("guardian")
	if seq == -1 then return end

	ent:ResetSequence(seq)
	ent:SetCycle(0)
	ent:SetPlaybackRate(1)

	local duration = ent:SequenceDuration(seq)
	if duration <= 0 then duration = 1 end
	
	surface.PlaySound("fnaf2/gfreddy/head_guardian.mp3")

	currentRender = {
		ent = ent,
		startTime = CurTime(),
		duration = duration
	}

	hook.Add("PostRenderVGUI", "RenderGuardianModel", function(vm, ply, weapon)
		if not currentRender then return end

		local ent = currentRender.ent
		if not IsValid(ent) then
			currentRender = nil
			return
		end

		local timePassed = CurTime() - currentRender.startTime
		local progress = timePassed / currentRender.duration

		if progress >= 1 then
			currentRender = nil
			hook.Remove("PostRenderVGUI", "RenderGuardianModel")
			return
		end

		ent:FrameAdvance(FrameTime())

		local alphaFraction = math.ease.InOutCubic((1 - math.abs(progress - 0.5) * 2) * 0.85)

		local eyePos = EyePos()
		local eyeAngles = EyeAngles()
		
		util.ScreenShake( eyePos, alphaFraction * 25, 15, FrameTime() * 2, 5000 )

		render.ClearDepth()

		cam.Start3D(eyePos, eyeAngles, 70, 0, 0, ScrW(), ScrH(), 1, 1000)
			ent:SetPos(eyePos)
			ent:SetAngles(eyeAngles)

			render.SetStencilEnable(true)
			render.SetStencilWriteMask(0xFF)
			render.SetStencilTestMask(0xFF)
			render.SetStencilReferenceValue(1)
			
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)

			render.OverrideColorWriteEnable(true, false)
				ent:DrawModel()
			render.OverrideColorWriteEnable(false, false)

			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilPassOperation(STENCIL_KEEP)

			render.SetBlend(alphaFraction)
			render.SetAmbientLight(255,255,255)
				ent:DrawModel()
			render.SetBlend(1)

			render.SetStencilEnable(false)
		cam.End3D()
	end)
	
	BlendGlobalOutworldEffects()
end)