local state = Persist("cl_terror_radius")

terror_radius = terror_radius or {}

-- это хуйня нужна чтобы локальные переменные сохранялись после перезапуска скриптов

state.currentKillers = state.currentKillers or {}
state.everyoneKillers = state.everyoneKillers or {}
state.availableThemes = state.availableThemes or {}
state.loadedMusic = state.loadedMusic or {}
state.isChasing = state.isChasing or {}
state.chaseTimers = state.chaseTimers or {}

local currentKillers   = state.currentKillers
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

local layerCrossfadeDuration = 0.75
local volumeChangeDuration = 0.15
local musicReloadDelay = 1.0

local firstToSecondBlendDistance = 420
local secondToThirdBlendDistance = 360
local distanceDirectionThreshold = 12
local distanceBlendResponseDuration = 0.18

state.activeTerrorLayerWeights = state.activeTerrorLayerWeights or {}
state.lastTerrorDistance = nil
state.lastTerrorTheme = nil
state.activeDistanceBlendZone = nil

local activeTerrorLayerWeights = state.activeTerrorLayerWeights

table.Empty(activeTerrorLayerWeights)

state.musicTimelineStartedAt = state.musicTimelineStartedAt or CurTime()
state.musicLoadGeneration = (state.musicLoadGeneration or 0) + 1
state.musicInitializedGeneration = nil

local musicTimelineStartedAt = state.musicTimelineStartedAt
local musicLoadGeneration = state.musicLoadGeneration

hook.Remove("Think", "tr_update_music_channels")
cvars.RemoveChangeCallback("fh_terror_volume", "FH.TerrorRadius.Volume")

local function isValidAudioChannel(audioChannel)
    return audioChannel and audioChannel.IsValid and audioChannel:IsValid()
end

local function stopLoadedMusicEntry(musicEntry)
    if istable(musicEntry) then
        local audioChannel = musicEntry.channel

        if isValidAudioChannel(audioChannel) then
            audioChannel:Stop()
        end

        return
    end

    if musicEntry and musicEntry.Stop then
        pcall(musicEntry.Stop, musicEntry)
    end
end

local function loadThemes()
    table.Empty(availableThemes)

    local ignoredFiles, directories = file.Find("sound/music/chase/*", "GAME")

    local requiredFiles = {
        first_layer = "far.wav",
        second_layer = "approaching.wav",
        third_layer = "near.wav",
        chase = "chase.wav"
    }

    local additionalFiles = {
        chase_low = "chase_lowhp.wav",
        far_rage = "far_rage.wav",
        approaching_rage = "approaching_rage.wav",
        near_rage = "near_rage.wav",
        chase_rage = "chase_rage.wav"
    }

    for _, directoryName in ipairs(directories) do
        local foundLayers = {}

        for layerName, fileName in pairs(requiredFiles) do
            if file.Exists("sound/music/chase/" .. directoryName .. "/" .. fileName, "GAME") then
                foundLayers[layerName] = fileName
            end
        end

        for layerName, fileName in pairs(additionalFiles) do
            if file.Exists("sound/music/chase/" .. directoryName .. "/" .. fileName, "GAME") then
                foundLayers[layerName] = fileName
            end
        end

        if table.IsEmpty(foundLayers) then continue end

        availableThemes[directoryName] = foundLayers
    end

    if table.IsEmpty(availableThemes) then
        print("Shit. Failed loading chase themes from sound/music/chase/")
    end
end

local function getInterpolatedMusicVolume(musicEntry, currentTime)
    local fadeStartTime = tonumber(musicEntry.fadeStartTime) or currentTime
    local fadeEndTime = tonumber(musicEntry.fadeEndTime) or fadeStartTime
    local fadeStartVolume = tonumber(musicEntry.fadeStartVolume) or 0
    local fadeTargetVolume = tonumber(musicEntry.fadeTargetVolume) or 0

    if fadeEndTime <= fadeStartTime or currentTime >= fadeEndTime then
        return fadeTargetVolume
    end

    if currentTime <= fadeStartTime then
        return fadeStartVolume
    end

    local fraction = math.Clamp((currentTime - fadeStartTime) / (fadeEndTime - fadeStartTime), 0, 1)
    fraction = fraction * fraction * (3 - 2 * fraction)

    return Lerp(fraction, fadeStartVolume, fadeTargetVolume)
