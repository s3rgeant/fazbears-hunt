currentKiller = currentKiller or ""
fh_hud_color = fh_hud_color or ""

currentAbilities = currentAbilities or {}
cupcakes = cupcakes or 0

local scrollOffsets = {}
local scrollSpeeds = {}

local fh_ui_scale = CreateClientConVar('fh_ui_scale', 1, true, false, 'FH Ui Scale (Animatronics Hud Only)', 0, 2)
	
local uiScale = fh_ui_scale:GetFloat() / (1920 / ScrW())

--[[
cvars.AddChangeCallback("fh_ui_scale", function(name, value_old, value_new)
	hook.Remove("HUDPaint", "DrawKillerInterface")
	uiScale = (1920 / ScrW()) * value_new
	hook.Add("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
end)
--]]

local killerIconPath = killerIconPath or ""
local killerIcon = killerIcon or Material( killerIconPath )
local cake = Material( "vgui/cake.png", "smooth" )

local circle_mat = Material( "vgui/animatronics_hud/circle.png", "smooth" )
local circle_outline_mat = Material( "vgui/animatronics_hud/circle_outline.png", "smooth" )

local tokens_bg_mat = Material( "vgui/animatronics_hud/abilities/tokens_bg.png", "smooth" )
local tokens_bg_outline_mat = Material( "vgui/animatronics_hud/abilities/tokens_outline.png", "smooth" )

local abil_bg_mat = Material( "vgui/animatronics_hud/abilities/bg.png", "smooth" )
local abil_bg_outline_mat = Material( "vgui/animatronics_hud/abilities/bg_outline.png", "smooth" )

surface.CreateFont("fh_hud_ability_title", { font = "Share Tech Mono Regular", size = 28 * uiScale, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("fh_hud_ability_button", { font = "Share Tech Mono Regular", size = 40 * uiScale, extended = true, weight = 400, antialias = true, bold = false })
surface.CreateFont("fh_hud_ability_time", { font = "Share Tech Mono Regular", size = 16 * uiScale, extended = true, weight = 400, antialias = true, bold = false })

local button_ability_mat = Material( "vgui/animatronics_hud/abilities/button_ability.png", "smooth" )
local mouse_ability_mat = Material( "vgui/animatronics_hud/abilities/mouse_ability.png", "smooth" )

function DrawKillerInterface()
	if currentKiller == "" or not currentKiller or not GetConVar("cl_drawhud"):GetBool() then return end

	local screenW, screenH = ScrW(), ScrH()

	local size = 330 * uiScale
	local avatar_y = 260 * uiScale

	local circle_width, circle_height = (circle_mat:GetInt("$realwidth") or 100) * uiScale, (circle_mat:GetInt("$realheight") or 100) * uiScale

	local circleX = 32 * uiScale
	local circleY = screenH - avatar_y - (16 * uiScale)

	surface.SetMaterial(circle_mat)
	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawTexturedRect(circleX, circleY, circle_width, circle_height)

	local circle_outline_mat_width, circle_outline_mat_height = circle_outline_mat:GetInt("$realwidth") * uiScale, circle_outline_mat:GetInt("$realheight") * uiScale

	local hud_color = fh_hud_color or Color(255,255,255,255)

	surface.SetMaterial(circle_outline_mat)
	surface.SetDrawColor(hud_color)
	surface.DrawTexturedRect(32 * uiScale, screenH - avatar_y - (16 * uiScale), circle_outline_mat_width, circle_outline_mat_height)

	if file.Exists("materials/" .. killerIconPath, "GAME") then
		local mat_width, mat_height = (killerIcon:GetInt("$realwidth") or 100) * uiScale, (killerIcon:GetInt("$realheight") or 100) * uiScale
		local avatarX = circleX + (circle_width - mat_width) / 2
		local avatarY = circleY + circle_height - mat_height - (7 * uiScale)

		surface.SetMaterial(killerIcon)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(avatarX, avatarY, mat_width, mat_height)
	end

	local abilityX, abilityY = size, screenH - (100 * uiScale)

	for abilityName, abilityData in pairs(currentAbilities) do
		local maxTime = abilityData.maxTime
		local timeLeft = abilityData.endTime and (abilityData.endTime - CurTime()) or 0
		if timeLeft < 0 then timeLeft = 0 end

		if timeLeft > 0 or not abilityData.hidden then
			local clr = abilityData.color
			if type(clr) == "function" then
				clr = clr()
			end

			local abil_bg_width, abil_bg_height = (abil_bg_mat:GetInt("$realwidth") or 100) * uiScale, (abil_bg_mat:GetInt("$realheight") or 100) * uiScale

			surface.SetMaterial(abil_bg_mat)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(abilityX, abilityY, abil_bg_width, abil_bg_height)

			local abil_bg_outline_width, abil_bg_outline_height = abil_bg_outline_mat:GetInt("$realwidth") * uiScale, abil_bg_outline_mat:GetInt("$realheight") * uiScale

			surface.SetMaterial(abil_bg_outline_mat)
			surface.SetDrawColor(hud_color)
			surface.DrawTexturedRect(abilityX, abilityY, abil_bg_outline_width, abil_bg_outline_height)

			local button_ability_width, button_ability_height = button_ability_mat:GetInt("$realwidth") * uiScale, button_ability_mat:GetInt("$realheight") * uiScale
			local mouse_ability_width, mouse_ability_height = mouse_ability_mat:GetInt("$realwidth") * uiScale, mouse_ability_mat:GetInt("$realheight") * uiScale

			local ability_button_x = 0

			if abilityData.keyboard then
				ability_button_x = abilityX + (205 * uiScale)
				surface.SetMaterial(button_ability_mat)
				surface.SetDrawColor(clr or Color(255,255,255,255))
				surface.DrawTexturedRect(ability_button_x, abilityY + (abil_bg_height/2 - button_ability_height/2), button_ability_width, button_ability_height)
			else
				ability_button_x = abilityX + (168 * uiScale)
				surface.SetMaterial(mouse_ability_mat)
				surface.SetDrawColor(clr or Color(255,255,255,255))
				surface.DrawTexturedRect(ability_button_x, abilityY + (abil_bg_height/2 - mouse_ability_height/2), mouse_ability_width, mouse_ability_height)
			end

			local translated_ability = language.GetPhrase("fazhunt.abilities." .. abilityName)
			if translated_ability == "fazhunt.abilities." .. abilityName then
				translated_ability = abilityName
			end

			surface.SetFont("fh_hud_ability_title")
			local textWidth, textHeight = surface.GetTextSize(translated_ability)
			local maxTextWidth = (abilityData.keyboard and 170 or 140) * uiScale
			local textX = abilityX + (18 * uiScale)
			local textY = abilityY + (10 * uiScale)

			scrollOffsets[abilityName] = scrollOffsets[abilityName] or 0
			scrollSpeeds[abilityName] = scrollSpeeds[abilityName] or 15

			if textWidth > maxTextWidth then
				local offset = scrollOffsets[abilityName]
				local speed = scrollSpeeds[abilityName]
				offset = offset + FrameTime() * speed

				if offset >= (textWidth - maxTextWidth + 10) or offset <= 0 then
					scrollSpeeds[abilityName] = -speed
				end

				scrollOffsets[abilityName] = offset

				render.SetScissorRect(textX, textY, textX + maxTextWidth, textY + textHeight, true)
				draw.SimpleText(translated_ability, "fh_hud_ability_title", textX - scrollOffsets[abilityName], textY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
				render.SetScissorRect(0, 0, 0, 0, false)
			else
				draw.SimpleText(translated_ability, "fh_hud_ability_title", textX, textY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT)
			end

			local translatable_key = abilityData.text
			local key_phrase_translatable = "keys." .. string.lower(abilityData.text)
			local translated = language.GetPhrase(key_phrase_translatable)

			if translated ~= key_phrase_translatable then
				translatable_key = translated
			end
			
			--print( string.len(translatable_key) )

			draw.SimpleText(
				language.GetPhrase(translatable_key),
				"fh_hud_ability_button",
				ability_button_x + (abilityData.keyboard and (button_ability_width/2) or (mouse_ability_width/2)),
				abilityY + (abil_bg_outline_height / 2 - 20 * uiScale),
				clr,
				TEXT_ALIGN_CENTER
			)

			local timer_width = (abilityData.keyboard and 172 or 122) * uiScale
			local timer_x = 13 * uiScale
			local timer_y = 51 * uiScale
			local max_timer_width = timer_width - (6 * uiScale)

			if maxTime and timeLeft > 0 then
				draw.RoundedBox(0, abilityX + timer_x, abilityY + timer_y, 2 * uiScale, 8 * uiScale, Color(255,255,255))
				draw.RoundedBox(0, abilityX + timer_x + timer_width, abilityY + timer_y, 2 * uiScale, 8 * uiScale, Color(255,255,255))
				draw.RoundedBox(0, abilityX + timer_x + (4 * uiScale), abilityY + timer_y + (2 * uiScale), max_timer_width * (timeLeft / maxTime), 4 * uiScale, Color(255,255,255))
			end

			if timeLeft > 0 then
				draw.SimpleText(tostring(math.ceil(timeLeft)) .. " s", "fh_hud_ability_time", abilityX + timer_x + max_timer_width/2, abilityY + (36 * uiScale), Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
			end

			if abilityData.tokens >= 0 then
				local y_20 = abilityY - 24 * uiScale
			
				local tokens_bg_width, tokens_bg_height = (tokens_bg_mat:GetInt("$realwidth") or 100) * uiScale, (tokens_bg_mat:GetInt("$realheight") or 100) * uiScale

				surface.SetMaterial(tokens_bg_mat)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(abilityX, y_20, tokens_bg_width, tokens_bg_height)

				local tokens_bg_outline_width, tokens_bg_outline_height = (tokens_bg_outline_mat:GetInt("$realwidth") or 100) * uiScale, (tokens_bg_outline_mat:GetInt("$realheight") or 100) * uiScale

				surface.SetMaterial(tokens_bg_outline_mat)
				surface.SetDrawColor(hud_color)
				surface.DrawTexturedRect(abilityX, y_20, tokens_bg_outline_width, tokens_bg_outline_height)

				local token_bar_height = 6 * uiScale
				local gap_from_sides = 10 * uiScale
				local spacing = 6 * uiScale
				local token_count = abilityData.tokens
				local max_tokens = abilityData.maxtokens or token_count
				local available_width = tokens_bg_width - (gap_from_sides * 2)
				local total_spacing = spacing * (max_tokens - 1)
				local token_width = (available_width - total_spacing) / max_tokens

				for i = 0, token_count - 1 do
					local x = abilityX + gap_from_sides + i * (token_width + spacing)
					local y = y_20 + (tokens_bg_outline_height / 2) - (token_bar_height / 2)
					draw.RoundedBox(0, x, y, token_width, token_bar_height, Color(255, 255, 255))
				end
			end

			if abilityName == "mine" then
				local x_add = 6
				if cupcakes > 0 then
					for i = 1, cupcakes do
						surface.SetMaterial(cake)
						surface.SetDrawColor(255, 255, 255, 255)
						surface.DrawTexturedRect(abilityX + x_add, abilityY - 56, 43 * 0.8, 64 * 0.8)
						x_add = x_add + 40
					end
				end
			end

			abilityX = abilityX + abil_bg_width + 24
		end
	end
end

local function updateAnimHudHeader(name)
	killerIconPath = "vgui/animatronics_hud/heads/"..name..".png"
	killerIcon = Material( killerIconPath, "smooth" )
end

function assignAbilitiesByKiller(name)
    local abilities = killerAbilities[name]
    if not abilities then return end

    for _, ability in ipairs(abilities) do
        addAbility(
            ability.name,
            ability.key,
            ability.duration or 0,
            ability.keyboard,
            ability.tokens or -1,
            ability.hidden or false
        )
        if ability.condition then
            abilityParentClrFunc(ability.name, ability.condition)
        end
    end
end

function addAbility(name, text, duration, keyboard, tokens, hidden)
    if currentAbilities[name] then
        return
    end

    currentAbilities[name] = {
        text = text,
        timeleft = duration,
        keyboard = keyboard or false,
		tokens = tokens or -1,
		maxtokens = tokens or -1,
        hidden = hidden or false
    }
end

function isNotStuck()
	local ply = LocalPlayer()
	if ply:GetMoveType() == 2 then return end
	local trace = util.TraceHull({
		start = ply:GetPos(),
		endpos = ply:GetPos(),
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
		filter = ply,
	})
	if trace.Hit then
		return Color(200, 32, 32, 200)
	end
	return Color(255, 255, 255, 255)
end

function abilityParentClrFunc(name, func)
	currentAbilities[name].color = func
end

function setDuration(name, newDuration)
    if currentAbilities[name] then
        currentAbilities[name].maxTime = newDuration
        currentAbilities[name].endTime = CurTime() + newDuration
    end
end

function setTokens(name, tkns)
    if currentAbilities[name] then
        currentAbilities[name].tokens = tkns
    end
end

net.Receive("ApplyKiller", function()
	hook.Add("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
    currentKiller = net.ReadString()
    fh_hud_color = net.ReadColor()
	updateAnimHudHeader(currentKiller)
	assignAbilitiesByKiller(currentKiller)
end)

net.Receive("fh_remove_hud_mine", function()
	if cupcakes > 0 then
		cupcakes = cupcakes - 1
	end
end)

net.Receive("RemoveKiller", function()
	hook.Remove("HUDPaint", "DrawKillerInterface")
    currentKiller = ""
	cupcakes = 0
	table.Empty(currentAbilities)
	table.Empty(scrollOffsets)
	table.Empty(scrollSpeeds)
end)

net.Receive("fh_net_killer_change", function()
	local str = net.ReadString()
    setDuration(str, net.ReadFloat())
	if str == 'addmine' then
		cupcakes = cupcakes + 1
	end
	--[[
	if str == 'Submerge' then
		hook.Add("RenderScreenspaceEffects", "NightVisionEffect", function()
            local colorCorrection = {
                ["$pp_colour_addr"] = 0.3,
                ["$pp_colour_addg"] = -0.6,
                ["$pp_colour_addb"] = 0.3,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"] = 0.6,
                ["$pp_colour_colour"] = 0.4,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(colorCorrection)
        end)
	end
	]]
end)

net.Receive("fh_net_killer_change_tokens", function()
	local str = net.ReadString()
	setTokens(str, net.ReadInt(9))
end)

-- текст смешной сверху
surface.CreateFont("BigTextFont", {
    font = "Arial",
	shadow = true,
	extended = true,
	antialias = true,
    size = 48,
    weight = 700
})

surface.CreateFont("SmallTextFont", {
    font = "Arial",
	shadow = true,
	extended = true,
	antialias = true,
    size = 32,
    weight = 500
})

local displayText1 = ""
local displayText2 = ""
local displayDuration = 0
local startTime = 0
local isDisplaying = false
hook.Add("HUDPaint", "fh_display_text", function()
    if isDisplaying and GetConVar("cl_drawhud"):GetBool() then
        local elapsedTime = CurTime() - startTime
        local alpha = 255

        if elapsedTime > displayDuration then
            local fadeDuration = 1
            local fadeTime = elapsedTime - displayDuration
            if fadeTime < fadeDuration then
                alpha = 255 * (1 - fadeTime / fadeDuration)
            else
                isDisplaying = false
                return
            end
        end

        surface.SetFont("BigTextFont")
        surface.SetTextColor(255, 255, 255, alpha)

        local w, h = surface.GetTextSize(displayText1)
        local x = ScrW() / 2 - w / 2
        local y = ScrH() / 4

        surface.SetTextPos(x, y)
        surface.DrawText(displayText1)

        surface.SetFont("SmallTextFont")
        surface.SetTextColor(255, 255, 255, alpha)

        local w2, h2 = surface.GetTextSize(displayText2)
        local x2 = ScrW() / 2 - w2 / 2
        local y2 = y + h + 5

        surface.SetTextPos(x2, y2)
        surface.DrawText(displayText2)
    end
end)

function fh_change_display(text1, text2, duration)
    displayText1 = text1
    displayText2 = text2
    displayDuration = duration
    startTime = CurTime()
    isDisplaying = true
end


concommand.Add("fh_test_broadcast", function(ply, cmd, args)
	if ply:IsAdmin() then
		local text1 = args[1] or "Hello"
		local text2 = args[2] or "World"
		local duration = tonumber(args[3]) or 5
		
		fh_change_display(text1, text2, duration)
	end
end)

net.Receive("fh_net_display", function()
    local text1 = net.ReadString()
    local text2 = net.ReadString()
    local frmt = net.ReadFloat() or -1
    local duration = net.ReadFloat()
	
	if string.len(text1) > 0 then
		text1 = language.GetPhrase(text1)
	end
	
	if string.len(text2) > 0 then
		text2 = language.GetPhrase(text2)
	end
	
	if frmt > 0 then
		text2 = string.format(tostring(text2), frmt)
	end
	
    fh_change_display(text1, text2, duration)
end)

//think fast chucklenuts

local thinkfast_mat = Material("vgui/thinkFast.png")
function chucklenuts()
    if GetConVar("cl_drawhud"):GetBool() then
		surface.SetDrawColor(255, 255, 255, 255)
		
		surface.SetMaterial(thinkfast_mat)
		
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    end
end

net.Receive("fh_net_thinkfast", function()
	hook.Add("HUDPaint", "fh_thinkfast", chucklenuts)
	
	surface.PlaySound('thinkfast.wav')
	
	timer.Simple(1.2, function() 
		LocalPlayer():ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 255 ), 2, 2 )
		LocalPlayer():SetDSP(35, false)
		
		hook.Remove("HUDPaint", "fh_thinkfast")
		
		timer.Simple(1.5, function()
			LocalPlayer():SetDSP(35, true)
		end)
	end)
end)

local contextmenu_options = nil

hook.Add("OnContextMenuOpen", "fh_contextmenu", function()
	
	if IsValid(contextmenu_options) then 
		contextmenu_options:Open()
		contextmenu_options:SetPos(0, (ScrH() / 2))
		return 
	end
	
	contextmenu_options = DermaMenu() 
	local playeredit_button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.context.player_editor"), openPlayerEditor )
	playeredit_button:SetIcon("icon16/user.png")
	
	local button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.context.mute_spectators") )
	button:SetIsCheckable( true )
	button:SetChecked( !GetConVar("proximity_hear_spectators"):GetBool() )
	button.OnChecked = function( checked ) toggleConsoleCommand("proximity_hear_spectators") end
	
	local panel = vgui.Create( "DPanel", contextmenu_options )
	panel:SetSize( 55, 25 )
	panel:SetBackgroundColor( Color( 255, 255, 255 ) )
	
	local dlable = vgui.Create( "DLabel", panel )
	dlable:SetSize( 200, 25 )
	dlable:SetText( language.GetPhrase("fazhunt.context.animatronics_only") )
	dlable:SetPos( 12, 0 )
	dlable:SetTextColor( Color(0,0,0) )
	
	contextmenu_options:AddPanel(panel)
	contextmenu_options:AddSpacer()
	
	local button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.context.thirperson") )
	button:SetIsCheckable( true )
	button:SetChecked( GetConVar("fh_thirdperson"):GetBool() )
	button.OnChecked = function( checked ) toggleConsoleCommand("fh_thirdperson") end
	
	local button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.context.halo_teammates") )
	button:SetIsCheckable( true )
	button:SetChecked( GetConVar("fh_halo_teammates"):GetBool() )
	button.OnChecked = function( checked ) toggleConsoleCommand("fh_halo_teammates") end
	
	local button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.context.dynamic_camera") )
	button:SetIsCheckable( true )
	button:SetChecked( GetConVar("fh_dynamic_firstperson"):GetBool() )
	button.OnChecked = function( checked ) toggleConsoleCommand("fh_dynamic_firstperson") end
	
	contextmenu_options:Open()
	contextmenu_options:SetPos(0, (ScrH() / 2))
end)

hook.Add("OnContextMenuClose", "fh_contextmenu_close", function()
	
	if IsValid(contextmenu_options) then
		contextmenu_options:Hide()
	end
end)

function toggleConsoleCommand(str)
	local ply = LocalPlayer()
	local option = GetConVar(str):GetBool() and "0" or "1"
	RunConsoleCommand(str, option)
end

function openPlayerEditor()

    local newv = list.Get( "DesktopWindows" )[ "PlayerEditor" ]

	local Window = vgui.Create( "DFrame" )
	Window:SetSize( newv.width, newv.height )
	Window:SetTitle( newv.title )
	Window:Center()
	Window:MakePopup()
	
	newv.init( nil, Window )
	
end