AddCSLuaFile()

local cupcakes = {} 

pills.register("pill_wchica2",{
	printName="Withered Chica",
	model="models/speps/pill/oldchica.mdl",
		
	options=function() return {
		["default"] = {
			-- ничего
		},
		["halloween"] = {
			skin = 1
		},
		["christmas"] = {
			bodyGroups = { [0] = 2 },
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
			cloak="special1",
			jump="jump",
			glide="air",
			land="land",
			scare="scare",
			stun="stun",
			melee="melee",
		},
	},
	moveSpeed={
		walk=80,
		run=485,
		ducked=80,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.mp3",
		land="land.mp3",
		melee="fnaf2/xscream2.wav",
		deploy="chica_deploycake.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	bloodType=BLOOD_COLOR_MECH,
	
    jumpPower=250,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "chica")
	end,
	
	killCondition=function(ply,ent)
		local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "chica", 50)
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !cupcakes[ply] then cupcakes[ply] = 0 end
			if cupcakes[ply] < conVars.fh_max_cupcakes:GetInt() and !cooldown.Exists(ply, "mine") then
				cooldown.Set(ply, "mine", 15)
				cooldown.Send(ply, "mine")
				
				local playerPos = ply:GetPos()
				local spawnPos = playerPos + ply:GetUp() * 10
				local cupcake = ents.Create("cakemine")
				
				ent:PillSound('deploy')
				
				if not IsValid(cupcake) then return end

				if math.random(1, 10) > 4 then playVoiceline('chica', 'plant', ply, 0.1) end
				
				cupcake:SetPos(spawnPos)
				cupcake:SetAngles(ply:GetAngles())
				cupcake:SetOwner(ply)
				cupcake:Spawn()
				cupcake:Activate()
				
				hook.Run("FH_MinePlanted", ply, ent, cupcake)
				
				cupcakes[ply] = cupcakes[ply] + 1
			
				net.Start("fh_cooldown_receive")
				net.WriteString("addmine")
				net.WriteFloat(1)
				net.Send(ply)
			end
		end
	},
	
	land=function(ply,ent)
		if !ent.cloaked and ply:WaterLevel() < 2 then
			if ply._wereJumpingPill or !ply._wereJumpingPill and ply:GetVelocity().z < -270 then
				if !ply._jumpPosPill or ply._jumpPosPill and ply:GetPos():Distance(ply._jumpPosPill) > 150 then
					ent:PillAnim("land",true)
				end
			end
		end
		
		landTripCheck(ply, ent, "chica")
	end,
	
	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", false)
	end,
	onRemove=function(ent,formTable,ply)
		if SERVER then
			killCupcakes(ply)
		end
	end
})
	
hook.Add( "PlayerDisconnected", "fh_pill_wchica_cupcakes", function( ply )
	killCupcakes(ply)
end)
	
function killCupcakes(ply)
	if table.IsEmpty(cupcakes) or !cupcakes[ply] then return end
	for _, ent in ipairs( ents.FindByClass( "cakemine" ) ) do
		if ent:GetOwner() == ply then
			ent:Remove()
		end
	end
	cupcakes[ply] = nil
end
	
hook.Add("EntityRemoved", "RemoveKilledCupcake", function(ent)
	if ent:GetClass() == "cakemine" then
		local owner = ent:GetOwner() 
		if IsValid(owner) then
			if cupcakes[owner] then
				cupcakes[owner] = math.max(0, cupcakes[owner] - 1)
			end
		end
	end
end)

hook.Add( "PostCleanupMap", "fh_cupcakes_reset", function()
	table.Empty(cupcakes)
end)