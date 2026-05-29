AddCSLuaFile()

if SERVER then
end

shadow_freddyability = CreateConVar( "fh_sfreddy_noclip", "1", { FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED }, 
"Should Shadow Freddy Noclip or just slide throught objects while being invisible?" )

--[[
	КД на убийство когда вышел из ноуклипа; 	когда вошёл в ноуклип;		когда вышел из него
]]
local sfreddy_cooldowns = {1.5, 7, 7.5}

-- ХОДЬБА, БЕГ, ВПРИСЯДИ, СИЛА ПРЫЖКА
local sfreddy_default_movement = {100, 100, 65, 250} -- обычное передвижение
local sfreddy_noclip_movement = {500, 600, 500, 250} -- это на случай если - fuppr_sfreddy_noclip 0

pills.register("pill_sfreddy2",{
	printName="Shadow Freddy",
	model="models/speps/pill/oldgoldenfreddy.mdl",
		
	options=function() return {
		["default"] = {
			skin = 1,
		},
		["halloween"] = {
			skin = 2,
		}
	} end,
	option=IsHalloween() and "halloween" or "default",

	bodyGroups={[12] = 1},
	
	anims={
		default={
			idle="sidle",
			crouch="scrouch",
			crouch_walk="scrouchmove",
			walk="swalk",
			run="srun",
			cloak="sdisappear",
			uncloak="sappear",
			jump="sjump",
			glide="sglide",
			scare="sscare",
			stun="sstun",
		},
		gestures={
			melee="melee",
			land="land",
		},
		speedCap={
			walk=90,
		},
	},
	moveSpeed={
		walk=sfreddy_default_movement[1],
		run=sfreddy_default_movement[2],
		ducked=sfreddy_default_movement[3],
	},
	sounds={
		jump="sfreddylunge.mp3",
		land_snd="sfreddyland.mp3",
		melee=pills.helpers.makeList("fnaf2/sxscream.wav",2),
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_freddy",
		skin=IsHalloween() and 4 or 2,
		func=function(wep)
			wep:AddAnimation("walk", nil, "slowwalk")
		end
	},
	
	cloak={
		max=-1
	},
    jumpPower=sfreddy_default_movement[4],
	health=10000,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},
	bloodType=BLOOD_COLOR_MECH,
	
	muteSteps = true,

	noFallDamage=true,
	restore=function(ply,ent)
		ply:SetPushBlocked(false)
		ply._SF_TouchedFloor_Uncloaked = nil
	end,
	
	startFunction=function(ply,ent)
		chaseVoicelineChecker(ply, ent, "sfreddy")
		ply._SF_TouchedFloor_Uncloaked = true
	end,
	
	killCondition=function(ply,ent)
		if ply:GetMoveType() == MOVETYPE_NOCLIP then return false end
		if cooldown.Exists(ply, "kill") then return false end
		local target = FindNearestPlayer(ply:EyePos(), 130, ply, 36)
		
		if IsValid(target) and !target:IsInvisible() and !target:IsJumpscared() then
			return true
		end
		return false
	end,
	
	attack={
		mode="trigger",
		func=function(ply,ent)
			if ent.cloaked or cooldown.Exists(ply, 'kill') then return end
			
			if IsValid(ply:GetEntityInUse()) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 130, ply, 36)
			
			local jumpscare
			
			if ply._SF_TouchedFloor_Uncloaked then
				jumpscare = performJumpscare(ply, ent, target, 1.6, "sfreddy", 52, "v_freddy")
			end
			
			if !IsValid(target) or !jumpscare then 
				AnimatronicBreakProp(ply, ent)
				return 
			end
		end
    },
	 
	attack2={
		mode="trigger",
		func = function(ply,ent)
			if cooldown.Exists(ply, 'submerge') then return end
			
			ply:LagCompensation( false )

			if !ply:KeyDown(IN_USE) then
			
				if ent.cloaked then
					local trace = util.TraceHull({
						start = ply:GetPos(),
						endpos = ply:GetPos(),
						mins = ply:OBBMins(),
						maxs = ply:OBBMaxs(),
						filter = ply,
						mask = MASK_PLAYERSOLID,
					})
					
					if trace.Hit then
						net.Start("fh_play_sound")
						net.WriteString('sfreddyerror.wav')
						net.Send(ply)
						return 
					end
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:HandleAnimation("draw", 0.5)
					end
					
					ply:DrawViewModel(true)
					ply:SetPushBlocked(false)
					ply:EmitSound("sfreddyout.mp3")
					
					ent.cloaked=false
					
					hook.Run("FH_SFreddySubmergeOut", ply, ent)
	
					ent:ToggleCloak()
						
					timer.Remove("ext" .. ply:EntIndex())
							
					ply:SetMoveType( MOVETYPE_WALK )
							
					ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
					
					if SERVER then
						if ply:OnGround() then
							cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
							cooldown.Send(ply, "kill")
							
							ply._SF_TouchedFloor_Uncloaked = true
						end
						
						timer.Simple(0.1, function()
							if ply:OnGround() and !ply._SF_TouchedFloor_Uncloaked then
								cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
								cooldown.Send(ply, "kill")
								
								ply._SF_TouchedFloor_Uncloaked = true
							end
						end)
					
						cooldown.Set(ply, "submerge", sfreddy_cooldowns[3])
						cooldown.Send(ply, "submerge")
					end
					
					ent:SetSpeed( unpack(sfreddy_default_movement) )
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.2, 1, function()
						if !IsValid(ent) then return end
						
						ent:PillAnim("uncloak")
						ent:SetMaterial()
						ent:DrawShadow(true)
					end)
				else
					if !ply:OnGround() and ply:WaterLevel() == 0 and !ply:IsStuck() then return end
					if !IsValid(ent) then return end
					cooldown.Set(ply, "submerge", sfreddy_cooldowns[2])
					cooldown.Send(ply, "submerge")
					
					ply:EmitSound("sfreddyin.mp3")
					ply:SetPushBlocked(true)
			
					local wep = ply:GetActiveWeapon()
					if IsValid(wep) and wep:GetClass() == "v_freddy" then
						wep:HandleAnimation("deploy", 99999)
					end
					
					ent:PillAnim("cloak")
					
					ply:SetJumpPower( 0 )
					
					timer.Create( "ext" .. ply:EntIndex(), 0.2, 0, function() 
						if !IsValid(ent) then return end
						if ply:Health() < 1000 then ply:SetHealth(ply:Health()+1) end
						if ent:IsOnFire() then ent:Extinguish() end
						if ply:IsOnFire() then ply:Extinguish() end
					end)
					
					ent.cloaked=true
					
					hook.Run("FH_SFreddySubmergeIn", ply, ent)
					ent:ToggleCloak()
					
					timer.Create("Cloacking"..ply:EntIndex(), 0.55, 1, function()
						if !IsValid(ent) then return end
						ply:DrawViewModel(false)
					
						ply._SF_TouchedFloor_Uncloaked = false
						
						if shadow_freddyability:GetInt() == 0 then
							ent:SetSpeed( unpack(sfreddy_noclip_movement) )
						end
						if shadow_freddyability:GetInt() == 1 then
							ply:SetMoveType( MOVETYPE_NOCLIP )
						end
						
						ent:SetMaterial("models/null")
						ent:DrawShadow(false)
						
						ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS )
						
						hook.Run("FH_SFreddySubmergePostIn", ply, ent)
					end)
				end
			end
			ply:LagCompensation( true )
		end
	},
	
	land=function(ply,ent)
		if ent.cloaked then return end
		
		if !ply._SF_TouchedFloor_Uncloaked then
			cooldown.Set(ply, "kill", sfreddy_cooldowns[1])
			cooldown.Send(ply, "kill")
			
			ply._SF_TouchedFloor_Uncloaked = true
		end
		
		ent:PillGesture('land', 2, 1, 0, 0.5)
		ent:PillSound("land_snd", false)
		landTripCheck(ply, ent, "sfreddy")
	end,
 
	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		if ent.cloaked then return end
		ent:PillSound("jump",false)
	end
})

