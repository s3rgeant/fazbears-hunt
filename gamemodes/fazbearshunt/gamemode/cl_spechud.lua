local playerSpecName

local function DrawDeadHUD()
	if playerSpecName == nil or playerSpecName == '' then return end

    local x = (ScrW() / 2) - (330 / 2)
    local y = ScrH() - (100 / 2) - 100

    draw.RoundedBox(10, x, y, 330, 100, Color(0, 0, 0, 200))

    draw.SimpleText("НАБЛЮДЕНИЕ:", "timerFontBelow", ScrW() / 2, y + 28, Color(255, 220, 0, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	
	draw.SimpleText(playerSpecName, "timerFontBelow", ScrW() / 2, y + 74, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

net.Receive("DeadHUDEnable", function()
	print('yes!')
	hook.Add("HUDPaint", "DrawDead", DrawDeadHUD)
end)

net.Receive("DeadHUDChange", function()
	playerSpecName = net.ReadString()
end)

net.Receive("DeadHUDDisable", function()
	hook.Remove( "HUDPaint" , "DrawDead" )
	playerSpecName = nil
end)

// сделал Zhapka