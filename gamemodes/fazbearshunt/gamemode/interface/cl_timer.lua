-- не смотря на название файла "cl_timer" тут также будет большинство интерфейса

resource.AddFile("resource/fonts/sharetechmonoregular_0.ttf")

local timerBg = Material("vgui/timer/timer_bg.png")
local timerGlow = Material("vgui/timer/time_glow.png")

local fh_draw_timer = CreateClientConVar('fh_draw_timer', 1, true, false, 'Draw Timer?', 0, 1)

local timerStart = 0
local timerEnd = 0
local timerSetupEnd = 0

local timerTotal = 0

local timerMode = "lobby"
local timerTitle = language.GetPhrase("fazhunt.generic.waiting_player")

local timerSubtitle = ""

local postlobbytimer_alpha = 255

local roundtimer_alpha = 255
local roundtimer_y = 52
local roundtimer_y_target = 52
	
local fh_timer_width = 360

surface.CreateFont("timerFontUpper", { font = "Share Tech Mono", size = 32, extended = true, weight = fh_timer_width, antialias = true, bold = true })
surface.CreateFont("timerFontBelow", { font = "Share Tech Mono", size = 48, extended = true, weight = fh_timer_width, antialias = true, bold = false })
surface.CreateFont("timerFontSmall", { font = "Share Tech Mono", size = 24, extended = true, weight = fh_timer_width, antialias = true, bold = true })

local function DrawTimer()
    if not GetConVar("cl_drawhud"):GetBool() or not fh_draw_timer:GetBool() then return end

    local timeStartupLeft = math.max(0, timerSetupEnd - CurTime())
	local timeLeft = timerEnd - CurTime()
	if timeStartupLeft > 0 then
		timeLeft = math.ceil(math.max(0, timerEnd - timerSetupEnd))
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

	local progress

	if timeStartupLeft > 0 then
		progress = 1
	elseif timerSetupEnd > 0 then
		progress = math.Clamp(timeLeft / (timerEnd - timerStart - (timerSetupEnd - timerStart)), 0, 1)
	else
		progress = math.Clamp(timeLeft / (timerEnd - timerStart), 0, 1)
	end

	draw.RoundedBox(0, x, y, fh_timer_width * progress, redline_w, Color(136, 0, 0, 255))
	
	local timertext = timerTitle .. (timerMode ~= "paused" and "" or " (PAUSED)")

    draw.SimpleText(timertext, "timerFontUpper", ScrW() / 2, main_y + 20, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	local whatToShow = (timerMode ~= "paused") and formatTime(timeLeft) or timerSubtitle
    
    draw.SimpleText("- " .. whatToShow .. " -", "timerFontBelow", ScrW() / 2, main_y + roundtimer_y, Color(255, 255, 255, roundtimer_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
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

-- #### ТАЙМЕР!!!
net.Receive("fh_start_lobby_timer", function()
    timerStart = net.ReadFloat()
    timerEnd = net.ReadFloat()
    
    timerTitle = language.GetPhrase("fazhunt.generic.startup")
    timerMode = "lobby"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 58
	roundtimer_alpha = 255
	
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
end)

net.Receive("fh_timer_cutback", function()
    timerStart = net.ReadFloat()
    timerEnd = net.ReadFloat()
	local soundtoplay = net.ReadString()
    
    timerMode = "game"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 58
	roundtimer_alpha = 255
	
    timerSetupEnd = timerStart
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
	
    surface.PlaySound(soundtoplay)
end)

// "ambient/alarms/warningbell1.wav"
net.Receive("fh_start_game_timer", function()
    timerStart = net.ReadFloat()
    timerEnd = net.ReadFloat()
    local startupDuration = net.ReadFloat()
	
	local soundtoplay = net.ReadString()
	
    timerTitle = language.GetPhrase("fazhunt.generic.round") .. ' ' .. net.ReadString()
    
    timerSetupEnd = timerStart + startupDuration
	
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

net.Receive("fh_pause_game_timer", function()
    local timeStamp = net.ReadFloat()
	local soundtoplay = net.ReadString()
    
    timerSubtitle = formatTime(timeStamp)
	
	timer.Remove('fh_timer_round_start')
	
	timerMode = "paused"
	roundtimer_alpha = 150
	roundtimer_y_target = 58
    
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
    
    surface.PlaySound(soundtoplay)
end)

net.Receive("ResetTimer", function()
    timerMode = "endgame"
	
	if timer.Exists('fh_timer_round_start') then 
		timer.Remove('fh_timer_round_start') 
	end
	
	toggleScarySound(false)
	
	timerStart = 0
	timerSetupEnd = 0
	timerEnd = 0
    
    hook.Remove("HUDPaint", "DrawGameTimer")
    surface.PlaySound("ambient/levels/canals/windchime2.wav")
end)

function language.SafeGetPhrase(key)
    return string.TrimRight(language.GetPhrase(key))
end