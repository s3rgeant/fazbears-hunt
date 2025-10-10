if SERVER then return end

local currentKillers = currentKillers or {}
local stealthKillers = {}
local trUpdating = false
local availableThemes = availableThemes or {}
local loadedMusic = loadedMusic or {}
local isChasing = {}
local chaseTimers = {}

--НАСТРОЙКИ ДИСТАНЦИЙ
local tr_Far = 2600
local tr_Approach = 1400
local tr_Close = 800

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
        ["chase_low"] = "chase_lowhp.wav"
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

                local uniqueName = (dir .. layer)

                if loadedMusic[uniqueName] then
                    loadedMusic[uniqueName]:Stop()
                end
            
                loadedMusic[uniqueName] = CreateSound(game.GetWorld(), "#music/chase/" .. dir .. "/" .. filepath)
                loadedMusic[uniqueName]:SetSoundLevel(0)
            end
        end
    end
end )

local lastTRMusic = nil

local function terrorStop(dur)
    if lastTRMusic and loadedMusic[lastTRMusic] then
        loadedMusic[lastTRMusic]:ChangeVolume(0, dur)

        local rember = lastTRMusic

        timer.Create("StopTRMusic_" .. rember, dur + 0.05, 1, function()
            if loadedMusic[rember] then
                loadedMusic[rember]:Stop()
            end
        end)

        lastTRMusic = nil
    end
end

function terrorSetVolume(name, volume, dur)
    dur = dur or 0

    if timer.Exists("StopTRMusic_" .. name) then
        timer.Remove("STopTRMusic_" .. name)
    end

    if lastTRMusic and name ~= lastTRMusic and loadedMusic[lastTRMusic] then
        loadedMusic[lastTRMusic]:ChangeVolume(0, dur)
    end

    local soundObj = loadedMusic[name]
    if not soundObj then return end

    if soundObj:IsPlaying() then
        soundObj:Stop()
    end

    if !soundObj:IsPlaying() then
        soundObj:PlayEx(0, 100)
    end
    
    soundObj:ChangeVolume(volume, dur)

    if volume <= 0 then
        timer.Create("StopTRMusic_" .. name, dur + 0.05, 1, function()
            if loadedMusic[name] then 
                loadedMusic[name]:Stop()
            end
        end)
    else
        lastTRMusic = name
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
local function isPlayerMoving(ply)
    return ply:GetVelocity():Length() > 5
end
local function isPlayerRunning(ply)
    return ply:GetVelocity():Length() > ply:GetRunSpeed() * 0.9
end
function checkChase(ply, killer)
    local distance = ply:GetPos():Distance(killer:GetPos())
    local killerMoving = isPlayerMoving(killer)
    local playerMoving = isPlayerMoving(ply)
    if distance < tr_Close and isKillerLookingAt(ply, killer) and killerMoving and playerMoving and killer:GetMoveType() ~= MOVETYPE_NOCLIP then
        isChasing[ply] = true
        if chaseTimers[ply] then
            timer.Remove(chaseTimers[ply])
            chaseTimers[ply] = nil
        end
    elseif isChasing[ply] then
        if not chaseTimers[ply] then
            chaseTimers[ply] = "ChaseEndTimer_" .. ply:EntIndex()
            timer.Create(chaseTimers[ply], 5, 1, function()
                isChasing[ply] = nil
            end)
        end
    end
end

