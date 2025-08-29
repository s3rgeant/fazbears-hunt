stats = stats or {}
local playerStats = {}
local statMeta = {}

function stats.SetMin(statName, minValue)
    statMeta[statName] = statMeta[statName] or {}
    statMeta[statName].min = minValue
end

stats.SetMin("saw_animatronic", 10)
stats.SetMin("ran_meters", 2000)
stats.SetMin("got_highlighted", 6)
stats.SetMin("got_damaged", 100)
stats.SetMin("revived", 3)
stats.SetMin("tasered", 5)
stats.SetMin("got_slowed", 3)
stats.SetMin("evaded_blind_rage", 2)
stats.SetMin("evaded_highlight", 3)
stats.SetMin("got_hit_by_plushtrap", 10)
stats.SetMin("broke_cupcakes", 6)
stats.SetMin("evaded_sfreddy_appearance", 5)

stats.SetMin("jumped", 80)
stats.SetMin("slipped_on_banana", 15)
stats.SetMin("broke_props", 25)

stats.SetMin("killed", 8)
stats.SetMin("killed_using_props", 3)
stats.SetMin("grabbed", 7)
stats.SetMin("damaged", 500)
stats.SetMin("hitted_using_hammer", 15)
stats.SetMin("killed_using_cupcake", 5)
stats.SetMin("slowed_using_cupcake", 7)
stats.SetMin("killed_using_blind_rage", 5)
stats.SetMin("killed_targets", 3)
stats.SetMin("killed_using_steel_grip_by_falldamage", 2)

stats.SetMin("broke_doors", 15)
stats.SetMin("broke_cameras", 10)
stats.SetMin("placed_cameras", 9)
stats.SetMin("killed_using_car", 3)
stats.SetMin("damaged_by_winded_up_plushtrap", 70)

function stats.Add(ply, statName, value)
    local sid = ply:SteamID()
	value = value or 1
    
    if not playerStats[sid] then
        playerStats[sid] = {
            ply = ply
        }
    end

    local stata = playerStats[sid]
    stata[statName] = (stata[statName] or 0) + value
end

function stats.GetTop(statName)
    local topPlayer, topValue = nil, -math.huge

    for _, data in pairs(playerStats) do
        local value = data[statName] or 0
        if value > topValue then
            topValue = value
            topPlayer = data.ply
        end
    end

    return topPlayer, topValue
end

