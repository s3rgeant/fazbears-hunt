currentKiller = currentKiller or ""
fh_hud_color = fh_hud_color or ""

local currentCompanion = ""
local companionColor = Color(255,255,255,255)
local companionIcon
local companionLifeTime
local companionStartTime

currentAbilities = currentAbilities or {}
cupcakes = cupcakes or 0

local scrollOffsets = {}
local scrollSpeeds = {}

fh_ui_scale = CreateClientConVar('fh_ui_scale', 1, true, false, 'FH Ui Scale (Animatronics Hud Only)', 0, 2)
	
local uiScale = fh_ui_scale:GetFloat() --[[ / (1920 / ScrW()) ]]--

cvars.AddChangeCallback("fh_ui_scale", function(name, value_old, value_new)
	hook.Remove("HUDPaint", "DrawKillerInterface")
	uiScale = value_new
	hook.Add("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
end)

local killerIcon
local cake = Material( "vgui/cake.png", "smooth" )

local abilities_X_add = 0

local circle_mat = Material( "vgui/base/killer/avatar.png", "smooth" )

local c_comp_mat = Material( "vgui/animatronics_hud/companion_circle.png", "smooth" )
local c_comp_outline_mat = Material( "vgui/animatronics_hud/companion_outline.png", "smooth" )

local tokens_bg_mat = Material( "vgui/animatronics_hud/abilities/tokens_bg.png", "smooth" )

local ability_bg = Material( "vgui/base/killer/ability_bg.png", "smooth" )
local press_button = Material( "vgui/base/killer/press_button.png", "smooth" )
local press_button2 = Material( "vgui/base/killer/press_button2.png", "smooth" )

local tokens = Material( "vgui/base/killer/tokens_bg.png", "smooth" )
local tokens_w, tokens_h = tokens:Width(), tokens:Height()

local gradient = Material( "vgui/base/killer/gradient.png", "smooth" )
local grad_w, grad_h = gradient:Width(), gradient:Height()

surface.CreateFont("fh_hud_ability_title", { font = "Share Tech Mono", size = 28 * uiScale, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("fh_hud_ability_button", { font = "Share Tech Mono", size = 32 * uiScale, extended = true, weight = 400, antialias = true, bold = true })
surface.CreateFont("fh_hud_ability_time", { font = "Share Tech Mono", size = 24 * uiScale, extended = true, weight = 400, antialias = true, bold = false })

local function hidedefaulthud()
	hook.Add("FH_PreDrawHud", "pills_hideHud", function(name) return true end)
end

local function DrawMaterial_RealSize(mat, clr, x, y, scaleW, scaleH)
	scaleW = scaleW or 1
	scaleH = scaleH or 1
	local REAL_w, REAL_h = mat:Width() * uiScale, mat:Height() * uiScale

	surface.SetMaterial(mat)
	surface.SetDrawColor(clr.r, clr.g, clr.b, clr.a or 255)
	surface.DrawTexturedRect(x, y, REAL_w * scaleW, REAL_h * scaleH)
	
	return REAL_w, REAL_h
end

local grads = {}
function DrawKillerInterface()
	if currentKiller == "" or not currentKiller or not GetConVar("cl_drawhud"):GetBool() then return end

	local screenW, screenH = ScrW(), ScrH()
	
	local curtime = CurTime()

	local hud_color = fh_hud_color or color_white
	local с_hud_color = companionColor or color_white

	local size = 330 * uiScale
	local avatar_y = 260 * uiScale

	local circleX = 32 * uiScale
	local circleY = screenH - avatar_y - (16 * uiScale)
	
	local circle_width, circle_height = DrawMaterial_RealSize(circle_mat, hud_color, circleX, circleY)

	if killerIcon then
		local mat_width, mat_height = (killerIcon:GetInt("$realwidth") or 100) * uiScale, (killerIcon:GetInt("$realheight") or 100) * uiScale
		local avatarX = circleX + (circle_width - mat_width) / 2
		local avatarY = circleY + circle_height - mat_height - (5 * uiScale)

		surface.SetMaterial(killerIcon)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(avatarX, avatarY, mat_width, mat_height)
	end
	
	if companionIcon then
		local c_comp_mat_width, c_comp_mat_height = (c_comp_mat:GetInt("$realwidth") or 60) * uiScale, (c_comp_mat:GetInt("$realheight") or 60) * uiScale

		local c_comp_x = circleX + circle_width / 1.7
		local c_comp_y = circleY + circle_height - c_comp_mat_height

		surface.SetMaterial(c_comp_mat)
		surface.SetDrawColor(с_hud_color)
		surface.DrawTexturedRect(c_comp_x, c_comp_y, c_comp_mat_width, c_comp_mat_height)

		local c_comp_outline_mat_width, c_comp_outline_mat_height = (c_comp_outline_mat:GetInt("$realwidth") or 60) * uiScale, (c_comp_outline_mat:GetInt("$realheight") or 60) * uiScale
		
		local totalDuration = companionLifeTime - companionStartTime
		local elapsed = curtime - companionStartTime
		local fillPercent = 1 - math.Clamp(elapsed / totalDuration, 0, 1)
		
		local x, y = c_comp_x, c_comp_y
		local w, h = c_comp_outline_mat_width, c_comp_outline_mat_height
		local filledHeight = h * fillPercent

		render.SetScissorRect(x, y + (h - filledHeight), x + w, y + h, true)

		surface.SetMaterial(c_comp_outline_mat)
		surface.SetDrawColor(с_hud_color)
		surface.DrawTexturedRect(x, y, w, h)

		render.SetScissorRect(0, 0, 0, 0, false)
		
		if companionIcon then
			local mat_width, mat_height = (companionIcon:GetInt("$realwidth") * 0.61 or 50) * uiScale, (companionIcon:GetInt("$realheight") * 0.61 or 50) * uiScale

			local avatarX = c_comp_x + (c_comp_mat_width - mat_width) / 2
			local avatarY = circleY + circle_height - mat_height - 11

			surface.SetMaterial(companionIcon)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(avatarX, avatarY, mat_width, mat_height)
		end
		local timeLeft = math.ceil(companionLifeTime - curtime or 0)
		draw.SimpleText( tostring(timeLeft), "fh_hud_ability_button", x + w/2, y + h -  14, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )

		abilities_X_add = math.min(abilities_X_add + (50 * FrameTime()), 25)
	else
		abilities_X_add = math.max(abilities_X_add - (50 * FrameTime()), 0)
	end

	local abilityX, abilityY = size + abilities_X_add, screenH - (92 * uiScale)

	for _, abilityData in ipairs(currentAbilities) do
		local abilityName = abilityData.name
		local maxTime = abilityData.maxTime
		local timeLeft = abilityData.endTime and (abilityData.endTime - curtime) or 0
		local timerIsOn = timeLeft > 0
		if timeLeft < 0 then timeLeft = 0 end
		
		local isvisible = timerIsOn or not abilityData.hidden

		if isvisible then
			local dColor
			local abil_color = hud_color
			local button_color = color_white
			
			local clr = abilityData.color
			
			if clr then
				dColor = clr()
				abil_color = clr(hud_color) or hud_color
				button_color = clr()
			end

			local abil_bg_width, abil_bg_height = DrawMaterial_RealSize(ability_bg, abil_color, abilityX, abilityY)
				
			if abilityData.notify and abilityData._notifyData then
				if not timerIsOn then
					local data = abilityData._notifyData
					
					if data.notAvailable then
						grads[abilityName] = curtime
						
						surface.PlaySound("ui/ability_ready.wav")
					end
				end
			end
			
			if grads[abilityName] then
				local dur = 2
				local endTime = grads[abilityName] + dur
				local fraction = (endTime - curtime) / dur
				
				if fraction <= 0 then grads[abilityName] = nil end
				
				if fraction > 0 then
					local color = (dColor or hud_color):Copy()
					color.a = fraction * 220
				
					surface.SetMaterial(gradient)
					surface.SetDrawColor(color)
					surface.DrawTexturedRect(abilityX, abilityY, abil_bg_width, grad_h)
				end
			end

			local ability_button_x = 0
			
			local singleButton = !abilityData.text or abilityData.text:len() <= 1
			local buttonBG = press_button
			if timerIsOn then buttonBG = press_button2 end

			if abilityData.text or timerIsOn then
				local txtColor = !timerIsOn and color_black or color_white
				local butbg_w, butbg_h = buttonBG:Width() * uiScale, buttonBG:Height() * uiScale
				
				surface.SetMaterial(buttonBG)
				surface.SetDrawColor(dColor or (!timerIsOn and color_white or hud_color))
				surface.DrawTexturedRect(abilityX + abil_bg_width - butbg_w * .5, abilityY - butbg_h * .5, butbg_w, butbg_h)
				
				if !timerIsOn then
					local translatable_key = abilityData.text
					local key_phrase_translatable = "keys." .. string.lower(abilityData.text)
					local translated = language.SafeGetPhrase(key_phrase_translatable)

					if translated ~= key_phrase_translatable then
						translatable_key = translated
					end

					draw.SimpleTextOutlined(
						translatable_key,
						"fh_hud_ability_button",
						abilityX + abil_bg_width - 1,
						abilityY + 1,
						txtColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0, color_black
					)
				else

					draw.SimpleText(
						formatTime(timeLeft),
						"fh_hud_ability_time",
						abilityX + abil_bg_width - 1,
						abilityY + 1,
						txtColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
					)
				end
			end

			local translated_ability = language.SafeGetPhrase("fazhunt.abilities." .. abilityName)
			if translated_ability == "fazhunt.abilities." .. abilityName then
				translated_ability = abilityName
			end

			surface.SetFont("fh_hud_ability_title")
			local textWidth, textHeight = surface.GetTextSize(translated_ability)
			local maxTextWidth = (abil_bg_width - 24) * uiScale
			
			local textX = abilityX + (12 * uiScale)
			local textY = abilityY + abil_bg_height * .5

			scrollOffsets[abilityName] = scrollOffsets[abilityName] or 0
			scrollSpeeds[abilityName] = scrollSpeeds[abilityName] or 15

			if textWidth > maxTextWidth then
				local offset = scrollOffsets[abilityName]
				local speed = scrollSpeeds[abilityName]
				local maxOffset = textWidth - maxTextWidth + 10

				offset = offset + FrameTime() * speed

				if offset > maxOffset then
					offset = maxOffset
					speed = -math.abs(speed)
				elseif offset < 0 then
					offset = 0
					speed = math.abs(speed)
				end

				scrollOffsets[abilityName] = offset
				scrollSpeeds[abilityName] = speed

				render.SetScissorRect(textX, textY - 20, textX + maxTextWidth, textY + textHeight, true)
				draw.SimpleText(translated_ability, "fh_hud_ability_title", textX - offset, textY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				render.SetScissorRect(0, 0, 0, 0, false)
			else
				draw.SimpleText(translated_ability, "fh_hud_ability_title", textX, textY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			if isnumber(abilityData.tokens) and abilityData.tokens >= 0 then
				local y_20 = abilityY - 28 * uiScale
				
				local tkens_w, tkens_h = tokens_w * uiScale, tokens_h * uiScale
				
				surface.SetMaterial(tokens)
				surface.SetDrawColor(dColor or hud_color)
				surface.DrawTexturedRect(abilityX, y_20, tkens_w, tkens_h)
				
				local token_bar_height = 6 * uiScale
				local gap_from_sides = 10 * uiScale
				local spacing = 6 * uiScale
				local token_count = abilityData.tokens
				local max_tokens = abilityData.maxtokens or token_count
				local available_width = tkens_w - (gap_from_sides * 2)
				local total_spacing = spacing * (max_tokens - 1)
				local token_width = (available_width - total_spacing) / max_tokens

				for i = 0, token_count - 1 do
					local x = abilityX + gap_from_sides + i * (token_width + spacing)
					local y = y_20 + (tkens_h * .5) - (token_bar_height * .5)
					draw.RoundedBox(0, x, y, token_width, token_bar_height, Color(255, 255, 255))
				end
			end

			if abilityName == "mine" then
				local x_add = 6
				if cupcakes > 0 then
					for i = 1, cupcakes do
						surface.SetMaterial(cake)
						surface.SetDrawColor(255, 255, 255, 255)
						surface.DrawTexturedRect(abilityX + (x_add * uiScale), abilityY - (56 * uiScale), (43 * 0.8)* uiScale, (64 * 0.8) * uiScale)
						x_add = x_add + 40
					end
				end
			end

			abilityX = abilityX + abil_bg_width + 42
		end
		
		if abilityData.notify then
			abilityData._notifyData = {
				notAvailable = timerIsOn,
				tokens = abilityData.tokens or nil,
			}
		end
	end
end

function getAbilityTokens(name)
	if !currentAbilities[name] or !currentAbilities[name].tokens then
		return 0
	end
	return currentAbilities[name].tokens
end

local function updateAnimHudHeader(name, ent)
	if ent.formTable.option == "halloween" then
		name = "h_" .. name
	end
	
	local findHeader = killers.GetPortrait(name)
	
	if findHeader then
		killerIcon = findHeader
		return
	end
	
	local path = "vgui/animatronics_hud/heads/" .. name .. ".png"
	
	
	if file.Exists("materials/" .. path, "GAME") then
		killerIcon = Material( path, "smooth" )
		return
	end
	
	killerIcon = nil
end

local function setCompanion(name, color, lifetime)
	local findHeader = killers.GetPortrait(name)
	
	companionColor = color
	companionLifeTime = lifetime or nil
	companionStartTime = CurTime()
	
	if findHeader then
		companionIcon = findHeader
		return
	end
	
	local path = "vgui/animatronics_hud/heads/" .. name .. ".png"
	
	if file.Exists("materials/" .. path, "GAME") then
		companionIcon = Material( path, "smooth" )
		return
	end
	
	companionColor = Color(255,255,255,255)
	companionLifeTime = nil
	companionStartTime = nil
	companionIcon = nil
end

function assignAbilitiesByKiller(name)
    local abilities = killerAbilities[name]
    if not abilities then return end

    for _, ability in ipairs(abilities) do
        AbilityAdd(
            ability.name,
            ability.key,
            ability.duration or 0,
            ability.tokens or -1,
            ability.hidden or false,
            ability.notify or false
        )
        if ability.condition then
            abilityParentClrFunc(ability.name, ability.condition)
        end
    end
end

function AbilityToggle(name, hide)
	for _, data in ipairs(currentAbilities) do
		if data.name == name then
			data.hidden = hide
			break
		end
	end
end

function AbilityRemove(name)
	for i, data in ipairs(currentAbilities) do
		if data.name == name then
			currentAbilities[i] = nil
			break
		end
	end
end

function AbilityAdd(name, text, duration, tokens, hidden, notify)
    currentAbilities[#currentAbilities + 1] = {
		name = name,
        text = text,
        timeleft = duration,
		tokens = tokens or -1,
		maxtokens = tokens or -1,
        hidden = hidden or false,
		notify = notify or false
    }
end

local noCOLOR = Color(200, 32, 32, 200)
function isNotStuck(default)
	local ply = LocalPlayer()
	if ply:GetMoveType() == 2 then return end
	local trace = util.TraceHull({
		start = ply:GetPos(),
		endpos = ply:GetPos(),
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
		filter = ply,
		mask = MASK_PLAYERSOLID,
		collisiongroup = ply:GetCollisionGroup()
	})
	if trace.Hit then
		return noCOLOR
	end
	return default or white_color
end
-- DEPRECATED: Use AbilityAdd instead
function addAbility(...)
	AbilityAdd(...)
end

function CanMangleLunge(default)
	local ply = LocalPlayer()
	local eyeAng = ply:EyeAngles()
	
	if !ply:GetNWBool("_MangleHooked") then
		if !ply:OnGround() or ply:Crouching() then
			return noCOLOR
		end
	elseif ply:GetNWString("_MangleLastHookType") ~= "ceiling" then
		local diff = math.AngleDifference( eyeAng.y, ply:GetNWAngle("_MangleHookAngle").y )
		
		if diff < -90 or diff > 90 then
			return noCOLOR
		end
	end
	return default or white_color
end

function foxyChargeCondition(default)
	local ply = LocalPlayer()
	
	if ply:Crouching() or !ply:OnGround() then
		return noCOLOR
	end
	return default or white_color
end

function abilityParentClrFunc(name, func)
	for _, abilityData in ipairs(currentAbilities) do
		if abilityData.name == name then
			abilityData.color = func
			break
		end
	end
end

function setDuration(name, newDuration)
	for _, abilityData in ipairs(currentAbilities) do
		if abilityData.name == name then
			abilityData.maxTime = newDuration
			abilityData.endTime = CurTime() + newDuration
			break
		end
    end
end

function setTokens(name, tkns)
	for _, abilityData in ipairs(currentAbilities) do
		if abilityData.name == name then
			abilityData.tokens = tkns
			break
		end
	end
end

function hud_ApplyKiller(name, ent, color)
	table.Empty(currentAbilities)
	hidedefaulthud()
	hook.Add("HUDPaint", "DrawKillerInterface", DrawKillerInterface)
    currentKiller = name
    fh_hud_color = color
	updateAnimHudHeader(currentKiller, ent)
	assignAbilitiesByKiller(currentKiller)
end

hook.Add("PillApply", "fh_applyhudkiller", function(ply, ent)
	local myself = LocalPlayer()
	
	if IsValid(myself) and ply == myself then
		local name = ent.formTable.name
	
		local killerData = killers.GetAll()

		local clr = Color(45,45,45)
			
		if killerData[name] then 
			local killer = killerData[name]

			clr = killer.color
			name = killer.name
		end

		hud_ApplyKiller(name, ent, clr)
	end
end)

net.Receive("ApplyKillerCompanion", function() 
	local anim = net.ReadString()
	local clr = net.ReadColor()
	local lifetime = net.ReadFloat()

	setCompanion(anim, clr, lifetime)
end)

net.Receive("RemoveKillerCompanion", function() 
	companionColor = Color(255,255,255,255)
	companionIcon = nil
end)

net.Receive("fh_remove_hud_mine", function()
	if cupcakes > 0 then
		cupcakes = cupcakes - 1
	end
end)

hook.Add("PostCleanupMap", "fh_cleanhudkiller", function(ply)
	hook.Remove("HUDPaint", "DrawKillerInterface")
	hook.Remove("FH_PreDrawHud", "pills_hideHud")
    currentKiller = ""
	cupcakes = 0
	table.Empty(currentAbilities)
	table.Empty(scrollOffsets)
	table.Empty(scrollSpeeds)
end)

function hud_RemoveKiller()
	hook.Remove("HUDPaint", "DrawKillerInterface")
	hook.Remove("FH_PreDrawHud", "pills_hideHud")
    currentKiller = ""
	cupcakes = 0
	table.Empty(currentAbilities)
	table.Empty(scrollOffsets)
	table.Empty(scrollSpeeds)
end

hook.Add("PillRestore", "fh_removehudkiller", function(ply)
	local myself = LocalPlayer()
	
	if IsValid(myself) and ply == myself then
		hud_RemoveKiller()
		
		companionColor = color_white
		companionIcon = nil
	end
end)

net.Receive("RemoveKiller", function()
	hud_RemoveKiller()
end)

hook.Add("FH_CooldownReceive", "fh_net_killer_change", function(str, duration)
    setDuration(str, duration)
	if str == 'addmine' then
		cupcakes = cupcakes + 1
	end
end)

net.Receive("fh_net_killer_change_tokens", function()
	local str = net.ReadString()
	setTokens(str, net.ReadInt(9))
end)

function FindAbilityVar(ability, var, pill)
	if not ability then return end
	if not var then var = "name" end

	if pill then
		if not killerAbilities[pill] then
		
			local pillName = killers.GetName(pill) -- ищем по короткому погонялу типо freddy
			
			if not killerAbilities[pillName] then return nil end
			
			for _, data in ipairs( killerAbilities[pillName] ) do
				if data.name == ability then return data[var] end
			end
			
		else
		
			for _, data in ipairs( killerAbilities[pill] ) do
				if data.name == ability then return data[var] end
			end
		
		end
	end
	
	return nil
end

local function CheckForNextAbility(should)
	if should ~= 1 then return end
	
	local ability = net.ReadString()
	local pill = net.ReadString()
	local goNext = net.ReadBit()
	
	local key = FindAbilityVar(ability, "key", pill)
	local tokens = FindAbilityVar(ability, "tokens", pill)
	local notify = FindAbilityVar(ability, "notify", pill)
	
	AbilityAdd(ability, key, nil, tokens, false, notify)
	
	CheckForNextAbility(goNext)
end

net.Receive("fh_AbilitiesAdd", function()
	CheckForNextAbility(1)
end)

net.Receive("fh_AbilitiesRemove", function()
	local ability = net.ReadString()
	
	AbilityRemove(ability)
end)

local killcross = Material("vgui/kill-crosshair.png", "smooth")
local addY = 20
local size = 24
local halfs = size/2

hook.Add( "HUDPaint", "fh_killable", function()
	myself = myself or LocalPlayer()
	
	local ent = pills.getMappedEnt(myself)
	
	if IsValid(ent) and ent:Get("killCondition") then
		local condition = ent.formTable.killCondition(myself, ent)
		
		if condition then
			surface.SetDrawColor(255, 0, 0, 255)
			surface.SetMaterial(killcross)
			surface.DrawTexturedRect(ScrW() / 2 - halfs, ScrH()/2 - halfs, size, size)
		end
	end
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

function DisplayText(text1, text2, duration)
    local displayText1 = text1
    local displayText2 = text2
    local displayDuration = duration
    local startTime = CurTime()
	
	hook.Add("HUDPaint", "fh_display_text", function()
		if GetConVar("cl_drawhud"):GetBool() then
			local elapsedTime = CurTime() - startTime
			local alpha = 255

			if elapsedTime > displayDuration then
				local fadeDuration = 1
				local fadeTime = elapsedTime - displayDuration
				if fadeTime < fadeDuration then
					alpha = 255 * (1 - fadeTime / fadeDuration)
				else
					hook.Remove("HUDPaint", "fh_display_text")
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
end

net.Receive("fh_net_display", function()
    local text1 = net.ReadString()
    local text2 = net.ReadString()
    local frmt = net.ReadFloat() or -1
    local duration = net.ReadFloat()
	
	if text1:len() > 0 then text1 = language.GetPhrase(text1) end
	
	if text2:len() > 0 then text2 = language.GetPhrase(text2) end
	
	if frmt > 0 then
		text2 = string.format(tostring(text2), frmt)
	end
	
    DisplayText(text1, text2, duration)
end)

concommand.Add("fh_test_broadcast", function(ply, cmd, args)
	if ply:IsAdmin() then
		local text1 = args[1] or "Hello"
		local text2 = args[2] or "World"
		local duration = tonumber(args[3]) or 5
		
		DisplayText(text1, text2, duration)
	end
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
		local myself = LocalPlayer()
		myself:ScreenFade( SCREENFADE.IN, Color( 255, 255, 255, 255 ), 2, 2 )
		myself:SetDSP(35, false)
		
		hook.Remove("HUDPaint", "fh_thinkfast")
		
		timer.Simple(1.5, function()
			myself:SetDSP(35, true)
		end)
	end)
end)

local function askServerFhEditor()
	net.Start("fh_client_asks_editor")
	net.SendToServer()
end

local function openSettings()
	RunConsoleCommand("fh_settings_open")
end

local contextmenu_options = contextmenu_options or nil

local lable_clr = Color( 238, 49, 49, 20 )
hook.Add("OnContextMenuOpen", "fh_contextmenu", function()
	
	if IsValid(contextmenu_options) then 
		contextmenu_options:Open()
		contextmenu_options:SetPos(0, (ScrH() / 2))
		return 
	end
	
	contextmenu_options = DermaMenu() 
	
	local button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.allsettings"), openSettings )
	button:SetIcon("icon16/cog.png")
	
	contextmenu_options:AddSpacer()
	
	local playeredit_button = contextmenu_options:AddOption( language.GetPhrase("fazhunt.player_editor"), openPlayerEditor )
	playeredit_button:SetIcon("icon16/user.png")
	
	local button = contextmenu_options:AddCVar( language.GetPhrase("fazhunt.mute_spectators"), "proximity_hear_spectators", "0", "1" )
	local button = contextmenu_options:AddCVar( language.GetPhrase("fazhunt.opt_out"), "fh_opt_out_anim", "1", "0" )
	if IsHalloween() then
		local button = contextmenu_options:AddCVar( "Halloween Color Correction", "fh_halloween_cc", "1", "0" )
	end
	
	hook.Run("FHContextMenuOpen", contextmenu_options)
	
	local panel = vgui.Create( "DPanel", contextmenu_options )
		panel:SetSize( 55, 25 )
		panel:SetBackgroundColor( lable_clr )
	local dlable = vgui.Create( "DLabel", panel )
		dlable:SetSize( 200, 25 )
		dlable:SetText( language.GetPhrase("fazhunt.context.animatronics_only") )
		dlable:SetPos( 12, 0 )
		dlable:SetTextColor( color_white )

	contextmenu_options:AddPanel(panel)
	contextmenu_options:AddSpacer()
	
	local button = contextmenu_options:AddCVar( language.GetPhrase("fazhunt.halo_teammates"), "fh_halo_teammates", "1", "0" )
	local button = contextmenu_options:AddCVar( language.GetPhrase("fazhunt.thirperson"), "fh_thirdperson", "1", "0" )
	
	hook.Run("FHContextMenuAnimatronicsOpen", contextmenu_options)
	
	local myself = LocalPlayer()
	
	if IsValid(myself) and (myself:IsSuperAdmin() and !game.SinglePlayer()) then
		
		local panel = vgui.Create( "DPanel", contextmenu_options )
			panel:SetSize( 55, 25 )
			panel:SetBackgroundColor( lable_clr )
		local dlable = vgui.Create( "DLabel", panel )
			dlable:SetSize( 200, 25 )
			dlable:SetText( "Super Admin Only" )
			dlable:SetPos( 12, 0 )
			dlable:SetTextColor( color_white )
	
		contextmenu_options:AddOption( "FH Editor (BETA)", askServerFhEditor )
	end
	
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

local fh_rmb_material = Material("hud/fh_rmb")

local fh_rmb_size = 72
local fh_rmb_halfsize = fh_rmb_size/2

local function DrawRMBHint()
	surface.SetMaterial( fh_rmb_material )
	surface.SetDrawColor( 255, 255, 255, 255 )
	surface.DrawTexturedRect( ScrW() / 2 - fh_rmb_halfsize, ScrH() / 2 + 32, fh_rmb_size, fh_rmb_size )
end

function RMBHint(duration)
	--таймер

	hook.Add( "HUDPaint", "FH_HudPaint_RMBHINT", function()
		DrawRMBHint()
	end )
	
	if duration and duration > 0 then
		if timer.Exists("FH_DrawRMBHINT_TIMER") then
			timer.Remove("FH_DrawRMBHINT_TIMER")
		end
		timer.Create("FH_DrawRMBHINT_TIMER", duration, 1, function()
			hook.Remove("HUDPaint", "FH_HudPaint_RMBHINT")
		end)
	end
end

function RemoveRMBHint()
	hook.Remove("HUDPaint", "FH_HudPaint_RMBHINT")
end

local fh_interact_material = Material("hud/fh_interact")

local function DrawRMBHint()
	surface.SetMaterial( fh_interact_material )
	surface.SetDrawColor( 255, 255, 255, 255 )
	surface.DrawTexturedRect( ScrW() / 2 - fh_rmb_halfsize, ScrH() / 2 + 32, fh_rmb_size, fh_rmb_size )
end

function INTERACT_Hint(duration)
	hook.Add( "HUDPaint", "FH_HudPaint_E_HINT", function()
		DrawRMBHint()
	end )
	
	if duration and duration > 0 then
		if timer.Exists("FH_DrawEHINT_TIMER") then
			timer.Remove("FH_DrawEHINT_TIMER")
		end
		timer.Create("FH_DrawEHINT_TIMER", duration, 1, function()
			hook.Remove("HUDPaint", "FH_HudPaint_E_HINT")
		end)
	end
end

function RemoveINTERACT_Hint()
	hook.Remove("HUDPaint", "FH_HudPaint_E_HINT")
end