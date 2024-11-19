AddCSLuaFile()

if SERVER then
	util.AddNetworkString("JumpscareLight")
	util.AddNetworkString("SetKillerAngle")
	
	util.AddNetworkString("fh_net_killer_change")
	
	util.AddNetworkString("fh_stalk_sound_play")
	util.AddNetworkString("fh_stalk_sound_stop")
	
	util.AddNetworkString("SF_cantout")
	
	util.AddNetworkString("PlayHighlightSounds")
	util.AddNetworkString("AddAffectedPlayers")
	util.AddNetworkString("RemoveAffectedPlayer")
	util.AddNetworkString("ToggleHighlightSound")
	util.AddNetworkString("NotifySpectators")
end

pcall(require,"pk_pills")

local haloUsers = {}

local cupcakes = {} 

shadow_freddyability = CreateConVar( "fuppr_sfreddy_noclip", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, "Noclip." )

pk_pills.packStart("FUPPR 2 WE","FUPPR 2 WE","icon/fnafur2we.png")

pk_pills.register("pill_wfreddy2",{
	printName="Withered Freddy",
	model="models/speps/pill/oldfreddy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special",
			scare="scare",
			jump="jump",
			glide="air",
			land="land",
			stalk="stalk",
		},
	},
	moveSpeed={
		walk=150,
		run=490,
		ducked=65,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		laugh={"fnaf2/giggling1.wav",
			   "fnaf2/giggling2.wav",
			   "fnaf2/giggling3.wav"},
		jump="jump.wav",
		land="land.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
				
				chaseCheck(ply, 'freddy')
			end)
		end
	end,

	noFallDamage=true,
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			playVoiceline('freddy', 'kill', ply, 2)
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 50)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			local target = fh_random_stalk_target(ply)
			
			if !IsValid(target) then return end
			
			local totalDistance = 0
			local lastPosition = target:GetPos()
			smoothLookAt(ply, target)
			ent:PillAnim("stalk",true)
			ply:SetFOV(60, 8)
			
			net.Start('fh_stalk_sound_play')
			net.Send(ply)
			
			timer.Create("stalk_check"..ent:EntIndex(), 1, 11, function()
				
				if !IsValid(target) or timer.RepsLeft("stalk_check"..ent:EntIndex()) == 1 then
					timer.Remove("SmoothLookAt_" .. ply:EntIndex())
					timer.Remove("stalk_check"..ent:EntIndex())
					ply:SetFOV(0, 1)
					net.Start('fh_stalk_sound_stop')
					net.Send(ply)
					return
				end
				
				local currentPosition = target:GetPos()
		
				if not target:Crouching() then
					local distance = currentPosition:Distance(lastPosition)
					totalDistance = totalDistance + distance
				end
				
				lastPosition = currentPosition
		
				if totalDistance > 1800 then
					ent:PillAnim("idle")
					timer.Remove("SmoothLookAt_" .. ply:EntIndex())
					timer.Remove("stalk_check"..ent:EntIndex())
					ply:SetFOV(0, 1)
				end
			end)
		end
	},

	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	
	land=function(ply,ent)
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -200 then
			ent:PillAnim("land",true)
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end,
	restore=function(ply,ent)
		timer.Remove("SmoothLookAt_"..ply:EntIndex())
		timer.Remove("stalk_check"..ent:EntIndex())
	end
})

-- сталк
function fh_random_stalk_target(ignore)
    local candidates = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and ply ~= ignore and ply:Team() != 2701 then
            local speed = ply:GetVelocity():Length()
            if speed < 70 then
                table.insert(candidates, ply)
            end
        end
    end

    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    else
        return nil -- Нет подходящих игроков
    end
end


function smoothLookAt(anim, targetPlayer)
    if not IsValid(anim) or not IsValid(targetPlayer) then return end

    timer.Create("SmoothLookAt_" .. anim:EntIndex(), 0.01, 0, function()
        if not IsValid(anim) or not IsValid(targetPlayer) then
            timer.Remove("SmoothLookAt_" .. anim:EntIndex())
            return
        end

        local currentAngle = anim:EyeAngles()

        local targetPos = targetPlayer:GetPos()
        local direction = (targetPos - anim:GetPos()):GetNormalized()

        local targetAngle = direction:Angle()

        local newAngle = LerpAngle(0.05, currentAngle, targetAngle)

        anim:SetEyeAngles(newAngle)
    end)
end


--bonnie









