
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

hook.Add( "EntityTakeDamage", "fh_bear_kill", function( ply, dmginfo )
	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) then
		if ply:IsPlayer() and ply:IsSurvivor() and fh.GetRoundType() == 3 and attacker:IsPlayer() and attacker:IsAnimatronic() then
			local damageDealt = dmginfo:GetDamage()
			
			if damageDealt >= ply:Health() then
				giveKillerSilent(ply, "bear5_clone", true)
				
				ply:NoPlayerCollide(0.25)
				
				hook.Run("SendDeathNotice", attacker, attacker:GetActiveWeapon():GetClass(), ply, 1)
				
				winConditions()
			end
		end
	end
end )