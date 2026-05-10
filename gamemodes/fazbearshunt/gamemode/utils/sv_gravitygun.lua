local function IsTrackedProp(ent)
    if not IsValid(ent) then return false end

    local class = ent:GetClass()

    return class == "prop_physics"
        or class == "prop_physics_multiplayer"
        or class == "prop_ragdoll"
        or class == "func_physbox"
end

local zombie = {}
hook.Add("GravGunPunt", "fh_damagecheker", function(ply,ent)

	if zombie[ent] then 
		ent:RemoveCallback("PhysicsCollide", zombie[ent])
		zombie[ent] = nil 
	end

	zombie[ent] = ent:AddCallback("PhysicsCollide", function(prop, data)
        if not IsValid(prop) then return end
		
        if not IsValid(ply) then 
			ent:RemoveCallback("PhysicsCollide", zombie[ent])
			zombie[ent] = nil
		end

        local hitEnt = data.HitEntity
		
		if IsValid(hitEnt) and IsTrackedProp(hitEnt) then
			hitEnt._ImpulseOwner = ply
			
			local timerName = "reset_impulse_owner" .. hitEnt:EntIndex()
			
			if timer.Exists(timerName) then
				timer.Remove(timerName)
			end
			
			timer.Create(timerName, 2, 1, function()
				if IsValid(hitEnt) and hitEnt._ImpulseOwner then
					hitEnt._ImpulseOwner = nil
				end
			end)
		end
    end)
end)