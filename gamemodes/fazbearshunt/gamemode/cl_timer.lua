-- не смотря на название файла "cl_timer" тут также будет большинство интерфейса

resource.AddFile("resource/fonts/ShareTechMonoRegular_0.ttf")

local timerBg = Material("vgui/timer/timer_bg.png")
local timerGlow = Material("vgui/timer/time_glow.png")

local fh_draw_timer = CreateClientConVar('fh_draw_timer', 1, true, false, 'Draw Timer?', 0, 1)

local timerEnd = 0
local timerSetupEnd = 0

local timerTotal = 0

local timerMode = "lobby"
local timerTitle = 'ОЖИДАНИЕ ИГРОКОВ'

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

local animatronics = {}
local selector
local grid
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
    titleLabel:SetText("ВЫБЕРИ АНИМАТРОНИКА")
    titleLabel:SetFont("DermaLarge")
    titleLabel:SetTextColor(Color(255, 255, 255))
    titleLabel:SizeToContents()
    titleLabel:CenterHorizontal()
    titleLabel:SetPos(titleLabel:GetX(), 20)

    local timeLeft = 30
    
    local timerLabel = vgui.Create("DLabel", selector)
    timerLabel:SetFont("DermaLarge")
    timerLabel:SetTextColor(Color(255, 200, 0))
    timerLabel:SetPos(0, 60)
    timerLabel:SetText(string.format("– %d –", timeLeft))
    timerLabel:SizeToContents()
    timerLabel:CenterHorizontal()
    
    timer.Create("AnimatronicMenuTimer", 1, 30, function()
        if not IsValid(timerLabel) or not IsValid(selector) then return end
        
        timeLeft = timeLeft - 1
        timerLabel:SetText(string.format("– %d –", timeLeft))
        timerLabel:SizeToContents()
        timerLabel:CenterHorizontal()
        
        if timeLeft <= 0 then
            if IsValid(selector) then selector:Close() end
            timer.Remove("AnimatronicMenuTimer")
			
			net.Start("fh_selector_nomore")
			net.SendToServer()
        end
    end)
    
    grid = vgui.Create("DGrid", selector)
	grid:SetPos(100, 100)
	grid:SetCols(3)
	grid:SetColWide(150)
	grid:SetRowHeight(150)
	
	for i, animName in ipairs(animatronics) do
		local imagePath = "vgui/bars/" .. killerData[animName].name .. ".png"
	
		if file.Exists("materials/" .. imagePath, "GAME") then
			local box = vgui.Create("DImageButton")
			box:SetSize(140, 140)
			box:SetImage(imagePath)
			box.name = animName
			box.DoClick = function()
				net.Start("fh_selected_killer")
				net.WriteString(animName)
				net.SendToServer()
			end
			grid:AddItem(box)
		else
			local box = vgui.Create("DImageButton")
			box:SetSize(140, 140)
			box.name = animName
			box.DoClick = function()
				net.Start("fh_selected_killer")
				net.WriteString(animName)
				net.SendToServer()
			end
	
			box.Paint = function(self, w, h)
				draw.RoundedBox(4, 0, 0, w, h, Color(0, 0, 0))
				draw.SimpleText(language.GetPhrase(killerData[animName].fullname), "timerFontSmall", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
	
			grid:AddItem(box)
		end
	end
end

net.Receive("fh_let_killers_choose", function()
    animatronics = net.ReadTable()
	
    draw_killer_selector()
end)

net.Receive("fh_update_killer_selector", function()
    local ply = net.ReadPlayer()
	local killer = net.ReadString()
	
	if ply == LocalPlayer() then
        if IsValid(selector) then selector:Close() end
		return
	end
	if IsValid(selector) and IsValid(grid) then
		for _,v in pairs(grid:GetItems()) do
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
    timerTitle = language.GetPhrase("fazhunt.generic.startup")
    
    timerMode = "lobby"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 58
	roundtimer_alpha = 255
	
    timerEnd = CurTime() + timerDuration
	timerTotal = timerDuration
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
end)

net.Receive("fh_start_game_timer", function()
    local timerDuration = net.ReadFloat()
    local startupDuration = net.ReadFloat()
	
	timerTotal = timerDuration
    
    timerTitle = language.GetPhrase("fazhunt.generic.round") .. ' ' .. net.ReadInt(32)
    
    timerEnd = CurTime() + timerDuration + startupDuration
    timerSetupEnd = CurTime() + startupDuration
	
	timer.Create('fh_timer_round_start', startupDuration, 1, function()
		timerMode = "game"
		roundtimer_alpha = 255
		roundtimer_y_target = 58
		
		toggleScarySound(true)
	end)
    
    timerMode = "postlobby"
    postlobbytimer_alpha = 255
	roundtimer_alpha = 45
	roundtimer_y_target = 50
    
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
    
    surface.PlaySound("ambient/alarms/warningbell1.wav")
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

concommand.Add("AAA_fh", function()

    local timerDuration = 8
    timerTitle = language.GetPhrase("fazhunt.generic.startup")
    
    timerMode = "lobby"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 64
	roundtimer_alpha = 255
	
    timerEnd = CurTime() + timerDuration
	timerTotal = timerDuration
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
end)