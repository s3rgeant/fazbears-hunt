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

    local tempSpawn = ents.Create("info_player_start")
    tempSpawn:SetPos(findSpawnPos(spawnPos, ply))
    tempSpawn:SetAngles(spawnAng)
    tempSpawn:Spawn()

    timer.Simple(1, function()
        if IsValid(tempSpawn) then
            tempSpawn:Remove()
        end
    end)

    return tempSpawn
end)

function findSpawnPos(pos, player)
    local maxDistance = 500
    local stepSize = 25

    for radius = stepSize, maxDistance, stepSize do
        for angle = 0, 360, 45 do
            local offsetX = math.cos(math.rad(angle)) * radius
            local offsetY = math.sin(math.rad(angle)) * radius
            local testPos = pos + Vector(offsetX, offsetY, 0)

            local trace = util.TraceEntity({
                start = testPos,
                endpos = testPos,
                filter = player,
				mask = MASK_ALL,
            }, player)

            if !trace.Hit then
				debugoverlay.Line(pos, testPos, 15, Color(255, 0, 0), true)
                return testPos
            end
        end
    end

    return pos
end