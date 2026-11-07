AddCSLuaFile()

if not CLIENT then return end

local endo_ability_selector = Material("vgui/endo/endo_ability_selector.png")

local availableKillers 		= {}
local selector_panel
local curSelected = 0

local barsData = {}

surface.CreateFont("FHEndoSelectAbility", 
	{ font = "Share Tech Mono", size = 24, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("FHEndoAbility", 
	{ font = "Share Tech Mono", size = 32, extended = true, weight = 400, antialias = true, bold = true })
	
local function draw_endoui()
	if not istable(availableKillers) then return end

	selector_panel = vgui.Create("DFrame")
	selector_panel:SetTitle("")
	selector_panel:SetDraggable(false)
	selector_panel:ShowCloseButton(false)
	selector_panel:SetSize(780, 280)
	selector_panel:Center()
	selector_panel.Paint=function(self, w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(endo_ability_selector)
		surface.DrawTexturedRect(0, 0, w, h)
		
		draw.SimpleText( "Выбери способность", "FHEndoSelectAbility", w*.5, 34, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		
		local curAbilityData = availableKillers[curSelected + 1]
		if curAbilityData then
			local abilityTxt = curAbilityData.ability
			
			local toTranslate = "fazhunt.abilities." .. abilityTxt
			local translated = language.GetPhrase(toTranslate)
			
			if translated == toTranslate then translated = abilityTxt end
			
			local animName = language.GetPhrase(killers.GetFullName(curAbilityData.killer))
			
			draw.SimpleText( animName .. " - " .. translated, "FHEndoAbility", w*.5, 78, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		
		local count = 0
		local size = 88
		local hsize = size*.5
		for i = 1, #availableKillers do
			local abilityData = availableKillers[i]
			local animatronic = abilityData.killer
			local ability = abilityData.ability
			
			local bar = killers.GetAvatar(animatronic)
			if not bar then continue end
			
			if not barsData[bar] then barsData[bar] = {} end
			local data = barsData[bar]
			
			local selected = (count == curSelected)
			
			local x = (w/2)
			local y = 176.5
			
			local factor = FrameTime() * 20
			local localSize = Lerp(factor, data.size or size, selected and size*1.3 or size)
			local hlocalSize = localSize*.5
			
			local targetX = (x - hlocalSize) + ( (count-curSelected) * (localSize + 24) )
			local localX = Lerp(factor, data.x or targetX, targetX)
				
			local localY = y - hlocalSize
			
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial( bar )
			surface.DrawTexturedRect(localX, localY, localSize, localSize)
			
			data.x = localX
			data.y = localY
			data.size = localSize
			
			count=count+1
		end
	end
end

function endo.IsPretenseUIOpen()
	return IsValid(selector_panel)
end

local nextMouseWheel = 0
function endo.PretenseOpenUI()
	draw_endoui()
	
	curSelected = 0
		
	sortedAbilities = endo.GetSortedAbilities()
	availableKillers = {}
		
	local myself = LocalPlayer()
	local ent = myself:GetPillCostume()
	
	local skipThese = {}
			
	for _, teammate in ipairs( team.GetPlayers( myself:Team() ) ) do -- я еблан или нет? оцените пожалуйста
		local pill = teammate:GetPillCostume()
		if IsValid(pill) then
			if pill.GetPillName then skipThese[ pill:GetPillName() ] = true end
		end
	end
	
	for _, data in ipairs(sortedAbilities) do
		local ability = data.ability
		local killer = data.killer
		
		if skipThese[killer] then continue end
		
		if IsValid(ent) then
			if ent:GetNW2String("ENDO_CurrentAbility", "") == ability then continue end
			if ent:GetNW2String("ENDO_LastAbility", "") == ability and ability ~= "pretense" then continue end
		end
		
		availableKillers[#availableKillers + 1] = data
	end
	
	hook.Add( "CreateMove", "endo_ui_scroll", function(cmd)
		local curtime = CurTime()
		
		if curtime < nextMouseWheel then return end
		
		if ( input.WasMousePressed( MOUSE_WHEEL_UP ) ) then 
			curSelected = curSelected - 1
			nextMouseWheel = curtime + .01
			
			if curSelected < 0 then
				curSelected = 0
			end
			return
		elseif ( input.WasMousePressed( MOUSE_WHEEL_DOWN ) ) then 
			curSelected = curSelected + 1 
			nextMouseWheel = curtime + .01
			
			if curSelected > #availableKillers - 1 then
				curSelected = #availableKillers - 1
			end
			return
		end
	end )
	
	hook.Add( "PlayerBindPress", "endo_ui_select", function( ply, bind, pressed )
		if not pressed then return end
		
		if bind == "+attack" then
		
			net.Start("fh_endo_AbilitySelected")
				net.WriteString( availableKillers[ curSelected + 1 ].ability )
				net.WriteString( availableKillers[ curSelected + 1 ].killer )
			net.SendToServer()
			
			cooldown.Set(LocalPlayer(), "pretense", 2)
			
			endo.PretenseCloseUI()
		
			return true
		
		elseif bind == "+attack2" then
			--cooldown.Set(LocalPlayer(), "pretense", .1)
			
			endo.PretenseCloseUI()
		
			return true
		end
	end)
end

function endo.PretenseCloseUI()
	if IsValid(selector_panel) then
		selector_panel:Close()
		barsData = {}
		
		hook.Remove( "CreateMove", "endo_ui_scroll" )
		hook.Remove( "PlayerBindPress", "endo_ui_select")
	end
end

concommand.Add("endoui_test", function()
    if LocalPlayer():IsSuperAdmin() then
		draw_endoui()
		
		availableKillers = table.GetKeys(killers.GetAll())
		
		timer.Simple(2, function()
			curSelected=1
		end)
		timer.Simple(4, function()
			curSelected=4
		end)
		timer.Simple(6, function()
			selector_panel:Close()
		end)
	end
end)