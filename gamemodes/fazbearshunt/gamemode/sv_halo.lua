
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
	
		local affectedNicknames = {}
		for _, player in ipairs(player:GetAll()) do
			if player ~= ply and player:IsPlayer() and player:Health() > 0 and (player:Team() != TEAM_SPECTATOR and player:Team() != 2701) and player:IsValid() then
				local distance = ply:GetPos():Distance(player:GetPos())
				
				if !conVars.fh_silent_highlight:GetBool() then
					net.Start("PlayHighlightSounds") -- всем остальным кидаем звук прикольный
					net.WriteBool(distance <= conVars.halo_radius:GetInt())
					net.WriteBool(ent.formTable.name == "pill_springtrap")
					net.Send(player)
				else
					net.Start("PlayHighlightSounds") -- если silent govno, то чуваки знают, но не знают
					net.WriteBool(false)
					net.WriteBool(ent.formTable.name == "pill_springtrap")
					net.Send(player)
					
					player:ChatPrint("Просвет... Или нет?")
				end
				
				if (distance <= conVars.halo_radius:GetInt()) then -- передаём чуваку кто подсвечивается в радиусе
					table.insert(affectedPlayers, player)
					table.insert(totalPlayers, player)
					table.insert(affectedNicknames, player:Nick())
					timer.Simple(conVars.halo_time:GetFloat(), function()
						table.RemoveByValue(affectedPlayers, player)
					end)
				end
			end
		end
				
		if table.Count(totalPlayers) > 0 then
			net.Start("AddAffectedPlayers")
			net.WriteTable(totalPlayers)
			net.Send(ply)
			if table.Count(team.GetPlayers(TEAM_SPECTATOR)) > 0 then
				net.Start('NotifySpectators')
				net.WriteTable(affectedNicknames)
				net.WriteEntity(ply)
				net.Broadcast()
			end
		end
					
		net.Start("ToggleHighlightSound") -- включаем чуваку звук что он дофига крутой со спермой под губой
		net.WriteBool(table.Count(totalPlayers) > 0)
		net.Send(ply)
	end
end

hook.Add("SetupPlayerVisibility", "fh_halo_visibility", function(ply, viewent)
	if table.Count(affectedPlayers) > 0 then
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

net.Receive("AddServerAffectedPlayers", function(len, ply)
	local players = net.ReadTable()
	for _, player in ipairs(players) do
		table.insert(affectedNicknames, player)
	end
end)