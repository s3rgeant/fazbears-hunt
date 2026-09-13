-- Ниже код предотвращает многократное поднятие пропов, а также последствия от этого, такие как проп-флай или проп-клаймб
-- Код предоставлен by Zemen!!!

local PICKUP_COOLDOWN = 0.65

local function IsTrackedProp(ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    return class == "prop_physics"
        or class == "prop_physics_multiplayer"
        or class == "prop_ragdoll"
        or class == "func_physbox"
end

local function IsOnPickupCooldown(ent)
    local untilTime = ent.AntiPropPickup_Until
    return untilTime ~= nil and untilTime > CurTime()
end

local function RemovePropPhysicsCallback(ent)
    if not IsTrackedProp(ent) then return end

    local callbackId = ent.AntiPropPickup_PhysCollideCallback
    if callbackId == nil then return end

    if ent.RemoveCallback then
        ent:RemoveCallback("PhysicsCollide", callbackId)
    end

    ent.AntiPropPickup_PhysCollideCallback = nil
end

local function FinalizeStopHoldingProp(ply, ent)
    if not IsTrackedProp(ent) then return end

    RemovePropPhysicsCallback(ent)

    if IsValid(ply) and ply.AntiPropPickup_HeldEnt == ent then
        ply.AntiPropPickup_HeldEnt = nil
    end

    if ent.AntiPropPickup_Holder == ply then
        ent.AntiPropPickup_Holder = nil
    end

    ent.AntiPropPickup_Until = CurTime() + PICKUP_COOLDOWN
end

local function ForceDropHeldProp(ply, ent)
    if not (IsValid(ply) and IsTrackedProp(ent)) then return end
    if ent.AntiPropPickup_Holder ~= ply then return end
    if ent.AntiPropPickup_ForceDropping then return end

    ent.AntiPropPickup_ForceDropping = true

    if ent.ForcePlayerDrop then
        ent:ForcePlayerDrop()
    end

    if ply.DropObject then
        ply:DropObject(ent)
    end

    timer.Simple(0, function()
        if IsValid(ent) then
            ent.AntiPropPickup_ForceDropping = nil
        end

        if IsValid(ply) and IsValid(ent) then
            FinalizeStopHoldingProp(ply, ent)
        end
    end)
end

local function EnsurePropPhysicsCallback(ent)
    if not IsTrackedProp(ent) then return end
    if not ent.AddCallback then return end
    if ent.AntiPropPickup_PhysCollideCallback ~= nil then return end

    ent.AntiPropPickup_PhysCollideCallback = ent:AddCallback("PhysicsCollide", function(prop, data)
        if not IsValid(prop) then return end
        if not data then return end

        local holder = prop.AntiPropPickup_Holder
        if not (IsValid(holder) and holder:IsPlayer()) then return end
		if holder:IsAnimatronic() then return end
        if data.HitEntity ~= holder then return end

        ForceDropHeldProp(holder, prop)
    end)
end

local function StartHoldingProp(ply, ent)
    if not (IsValid(ply) and IsTrackedProp(ent)) then return end

    local currentHolder = ent.AntiPropPickup_Holder
    if IsValid(currentHolder) and currentHolder ~= ply then
        if currentHolder.AntiPropPickup_HeldEnt == ent and currentHolder:IsPlayerHolding() then
            return
        end

        FinalizeStopHoldingProp(currentHolder, ent)
    end

    local prevHeld = ply.AntiPropPickup_HeldEnt
    if IsValid(prevHeld) and prevHeld ~= ent then
        FinalizeStopHoldingProp(ply, prevHeld)
    end

    ent.AntiPropPickup_Holder = ply
    ply.AntiPropPickup_HeldEnt = ent
    ent.AntiPropPickup_Until = nil

    EnsurePropPhysicsCallback(ent)

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

local function StopHoldingProp(ply, ent)
    if not (IsValid(ply) and IsTrackedProp(ent)) then return end
    FinalizeStopHoldingProp(ply, ent)
end

hook.Add("AllowPlayerPickup", "AntiPropPickup_BlockHandsPickupOnCooldown", function(ply, ent)
    if not IsTrackedProp(ent) then return end
    if IsOnPickupCooldown(ent) then
        return false
    end
end)

hook.Add("OnPlayerPhysicsPickup", "AntiPropPickup_TrackHandsHolder", function(ply, ent)
    StartHoldingProp(ply, ent)
end)

hook.Add("OnPlayerPhysicsDrop", "AntiPropPickup_ClearHandsHolder", function(ply, ent)
    StopHoldingProp(ply, ent)

    if IsTrackedProp(ent) then
        ent.AntiPropPickup_ForceDropping = nil
    end
end)

hook.Add("EntityTakeDamage", "AntiPropPickup_BlockFriendlyPropDamage", function(target, dmg)
    if not IsValid(target) or not target:IsPlayer() then return end

    local prop
    local inflictor = dmg:GetInflictor()
    local attacker = dmg:GetAttacker()

    if IsTrackedProp(inflictor) and IsValid(inflictor.AntiPropPickup_Holder) then
        prop = inflictor
    elseif IsTrackedProp(attacker) and IsValid(attacker.AntiPropPickup_Holder) then
        prop = attacker
    end

    if not IsValid(prop) then return end

    local holder = prop.AntiPropPickup_Holder
    if not IsValid(holder) or not holder:IsPlayer() then return end

    dmg:SetAttacker(holder)
end)

hook.Add("PlayerDeath", "AntiPropPickup_ClearHeldOnDeath", function(ply)
    if not IsValid(ply) then return end

    local ent = ply.AntiPropPickup_HeldEnt
    if IsValid(ent) then
        FinalizeStopHoldingProp(ply, ent)
    end

    ply.AntiPropPickup_HeldEnt = nil
end)

hook.Add("PlayerDisconnected", "AntiPropPickup_ClearHeldOnDisconnect", function(ply)
    if not IsValid(ply) then return end

    local ent = ply.AntiPropPickup_HeldEnt
    if IsValid(ent) then
        FinalizeStopHoldingProp(ply, ent)
    end
end)

hook.Add("EntityRemoved", "AntiPropPickup_ClearRemovedPropHolder", function(ent)
    if not IsTrackedProp(ent) then return end

    local holder = ent.AntiPropPickup_Holder

    RemovePropPhysicsCallback(ent)

    if IsValid(holder) and holder.AntiPropPickup_HeldEnt == ent then
        holder.AntiPropPickup_HeldEnt = nil
    end
end)

-- Ниже код предотвращает застревание func_train лифтов из-за игроков которые залазят друг на друга

hook.Add( "OnPlayerHitGround", "fh_AntiFuncTrainBlock", function( ply, inWater, onFloater, speed )
	local ply2 = ply:GetGroundEntity()
	
	if not ply2:IsPlayer() then return end
	
	local ply2Ground = ply2:GetGroundEntity()
	
	if IsValid(ply2Ground) and (ply2Ground:GetClass() == "func_train" or ply2Ground:GetClass() == "func_tracktrain") then
		ply:NoPlayerCollide(0.25)
	end
end )