end

local function setMusicEntryTargetVolume(musicEntry, targetVolume, duration)
    targetVolume = math.Clamp(tonumber(targetVolume) or 0, 0, 1)
    duration = math.max(0, tonumber(duration) or 0)

    local currentTime = CurTime()
    local currentVolume = getInterpolatedMusicVolume(musicEntry, currentTime)
    local oldTargetVolume = tonumber(musicEntry.fadeTargetVolume) or 0

    if math.abs(oldTargetVolume - targetVolume) <= 0.0001 then return end

    musicEntry.currentVolume = currentVolume
    musicEntry.fadeStartVolume = currentVolume
    musicEntry.fadeTargetVolume = targetVolume
    musicEntry.fadeStartTime = currentTime
    musicEntry.fadeEndTime = currentTime + duration

    if duration <= 0 then
        musicEntry.currentVolume = targetVolume

        if isValidAudioChannel(musicEntry.channel) then
            musicEntry.channel:SetVolume(targetVolume)
        end
    end
end

local function synchronizeMusicChannel(audioChannel)
    if not isValidAudioChannel(audioChannel) then return end

    local trackLength = math.max(0, tonumber(audioChannel:GetLength()) or 0)
    if trackLength <= 0.01 then return end

    local elapsedTime = math.max(0, CurTime() - musicTimelineStartedAt)
    local playbackTime = elapsedTime % trackLength

    pcall(audioChannel.SetTime, audioChannel, playbackTime, true)
end

local function startMusicEntryLoading(themeName, layerName, musicEntry)
    if not musicEntry or musicEntry.loading then return end
    if musicEntry.retryAt and musicEntry.retryAt > CurTime() then return end

    musicEntry.loading = true
    musicEntry.ready = false
    musicEntry.loadToken = (musicEntry.loadToken or 0) + 1

    local loadToken = musicEntry.loadToken
    local filePath = "sound/music/chase/" .. themeName .. "/" .. musicEntry.fileName

    sound.PlayFile(filePath, "noblock noplay", function(audioChannel, errorId, errorName)
        if state.musicLoadGeneration ~= musicLoadGeneration then
            if isValidAudioChannel(audioChannel) then
                audioChannel:Stop()
            end

            return
        end

        local themeMusic = loadedMusic[themeName]
        local currentEntry = themeMusic and themeMusic[layerName]

        if currentEntry ~= musicEntry or musicEntry.loadToken ~= loadToken then
            if isValidAudioChannel(audioChannel) then
                audioChannel:Stop()
            end

            return
        end

        musicEntry.loading = false

        if not isValidAudioChannel(audioChannel) then
            musicEntry.channel = nil
            musicEntry.ready = false
            musicEntry.retryAt = CurTime() + musicReloadDelay

            print("[FH TerrorRadius] Failed loading:", filePath, errorId, errorName)
            return
        end

        musicEntry.channel = audioChannel
        musicEntry.ready = true
        musicEntry.retryAt = 0
        musicEntry.currentVolume = 0

        audioChannel:SetVolume(0)
        audioChannel:EnableLooping(true)
        synchronizeMusicChannel(audioChannel)
        audioChannel:Play()
    end)
end

local function ensureThemeMusicLoaded(themeName)
    local themeLayers = availableThemes[themeName]
    if not themeLayers then return false end

    loadedMusic[themeName] = loadedMusic[themeName] or {}

    local themeMusic = loadedMusic[themeName]

    for layerName, fileName in pairs(themeLayers) do
        local musicEntry = themeMusic[layerName]

        if not istable(musicEntry) or musicEntry.fileName ~= fileName then
            stopLoadedMusicEntry(musicEntry)

            musicEntry = {
                fileName = fileName,
                channel = nil,
                loading = false,
                ready = false,
                retryAt = 0,
                loadToken = 0,
                currentVolume = 0,
                fadeStartVolume = 0,
                fadeTargetVolume = 0,
                fadeStartTime = CurTime(),
                fadeEndTime = CurTime()
            }

            themeMusic[layerName] = musicEntry
        end

        if not isValidAudioChannel(musicEntry.channel) then
            musicEntry.channel = nil
            musicEntry.ready = false
            startMusicEntryLoading(themeName, layerName, musicEntry)
        end
    end

    return true
end

