local state = Persist("cl_terror_radius")

terror_radius = terror_radius or {}

-- это хуйня нужна чтобы локальные переменные сохранялись после перезапуска скриптов

state.currentKillers = state.currentKillers or {}
state.stealthKillers = state.stealthKillers or {}
state.stealthKillers2 = state.stealthKillers2 or {}
state.everyoneKillers = state.everyoneKillers or {}
state.availableThemes = state.availableThemes or {}
state.loadedMusic = state.loadedMusic or {}
state.isChasing = state.isChasing or {}
state.chaseTimers = state.chaseTimers or {}

local currentKillers   = state.currentKillers
local stealthKillers   = state.stealthKillers
local stealthKillers2  = state.stealthKillers2
local everyoneKillers  = state.everyoneKillers
local availableThemes  = state.availableThemes
local loadedMusic      = state.loadedMusic
local isChasing        = state.isChasing
local chaseTimers      = state.chaseTimers

--НАСТРОЙКИ ДИСТАНЦИЙ
local tr_Far = 2700
local tr_Approach = 1900
local tr_Close = 1000

local tr_ChaseKeep = 1200 -- если начался чейз, он не пропадёт пока мы не отбежим от аниматроника на это расстояние

local fh_terror_enabled = CreateClientConVar("fh_terror_enabled", "1", true, false, "Should you hear terror radius at all?", 0, 1)
local fh_terror_volume = CreateClientConVar("fh_terror_volume", "0.7", true, false, "Terror radius volume.", 0, 1)
local fh_terror_spectators = CreateClientConVar("fh_terror_spectators", "0", true, false, "Should you hear terror radius while spectating?", 0, 1)

local function loadThemes()
    availableThemes = {}
    local files, directories = file.Find("sound/music/chase/*", "GAME")
    
    local requiredFiles = {
        ["first_layer"] = "far.wav",
        ["second_layer"] = "approaching.wav",
        ["third_layer"] = "near.wav",
        ["chase"] = "chase.wav"
    }

    local additionary = {
        ["chase_low"] = "chase_lowhp.wav",
        ["far_rage"] = "far_rage.wav",
        ["approaching_rage"] = "approaching_rage.wav",
        ["near_rage"] = "near_rage.wav",
        ["chase_rage"] = "chase_rage.wav",
    }

    for _, dir in ipairs(directories) do
        local found = {}

        for key, reqFile in pairs(requiredFiles) do
            if file.Exists("sound/music/chase/" .. dir .. "/" .. reqFile, "GAME") then
                found[key] = reqFile
            end
        end

        for key, reqFile in pairs(additionary) do
            if file.Exists("sound/music/chase/" .. dir .. "/" .. reqFile, "GAME") then
                found[key] = reqFile
            end
        end
        
        if table.IsEmpty(found) then continue end

        availableThemes[dir] = found
    end

    if table.IsEmpty(availableThemes) then
        print("Shit. Failed loading chase themes from sound/music/chase/")
    end
end

if table.IsEmpty(loadedMusic) then
    loadThemes()
end

hook.Add( "InitPostEntity", "tr_create_music", function()
    if !table.IsEmpty(availableThemes) then
        for dir,layers in pairs(availableThemes) do 
            for layer,filepath in pairs(layers) do 
                if loadedMusic[dir] and loadedMusic[dir][layer] then
                    loadedMusic[dir][layer]:Stop()
                end
				
				if not loadedMusic[dir] then loadedMusic[dir] = {} end
            
                loadedMusic[dir][layer] = CreateSound(game.GetWorld(), "#music/chase/" .. dir .. "/" .. filepath)
                loadedMusic[dir][layer]:SetSoundLevel(0)
            end
        end
    end
end )

lastTheme = lastTheme or nil
lastTerror = lastTerror or nil

local function terrorStop(dur)
    if lastTheme and lastTerror and loadedMusic[lastTheme][lastTerror] then
        loadedMusic[lastTheme][lastTerror]:ChangeVolume(0, dur)

        local theme = lastTheme
        local rember = lastTerror

        timer.Create("StopTRMusic_" .. theme..rember, dur + 0.05, 1, function()
            if loadedMusic[theme][rember] then
                loadedMusic[theme][rember]:Stop()
            end
        end)

        lastTheme = nil
        lastTerror = nil
    end
