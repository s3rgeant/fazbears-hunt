AddCSLuaFile()

if SERVER then
	util.PrecacheModel("models/fh/animatronics/UFMP/WitheredChica.mdl")
end

local CUPCAKE_CLASS = "cakemine" --"fh_cupcake"
local cupcakes = {} 

pills.register("pill_wchica2",{
	printName="Withered Chica",
	model="models/fh/animatronics/UFMP/WitheredChica.mdl",
	modelScale="1.4",
	--[[	
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
	]]--
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			run="run",
			cloak="special1",
			jump="jump",
			glide="glide",
			land="land",
			scare="scare",
			stun="stun",
		},
		gestures={
			melee="melee",
		},
	},
	moveSpeed={
		walk=114,
		run=485,
		ducked=80,
	},
	sounds={
		jump="jump.mp3",
		land="land.mp3",
		melee=")fnaf2/xscream2.wav",
		deploy=")chica_deploycake.wav",
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
	
	initialize=function(ply, ent)
		chaseVoicelineChecker(ply, ent, "chica")
		ent:SetFlexWeight( 0, .6 )
	end,
	restore=function(ply, ent)
		if SERVER then
			killCupcakes(ply)
		end
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
			if cooldown.Exists(ply, "kill") then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "chica", 50)
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end
    },
	
	attack2={
		mode="trigger",
		func = function(ply, ent)
			ChicaDeployCupcake(ply, ent)
		end,
	},
	
	postPropMelee = function(ply, ent)
		ply:ViewPunch( Angle( 10, 0, 0 ) )
	end,
	
	land=function(ply,ent)
		if AreLandConditionsGood(ply, ent) then
			ent:PillAnim("land",true)
		end
		
		landTripCheck(ply, ent, "chica")
	end,
	
	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump", false)
	end,
})

function ChicaDeployCupcake(ply, ent)
	if cooldown.Exists(ply, "mine") then return end
	if !cupcakes[ply] then cupcakes[ply] = 0 end
	
	if cupcakes[ply] < conVars.fh_max_cupcakes:GetInt() then
		cooldown.Set(ply, "mine", 15)
		cooldown.Send(ply, "mine")
		
		local playerPos = ply:GetPos()
		local spawnPos = playerPos + ply:GetUp() * 10
		local cupcake = ents.Create( CUPCAKE_CLASS )
		
		if not IsValid(cupcake) then return end
		
		ent:EmitSound('chica_deploycake.wav')

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
	
hook.Add( "PlayerDisconnected", "fh_pill_wchica_cupcakes", function( ply )
	killCupcakes(ply)
end)
	
function killCupcakes(ply)
	if table.IsEmpty(cupcakes) or !cupcakes[ply] then return end
	for _, ent in ipairs( ents.FindByClass( CUPCAKE_CLASS ) ) do
		if ent:GetOwner() == ply then
			ent:Remove()
		end
	end
	cupcakes[ply] = nil
end

local fh_cupcake_blast = CreateConVar( "fh_cupcake_blast", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Should Chica's cupcakes blast damage when destroyed?" )
	
hook.Add("EntityRemoved", "RemoveKilledCupcake", function(ent)
	if ent:GetClass() == CUPCAKE_CLASS then
		local owner = ent:GetOwner() 
		
		if fh_cupcake_blast:GetBool() then
			util.BlastDamage( ent, IsValid(owner) and owner or ent, ent:GetPos(), 300, math.Clamp( 300, 0, 1500 ) )
		end
		
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