local function resetDistanceBlendState()
    state.lastTerrorDistance = nil
    state.lastTerrorTheme = nil
    state.activeDistanceBlendZone = nil
end

local function initializeTerrorMusic()
    if state.musicInitializedGeneration == musicLoadGeneration then return end

    state.musicInitializedGeneration = musicLoadGeneration

    for _, themeMusic in pairs(loadedMusic) do
        for _, musicEntry in pairs(themeMusic) do
            stopLoadedMusicEntry(musicEntry)
        end
    end

    table.Empty(loadedMusic)
    table.Empty(activeTerrorLayerWeights)

    lastTheme = nil
    lastTerror = nil

    resetDistanceBlendState()
end

local function copyActiveLayerWeights(layerWeights)
    table.Empty(activeTerrorLayerWeights)

    for layerName, layerWeight in pairs(layerWeights or {}) do
        layerWeight = math.Clamp(tonumber(layerWeight) or 0, 0, 1)

        if layerWeight > 0 then
            activeTerrorLayerWeights[layerName] = layerWeight
        end
    end
end

local function changeAllTerrorVolumes(activeTheme, layerWeights, activeVolume, duration)
    activeVolume = math.Clamp(tonumber(activeVolume) or 0, 0, 1)
    duration = math.max(0, tonumber(duration) or 0)

    if activeTheme then
        ensureThemeMusicLoaded(activeTheme)
    end

    for themeName, themeMusic in pairs(loadedMusic) do
        for layerName, musicEntry in pairs(themeMusic) do
            local targetVolume = 0

            if themeName == activeTheme then
                targetVolume = activeVolume * math.Clamp(tonumber(layerWeights and layerWeights[layerName]) or 0, 0, 1)
            end

            setMusicEntryTargetVolume(musicEntry, targetVolume, duration)
        end
    end
end

local function applyTerrorLayerWeights(themeName, layerWeights, volume, duration, primaryLayer)
    if not themeName or not primaryLayer then return false end

    local themeLayers = availableThemes[themeName]
    if not themeLayers or not themeLayers[primaryLayer] then return false end

    ensureThemeMusicLoaded(themeName)
    copyActiveLayerWeights(layerWeights)

    volume = math.Clamp(tonumber(volume) or 0, 0, 1)
    duration = math.max(0, tonumber(duration) or layerCrossfadeDuration)

    changeAllTerrorVolumes(themeName, activeTerrorLayerWeights, volume, duration)

    lastTheme = themeName
    lastTerror = primaryLayer

    return true
end

local function terrorStop(duration)
    table.Empty(activeTerrorLayerWeights)
    changeAllTerrorVolumes(nil, activeTerrorLayerWeights, 0, duration)

    lastTheme = nil
    lastTerror = nil

    resetDistanceBlendState()
end

function terrorSetVolume(themeName, layerName, volume, duration)
    if not themeName or not layerName then
        print("[FH TerrorRadius] Failed:", themeName, layerName)
        return false
    end

    return applyTerrorLayerWeights(themeName, {
        [layerName] = 1
    }, volume, duration, layerName)
end

local function terrorSetLayerBlend(themeName, sourceLayer, targetLayer, targetFraction, volume, duration, primaryLayer)
    if not sourceLayer or not targetLayer then return false end

    if sourceLayer == targetLayer then
        return terrorSetVolume(themeName, primaryLayer or targetLayer, volume, duration)
    end

    local themeLayers = availableThemes[themeName]
    if not themeLayers or not themeLayers[sourceLayer] or not themeLayers[targetLayer] then
        return false
    end

    targetFraction = math.Clamp(tonumber(targetFraction) or 0, 0, 1)

    return applyTerrorLayerWeights(themeName, {
        [sourceLayer] = 1 - targetFraction,
        [targetLayer] = targetFraction
    }, volume, duration, primaryLayer or targetLayer)
end

loadThemes()
initializeTerrorMusic()

hook.Add("InitPostEntity", "tr_create_music", initializeTerrorMusic)

timer.Simple(0, initializeTerrorMusic)

cvars.AddChangeCallback("fh_terror_volume", function(convarName, oldValue, newValue)
    if not lastTheme or not lastTerror then return end

    changeAllTerrorVolumes(lastTheme, activeTerrorLayerWeights, (tonumber(newValue) or 0) * GetConVar("snd_musicvolume"):GetFloat(), volumeChangeDuration)
end, "FH.TerrorRadius.Volume")

