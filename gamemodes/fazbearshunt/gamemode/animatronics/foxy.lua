AddCSLuaFile()

local MAX_RUSH_TOKENS = 5

if SERVER then
	util.AddNetworkString("fh_net_killer_change_tokens")

	function receiveTokensBack(ply)
		timer.Create("receiving_tokens" .. ply:EntIndex(), 2.5, 5, function()
			if not IsValid(ply) then return end
			if ply.blightRushTokens == MAX_RUSH_TOKENS then
				timer.Remove("receiving_tokens" .. ply:EntIndex())
				return
			end

			ply.blightRushTokens = ply.blightRushTokens + 1
			
			ply:SendLua("surface.PlaySound('buttons/blip1.wav')")
			
			net.Start("fh_net_killer_change_tokens")
			net.WriteString("charge")
			net.WriteInt(ply.blightRushTokens, 9)
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

		ply:SetNWBool("isBlightRushing", false)
		ply:SetNWBool("isBlightBouncing", false)
		ply:SetNWBool("Blight_BlockM1", false)
		StopBleeding(ply)
	end)

	hook.Add("PlayerSpawn", "BlightRush_ResetOnSpawn", function(ply)
		stopReceivingTokens(ply)
		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end

		ply:SetNWBool("isBlightRushing", false)
		ply:SetNWBool("isBlightBouncing", false)
		ply:SetNWBool("Blight_BlockM1", false)
	end)
end

function foxyStun(ply)
	local ent = pills.getMappedEnt(ply)
		
	ply:SetNWBool("blightRushing", false)
	ply:SetNWBool("Blight_BlockM1", true)
	
	if !IsValid(ent) then return end
	
	if SERVER then
	ent:SetSpeed(unpack(StunnedFoxyMovementSpeed()))
	ply:SetFOV(60, 0.5)
	end
	
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "v_foxy" then
		wep:AddAnimation("run", ACT_VM_SPRINT_IDLE)
	end
	
	timer.Simple(3, function()
		if not IsValid(ply) then return end	
		if IsValid(ent) and SERVER then
			ent:SetDefaultSpeed()
		end
		ply:SetFOV(0, 0.5)
		
		ply:SetNWBool("Blight_BlockM1", false)
	end)
end

--[[
			FOXY RUSH ABILITY
]]--
function foxyRush(ply, ent)
	if ply:GetNWBool("isBlightRushing") then return end

	if not ply:OnGround() or ply:Crouching() then return end

	if ply:GetNWBool("isBlightBouncing") then
		ply:SetNWBool("isBlightBouncing", false)
	end
	
	local dsp = IsHalloween() and 38 or 0

	if not ply.blightRushTokens or ply.blightRushTokens == MAX_RUSH_TOKENS then
		ply.blightRushTokens = MAX_RUSH_TOKENS
		ply:SetNWBool("Blight_BlockM1", true)
		
		if SERVER then
			ply:EmitSound("vo/foxy_charge1.mp3", 75, 100, 1, CHAN_AUTO, 0, dsp)
		
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:AddAnimation("run", ACT_MP_RUN_MELEE)
			end
		end
	elseif ply.blightRushTokens == 4 and ply:GetNWBool("blightRushing") and SERVER then
		ply:EmitSound("vo/foxy_charge2.mp3", 75, 100, 1, CHAN_AUTO, 0, dsp)
	end

	if ply.blightRushTokens ~= MAX_RUSH_TOKENS and not ply:GetNWBool("blightRushing") then return end
	
	if ply.blightRushTokens <= 4 then
		ply:SetNWBool("Blight_BlockM1", false)
	
		if SERVER then
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep:AddAnimation("run", ACT_VM_SPRINT_IDLE)
			end
		end
	end
	
	if CLIENT then
		RemoveRMBHint()
	end

	if SERVER then
		net.Start("fh_net_killer_change")
		net.WriteString("charge")
		net.WriteFloat(0)
		net.Send(ply)
	end

	ply:SetNWBool("blightRushing", true)
	ply:SetFOV(100, 0.5)
	ply.blightRushTokens = ply.blightRushTokens - 1
	ply:SetNWBool("isBlightRushing", true)
	if SERVER then
		stopReceivingTokens(ply)
	end
	ply.puppet = ent
	
	local rushDuration = 3.5
	ply:SetNWFloat("RushEndTime", CurTime() + rushDuration)

	if ply.blightTimeoutTimer then
		timer.Remove(ply.blightTimeoutTimer)
		ply.blightTimeoutTimer = nil
	end

	if SERVER then
		net.Start("fh_net_killer_change_tokens")
		net.WriteString("charge")
		net.WriteInt(ply.blightRushTokens, 9)
		net.Send(ply)
	end