pk_pills.register("pill_wbonnie2",{
	printName="Withered Bonnie",
	model="models/speps/pill/oldbonnie.mdl",
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special",
			teleport="zombie_leap_mid",
			jump="jump",
			glide="jumpidle",
			land="jumpend",
			scare="scare",
			point="point",
		},
	},
	moveSpeed={
		walk=90,
		run=475,
		ducked=80,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		jump="jump.wav",
		land="land.wav",
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	muteSteps = true,

    jumpPower=250,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
				
				chaseCheck(ply, 'bonnie')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			playVoiceline('bonnie', 'kill', ply, 2)
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.5)
			net.Send(ply)
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				
				target:UnLock()
				ply:UnLock()
				target:SetVelocity(ply:GetForward() * 600) -- чтоб он нахуй улетел
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if ply:IsFrozen() then return end
			if !ply:Crouching() then
				ent:PillGesture('point', 1, 1, 0.1, 0.1)
				
				local target = FindNearestPlayer(ent:GetPos(), 600, ply)
				if !IsValid(target) then return end
				
				playVoiceline('bonnie', 'spotted', ply, 1)
			end
		end
	},
	
	land=function(ply,ent)
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -200 then
			ent:PillAnim("land",true)
		end
	end,

	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,

	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end
})






--chica





pk_pills.register("pill_wchica2",{
	printName="Withered Chica",
	model="models/speps/pill/oldchica.mdl",
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special1",
			teleport="zombie_leap_mid",
			jump="jump",
			glide="air",
			land="land",
			scare="scare",
		},
	},
	moveSpeed={
		walk=80,
		run=470,
		ducked=80,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.wav",
		land="land.wav",
	//	scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		deploy="chica_deploycake.wav",
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
    jumpPower=250,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
				
				chaseCheck(ply, 'chica')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			playVoiceline('chica', 'kill', ply, 2)
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 60)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if table.Count(cupcakes) < 3 and not timer.Exists('C_deploycake'..ply:EntIndex()) then
				timer.Create("C_deploycake"..ply:EntIndex(), 1, 1, function() end)
				
				local playerPos = ply:GetPos()
				local spawnPos = playerPos + ply:GetUp() * 10
				local cupcake = ents.Create("cakemine")
				
				ent:PillSound('deploy')
				
				if not IsValid(cupcake) then return end
				
				cupcake:SetPos(spawnPos)
				cupcake:SetOwner(ply)
				cupcake:Spawn()
				cupcake:Activate()
				
				table.insert(cupcakes, cupcake:EntIndex())
			
				net.Start("fh_net_killer_change")
				net.WriteString("Mine")
				net.WriteFloat(1)
				net.Send(ply)
			end
		end
	},
	
	land=function(ply,ent)
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -200 then
			ent:PillAnim("land",true)
		end
	end,
	
	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end,
	restore=function(ply,ent)
		killCupcakes(ply)
	end
})










--foxy








pk_pills.register("pill_wfoxy2",{
	printName="Withered Foxy",
	model="models/speps/pill/oldfoxy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			jump="jump",
			glide="air",
			run="run",
			cloak="taunt",
			teleport="zombie_leap_mid",
			land="land",
			scare="scare",
		},
	},
	moveSpeed={
		walk=150,
		run=530,
		ducked=70,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/xscream2.wav",
		jump="lunge.wav",
		land="land_foxy.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		scream="fnaf2/foxyflashed.wav",
		taunt="foxy_laugh.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
    jumpPower=400,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
				
				chaseCheck(ply, 'foxy')
			end)
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			playVoiceline('foxy', 'kill', ply, 2)
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 75)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			ent:PillSound("taunt", true)
			ent:PillAnim("cloak", true)
		end
	},
	
	land=function(ply,ent)
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -200 then
			ent:PillAnim("land",true)
		end
	end,

		
	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end
})











--goldy












