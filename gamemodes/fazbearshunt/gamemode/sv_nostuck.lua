local spawnOffset = 70
local maxAttempts = 20
local hullMin = Vector(-16, -16, 0)
local hullMax = Vector(16, 16, 72)

hook.Add("PlayerSelectSpawn", "PreventPlayerStuckSpawn", function(ply)
    local spawns = ents.FindByClass("info_player_start")
    if #spawns == 0 then
        spawns = ents.FindByClass("info_player_deathmatch")
    end

    if #spawns == 0 then
        return Vector(0, 0, 0)
    end

    local chosenSpawn = spawns[math.random(#spawns)]
    local spawnPos = chosenSpawn:GetPos()
    local spawnAng = chosenSpawn:GetAngles()

    local attempts = 0
    local isPositionFound = false

    while attempts < maxAttempts do
        local isOccupied = false

        for _, otherPly in ipairs(player.GetAll()) do
            if otherPly ~= ply and IsValid(otherPly) then
                if otherPly:GetPos():Distance(spawnPos) < spawnOffset then
                    isOccupied = true
                    break
                end
            end
        end

        if isOccupied then
            local angle = math.rad(math.random(0, 360))
            local offset = Vector(math.cos(angle), math.sin(angle), 0) * spawnOffset
            spawnPos = chosenSpawn:GetPos() + offset
            attempts = attempts + 1
        else
            local trace = {}
            trace.start = spawnPos + Vector(0, 0, 10)
            trace.endpos = spawnPos + Vector(0, 0, 10)
            trace.mins = hullMin
            trace.maxs = hullMax
            trace.filter = ply

            local tr = util.TraceHull(trace)

            if not tr.Hit then
                isPositionFound = true
				debugoverlay.Line(spawnPos + Vector(0, 0, 10), spawnPos + Vector(0, 0, 10), 15, Color(255, 0, 0), true)
                break
            else
                local angle = math.rad(math.random(0, 360))
                local offset = Vector(math.cos(angle), math.sin(angle), 0) * spawnOffset
                spawnPos = spawnPos + offset
                attempts = attempts + 1
            end
        end
    end

    if not isPositionFound then
        spawnPos = chosenSpawn:GetPos()
    end

    local tempSpawn = ents.Create("info_player_start")
    tempSpawn:SetPos(spawnPos)
    tempSpawn:SetAngles(spawnAng)
    tempSpawn:Spawn()

    timer.Simple(1, function()
        if IsValid(tempSpawn) then
            tempSpawn:Remove()
        end
    end)

    return tempSpawn
end)