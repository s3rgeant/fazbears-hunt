modifiers = modifiers or {}

local registeredMods = {}
local currentMods = {}

local uniqueM = {}
local soloM = {}

local modifiers_enabled = CreateConVar( "fh_modifiers_enabled", 1, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Toggle modifiers." )
local modifiers_chance = CreateConVar( "fh_modifiers_chance", 0.8, { FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Global modifiers chance of enabling." )

local lastId = 0

function modifiers.Register(name, chance, startupFunc, startFunc, endfunc)
    assert(name, "Modifier name is required for registration")
    assert(func, "Modifier function is required for registration")
	
	if registeredMods[name] then 
		print("[FH] Failed to register new modifier with name: " .. name .. ". Such name is already in use!")
		return
	end
	
	registeredMods[name] = {
		id = lastId,
		chance = chance,
		startup = startupFunc,
		start = startFunc,
		endfunc = endfunc,
	}
	lastId = lastId+1
end

function modifiers.Activate(name)
    assert(name, "Modifier name is required")
	
	if !registeredMods[name] then 
		print("[FH] Failed to activate modifier: " .. name .. ". Such modifier does not exist!")
		return
	end
	
	if currentMods[name] then return end
	
	currentMods[name] = true
end

function modifiers.Deactivate(name)
    assert(name, "Modifier name is required")
	
	if !registeredMods[name] then 
		print("[FH] Failed to deactivate modifier: " .. name .. ". Such modifier does not exist!")
		return
	end
	
	if !currentMods[name] then  return end
	
	currentMods[name] = nil
end

function modifiers.DeactivateAll()
	for name, _ in pairs(currentMods) do
		currentMods[name] = nil
	end
end

function modifiers.SetUnique(name, bool)
	if !registeredMods[name] then return end
	uniqueM[name] = bool and true or nil
end

function modifiers.SetSolo(name, bool)
	if !registeredMods[name] then return end
	soloM[name] = bool and true or nil
end

function modifiers.Setup(roundType)
	if !modifiers_enabled:GetBool() then return end
	
	local globalChance = modifiers_chance:GetFloat()*100
	
	if math.random(1,100) <= globalChance then
		
		local pool = {}
		local curmap = game.GetMap()
		local skip = false
		
		local foundUnique = false
		
		local uncommon = ""
		
		for name, data in pairs(currentMods) do
			skip = false
	
			local chance = data.chance*100 or 100
			
			if math.random(1,100) > chance then skip=true continue end
			
			if data.blacklistRounds then
				for round, _ in pairs(data.blacklistRounds) do
					if round == roundType then
						skip = true
						break
					end
				end
			end
			if skip then continue end
			
			if data.whitelist then
				skip = true
				for map, _ in pairs(data.whitelist) do
					if map == curmap then
						skip = false
						break
					end
				end
			end
			if skip then continue end
			
			if data.blacklist then
				for map, _ in pairs(data.blacklist) do
					if map == curmap then
						skip = true
						break 
					end
				end
			end
			if skip then continue end
			
			if uniqueM[name] then 
				if foundUnique then continue end
				foundUnique = true 
			end
			
			if soloM[name] then 
				table.Empty(pool)
				pool[name] = data
				break
			end
			
			pool[name] = data
		end
		
		for modifier, data in pairs(pool) do
			local skip = hook.Run("FH_SkipSetupModifier", modifier, data, pool)
			
			if skip then
				modifiers.Activate(modifier)
			end
		end
		
	end
	
end

function modifiers.Startup()
	for name, data in pairs(currentMods) do
		if data.startup then
			data.startup()
		end
	end
end

function modifiers.Start()
	for name, data in pairs(currentMods) do
		if data.start then
			data.start()
		end
	end
end

function modifiers.End()
	for name, data in pairs(currentMods) do
		if data.endfunc then
			data.endfunc()
		end
	end
end