pk_pills.register("pill_wgfreddy2",{
	printName="Withered Golden Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="sit",
			walk="walk",
			run="run",
			out="sdpecial",
			inn="tonormal",
			teleport="zombie_leap_mid",
		},
	},

	moveSpeed={
		walk=130,
		run=500,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/wgfreddy_laugh.wav",
		scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	muteSteps = true,
	
	cloak={
		max=-1
	},
    jumpPower=0,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,

	noFallDamage=true,
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			target:TakeDamage(99999, ply)
			ent:PillSound("melee")
			if target:IsNPC() then
				timer.Simple( 1.5, function()
					if !IsValid(ent) then return end
					target:EmitSound( "legitfreddy/static.wav" )
				end)
			return end
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				target:EmitSound( "legitfreddy/static.wav" )
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end

//			ent:PillAnim("cloak",true)

			timer.Simple(0,function()
				if !IsValid(ent) then return end
				ent:ToggleCloak()
			end)
/*
			if ent.cloaked then
				ent.cloaked=nil

				timer.Simple(1,function()
					if !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial()
					ent:DrawShadow(true)
				end)
			else
				ent.cloaked=true

				timer.Simple(0.88,function()
					if !IsValid(ent) or !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial("Models/effects/vol_light001")
					ent:DrawShadow(false)
				end)
			end*/
		end
	},

	flashlight=function(ply,ent)
		if !ply:OnGround() then return end
		
	//	ent:PillAnim("teleport",true)

		timer.Simple(.1,function()
			if !IsValid(ent) then return end
			local tracein={}
			tracein.maxs=Vector(16,16,72)
			tracein.mins=Vector(-16,-16,0)
			tracein.start=ply:EyePos()
			tracein.endpos=ply:EyePos()+ply:EyeAngles():Forward()*9999
			tracein.filter = {ply,ent}

			local traceout= util.TraceHull(tracein)
			ply:SetPos(traceout.HitPos)
			ent:PillSound("teleport")
		end)
	end,
	
	noragdoll=true,
	reload=function(ply,ent)
		ent:PillAnim("out",true)
	
		timer.Simple(0.9,function()
			if !IsValid(ent) then return end


			pk_pills.apply(ply,ent.formTable.crab)
			local e = pk_pills.apply(ply,ent.formTable.printName=="Withered Golden Freddy" and "pill_wgfreddyhead2")
			e:PillAnim("inn",true)
			if (attach) then
				ply:SetPos(attach.Pos)
			end
		end)
	end,

	jump=function(ply,ent)
		ent:PillSound("gs")
	end
})





































