inventory_backup = inventory_backup or {}

local blockedReviveWeapons = {
	["weapon_killer_axe"] = true,
	["weapon_taser"] = true,
}

function inventory_backup.SaveCurrentInventory(ply)
	if IsValid( ply:GetActiveWeapon() ) then
		ply.ReviveActiveWeapon = ply:GetActiveWeapon():GetClass()
	end
	
	local weapons = ply:GetWeapons()
	
	ply.ReviveWeapons = {}
	for _, v in ipairs( weapons ) do
		local class = v:GetClass()
		if blockedReviveWeapons[class] then continue end
		
		ply.ReviveWeapons[v:GetClass()] = true
	end
	
	ply.RevivalPreviousAmmo = {}
	for _, v in pairs( weapons ) do
		local primary = v:GetPrimaryAmmoType()
		local secondary = v:GetSecondaryAmmoType()
		
		local newPrimary = math.floor( ply:GetAmmoCount( primary ) * 0.5 )
		local newSecondary = math.floor( ply:GetAmmoCount( secondary ) * 0.5 )
		
		ply.RevivalPreviousAmmo[primary] = newPrimary
		ply.RevivalPreviousAmmo[secondary] = newSecondary
	end
end

function inventory_backup.RemoveItem(ply, item)
	if ply.ReviveWeapons ~= nil then
		if ply.ReviveWeapons[item] then
			ply.ReviveWeapons[item] = nil
		end
	end
end

function inventory_backup.LoadBackup(ply)
	if ply.ReviveWeapons ~= nil then
		for wep, _ in pairs( ply.ReviveWeapons ) do
			ply:Give(wep)
		end
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