AddCSLuaFile()

fh.RegisterRoundType("bear5", 3, function()
	local players = player.GetAll()
		
	players = fh.GetEarnedKillers(players)
	
	if players then
		local chosenPlayer = players[1]
		
		GiveKiller(chosenPlayer, "bear5_main", true)
		
		chosenPlayer.lobbyFreeze = true
		chosenPlayer:ReturnToSpawn()
	end
	
	RandomTaser()
	
	freezeAnimatronics()
end, 10, 6, 32)

fh.AddRoundMusic(3, "music/bear_timer.wav")

if CLIENT then return end

hook.Add( "EntityTakeDamage", "fh_bear_kill", function( ply, dmginfo )
	if not ply:IsPlayer() then return end
	if not ply:IsSurvivor() then return end
	
	local attacker = dmginfo:GetAttacker()
	if IsValid(attacker) then
		if not attacker:IsPlayer() then return end
		if not attacker:IsAnimatronic() then return end
		
		local ent = attacker:GetPillCostume()
		
		if not IsValid(ent) then return end
		
		local pillName = ent:GetPillName()
		
		if fh.GetRoundType() == 3 and (pillName:find("bear5") or pillName:find("fox4")) then
			if ply:GetNW2Bool("KillerObsessed") then
				dmginfo:SetDamage( math.min(dmginfo:GetDamage(), math.random(5,6) ) )
			end
			
			local damageDealt = dmginfo:GetDamage()
			
			if damageDealt >= ply:Health() then
				inventory_backup.SaveCurrentInventory(ply)
				GiveKillerSilent(ply, "bear5_clone", true)
				
				ply:NoPlayerCollide(0.25)
				
				hook.Run("SendDeathNotice", attacker, attacker:GetActiveWeapon():GetClass(), ply, 0)
				
				if table.Count(survivors) == 1 then
					hook.Run("FH_LastManStanding")
				end
				
				WinConditions()
			end
		end
	end
end )

hook.Add( "DefibrillatorUse", "fh_bear5", function( wep, owner, ent )
	--if fh.GetRoundType() == 3 then
		if ent:IsPlayer() and IsValid(ent:GetPill()) and ent:GetPill():GetPillName() == "bear5_clone" then
			restoreAnimatronic(ent)
			ent:NoPlayerCollide(0.25)
			ent:SetHealth(100)
			
			local effect2 = EffectData()
			effect2:SetOrigin(ent:GetPos())
			effect2:SetStart(ent:GetPos())
			effect2:SetMagnitude(1)
			effect2:SetEntity(ent)
			util.Effect("teslaHitBoxes",effect2, true, true)
			
			ent:EmitSound("defibl/bearling_revive.mp3")
	
			if CLIENT then
				return
			end
			
			inventory_backup.LoadBackup(ent)
			
			local spark = ents.Create("env_spark")
			spark:SetPos(ent:GetPos())
			spark:SetKeyValue("spawnflags", "192")
			spark:SetKeyValue("traillength", "1")
			spark:SetKeyValue("magnitude", "2")
			spark:Spawn()
			spark:Fire("SparkOnce", "", 0.05)
			spark:Fire("kill", "", 0.1)
	
			owner:ViewPunch(Angle(-10, 0, 0))

			owner:EmitSound("defibl/charged.wav", 75, 100)
			wep:SetClip1(100)

			timer.Simple(0.5, function()
				if IsValid(wep) and IsValid(owner) then
					owner:StripWeapon(wep:GetClass())
				end
				
				if ent:IsValid() then
					if ent:IsStuck() then
						ent:SetPos(owner:GetPos())
					end
				end
			end)
		end
	--end
end)

hook.Add("FH_LastManStanding", "bear5", function()
	if fh.GetRoundType() == 3 then 
		local timecheck = 200
		local fh_bear5_killermask_last = conVars.fh_bear5_killermask_last
		
		if fh_bear5_killermask_last:GetBool() then
			local ply
			for p, _ in pairs(survivors) do
				ply = p
				break
			end
			if IsValid(ply) then
				if not ply:HasWeapon("weapon_killer_axe") then 
					ply:StripWeapons()
					ply:StripAmmo()
					
					ply:Give("weapon_killmask", true)
					ply:SelectWeapon("weapon_killmask")
			
					local wep = ply:GetActiveWeapon()
					
					if IsValid(wep) then
						ply:SetHealth(100)
						ply:Freeze(true)
						ply:GodEnable()
						ply:SetGFreddyImmune(true)
						if wep.PrimaryAttack then
							wep:PrimaryAttack(wep)
						end
					end
				end
				
				timecheck = 320
			end
		end
		if table.Count(animatronics) >= 2 and fh.timer.GetTimeLeft() >= timecheck then
			fh.timer.CutBack(timecheck-20, "round/time_cutback.mp3")
		end
	end
end)

hook.Add("fh_postendgame", "bear5_win_dance", function(victory, anims)
	if victory then
		local win_location, win_camera = FindSuitableVictoryPos(150, 200)
		local bear_ply = fh.GetActiveUsedKiller("bear5_main")
				
		if IsValid(win_location) and IsValid(win_camera) then
			
			if fh.GetRoundType() == 3 and bear_ply then
				
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
					
					timer.Simple(0, function()
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