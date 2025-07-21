
util.AddNetworkString("PlayHighlightSounds")
util.AddNetworkString("AddAffectedPlayers")
util.AddNetworkString("RemoveAffectedPlayer")
util.AddNetworkString("ToggleHighlightSound")
util.AddNetworkString("NotifySpectators")
	
affectedPlayers = {}
local haloUsers = {}

hook.Add( "PostCleanupMap", "fh_halo_reset", function( name )
	table.Empty(haloUsers)
end)

function HighlightPlayers(ply, ent)
	local totalPlayers = {}
	if !table.HasValue(haloUsers, ply) then -- чел не под кулдауном? разрешай
		table.insert(haloUsers, ply)
		
		net.Start("fh_net_killer_change")
		net.WriteString("highlight")
		net.WriteFloat(conVars.halo_cooldown:GetFloat())
		net.Send(ply)
		
		timer.Simple(conVars.halo_cooldown:GetFloat(), function()
			table.RemoveByValue(haloUsers, ply)
		end)
		
		local outworlded = getOutworldVictims()
	
		local affectedNicknames = {}
		for _, player in player.Iterator() do
			if player ~= ply and player:IsPlayer() 
							and player:Health() > 0 
							and (player:Team() != TEAM_SPECTATOR
							and player:Team() != 2701) 
							and player:IsValid()
							and !outworlded[player] then
				local distance = ply:GetPos():Distance(player:GetPos())
				
				local isAffected = distance <= conVars.halo_radius:GetInt()
				
				if !conVars.fh_silent_highlight:GetBool() then
					net.Start("PlayHighlightSounds") -- всем остальным кидаем звук прикольный
					net.WriteBool(isAffected)
					net.WriteBool(ent.formTable.name == "pill_springtrap")
					net.Send(player)
				else
					net.Start("PlayHighlightSounds") -- если silent govno, то чуваки знают, но не знают
					net.WriteBool(false)
					net.WriteBool(ent.formTable.name == "pill_springtrap")
					net.Send(player)
					
					player:ChatPrint("Просвет... Или нет?")
				end
				
				if (isAffected) then -- передаём чуваку кто подсвечивается в радиусе
					table.insert(affectedPlayers, player)
					table.insert(totalPlayers, player)
					table.insert(affectedNicknames, player:Nick())
					timer.Simple(conVars.halo_time:GetFloat(), function()
						table.RemoveByValue(affectedPlayers, player)
					end)
					
					stats.Add(player, "got_highlighted", 1)
				else
					stats.Add(player, "evaded_highlight", 1)
				end
			end
		end
				
		if !table.IsEmpty(totalPlayers) then
			net.Start("AddAffectedPlayers")
			net.WriteTable(totalPlayers)
			net.Send(ply)
			if !table.IsEmpty(team.GetPlayers(TEAM_SPECTATOR)) then
				net.Start('NotifySpectators')
				net.WriteTable(affectedNicknames)
				net.WriteEntity(ply)
				net.Broadcast()
			end
		end
					
		net.Start("ToggleHighlightSound") -- включаем чуваку звук что он дофига крутой со спермой под губой
		net.WriteBool(!table.IsEmpty(totalPlayers))
		net.Send(ply)
	end
end

hook.Add("SetupPlayerVisibility", "fh_halo_visibility", function(ply, viewent)
	if !table.IsEmpty(affectedPlayers) then
		for _, player in ipairs(affectedPlayers) do
			if IsValid(player) then
				AddOriginToPVS(player:GetPos())
			end
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
end)
	
hook.Add( "PlayerDisconnected", "fh_pill_fnaf2_disconnect", function( ply )
	if table.HasValue(affectedPlayers, ply) then
		table.RemoveByValue(affectedPlayers, ply)
		
		net.Start("RemoveAffectedPlayer")
		net.WriteEntity(ply)
		net.Broadcast()
	end
end)