end

local function BlightCheckCollision(ply)
	local velocity = ply:GetVelocity()
	velocity.z = 0

	local eyeDir = ply:EyeAngles():Forward()
	eyeDir.z = 0
	eyeDir:Normalize()

	local speedDir = velocity:GetNormalized()
	local dot = eyeDir:Dot(speedDir)

	local startPos = ply:GetPos() + Vector(0, 0, ply:GetStepSize())
	local traceDist = 30
	local hullSize = 8
	
	local tr = util.TraceLine( {
		start = ply:GetPos() + Vector(0, 0, ply:GetStepSize()),
		endpos = startPos + eyeDir * traceDist,
		filter = ply
	} )
	tr.startPos = startPos
	
	--debugoverlay.Line( ply:GetPos() + Vector(0, 0, ply:GetStepSize()), startPos + speedDir * traceDist )
	
	if tr.Hit then return tr end

	local tr = util.TraceHull({
		start = startPos,
		endpos = startPos + speedDir * traceDist,
		mins = Vector(-hullSize, -hullSize, 0),
		maxs = Vector(hullSize, hullSize, ply:OBBMaxs().z * 0.8),
		filter = ply
	})
	
	--debugoverlay.Box( startPos + speedDir * traceDist, Vector(-hullSize, -hullSize, 0), Vector(hullSize, hullSize, ply:OBBMaxs().z * 0.8), 3, tr.Hit and Color(0, 255, 0) or Color(255,0,0))

	tr.startPos = startPos
	return tr
end

function EndRush(ply)
	ply:SetNWBool("isBlightRushing", false)

	if SERVER then
		receiveTokensBack(ply)
		foxyStun(ply)
	end
end

hook.Add("SetupMove", "BlightPredictionMove", function(ply, mv, cmd)

	if not ply:GetNWBool("isBlightRushing") then return end
	
	if !ply:OnGround() then return end
	
	local rushEnd = ply:GetNWFloat("RushEndTime", 0)
	if CurTime() > rushEnd or ply:WaterLevel() >= 2 or ply:Crouching() then
		EndRush(ply) 
		if SERVER then 
			playVoiceline('foxy', 'miss', ply)
		end
		return
	end

	local dir = mv:GetMoveAngles():Forward()
	dir.z = 0
	dir:Normalize()

	mv:SetVelocity(dir * 900)
	mv:SetMaxClientSpeed(900)
	mv:SetMaxSpeed(900)

	mv:SetForwardSpeed(1000)

	local wep = ply:GetViewModel(0)
	if IsValid(wep) and not wep.IsCharging then
		wep:SetPlaybackRate(1.3)
	end
end)

hook.Add("SetupMove", "BlightPredictionBounce", function(ply, mv, cmd)
	
	if !IsFirstTimePredicted() then return end
	
	if ply:GetNWBool("isBlightBouncing") then
		local startTime = ply:GetNWFloat("BlightBounceStart", 0)
		local endTime = ply:GetNWFloat("BlightBounceEnd", 0)
		local t = CurTime()

		if t >= endTime or !ply:OnGround() then
			ply:SetNWBool("isBlightBouncing", false)
			return
		end

		local progress = (t - startTime) / math.max(endTime - startTime, 0.01)
		local ease = 1 - (progress ^ 2)

		local dir = ply.blightBounceDir or Vector(0, 0, 0)
		local speed = 500 * ease
		local vel = dir * speed

		mv:SetVelocity(vel)

        mv:SetForwardSpeed(speed)

		if CLIENT and ply == LocalPlayer() then
			ply:SetLocalVelocity(vel)
		end
	end
end)

