killermask = killermask or {}

local ALLOW_KILLMASK_GIFT = true

function killermask.IsGiftingAllowed()
	return ALLOW_KILLMASK_GIFT
end

hook.Add("fh_startgame", "killermask_hook", function()
	ALLOW_KILLMASK_GIFT=true
end)
hook.Add("FH_KillerObsessed", "killermask_hook", function()
	ALLOW_KILLMASK_GIFT=false
end)

hook.Add( "CustomPlayerTakeDamageConditions", "fh_axe_shouldtakedamage", function( ply, attacker )
	if IsValid(attacker) and attacker:IsPlayer() and IsValid(attacker:GetActiveWeapon()) and attacker:GetActiveWeapon():GetClass() == "weapon_killer_axe" then
		return true
	end
	if  IsValid(attacker) and attacker:IsPlayer() and attacker:IsAnimatronic() and IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() == "weapon_killer_axe" then
		return true
	end
end)

hook.Add( "FH_PlayerShouldJumpscare", "fh_axe_owner_no_jumpscare", function( ply, ent, target )
	if ply:IsAnimatronic() and IsValid(target) and target:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

hook.Add( "fh_animatronic_post_break_prop", "fh_anims_fight_axe_owner", function( ply, ent, tr )
	local target = tr.Entity
	
	if target:IsPlayer() and target:GetNW2Bool("KillerObsessed") then
		local wep = ply:GetActiveWeapon()

		ply:EmitSound("bonnie_punch.mp3")
		
		local dmginfo = DamageInfo()
		dmginfo:SetAttacker( ply )
		dmginfo:SetInflictor( IsValid(wep) and wep or ply )
		dmginfo:SetDamage( math.random(5,6) )

		SuppressHostEvents( NULL )
		target:TakeDamageInfo( dmginfo )
		SuppressHostEvents( ply )
		if IsValid(wep) then
			wep:HandleAnimation("attack", -1, true)
		end
		
		ent:PillGesture('melee', 2, 1, 0.1, 0.7)
		
        local edata = EffectData()
        edata:SetOrigin(tr.HitPos)
        edata:SetEntity(target)
        util.Effect("BloodImpact", edata, true, true)
		
		ply._breakPropAsAnimTime = CurTime() + 0.8
	end
end)

hook.Add( "SetupPlayerVisibility", "fh_axe_visibility", function( ply, viewent )
	for _, sex in player.Iterator() do
		if sex ~= ply and (sex:GetNW2Bool("KillerObsessed") or ply:GetNW2Bool("KillerObsessed")) then
			if viewent:IsValid() and not viewent:TestPVS(sex) then
				AddOriginToPVS(sex:GetPos())
			end
		end
	end
end)

hook.Add( "PlayerSpawn", "fh_axe_anim_spawn", function( ply )
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(1)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
	
	if ply:HasWeapon("weapon_killer_axe") then
		ply:StripWeapon("weapon_killer_axe")
	end
end)

hook.Add("PillApply", "fh_axe_joinpill", function(ply, name)
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(1)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
end)

hook.Add("FH_HandleGiftPickup", "fh_axe_giftpickup", function(gift, ply)
	if ply:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

hook.Add("FH_ShouldPlayerReceiveGifts", "fh_axe_giftpickup", function(ply)
	if ply:GetNW2Bool("KillerObsessed") then
		return false
	end
end)

local animKillHealth = 40
local survKillHealth = 12
hook.Add( "PlayerDeath", "fh_axe_anim_death", function( ply, inflictor, attacker )
	if ply:GetNW2Bool("KillerObsessed") then
		ply:SetNW2Bool("KillerObsessed", false)
		ply:SetDSP(1)
	end
	if ply:GetNW2Bool("KillerMaskEquiped") then
		ply:SetNW2Bool("KillerMaskEquiped", false)
	end
	
	if IsValid(attacker) and attacker:IsPlayer() and IsValid(inflictor) and inflictor:GetClass() == "weapon_killer_axe" then
		if ply:IsAnimatronic() then
			local effectdata = EffectData()
			effectdata:SetOrigin(ply:GetPos())
			effectdata:SetScale(1)
			util.Effect("Explosion", effectdata, true, true)
			
			for i = 1, (ply:GetMaxHealth() / 10000) * animKillHealth do
				timer.Simple(0 + i/25, function()
					if IsValid(attacker) and attacker:Health() < 100 then
						attacker:SetHealth(attacker:Health() + 1)
					end
				end) 
			end
		else
			for i = 1, survKillHealth do
				timer.Simple(0 + i/8, function()
					if IsValid(attacker) and attacker:Health() < 100 then
						attacker:SetHealth(attacker:Health() + 1)
					end
				end) 
			end
		end
		hook.Run("KillerAxeKilled", attacker, ply)
	end
end)

hook.Add( "EntityTakeDamage", "fh_killmask_damage", function( target, dmginfo )
	if target:IsPlayer() and target:GetNW2Bool("KillerObsessed") then
		dmginfo:SetDamage( math.min(dmginfo:GetDamage(), math.random(5,6) ) )
	end
	if target:IsPlayer() and target:IsSurvivor() and IsValid(dmginfo:GetAttacker()) and dmginfo:GetAttacker():GetNW2Bool("KillerObsessed") then
		dmginfo:SetDamage( math.min(dmginfo:GetDamage(), 30) )
	end
end)

concommand.Add( "dev_force_killermask", function( ply, cmd, args )
	if CLIENT or not ply:IsSuperAdmin() then return end

	local nick1 = tostring(args[1])
	
	local killer = nil
	
	for _, ply in player.Iterator() do
		local nickname = ply:Nick():lower()
	
		if !IsValid(killer) and nickname:match( nick1:lower() ) and ply:Alive() and ply:IsSurvivor() then
			killer = ply
			break
		end
	end
	
	if not killer then killer = ply end
	
	if IsValid(killer) and killer:Alive() then
		killer:Give("weapon_killmask", true)
		killer:SelectWeapon("weapon_killmask")
		
		local wep = killer:GetActiveWeapon()
		
		if IsValid(wep) then
			if wep.PrimaryAttack then
				wep:PrimaryAttack(wep)
			end
		end
		return
	end
	
	print("dev_force_killermask - has failed! Maybe the nicknames were wrong.")
end)