--[[
local currentSpeed = 150
local baseSpeed = 100
local maxSpeed = 200
local accel = 100
local shiftAccel = 2000
local shiftMax = 600

hook.Add("Move", "shadow_freddy_movement", function(ply, mv)
	if IsValid(ply:GetPill()) and ply:GetPill():GetPillName() ~= "pill_sfreddy2" then return end
	
	if ply:GetMoveType() ~= MOVETYPE_NOCLIP then return end

	local ft = FrameTime()
	local isMoving = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0 or mv:GetUpSpeed() ~= 0
	local isShift = mv:KeyDown(IN_SPEED)

	local targetMax = isShift and shiftMax or maxSpeed
	local targetAccel = isShift and shiftAccel or accel

	if isMoving then
		currentSpeed = math.min(currentSpeed + targetAccel * ft, targetMax)
	else
		currentSpeed = math.max(currentSpeed - targetAccel * 2 * ft, baseSpeed)
	end

	local ang = mv:GetMoveAngles()
	local pos = mv:GetOrigin()
	local dir = Vector(0, 0, 0)

	dir = dir + ang:Forward() * (mv:GetForwardSpeed() / 100)
	dir = dir + ang:Right() * (mv:GetSideSpeed() / 100)
	dir = dir + ang:Up() * (mv:GetUpSpeed() / 100)

	if dir:IsZero() and !mv:KeyDown(IN_JUMP) then
		mv:SetVelocity(Vector(0, 0, 0))
		currentSpeed = 250
		return true
	end
	
	if mv:KeyDown(IN_JUMP) then dir = dir + ply:GetUp()*100 end

	dir:Normalize()

	local vel = dir * currentSpeed
	pos = pos + vel * ft

	mv:SetVelocity(vel)
	mv:SetOrigin(pos)

	return true
end)

--]]