hook.Add("Think", "tr_update_music_channels", function()
    local currentTime = CurTime()

    for themeName, themeMusic in pairs(loadedMusic) do
        for layerName, musicEntry in pairs(themeMusic) do
            local audioChannel = musicEntry.channel

            local currentVolume = getInterpolatedMusicVolume(musicEntry, currentTime)

            if not isValidAudioChannel(audioChannel) then
				if currentVolume > 0 then
					musicEntry.channel = nil
					musicEntry.ready = false

					if not musicEntry.loading then
						startMusicEntryLoading(themeName, layerName, musicEntry)
					end
				end

                continue
            end

            musicEntry.currentVolume = currentVolume
            audioChannel:SetVolume(currentVolume)
			
			if currentVolume <= 0 then -- фикс земеновской штуки
				audioChannel:Stop()
			end
        end
    end
end)

lastTheme = nil
lastTerror = nil

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
	
	--[[ if isMoving(ply) then
		if isMoving(killer) then
			return true
		else return false end
	end --]]
	
	return false
end
function checkChase(ply, killer)
    local distance = ply:GetPos():Distance(killer:GetPos())
	local pill = pills.getMappedEnt(ply)
    local playerVisible = !ply:GetNoDraw() and ply:GetMaterial() ~= "models/null" and !IsValid(pill) or IsValid(pill) and pill:GetMaterial() ~= "models/null" and !pill:GetNoDraw()
	
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

local function getLayer(...)
	return terror_radius.getLayer(...)
end

-- Переходы МЕЖДУ лейерами

local function getDistanceBlendZone(themeName, distance)
    if distance > tr_Approach and distance < tr_Approach + firstToSecondBlendDistance then
        local sourceLayer = getLayer(themeName, "first_layer")
        local targetLayer = getLayer(themeName, "second_layer")

        return "first_to_second", sourceLayer, targetLayer, tr_Approach + firstToSecondBlendDistance, tr_Approach
    end

    if distance > tr_Close and distance < tr_Close + secondToThirdBlendDistance then
        local sourceLayer = getLayer(themeName, "second_layer") or getLayer(themeName, "first_layer")
        local targetLayer = getLayer(themeName, "third_layer")

        return "second_to_third", sourceLayer, targetLayer, tr_Close + secondToThirdBlendDistance, tr_Close
    end

    return nil
end

local function applyApproachDistanceBlend(themeName, selectedLayer, distance, volume)
    local previousTheme = state.lastTerrorTheme
    local previousDistance = tonumber(state.lastTerrorDistance)
    local sameTheme = previousTheme == themeName and previousDistance ~= nil

    local movingCloser = sameTheme and distance < previousDistance - distanceDirectionThreshold
    local movingAway = sameTheme and distance > previousDistance + distanceDirectionThreshold

    if not sameTheme or movingAway then
        state.activeDistanceBlendZone = nil
    end

    local zoneName, sourceLayer, targetLayer, outerDistance, innerDistance = getDistanceBlendZone(themeName, distance)
    local activeZone = state.activeDistanceBlendZone
    local canUseZone = zoneName and sourceLayer and targetLayer and sourceLayer ~= targetLayer
    local shouldBlend = canUseZone and not movingAway and (activeZone == zoneName or movingCloser)

    state.lastTerrorTheme = themeName
    state.lastTerrorDistance = distance

    if not shouldBlend then
        if not zoneName then
            state.activeDistanceBlendZone = nil
        end

        return false
    end

    state.activeDistanceBlendZone = zoneName

    local blendDistance = math.max(1, outerDistance - innerDistance)
    local targetFraction = math.Clamp((outerDistance - distance) / blendDistance, 0, 1)

    return terrorSetLayerBlend(themeName, sourceLayer, targetLayer, targetFraction, volume, distanceBlendResponseDuration, selectedLayer)
end

local imChasing = false

function terror_radius.imChasing()
	return imChasing or false
end

