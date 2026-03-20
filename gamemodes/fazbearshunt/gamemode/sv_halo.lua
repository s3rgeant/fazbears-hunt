highlight = highlight or {}

util.AddNetworkString("PlayHighlightSounds")
util.AddNetworkString("AddAffectedPlayers")
util.AddNetworkString("RemoveAffectedPlayer")
util.AddNetworkString("ToggleHighlightSound")
util.AddNetworkString("NotifySpectators")
	
local affectedPlayers = {}
local haloUsers = {}
local countNotAffected = {}

hook.Add( "PostCleanupMap", "fh_halo_reset", function( name )
	table.Empty(haloUsers)
	table.Empty(affectedPlayers)
	table.Empty(countNotAffected)
end)

function highlight.ByDistance(ply, ent)
	local totalPlayers = {}
	if !haloUsers[ply] or haloUsers[ply].hl_Time < CurTime() then -- чел не под кулдауном? разрешай
		highlight.Cooldown(ply, conVars.halo_cooldown:GetFloat())
		
		local outworlded = getOutworldVictims()
	
		local affectedNicknames = {}
		for _, player in player.Iterator() do
			if player ~= ply and player:IsPlayer() 
							and player:IsSurvivor()
							and !outworlded[player]
							and hook.Run("FH_ShouldHighlightPlayer", player, ply, ent) ~= false then
				local distance = ply:GetPos():Distance(player:GetPos())
				
				local isAffected = distance <= conVars.halo_radius:GetInt() or (conVars.fair_hl:GetBool() and countNotAffected[player] and countNotAffected[player] >= 2)
				
				if (isAffected) then -- передаём чуваку кто подсвечивается в радиусе
					table.insert(totalPlayers, player)
					table.insert(affectedNicknames, player:Nick())
				
					highlight.Add(ply, player)
					
					stats.Add(player, "got_highlighted", 1)
					countNotAffected[player] = 0
				else
					stats.Add(player, "evaded_highlight", 1)
					if !countNotAffected[player] then countNotAffected[player] = 0 end
					countNotAffected[player] = countNotAffected[player] + 1
				end
				
				highlight.NotifyTarget(player, ent, isAffected)
			end
		end
				
		if team.NumPlayers(TEAM_SPECTATOR) > 0 and !table.IsEmpty(affectedNicknames) then
			net.Start('NotifySpectators')
			net.WriteTable(affectedNicknames)
			net.WriteEntity(ply)
			net.Send( team.GetPlayers(TEAM_SPECTATOR) )
		end
		
		net.Start("ToggleHighlightSound") -- включаем чуваку звук что он дофига крутой со спермой под губой
		net.WriteBool(!table.IsEmpty(totalPlayers))
		net.Send(ply)
		
		hook.Run("FH_HighlightByDistance", ply, ent, totalPlayers)
	end
end

local function highlight_remove_Timer(maboy, ply, duration)
	if not IsValid(maboy) or not IsValid(ply) then return end

	affectedPlayers[maboy] = affectedPlayers[maboy] or {}

	local curTime = CurTime()
	local prevTime = affectedPlayers[maboy][ply] or 0
	local newTime = math.max(prevTime, curTime + duration)

	affectedPlayers[maboy][ply] = newTime

	local timerName = "highlight_remove_" .. maboy:EntIndex() .. "_" .. ply:EntIndex()

	timer.Remove(timerName)
	timer.Create(timerName, newTime - curTime, 1, function()
		if affectedPlayers[maboy] and affectedPlayers[maboy][ply] then
			affectedPlayers[maboy][ply] = nil
		end

		if IsValid(maboy) and IsValid(ply) and ply:Alive() then
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(ply)
			net.Send(maboy)
		end

		if affectedPlayers[ply] and table.IsEmpty(affectedPlayers[maboy]) then
			affectedPlayers[maboy] = nil
		end
	end)
end

function highlight.Add(maboy, players, duration, color)
	assert(IsValid(maboy), "Can't highlight players for invalid maboy")
	assert(players, "Players is nil")

	duration = duration or conVars.halo_time:GetFloat() or 5
	color = color or Color(255, 0, 0)

	local sendTbl = {}

	if istable(players) then
		for _, ply in ipairs(players) do
			if IsValid(ply) then
				table.insert(sendTbl, ply)
				highlight_remove_Timer(maboy, ply, duration)
			end
		end
	else
		if IsValid(players) then
			sendTbl[1] = players
			highlight_remove_Timer(maboy, players, duration)
		end
	end

	if #sendTbl > 0 then
		net.Start("AddAffectedPlayers")
		net.WriteTable(sendTbl)
		net.WriteFloat(duration)
		net.WriteColor(color)
		net.Send(maboy)
	end
end


--[[
				КУЛДАУНЫ
]]
function highlight.Cooldown(ply, duration)
	haloUsers[ply] = {hl_Time = CurTime() + duration}
		
	net.Start("fh_cooldown_receive")
	net.WriteString("highlight")
	net.WriteFloat(duration)
	net.Send(ply)
end

function highlight.GetCooldown(ply)
	if !IsValid(ply) then return end
	if !haloUsers[ply] or haloUsers[ply].hl_Time < CurTime() then return 0 end
	
	return haloUsers[ply].hl_Time - CurTime()
end


--[[
				ЗВУКИ ПРОСВЕТА
]]
local vision_sounds = {
	["default"] = {affected = "vision_affected.wav", unaffected = "vision_unaffected.wav"}
}
util.PrecacheSound( "vision_affected.wav" )
util.PrecacheSound( "vision_unaffected.wav" )

