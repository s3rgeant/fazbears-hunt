-- не смотря на название файла "cl_timer" тут также будет большинство интерфейса

resource.AddFile("resource/fonts/ShareTechMonoRegular_0.ttf")

local timerBg = Material("vgui/timer/timer_bg.png")
local timerGlow = Material("vgui/timer/time_glow.png")

local fh_draw_timer = CreateClientConVar('fh_draw_timer', 1, true, false, 'Draw Timer?', 0, 1)

local timerEnd = 0
local timerSetupEnd = 0

local timerTotal = 0

local timerMode = "lobby"
local timerTitle = language.GetPhrase("fazhunt.generic.waiting_player")

local postlobbytimer_alpha = 255

local roundtimer_alpha = 255
local roundtimer_y = 52
local roundtimer_y_target = 52
	
local fh_timer_width = 360

surface.CreateFont("timerFontUpper", { font = "Share Tech Mono Regular", size = 32, extended = true, weight = fh_timer_width, antialias = true, bold = true })
surface.CreateFont("timerFontBelow", { font = "Share Tech Mono Regular", size = 48, extended = true, weight = fh_timer_width, antialias = true, bold = false })
surface.CreateFont("timerFontSmall", { font = "Share Tech Mono Regular", size = 24, extended = true, weight = fh_timer_width, antialias = true, bold = true })