timer.Create("tr_update", 0.5, 0, function()
	local myself = LocalPlayer()

	if !IsValid(myself) then return end

	local closestGuyPos, closestTheme, layer = nil, nil, nil
	local closestLayerAllowsDistanceBlend = true
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
					if ply:IsDormant() then continue end
					if !ply:Alive() or (!everyoneKillers[myself] and ply:Team() == myself:Team()) then continue end

					local distance = myself:GetPos():Distance(ply:GetPos())

					local theme = currentKillers[myself]
					
					if distance < tr_Close then
						checkChase(ply, myself)
				
						local ent = myself:GetPillCostume()

						local shouldProccessMy = hook.Run("FH_HandleMineTerrorRadius", myself, ply, theme, ent)

						if shouldProccessMy == false then continue end

						if isChasing[ply] == myself and getLayer(theme, "chase") then
							layer = "chase"
							imChasing = true
							closestLayerAllowsDistanceBlend = false
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
				
				local ent = killer:GetPillCostume()

				local shouldProccessKiller = hook.Run("FH_HandleKillerTerrorRadius", myself, killer, theme, ent)

				if shouldProccessKiller == false then continue end

				if myself:IsSurvivor() and currentKillers[myself] then break end

				if killer == myself or !killer:Alive() or (!everyoneKillers[killer] and killer:Team() == myself:Team()) then continue end

				local distance = myself:GetPos():Distance(killer:GetPos())
				local allowDistanceBlend = true

				if closestGuyPos and distance > closestGuyPos then continue end
				
				local d_Far = tr_Far
				local d_Approach = tr_Approach
				local d_Close = tr_Close
				
				if distance > d_Far then continue end

				foundNoOne = false
				
				if distance < d_Far and distance > d_Approach then
					layer = getLayer(theme, "first_layer")
				elseif distance < d_Approach and distance > d_Close then
					layer = getLayer(theme, "second_layer") or getLayer(theme, "first_layer")
				elseif distance < d_Close then
					layer = getLayer(theme, "third_layer") or getLayer(theme, "second_layer") or getLayer(theme, "first_layer")
				end
				
				checkChase(myself, killer)

				if isChasing[myself] == killer then
					layer = "chase"
					allowDistanceBlend = false

					if getLayer(theme, "chase_low") and myself:Health() <= myself:GetMaxHealth() / 2 then
						layer = "chase_low"
					end
				end
				
				local forceLayer, forceNotFound = nil, nil
				forceLayer, forceNotFound = hook.Run("FH_HandleKillerTerrorLayers", myself, killer, theme, layer, ent)
				
				if forceLayer then
					layer = forceLayer
					allowDistanceBlend = false
				end
				
				if forceNotFound then
					layer = nil
					foundNoOne = true
					continue
				end

				closestGuyPos = distance
				closestTheme = theme
				closestLayerAllowsDistanceBlend = allowDistanceBlend
			end
		end
	end
	
	local closestTheme_handler, layer_handler = nil, nil
	closestTheme_handler, layer_handler = hook.Run("FH_HandlePostTerrorRadius", myself, closestTheme, layer)
	
	if closestTheme_handler and layer_handler then
		closestTheme = closestTheme_handler
		layer = layer_handler
		closestLayerAllowsDistanceBlend = false
		foundNoOne = false
	end

	if foundNoOne and !imChasing then
		isChasing[myself] = nil
		terrorStop(0.2)
	end

	if (!closestTheme or !layer) and not imChasing then 
		terrorStop(0.2)
		return 
	end

	local terrorVolume = fh_terror_volume:GetFloat() * GetConVar("snd_musicvolume"):GetFloat()
	local isChaseLayer = imChasing or layer == "chase" or layer == "chase_low" or layer == "chase_rage"

	if isChaseLayer then
		resetDistanceBlendState()

		if layer == "chase" and lastTerror ~= "chase" --[[and fh_terror_enabled:GetBool() and terrorVolume > 0--]] then
			surface.PlaySound("chase_begin.mp3")
		end

		terrorSetVolume(closestTheme, layer, terrorVolume, layerCrossfadeDuration)
		return
	end

	if closestLayerAllowsDistanceBlend and closestGuyPos and applyApproachDistanceBlend(closestTheme, layer, closestGuyPos, terrorVolume) then
		return
	end

	if not closestLayerAllowsDistanceBlend or not closestGuyPos then
		resetDistanceBlendState()
	end

	terrorSetVolume(closestTheme, layer, terrorVolume, layerCrossfadeDuration)
end)

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
	end
end

function terror_radius.resetPlayerTheme(ply)
	if !ply or !ply:IsPlayer() then return end
	
	if currentKillers[ply] then
		currentKillers[ply] = nil
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