hook.Add("FinishMove", "BlightPredictionFinish", function(ply, mv)
	if not ply:GetNWBool("isBlightRushing") or ply:KeyDown(IN_ATTACK) then return end

	ply:LagCompensation(true)
	local tr = BlightCheckCollision(ply)
	ply:LagCompensation(false)
	
	if tr.Hit and (!IsValid(tr.Entity) or not tr.Entity:IsPlayer() or tr.Entity:IsAnimatronic()) then
		
		if CLIENT and tr.Entity ~= game.GetWorld() then
			return
		end
		
		if IsValid(tr.Entity) and !tr.Entity:IsPlayer() then
		
			local ent = tr.Entity
			local physobj = ent:GetPhysicsObject()
			if IsValid(physobj) and ent:Health() > 0 then
				local wep = ply:GetActiveWeapon()
				
				local dmginfo = DamageInfo()
				dmginfo:SetAttacker(ply)
				dmginfo:SetInflictor(IsValid(wep) and wep or ply)
				dmginfo:SetDamage(100)
			
				SuppressHostEvents(NULL)
				ent:TakeDamageInfo(dmginfo)
				SuppressHostEvents(ply)
				
				return
			end
			
			if tr.Entity:GetClass() == "prop_door_rotating" then
				breakBustDoor(ply, tr.Entity)
				return
			end
		end
		
		local bounceDuration = 0.35
		local bounceDir = tr.HitNormal
		bounceDir.z = 0
		bounceDir:Normalize()

		if IsFirstTimePredicted() then
			ply:SetNWFloat("BlightBounceStart", CurTime())
			ply:SetNWFloat("BlightBounceEnd", CurTime() + bounceDuration)
		
			ply:SetNWBool("isBlightRushing", false)
			ply:SetNWBool("isBlightBouncing", true)
			ply.blightBounceDir = bounceDir
			ply:SetVelocity(bounceDir * 500)
		end
		
		if CLIENT then
			if getAbilityTokens("charge") > 0 then
				RMBHint(2)
			end
		end

		if SERVER then
			ply:EmitSound("blight/impact.wav")

			if IsValid(ply.puppet) then
				ply.puppet:PillGesture("chargestun", 1, 0.8, 0.1, 0.3)
			end
		end

		local effectData = EffectData()
		effectData:SetOrigin(tr.HitPos + Vector(0,0,32))
		effectData:SetStart(tr.startPos)
		effectData:SetEntity(tr.Entity or ply)
		effectData:SetNormal(tr.HitNormal)
		effectData:SetSurfaceProp(tr.SurfaceProps or 0)
		effectData:SetDamageType(DMG_CLUB)
		effectData:SetHitBox(tr.HitBox or 0)
		effectData:SetScale(1)
		util.Effect("Impact_GMOD", effectData, true, true)
		
		if ply.blightRushTokens == 0 then
			EndRush(ply)
			return
		end
		
		if CLIENT then return end

		ply.blightTimeoutTimer = "BlightTimeout_" .. ply:SteamID()
		timer.Create(ply.blightTimeoutTimer, 2, 1, function()
			if not IsValid(ply) then return end
			ply.blightTimeoutTimer = nil
		
			foxyStun(ply)
			
			playVoiceline('foxy', 'miss', ply)

			timer.Simple(5, function()
				if IsValid(ply) then
					receiveTokensBack(ply)
				end
			end)
		end)
	end
end)

hook.Add("StartCommand", "BlightCancelJumpPress", function(ply, cmd)
    if ply:GetNWBool("isBlightRushing") or ply:GetNWBool("isBlightBouncing") or ply.blightTimeoutTimer then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_JUMP)
		cmd:AddKey(IN_SPEED)
	end

	if ply:GetNWBool("Blight_BlockM1") then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

local YAW_LIMIT_DPS = 60
local YAW_LIMIT_DPS_ATTACK = 140

if CLIENT then
    local lastAng

    hook.Add("StartCommand", "limit_mouse_foxy", function(ply, cmd)
		if ply:GetNWBool("isBlightRushing") then
			local ang = cmd:GetViewAngles()

			if not lastAng then
				lastAng = Angle(ang.p, ang.y, ang.r)
				return
			end

			local maxDelta = ( (ply:KeyDown(IN_ATTACK) and !ply:GetNWBool("Blight_BlockM1")) and YAW_LIMIT_DPS_ATTACK or YAW_LIMIT_DPS ) * RealFrameTime()

			local dy = math.AngleDifference(ang.y, lastAng.y)

			if dy > maxDelta then dy = maxDelta
			elseif dy < -maxDelta then dy = -maxDelta end

			ang.y = lastAng.y + dy
			cmd:SetViewAngles(ang)

			lastAng.y = ang.y
			lastAng.p = ang.p
			lastAng.r = 0
			return
		end
		lastAng = nil
    end)
	
	hook.Add("PlayerBindPress", "limit_left_right_foxy", function(ply, bind)
		if ply:GetNWBool("isBlightRushing") then
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

		if ply._damagePausedUntil and CurTime() < ply._damagePausedUntil then
			return
		end

		local dmg = DamageInfo()
		dmg:SetDamage(2)
		dmg:SetAttacker(IsValid(dealer) and dealer or game.GetWorld())
		dmg:SetDamageType(DMG_GENERIC)
		ply:TakeDamageInfo(dmg)
	end)

	timer.Create(decaltimerName, 0.5, 0, function()
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

function PauseBleeding(ply, duration)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply._damagePausedUntil = CurTime() + duration
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

    ply._damagePausedUntil = nil
end