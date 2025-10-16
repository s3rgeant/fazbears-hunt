AddCSLuaFile()

pills.packStart("FH ENDO TEST", "FH ENDO TEST", "icon16/pill.png")

pills.register("pill_endo02_test",{
	printName="Endo02",
	model="models/speps/pill/endo02.mdl",
	options=function() return {
		IsHalloween() and {skin=1} or {}
	} end,
	anims={
		default={
			idle="idle",
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
		melee=pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
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
			
			chaseCheck(ply, 'endo')
		end)
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply, 90)
			
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
			takePlayer(ply,ent)
		end
	},
	
	land=function(ply,ent)
		if ply.lobbyFreeze != nil and ply.lobbyFreeze then return end
		if ply:WaterLevel() < 2 and ply:GetVelocity().z < -160 then
			ent:PillAnim("land",true)
			return
		end
		
		landTripCheck(ply, ent, "endo")
	end,
	
	noragdoll=true,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
	
})