end

cvars.AddChangeCallback("fh_terror_volume", function(convar_name, value_old, value_new)
	if lastTheme and lastTerror then
		terrorSetVolume(lastTheme, lastTerror, tonumber(value_new) or 0)
	end
end)

function terrorSetVolume(theme, name, volume, dur)
    dur = dur or 0
	local comName = theme .. name

    if timer.Exists("StopTRMusic_" .. comName) then
        timer.Remove("STopTRMusic_" .. comName)
    end

    if lastTheme and lastTerror and comName ~= lastTheme..lastTerror and loadedMusic[lastTheme][lastTerror] then
        loadedMusic[lastTheme][lastTerror]:ChangeVolume(0, dur)
    end

    local soundObj = loadedMusic[theme][name]
    if not soundObj then return end

    if soundObj:IsPlaying() and comName ~= lastTheme .. lastTerror then
        soundObj:Stop()
    end

    if !soundObj:IsPlaying() then
        soundObj:PlayEx(0, 100)
    end
    
    soundObj:ChangeVolume(volume, dur)

    if volume <= 0 then
        timer.Create("StopTRMusic_" .. theme..name, dur + 0.05, 1, function()
            if loadedMusic[theme][name] then 
                loadedMusic[theme][name]:Stop()
            end
        end)
    else
		lastTheme = theme
        lastTerror = name
    end
end

local function isKillerLookingAt(ply, killer)
    local directionToPlayer = (ply:GetPos() - killer:GetPos()):GetNormalized()
    local killerViewDirection = killer:GetAimVector()
    local angleBetween = math.deg(math.acos(directionToPlayer:Dot(killerViewDirection)))

    local traceData = {}
    traceData.start = killer:EyePos()
    traceData.endpos = ply:EyePos()
    traceData.filter = {killer, ply}
    local tr = util.TraceLine(traceData)

    return angleBetween <= 50 and (not tr.Hit or tr.Entity == ply)
end
local function isMoving(ply)
    return ply:GetVelocity():Length() > 15
end
local function isRunning(ply)
    return ply:GetVelocity():Length() > ply:GetRunSpeed() * 0.9
end
local function sameHeight(killer, ply)
    return math.abs(ply:GetPos().z - killer:GetPos().z)
end
local function sameMovement(ply,killer)
	if ply:Crouching() and isMoving(ply) then
		if killer:Crouching() and isMoving(killer) then
			return true
		else return false end
	end
	if isRunning(ply) then
		if isRunning(killer) then
			return true
		else return false end
	end
	
	--
	--[[ if isMoving(ply) then
		if isMoving(killer) then
			return true
		else return false end
	end --]]
	
	return false
end
function checkChase(ply, killer)
    local distance = ply:GetPos():Distance(killer:GetPos())
    local playerVisible = !ply:GetNoDraw() and ply:GetMaterial() ~= "models/null" and !IsValid(ply:GetPill()) or IsValid(ply:GetPill()) and ply:GetPill():GetMaterial() ~= "models/null" and !ply:GetPill():GetNoDraw()
	
    local conditions = sameMovement(ply,killer) and playerVisible
	
    if distance < tr_ChaseKeep and sameHeight(killer,ply) < 120 and isKillerLookingAt(ply, killer) and conditions and killer:GetMoveType() ~= MOVETYPE_NOCLIP then
        isChasing[ply] = killer
        if chaseTimers[ply] then
            timer.Remove(chaseTimers[ply])
            chaseTimers[ply] = nil
        end
    elseif isChasing[ply] then
        if not chaseTimers[ply] then
            chaseTimers[ply] = "ChaseEndTimer_" .. ply:EntIndex()
            timer.Create(chaseTimers[ply], 4.5, 1, function()
                isChasing[ply] = nil
            end)
        end
    end
end

function terror_radius.getLayer(theme, layer)
	if !theme or !layer then return end
	if availableThemes[theme] and availableThemes[theme][layer] then
		return layer
	end
	return nil
end

local function getLayer(theme, layer)
	return terror_radius.getLayer(theme, layer)
end

