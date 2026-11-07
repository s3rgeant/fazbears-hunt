AddCSLuaFile()

foxy = foxy or {}

FOXY_MAX_RUSH_TOKENS = 5

--foxy
local stunned_foxy_movement_speed = {120, 120, 70, 100}

function StunnedFoxyMovementSpeed()
	return stunned_foxy_movement_speed
end

function foxy.IsBusy(ply)
	return ply:GetFoxyRushing() or ply:GetFoxyBouncing() or ply:GetFoxySession()
end

local model_prefix = IsHalloween() and "phantom" or "old"

if SERVER then
	util.PrecacheModel("models/speps/pill/" .. model_prefix .. "foxy.mdl")
end

pills.register("pill_wfoxy2",{
	printName="Withered Foxy",
	model="models/speps/pill/" .. model_prefix .. "foxy.mdl",
	class = "player_foxy",
		
	options=function() return {
		["default"] = {
			bodyGroups = { [0] = 1 }
		},
		["halloween"] = {
			-- ничего
		},
		["christmas"] = {
			bodyGroups = { 
				[0] = 1,
				[1] = 1,
			}
		},
	} end,
	option=IsHalloween() and "halloween" or IsChristmas() and "christmas" or "default",
	
	anims={
		default={
			idle="idle",
			crouch="crouch",
			crouch_walk="crouchmove",
			walk="walk",
			jump="jump",
			glide="air",
			run="run",
			laugh="taunt",
			land="land",
			scare="scare",
			stun="stun",
		},
		gestures={
			chargestun="chargestun",
			swing="preattack",
			melee="melee",
			
			jammerstun="jammerstun",
			damaged1="damaged1",
			damaged2="damaged2",
			damaged3="damaged3",
		},
		speedCap={
			walk=150,
			run=540,
		},
	},
	moveSpeed={
		walk=150,
		run=490,
		ducked=70,
	},
	sounds={
		jump="jump.mp3",
		regular_land="land.mp3",
		land="land.mp3",
		taunt="foxy_laugh.wav",
		melee=")fnaf2/xscream2.wav",
	},
	type="ply",
    camera = {
        offset = Vector(0, 0, 90),
		dist = 150
    },
	hull=Vector(32,32,86),
	duckBy=60,
	
	viewmodel={
		weapon="v_foxy",
		skin=IsHalloween() and 1 or 0
	},
	bloodType=BLOOD_COLOR_MECH,
	
    jumpPower=400,
	health=10000,
	
	muteSteps = true,
	movePoseMode="xy",
	aim = {
		xPose="aim_yaw",
		yPose="aim_pitch"
	},

	noFallDamage=true,
	
	initialize=function(ply,ent)
		ply:SetFoxyTokens(FOXY_MAX_RUSH_TOKENS)
		chaseVoicelineChecker(ply, ent, "foxy")
	end,
	
	killCondition=function(ply,ent)
		if foxy.IsBusy(ply) then return end
		
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
			
			if foxy.IsBusy(ply) then return end
			
			local target = FindNearestPlayer(ply:EyePos(), 125, ply, 36)
			
			local jumpscare = performJumpscare(ply, ent, target, 1.6, "foxy", 75, "v_foxy")
			
			if !IsValid(target) or !jumpscare then 
				if not AnimatronicBreakProp(ply, ent) then cooldown.SetSend(ply, "kill", 0.9) end
				return 
			end
		end
    },

	taunt=function(ply,ent,act)
		if act == ACT_GMOD_TAUNT_LAUGH and !ply:GetFoxySession() then
			if !ply:OnGround() then return end

			ent:PillAnim("laugh", true)
			ent:PillSound("taunt",false)

			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:HandleAnimation("laugh", 2)
			end
		end
	end,
	
	land=function(ply,ent, iw)
		if foxy.IsBusy(ply) then return end
		
		if AreLandConditionsGood(ply, ent) then
			ent:PillAnim("land",true)
		end
		
		landTripCheck(ply, ent, "foxy")
	end,

	reload=function(ply,ent)
		highlight.ByDistance(ply, ent)
	end,
	
	jump=function(ply,ent)
		ent:PillSound("jump",false)
	end,
	
	taserStun = function(ply, ent)
		if ply:GetFoxySession() then
			if ply.blightTimeoutTimer then
				timer.Remove(ply.blightTimeoutTimer)
			end
			ply:SetFoxySession(false)
			ply:SetFoxyRushing(false)
			ply:SetFoxyBouncing(false)
			
			if !timer.Exists("receiving_tokens" .. ply:EntIndex()) then
				receiveTokensBack(ply, ent)
			end
		end
	end,
	
	jammerStun = function(ply, ent)
		if ply:GetFoxySession() then
			if ply.blightTimeoutTimer then
				timer.Remove(ply.blightTimeoutTimer)
			end
			ply:SetFoxySession(false)
			ply:SetFoxyRushing(false)
			ply:SetFoxyBouncing(false)
			
			if !timer.Exists("receiving_tokens" .. ply:EntIndex()) then
				receiveTokensBack(ply, ent)
			end
		end
	end,
})

