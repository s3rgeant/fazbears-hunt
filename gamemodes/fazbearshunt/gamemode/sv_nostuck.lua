local spawnOffset = 70
local maxAttempts = 20
local hullMin = Vector(-16, -16, 0)
local hullMax = Vector(16, 16, 72)

hook.Add("PlayerSelectSpawn", "PreventPlayerStuckSpawn", function(ply)
    local spawns

    if ply:Team() == 2701 or ply:Team() == 27 or team.GetName(ply:Team()):lower():match("animatronic") then
        spawns = ents.FindByClass("info_player_killer") -- кастомные спавны для аниматроников
        if #spawns == 0 then
            spawns = ents.FindByClass("info_player_start")
            spawns = updateSpawnList(spawns)
        end
    else
        spawns = ents.FindByClass("info_player_start")
        spawns = updateSpawnList(spawns)
    end

    if #spawns == 0 then
        spawns = ents.FindByClass("info_player_start")
    end

    if #spawns == 0 then
        return
    end

    local chosenSpawn = spawns[math.random(#spawns)]
    local spawnPos = chosenSpawn:GetPos()
    local spawnAng = chosenSpawn:GetAngles()

    local attempts = 0
    local isPositionFound = false

    while attempts < maxAttempts do
        local isOccupied = false

        for _, otherPly in player.Iterator() do
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

function updateSpawnList(tab)
	spws = tab
	
	spws = table.Add( spws, ents.FindByClass( "info_player_deathmatch" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_combine" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_rebel" ) )
	spws = table.Add( spws, ents.FindByClass( "info_coop_spawn" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_counterterrorist" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_terrorist" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_axis" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_allies" ) )
	spws = table.Add( spws, ents.FindByClass( "gmod_player_start" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_teamspawn" ) )
	spws = table.Add( spws, ents.FindByClass( "ins_spawnpoint" ) )
	spws = table.Add( spws, ents.FindByClass( "aoc_spawnpoint" ) )
	spws = table.Add( spws, ents.FindByClass( "dys_spawn_point" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_pirate" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_viking" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_knight" ) )
	spws = table.Add( spws, ents.FindByClass( "diprip_start_team_blue" ) )
	spws = table.Add( spws, ents.FindByClass( "diprip_start_team_red" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_red" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_blue" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_coop" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_human" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_zombie" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_zombiemaster" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_fof" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_desperado" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_vigilante" ) )
	spws = table.Add( spws, ents.FindByClass( "info_survivor_rescue" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_attacker" ) )
	spws = table.Add( spws, ents.FindByClass( "info_player_defender" ) )
	spws = table.Add( spws, ents.FindByClass( "info_ff_teamspawn" ) )
	
	return spws
end

local ignoredCollisionGroups = {COLLISION_GROUP_DEBRIS_TRIGGER, COLLISION_GROUP_PASSABLE_DOOR, COLLISION_GROUP_WEAPON}

local function IsPlayerStuck(ply)
    local tr = util.TraceHull({
        start = ply:GetPos(),
        endpos = ply:GetPos(),
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
		filter = function(ent)
			return ent != ply and !table.HasValue(ignoredCollisionGroups, ent:GetCollisionGroup()) and 
				(ent:IsPlayer() and ent:GetCollisionGroup() != COLLISION_GROUP_NONE 
				and ply:GetCollisionGroup() != COLLISION_GROUP_PASSABLE_DOOR)
		end,
		mask = MASK_PLAYERSOLID
    })
    return tr.Hit
end

local function FindSafePosition(ply)
    local startPos = ply:GetPos()
    local directions = {
        Vector(50, 0, 0),
        Vector(-50, 0, 0),
        Vector(0, 50, 0),
        Vector(0, -50, 0),
        Vector(0, 0, 50),
        Vector(0, 0, -50),
    }

    for i = 1, 10 do
        for _, dir in ipairs(directions) do
            local checkPos = startPos + dir * i
            local tr = util.TraceHull({
                start = checkPos,
                endpos = checkPos,
                mins = ply:OBBMins(),
                maxs = ply:OBBMaxs(),
                filter = ply
            })

            if not tr.Hit then
                return checkPos
            end
        end
    end

    return nil
end

local nextCheckTime = {}
function keyPressCheck(ply, key)
	if (!ply:Alive() or ply:Team() == TEAM_SPECTATOR) or ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetCollisionGroup() == COLLISION_GROUP_DEBRIS then return end
    if key == IN_FORWARD or key == IN_MOVELEFT or key == IN_MOVERIGHT or key == IN_DUCK then
		local curTime = CurTime()
		if !nextCheckTime[ply] or curTime >= nextCheckTime[ply] then
			if IsPlayerStuck(ply) then
				local safePos = FindSafePosition(ply)
				if safePos then
					ply:SetPos(safePos)
					ply:DropToFloor()
					nextCheckTime[ply] = curTime + 4
				end
			else
				nextCheckTime[ply] = curTime + 2
			end
		end
    end
end

local PLAYER = FindMetaTable("Player")

function PLAYER:IsStuck()
	return IsPlayerStuck(self)
end

function PLAYER:Unstuck()
	local safePos = FindSafePosition(self)
	
	if safePos then
		self:SetPos(safePos)
		self:DropToFloor()
	end
end

hook.Add("fh_startgame", "fh_startgame_unstuck", function(roundType)

	for i, ply in player.Iterator() do
		timer.Simple(i/10, function()
			if ply:IsStuck() then
				ply:Unstuck()
			end
		end)
	end
	
	hook.Add("KeyPress", "CheckStuckAndTeleport", function(ply, key)
		keyPressCheck(ply,key)
	end)
	
	if timer.Exists("remove_unstuck_hook") then 
		timer.Remove("remove_unstuck_hook")
	end
	
	timer.Create("remove_unstuck_hook", 5, 1, function()
		hook.Remove("KeyPress", "CheckStuckAndTeleport")
	end)
end)

hook.Add("fh_defibrillator_spawn", "fh_startgame_unstuck", function()
	
	hook.Add("KeyPress", "CheckStuckAndTeleport", function(ply, key)
		keyPressCheck(ply,key)
	end)
	
	if timer.Exists("remove_unstuck_hook") then 
		timer.Remove("remove_unstuck_hook")
	end
	
	timer.Create("remove_unstuck_hook", 10, 1, function()
		hook.Remove("KeyPress", "CheckStuckAndTeleport")
	end)
end)