highlight = highlight or {}

util.AddNetworkString("PlayHighlightSounds")
util.AddNetworkString("AddAffectedPlayers")
util.AddNetworkString("RemoveAffectedPlayer")
util.AddNetworkString("ToggleHighlightSound")
util.AddNetworkString("NotifySpectators")
	
affectedPlayers = {}
local haloUsers = {}

hook.Add( "PostCleanupMap", "fh_halo_reset", function( name )
	table.Empty(haloUsers)
	table.Empty(affectedPlayers)
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
							and hook.Run("FH_ShouldHighlightPlayer", player, ply, ent) == false then
				local distance = ply:GetPos():Distance(player:GetPos())
				
				local isAffected = distance <= conVars.halo_radius:GetInt()
				
				if (isAffected) then -- передаём чуваку кто подсвечивается в радиусе
					table.insert(totalPlayers, player)
					table.insert(affectedNicknames, player:Nick())
				
					highlight.Add(ply, player)
					
					stats.Add(player, "got_highlighted", 1)
				else
					stats.Add(player, "evaded_highlight", 1)
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
	end
end

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

function highlight.Add(ply, players, duration)
    assert(ply, "Can't highlight players for someone who is NOT VALID!")
    assert(players, "Can't highlight players if they are NOT VALID!")

	local duration = duration or conVars.halo_time:GetFloat() or 5
	if istable(players) then
		if !table.IsEmpty(players) then
			net.Start("AddAffectedPlayers")
			net.WriteTable(players)
			net.WriteFloat(duration)
			net.Send(ply)
			
			for _, v in ipairs(players) do
				if !table.HasValue(affectedPlayers, v) then
					table.insert(affectedPlayers, v)
				end
				
				timer.Simple(duration, function()
					table.RemoveByValue(affectedPlayers, v)
				end)
			end
		end
	else
		if players:IsValid() then
			net.Start("AddAffectedPlayers")
			net.WriteTable( {players} )
			net.WriteFloat(duration)
			net.Send(ply)
			
			if !table.HasValue(affectedPlayers, v) then
				table.insert(affectedPlayers, players)
			end
			
			timer.Simple(duration, function()
				table.RemoveByValue(affectedPlayers, players)
			end)
		end
	end
end


--[[
				КУЛДАУНЫ
]]
function highlight.Cooldown(ply, duration)
	haloUsers[ply] = {hl_Time = CurTime() + duration}
		
	net.Start("fh_net_killer_change")
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
	if !table.IsEmpty(affectedPlayers) then
		for _, player in ipairs(affectedPlayers) do
			if IsValid(player) and player ~= ply and ply:IsAnimatronic() then
				AddOriginToPVS(player:GetPos())
			end
		end
	end
end)

hook.Add("PlayerChangedTeam", "fh_halo_team", function(ply, oldteam, team)
	if team != 2701 then
		if haloUsers[ply] then
			haloUsers[ply] = nil
		end
	end
	
	if table.HasValue(affectedPlayers, ply) then
		if team == 2701 then
			table.RemoveByValue(affectedPlayers, ply)
			net.Start("RemoveAffectedPlayer")
			net.WriteEntity(ply)
			net.Broadcast()
		end
	end
end)

hook.Add( "PlayerDeath", "fh_halo_death_check", function( victim, inflictor, attacker )
	if table.HasValue(affectedPlayers, victim) then
		table.RemoveByValue(affectedPlayers, victim)
		
		net.Start("RemoveAffectedPlayer")
		net.WriteEntity(victim)
		net.Broadcast()
		
		net.Start('fh_nodraw_hl_overlay')
		net.Send(victim)
	end
	
	if attacker:IsPlayer() and attacker:IsAnimatronic() then
		highlight.Cooldown(attacker, highlight.GetCooldown(attacker) + 10)
	end
end)
	
hook.Add( "PlayerDisconnected", "fh_pill_fnaf2_disconnect", function( ply )
	if table.HasValue(affectedPlayers, ply) then
		table.RemoveByValue(affectedPlayers, ply)
		
		net.Start("RemoveAffectedPlayer")
		net.WriteEntity(ply)
		net.Broadcast()
	end
end)