if SERVER then
	util.AddNetworkString("fh_net_killer_change_tokens")

	function receiveTokensBack(ply, ent)
		local tName = "receiving_tokens" .. ply:EntIndex()
		timer.Create(tName, 2.5, FOXY_MAX_RUSH_TOKENS, function()
			if not IsValid(ply) then timer.Remove(tName) return end
			if not IsValid(ent) then timer.Remove(tName) return end
		
			if ply:GetFoxyTokens() == FOXY_MAX_RUSH_TOKENS then
				timer.Remove("receiving_tokens" .. ply:EntIndex())
				return
			end

			ply:SetFoxyTokens(ply:GetFoxyTokens() + 1, ent)
			
			ply:SendLua("surface.PlaySound('buttons/blip1.wav')")
			
			net.Start("fh_net_killer_change_tokens")
			net.WriteString("charge")
			net.WriteInt(ply:GetFoxyTokens(), 9)
			net.Send(ply)
		end)
	end

	function stopReceivingTokens(ply)
		if not IsValid(ply) then return end
		timer.Remove("receiving_tokens" .. ply:EntIndex())
	end
	
	hook.Add("PlayerDisconnected", "BlightRush_Cleanup", function(ply)
		stopReceivingTokens(ply)
		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end
		StopBleeding(ply)
	end)

	hook.Add("PlayerDeath", "BlightRush_ResetOnDeath", function(ply)
		stopReceivingTokens(ply)
		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end
		StopBleeding(ply)
	end)

	hook.Add("PlayerSpawn", "BlightRush_ResetOnSpawn", function(ply)
		stopReceivingTokens(ply)
		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end
	end)
end


function foxy.Stun(ply)
	local ent = pills.getMappedEnt(ply)
	
	ply:SetFoxySession(false)
	ply:SetFoxyBouncing(false)
	ply:SetFoxyBlockM1(true)
	
	if !IsValid(ent) then return end
	
	if ent:GetPillName() == "pill_wfoxy2" then
		ent:ReplaceAnimation("glide", "air")
	end
	
	if SERVER then
		ent:SetSpeed(unpack(StunnedFoxyMovementSpeed()))
		ply:SetFOV(60, 0.5)
		ent:SetPlaybackRate(1)
		
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_foxy" then
			wep:AddAnimation("run", ACT_VM_SPRINT_IDLE)
		end
		
		timer.Create( "foxyUnstun" .. ply:EntIndex(), 3, 1, function()
			if not IsValid(ply) then return end	
			if IsValid(ent) then
				ent:SetDefaultSpeed()
			end
			ply:SetFOV(0, 0.5)
			
			ply:SetFoxyBlockM1(false)
		end)
	end
end

function foxy.UnStun(ply)
	timer.Remove( "foxyUnstun" .. ply:EntIndex() )
	
	local ent = pills.getMappedEnt(ply)
	if !IsValid(ent) then return end
	
	if not IsValid(ply) then return end	
	if SERVER then
		ent:SetDefaultSpeed()
		ply:SetFOV(0, 0.5)
	end
	
	ply:SetFoxyBlockM1(false)
end

--[[
			FOXY RUSH ABILITY
]]--

function FoxyCharge(ply, ent)
	if ent:GetNW2Bool("Jammered") then return end
	
	if not ply.GetFoxyRushing then return end
	if ply:GetFoxyRushing() then return end

	if not ply:OnGround() or ply:Crouching() then return end

	ply:SetFoxyBouncing(false)
	
	local dsp = IsHalloween() and 38 or 0
	local tokens = ply:GetFoxyTokens()
	local session = ply:GetFoxySession()

	if tokens == FOXY_MAX_RUSH_TOKENS then
		ply:SetFoxyBlockM1(true)
		
		if IsFirstTimePredicted() then
			ply:EmitSound("vo/foxy_charge1.mp3", 75, 100, 1, CHAN_AUTO, 0, dsp)
		end
		
		if SERVER then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:AddAnimation("run", ACT_MP_RUN_MELEE)
			end
		end
	elseif tokens == 4 and session then
		if IsFirstTimePredicted() then
			ply:EmitSound("vo/foxy_charge2.mp3", 75, 100, 1, CHAN_AUTO, 0, dsp)
		end
	end

	if not session and tokens ~= FOXY_MAX_RUSH_TOKENS then return end
	if tokens <= 0 then return end
	
	if tokens <= 4 then
		ply:SetFoxyBlockM1(false)
	
		if SERVER then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:AddAnimation("run", ACT_VM_SPRINT_IDLE)
			end
		end
	end
	
	if CLIENT and IsFirstTimePredicted() then
		RemoveRMBHint()
	end
	
	if ent:GetPillName() == "pill_wfoxy2" then
		ent:ReplaceAnimation("glide", "freeglide")
	end

	ply:SetFoxySession(true)
	ply:SetFoxyTokens(tokens - 1, ent)
	ply:SetFoxyRushing(true)
	
	ply:SetFOV(100, 0.5)
	
	local rushDuration = 5
	ply:SetFoxyRushEnd(CurTime() + rushDuration)

	if ply.blightTimeoutTimer then
		timer.Remove(ply.blightTimeoutTimer)
		ply.blightTimeoutTimer = nil
	end

	if SERVER then
		cooldown.Send(ply, "charge")
		stopReceivingTokens(ply)
		
		net.Start("fh_net_killer_change_tokens")
		net.WriteString("charge")
		net.WriteInt(ply:GetFoxyTokens(), 9)
		net.Send(ply)
	end
