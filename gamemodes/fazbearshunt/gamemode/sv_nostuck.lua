fhspawns = fhspawns or {}

local spawnOffset = 70
local maxAttempts = 20
local hullMin = Vector(-16, -16, 0)
local hullMax = Vector(16, 16, 72)

hook.Add("PlayerSelectSpawn", "PreventPlayerStuckSpawn", function(ply)
	if game.SinglePlayer() then
		return
	end

    local spawns = {}

    if ply:IsAnimatronic() or team.GetName(ply:Team()):lower():match("animatronic") then
		local anim_spawns = ents.FindByClass("info_player_killer") -- кастомные спавны для аниматроников
		
        if #anim_spawns ~= 0 then
			local foundSpawns = false
			
			for _, ent in ipairs(anim_spawns) do
				local pill = ply:GetPill()
				if !IsValid(pill) then continue end
			
				if ent.AnimType and pill:GetPillName() == ent.AnimType then
					table.insert(spawns, ent)
					foundSpawns = true
				end
			end
			
			if #spawns == 0 then
				for _, ent in ipairs(anim_spawns) do
					if !ent.AnimType or ent.AnimType:len() < 1 then
						table.insert(spawns, ent)
					end
				end
			end
			
			if #spawns == 0 then
				spawns = anim_spawns
			end
        end
    end

    if #spawns == 0 then
        spawns = ents.FindByClass("info_player_start")
        spawns = updateSpawnList(spawns)
    end

    if #spawns == 0 then
        return
    end
	
	return spawns[math.random(#spawns)]
end)

local hasSpawns = {}
hook.Add("EntityKeyValue", "rember_spawns", function(ent)
	if ent:GetClass() == "info_player_killer" then
		if ent.AnimType then
			if !hasSpawns[ent.AnimType] then hasSpawns[ent.AnimType] = {} end
			hasSpawns[ent.AnimType][ent] = true
		end
	end
end)

function fhspawns.GetSpawnsFor(name)
	if hasSpawns[name] then
		return hasSpawns[name]
	end
	return nil
end

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

local ignoredCollisionGroups = {
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true, 
	[COLLISION_GROUP_PASSABLE_DOOR] = true, 
	[COLLISION_GROUP_WEAPON] = true,
}

local function IsPlayerStuck(ply)
    if !IsValid(ply) then return false end
    local tr = util.TraceHull({
        start = ply:GetPos(),
        endpos = ply:GetPos(),
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
		filter = ply,
		collisiongroup = COLLISION_GROUP_PLAYER,
		mask = MASK_SOLID
    })
    return tr.Hit
end

local function QuickIsStuck(ent)
	if not IsValid(ent) then return false end

	local trace = util.TraceEntity({
		start = ent:GetPos(),
		endpos = ent:GetPos(),
		filter = ent,
		mask = MASK_SOLID
	}, ent)

	return trace.Hit
end

local function FindSafePosition(ply, startPos)
	if !startPos then
		startPos = ply:GetPos()
	end
    local directions = {
        Vector(12, 0, 0),
        Vector(-12, 0, 0),
        Vector(0, 12, 0),
        Vector(0, -12, 0),
        Vector(0, 0, 5),
        Vector(0, 0, -5),
    }
	
	local Hull_OBBmins = ply:OBBMins()
	local Hull_OBBMaxs = ply:OBBMaxs()

    for i = 1, 12 do
        for _, dir in ipairs(directions) do
            local checkPos = startPos + dir * i
            local tr = util.TraceHull({
                start = checkPos,
                endpos = checkPos,
                mins = Hull_OBBmins,
                maxs = Hull_OBBMaxs,
                filter = ply
            })
			
			debugoverlay.Box( checkPos, Hull_OBBmins, Hull_OBBMaxs, 10, Color( 255, 255, 255, 10 ) )

            if not tr.Hit then
                return checkPos
            end
        end
    end
	
	local area = navmesh.GetNearestNavArea( startPos, nil, nil, nil, false )
	
	if IsValid(area) then
		return area:GetCenter()
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

function PLAYER:Unstuck(reservedPos)
	local safePos = FindSafePosition(self)
	
	if safePos then
		self:SetPos(safePos)
		if !self:GetNWBool("_MangleHooked") then
			self:DropToFloor()
		end
		return
	end
	
	if reservedPos and isvector(reservedPos) then
		safePos = FindSafePosition(self, reservedPos)
		
		if safePos then
			self:SetPos(safePos)
			if !self:GetNWBool("_MangleHooked") then
				self:DropToFloor()
			end
			return
		end
	end
end

local ply_oldCollisions = {}
function PLAYER:NoPlayerCollide(duration)
	if !IsValid(self) then return end
	
	local timerName = "fh_repeat_unstuck" .. self:EntIndex()
	
	if timer.Exists(timerName) then return end

	duration = duration or 0.5
	
	ply_oldCollisions[self] = self:GetCollisionGroup()
	
	self:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)
	self:CollisionRulesChanged()
	
	timer.Create(timerName, duration, 0, function()
		if !IsValid(self) or !self:Alive() or self:GetCollisionGroup() ~= COLLISION_GROUP_PASSABLE_DOOR then
			timer.Remove(timerName)
			if self:IsStuck() then
				self:NoPlayerCollide()
			end
			return
		end
		
		if IsValid(self) and !QuickIsStuck(self) then
			self:SetCollisionGroup(ply_oldCollisions[self])
			self:CollisionRulesChanged()
			timer.Remove(timerName)
		end
	end)
end

function PLAYER:RepeatRestoreCollision(duration)
	duration = duration or 0.5
	
	timer.Create("fh_repeat_unstuck" .. self:EntIndex(), duration, 0, function()
		if IsValid(self) and !QuickIsStuck(self) then
			self:SetCollisionGroup(COLLISION_GROUP_PLAYER)
			timer.Remove("fh_repeat_unstuck" .. self:EntIndex())
			return
		end
		
		if !IsValid(self) or !self:Alive() then
			timer.Remove("fh_repeat_unstuck" .. self:EntIndex())
		end
	end)
end

hook.Add("fh_startgame", "fh_startgame_unstuck", function(roundType)
	--for i, ply in player.Iterator() do
		--timer.Simple(i/10, function()
			--if ply:IsStuck() then
				--ply:Unstuck()
			--end
		--end)
	--end
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