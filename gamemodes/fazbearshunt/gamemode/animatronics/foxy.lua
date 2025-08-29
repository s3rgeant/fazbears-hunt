AddCSLuaFile()

if SERVER then
	util.AddNetworkString("BlightRush_Start")
	util.AddNetworkString("BlightRush_End")
	util.AddNetworkString("fh_net_killer_change_tokens")

	local MAX_RUSH_TOKENS = 5

	function receiveTokensBack(ply)
		timer.Create("receiving_tokens" .. ply:EntIndex(), 4, 5, function()
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

	local function stopReceivingTokens(ply)
		if not IsValid(ply) then return end
		timer.Remove("receiving_tokens" .. ply:EntIndex())
	end

	function foxyStun(ply)
		local ent = pills.getMappedEnt(ply)
			
		ply.blightRushing = false
		ply:SetNWBool("Blight_BlockM1", true)
		
		if !IsValid(ent) then return end
		
		ent:SetSpeed(unpack(StunnedFoxyMovementSpeed()))
		ply:SetFOV(60, 0.5)
		
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "v_foxy" then
			wep.run_string = "run"
			wep.run_act = ACT_VM_SPRINT_IDLE
		end
		
		timer.Simple(3, function()
			if not IsValid(ply) then return end	
			if IsValid(ent) then
				ent:SetSpeed(unpack(FoxyMovementSpeed()))
			end
			ply:SetFOV(0, 0.5)
			
			ply:SetNWBool("Blight_BlockM1", false)
		end)
	end

	--[[
				FOXY RUSH ABILITY
	]]--
	function foxyRush(ply, ent)
		if ply.isBlightRushing or ply.isBlightBouncing then return end
		if not ply:OnGround() or ply:Crouching() then return end

		if not ply.blightRushTokens or ply.blightRushTokens == MAX_RUSH_TOKENS then
			ply.blightRushTokens = MAX_RUSH_TOKENS
			ply:SetNWBool("Blight_BlockM1", true)
			
			ply:EmitSound("blight/first_rush.wav")
		
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep.run_string = "weakrun"
				wep.run_act = ACT_MP_RUN_MELEE
			end
		elseif ply.blightRushTokens == 4 and ply.blightRushing then
			ply:EmitSound("blight/rushing_lethal.wav")
		end

		if ply.blightRushTokens ~= MAX_RUSH_TOKENS and not ply.blightRushing then return end
		
		if ply.blightRushTokens <= 4 then
			ply:SetNWBool("Blight_BlockM1", false)
		
			local wep = ply:GetActiveWeapon()
			if IsValid(wep) and wep:GetClass() == "v_foxy" then
				wep.run_string = "run"
				wep.run_act = ACT_VM_SPRINT_IDLE
			end
		end
		
		ply:SendLua("RemoveRMBHint()")

		net.Start("fh_net_killer_change")
		net.WriteString("charge")
		net.WriteFloat(0)
		net.Send(ply)

		ply.blightRushing = true
		ply:SetFOV(100, 0.5)
		ply.blightRushTokens = ply.blightRushTokens - 1
		ply.isBlightRushing = true
		ply:SetNWBool("isBlightRushing", true)
		ply.blightRushStart = CurTime()
		ply.blightRushAngle = ply:EyeAngles()
		stopReceivingTokens(ply)
		ply.puppet = ent

		net.Start("fh_net_killer_change_tokens")
		net.WriteString("charge")
		net.WriteInt(ply.blightRushTokens, 9)
		net.Send(ply)

		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end

		net.Start("BlightRush_Start")
		net.Send(ply)
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

		ply.isBlightRushing = false
		ply.isBlightBouncing = false
		ply:SetNWBool("isBlightRushing", false)
		ply:SetNWBool("Blight_BlockM1", false)
		StopBleeding(ply)
	end)
	
	
	hook.Add("PlayerSpawn", "BlightRush_ResetOnSpawn", function(ply)
		stopReceivingTokens(ply)
		if ply.blightTimeoutTimer then
			timer.Remove(ply.blightTimeoutTimer)
			ply.blightTimeoutTimer = nil
		end

		ply.isBlightRushing = false
		ply.isBlightBouncing = false
		ply:SetNWBool("isBlightRushing", false)
		ply:SetNWBool("Blight_BlockM1", false)
	end)
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
	ply.isBlightRushing = false
	ply:SetNWBool("isBlightRushing", false)

	if SERVER then
		net.Start("BlightRush_End")
		net.Send(ply)
		receiveTokensBack(ply)
		foxyStun(ply)
	end
end

