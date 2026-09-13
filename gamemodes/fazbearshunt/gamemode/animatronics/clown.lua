AddCSLuaFile()

if SERVER then
	util.PrecacheModel("models/tettris/FNaF/SD/springtrap_clown.mdl")
end
pills.register("pill_clown",{
	printName="Clown",
	modelScale="1.2",
	model="models/tettris/FNaF/SD/springtrap_clown.mdl",
	health=10000,
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			jump="jump",
			glide="glide",
			dance="dance",
			crouch="crouch",
			crouch_walk="crouchmove",
			stun="stun",
		},
		gestures={
			hit="hit",
			land="land",
		},
	},
	moveSpeed={
		walk=110,
		run=420,
		ducked=70,
	},
    jumpPower=250,
	
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		loop_dance="kloun_ebanat.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_clown"
	},
	bloodType=BLOOD_COLOR_MECH,
	
	animEvent=function(ply,ent,event)
		if event == "CLOWN_HIDE_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(0,0,0) )
			end
		elseif event == "CLOWN_SHOW_HAMMER" then
			if ent:LookupBone( "Hammer_Bn" ) then
				ent:ManipulateBoneScale(ent:LookupBone( "Hammer_Bn" ), Vector(1,1,1) )
			end
		end
	end,
	
	initialize=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "clown")
	end,
	
	restore=function(ply,ent)
		if CLIENT then return end
		ply:SetJumpBoostMultiplier( getScaledJumpBoost() )
	end,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,

	taunt=function(ply,ent,act)
		if !ent.NextAct or ent.NextAct and CurTime() > ent.NextAct then
			if act == ACT_GMOD_TAUNT_DANCE and ent.anim ~= "dance" then
				if !ply:OnGround() then return end

				ent:PillLoopSound('dance', 0.6)
				ent:PillAnim("dance", true)
				ent.ignoreFreeze = true
				
				ent.NextAct = CurTime() + 4.5
				ply:GoPillThirdperson(4.5)
			end
		end
	end,
	
	animStopped=function(ply,ent, name)
		if name == 'dance' then
			ent:PillLoopStop('dance')
		end
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	land=function(ply,ent)
		ent.anim = nil
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
			ent:PillGesture('land', 1, 2, 0.15, 0.3, 0.06)
			ent:PillLoopStop('dance')
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end
})