resource.AddFile("resource/fonts/trebuc.ttf")

local fh_draw_timer = CreateClientConVar('fh_draw_timer', 1, true, false, 'Draw Timer?', 0, 1)

local timerEnd = 0
local timerSetupEnd = 0
local timerMode = "lobby"
local timerTitle = 'ОЖИДАНИЕ ИГРОКОВ'

local postlobbytimer_alpha = 255

local roundtimer_alpha = 255
local roundtimer_y = 52
local roundtimer_y_target = 52
	
local fh_timer_width = 360

surface.CreateFont("timerFontUpper", { font = "Trebuchet MS", size = 32, weight = fh_timer_width, antialias = true, bold = true })
surface.CreateFont("timerFontBelow", { font = "Trebuchet MS", size = 48, weight = fh_timer_width, antialias = true, bold = false })

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
    local y = 16

    draw.RoundedBox(24, x, y, fh_timer_width, 100, Color(0, 0, 0, 200))

    draw.SimpleText(timerTitle, "timerFontUpper", ScrW() / 2, y + 20, Color(255, 0, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    draw.SimpleText("- " .. formatTime(timeLeft) .. " -", "timerFontBelow", ScrW() / 2, y + roundtimer_y, Color(255, 255, 255, roundtimer_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    draw.SimpleText(formatTime(timeStartupLeft), "timerFontUpper", ScrW() / 2, y + 82, Color(255, 174, 0, postlobbytimer_alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("Think", "fh_timer_think", function()
    if timerMode == "game" and postlobbytimer_alpha > 0 then
        postlobbytimer_alpha = postlobbytimer_alpha - 2
    end
	
    local speed = FrameTime() * 2
    roundtimer_y = Lerp(speed, roundtimer_y, roundtimer_y_target)
end)

net.Receive("fh_start_lobby_timer", function()
    local timerDuration = net.ReadFloat()
    timerTitle = language.GetPhrase("fazhunt.generic.startup")
    
    timerMode = "lobby"
	
    postlobbytimer_alpha = 0
	roundtimer_y_target = 64
	roundtimer_alpha = 255
	
    timerEnd = CurTime() + timerDuration
    hook.Add("HUDPaint", "DrawGameTimer", DrawTimer)
end)

net.Receive("fh_start_game_timer", function()
    local timerDuration = net.ReadFloat()
    local startupDuration = net.ReadFloat()
    
    timerTitle = language.GetPhrase("fazhunt.generic.round") .. ' ' .. net.ReadInt(32)
    
    timerEnd = CurTime() + timerDuration + startupDuration
    timerSetupEnd = CurTime() + startupDuration
	
	timer.Create('fh_timer_round_start', startupDuration, 1, function()
		timerMode = "game"
		roundtimer_alpha = 255
		roundtimer_y_target = 64
		
		toggleScarySound(true)
	end)
    
    timerMode = "postlobby"
    postlobbytimer_alpha = 255
	roundtimer_alpha = 45
	roundtimer_y_target = 52
    
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