util.AddNetworkString("fh_top_stats")
function fh.AnnounceStats(maxCount)
    maxCount = maxCount or 5

    local allCandidates = {}
	
	if table.IsEmpty(playerStats) then return end

    local firstKey = next(playerStats)
	if not firstKey then return end

	for statName, _ in pairs(playerStats[firstKey]) do
        if statName == "ply" then continue end

        local ply, value = stats.GetTop(statName)

        local min = statMeta[statName] and statMeta[statName].min or 1
        if not ply or !IsValid(ply) or value < min then continue end

        local format = statName

        table.insert(allCandidates, {
            stat = statName,
            nick = ply:Nick(),
            steamid = ply:SteamID(),
            value = value,
            format = format
        })
    end

    if #allCandidates == 0 then return end

    local uniquePlayers = {}
    local finalStats = {}

    for _, candidate in RandomPairs(allCandidates) do
        if uniquePlayers[candidate.steamid] then continue end
        uniquePlayers[candidate.steamid] = true
        table.insert(finalStats, candidate)
        if #finalStats >= maxCount then break end
    end

    if #finalStats == 0 then return end

    net.Start("fh_top_stats")
    net.WriteUInt(#finalStats, 8)
    for _, stat in ipairs(finalStats) do
        net.WriteString(stat.format)
        net.WriteString(stat.nick)
        net.WriteUInt(stat.value, 32)
    end
    net.Broadcast()
end

hook.Add("fh_postendgame", "fh_show_stats", function(killerVictory, animatronics)
    fh.AnnounceStats(5)
	table.Empty(playerStats)
end)

-- НЕКОТОРЫЕ СТАТЫ АВТОМАТИЧЕСКИЕ, НУ КАРОЧЕ ЭТИ СНИЗУ. ДА
hook.Add("PlayerDeath", "fh_stats_deaths", function( victim, inflictor, attacker )
	if victim:IsPlayer() and attacker:IsPlayer() and attacker:Team() == 2701 then
		if IsValid(inflictor) and inflictor:GetClass() == "prop_physics" then
			stats.Add(attacker, "killed_using_props", 1)
		end
		
		stats.Add(attacker, "killed", 1)
		if victim._cupcakeAffected then
			stats.Add(attacker, "killed_using_cupcake", 1)
		end
	end
end)

hook.Add("PostEntityTakeDamage", "fh_stats_damage", function(target, dmginfo)
	if target:IsPlayer() and target:Team() ~= 2701 then
		stats.Add(target, "got_damaged", dmginfo:GetDamage())
		
		local attacker = dmginfo:GetAttacker()
		local inflictor = dmginfo:GetInflictor()
		
		if IsValid(attacker) and attacker:IsPlayer() and attacker:Team() == 2701 then
			stats.Add(attacker, "damaged", dmginfo:GetDamage())
			if IsValid(inflictor) then
				if inflictor:GetClass() == "v_clown" then
					stats.Add(attacker, "hitted_using_hammer", 1)
				elseif inflictor:GetClass() == "v_plushtrap" then
					stats.Add(target, "got_hit_by_plushtrap", 1)
				end
			end
		end
		
		if dmginfo:IsFallDamage() then
			timer.Simple(0, function()
				if !target:Alive() and target._LastEndo ~= nil and target._GrabbedByEndoTime > CurTime() - 10 then
					stats.Add(target._LastEndo, "killed_using_steel_grip_by_falldamage", 1)
				end
			end)
		end
	end
	
	if target:GetClass() == "cakemine" then
		
		local attacker = dmginfo:GetAttacker()
		local inflictor = dmginfo:GetInflictor()
		timer.Simple(0, function()
			if !IsValid(target) and attacker:IsPlayer() and attacker:IsSurvivor() then
				stats.Add(attacker, "broke_cupcakes", 1)
			end
		end)
	end
end)

hook.Add("OnPlayerJump", "fh_stats_jumping", function(ply, vel)
	stats.Add(ply, "jumped", 1)
end)

hook.Add( "PropBreak", "fh_stats_props", function( attacker, prop )
	if IsValid( attacker ) and attacker:IsPlayer() then 
		stats.Add(attacker, "broke_props", 1)
	end
end)

local rememberLucky = {}
hook.Add("FH_SFreddySubmergeOut", "fh_stats_sfreddy_appearance", function(sfreddy, ent)
	local luckyplayers = fh_get_nearest_players(sfreddy:GetPos(), 200, sfreddy)
	
	if luckyplayers then
	
		for _, ply in pairs(luckyplayers) do
			rememberLucky[ply] = true
		end
	
	end
end)

hook.Add("FH_SFreddySubmergePostIn", "fh_stats_sfreddy_dissappear", function(sfreddy, ent)
	
	for ply, v in pairs(rememberLucky) do
		if ply:IsSurvivor() and ply:Alive() then
			stats.Add(ply, "evaded_sfreddy_appearance", 1)
		end
		rememberLucky[ply] = false
	end
end)

-- считаем метры
local lastPos = {}
local accumMeters = {}
local lastUpdate = 0

local CurTime = CurTime
local IsValid = IsValid
local GetHumans = player.GetHumans
local MOVETYPE_WALK = MOVETYPE_WALK
local floor = math.floor

local function dist(a, b)
    return (a - b):Length()
end

hook.Add("Think", "fh_stats_run_tracker", function()
    local now = CurTime()
    if now - lastUpdate < 0.1 then return end
    lastUpdate = now

    for _, ply in player.Iterator() do
        if not IsValid(ply) or not ply:Alive() or ply:Team() == TEAM_SPECTATOR or ply:GetMoveType() ~= MOVETYPE_WALK then continue end

        local pos = ply:GetPos()
        local prev = lastPos[ply]

        if prev then
            local meters = dist(pos, prev) / 39.37
            if meters > 0 then
                accumMeters[ply] = (accumMeters[ply] or 0) + meters
                local whole = floor(accumMeters[ply])
                if whole > 0 then
                    accumMeters[ply] = accumMeters[ply] - whole
                    stats.Add(ply, "ran_meters", whole)
                end
            end
        end

        lastPos[ply] = pos
    end
end)

hook.Add("PlayerDisconnected", "SuperRunTrackerCleanup", function(ply)
    lastPos[ply] = nil
    accumMeters[ply] = nil
	rememberLucky[ply] = nil
end)