pk_pills.register("pill_wgfreddyhead2",{
	printName="Withered Golden Freddy Head",
	model="models/speps/pill/oldgoldenfreddyhead.mdl",
	bodyGroups={0},
	anims={
		default={
			idle="idle",
			crouch="crouch",
			walk="walk",
			out="special",
			inn="tohead",
			run="run",
			teleport="zombie_leap_mid",
		},
	},
	modelScale="2.5",
	moveSpeed={
		walk=300,
		run=1000,
		ducked=0,
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs={"fnaf2/wgfreddy_glitchsound.wav",
		"fnaf2/wgfreddy_glitchsound2.wav"},
		scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	muteSteps = true,
	
	cloak={
		max=-1
	},
    jumpPower=0,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	noFallDamage=true,	
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			target:TakeDamage(99999, ply)
			ent:PillSound("melee")
			if target:IsNPC() then
				timer.Simple( 1.5, function()
					if !IsValid(ent) then return end
					target:EmitSound( "legitfreddy/static.wav" )
				end)
			return end
		
			timer.Simple( 1.5, function()
				if !IsValid(target) then return end
				target:EmitSound( "legitfreddy/static.wav" )
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },

	attack2={
		mode="trigger",
		func = function(ply,ent)
			if !ply:OnGround() then return end

//			ent:PillAnim("cloak",true)

			timer.Simple(0,function()
				if !IsValid(ent) then return end
				ent:ToggleCloak()
			end)
/*
			if ent.cloaked then
				ent.cloaked=nil

				timer.Simple(1,function()
					if !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial()
					ent:DrawShadow(true)
				end)
			else
				ent.cloaked=true

				timer.Simple(1,function()
					if !IsValid(ent) or !IsValid(ent) then return end
					ent:PillSound("cloak")
					ent:SetMaterial("Models/effects/vol_light001")
					ent:DrawShadow(false)
				end)
			end*/
		end
	},

	
	noragdoll=true,
	reload=function(ply,ent)
		ent:PillAnim("out",true)
	
		timer.Simple(0.6,function()
			if !IsValid(ent) then return end


			pk_pills.apply(ply,ent.formTable.crab)
			local e = pk_pills.apply(ply,ent.formTable.printName=="Withered Golden Freddy Head" and "pill_wgfreddy2")
			e:PillAnim("inn",true)
			if (attach) then
				ply:SetPos(attach.Pos)
			end
		end)
	end,
	

	flashlight=function(ply,ent)
		if !ply:OnGround() then return end
		
	//	ent:PillAnim("teleport",true)

		timer.Simple(.1,function()
			if !IsValid(ent) then return end
			local tracein={}
			tracein.maxs=Vector(16,16,72)
			tracein.mins=Vector(-16,-16,0)
			tracein.start=ply:EyePos()
			tracein.endpos=ply:EyePos()+ply:EyeAngles():Forward()*9999
			tracein.filter = {ply,ent}

			local traceout= util.TraceHull(tracein)
			ply:SetPos(traceout.HitPos)
			ent:PillSound("teleport")
		end)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("gs")
	end
})














--shadow





--[[
	КД ШЕДОУ МИШКИ
	
	КД на убийство когда вышел из ноуклипа; 	когда вошёл в ноуклип;		когда вышел из него
	
]]
local sfreddy_cooldowns = {1.5, 7, 5}

-- ХОДЬБА, БЕГ, ВПРИСЯДИ, СИЛА ПРЫЖКА
local sfreddy_default_movement = {80, 80, 65, 0} -- обычное передвижение
local sfreddy_noclip_movement = {360, 360, 360, 0} -- это на случай если - fuppr_sfreddy_noclip 0

pk_pills.register("pill_sfreddy2",{
	printName="Shadow Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",

options=function() return {
{skin=1}
}end,
	bodyGroups={12},
	anims={

		default={
			idle="sidle",
			crouch="scrouch",
			crouch_walk="scrouchmove",
			walk="swalk",
			cloak="sdisappear",
			uncloak="sappear",
			teleport="zombie_leap_mid",
			scare="sscare",
		},
	},
	moveSpeed={
		walk=sfreddy_default_movement[1],
		run=sfreddy_default_movement[2],
		ducked=sfreddy_default_movement[3],
	},
	sounds={
	//	teleport="legitfreddy/laugh_giggle_girl_1d.wav",
		gs="fnaf2/shfreddy_laugh.wav",
		stare={"fnaf2/garble1.wav",
		"fnaf2/garble2.wav",
		"fnaf2/garble3.wav"},
	//	scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/sxscream.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
	cloak={
		max=-1
	},
    jumpPower=0,
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
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ent.cloaked or timer.Exists("SF_cantKill"..ply:EntIndex()) then return end
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			
			//playVoiceline('sfreddy', 'kill', ply, 2)
			
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	 
	attack2={
		mode="trigger",
		func = function(ply,ent)
			
			if timer.Exists('SF_Cloacking'..ply:EntIndex()) or (timer.Exists('SF_Cooldown'..ply:EntIndex())) then return end

			if !ply:KeyDown(IN_USE) then
			
				if ent.cloaked then
			
					local trace = util.TraceHull({
						start = ply:GetPos(),
						endpos = ply:GetPos(),
						mins = ply:OBBMins(),
						maxs = ply:OBBMaxs(),
						filter = ply
					})
					
					if trace.Hit then
						net.Start("SF_cantout")
						net.Send(ply)
						return 
					end
					
					ply:EmitSound("sfreddyout.wav")
					
					ent.cloaked=false
	
					ent:ToggleCloak()
						
					timer.Remove("ext")
					timer.Create("SF_cantKill"..ply:EntIndex(), sfreddy_cooldowns[1], 1, function() end)
					
					timer.Create("SF_Cooldown"..ply:EntIndex(), sfreddy_cooldowns[3], 1, function() end)
					
					if SERVER then
			
						net.Start("fh_net_killer_change")
						net.WriteString("Kill")
						net.WriteFloat(sfreddy_cooldowns[1])
						net.Send(ply)
				
						net.Start("fh_net_killer_change")
						net.WriteString("Submerge")
						net.WriteFloat(sfreddy_cooldowns[3])
						net.Send(ply)
						
					end
							
					if shadow_freddyability:GetInt() == 1 then
						ply:SetMoveType( MOVETYPE_WALK )
					end
							
					ply:SetCustomCollisionCheck(true)
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					
					ent:SetSpeed(sfreddy_default_movement[1], sfreddy_default_movement[2], sfreddy_default_movement[3], 0)
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.2, 1, function()
						if !IsValid(ent) then return end
							timer.Simple(0,function()
							ent:PillAnim("uncloak")
							
							ent:SetMaterial()
							
							//ply:SetNoDraw( false )
							//ent:SetNoDraw( false )
							
							ent:SetModel("models/speps/pill/oldgoldenfreddy.mdl")
							ent:DrawShadow(true)
						end)
					end)
				else
					if !ply:OnGround() then return end
					if !IsValid(ent) or !IsValid(ent) then return end
					timer.Create("SF_Cooldown"..ply:EntIndex(), sfreddy_cooldowns[2], 1, function() end)
					
					ply:EmitSound("sfreddyin.wav")
					ply:EmitSound("sfreddyin.wav")
			
					if SERVER then
					
						net.Start("fh_net_killer_change")
						net.WriteString("Submerge")
						net.WriteFloat(sfreddy_cooldowns[2])
						net.Send(ply)
						
					end
					
					ent:PillAnim("cloak")
					
					timer.Create( "ext", 0.2, 0, function() 
						if !IsValid(ent) then return end
						if ply:Health() < 1000 then ply:SetHealth(ply:Health()+1) end
						if ent:IsOnFire() then ent:Extinguish() end
						if ply:IsOnFire() then ply:Extinguish() end
					end)
					
					ent.cloaked=true
					ent:ToggleCloak()
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.6, 1, function()
						ent:SetSpeed(sfreddy_noclip_movement[1], sfreddy_noclip_movement[2], sfreddy_noclip_movement[3], 200)
						if shadow_freddyability:GetInt() == 1 then
							ply:SetMoveType( MOVETYPE_NOCLIP )
						end
						
						ent:SetMaterial("null")
						ent:SetModel("models/Items/AR2_Grenade.mdl")
						ent:DrawShadow(false)
						//ply:SetNoDraw( true )
						//ent:SetNoDraw( true )
						
						ply:SetCollisionGroup(COLLISION_GROUP_WORLD )
						ply:SetCustomCollisionCheck(true)
					end)
						
				end
			
			elseif ent.cloaked then
			
				ply:EmitSound( "" )
			
			end
			
		end
	},
 
 
	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	
	jump=function(ply,ent)
		//ent:PillSound("gs")
	end
})








