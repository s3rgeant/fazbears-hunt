AddCSLuaFile()

CreateConVar("bust_enabled", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable sprinting busting behavior", 0, 1)
CreateConVar("bust_doors", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable busting doors", 0, 1)
CreateConVar("bust_windows", 1, {FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY}, "Enable or disable busting windows", 0, 1)
CreateClientConVar("bust_viewpunch", 1, true, true, "Enable or disable bust viewpunch", 0, 1)

if SERVER then
    util.AddNetworkString("BustEffect")

    local et1

    local function PushPlayersFromDoor(door, forceDir)
        for _, ply in player.Iterator() do
            if not IsValid(ply) or not ply:Alive() then continue end
            local dist = ply:GetPos():Distance(door:GetPos())
            if dist < 100 then
                local dirToPlayer = (ply:GetPos() - door:GetPos()):GetNormalized()
                if dirToPlayer:Dot(forceDir) > 0 then
                    local physObj = ply:GetPhysicsObject()
                    if IsValid(physObj) then
                        ply:SetVelocity(dirToPlayer * 350)
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

    hook.Add("SetupMove", "DoorBustSetup", function(ply, mv, cmd)
        local notSolid = ply:GetMoveType() == MOVETYPE_NOCLIP 
            or ply:GetCollisionGroup() == COLLISION_GROUP_WORLD
            or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS

        if not IsFirstTimePredicted() or not GetConVar("bust_enabled"):GetBool() or not ply:Alive() then return end

        local vel = mv:GetVelocity()
		if vel:Length() < 600 then
			if vel:Length() < ply:GetRunSpeed() * 0.7 or (not cmd:KeyDown(IN_SPEED) and ply:GetRunSpeed() ~= ply:GetWalkSpeed() and vel:Length() < 400) or vel:Length() < 200 then return end
		end

        local dir = vel:GetNormalized()
        local pos = ply:GetPos() + Vector(0, 0, ply:GetStepSize() + 1)
        local pos2 = ply:GetPos() + (ply:OBBMins() + ply:OBBMaxs())
        local fwd, rt = dir, Vector(dir.y, -dir.x, dir.z)

        et1 = util.QuickTrace(pos2, fwd * 30, ply)
        local ent, ent2 = {et1.Entity, util.GetSurfacePropName(et1.SurfaceProps)}
        et1 = util.QuickTrace(pos, fwd * 30, ply)

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
    end)

    function BustRotatingDoor(ply, door, fx)
        local state = door:GetInternalVariable("m_eDoorState")
        if state == 2 then return end

        local isLocked = door:GetInternalVariable("m_bLocked")
        local oldDir = door:GetInternalVariable("opendir")
        local oldSpeed = door:GetInternalVariable("speed")

        if isLocked then
			return
        end
		
		door:SetKeyValue("opendir", 0)
		door:Fire("SetSpeed", 420, 0)
		door:Fire("OpenAwayFrom", "Buster" .. ply:EntIndex(), 0)
		door:Fire("Lock", "", 0)
		
		hook.Run("FuncDoorBust", ply, door)

		PushPlayersFromDoor(door, ply:GetForward())

		timer.Simple(0.3, function()
			if IsValid(door) then
				door:Fire("SetSpeed", oldSpeed, 0)
				door:SetKeyValue("opendir", oldDir)
				door:Fire("Unlock", "", 0)
			end
		end)

        if not fx then return end
        BustEffects(ply, door, true)
    end

    local function BustFuncRotating(ply, door)
        door:SetSaveValue("m_hactivator", ply)
        door:Fire("SetSpeed", 500, 0)
        door:Fire("Open", "", 0)
		door:Fire("Lock", "", 0)
        PushPlayersFromDoor(door, ply:GetForward())
    end

    function BustFuncDoor(ply, door, fx)
        local state = door:GetInternalVariable("m_toggle_state")
        if state ~= 1 then return end

        local isLocked = door:GetInternalVariable("m_bLocked")
        local oldSpeed = door:GetInternalVariable("speed")
        local oldFlags = door:GetSpawnFlags()
        local newFlags = oldFlags

        if isLocked then
			return
        end
		
		local localRight = door:GetRight()
		local openDir = door:HasSpawnFlags(2) and (-localRight) or localRight

		if door:HasSpawnFlags(2) then
			if ply:GetVelocity():Dot(openDir) > 0 then
				BustFuncRotating(ply, door)
			end
		else
			if door:HasSpawnFlags(16) then newFlags = bit.bxor(newFlags, 16) end
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

        if not fx then return end
        BustEffects(ply, door, true)
    end

    function BustEffects(ply, ent, fx)
        ply:SetName("Buster" .. ply:EntIndex())
        ply:AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)

        if fx then
            util.ScreenShake(et1.HitPos, 10, 10, 1, 100)
            sound.Play("Wood_Furniture.Break", et1.HitPos, 100, math.random(95,105), 1)
            sound.Play("Plastic_Box.Break", et1.HitPos, 100, math.random(95,105), 1)
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
end



if CLIENT then
    net.Receive("BustEffect", function()
		if IsValid(LocalPlayer()) then
			LocalPlayer():AnimRestartGesture(4, ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST, true)
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
end