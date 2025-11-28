
fh.RegisterRoundType("bear5", 3, function()
	local players = player.GetAll()
		
	players = fh.GetEarnedKillers(players)
	
	if players then
		local chosenPlayer = fh.randomChoice(players)
		
		giveKiller(chosenPlayer, "bear5_main", true)
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:ReturnToSpawn()
	end
	
	RandomTaser()
	
	freezeAnimatronics()
end, 20, 6, 24)

fh.AddRoundMusic(3, "music/bear_timer.wav")

hook.Add( "PlayerShouldTakeDamage", "fh_bear_kill", function( ply, attacker )
	print(fh.GetRoundType(), attacker:IsPlayer(), attacker:IsAnimatronic())
	if fh.GetRoundType() == 3 and attacker:IsPlayer() and attacker:IsAnimatronic() then
		
		giveKiller(ply, "bear5_clone", true)

		return false 
	end
end )