--endo








pk_pills.register("pill_endo02",{
	printName="Endo02",
	model="models/speps/pill/endo02.mdl",
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="movecrouch",
			walk="walk",
			run="run",
			cloak="special",
			teleport="zombie_leap_mid",
			g_hold="scare",
			jump="jump",
			glide="air",
			land="land",
			scare="scare",
		},
	},
	moveSpeed={
		walk=120,
		run=460,
		ducked=200,
	},
	sounds={
		gs="fnaf2/stareshort.wav",
		loop_stare="fnaf2/with_s2_loop2.wav",
		jump="jump.wav",
		land="land.wav",
	//	scream="fnaf2/bonniescream.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,
	
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
	
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
		end
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() then return end
			
			local target = FindNearestPlayer(ent:GetPos(), 130, ply)
			if !IsValid(target) then return end
			playVoiceline('endo', 'kill', ply, 2)
			ent:PillSound("melee")
			if target:IsNPC() then
				target:TakeDamage(99999, ply)
				return 
			end
			jumpscareEvent(ply, ent, target, 52)
			ent:PillAnim("scare",true)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(1.6)
			net.Send(ply)
		
			timer.Simple( 1.6, function()
				
				if !IsValid(target) then return end
				//target:ConCommand( "pp_mat_overlay overlays/fivenights_static/static2" )
				target:UnLock()
				ply:UnLock()
				target:TakeDamage(99999, ply)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if timer.Exists("grabCooldown"..ply:EntIndex()) then return end
			takePlayer(ply,ent)
			//ent:PillGesture('hold')
		end
	},
	
	land=function(ply,ent)
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -200 then
			ent:PillAnim("land",true)
		end
	end,

	
	noragdoll=true,

	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end
	
})
	
	
	
	
	
	-- CLOWN
	
	
	
	