local stealthDelay = 2 -- чтобы террор быстро не пропадал если аниматроник резко застелсил
local stealthLastActive = {}
local imChasing = false

function terror_radius.imChasing()
	return imChasing or false
end

if !timer.Exists("tr_update") then
    timer.Create("tr_update", 0.5, 0, function()
        local myself = LocalPlayer()

        if !IsValid(myself) then return end

        local closestGuyPos, closestTheme, layer = nil, nil, nil
        local foundNoOne = true
		imChasing = false

        hook.Run("FH_TerrorRadiusUpdate", currentKillers)
        if fh_terror_enabled:GetBool() and !table.IsEmpty(currentKillers) and (myself:Alive() or !myself:Alive() and fh_terror_spectators:GetBool()) then
			local shouldProccess = hook.Run("FH_HandleTerrorRadius", currentKillers)
		
			local observertarget = myself:GetObserverTarget()
			
			if IsValid(observertarget) and observertarget:IsPlayer() then
				myself = observertarget
			end
			
			if shouldProccess ~= false then
				if currentKillers[myself] then
					for _, ply in player.Iterator() do
						if !ply:Alive() or (!everyoneKillers[myself] and ply:Team() == myself:Team()) then continue end
						if ply:IsDormant() then continue end

						local distance = myself:GetPos():Distance(ply:GetPos())

						local theme = currentKillers[myself]
						
						if distance < tr_Close then
							checkChase(ply, myself)

                            local shouldProccessMy = hook.Run("FH_HandleMineTerrorRadius", ply, theme)

                            if shouldProccessMy == false then continue end

							if isChasing[ply] == myself then
								layer = "chase"
								imChasing = true
								if getLayer(theme, "chase_low") then
									if ply:Health() <= ply:GetMaxHealth() / 2 then
										layer = "chase_low"
									end
								end
								closestTheme = currentKillers[myself]
								break
							end
						end
					end
				end
				for killer, theme in pairs(currentKillers) do
					if !theme or !IsValid(killer) then continue end 

			        local shouldProccessKiller = hook.Run("FH_HandleKillerTerrorRadius", killer, theme)

                    if shouldProccessKiller == false then continue end

					if myself:IsSurvivor() and currentKillers[myself] then break end

					if killer == myself or !killer:Alive() or (!everyoneKillers[killer] and killer:Team() == myself:Team()) then continue end

					local distance = myself:GetPos():Distance(killer:GetPos())

					if closestGuyPos and distance > closestGuyPos then continue end
					
					if distance > tr_Far then continue end
					
					--if IsValid(killer:GetPill()) and killer:GetPill():GetMaterial() == "models/null" then continue end

					if stealthKillers[killer] then
						if isRunning(killer) or isChasing[myself] == killer then
							stealthLastActive[killer] = CurTime()
						elseif stealthLastActive[killer] and (CurTime() - stealthLastActive[killer]) < stealthDelay then
						else
							continue
						end
					elseif stealthKillers2[killer] then
						if isMoving(killer) or isChasing[myself] == killer then
							stealthLastActive[killer] = CurTime()
						elseif stealthLastActive[killer] and (CurTime() - stealthLastActive[killer]) < stealthDelay then
						else
							continue
						end
					end

					foundNoOne = false
					
					if distance < tr_Far and distance > tr_Approach then
						layer = "first_layer"
					elseif distance < tr_Approach and distance > tr_Close then
						layer = getLayer(theme, "second_layer") or getLayer(theme, "first_layer")
					elseif distance < tr_Close then
						layer = getLayer(theme, "third_layer") or getLayer(theme, "second_layer") or getLayer(theme, "first_layer")
					end
					
					checkChase(myself, killer)

					if isChasing[myself] == killer then
						layer = "chase"
						if getLayer(theme, "chase_low") then
							if myself:Health() <= myself:GetMaxHealth() / 2 then
								layer = "chase_low"
							end
						end
					end
					
					local forceLayer, forceNotFound = nil, nil
			        forceLayer, forceNotFound = hook.Run("FH_HandleKillerTerrorLayers", killer, theme, layer)
					
					if forceLayer then
						layer = forceLayer
					end
					
					if forceNotFound then
						layer = nil
						foundNoOne = true
						continue
					end

					closestGuyPos = distance
					closestTheme = theme
				end
			end
        end
		
		local closestTheme_handler, layer_handler = nil, nil
		closestTheme_handler, layer_handler = hook.Run("FH_HandlePostTerrorRadius", closestTheme, layer)
		
		if closestTheme_handler and layer_handler then
			closestTheme = closestTheme_handler
			layer = layer_handler
			
			foundNoOne = false
		end

        if foundNoOne and !imChasing then
			isChasing[myself] = nil
            terrorStop(0.5)
        end

        if !closestTheme or !layer then return end

        if closestTheme == lastTheme and layer == lastTerror then return end
        
        terrorSetVolume(closestTheme, layer, fh_terror_volume:GetFloat(), 0.5)
    end)
