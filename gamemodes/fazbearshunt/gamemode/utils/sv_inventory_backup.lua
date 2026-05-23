inventory_backup = inventory_backup or {}

local blockedReviveWeapons = {
	["weapon_killer_axe"] = true,
	["weapon_taser"] = true,
}

function inventory_backup.SaveCurrentInventory(ply)
	ply.ReviveActiveWeapon = nil
	local activeWeapon = ply:GetActiveWeapon()
	if IsValid( activeWeapon ) and not activeWeapon.BackupBlocked then
		local class = activeWeapon:GetClass()
		if not blockedReviveWeapons[class] then
			ply.ReviveActiveWeapon = class
		end
	end
	
	local weapons = ply:GetWeapons()
	local count=0
	
	ply.ReviveWeapons = {}
	for _, v in ipairs( weapons ) do
		local class = v:GetClass()
		if blockedReviveWeapons[class] then continue end
		if v.BackupBlocked then continue end
		
		ply.ReviveWeapons[class] = true
		count=count+1
	end
	
	ply.RevivalPreviousAmmo = {}
	for _, v in ipairs( weapons ) do
		local primary = v:GetPrimaryAmmoType()
		local secondary = v:GetSecondaryAmmoType()
		
		local newPrimary = math.floor( ply:GetAmmoCount( primary ) * 0.5 )
		local newSecondary = math.floor( ply:GetAmmoCount( secondary ) * 0.5 )
		
		ply.RevivalPreviousAmmo[primary] = newPrimary
		ply.RevivalPreviousAmmo[secondary] = newSecondary
	end
	
	print("[FH] Saved inventory for " .. ply:Nick() .. ". He has " .. count .. " weapons")
end

function inventory_backup.RemoveItem(ply, item)
	if ply.ReviveWeapons ~= nil then
		if ply.ReviveWeapons[item] then
			ply.ReviveWeapons[item] = nil
		end
	end
end

function inventory_backup.LoadBackup(ply)
	print("[FH] Trying to load inventory for " .. ply:Nick())
	if ply.ReviveWeapons ~= nil then
		local count=0
		for wep, _ in pairs( ply.ReviveWeapons ) do
			ply:Give(wep)
			count=count+1
		end
		print("[FH] Loaded inventory for " .. ply:Nick() .. ". He has " .. count .. " weapons", ply:Alive())
	end
	
	if ply.ReviveActiveWeapon ~= nil then
		ply:SelectWeapon( ply.ReviveActiveWeapon )
	end
	
	if ply.RevivalPreviousAmmo ~= nil then
		for k, v in pairs( ply.RevivalPreviousAmmo ) do
			ply:GiveAmmo( v, k, true )
		end
	end
end