pk_pills.register("pill_springtrap",{
	printName="Clown Springtrap",
	bodyGroups={0},
	modelScale="1.2",
	model="models/tettris/FNaF/SD/springtrap_clown.mdl",
	anims={
		default={
			idle="idle",
			walk="walk",
			run="run",
			hit="hit",
			land="land",
			jump="jump",
			glide="glide",
		},
	},
	moveSpeed={
		walk=110,
		run=440,
		ducked=70,
	},
	sounds={
		jump="jump.wav",
		land="land.wav",
		melee=pk_pills.helpers.makeList("fnaf2/xscream2.wav",2),
		step=pk_pills.helpers.makeList("fnaf2/none.wav",1)
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(16,16,86),
	duckBy=60,

    jumpPower=250,
	
	muteSteps = true,
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	canAim=function(ply,ent)
		return ent.active
	end,
	
	--[[
	moveFunction=function(ply,ent)
		if IsValid(ent) then
			if CLIENT then return end
		
			if timer.Exists( "CheckConditions"..ply:EntIndex()) or timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
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
				
				chaseCheck(ply, 'freddy')
			end)
		end
	end,
	--]]

	noFallDamage=true,
	hideHud = true,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ply:IsFrozen() or timer.Exists('Cl_cantKill'..ply:EntIndex()) then return end
			ent:PillGesture('hit', 2, 1, 0.1, 0.3)
			
			timer.Create('Cl_cantKill'..ply:EntIndex(), 2, 1, function() end)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Kill")
			net.WriteFloat(2)
			net.Send(ply)
			ply:EmitSound("hammer_ready.wav")
			
			timer.Simple( 0.85, function()
				local hitpos = ent:GetPos() + (ent:GetForward() * 100)
				local target = FindNearestPlayer(hitpos, 100, ply)
				
				local trace = util.TraceLine({
					start = hitpos,
					endpos = hitpos - Vector(0, 0, 150),
					filter = ply,ent
				})
            
				local distance = (hitpos - trace.HitPos):Length()
				
				if trace.Hit or target then
				
					local effectdata = EffectData()
					effectdata:SetOrigin(trace.HitPos)
					effectdata:SetScale(160)
					util.Effect("ThumperDust", effectdata)
					
					ply:EmitSound("hammer_hit.wav")
				
				end
				if !IsValid(target) then return end
		
				if target:IsNPC() then
					target:TakeDamage(99999, ply)
					return 
				end
			
				target:TakeDamage(36, ply)
				target:SetVelocity(ply:GetUp() * 249) -- чтоб он нахуй улетел
				
				--playVoiceline('clown', 'kill', ply, 2)
				
				timer.Simple( 2, function()
					if !IsValid(target) then return end
					//target:ConCommand( "pp_mat_overlay " )
				end)
			end)
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply,ent)
			--ent:PillSound("laugh")
			--ent:PillAnim("cloak",true)
		end
	},

	noragdoll=true,
	reload=function(ply,ent)
		HighlightPlayers(ply)
	end,
	
	land=function(ply,ent)
		ent.anim = nil
		if ply:IsFrozen() then return end
		if ply:WaterLevel() < 1 and ply:GetVelocity().z < -100 then
			ent:PillGesture('land', 1, 2, 0.1, 0.3, 0.06)
		end
	end,
	jump=function(ply,ent)
		ent:PillSound("jump", true)
	end
})

function playVoiceline(character, line, who, when)
	if ( timer.Exists( "PlayVoiceLine" .. who:UserID()) or timer.Exists( "DontVoiceLine" .. who:UserID() ) ) then return end
	
	timer.Create("PlayVoiceLine" .. who:UserID(), when, 1, function()
		who:EmitSound( character .."." .. line)
		timer.Create("DontVoiceLine" .. who:UserID(), 5, 1, function() end)
	end)
end

function FindNearestPlayer(origin, radius, ignorePlayer)
    local nearestPlayer = nil
    local nearestDistance = radius

    for _, ply in ipairs( ents.FindInSphere( origin, radius ) ) do
        if ply ~= ignorePlayer and ply:Health() > 0 and ((ply:IsPlayer() and (ply:Team() != TEAM_SPECTATOR and ply:Team() != 2701)) or ply:IsNPC()) then
            local distance = origin:Distance(ply:GetPos())
			local trace = util.TraceLine({
				start = ignorePlayer:EyePos(),
				endpos = ply:EyePos(),
				filter = function(ent)
				return ent != ignorePlayer and ent != ply and not ent:IsPlayer() and not ent:IsNPC() and ent:GetClass() != "prop_physics"
			end})

            if distance <= nearestDistance and not trace.Hit then
                nearestDistance = distance
                nearestPlayer = ply
            end
        end
    end

    return nearestPlayer
end

local playersHoldingRightClick = {}
local noClipBlockedPlayers = {}
resource.AddFile("sound/grab_player.wav")
resource.AddFile("sound/throw_player.wav")

function jumpscareEvent(ply, ent, target, dist)
	if CLIENT then return end
	if !IsValid(target) then return end
	
	net.Start("JumpscareLight")
	net.Send(target)
	
	target:Lock()
	ply:Lock()
	
	target:SetVelocity(Vector(0, 0, 0))
	ply:SetVelocity(Vector(0, 0, 0))
	
	util.ScreenShake(target:GetPos(), 5, 5, 2, 500)
	
    local distance = dist or 50

    local attackerPos = ply:GetPos()
    local attackerForward = ply:GetForward()

    local targetPos = attackerPos + attackerForward * distance

    local tr = util.TraceHull({
        start = targetPos,
        endpos = targetPos,
        mins = Vector(-16, -16, 0),
        maxs = Vector(16, 16, 72),
        mask = MASK_PLAYERSOLID,
        filter = { ply, target }
    })

    if tr.Hit then
        local backDistance = distance
        local backPos = attackerPos - attackerForward * backDistance

        local backTr = util.TraceHull({
            start = backPos,
            endpos = backPos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            mask = MASK_PLAYERSOLID,
            filter = { ply, target }
        })

        if not backTr.Hit then
            ply:SetPos(backPos)
            attackerPos = backPos
			
            targetPos = attackerPos + attackerForward * distance
        end
    end
	
	target:SetPos(targetPos)

    local direction = (ply:GetPos() - target:GetPos()):Angle()
    target:SetEyeAngles(direction)
	
    local direction = (target:GetPos() - ply:GetPos()):Angle()
	ply:SetEyeAngles(direction)
	
	net.Start("SetKillerAngle")
	net.WriteEntity(ent)
	net.Broadcast()
