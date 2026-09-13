local health_bar = Material("vgui/base/health_bar.png")

local weapon_bar = Material("vgui/base/weapon_bar.png")
local big_weapon_bar = Material("vgui/base/big_weapon_bar.png")
local wep_slot = Material("vgui/base/wep_slot.png")

local wep_info_bar = Material("vgui/base/wep_info_bar.png")

surface.CreateFont("FHHealth", 
	{ font = "Share Tech Mono", size = 40, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("FHHealthL", 
	{ font = "Share Tech Mono", size = 12, extended = true, weight = 400, antialias = true, bold = true })

surface.CreateFont("FHArmor", 
	{ font = "Share Tech Mono", size = 24, extended = true, weight = 400, antialias = true, bold = true })

surface.CreateFont("FHWeaponSlot", 
	{ font = "Share Tech Mono", size = ScreenScale(6), extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("FHWeaponLegacy", 
	{ font = "HalfLife2", size = 64, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("FHWeaponLegacyBig", 
	{ font = "HalfLife2", size = 96, extended = true, weight = 400, antialias = true, bold = true })

surface.CreateFont("FHCurrentWeapon", 
	{ font = "Share Tech Mono", size = 16, extended = true, weight = 400, antialias = true, bold = true })

local hide = {
	["CHudHealth"] = true,
	["CHudBattery"] = true
}

-- КОСТЫЛЬ БЛЯЯЯ
local WeaponIcons = {
	[ "weapon_pistol" ]     = "d",
	[ "weapon_357" ]        = "e",
	[ "weapon_smg1" ]       = "a",
	[ "weapon_shotgun" ]    = "b",
	[ "weapon_ar2" ]        = "f",
	[ "weapon_rpg" ]        = "i",
	[ "weapon_bugbait" ]    = "j",
	[ "weapon_frag" ]    	= "k",
	[ "weapon_alyxgun" ]    = "d",
	[ "weapon_annabelle" ]  = "b",
	[ "weapon_crossbow" ]   = "g",
	[ "weapon_stunstick" ]  = "n",
	[ "weapon_crowbar" ]    = "c",
	[ "weapon_slam" ]    	= "o",
	
	[ "weapon_physcannon" ]    	= "m",
	[ "weapon_physgun" ]    	= "h",
}

hook.Add( "HUDShouldDraw", "HideHUD", function( name )
	if hide[ name ] then
		return false
	end
end)

local color_gray = Color(137,137,137)
local color_yellow_wpn = Color(255,230,54)

local color_surv = team.GetColor( TEAM_SURVIVOR )
local surv_r = color_surv.r
local surv_g = color_surv.g
local surv_b = color_surv.b

local healthColor = Color(255,255,255)

local myself
local HData = {}
local function FLerpC(clr, p, t)
	clr[p] = Lerp(t, clr[p], 255)
end

local selectingTil = false
local curSelected = 0

local bw_w = 135
local bw_h = 85
local w_w = 84
local w_h = 54

local drawhud = GetConVar("cl_drawhud")

hook.Add( "PostDrawHUD", "fh_basehud", function()

	if not drawhud:GetBool() then return end
	
	if hook.Run("FH_PreDrawHud") == true then return end
	
	if render.GetRenderTarget() ~= nil then return end

	local selecting = false
	
	local sw = ScrW()
	local sh = ScrH()
	
	local frametime = FrameTime()
	
	local myself = myself or LocalPlayer()
		
	local curWep = myself:GetActiveWeapon()
	local selectedWep
	
	local usedSlots = {}

	cam.Start2D()
	
		local w = 200
		local h = 72
		
		local x = 32
		local y = sh-h-14
		
		local frac = FrameTime() * 2
	
		surface.SetMaterial( health_bar )
		surface.SetDrawColor( surv_r, surv_g, surv_b, 255 )
		surface.DrawTexturedRect( x, y, w, h )
		
		local hp = myself:Health()
		local armor = myself:Armor()
		
		draw.SimpleText( "/", "FHArmor", x+105, y+37, color_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		
		if HData.health and HData.health > hp then
			healthColor.g = 20
			healthColor.b = 20
		end
		
		if healthColor.g ~= 255 then FLerpC(healthColor, "g", frac) end
		if healthColor.b ~= 255 then FLerpC(healthColor, "b", frac) end

		draw.SimpleText( hp, "FHHealth", x+54, y+32, healthColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		draw.SimpleText( "Здоровье", "FHHealthL", x+54, y+58, color_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		
		draw.SimpleText( armor, "FHArmor", x+146, y+32, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		draw.SimpleText( "Броня", "FHHealthL", x+146, y+58, color_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			
		HData.health = hp
		HData.armor = armor
		
		local weapons = myself:GetWeapons()
		local i = 0
		local h_i = 0 -- i for hidden items
		local r_i = 1 -- count for ALL items
		
		table.sort(weapons, function(a, b)
			local slotA = a:GetSlot() or 0
			local slotB = b:GetSlot() or 0

			if slotA ~= slotB then
				return slotA < slotB
			end

			local posA = a:GetSlotPos() or 0
			local posB = b:GetSlotPos() or 0

			return posA < posB
		end)
            
		selecting = false
		if selectingTil then
			selecting = CurTime() < selectingTil
		end
		
		local runningX = 0 
		
        for _, wep in ipairs(weapons) do
        
            local Wx = x + 228
            local Wy = y + 18
            
            local slot = wep:GetSlot() + 1
            local ci = i
            
            if selecting then
                ci = ci - curSelected + 1
			else
				curSelected = 0
            end
            
            local IsSelected = (selecting and ci == 0) or (!selecting and wep == curWep)
            
			local mat = weapon_bar
            local w = 82
            local h = 54
			local speed = selecting and 10 or 7
            
            if IsSelected then
                w = bw_w
                h = bw_h
                Wy = y - 13
				mat = big_weapon_bar
				
				selectedWep = wep
            end
        
            local hidden = false
            if not selecting then
				if not IsSelected then
					if not wep:IsScripted() or not wep.Gifted and not wep.HudAlwaysDisplay then hidden = true end
				end
            end
            
            local addY = 0
            
            if hidden then 
                addY = addY + 100 
                ci = r_i
            end
            
            local targetAlpha = 255
            if ci < 0 then
                targetAlpha = 0
            end
            
            local targetX = 0
            if ci < 0 then
                targetX = ci * (82 + 14)
            elseif not hidden then
                targetX = runningX
                runningX = runningX + w + 14 
            end
            
            local addX = targetX
            
            if not HData[r_i .. "_lastX"] then HData[r_i .. "_lastX"] = addX end
            local curAddX = Lerp(frac*speed, HData[r_i .. "_lastX"], addX)
			
            HData[r_i .. "_lastX"] = curAddX
			
			if hidden then curAddX = addX end
			
			surface.SetMaterial( mat )
			surface.SetDrawColor( surv_r, surv_g, surv_b, targetAlpha )
			surface.DrawTexturedRect( Wx + curAddX, Wy+addY, w, h )
			
			local isMaterial = not wep.WepSelectIcon
			
			local class = wep:GetClass()
			
			if wep.WepSelectIcon then -- SCRIPTED WEAPONS 
			
				local i_addX = (w + 14) * ci
				local i_w = w * 1.35
			
				render.SetScissorRect(
					Wx + curAddX,
					Wy,
					Wx + curAddX + w,
					Wy + h,
					true
				)
				
				surface.SetTexture( wep.WepSelectIcon )
				surface.SetDrawColor( 255, 255, 255, targetAlpha )
				surface.DrawTexturedRect( (Wx+curAddX) - i_w*.5 + w*.5, Wy + addY, w*1.35, h )
				
				render.SetScissorRect( 0, 0, 0, 0, false )
				
			elseif WeaponIcons[class] then -- HALF LIFE 2 ENGINE WEAPONS
			
				local i_addX = (w + 14) * ci
				local i_w = w * 1.35
			
				render.SetScissorRect(
					Wx + curAddX,
					Wy,
					Wx + curAddX + w,
					Wy + h,
					true
				)
				
				if targetAlpha > 0 then
					draw.SimpleText( WeaponIcons[class], IsSelected and "FHWeaponLegacyBig" or "FHWeaponLegacy", Wx+curAddX + w*.5, Wy+addY + h*.5, color_yellow_wpn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
				
				render.SetScissorRect( 0, 0, 0, 0, false )
			
			end
			
			if IsSelected and wep.Instructions then
				--draw.SimpleText( wep.Instructions, "FHArmor", Wx+curAddX, Wy+addY + h*.5, color_yellow_wpn, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
			end
			
			if not hidden and not usedSlots[slot] then
				local w = ScreenScale(8)
				local h=w
				local hw = w*.5
				
				surface.SetMaterial( wep_slot )
				surface.SetDrawColor( 255, 255, 255, targetAlpha )
				surface.DrawTexturedRect( Wx+curAddX - hw, Wy+addY - hw, w, w )
				
				if targetAlpha > 0 then
					draw.SimpleText( slot, "FHWeaponSlot", Wx+curAddX, Wy+addY, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
			end
			
			if not hidden then
				usedSlots[slot] = true
			end
			
			if hidden then
				h_i=h_i+1
			else
				i=i+1
			end
			
			r_i=r_i+1
		end
		
		local w = 200
		local h = 34
		
		if selecting and IsValid(selectedWep) or not selecting and IsValid(curWep) then
			local wep = selecting and selectedWep or curWep
			surface.SetMaterial( wep_info_bar )
			surface.SetDrawColor( surv_r, surv_g, surv_b, targetAlpha )
			surface.DrawTexturedRect( x, y - h - 6, w, h )
			
			draw.SimpleText( wep:GetPrintName(), "FHCurrentWeapon", x + w*.5, y - h*.5 - 6, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		
	cam.End2D()
	
end )

local zero_vec = Vector(0,0,0)
local scrollKeys = {
	--[KEY_0] = true,
	[KEY_1] = true,
	[KEY_2] = true,
	[KEY_3] = true,
	[KEY_4] = true,
	[KEY_5] = true,
	[KEY_6] = true,
	[KEY_7] = true,
	[KEY_8] = true,
	[KEY_9] = true,
}

local function GetSortedWeapons(ply)
    local weapons = ply:GetWeapons()
    table.sort(weapons, function(a, b)
        local slotA = a:GetSlot() or 0
        local slotB = b:GetSlot() or 0
        if slotA ~= slotB then
            return slotA < slotB
        end
        return (a:GetSlotPos() or 0) < (b:GetSlotPos() or 0)
    end)
    return weapons
end
hook.Add( "PlayerButtonDown", "fh_items_scroll", function( ply, button )
    if IsFirstTimePredicted() then
        if scrollKeys[button] then
			if hook.Run("HandleInventoryScrolling", ply, button) == false then return end
            local num = tonumber(input.GetKeyName( button ))
            local targetSlot = num - 1
            
            selectingTil = CurTime() + 6
        
            local weapons = ply:GetWeapons()
            
            table.sort(weapons, function(a, b)
                local slotA = a:GetSlot() or 0
                local slotB = b:GetSlot() or 0
                if slotA ~= slotB then return slotA < slotB end
                return (a:GetSlotPos() or 0) < (b:GetSlotPos() or 0)
            end)
            
            local slotWeapons = {}
            for i, wep in ipairs(weapons) do
                if wep:GetSlot() == targetSlot then
                    table.insert(slotWeapons, i)
                end
            end
            
            if #slotWeapons > 0 then
                local nextIndex = 1
                
                for idx, globalWepIndex in ipairs(slotWeapons) do
                    if curSelected == globalWepIndex then
                        nextIndex = idx + 1
                        break
                    end
                end
                
                if nextIndex > #slotWeapons then nextIndex = 1 end
                
                curSelected = slotWeapons[nextIndex]	
            end

			if GetConVar("hud_fastswitch"):GetBool() then
				local weapons = GetSortedWeapons(ply)
				local selectedWep = weapons[curSelected]
			
				if IsValid(selectedWep) then
					input.SelectWeapon(selectedWep)
					selectingTil = CurTime() + .5
					EmitSound("Player.WeaponSelectionClose", zero_vec)
			
					return
				end
			end
			
			EmitSound("Player.WeaponSelectionMoveSlot", zero_vec)
        end
    end
end)
hook.Add( "PlayerBindPress", "fh_weapon_scroll", function( ply, bind, pressed )
	if not pressed then return end
	
	local curtime = CurTime()
	
	if bind == "invnext" or bind == "invprev" then
		if hook.Run("HandleInventoryScrolling", ply, bind, pressed) == false then return end
			
		local weapons = GetSortedWeapons(ply)
		if #weapons == 0 then return true end
	
		local isSelecting = selectingTil and curtime < selectingTil
	
		if not isSelecting or curSelected < 1 or curSelected > #weapons then
			local activeWep = ply:GetActiveWeapon()
			curSelected = 1
			
			if IsValid(activeWep) then
				for i, wep in ipairs(weapons) do
					if wep == activeWep then
						curSelected = i
						break
					end
				end
			end
		end
	
		if bind == "invnext" then
			curSelected = curSelected + 1
			if curSelected > #weapons then
				curSelected = 1
			end
		elseif bind == "invprev" then
			curSelected = curSelected - 1
			if curSelected < 1 then
				curSelected = #weapons
			end
		end
		
		if GetConVar("hud_fastswitch"):GetBool() then
			local weapons = GetSortedWeapons(ply)
			local selectedWep = weapons[curSelected]
		
			if IsValid(selectedWep) then
				input.SelectWeapon(selectedWep)
				selectingTil = curtime + .5
				EmitSound("Player.WeaponSelectionClose", zero_vec)
		
				return
			end
		end
		
		EmitSound("Player.WeaponSelectionMoveSlot", zero_vec)
	
		selectingTil = curtime + 6
	end
	
	if bind == "+attack" and selectingTil and curtime < selectingTil then
		local weapons = GetSortedWeapons(ply)
		local selectedWep = weapons[curSelected]
	
		if IsValid(selectedWep) then
			input.SelectWeapon(selectedWep)
		end
	
		selectingTil = curtime + .05
		EmitSound("Player.WeaponSelectionClose", zero_vec)
		return true
	end
end)

hook.Add("HUDShouldDraw", "no_engine_selection", function(name)
	if name == "CHudWeaponSelection" then return false end
end)