end

function foxy.EndCharge(ply)
	ply:SetFoxyRushing(false)

	if SERVER then
		local ent = ply:GetPillCostume()
		receiveTokensBack(ply, ent)
	end

	foxy.Stun(ply)
end

hook.Add("FuncDoorBust", "fh_charge_doorbust", function(ply, door)
	local pill = pills.getMappedEnt(ply)
	if not IsValid(pill) then return end

	if ply.GetFoxyRushing and ply:GetFoxyRushing() then
		breakBustDoor(ply, door)
	end
end)

hook.Add("StartCommand", "BlightCancelJumpPress", function(ply, cmd)
		
	if not ply.GetFoxyRushing then return end
	
    if ply:GetFoxyRushing() then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_JUMP)
		cmd:AddKey(IN_SPEED)
	end
	
	if not ply.GetFoxySession then return end
	if not ply.GetFoxyBouncing then return end
	
    if ply:GetFoxySession() and ply:GetFoxyBouncing() then
		cmd:RemoveKey(IN_SPEED)
		cmd:RemoveKey(IN_JUMP)
		cmd:RemoveKey(IN_DUCK)
	end
	
	if not ply.GetFoxyBlockM1 then return end

	if ply:GetFoxyBlockM1() then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

local YAW_LIMIT_DPS = 100
local YAW_LIMIT_DPS_ATTACK = 200

if CLIENT then
	local lastAng
	
	hook.Add("CreateMove", "limit_mouse_foxy", function(cmd)
		local ply = LocalPlayer()
	
		if not ply.GetFoxyRushing or not ply.GetFoxyBlockM1 then return end
		
		if not IsValid(ply) or not ply:GetFoxyRushing() then
			lastAng = nil
			return
		end
	
		local ang = cmd:GetViewAngles()
	
		if not lastAng then
			lastAng = Angle(ang.p, ang.y, ang.r)
			return
		end
	
		local attackHeld = cmd:KeyDown(IN_ATTACK) and !ply:GetFoxyBlockM1()
		local maxDelta = (attackHeld and YAW_LIMIT_DPS_ATTACK or YAW_LIMIT_DPS) * RealFrameTime()
	
		local dy = math.AngleDifference(ang.y, lastAng.y)
	
		if dy > maxDelta then dy = maxDelta
		elseif dy < -maxDelta then dy = -maxDelta end
	
		ang.y = lastAng.y + dy
		cmd:SetViewAngles(ang)
	
		lastAng.y = ang.y
		lastAng.p = ang.p
		lastAng.r = 0
	end)
	
	hook.Add("PlayerBindPress", "limit_left_right_foxy", function(ply, bind)
		if not ply.GetFoxyRushing then return end
		if ply:GetFoxyRushing() then
			if string.find( bind, "+left" ) or string.find( bind, "+right" ) then
				return true
			end
		end
	end)
end

local DamageTimers = {}
local DecalTimers = {}

function StartBleeding(ply, dealer)
	if not IsValid(ply) then return end
	
	local steamID = ply:SteamID()
	
	if DamageTimers[steamID] then return end
	
	local timerName = "DamagePlayer_" .. steamID
	DamageTimers[steamID] = timerName
	
	local decaltimerName = "DecalPlayer_" .. steamID
	DecalTimers[steamID] = decaltimerName
	
	timer.Create(timerName, 1, 0, function()
		if not IsValid(ply) or !ply:Alive() or !ply:IsSurvivor() then
			StopBleeding(ply)
			return
		end
	
		local dmg = DamageInfo()
		dmg:SetDamage(2)
		dmg:SetAttacker(IsValid(dealer) and dealer or game.GetWorld())
		dmg:SetDamageType(DMG_GENERIC)
		ply:TakeDamageInfo(dmg)
	end)
	
	timer.Create(decaltimerName, 0.2, 0, function()
		if not IsValid(ply) or !ply:Alive() or !ply:IsSurvivor() then
			StopBleeding(ply)
			return
		end
	
		local pos = ply:GetPos()
		local tr = util.TraceLine({
			start = pos + Vector(0, 0, 10),
			endpos = pos - Vector(0, 0, 100),
			filter = ply
		})
	
		if tr.Hit then
			util.Decal("Blood", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
		end
	end)
end

function StopBleeding(ply)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local steamID = ply:SteamID()
	local timerName = DamageTimers[steamID]
	local decaltimerName = DecalTimers[steamID]

	if timerName then
		timer.Remove(timerName)
		DamageTimers[steamID] = nil
	end

	if decaltimerName then
		timer.Remove(decaltimerName)
		DecalTimers[steamID] = nil
	end
end