end

function takePlayer(ply, ent)
	if ply:Team() == TEAM_SPECTATOR or ply:Health() == 0 then return end

    local nearestPlayer = FindNearestPlayer(ply:EyePos(), 125, ply)

    if nearestPlayer and nearestPlayer:IsPlayer() and !nearestPlayer:IsFrozen() then
		ply:EmitSound("grab_player.wav")
        nearestPlayer:SetMoveType(MOVETYPE_NONE)
        nearestPlayer:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        noClipBlockedPlayers[nearestPlayer] = true

        playersHoldingRightClick[ply] = nearestPlayer

        timer.Create("UpdateCameraAndPosition" .. ply:UserID(), 0.01, 0, function()
			if not IsValid(ply) or not ply:KeyDown(IN_ATTACK2) then
				timer.Remove("UpdateCameraAndPosition" .. ply:UserID())
				return
			end
		
			if IsValid(nearestPlayer) then
				local eyePos = ply:EyePos()
				nearestPlayer:SetEyeAngles((eyePos - nearestPlayer:EyePos()):Angle())
				
				local vectorOffset = 50
				
				if ply:Crouching() then vectorOffset = 5 end
		
				local offset = (ply:EyeAngles():Forward() * 50)
				local newPos = ((ply:GetPos() + ply:EyePos()) / 2) + offset
		
				local traceData = {}
				traceData.start = (ply:GetPos() + ply:GetForward() * -50 + ply:EyePos()) / 2
				traceData.endpos = newPos
				traceData.mins = nearestPlayer:OBBMins()
				traceData.maxs = nearestPlayer:OBBMaxs()
				traceData.filter = {ply, nearestPlayer}
		
				local trace = util.TraceHull(traceData)
		
				if trace.Hit then
					-- Если игрок оказался внутри препятствия, уменьшаем расстояние
					local safeDistance = trace.Fraction * 50  -- Безопасная дистанция, где нет коллизии
					offset = (Vector(0, 0, vectorOffset)) + (ply:EyeAngles():Forward() * safeDistance)
					newPos = ply:GetPos() + offset
				end
				debugoverlay.Line(traceData.start, traceData.endpos, 0.05, Color(255, 0, 0), true)
				debugoverlay.Box( newPos, traceData.mins, traceData.maxs, 0.05, Color( 255, 255, 255, 20 ) )
		
				-- Устанавливаем новую позицию nearestPlayer
				nearestPlayer:SetPos(newPos)
			end
		end)
    end
end

hook.Add("KeyRelease", "PlayerRightClickRelease", function(ply, key)
	
    if key == IN_ATTACK2 then
        local target = playersHoldingRightClick[ply]
        if IsValid(target) then
            ply:EmitSound("throw_player.wav")
			playVoiceline('endo', 'throw', ply, 0.1)

            target:SetMoveType(MOVETYPE_WALK)
            target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
            noClipBlockedPlayers[target] = nil

            local direction = (target:GetPos() - (ply:GetPos() + (ply:EyeAngles():Up() * 50))):GetNormalized()

            target:SetVelocity(direction * 600)

            ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
            target:SetCollisionGroup(COLLISION_GROUP_WORLD)
		
			timer.Create("grabCooldown"..ply:EntIndex(), 1, 1, function()
			end)
					
			net.Start("fh_net_killer_change")
			net.WriteString("Grab")
			net.WriteFloat(1)
			net.Send(ply)

            timer.Simple(1, function()
                if IsValid(ply) then
                    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                end
                if IsValid(target) and noClipBlockedPlayers[target] == nil then
                    target:SetCollisionGroup(COLLISION_GROUP_PLAYER)
                end
            end)
        end
        playersHoldingRightClick[ply] = nil

        timer.Remove("UpdateCameraAndPosition" .. ply:UserID())
    end
end)

affectedPlayers = {}