function highlight.AddVisionSounds(name, snd_affected, snd_unaffected)
	util.PrecacheSound( snd_affected )
	util.PrecacheSound( snd_unaffected )
	vision_sounds[name] = {affected = snd_affected, unaffected = snd_unaffected}
end

highlight.AddVisionSounds("pill_springtrap", "fnaf3/spr_vision_affected.wav", "fnaf3/spr_vision_unaffected.wav")
highlight.AddVisionSounds("pill_sfreddy2", "shadow_affected_vision.wav", "vision_unaffected.wav")

function highlight.GetVisionSound(ent)
	if IsValid(ent) then 
		local name = ent.formTable.name
		
		if vision_sounds[name] then
			return vision_sounds[name]
		end
	end
	return vision_sounds["default"]
end

function highlight.NotifyTarget(target, ent, isAffected)
	local sound_to_play = highlight.GetVisionSound(ent)
	if !conVars.fh_silent_highlight:GetBool() then
		net.Start("PlayHighlightSounds") -- всем остальным кидаем звук прикольный
		net.WriteBool( isAffected )
		net.WriteString( isAffected and sound_to_play.affected or sound_to_play.unaffected )
		net.Send(target)
	else
		net.Start("PlayHighlightSounds") -- если silent govno, то чуваки знают, но не знают
		net.WriteBool( false )
		net.WriteString( sound_to_play.unaffected )
		net.Send(target)
		
		target:ChatPrint("Просвет... Или нет?")
	end
end



--[[
				МАШКУ ЗА ЛЯЖКУ
]]
hook.Add("SetupPlayerVisibility", "fh_halo_visibility", function(ply, viewent)
	if ply:IsAnimatronic() and not table.IsEmpty(affectedPlayers) then
		for maboy, targets in pairs(affectedPlayers) do
			if IsValid(maboy) and maboy == ply then
				for target, _ in pairs(targets) do
					if IsValid(target) and viewent:IsValid() and not viewent:TestPVS(target) then
						AddOriginToPVS(target:GetPos())
					end
				end
				break
			end
		end
	end
end)

hook.Add("PlayerChangedTeam", "fh_halo_team", function(ply, oldteam, team)
	if team ~= 2701 and haloUsers[ply] then
		haloUsers[ply] = nil
	end

	for maboy, targets in pairs(affectedPlayers) do
		if targets[ply] then
			targets[ply] = nil

			if IsValid(maboy) then
				net.Start("RemoveAffectedPlayer")
				net.WriteEntity(ply)
				net.Send(maboy)
			end

			if table.IsEmpty(targets) then
				affectedPlayers[maboy] = nil
			end
		end
	end
end)

hook.Add("PlayerDeath", "fh_halo_death_check", function(victim, inflictor, attacker)
	for maboy, targets in pairs(affectedPlayers) do
		if targets[victim] then
			targets[victim] = nil

			if IsValid(maboy) then
				net.Start("RemoveAffectedPlayer")
				net.WriteEntity(victim)
				net.Send(maboy)
			end

			if table.IsEmpty(targets) then
				affectedPlayers[maboy] = nil
			end
		end
	end

	net.Start('fh_nodraw_hl_overlay')
	net.Send(victim)

	if IsValid(attacker) and attacker:IsPlayer() and attacker:IsAnimatronic() then
		highlight.Cooldown(attacker, highlight.GetCooldown(attacker) + 10)
	end
end)
	
hook.Add("PlayerDisconnected", "fh_halo_disconnect", function(ply)
	for maboy, targets in pairs(affectedPlayers) do
		if targets[ply] then
			targets[ply] = nil

			if IsValid(maboy) then
				net.Start("RemoveAffectedPlayer")
				net.WriteEntity(ply)
				net.Send(maboy)
			end

			if table.IsEmpty(targets) then
				affectedPlayers[maboy] = nil
			end
		end
	end
end)

concommand.Add("fh_show_halo_radius", function(ply, cmd, args)
	if IsValid(ply) and ply:IsSuperAdmin() then

		debugoverlay.Sphere( ply:GetPos(), conVars.halo_radius:GetInt(), 10, Color( 255, 0, 0, 120 ), true )
	end
end)

local function getMapHalfSize()
    local mins, maxs = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)

    for _, ent in ents.Iterator() do
		local modelname = ent:GetModel()
		if modelname and ( modelname:match("skybox") or modelname:match("cloud") or !modelname:match(".mdl") ) or !modelname then continue end
	
        local eMins, eMaxs = ent:WorldSpaceAABB()
        mins.x = math.min(mins.x, eMins.x)
        mins.y = math.min(mins.y, eMins.y)
        mins.z = math.min(mins.z, eMins.z)
        maxs.x = math.max(maxs.x, eMaxs.x)
        maxs.y = math.max(maxs.y, eMaxs.y)
        maxs.z = math.max(maxs.z, eMaxs.z)
    end

    local size = maxs - mins
    local half = size:Length() / 2

    return half
end

concommand.Add("fh_test_auto_halo_radius", function(ply, cmd, args)
	if IsValid(ply) and ply:IsSuperAdmin() then
	
		local halfDiagonal = getMapHalfSize()
		print("Auto Halo Radius: ", halfDiagonal / 2, conVars.halo_radius:GetInt())

		debugoverlay.Sphere( ply:GetPos(), conVars.halo_radius:GetInt(), 8, Color( 255, 0, 0, 120 ), true )
		
		debugoverlay.Sphere( ply:GetPos(), halfDiagonal / 2, 8, Color( 0, 125, 255, 120 ), true )
	end
end)