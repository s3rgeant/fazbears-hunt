modifiers = modifiers or {}

local registeredMods = {}
local activatedMods = {}

function modifiers.Register(name, func)
    assert(name, "Modifier name is required for registration")
    assert(func, "Modifier function is required for registration")
	
	if registeredMods[name] then 
		print("[FH] Failed to register new modifier with name: " .. name .. ". Such name is already in use!")
		return
	end
	
	registeredMods[name] = {
		func = func,
	}
end

function modifiers.Activate(name)
    assert(name, "Modifier name is required")
	
	if !registeredMods[name] then 
		print("[FH] Failed to activate modifier: " .. name .. ". Such modifier does not exist!")
		return
	end
	
	if activatedMods[name] then 
		return
	end
	
	activatedMods[name] = true
end

function modifiers.Deactivate(name)
    assert(name, "Modifier name is required")
	
	if !registeredMods[name] then 
		print("[FH] Failed to deactivate modifier: " .. name .. ". Such modifier does not exist!")
		return
	end
	
	if !activatedMods[name] then 
		return
	end
	
	activatedMods[name] = nil
end