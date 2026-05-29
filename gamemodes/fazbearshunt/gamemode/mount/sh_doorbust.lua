AddCSLuaFile()

CreateConVar("bust_enabled", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable sprinting busting behavior", 0, 1)
CreateConVar("bust_doors", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable busting doors", 0, 1)
CreateConVar("bust_windows", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable busting windows", 0, 1)
CreateClientConVar("bust_viewpunch", 1, true, true, "Enable or disable bust viewpunch", 0, 1)

local BUST_SPEED = 600
if SERVER then
    util.AddNetworkString("BustEffect")

    local et1
	
	local bustedDoors = {}

    local function PushPlayersFromDoor(door, buster)
		local forceDir = buster:GetForward()
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(door:GetPos())
            if dist < 100 then
                local dirToPlayer = (ply:GetPos() - door:GetPos()):GetNormalized()
                if dirToPlayer:Dot(forceDir) > 0 then
                    local physObj = ply:GetPhysicsObject()
                    if IsValid(physObj) then
                        ply:SetVelocity(dirToPlayer * (buster:IsAnimatronic() and 740 or 350))
                    end
                end
            end
        end
    end

    local function BustDoorTest(ply, tbl, fx)
        local ent, surf = tbl[1], tbl[2]
        if not IsValid(ent) then print("if you see this something went wrong with doorbusting") return end
        if GetConVar("bust_doors"):GetBool() then
            if ent:GetClass() == "prop_door_rotating" then
                BustRotatingDoor(ply, ent, fx)
				return true
            elseif ent:GetClass() == "func_door_rotating" then
                BustFuncDoor(ply, ent, fx)
				return true
            end
        end
        if GetConVar("bust_windows"):GetBool() and (string.find(surf, "glass") or string.find(surf, "default")) then
            if ent:GetClass() == "func_breakable_surf" then
                ent:Fire("Shatter", "0.5 0.5 " .. ent:BoundingRadius())
                BustEffects(ply, ent, false)
				return true
            elseif !ent:IsPlayer() and ent:Health() > 0 and ent:Health() <= ent:GetMaxHealth() then
                ent:TakeDamage(10, ply, ent)
                ent:EmitSound("Glass.Strain")
                BustEffects(ply, ent, false)
				return true
            end
        end
		return false
    end

	local tr_t = {}
    hook.Add("SetupMove", "DoorBustSetup", function(ply, mv, cmd)
        local notSolid = ply:GetMoveType() == MOVETYPE_NOCLIP 
            or ply:GetCollisionGroup() == COLLISION_GROUP_WORLD
            or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS

        if not IsFirstTimePredicted() or not GetConVar("bust_enabled"):GetBool() or not ply:Alive() then return end

        local vel = mv:GetVelocity()
		if (!ply:Crouching() or !ply:OnGround()) and (ply:IsSprinting() and vel:Length() > 50 or !ply:IsSprinting() and vel:Length() > 300) then

			local dir = vel:GetNormalized()
			local pos = ply:GetPos() + Vector(0, 0, ply:GetStepSize() + 1)
			local pos2 = ply:GetPos() + (ply:OBBMins() + ply:OBBMaxs())
			local fwd, rt = dir, Vector(dir.y, -dir.x, dir.z)

			tr_t.start = pos2
			tr_t.endpos = pos2 + fwd * 40
			tr_t.filter = function(ent)
				return not ent:IsPlayer()
			end
			
			et1 = util.TraceLine(tr_t)
			local ent, ent2 = {et1.Entity, util.GetSurfacePropName(et1.SurfaceProps)}
			tr_t.start = pos
			et1 = util.TraceLine(tr_t)

			if et1.HitNonWorld and not notSolid then
				if et1.Entity == ent[1] then
					BustDoorTest(ply, ent, true)
				end
				if not IsValid(et1.Entity) or (string.find(ent[2], "glass") or string.find(ent[2], "default")) then return end

				local et2 = util.QuickTrace(pos - (rt * 16), fwd * 45, ply)
				if not IsValid(et2.Entity) or et2.Entity == ent[1] then
					et2 = util.QuickTrace(pos + (rt * 16), fwd * 45, ply)
				end
				if not IsValid(et2.Entity) or et2.Entity == ent[1] then return end

				ent2 = {et2.Entity, util.GetSurfacePropName(et2.SurfaceProps)}
				if ent2 and ent2 ~= ent then
					BustDoorTest(ply, ent2, false)
				end
			end
		end
    end)

    function BustRotatingDoor(ply, door, fx)
        local state = door:GetInternalVariable("m_eDoorState")
        if state == 2 then return end
		
		if bustedDoors[door] then
			if CurTime() < bustedDoors[door] then return end
		end

        local isLocked = door:GetInternalVariable("m_bLocked")
        local oldDir = door:GetInternalVariable("opendir")
        local oldSpeed = door:GetInternalVariable("speed")

        if isLocked then return end
		
		door:SetKeyValue("opendir", 0)
		door:Fire("SetSpeed", BUST_SPEED, 0)
		door:Fire("OpenAwayFrom", "Buster" .. ply:EntIndex(), 0)
		door:Fire("Lock", "", 0)
		
		hook.Run("FuncDoorBust", ply, door)

		PushPlayersFromDoor(door, ply)
		
		timer.Simple(0.1, function()
			door:SetKeyValue("opendir", oldDir)
		end)

		timer.Simple(0.3, function()
			if IsValid(door) then
				door:Fire("SetSpeed", oldSpeed, 0)
				door:Fire("Unlock", "", 0)
			end
		end)
		
		bustedDoors[door] = CurTime() + 0.1

        if not fx then return end
        BustEffects(ply, door, true)
    end

    local function BustFuncRotating(ply, door)
		if bustedDoors[door] then
			if CurTime() < bustedDoors[door] then return end
		end
		
		--PrintTable(door:GetKeyValues())
        door:SetSaveValue("m_hactivator", ply)
        door:Fire("SetSpeed", 500, 0)
        door:Fire("Open", "", 0)
		door:Fire("Lock", "", 0)
        PushPlayersFromDoor(door, ply)
		
		bustedDoors[door] = CurTime() + 0.1
    end

    function BustFuncDoor(ply, door, fx)
        local state = door:GetInternalVariable("m_toggle_state")
        if state ~= 1 then return end
		
		if bustedDoors[door] then
			if CurTime() < bustedDoors[door] then return end
		end

        local isLocked = door:GetInternalVariable("m_bLocked")
        local oldSpeed = door:GetInternalVariable("speed")
        local oldFlags = door:GetSpawnFlags()
        local newFlags = oldFlags

        if isLocked then return end
		
		local localRight = door:GetRight()
		local openDir = door:HasSpawnFlags(2) and (-localRight) or localRight

		if door:HasSpawnFlags(2) then
			if ply:GetVelocity():Dot(openDir) > 0 then
				BustFuncRotating(ply, door)
			end
		else
			--if door:HasSpawnFlags(16) then newFlags = bit.bxor(newFlags, 16) print('chto', newFlags) end
			door:SetKeyValue("spawnflags", newFlags)
			BustFuncRotating(ply, door)
		end

		timer.Simple(0.5, function()
			if IsValid(door) then
				door:Fire("SetSpeed", oldSpeed, 0)
				door:SetKeyValue("spawnflags", oldFlags)
				door:Fire("Unlock", "", 0)
			end
		end)
		
		bustedDoors[door] = CurTime() + 0.1

        if not fx then return end
        BustEffects(ply, door, true)
    end

    function BustEffects(ply, ent, fx)
        ply:SetName("Buster" .. ply:EntIndex())
        ply:AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)

        if fx then
			local rf = RecipientFilter()
			rf:AddPAS(et1.HitPos)
			rf:RemovePlayer(ply)
			
            util.ScreenShake(et1.HitPos, 10, 10, 1, 100, nil,rf)
			
			local pitch = math.random(95,105)
			
            EmitSound("Wood_Furniture.Break", et1.HitPos, 0, nil, 1, 75,0,pitch,1,rf)
            EmitSound("Plastic_Box.Break", et1.HitPos, 0, nil, 1, 75, 0,pitch,1,rf)
        end

        net.Start("BustEffect")
        net.WriteVector(et1.HitPos)
        net.WriteNormal(et1.HitNormal)
        net.WriteFloat(ent:GetInternalVariable("speed") or 500)
        net.Broadcast()

        if not tobool(ply:GetInfoNum("bust_viewpunch", 0)) then return end

        local isLeftBust = tobool(math.random(0, 1))
        local bustYaw, bustRoll = isLeftBust and 10 or -10, isLeftBust and -10 or 10
        ply:ViewPunch(Angle(10, bustYaw, bustRoll))
    end
	
	local TrackedEnts = {
		[ "prop_door_rotating" ] = true,
		[ "func_door_rotating" ] = true
	}

	hook.Add("OnEntityCreated", "doorbust", function(ent)
		if TrackedEnts[ent:GetClass()] then
			timer.Simple(0.1, function()
				if not IsValid(ent) then return end
				
				if ent:GetClass() == "func_door_rotating" then
					local pivot = ent:GetNetworkOrigin()
					local center = ent:GetPos() + ent:OBBCenter()

					local hingeToCenter = (center - pivot)
					hingeToCenter.z = 0
					hingeToCenter:Normalize()

					local forward = Vector(
						hingeToCenter.y,
						-hingeToCenter.x,
						0
					)

					ent:SetNWVector("_DoorForward", forward)

					local ang = forward:Angle()
					ang.p = 0
					ang.r = 0

					ent:SetNWAngle("_DoorAngleOrigin", ang)
					return
				end
				
				ent:SetNWAngle("_DoorAngleOrigin", ent:GetInternalVariable("m_angRotationClosed") or ent:GetAngles())
			end)
		end
	end)
	
	local DoorClasses = {
		["func_door"] = true,
		["func_door_rotating"] = true
	}
end

if CLIENT then
    net.Receive("BustEffect", function()
        local ply = LocalPlayer()
        if IsValid(ply) then
            ply:AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)
        end
        
        local hitPos = net.ReadVector()
        local normal = net.ReadNormal()
        local magnit = net.ReadFloat()

        local ef = EffectData()
        ef:SetStart(hitPos)
        ef:SetOrigin(hitPos)
        ef:SetNormal(normal)
        ef:SetMagnitude(magnit)
        util.Effect("busteffect", ef)
    end)

	local localBustedDoors = {}
	hook.Add("Think", "VisualDoorBust", function()
		local currentTime = UnPredictedCurTime()
		
		for door, data in pairs(localBustedDoors) do
			if not IsValid(door) or currentTime > data.EndTime then
				if IsValid(door) then 
					door:SetRenderAngles()
				end
				localBustedDoors[door] = nil
				continue
			end
			local elapsed = currentTime - data.StartTime
            local fraction = math.Clamp(elapsed / data.Duration, 0, 1)
			local angs = LerpAngle(fraction, data.StartAng, data.TargetAng)
			
			door:SetRenderAngles(angs)
		end
	end)
	
	local function fakeBustDoor(ent, ply, fwd, hitpos)
		local cl = ent:GetClass()
		local state
		
		--if cl == "prop_door_rotating" then
			state = ent:GetInternalVariable("m_eDoorState")
			if state == 2 then return end
		--[[else
			state = ent:GetInternalVariable("m_toggle_state")
			print(state)
			if state ~= 1 then return end
		end--]]
		
		local isLocked = ent:GetInternalVariable("m_bLocked")
		if isLocked then return end
		
		if not localBustedDoors[ent] then
			local baseAng = ent:GetNWAngle("_DoorAngleOrigin", ent:GetAngles())
			local currentAng = ent:GetAngles()
            
            local doorForward = ent:GetNWVector("_DoorForward", ent:GetForward())
            local dot = fwd:Dot(doorForward)
			if cl == "func_door_rotating" then 
				currentAng.y = currentAng.y + (doorForward.y*90)
			end
            
            local yawOffset = (dot < 0) and 90 or -90
            local targetAng = Angle(baseAng.p, baseAng.y + yawOffset, baseAng.r)
			
			local checkie = currentAng.y
			if cl == "func_door_rotating" then 
				local ogAngles = ent:GetAngles()
				ogAngles.y = ogAngles.y + yawOffset
				targetAng = ogAngles
				checkie = 0
			end
			
			local angleDiff = math.abs(math.AngleDifference(targetAng.y, checkie))
            local duration = angleDiff / BUST_SPEED
			
			util.ScreenShake(hitpos, 2, 2, 1, 100)
	
			sound.Play("Wood_Furniture.Break", hitpos, 100, math.random(95, 105), 1)
			sound.Play("Plastic_Box.Break", hitpos, 100, math.random(95, 105), 1)
	
			localBustedDoors[ent] = {
				StartTime = UnPredictedCurTime(),
				EndTime = UnPredictedCurTime() + 0.5,
				Duration = duration,
				StartAng = ent:GetAngles(),
				TargetAng = targetAng
			}
		end
	end
	
	local tr_t = {}
	local fakies = {
		["prop_door_rotating"] = true,
		["func_door_rotating"] = true,
	}
    hook.Add("SetupMove", "DoorBustSetup", function(ply, mv, cmd)
        local notSolid = ply:GetMoveType() == MOVETYPE_NOCLIP 
            or ply:GetCollisionGroup() == COLLISION_GROUP_WORLD
            or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS
			
        if not IsFirstTimePredicted() or not GetConVar("bust_enabled"):GetBool() or not ply:Alive() or ply ~= LocalPlayer() then return end

        local vel = mv:GetVelocity()
        if (!ply:Crouching() or !ply:OnGround()) and (ply:IsSprinting() and vel:Length() > 50 or !ply:IsSprinting() and vel:Length() > 300) then

			local dir = vel:GetNormalized()
			local pos = ply:GetPos() + Vector(0, 0, ply:GetStepSize() + 1)
			local pos2 = ply:GetPos() + (ply:OBBMins() + ply:OBBMaxs())
			local fwd, rt = dir, Vector(dir.y, -dir.x, dir.z)

            tr_t.start = pos2
            tr_t.endpos = pos2 + fwd * 40
            tr_t.filter = function(ent) return not ent:IsPlayer() end
			
			et1 = util.TraceLine(tr_t)
			local ent, ent2 = {et1.Entity, util.GetSurfacePropName(et1.SurfaceProps)}
			tr_t.start = pos
			et1 = util.TraceLine(tr_t)

			if et1.HitNonWorld and not notSolid then
				if et1.Entity == ent[1] then
					if fakies[ent[1]:GetClass()] then
						fakeBustDoor(ent[1], ply, fwd, et1.HitPos)
					end
				end
				if not IsValid(et1.Entity) or (string.find(ent[2], "glass") or string.find(ent[2], "default")) then return end

				local et2 = util.QuickTrace(pos - (rt * 16), fwd * 45, ply)
				if not IsValid(et2.Entity) or et2.Entity == ent[1] then
					et2 = util.QuickTrace(pos + (rt * 16), fwd * 45, ply)
				end
				if not IsValid(et2.Entity) or et2.Entity == ent[1] then return end

				ent2 = {et2.Entity, util.GetSurfacePropName(et2.SurfaceProps)}
				if ent2 and ent2 ~= ent then
					if fakies[ent2[1]:GetClass()] then
						fakeBustDoor(ent2[1], ply, fwd, et2.HitPos)
					end
				end
			end
        end
    end)
end