end

timer.Pause("tr_update")

hook.Add("fh_poststartgame", "tr_allow_tr_playing", function()
    start_TR_Update()
end)

hook.Add("fh_postendgame", "tr_allow_tr_playing", function()
    stop_TR_Update()
end)

local animatronicThemes = {
    ["pill_wchica2"] 		= "default",
    ["pill_clown"] 			= "default",
    ["pill_springtrap"] 	= "default",
    ["pill_plushtrap"] 		= "default",
    ["pill_mangle"] 		= "default",
	
    ["pill_wfreddy2"] 		= "freddy",
    ["pill_wbonnie2"] 		= "bonnie",
	["pill_wfoxy2"] 		= "foxy",
    ["pill_sfreddy2"] 		= "sfreddy",
    ["pill_endo02"] 		= "endo",
	
    ["mask"] 				= "mask",
	
    ["bear5_main"] 			= "bear5",
    ["fox4"] 				= "bear5",
}

local stealthAnims = {
    ["pill_springtrap"] = true,
    ["pill_toychica"] = true,
}

local stealth2Anims = {
    ["pill_mangle"] = true,
}

local function getThemeByName(name)
    if availableThemes[name] then
        return name
    end

    if animatronicThemes[name] then
        return animatronicThemes[name]
    end
    return nil
end

function terror_radius.addTheme(name, theme)
	if !name or !theme then return end
	if animatronicThemes[name] then return end
	
	animatronicThemes[name] = theme
end

function terror_radius.getPlayerTheme(ply)
	if !ply then return "" end
	if !currentKillers[ply] then return "" end
	
	return currentKillers[ply]
end

function terror_radius.setPlayerTheme(ply, theme)
	if !ply or !theme or !ply:IsPlayer() then return end
	
	local selectedTheme = getThemeByName(theme)
	if selectedTheme then
		currentKillers[ply] = selectedTheme
		if stealthAnims[theme] then
			stealthKillers[ply] = true
		elseif stealth2Anims[theme] then
			stealthKillers2[ply] = true
		end
	end
end

function terror_radius.resetPlayerTheme(ply)
	if !ply or !ply:IsPlayer() then return end
	
	if currentKillers[ply] then
		currentKillers[ply] = nil
		stealthKillers[ply] = nil
		stealthKillers2[ply] = nil
		everyoneKillers[ply] = nil
	end
end

hook.Add("PillApply", "tr_apply_chase", function(ply, ent)
    if IsValid(ply) then
		if ent.formTable and ent.formTable.chaseTheme then
			terror_radius.setPlayerTheme(ply, ent.formTable.chaseTheme)
			return
		end
		
		local name = ent.formTable and ent.formTable.name
	
		terror_radius.setPlayerTheme(ply, name)
    end
end)

hook.Add("FH_KillerObsessed", "tr_apply_chase_maskkiller", function(ply)
    if IsValid(ply) then
		terror_radius.setPlayerTheme(ply, "mask")
		everyoneKillers[ply] = true
    end
end)

hook.Add("FH_KillerLostObsession", "tr_restore_chase_maskkiller", function(ply)
    terror_radius.resetPlayerTheme(ply)
end)

hook.Add("PillRestore", "tr_restore_chase", function(ply)
    terror_radius.resetPlayerTheme(ply)
end)

function start_TR_Update()
    timer.UnPause("tr_update")
end

function stop_TR_Update()
    timer.Pause("tr_update")
    terrorStop(0.5)
end