if !timer.Exists("tr_update") then
    timer.Create("tr_update", 0.5, 0, function()
        local myself = LocalPlayer()

        if !IsValid(myself) then return end

        local closestGuyPos, closestTheme, layer = nil, nil, nil
        local foundNoOne = true
        local imChasing = false

        hook.Run("FH_TerrorRadiusUpdate", currentKillers)
        if !table.IsEmpty(currentKillers) and myself:Alive() then
            if currentKillers[myself] then
                for _, ply in player.Iterator() do
                    if !ply:Alive() or ply:Team() == myself:Team() then continue end

		            local distance = myself:GetPos():Distance(ply:GetPos())

                    local theme = currentKillers[myself]
                    
                    if distance < tr_Close then
                        checkChase(ply, myself)

                        if isChasing[ply] then
                            layer = "chase"
                            imChasing = true
                            if availableThemes[theme] and availableThemes[theme]["chase_low"] then
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
                if !theme or !killer then continue end 

                if myself:IsSurvivor() and currentKillers[myself] then break end

                if killer == myself or !killer:Alive() or killer:Team() == myself:Team() then continue end

		        local distance = myself:GetPos():Distance(killer:GetPos())

                if closestGuyPos and closestGuyPos > distance then continue end
                
                if distance > tr_Far then continue end

                if stealthKillers[killer] then
                    if !isPlayerRunning(killer) and !isChasing[myself] then
                        continue
                    end
                end

                foundNoOne = false

                if isChasing[myself] then
                    checkChase(myself, killer)
                    layer = "chase"
                    if availableThemes[theme] and availableThemes[theme]["chase_low"] then
                        if myself:Health() <= myself:GetMaxHealth() / 2 then
                            layer = "chase_low"
                        end
                    end
                else
                    if distance < tr_Far and distance > tr_Approach or distance < tr_Far and (killer:GetMoveType() == MOVETYPE_NOCLIP or killer:GetPill() and killer:GetPill():GetMaterial() == 'models/null') then
                        layer = "first_layer"
                    elseif distance < tr_Approach and distance > tr_Close then
                        layer = "second_layer"
                    elseif distance < tr_Close then
                        layer = "third_layer"
                    end
                end

                if layer == "third_layer" then
                    checkChase(myself, killer)
                end

                closestGuyPos = distance
                closestTheme = theme
            end
        end

        if foundNoOne and !imChasing then
            terrorStop(0.5)
        end

        if !closestTheme or !layer then return end

        if (closestTheme .. layer) == lastTRMusic then return end
        
        terrorSetVolume(closestTheme .. layer, 1, 0.5)
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
    ["pill_wfoxy2"] = "springtrap",
    ["pill_endo02"] = "springtrap",
    ["pill_wbonnie2"] = "springtrap",
    ["pill_wfreddy2"] = "springtrap",
    ["pill_wchica2"] = "springtrap",
    ["pill_sfreddy2"] = "springtrap",
    ["pill_clown"] = "springtrap",
    ["pill_springtrap"] = "springtrap",
    ["pill_plushtrap"] = "springtrap",
    ["pill_mangle"] = "springtrap",
    ["mask"] = "mask"
}

local stealthAnims = {
    ["pill_springtrap"] = true,
    ["pill_mangle"] = true
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

hook.Add("PillApply", "tr_apply_chase", function(ply, name)
    if IsValid(ply) then
        local selectedTheme = getThemeByName(name)
        if selectedTheme then
            currentKillers[ply] = selectedTheme
            if stealthAnims[name] then
                stealthKillers[ply] = true
            end
        end
    end
end)

hook.Add("FH_KillerObsessed", "tr_apply_chase_maskkiller", function(ply)
    if IsValid(ply) then
        local selectedTheme = getThemeByName("mask")
        if selectedTheme then
            currentKillers[ply] = selectedTheme
        end
    end
end)

hook.Add("FH_KillerLostObsession", "tr_restore_chase_maskkiller", function(ply)
    if currentKillers[ply] then
        currentKillers[ply] = nil
        if stealthKillers[ply] then
            stealthKillers[ply] = false
        end
    end
end)

hook.Add("PillRestore", "tr_restore_chase", function(ply)
    if currentKillers[ply] then
        currentKillers[ply] = nil
        if stealthKillers[ply] then
            stealthKillers[ply] = false
        end
    end
end)

function start_TR_Update()
    trUpdating = true
    timer.UnPause("tr_update")
end

function stop_TR_Update()
    trUpdating = false
    timer.Pause("tr_update")
    terrorStop(0.5)
end