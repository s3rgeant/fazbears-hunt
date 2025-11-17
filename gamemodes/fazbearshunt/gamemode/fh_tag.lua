local tagDuration = 240
local tagSetup = 24

fh.RegisterRoundType("bonnie_tag", 2, function()
	local players = player.GetAll()
	table.Shuffle(players)

	local halfCount = math.floor(#players / 2)

	for i = 1, halfCount do
		local ply = players[i]
		if IsValid(ply) then
			giveKiller(ply, "pill_wbonnie2", true)
			ply:Spawn()
		end
	end
		
	for _, ply in player.Iterator() do
		ply:SetJumpBoostMultiplier( 0 )
	end
	
	freezeAnimatronics(tagSetup)
	
	net.Start("fh_start_game_timer") -- Включаем встроенный в режим таймер
	net.WriteFloat(tagDuration)
	net.WriteFloat(tagSetup)
	net.WriteString("ambient/alarms/warningbell1.wav")
	net.WriteString(tostring(fh.GetRoundCount()))
	net.Broadcast()
	
	timer.Create("EndGameTimer", tagDuration + tagSetup, 1, function()
		fh_tag_end()
	end)
end, 10, 8, 20)

fh.SetRoundTypeBlocked(2, true)

hook.Add("fh_startgame", "tag_prevent_default_startgame", function(roundType)
	if roundType == 2 then
		return false
	end
end)

hook.Add( "PlayerShouldTakeDamage", "fh_tagkill", function( ply, attacker )
	if ply:IsSurvivor() and fh.GetRoundType() == 2 and !attacker:IsPlayer() then
		return false 
	end
	
	if ply:IsSurvivor() and fh.GetRoundType() == 2 and attacker:IsPlayer() and attacker:IsAnimatronic() then
		attacker:SetHealth(100)
		
		for k,v in pairs( ents.FindInSphere( attacker:GetPos(), 350 ) ) do
			if v:IsPlayer() and v ~= attacker and v ~= ply then
				TaseAnimatronic(v)
			end
		end
		
		giveKiller(ply, "pill_wbonnie2", true)
		restoreAnimatronic(attacker)
		attacker:SetTeam(TEAM_SURVIVOR)
		
		ply.tagged = true
		timer.Simple(0.1, function()
			attacker:SetRunSpeed(550)
			attacker:SetCrouchedWalkSpeed(0.8)
		end)
		timer.Simple(2, function()
			if IsValid(ply) then
				ply.tagged = false
				attacker:SetRunSpeed(420)
				attacker:SetCrouchedWalkSpeed(0.3)
			end
		end)
		return false 
	end
	
	if fh.GetRoundType() == 2 and ply:IsAnimatronic() and attacker:IsPlayer()  then
		return false
	end
end )

hook.Add("fh_should_animatronic_respawn", "fh_tag_dont_respawn_anims", function(target)
	if fh.GetRoundType() == 2 then
		return false
	end
end)

hook.Add("CanPlayerSuicide", "fh_tag_dont_suicide", function(ply)
	if fh.GetRoundType() == 2 then
		return false
	end
end)

hook.Add("SetupMove", "fh_tag_lock", function(ply, mv, cmd)
	if ply.tagged then
		mv:SetVelocity(vector_origin)
		mv:SetOrigin(ply:GetPos())
	end
end)

hook.Add("PlayerPostThink", "fh_zero_physics", function(ply)
	if ply.tagged then
		ply:SetVelocity(-ply:GetVelocity())
	end
end)

hook.Add("FinishMove", "fh_tag_cantmove", function(ply)
	if ply.tagged then
		return true
	end
end)

hook.Add( "StartCommand", "fh_tag_cantattack", function( ply, cmd )
	if ply.tagged then
		cmd:RemoveKey(IN_ATTACK)
	end
end)

local tag_end = false
function fh_tag_end()

	net.Start("ResetTimer")
    net.Broadcast()
	
	isGameOn = false
	tag_end = true
	
	for ply,_ in pairs( animatronics ) do
		ply:TakeDamage(ply:Health() + ply:Armor())
		ply:SetTeam(TEAM_SPECTATOR)
	end
	
	local plys = {}
	for ply, _ in pairs(survivors) do
		table.insert(plys, ply:Nick())
	end
	
	net.Start("SurvivorsWin")
	net.WriteTable(plys)
	net.Broadcast()
	
	timer.Simple(5, function()
		local players = table.Copy(survivors)
		local count = table.Count(players) / 2
		
		if table.Count(players) >= 8 then
			isGameOn = true
			tag_end = false
			roundActive = false
			
			for k,_ in pairs( survivors ) do
				giveKiller(k, "pill_wbonnie2", true)
				k:ReturnToSpawn()
				count = count - 1
				if count == 0 then break end
			end
			
			for k,_ in pairs(survivors) do
				k:Spawn()
			end
			
			freezeAnimatronics(tagSetup)
	
			net.Start("fh_start_game_timer") -- Включаем встроенный в режим таймер
			net.WriteFloat(tagDuration)
			net.WriteFloat(tagSetup)
			net.WriteString("ambient/alarms/warningbell1.wav")
			net.WriteString(tostring(fh.GetRoundCount()))
			net.Broadcast()
		
			timer.Create("EndGameTimer", tagDuration + tagSetup, 1, function()
				fh_tag_end()
			end)
			
		else 
			tag_end = false
		
			endGame()
		end
	end)
end

hook.Add('PlayerDeathThink', 'fh_tag_block_respawn', function(ply)
	if tag_end then
		return false
	end
end)

hook.Add("fh_prespawngifts", "fh_tag_gifts", function()
	if fh.GetRoundType() == 2 then
		return false
	end
end)

--fh.AddRoundMusic(2, "music/tag_music.wav")