local function DrawTimer()
    if not GetConVar("cl_drawhud"):GetBool() or not fh_draw_timer:GetBool() then return end

    local timeStartupLeft = math.max(0, timerSetupEnd - CurTime())
    local timeLeft = timerEnd - CurTime()
    if timeStartupLeft > 0 then
        timeLeft = math.max(0, timerEnd - timerSetupEnd)
    else
        timeLeft = math.max(0, timeLeft)
    end

    local x = (ScrW() / 2) - (fh_timer_width / 2)
    local y = 8
	local redline_w = 6
	
	local main_y = y + redline_w + 10
	
    surface.SetDrawColor(255, 255, 255, 250)
    surface.SetMaterial(timerBg)
    surface.DrawTexturedRect(ScrW() / 2 - 200, main_y - 4, 400, 100)

    draw.RoundedBox(0, x, y, fh_timer_width, redline_w, Color(0, 0, 0, 250))

    draw.RoundedBox(0, x, y, fh_timer_width * (timeLeft / timerTotal), redline_w, Color(136, 0, 0, 255))

    --draw.RoundedBox(0, x, main_y, fh_timer_width, 100, Color(0, 0, 0, 240))

    draw.SimpleText(timerTitle, "timerFontUpper", ScrW() / 2, main_y + 20, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    draw.SimpleText("- " .. formatTime(timeLeft) .. " -", "timerFontBelow", ScrW() / 2, main_y + roundtimer_y, Color(255, 255, 255, roundtimer_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
    surface.SetDrawColor(255, 255, 255, 25 * (roundtimer_alpha/255))
    surface.SetMaterial(timerGlow)
    surface.DrawTexturedRect(ScrW() / 2 - 114, main_y + roundtimer_y - 24, 227, 46)

    draw.SimpleText(formatTime(timeStartupLeft), "timerFontSmall", ScrW() / 2, main_y + 79, Color(255, 174, 0, postlobbytimer_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("Think", "fh_timer_think", function()
    if timerMode == "game" and postlobbytimer_alpha > 0 then
        postlobbytimer_alpha = postlobbytimer_alpha - 2
    end
	
    local speed = FrameTime() * 2
    roundtimer_y = Lerp(speed, roundtimer_y, roundtimer_y_target)
end)




-- #### ВЫБИРАЛКА АНИМАТРОНОВ!!!

local animatronics = animatronics or {}
local selectable = selectable or false
local selector = selector or nil
local grid = grid or nil
local animtooltip = nil

local showAnimTooltip = false
local animTooltipText = ""

function draw_killer_selector()
    if not istable(animatronics) then return end

    if IsValid(fh_admin_panel) then 
        fh_admin_panel:Remove()
        gui.EnableScreenClicker(false)
    end

    selector = vgui.Create("DFrame")
    selector:SetTitle("")
    selector:SetDraggable(false)
    selector:ShowCloseButton(false)
    selector:SetSize(600, 600)
    selector:Center()
    selector:MakePopup()

    selector.Paint = function(self, w, h)
        draw.RoundedBox(24, 0, 0, w, h, Color(0, 0, 0, 240))
    end

    local titleLabel = vgui.Create("DLabel", selector)
    titleLabel:SetText(language.GetPhrase("fazhunt.selector.select_animatronic"))
    titleLabel:SetFont("DermaLarge")
    titleLabel:SetTextColor(Color(255, 255, 255))
    titleLabel:SizeToContents()
    titleLabel:CenterHorizontal()
    titleLabel:SetPos(titleLabel:GetX(), 20)

    local duration = 30
    local endTime = CurTime() + duration

    local timerLabel = vgui.Create("DLabel", selector)
    timerLabel:SetFont("DermaLarge")
    timerLabel:SetTextColor(Color(255, 200, 0))
    timerLabel:SetPos(0, 60)
    timerLabel:SizeToContents()
    timerLabel:CenterHorizontal()

    selector.Think = function()
        if not IsValid(timerLabel) then return end

        local timeLeft = math.max(0, math.ceil(endTime - CurTime()))
        timerLabel:SetText(string.format("– %d –", timeLeft))
        timerLabel:SizeToContents()
        timerLabel:CenterHorizontal()

        if timeLeft <= 0 and IsValid(selector) then
            selector:Close()
			showAnimTooltip = false
            selectable = false

            net.Start("fh_selector_nomore")
            net.SendToServer()
        end
    end

    local scroll = vgui.Create("DScrollPanel", selector)
    scroll:SetPos(50, 100)
    scroll:SetSize(500, 450)

    grid = vgui.Create("DGrid", scroll)
    grid:SetCols(3)
    grid:SetColWide(150)
    grid:SetRowHeight(150)
    grid:Dock(TOP)
    grid:DockMargin(0, 0, 0, 0)

    local rowCount = math.ceil(#animatronics / 3)
    grid:SetTall(rowCount * 150)

    for i, animName in ipairs(animatronics) do
        local imagePath = "vgui/bars/" .. killerData[animName].name .. ".png"

        local box = vgui.Create("DImageButton")
        box:SetSize(140, 140)
        box.name = animName
		
		box.OnCursorEntered = function(self)
			local key = "fazhunt.animatronics.description." .. killerData[self.name].name
			local localized = language.GetPhrase(key)

			if localized == key then
				showAnimTooltip = false
			else
				showAnimTooltip = true
				animTooltipText = localized
			end
		end

		box.OnCursorExited = function(self)
			showAnimTooltip = false
		end

        box.DoClick = function()
            if not selectable then return end
            net.Start("fh_selected_killer")
            net.WriteString(animName)
            net.SendToServer()
        end

        if file.Exists("materials/" .. imagePath, "GAME") then
            box:SetImage(imagePath)
        else
            box.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0))
                draw.SimpleText(language.SafeGetPhrase(killerData[animName].fullname), "timerFontSmall", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        grid:AddItem(box)
    end
end

hook.Add("PostRenderVGUI", "DrawAnimTooltip", function()
	if not showAnimTooltip then return end

	local x, y = input.GetCursorPos()
	local maxWidth = 300
	local padding = 10

	surface.SetFont("DermaDefault")

	local rawLines = string.Explode("\n", animTooltipText, false)
	local lines = {}

	for _, rawLine in ipairs(rawLines) do
		if rawLine == "" then
			table.insert(lines, "")
		else
			local currentLine = ""
			for word in string.gmatch(rawLine, "%S+") do
				local testLine = currentLine == "" and word or currentLine .. " " .. word
				local testWidth = surface.GetTextSize(testLine)

				if testWidth > maxWidth - padding * 2 then
					if currentLine ~= "" then table.insert(lines, currentLine) end
					currentLine = word
				else
					currentLine = testLine
				end
			end
			if currentLine ~= "" then table.insert(lines, currentLine) end
		end
	end

	local tooltipWidth = maxWidth
	local tooltipHeight = #lines * 18 + padding * 2

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(x + 10, y + 10, tooltipWidth, tooltipHeight)

	for i, line in ipairs(lines) do
		draw.SimpleText(line, "DermaDefault", x + 10 + padding, y + 10 + padding + (i - 1) * 18, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end)


net.Receive("fh_let_killers_choose", function()
    animatronics = net.ReadTable()
    draw_killer_selector()

    timer.Simple(1.5, function()
        selectable = true
    end)
end)

net.Receive("fh_update_killer_selector", function()
    local ply = net.ReadPlayer()
    local killer = net.ReadString()

    if ply == LocalPlayer() then
        if IsValid(selector) then 
            selector:Close()
			showAnimTooltip = false
            selectable = false
        end
        return
    end

    if IsValid(selector) and IsValid(grid) then
        for _, v in pairs(grid:GetItems()) do
            if v.name == killer then
                v:SetEnabled(false)
                v:SetAlpha(100)
            end
        end
    end
end)





-- #### ТАЙМЕР!!!
net.Receive("fh_start_lobby_timer", function()
    local timerDuration = net.ReadFloat()
    timerTitle = language.SafeGetPhrase("fazhunt.generic.startup")
	local soundtoplay = net.ReadString()
    
    timerMode = "lobby"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 58
	roundtimer_alpha = 255
	
    timerEnd = CurTime() + timerDuration
	timerTotal = timerDuration
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
	
    surface.PlaySound(soundtoplay)
end)

net.Receive("fh_timer_cutback", function()
    local timerDuration = net.ReadFloat()
	local soundtoplay = net.ReadString()
    
    timerMode = "game"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 58
	roundtimer_alpha = 255
	
    timerEnd = CurTime() + timerDuration
    timerSetupEnd = CurTime()
	timerTotal = timerDuration
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
	
    surface.PlaySound(soundtoplay)
end)

// "ambient/alarms/warningbell1.wav"
net.Receive("fh_start_game_timer", function()
    local timerDuration = net.ReadFloat()
    local startupDuration = net.ReadFloat()
	local soundtoplay = net.ReadString()
	
    timerTitle = language.SafeGetPhrase("fazhunt.generic.round") .. ' ' .. net.ReadString()
	
	timerTotal = timerDuration
    
    timerEnd = CurTime() + timerDuration + startupDuration
    timerSetupEnd = CurTime() + startupDuration
	
	timer.Create('fh_timer_round_start', startupDuration, 1, function()
		timerMode = "game"
		roundtimer_alpha = 255
		roundtimer_y_target = 58
	end)
    
    timerMode = "postlobby"
    postlobbytimer_alpha = 255
	roundtimer_alpha = 45
	roundtimer_y_target = 50
    
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
    
    surface.PlaySound(soundtoplay)
end)

net.Receive("ResetTimer", function()
    timerMode = "endgame"
	
	if timer.Exists('fh_timer_round_start') then 
		timer.Remove('fh_timer_round_start') 
	end
	
	toggleScarySound(false)
	
	timerSetupEnd = 0
	timerEnd = 0
    
    hook.Remove("HUDPaint", "DrawGameTimer")
    surface.PlaySound("ambient/levels/canals/windchime2.wav")
end)

function language.SafeGetPhrase(key)
    return string.TrimRight(language.GetPhrase(key))
end