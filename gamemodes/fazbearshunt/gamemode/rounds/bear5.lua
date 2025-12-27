
fh.RegisterRoundType("bear5", 3, function()
	local players = player.GetAll()
		
	players = fh.GetEarnedKillers(players)
	
	if players then
		local chosenPlayer = players[1]
		
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
		if ply:IsPlayer() and ply:IsSurvivor() and fh.GetRoundType() == 3 and attacker:IsPlayer() and attacker:IsAnimatronic() and 
		(attacker:GetPill():GetPillName():match("bear5") == "bear5" or attacker:GetPill():GetPillName():match("fox4") == "fox4") then
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

hook.Add("fh_postendgame", "bear5_win_dance", function(victory, anims)
	if victory then
		local win_location, win_camera = FindSuitableVictoryPos(150, 200)
		local bear_ply = fh.GetActiveUsedKiller("bear5_main")
				
		if IsValid(win_location) and IsValid(win_camera) then
			
			if fh.GetRoundType() == 3 and bear_ply then
					
				hook.Add("SetupPlayerVisibility", "fh_pvs_wincamera", function(ply, viewent)
					if !IsValid(win_camera) then
						hook.Remove("SetupPlayerVisibility", "fh_pvs_wincamera")
						return
					end
					AddOriginToPVS(win_camera:GetPos())
				end)
				
				timer.Simple(0.5, function()
					for _, p in player.Iterator() do
						p:ScreenFade( SCREENFADE.OUT, Color( 0, 0, 0, 255 ), 0.5, 0 )
					end
				end)
				
				timer.Simple(1, function()
					local ent = pills.getMappedEnt(bear_ply)
					
					bear_ply:SetPos(win_location:GetPos() - win_location:GetForward() * 120)
					bear_ply:SetEyeAngles(win_location:GetAngles())
					bear_ply:SetRenderAngles(win_location:GetAngles())
					ent:SetUseForceAngles(true)
					ent:SetForceAngles(win_location:GetAngles())
					
					for _, p in player.Iterator() do
						p:SetViewEntity(win_camera)
						p:SetFOV(65, 2)
						
						p:ScreenFade( SCREENFADE.IN, Color( 0, 0, 0, 255 ), 1, 0 )
					end
					
					net.Start("fh_play_sound")
					net.WriteString("#music/pumpit.mp3")
					net.Broadcast()
					
					timer.Simple(0.01, function()
						ent:PillAnim("pumpit", true)
						bear_ply:Lock()
						ent.animLoop = true
						
						-- ну ещё раз на всякий
						bear_ply:SetEyeAngles(win_location:GetAngles())
						bear_ply:SetRenderAngles(win_location:GetAngles())
						ent:SetAngles(win_location:GetAngles())
					end)
				end)
			end
		end
	end
end)