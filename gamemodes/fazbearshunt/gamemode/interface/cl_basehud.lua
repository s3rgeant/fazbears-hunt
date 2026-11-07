local health_bar = Material("vgui/base/health_bar.png")
--if true then hook.Remove( "PostDrawHUD", "fh_basehud") hook.Remove("HUDShouldDraw", "HideHUD") return end
local ammo_bar = Material("vgui/base/ammo_bar.png")
local ammo_bar_w, ammo_bar_h = ammo_bar:Width(), ammo_bar:Height()

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

surface.CreateFont("FHAmmo", 
	{ font = "Share Tech Mono", size = 50, extended = true, weight = 400, antialias = true, bold = true })

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
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudWeaponSelection"] = true,
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

local swepIcon = surface.GetTextureID( 'weapons/swep' )

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
			
			local class = wep:GetClass()
			
			if wep.WepSelectIcon and not wep.FontIcon and not (wep.WepSelectIcon == swepIcon and wep.DrawWeaponSelection) then -- SCRIPTED WEAPONS 
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
			elseif WeaponIcons[class] or wep.FontIcon and WeaponIcons[wep.FontIcon] then -- HALF LIFE 2 ENGINE WEAPONS
				local i_addX = (w + 14) * ci
				local i_w = w * 1.35
				
				local icon = WeaponIcons[class] or (wep.FontIcon and WeaponIcons[wep.FontIcon])
			
				render.SetScissorRect(
					Wx + curAddX, Wy,
					Wx + curAddX + w, Wy + h,
					true
				)
				
				if targetAlpha > 0 then
					draw.SimpleText( icon, IsSelected and "FHWeaponLegacyBig" or "FHWeaponLegacy", Wx+curAddX + w*.5, Wy+addY + h*.5, color_yellow_wpn, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
				end
				
				render.SetScissorRect( 0, 0, 0, 0, false )
				
			elseif wep.DrawWeaponSelection then
				local i_addX = (w + 14) * ci
				local i_w = w * 1.35
			
				render.SetScissorRect(
					Wx + curAddX,
					Wy,
					Wx + curAddX + w,
					Wy + h,
					true
				)
				
				wep:DrawWeaponSelection((Wx+curAddX) - i_w*.5 + w*.5, Wy + addY, w*1.35, h, targetAlpha)
				
				render.SetScissorRect( 0, 0, 0, 0, false )
			
			end
			
			if not wep.DrawWeaponInfoBox == false and selecting and IsSelected and wep.Purpose and wep.Purpose:len() > 0 then
				local purp_x = Wx+curAddX
				local purp_y = Wy+addY - h*.5
				
				local text = wep.Purpose
				
				local purpw, purph = draw.SimpleText( text, "FHWeaponSlot", 0, 0, color_transparent )
				
				surface.SetFont("FHWeaponSlot")
				surface.SetDrawColor(0,0,0,190)
				surface.DrawRect(purp_x - 2, purp_y - 2, purpw + 4, purph + 4)
				
				draw.SimpleText( text, "FHWeaponSlot", purp_x, purp_y, color_yellow_wpn, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
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
		
		local isvalidCurWep = IsValid(curWep)
		
		if selecting and IsValid(selectedWep) or not selecting and isvalidCurWep then
			local wep = selecting and selectedWep or curWep
			surface.SetMaterial( wep_info_bar )
			surface.SetDrawColor( surv_r, surv_g, surv_b, targetAlpha )
			surface.DrawTexturedRect( x, y - h - 6, w, h )
			
			draw.SimpleText( wep:GetPrintName(), "FHCurrentWeapon", x + w*.5, y - h*.5 - 6, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		
		if isvalidCurWep then
			if curWep.DrawAmmo == false then cam.End2D() return end

			x = sw - ammo_bar_w - 32
			
			if curWep.Primary and curWep.Primary.DefaultClip and curWep.Primary.DefaultClip < 0 then cam.End2D() return end

			local clip1, clip2 = curWep:Clip1(), curWep:Clip2()
			local type1, type2 = curWep:GetPrimaryAmmoType(), curWep:GetSecondaryAmmoType()

			local main, reserve, alt

			if clip1 >= 0 then
				main = clip1
				if type1 > 0 then
					reserve = myself:GetAmmoCount( type1 )
				end
			elseif type1 > 0 then
				main = myself:GetAmmoCount( type1 )
			end

			if clip2 >= 0 then
				alt = clip2
			elseif type2 > 0 then
				alt = myself:GetAmmoCount( type2 )
			end

			if main or alt then
				surface.SetMaterial( ammo_bar )
				surface.SetDrawColor( surv_r, surv_g, surv_b, 255 )
				surface.DrawTexturedRect( x, y, ammo_bar_w, ammo_bar_h )

				draw.SimpleText( "#Valve_Hud_AMMO", "FHHealthL", x+27, y+38, color_gray, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

				if main then
					draw.SimpleText( main, "FHAmmo", x+138, y+38, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
				end
				local small = {}
				if reserve then small[#small + 1] = reserve end
				--if alt then small[#small + 1] = alt end

				local small_x, small_step = x + 210, 40
				for i, v in ipairs( small ) do
					draw.SimpleText( v, "FHArmor", small_x + (i - 1) * small_step, y+45, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
				end
			end
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
					selectingTil = CurTime() + 2.5
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
	
	local fastswitch = GetConVar("hud_fastswitch"):GetBool()
	
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
		
		if fastswitch then
			local weapons = GetSortedWeapons(ply)
			local selectedWep = weapons[curSelected]
		
			if IsValid(selectedWep) then
				input.SelectWeapon(selectedWep)
				selectingTil = curtime + 2.5
				EmitSound("Player.WeaponSelectionClose", zero_vec)
		
				return
			end
		end
		
		EmitSound("Player.WeaponSelectionMoveSlot", zero_vec)
	
		selectingTil = curtime + 6
	end
	
	if not fastswitch and bind == "+attack" and selectingTil and curtime < selectingTil then
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

hook.Add( "PreRegisterSWEP", "fh_no_info", function( swep, class )
	swep.PrintWeaponInfo = function() end
end )

-- PROGRESS BAR

local CurrentProgs = {}

function fh.AddProgress(wep, duration, think)
	local ct = CurTime()

	CurrentProgs[#CurrentProgs + 1] = {
		wep = wep or nil,
		startTime = ct,
		endTime = duration and (ct + duration) or ct,
		think = think or nil,
	}
end

local progress_bar = Material("vgui/base/progress/progress_bar.png")
local progress_bar_w = progress_bar:Width()
local progress_bar_h = progress_bar:Height()

hook.Add( "PostDrawHUD", "fh_basehud_progress", function()
	local count = #CurrentProgs

	if count <= 0 then return end

	if not drawhud:GetBool() then return end
	
	local data = CurrentProgs[1]
	
	if not data then return end
	
	local startTime = data.startTime
	local endTime = data.endTime
	
	local dur = endTime - startTime
	
	local think = data.think
	local wep = data.wep
	
	local ct = CurTime()
	
	if ct > endTime then
		CurrentProgs[count] = nil
		return
	end
	
	if wep then
		if not IsValid(wep) then
			CurrentProgs[count] = nil
			return
		end
	end
	
	if think then 
		local res = think(data)
		
		if res == true then
			CurrentProgs[count] = nil
			return
		end
	end
	
	local scrW = ScrW()
	local scrH = ScrH()
				
	local halfW = scrW * .5
	local halfH = scrH * .5
	
	local x = halfW - progress_bar_w * .5
	local y = halfH + 86
	
	local alpha = 255
	
	surface.SetMaterial( progress_bar )
	surface.SetDrawColor( surv_r, surv_g, surv_b, alpha )
	surface.DrawTexturedRect( x, y, progress_bar_w, progress_bar_h )
	
	local progress = math.abs( 1 - (endTime - ct) / dur )
	local timeLeft = endTime - ct
		
	surface.SetDrawColor( 0, 0, 0, alpha )
	surface.DrawRect( x + 11, y + 9, (progress_bar_w - 22), 3 )
		
	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.DrawRect( x + 11, y + 9, (progress_bar_w - 22) * progress, 3 )
	
	draw.SimpleText(formatTime(timeLeft), "FHCurrentWeapon", halfW, y + 24, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)