if SERVER then
	hook.Add("Think", "BlightRushThink", function()
		for _, ply in ipairs(team.GetPlayers(2701)) do
			if ply.isBlightBouncing then
				local bounceDuration = 0.2
				if CurTime() - (ply.blightBounceStart or 0) > bounceDuration then
					ply.isBlightBouncing = false
					ply:SetVelocity(Vector(0, 0, 0))
				else
					local dir = ply.blightBounceDir or Vector(0, 0, 0)
					local speed = ply.blightBounceSpeed or 80
					ply:SetVelocity(dir * speed)
				end
			end
		end
	end)
end

hook.Add("Move", "BlightPredictionMove", function(ply, mv)
	if not ply.isBlightRushing then return end
	if not ply:OnGround() then
		--EndRush(ply)
		return
	end

	local rushDuration = 3.5
	local speed = 900
	if CurTime() - (ply.blightRushStart or 0) > rushDuration or ply:WaterLevel() >= 2 or ply:Crouching() then
		EndRush(ply)
		return
	end

	local targetAng = mv:GetMoveAngles()
	local currentAng = ply.blightRushAngle or targetAng
	local maxTurn = 1.8
	local yawDiff = math.AngleDifference(targetAng.yaw, currentAng.yaw)
	yawDiff = math.Clamp(yawDiff, -maxTurn, maxTurn)
	currentAng.yaw = currentAng.yaw + yawDiff
	ply.blightRushAngle = currentAng

	local dir = currentAng:Forward()
	dir.z = 0
	dir:Normalize()
	mv:SetVelocity(dir * speed)

	if IsValid( ply.puppet ) then
		ply.puppet:SetPlaybackRate(1.3)
	end
	
	local wep = ply:GetViewModel(0)
	if IsValid(wep) and !wep.IsCharging then
		wep:SetPlaybackRate(1.3)
	end
		
	if SERVER then
		local tr = BlightCheckCollision(ply)
		if tr.Hit and (not tr.Entity or not tr.Entity:IsPlayer() or tr.Entity:Team() == 2701) then
		
			if tr.Entity then
				local ent = tr.Entity
				local physobj = ent:GetPhysicsObject()
				
				if IsValid(physobj) and ent:Health() > 0 then
					
					local wep = ply:GetActiveWeapon()
					
					local dmginfo = DamageInfo()
					dmginfo:SetAttacker( ply )
					dmginfo:SetInflictor( IsValid(wep) and wep or ply )
					dmginfo:SetDamage( 100 )
				
					SuppressHostEvents( NULL )
					ent:TakeDamageInfo( dmginfo )
					SuppressHostEvents( ply )
					
					return
				end
			end
					
			ply.isBlightRushing = false
			ply:SetNWBool("isBlightRushing", false)
			ply.isBlightBouncing = true
		
			net.Start("fh_net_killer_change")
			net.WriteString("charge")
			net.WriteFloat(2)
			net.Send(ply)
							
			ply.blightBounceStart = CurTime()

			local normal = tr.HitNormal
			normal.z = 0
			normal:Normalize()
			ply.blightBounceDir = normal
			ply.blightBounceSpeed = 80
					
			if IsValid(ply.puppet) then
				ply.puppet:SetPlaybackRate(1)
				ply.puppet:PillGesture('chargestun', 1, 0.8, 0.1, 0.3)
			end
			
			ply:EmitSound("blight/impact.wav")
			
			net.Start("BlightRush_End")
			net.Send(ply)
			
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
			
			ply:SendLua("RMBHint(2)")

			ply.blightTimeoutTimer = "BlightTimeout_" .. ply:SteamID()
			timer.Create(ply.blightTimeoutTimer, 2, 1, function()
				if not IsValid(ply) then return end
				ply.blightTimeoutTimer = nil
			
				foxyStun(ply)

				timer.Simple(5, function()
					if IsValid(ply) then
						receiveTokensBack(ply)
					end
				end)
			end)
		end
	end
end)

hook.Add("StartCommand", "BlightCancelJumpPress", function(ply, cmd)
    if ply:GetNWBool("isBlightRushing") or ply.isBlightBouncing or ply.blightTimeoutTimer then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_DUCK)
		cmd:RemoveKey(IN_JUMP)
	end

	if ply:GetNWBool("Blight_BlockM1") then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

if CLIENT then
	net.Receive("BlightRush_Start", function()
		local ply = LocalPlayer()
		
		local wep = ply:GetActiveWeapon()
		
		if IsValid(wep) and wep.Sensitivity then
			wep.Sensitivity = 6
		end
	end)

	net.Receive("BlightRush_End", function()
		local ply = LocalPlayer()
		
		local wep = ply:GetActiveWeapon()
		
		if IsValid(wep) and wep.Sensitivity then
			wep.Sensitivity = 1
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