if SERVER then

	function HighlightPlayers(ply)
		local totalPlayers = {}
		if !table.HasValue(haloUsers, ply) then -- чел не под кулдауном? разрешай
			table.insert(haloUsers, ply)
			
			net.Start("fh_net_killer_change")
			net.WriteString("Highlight")
			net.WriteFloat(conVars.halo_cooldown:GetFloat())
			net.Send(ply)
			
			timer.Simple(conVars.halo_cooldown:GetFloat(), function()
				table.RemoveByValue(haloUsers, ply)
			end)
		
			local affectedNicknames = {}
			for _, player in ipairs(player:GetAll()) do
				if player ~= ply and player:IsPlayer() and player:Health() > 0 and (player:Team() != TEAM_SPECTATOR and player:Team() != 2701) and player:IsValid() then
					local distance = ply:GetPos():Distance(player:GetPos())
					
					net.Start("PlayHighlightSounds") -- всем остальным кидаем звук прикольный
					net.WriteBool(distance <= conVars.halo_radius:GetInt())
					net.Send(player)
					
					if (distance <= conVars.halo_radius:GetInt()) then -- передаём чуваку кто подсвечивается в радиусе
						table.insert(affectedPlayers, player)
						table.insert(totalPlayers, player)
						table.insert(affectedNicknames, player:Nick())
						timer.Simple(conVars.halo_time:GetFloat(), function()
							table.RemoveByValue(affectedPlayers, player)
						end)
					end
				end
			end
		
			//ply:ChatPrint(table.concat(affectedNicknames, ', '))
					
			if table.Count(totalPlayers) > 0 then
				net.Start("AddAffectedPlayers")
				net.WriteTable(totalPlayers)
				net.Send(ply)
				if table.Count(team.GetPlayers(TEAM_SPECTATOR)) > 0 then
					net.Start('NotifySpectators')
					net.WriteTable(affectedNicknames)
					net.WriteEntity(ply)
					net.Broadcast()
				end
			end
						
			net.Start("ToggleHighlightSound") -- включаем чуваку звук что он дофига крутой со спермой под губой
			net.WriteBool(table.Count(totalPlayers) > 0)
			net.Send(ply)
		end
	end
	
	net.Receive("AddServerAffectedPlayers", function(len, ply)
		local players = net.ReadTable()
		for _, player in ipairs(players) do
			table.insert(affectedNicknames, player)
		end
	end)

	hook.Add("SetupPlayerVisibility", "SetupVisibilityForAffectedPlayers", function(ply, viewent)
		if table.Count(affectedPlayers) > 0 then
			for _, player in ipairs(affectedPlayers) do
				AddOriginToPVS(player:GetPos())
			end
		end
		if table.Count(team.GetPlayers(2701)) > 0 then
			for _, player in ipairs(team.GetPlayers(2701)) do
				AddOriginToPVS(player:GetPos())
			end
		end
	end)
	

	hook.Add( "PlayerDeath", "GlobalDeathMessage", function( victim, inflictor, attacker )
		if table.HasValue(affectedPlayers, victim) then
			table.RemoveByValue(affectedPlayers, victim)
			
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(victim)
			net.Broadcast()
		end
	end)
	

	hook.Add( "PlayerDisconnected", "RemoveAffected", function( ply )
		if table.HasValue(affectedPlayers, ply) then
			table.RemoveByValue(affectedPlayers, ply)
			
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(ply)
			net.Broadcast()
		end
	end)
	
	function killCupcakes(ply)
		if table.Count(cupcakes) == 0 then return end
		for _, index in pairs(cupcakes) do
			if ents.GetByIndex(index):GetOwner() == ply then
				ents.GetByIndex(index):Remove()
				table.RemoveByValue(cupcakes, 1)
			end
		end
	end
	
	hook.Add("EntityRemoved", "RemoveKilledCupcake", function(ent)
		if table.HasValue(cupcakes, ent:EntIndex()) then
			table.RemoveByValue(cupcakes, ent:EntIndex())
		end
	end)
end
	
hook.Add("PlayerNoClip", "BlockNoClipForHeldPlayer", function(ply, desiredState)
	if noClipBlockedPlayers[ply] then
		return false
	end
end)

function chaseCheck(ply, name)
	if ply:IsSprinting() and ply:GetVelocity():LengthSqr() > ply:GetRunSpeed() then
		local target = FindNearestPlayer(ply:GetPos(), 750, ply)
		
		if !IsValid(target) then return end
		if target:IsNPC() then return end
		
		if target:IsSprinting() and target:GetVelocity():LengthSqr() > target:GetWalkSpeed() then
	
			if timer.Exists( "ChaseCheck"..ply:EntIndex()) then return end
			
			playVoiceline(name, 'chase', ply, 1)
			
			timer.Create("ChaseCheck"..ply:EntIndex(), 14, 1, function() end) -- шобы войслайны не играли очень часто
			
		end
	end
end
